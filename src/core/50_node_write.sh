#!/bin/bash

write_create() {
    case $1 in
    server)
        is_tls=none
        get new
        is_listen='listen: "::"'

        if [[ $is_new_protocol == 'CFtunnel' ]]; then
            is_listen='listen: "127.0.0.1"'
        fi

        local safe_remark="${custom_remark//\//_}"
        if [[ -z "$safe_remark" ]]; then
            safe_remark="luopojunzi"
        fi

        if [[ $host ]]; then
            is_config_name=$2-${safe_remark}-${host}.json
            if [[ $is_new_protocol != 'CFtunnel' ]]; then
                is_listen='listen: "127.0.0.1"'
            fi
        else
            is_config_name=$2-${safe_remark}-${port}.json
        fi

        is_json_file=$is_conf_dir/$is_config_name

        if [[ $is_change || ! $json_str ]]; then
            get protocol $2
        fi
        if [[ $net == "reality" ]]; then
            is_add_public_key=",outbounds:[{type:\"direct\"},{tag:\"public_key_$is_public_key\",type:\"direct\"}]"
        fi
        is_new_json=$(jq "{inbounds:[{tag:\"$is_config_name\",type:\"$is_protocol\",$is_listen,listen_port:$port,$json_str}]$is_add_public_key}" <<<{})
        if [[ $is_test_json ]]; then
            return
        fi
        if [[ $is_gen ]]; then
            msg
            jq <<<$is_new_json
            msg
            return
        fi
        if [[ $is_config_file ]]; then
            is_no_del_msg=1
            del $is_config_file
        fi

        cat <<<$is_new_json >$is_json_file

        if [[ $is_new_protocol == 'CFtunnel' && $cf_token ]]; then
            install_cloudflared
            create_cftunnel_service "$cf_token" "$port"
        fi

        if [[ $is_new_install ]]; then
            create config.json
        fi
        if [[ $is_caddy && $host && ! $is_no_auto_tls ]]; then
            create caddy $net
        fi
        manage restart &
        ;;
    client)
        is_tls=tls
        is_client=1
        get info $2
        if [[ ! $is_client_id_json ]]; then
            err "($is_config_name) 不支持生成客户端配置."
        fi
        is_new_json=$(jq '{outbounds:[{tag:'\"$is_config_name\"',protocol:'\"$is_protocol\"','"$is_client_id_json"','"$is_stream"'}]}' <<<{})
        msg
        jq <<<$is_new_json
        msg
        ;;
    caddy)
        load caddy.sh
        if [[ $is_install_caddy ]]; then
            caddy_config new
        fi
        if [[ ! $(grep "$is_caddy_conf" $is_caddyfile) ]]; then
            msg "import $is_caddy_conf/*.conf" >>$is_caddyfile
        fi
        if [[ ! -d $is_caddy_conf ]]; then
            mkdir -p $is_caddy_conf
        fi
        caddy_config $2
        manage restart caddy &
        ;;
    config.json)
        is_log='log:{output:"/var/log/'$is_core'/access.log",level:"info","timestamp":true}'
        is_dns='dns:{}'
        is_ntp='ntp:{"enabled":true,"server":"time.apple.com"},'
        if [[ -f $is_config_json ]]; then
            if [[ $(jq .ntp.enabled $is_config_json) != "true" ]]; then
                is_ntp=
            fi
        else
            if [[ ! $is_ntp_on ]]; then
                is_ntp=
            fi
        fi
        is_outbounds='outbounds:[{tag:"direct",type:"direct"}]'
        is_server_config_json=$(jq "{$is_log,$is_dns,$is_ntp$is_outbounds}" <<<{})
        cat <<<$is_server_config_json >$is_config_json
        manage restart &
        ;;
    esac
}

