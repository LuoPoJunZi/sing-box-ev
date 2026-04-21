#!/bin/bash
# ==========================================
# Sing-box-EV Utility Toolbox
# ==========================================

# ----------------- Download 模块 -----------------
get_latest_version() {
    case $1 in
        core)
            name=$is_core_name
            url="https://api.github.com/repos/${is_core_repo}/releases/latest?v=$RANDOM"
            ;;
        sh)
            name="$is_core_name 脚本"
            url="https://api.github.com/repos/$is_sh_repo/releases/latest?v=$RANDOM"
            ;;
        caddy)
            name="Caddy"
            url="https://api.github.com/repos/$is_caddy_repo/releases/latest?v=$RANDOM"
            ;;
    esac
    latest_ver=$(_wget -qO- $url | grep tag_name | grep -E -o 'v([0-9.]+)')
    [[ ! $latest_ver ]] && err "获取 ${name} 最新版本失败."
    unset name url
}

download() {
    latest_ver=$2
    [[ ! $latest_ver ]] && get_latest_version $1
    tmpdir=$(mktemp -d 2> /dev/null || mktemp -d -t 'tmp-XXXXXX')

    case $1 in
        core)
            name=$is_core_name
            tmpfile=$tmpdir/$is_core.tar.gz
            link="https://github.com/${is_core_repo}/releases/download/${latest_ver}/${is_core}-${latest_ver:1}-linux-${is_arch}.tar.gz"
            download_file
            tar zxf $tmpfile --strip-components 1 -C $is_core_dir/bin
            chmod +x $is_core_bin
            ;;
        sh)
            name="$is_core_name 脚本"
            tmpfile=$tmpdir/sh.tar.gz
            link="https://github.com/${is_sh_repo}/archive/refs/tags/${latest_ver}.tar.gz"
            download_file
            tar zxf $tmpfile --strip-components 1 -C $is_sh_dir
            chmod +x $is_sh_bin ${is_sh_bin/$is_core/sb}
            ;;
        caddy)
            name="Caddy"
            tmpfile=$tmpdir/caddy.tar.gz
            link="https://github.com/${is_caddy_repo}/releases/download/${latest_ver}/caddy_${latest_ver:1}_linux_${is_arch}.tar.gz"
            download_file
            tar zxf $tmpfile -C $tmpdir
            cp -f $tmpdir/caddy $is_caddy_bin
            chmod +x $is_caddy_bin
            managed_record file "$is_caddy_bin"
            managed_record dir "$is_caddy_dir"
            managed_record file /lib/systemd/system/caddy.service
            ;;
    esac
    rm -rf -- "$tmpdir"
    unset latest_ver
}

download_file() {
    if ! _wget -t 5 -c $link -O $tmpfile; then
        rm -rf -- "$tmpdir"
        err "\n下载 ${name} 失败.\n"
    fi
}

# ----------------- Systemd 模块 -----------------
install_service() {
    case $1 in
        $is_core)
            cat > /lib/systemd/system/$is_core.service <<< "
[Unit]
Description=$is_core_name Service
Documentation=https://sing-box.sagernet.org/
After=network.target nss-lookup.target

[Service]
User=root
NoNewPrivileges=true
ExecStart=$is_core_bin run -c $is_config_json -C $is_conf_dir
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full

[Install]
WantedBy=multi-user.target"
            ;;
        caddy)
            cat > /lib/systemd/system/caddy.service <<< "
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=root
Group=root
ExecStart=$is_caddy_bin run --environ --config $is_caddyfile --adapter caddyfile
ExecReload=$is_caddy_bin reload --config $is_caddyfile --adapter caddyfile
TimeoutStopSec=5s
LimitNPROC=10000
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full

[Install]
WantedBy=multi-user.target"
            ;;
    esac
    systemctl enable $1 > /dev/null 2>&1
    systemctl daemon-reload > /dev/null 2>&1
}

# ----------------- BBR 模块 -----------------
_open_bbr() {
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    sysctl -p &> /dev/null
    echo
    _green "..已经启用 BBR 优化...."
    echo
}

_try_enable_bbr() {
    local _test1=$(uname -r | cut -d\. -f1)
    local _test2=$(uname -r | cut -d\. -f2)
    if [[ $_test1 -eq 4 && $_test2 -ge 9 ]] || [[ $_test1 -ge 5 ]]; then
        _open_bbr
    else
        err "不支持启用 BBR 优化."
    fi
}

