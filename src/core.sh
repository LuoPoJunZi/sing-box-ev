# ==========================================
# Sing-box-EV Core Business Logic
# ==========================================

. "$is_sh_dir/src/core/00_env.sh"
. "$is_sh_dir/src/core/10_ui.sh"
. "$is_sh_dir/src/core/20_validate.sh"
. "$is_sh_dir/src/core/30_runtime.sh"
. "$is_sh_dir/src/core/40_node_query.sh"
. "$is_sh_dir/src/core/50_node_write.sh"
. "$is_sh_dir/src/core/60_sub.sh"
. "$is_sh_dir/src/core/70_admin.sh"

msg() { ui_msg "$@"; }
msg_ul() { ui_msg_ul "$@"; }
pause() { ui_pause; }

get_uuid() {
    tmp_uuid=$(cat /proc/sys/kernel/random/uuid)
}

get_ip() {
    if [[ $ip || $is_no_auto_tls || $is_gen || $is_dont_get_ip ]]; then
        return
    fi
    ip=$(curl -s4m8 https://icanhazip.com || wget -qO- -t1 -T8 https://icanhazip.com)
    if [[ ! $ip ]]; then
        ip=$(curl -s6m8 https://icanhazip.com || wget -qO- -t1 -T8 https://icanhazip.com)
    fi
    if [[ ! $ip ]]; then
        err "获取服务器 IP 失败，请检查网络.."
    fi
}

install_cloudflared() {
    if [[ ! $(type -P cloudflared) ]]; then
        msg "正在下载并安装 Cloudflare Tunnel (cloudflared)..."
        local cf_arch="amd64"
        if [[ $(uname -m) =~ "aarch64" || $(uname -m) =~ "armv8" ]]; then
            cf_arch="arm64"
        fi
        wget -qO /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${cf_arch}
        chmod +x /usr/local/bin/cloudflared
        msg "✅ Cloudflare Tunnel 安装完成."
    fi
}

create_cftunnel_service() {
    local token=$1
    local l_port=$2
    cat <<EOF > /lib/systemd/system/cftunnel-${l_port}.service
[Unit]
Description=Cloudflare Tunnel for Port ${l_port}
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudflared tunnel --no-autoupdate run --token ${token}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now cftunnel-${l_port}.service &>/dev/null
    msg "✅ CFtunnel 穿透守护服务 (关联内部端口: ${l_port}) 已创建并启动."
    msg "⚠️  $(_yellow "重要：别忘了去 Cloudflare 面板完成域名映射！")"
}

firewall_allow() {
    local target_port=$1
    if [[ -z "$target_port" ]]; then
        return
    fi

    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        ufw allow ${target_port}/tcp >/dev/null 2>&1
        ufw allow ${target_port}/udp >/dev/null 2>&1
        msg "✅ 防火墙 (UFW): 已自动放行端口 ${target_port}"
    elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld | grep -q "^active"; then
        firewall-cmd --add-port=${target_port}/tcp --permanent >/dev/null 2>&1
        firewall-cmd --add-port=${target_port}/udp --permanent >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
        msg "✅ 防火墙 (Firewalld): 已自动放行端口 ${target_port}"
    elif command -v iptables >/dev/null 2>&1; then
        iptables -I INPUT -p tcp --dport ${target_port} -j ACCEPT >/dev/null 2>&1
        iptables -I INPUT -p udp --dport ${target_port} -j ACCEPT >/dev/null 2>&1
        if [[ -f /etc/sysconfig/iptables ]]; then
            service iptables save >/dev/null 2>&1
        fi
        if command -v netfilter-persistent >/dev/null 2>&1; then
            netfilter-persistent save >/dev/null 2>&1
        fi
        msg "✅ 防火墙 (Iptables): 已尝试放行端口 ${target_port}"
    fi
}

get_port() {
    is_count=0
    while :; do
        ((is_count++))
        if [[ $is_count -ge 233 ]]; then
            err "自动获取可用端口失败次数达到 233 次, 请检查端口占用情况."
        fi
        tmp_port=$(shuf -i 20000-65535 -n 1)
        if [[ ! $(is_test port_used $tmp_port) && $tmp_port != $port ]]; then
            break
        fi
    done

    if [[ $tmp_port ]]; then
        firewall_allow "$tmp_port"
    fi
}

get_pbk() {
    is_tmp_pbk=($($is_core_bin generate reality-keypair | sed 's/.*://'))
    is_public_key=${is_tmp_pbk[1]}
    is_private_key=${is_tmp_pbk[0]}
}

list_conf_json_names() {
    local file_filter="${1:-.json$}"
    find "$is_conf_dir" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null |
        grep -E -i "$file_filter" |
        sed '/dynamic-port-.*-link/d' |
        head -233
}

show_list() { ui_show_list "$@"; }

is_test() { validate_is_test "$@"; }

is_port_used() { validate_is_port_used "$@"; }

ask() {
    case $1 in
    set_ss_method)
        is_tmp_list=(${ss_method_list[@]})
        is_default_arg=$is_random_ss_method
        is_opt_msg="\n请选择加密方式:"
        is_opt_input_msg="➡️ 请选择 \e[92m(输入 0 返回主面板，默认 $is_default_arg)\e[0m: "
        is_ask_set=ss_method
        ;;
    set_protocol)
        echo -e "\e[96m=====================================================\e[0m"
        echo -e "                 请选择要添加的协议"
        echo -e "\e[96m=====================================================\e[0m"
        echo -e "  \e[93m[ 基础协议 ]\e[0m"
        echo -e "  \e[92m(1)\e[0m TUIC        \e[92m(2)\e[0m Trojan       \e[92m(3)\e[0m Hysteria2   \e[92m(4)\e[0m VMess-WS"
        echo -e "  \e[92m(5)\e[0m VMess-TCP   \e[92m(6)\e[0m VMess-HTTP   \e[92m(7)\e[0m VMess-QUIC  \e[92m(8)\e[0m Shadowsocks"
        echo -e "  \e[93m[ TLS 隧道 ]\e[0m"
        echo -e "  \e[92m(9)\e[0m VMess-H2    \e[92m(10)\e[0m VMess-WS   \e[92m(11)\e[0m VLESS-H2   \e[92m(12)\e[0m VLESS-WS"
        echo -e "  \e[92m(13)\e[0m Trojan-H2  \e[92m(14)\e[0m Trojan-WS  \e[92m(15)\e[0m VMess-HU   \e[92m(16)\e[0m VLESS-HU"
        echo -e "  \e[92m(17)\e[0m Trojan-HU\n"
        echo -e "  \e[93m[ 强力抗封锁 ]\e[0m"
        echo -e "  \e[92m(18)\e[0m VLESS-REALITY     \e[92m(19)\e[0m VLESS-HTTP2-REALITY"
        echo -e "  \e[92m(20)\e[0m AnyTLS\n"
        echo -e "  \e[93m[ 隧道穿透 ]\e[0m"
        echo -e "  \e[92m(21)\e[0m CFtunnel          \e[92m(22)\e[0m Socks\n"
        echo -e "  \e[93m[ 取消操作 ]\e[0m"
        echo -e "  \e[92m(0)\e[0m 返回主面板"
        echo -e "\e[90m-----------------------------------------------------\e[0m"
        is_ask_set=is_new_protocol
        is_opt_input_msg="➡️ 请选择协议序号 [\e[91m0-22\e[0m]: "
        ;;
    set_change_list)
        is_tmp_list=()
        for v in ${is_can_change[@]}; do
            is_tmp_list+=("${change_list[$v]}")
        done
        is_opt_msg="\n请选择更改:"
        is_ask_set=is_change_str
        is_opt_input_msg="➡️ 请输入对应的数字 \e[92m(输入 0 返回主面板)\e[0m: "
        ;;
    string)
        is_ask_set=$2
        is_opt_input_msg="${3/:/} \e[92m(输入 0 返回主面板)\e[0m: "
        ;;
    list)
        is_ask_set=$2
        if [[ ! $is_tmp_list ]]; then
            is_tmp_list=($3)
        fi
        is_opt_msg=$4
        if [[ ! $is_opt_msg ]]; then
            is_opt_msg="\n请选择:"
        fi
        is_opt_input_msg=$5
        if [[ ! $is_opt_input_msg ]]; then
            is_opt_input_msg="➡️ 请输入对应的数字 \e[92m(输入 0 返回主面板)\e[0m: "
        else
            is_opt_input_msg="${is_opt_input_msg/:/} \e[92m(输入 0 返回主面板)\e[0m: "
        fi
        ;;
    get_config_file)
        is_tmp_list=("${is_all_json[@]}")
        is_opt_msg="\n请选择配置:"
        is_ask_set=is_config_file
        is_opt_input_msg="➡️ 请输入对应的数字 \e[92m(输入 0 返回主面板)\e[0m: "
        ;;
    esac

    if [[ $is_opt_msg ]]; then
        msg "$is_opt_msg"
    fi
    if [[ $is_tmp_list ]]; then
        show_list "${is_tmp_list[@]}"
    fi

    while :; do
        echo -ne "$is_opt_input_msg"
        read REPLY

        if [[ "$REPLY" == "0" ]]; then
            echo -e "\n\e[33m已安全取消当前操作，正在返回主面板...\e[0m"
            sleep 0.5
            is_main_menu
            exit 0
        fi

        if [[ ! $REPLY && $is_emtpy_exit ]]; then
            exit
        fi
        if [[ ! $REPLY && $is_default_arg ]]; then
            export $is_ask_set=$is_default_arg
            break
        fi
        if [[ ! $REPLY && ! $is_default_arg && ! $is_emtpy_exit ]]; then
            continue
        fi

        if [[ $1 == "set_protocol" ]]; then
            if [[ "$REPLY" =~ ^([1-9]|1[0-9]|2[0-2])$ ]]; then
                export $is_ask_set="${protocol_list[$REPLY-1]}"
                break
            fi
        elif [[ ! $is_tmp_list ]]; then
            if [[ $(grep port <<<$is_ask_set) ]]; then
                if [[ ! $(is_test port "$REPLY") ]]; then
                    msg "$is_err 请输入正确的端口, 可选(1-65535)"
                    continue
                fi
                if [[ $(is_test port_used $REPLY) && $is_ask_set != 'door_port' ]]; then
                    msg "$is_err 无法使用 ($REPLY) 端口."
                    continue
                fi
            fi
            if [[ $(grep path <<<$is_ask_set) && ! $(is_test path "$REPLY") ]]; then
                if [[ ! $tmp_uuid ]]; then
                    get_uuid
                fi
                msg "$is_err 请输入正确的路径, 例如: /$tmp_uuid"
                continue
            fi
            if [[ $(grep uuid <<<$is_ask_set) && ! $(is_test uuid "$REPLY") ]]; then
                if [[ ! $tmp_uuid ]]; then
                    get_uuid
                fi
                msg "$is_err 请输入正确的 UUID, 例如: $tmp_uuid"
                continue
            fi
            if [[ $(grep ^y$ <<<$is_ask_set) ]]; then
                if [[ $(grep -i ^y$ <<<"$REPLY") ]]; then
                    break
                fi
                msg "请输入 (y)"
                continue
            fi
            if [[ $REPLY ]]; then
                export $is_ask_set=$REPLY
                msg "使用: ${!is_ask_set}"
                break
            fi
        else
            if [[ $(is_test number "$REPLY") ]]; then
                is_ask_result=${is_tmp_list[$REPLY - 1]}
            fi
            if [[ $is_ask_result ]]; then
                export $is_ask_set="$is_ask_result"
                msg "选择: ${!is_ask_set}"
                break
            fi
        fi

        msg "输入${is_err}"
    done
    unset is_opt_msg is_opt_input_msg is_tmp_list is_ask_result is_default_arg is_emtpy_exit
}

create() { write_create "$@"; }

change() { write_change "$@"; }

del() { write_del "$@"; }

get() { query_get "$@"; }

info() { query_info "$@"; }

show_all_nodes() { query_show_all_nodes "$@"; }

gen_sub() { sub_gen_sub; }

add() { write_add "$@"; }

footer_msg() { ui_footer_msg; }

url_qr() { query_url_qr "$@"; }

update() { admin_update "$@"; }

uninstall() { admin_uninstall "$@"; }

is_main_menu() { admin_is_main_menu "$@"; }

main() { admin_main "$@"; }