write_change() {
    is_change=1
    is_dont_show_info=1
    if [[ $2 ]]; then
        case ${2,,} in
        full) is_change_id=full ;;
        new) is_change_id=0 ;;
        port) is_change_id=1 ;;
        host) is_change_id=2 ;;
        path) is_change_id=3 ;;
        pass | passwd | password) is_change_id=4 ;;
        id | uuid) is_change_id=5 ;;
        ssm | method | ss-method | ss_method) is_change_id=6 ;;
        dda | door-addr | door_addr) is_change_id=7 ;;
        ddp | door-port | door_port) is_change_id=8 ;;
        key | publickey | privatekey) is_change_id=9 ;;
        sni | servername | servernames) is_change_id=10 ;;
        web | proxy-site) is_change_id=11 ;;
        *)
            if [[ $is_try_change ]]; then return; fi
            err "无法识别 ($2) 更改类型."
            ;;
        esac
    fi
    if [[ $is_try_change ]]; then
        return
    fi
    if [[ $is_dont_auto_exit ]]; then
        get info $1
    else
        if [[ $is_change_id ]]; then
            is_change_msg=${change_list[$is_change_id]}
            if [[ $is_change_id == 'full' ]]; then
                if [[ $3 ]]; then
                    is_change_msg="更改多个参数"
                else
                    is_change_msg=
                fi
            fi
            if [[ $is_change_msg ]]; then
                _green "\n快速执行: $is_change_msg"
            fi
        fi
        info $1
        if [[ $is_auto_get_config ]]; then
            msg "\n自动选择: $is_config_file"
        fi
    fi

    is_old_net=$net
    if [[ $is_tcp_http ]]; then net=http; fi
    if [[ $host ]]; then net=$is_protocol-$net-tls; fi
    if [[ $is_reality && $net_type =~ 'http' ]]; then net=rh2; fi

    if [[ $3 == 'auto' ]]; then is_auto=1; fi
    is_dont_show_info=
    if [[ ! $is_change_id ]]; then
        ask set_change_list
        is_change_id=${is_can_change[$REPLY - 1]}
    fi

    case $is_change_id in
    full) add $net ${@:3} ;;
    0) is_set_new_protocol=1; add ${@:3} ;;
    1)
        is_new_port=$3
        if [[ $host && ! $is_caddy || $is_no_auto_tls ]]; then
            err "($is_config_file) 不支持更改端口, 因为没啥意义."
        fi
        if [[ $is_new_port && ! $is_auto ]]; then
            if [[ ! $(is_test port $is_new_port) ]]; then err "请输入正确的端口, 可选(1-65535)"; fi
            if [[ $is_new_port != 443 && $(is_test port_used $is_new_port) ]]; then err "无法使用 ($is_new_port) 端口"; fi
        fi
        if [[ $is_auto ]]; then get_port; is_new_port=$tmp_port; fi
        if [[ ! $is_new_port ]]; then ask string is_new_port "请输入新端口"; fi
        if [[ $is_caddy && $host ]]; then
            net=$is_old_net
            is_https_port=$is_new_port
            load caddy.sh
            caddy_config $net
            manage restart caddy &
            info
        else
            add $net $is_new_port
        fi
        ;;
    2)
        is_new_host=$3
        if [[ ! $host ]]; then err "($is_config_file) 不支持更改域名."; fi
        if [[ ! $is_new_host ]]; then ask string is_new_host "请输入新域名"; fi
        old_host=$host
        add $net $is_new_host
        ;;
    3)
        is_new_path=$3
        if [[ ! $path ]]; then err "($is_config_file) 不支持更改路径."; fi
        if [[ $is_auto ]]; then get_uuid; is_new_path=/$tmp_uuid; fi
        if [[ ! $is_new_path ]]; then ask string is_new_path "请输入新路径"; fi
        add $net auto auto $is_new_path
        ;;
    4)
        is_new_pass=$3
        if [[ $ss_password || $password ]]; then
            if [[ $is_auto ]]; then
                get_uuid
                is_new_pass=$tmp_uuid
                if [[ $ss_password ]]; then is_new_pass=$(get ss2022); fi
            fi
        else
            err "($is_config_file) 不支持更改密码."
        fi
        if [[ ! $is_new_pass ]]; then ask string is_new_pass "请输入新密码"; fi
        password=$is_new_pass
        ss_password=$is_new_pass
        is_socks_pass=$is_new_pass
        add $net
        ;;
    5)
        is_new_uuid=$3
        if [[ ! $uuid ]]; then err "($is_config_file) 不支持更改 UUID."; fi
        if [[ $is_auto ]]; then get_uuid; is_new_uuid=$tmp_uuid; fi
        if [[ ! $is_new_uuid ]]; then ask string is_new_uuid "请输入新 UUID"; fi
        add $net auto $is_new_uuid
        ;;
    6)
        is_new_method=$3
        if [[ $net != 'ss' ]]; then err "($is_config_file) 不支持更改加密方式."; fi
        if [[ $is_auto ]]; then is_new_method=$is_random_ss_method; fi
        if [[ ! $is_new_method ]]; then ask set_ss_method; is_new_method=$ss_method; fi
        add $net auto auto $is_new_method
        ;;
    7)
        is_new_door_addr=$3
        if [[ $net != 'direct' ]]; then err "($is_config_file) 不支持更改目标地址."; fi
        if [[ ! $is_new_door_addr ]]; then ask string is_new_door_addr "请输入新的目标地址"; fi
        door_addr=$is_new_door_addr
        add $net
        ;;
    8)
        is_new_door_port=$3
        if [[ $net != 'direct' ]]; then err "($is_config_file) 不支持更改目标端口."; fi
        if [[ ! $is_new_door_port ]]; then ask string door_port "请输入新的目标端口"; is_new_door_port=$door_port; fi
        add $net auto auto $is_new_door_port
        ;;
    9)
        is_new_private_key=$3
        is_new_public_key=$4
        if [[ ! $is_reality ]]; then err "($is_config_file) 不支持更改密钥."; fi
        if [[ $is_auto ]]; then
            get_pbk
            add $net
        else
            if [[ $is_new_private_key && ! $is_new_public_key ]]; then err "无法找到 Public key."; fi
            if [[ ! $is_new_private_key ]]; then ask string is_new_private_key "请输入新 Private key"; fi
            if [[ ! $is_new_public_key ]]; then ask string is_new_public_key "请输入新 Public key"; fi
            if [[ $is_new_private_key == $is_new_public_key ]]; then err "Private key 和 Public key 不能一样."; fi
            is_tmp_json=$is_conf_dir/$is_config_file-$uuid
            cp -f $is_conf_dir/$is_config_file $is_tmp_json
            sed -i s#$is_private_key #$is_new_private_key# $is_tmp_json
            $is_core_bin check -c $is_tmp_json &>/dev/null
            if [[ $? != 0 ]]; then is_key_err=1; is_key_err_msg="Private key 无法通过测试."; fi
            sed -i s#$is_new_private_key #$is_new_public_key# $is_tmp_json
            $is_core_bin check -c $is_tmp_json &>/dev/null
            if [[ $? != 0 ]]; then is_key_err=1; is_key_err_msg+="Public key 无法通过测试."; fi
            rm $is_tmp_json
            if [[ $is_key_err ]]; then err $is_key_err_msg; fi
            is_private_key=$is_new_private_key
            is_public_key=$is_new_public_key
            is_test_json=
            add $net
        fi
        ;;
    10)
        is_new_servername=$3
        if [[ ! $is_reality ]]; then err "($is_config_file) 不支持更改 serverName."; fi
        if [[ $is_auto ]]; then is_new_servername=$is_random_servername; fi
        if [[ ! $is_new_servername ]]; then ask string is_new_servername "请输入新的 serverName"; fi
        is_servername=$is_new_servername
        add $net
        ;;
    11)
        is_new_proxy_site=$3
        if [[ ! $is_caddy && ! $host ]]; then err "($is_config_file) 不支持更改伪装网站."; fi
        if [[ ! -f $is_caddy_conf/${host}.conf.add ]]; then err "无法配置伪装网站."; fi
        if [[ ! $is_new_proxy_site ]]; then ask string is_new_proxy_site "请输入新的伪装网站 (例如 example.com)"; fi
        proxy_site=$(sed 's#^.*//##;s#/$##' <<<$is_new_proxy_site)
        load caddy.sh
        caddy_config proxy
        manage restart caddy &
        msg "\n已更新伪装网站为: $(_green $proxy_site) \n"
        ;;
    12)
        if [[ ! $is_socks_user ]]; then err "($is_config_file) 不支持更改用户名 (Username)."; fi
        ask string is_socks_user "请输入新用户名 (Username)"
        add $net
        ;;
    esac
}