# ----------------- Log 模块 -----------------
is_log_level_list=(trace debug info warn error fatal panic none del)

log_set() {
    if [[ $1 ]]; then
        for v in ${is_log_level_list[@]}; do
            [[ $(grep -E -i "^${1,,}$" <<< $v) ]] && is_log_level_use=$v && break
        done
        [[ ! $is_log_level_use ]] && err "无法识别 log 参数."

        case $is_log_level_use in
            del)
                rm -f -- "$is_log_dir"/*.log 2> /dev/null
                msg "\n $(_green 已临时删除 log 文件.)\n"
                ;;
            none)
                rm -f -- "$is_log_dir"/*.log 2> /dev/null
                cat <<< $(jq '.log={"disabled":true}' $is_config_json) > $is_config_json
                ;;
            *)
                cat <<< $(jq '.log={output:"/var/log/'$is_core'/access.log",level:"'$is_log_level_use'","timestamp":true}' $is_config_json) > $is_config_json
                ;;
        esac

        manage restart &
        [[ $1 != 'del' ]] && msg "\n已更新 Log 设定为: $(_green $is_log_level_use)\n"
    else
        if [[ -f $is_log_dir/access.log ]]; then
            msg "\n 提醒: 按 $(_green Ctrl + C) 退出\n"
            tail -f $is_log_dir/access.log
        else
            err "无法找到 log 文件."
        fi
    fi
}

# ----------------- DNS 模块 -----------------
is_dns_list=(1.1.1.1 8.8.8.8 h3://dns.google/dns-query h3://cloudflare-dns.com/dns-query h3://family.cloudflare-dns.com/dns-query set none)

dns_set() {
    if [[ $(echo -e "1.11.99\n$is_core_ver" | sort -V | head -n1) == '1.11.99' ]]; then
        is_dns_new=1
    fi
    if [[ $1 ]]; then
        case ${1,,} in
            11 | 1111) is_dns_use=${is_dns_list[0]} ;;
            88 | 8888) is_dns_use=${is_dns_list[1]} ;;
            gg | google) is_dns_use=${is_dns_list[2]} ;;
            cf | cloudflare) is_dns_use=${is_dns_list[3]} ;;
            nosex | family) is_dns_use=${is_dns_list[4]} ;;
            set) [[ $2 ]] && is_dns_use=${2,,} || ask string is_dns_use "请输入 DNS: " ;;
            none) is_dns_use=none ;;
            *) err "无法识别 DNS 参数" ;;
        esac
    else
        is_tmp_list=(${is_dns_list[@]})
        ask list is_dns_use "" "\n请选择 DNS:\n"
        [[ $is_dns_use == "set" ]] && ask string is_dns_use "请输入 DNS: "
    fi
    is_dns_use_bak=$is_dns_use
    if [[ $is_dns_use == "none" ]]; then
        cat <<< $(jq '.|.dns={}|del(.route.default_domain_resolver)' $is_config_json) > $is_config_json
    else
        if [[ $is_dns_new ]]; then
            dns_set_server $is_dns_use
            cat <<< $(jq '.|.dns.servers=[{tag:"dns",type:"'$is_dns_type'",server:"'$is_dns_use'",domain_resolver:"local"},{tag:"local",type:"local"}]|.route.default_domain_resolver="dns"' $is_config_json) > $is_config_json
        else
            cat <<< $(jq '.dns.servers=[{address:"'$is_dns_use'",address_resolver:"local"},{tag:"local",address:"local"}]' $is_config_json) > $is_config_json
        fi
    fi
    manage restart &
    msg "\n已更新 DNS 为: $(_green $is_dns_use_bak)\n"
}

dns_set_server() {
    if [[ $(grep '://' <<< $1) ]]; then
        is_tmp_dns_set=($(awk -F '://|/' '{print $1, $2}' <<< ${1,,}))
        case ${is_tmp_dns_set[0]} in
            tcp | udp | tls | https | quic | h3)
                is_dns_use=${is_tmp_dns_set[1]}
                is_dns_type=${is_tmp_dns_set[0]}
                ;;
            *) err "无法识别 DNS 类型!" ;;
        esac
    else
        is_dns_use=$1
        is_dns_type=udp
    fi
}