write_del() {
    is_dont_get_ip=1
    if [[ $is_conf_dir_empty ]]; then
        return
    fi
    if [[ ! $is_config_file ]]; then
        get info $1
    fi
    if [[ $is_config_file ]]; then
        if [[ $is_main_start && ! $is_no_del_msg ]]; then
            msg "\n是否删除配置文件?: $is_config_file"
            pause
        fi
        rm -rf -- "$is_conf_dir/$is_config_file"

        if [[ $is_config_file =~ "CFtunnel" ]]; then
            if [[ $port ]]; then
                systemctl disable --now cftunnel-${port}.service &>/dev/null
                rm -f /lib/systemd/system/cftunnel-${port}.service
                systemctl daemon-reload
                msg "✅ 已清理对应的 CFtunnel 穿透守护服务 (端口: $port)."
            fi
        fi

        if [[ ! $is_new_json ]]; then
            manage restart &
        fi
        if [[ ! $is_no_del_msg ]]; then
            _green "\n已删除: $is_config_file\n"
        fi

        if [[ $is_caddy ]]; then
            is_del_host=$host
            if [[ $is_change ]]; then
                if [[ ! $old_host ]]; then
                    return
                fi
                is_del_host=$old_host
            fi
            if [[ $is_del_host && $host != $old_host && -f $is_caddy_conf/$is_del_host.conf ]]; then
                rm -rf -- "$is_caddy_conf/$is_del_host.conf" "$is_caddy_conf/$is_del_host.conf.add"
                if [[ ! $is_new_json ]]; then
                    manage restart caddy &
                fi
            fi
        fi
    fi
    local conf_files=()
    mapfile -t conf_files < <(list_conf_json_names '.json$')
    if [[ ${#conf_files[@]} -eq 0 && ! $is_change ]]; then
        warn "当前配置目录为空! 因为你刚刚删除了最后一个配置文件."
        is_conf_dir_empty=1
    fi
    unset is_dont_get_ip
    if [[ $is_dont_auto_exit ]]; then
        unset is_config_file
    fi
}

write_add() {
    unset custom_remark
    is_lower=${1,,}
    if [[ $is_lower ]]; then
        case $is_lower in
        ws | tcp | quic | http) is_new_protocol=VMess-${is_lower^^} ;;
        wss | h2 | hu | vws | vh2 | vhu | tws | th2 | thu) is_new_protocol=$(sed -E "s/^V/VLESS-/;s/^T/Trojan-/;/^(W|H)/{s/^/VMess-/};s/WSS/WS/;s/HU/HTTPUpgrade/" <<<${is_lower^^})-TLS ;;
        r | reality) is_new_protocol=VLESS-REALITY ;;
        rh2) is_new_protocol=VLESS-HTTP2-REALITY ;;
        anytls) is_new_protocol=AnyTLS ;;
        cftunnel) is_new_protocol=CFtunnel ;;
        ss) is_new_protocol=Shadowsocks ;;
        door | direct) is_new_protocol=Direct ;;
        tuic) is_new_protocol=TUIC ;;
        hy | hy2 | hysteria*) is_new_protocol=Hysteria2 ;;
        trojan) is_new_protocol=Trojan ;;
        socks) is_new_protocol=Socks ;;
        *)
            for v in ${protocol_list[@]}; do
                if [[ $(grep -E -i "^$is_lower$" <<<$v) ]]; then is_new_protocol=$v; break; fi
            done
            if [[ ! $is_new_protocol ]]; then err "无法识别 ($1), 请使用: $is_core add [protocol] [args... | auto]"; fi
            ;;
        esac
    fi

    if [[ ! $is_new_protocol ]]; then ask set_protocol; fi

    case ${is_new_protocol,,} in
    *-tls)
        is_use_tls=1; is_use_host=$2; is_use_uuid=$3; is_use_path=$4; is_add_opts="[host] [uuid] [/path]" ;;
    vmess* | tuic*)
        is_use_port=$2; is_use_uuid=$3; is_add_opts="[port] [uuid]" ;;
    trojan* | hysteria*)
        is_use_port=$2; is_use_pass=$3; is_add_opts="[port] [password]" ;;
    *reality* | anytls)
        is_reality=1; is_use_port=$2; is_use_uuid=$3; is_use_servername=$4; is_add_opts="[port] [uuid] [sni]" ;;
    cftunnel)
        is_use_port=$2; is_use_uuid=$3; is_use_cf_token=$4; is_add_opts="[port] [uuid] [cf_token]" ;;
    shadowsocks)
        is_use_port=$2; is_use_pass=$3; is_use_method=$4; is_add_opts="[port] [password] [method]" ;;
    direct)
        is_use_port=$2; is_use_door_addr=$3; is_use_door_port=$4; is_add_opts="[port] [remote_addr] [remote_port]" ;;
    socks)
        is_socks=1; is_use_port=$2; is_use_socks_user=$3; is_use_socks_pass=$4; is_add_opts="[port] [username] [password]" ;;
    esac

    if [[ $1 && ! $is_change ]]; then
        msg "\n使用协议: $is_new_protocol"
        is_err_tips="\n\n请使用: $(_green $is_core add $1 $is_add_opts) 来添加 $is_new_protocol 配置"
    fi

    if [[ $is_set_new_protocol ]]; then
        case $is_old_net in
        h2 | ws | httpupgrade)
            old_host=$host
            if [[ ! $is_use_tls ]]; then unset host is_no_auto_tls; fi
            ;;
        reality)
            net_type=
            if [[ ! $(grep -i reality <<<$is_new_protocol) ]]; then is_reality=; fi
            ;;
        ss) if [[ $(is_test uuid $ss_password) ]]; then uuid=$ss_password; fi ;;
        esac
        if [[ ! $(is_test uuid $uuid) ]]; then uuid=; fi
        if [[ $(is_test uuid $password) ]]; then uuid=$password; fi
    fi

    if [[ $is_no_auto_tls && ! $is_use_tls ]]; then err "$is_new_protocol 不支持手动配置 tls."; fi

    if [[ $2 ]]; then
        for v in is_use_port is_use_uuid is_use_host is_use_path is_use_pass is_use_method is_use_door_addr is_use_door_port; do
            if [[ ${!v} == 'auto' ]]; then unset $v; fi
        done

        if [[ $is_use_port ]]; then
            if [[ ! $(is_test port ${is_use_port}) ]]; then err "($is_use_port) 不是一个有效的端口. $is_err_tips"; fi
            if [[ $(is_test port_used $is_use_port) && ! $is_gen ]]; then err "无法使用 ($is_use_port) 端口. $is_err_tips"; fi
            port=$is_use_port
        fi
        if [[ $is_use_door_port ]]; then
            if [[ ! $(is_test port ${is_use_door_port}) ]]; then err "(${is_use_door_port}) 不是一个有效的目标端口. $is_err_tips"; fi
            door_port=$is_use_door_port
        fi
        if [[ $is_use_uuid ]]; then
            if [[ ! $(is_test uuid $is_use_uuid) ]]; then err "($is_use_uuid) 不是一个有效的 UUID. $is_err_tips"; fi
            uuid=$is_use_uuid
        fi
        if [[ $is_use_path ]]; then
            if [[ ! $(is_test path $is_use_path) ]]; then err "($is_use_path) 不是有效的路径. $is_err_tips"; fi
            path=$is_use_path
        fi
        if [[ $is_use_method ]]; then
            is_tmp_use_name=加密方式
            is_tmp_list=${ss_method_list[@]}
            for v in ${is_tmp_list[@]}; do
                if [[ $(grep -E -i "^${is_use_method}$" <<<$v) ]]; then is_tmp_use_type=$v; break; fi
            done
            if [[ ! ${is_tmp_use_type} ]]; then
                warn "(${is_use_method}) 不是一个可用的${is_tmp_use_name}."
                msg "${is_tmp_use_name}可用如下: "
                for v in ${is_tmp_list[@]}; do msg "\t\t$v"; done
                msg "$is_err_tips\n"
                exit 1
            fi
            ss_method=$is_tmp_use_type
        fi
        if [[ $is_use_pass ]]; then ss_password=$is_use_pass; password=$is_use_pass; fi
        if [[ $is_use_host ]]; then host=$is_use_host; fi
        if [[ $is_use_door_addr ]]; then door_addr=$is_use_door_addr; fi
        if [[ $is_use_servername ]]; then is_servername=$is_use_servername; fi
        if [[ $is_use_socks_user ]]; then is_socks_user=$is_use_socks_user; fi
        if [[ $is_use_socks_pass ]]; then is_socks_pass=$is_use_socks_pass; fi
        if [[ $is_use_cf_token ]]; then cf_token=$is_use_cf_token; fi
    fi

    if [[ $is_use_tls ]]; then
        if [[ ! $is_no_auto_tls && ! $is_caddy && ! $is_gen && ! $is_dont_test_host ]]; then
            if [[ $(is_test port_used 80) || $(is_test port_used 443) ]]; then
                get_port; is_http_port=$tmp_port
                get_port; is_https_port=$tmp_port
                warn "端口 (80 或 443) 已经被占用, Caddy 将使用非标准端口实现自动配置 TLS, HTTP:$is_http_port HTTPS:$is_https_port\n"
                msg "请确定是否继续???"
                pause
            fi
            is_install_caddy=1
        fi
        if [[ ! $host ]]; then ask string host "请输入域名"; fi
        get host-test
    else
        if [[ $is_main_start ]]; then
            if [[ ! $port ]]; then
                get_port
                port=$tmp_port
                echo -e "\n--------------------------------------------------------"
                echo -e "端口分配: 已自动为您分配空闲端口 [\e[92m$port\e[0m]"
                echo -e "--------------------------------------------------------"
            fi

            if [[ $is_new_protocol == 'CFtunnel' ]]; then
                if [[ ! $cf_token ]]; then ask string cf_token "请输入 Cloudflare Tunnel Token"; fi
                if [[ ! $cf_domain ]]; then ask string cf_domain "请输入你准备为该节点绑定的 Cloudflare 域名 (例如 node1.example.com)"; fi
            fi

            case ${is_new_protocol,,} in
            socks)
                if [[ ! $is_socks_user ]]; then ask string is_socks_user "请设置用户名"; fi
                if [[ ! $is_socks_pass ]]; then ask string is_socks_pass "请设置密码"; fi
                ;;
            shadowsocks)
                if [[ ! $ss_method ]]; then ask set_ss_method; fi
                if [[ ! $ss_password ]]; then ask string ss_password "请设置密码"; fi
                ;;
            esac
        fi
    fi

    if [[ $is_new_protocol == 'Direct' ]]; then
        if [[ ! $door_addr ]]; then ask string door_addr "请输入目标地址"; fi
        if [[ ! $door_port ]]; then ask string door_port "请输入目标端口"; fi
    fi

    if [[ $(grep 2022 <<<$ss_method) ]]; then
        if [[ $ss_password ]]; then
            is_test_json=1
            create server Shadowsocks
            if [[ ! $tmp_uuid ]]; then get_uuid; fi
            is_test_json_save=$is_conf_dir/tmp-test-$tmp_uuid
            cat <<<"$is_new_json" >$is_test_json_save
            $is_core_bin check -c $is_test_json_save &>/dev/null
            if [[ $? != 0 ]]; then
                warn "Shadowsocks 协议不支持使用当前密码, 脚本将自动创建可用密码:)"
                ss_password=; json_str=
            fi
            is_test_json=
            rm -f $is_test_json_save
        fi
    fi

    if [[ $is_main_start ]]; then
        echo ""
        echo -e "--------------------------------------------------------"
        read -p "请输入该节点的自定义备注 (如留空按回车，则默认使用 luopojunzi): " custom_remark
        if [[ -z "$custom_remark" ]]; then custom_remark="luopojunzi"; fi
        echo -e "--------------------------------------------------------"
    else
        custom_remark="luopojunzi"
    fi

    if [[ $is_install_caddy ]]; then
        _green "\n安装 Caddy 实现自动配置 TLS.\n"
        download caddy
        install_service caddy &>/dev/null
        is_caddy=1
        _green "安装 Caddy 成功.\n"
    fi

    create server $is_new_protocol
    info
}

footer_msg() { ui_footer_msg; }

