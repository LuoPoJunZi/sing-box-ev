#!/bin/bash

query_get() {
    case $1 in
    addr)
        is_addr=$host
        if [[ ! $is_addr ]]; then
            get_ip
            is_addr=$ip
            if [[ $(grep ":" <<<$ip) ]]; then is_addr="[$ip]"; fi
        fi
        ;;
    new)
        if [[ ! $host ]]; then get_ip; fi
        if [[ ! $port ]]; then get_port; port=$tmp_port; fi
        if [[ ! $uuid ]]; then get_uuid; uuid=$tmp_uuid; fi
        ;;
    file)
        is_file_str=$2
        if [[ ! $is_file_str ]]; then is_file_str='.json$'; fi
        mapfile -t is_all_json < <(list_conf_json_names "$is_file_str")
        if [[ ! $is_all_json ]]; then err "无法找到相关的配置文件: $2"; fi
        if [[ ${#is_all_json[@]} -eq 1 ]]; then
            is_config_file=$is_all_json
            is_auto_get_config=1
        fi
        if [[ ! $is_config_file ]]; then
            if [[ $is_dont_auto_exit ]]; then return; fi
            ask get_config_file
        fi
        ;;
    info)
        get file $2
        if [[ $is_config_file ]]; then
            is_json_str=$(cat $is_conf_dir/"$is_config_file" | sed s#//.*##)
            is_json_data=$(jq '(.inbounds[0]|.type,.listen_port,(.users[0]|.uuid,.password,.username),.method,.password,.override_port,.override_address,(.transport|.type,.path,.headers.host),(.tls|.server_name,.reality.private_key)),(.outbounds[1].tag)' <<<$is_json_str)
            if [[ $? != 0 ]]; then err "无法读取此文件: $is_config_file"; fi
            is_up_var_set=(null is_protocol port uuid password username ss_method ss_password door_port door_addr net_type path host is_servername is_private_key is_public_key)
            if [[ $is_debug ]]; then msg "\n------------- debug: $is_config_file -------------"; fi
            i=0
            local json_items=()
            mapfile -t json_items < <(sed 's/""/null/g;s/"//g' <<<"$is_json_data")
            for v in "${json_items[@]}"; do
                ((i++))
                if [[ $is_debug ]]; then msg "$i-${is_up_var_set[$i]}: $v"; fi
                export ${is_up_var_set[$i]}="${v}"
            done
            for v in ${is_up_var_set[@]}; do
                if [[ ${!v} == 'null' ]]; then unset $v; fi
            done

            if [[ $is_private_key ]]; then
                is_reality=1
                net_type+=reality
                is_public_key=${is_public_key/public_key_/}
            fi
            is_socks_user=$username
            is_socks_pass=$password
            is_config_name=$is_config_file

            if [[ $is_caddy && $host && -f $is_caddy_conf/$host.conf ]]; then
                is_tmp_https_port=$(grep -E -o "$host:[1-9][0-9]?+" $is_caddy_conf/$host.conf | sed s/.*://)
            fi
            if [[ $host && ! -f $is_caddy_conf/$host.conf ]]; then is_no_auto_tls=1; fi
            if [[ $is_tmp_https_port ]]; then is_https_port=$is_tmp_https_port; fi
            if [[ $is_client && $host ]]; then port=$is_https_port; fi
            get protocol $is_protocol-$net_type
        fi
        ;;
    protocol)
        get addr
        is_lower=${2,,}
        net=
        is_users="users:[{uuid:\"$uuid\"}]"
        is_tls_json='tls:{enabled:true,alpn:["h3"],key_path:"'$is_tls_key'",certificate_path:"'$is_tls_cer'"}'
        case $is_lower in
        vmess*)
            is_protocol=vmess
            if [[ $is_lower =~ "tcp" || ! $net_type && $is_up_var_set ]]; then
                net=tcp
                json_str=$is_users
            fi
            ;;
        vless*) is_protocol=vless ;;
        anytls)
            is_protocol=vless
            net=reality
            if [[ ! $is_servername ]]; then is_servername=$is_random_servername; fi
            if [[ ! $is_private_key ]]; then get_pbk; fi
            is_json_add="tls:{enabled:true,server_name:\"$is_servername\",reality:{enabled:true,handshake:{server:\"$is_servername\",server_port:443},private_key:\"$is_private_key\",short_id:[\"\"]}}"
            is_users=${is_users/uuid/flow:\"xtls-rprx-vision\",uuid}
            json_str="$is_users,$is_json_add"
            ;;
        cftunnel)
            is_protocol=vless
            net=ws
            if [[ $cf_domain ]]; then host="$cf_domain"; else host="你的CF绑定域名(需修改)"; fi
            if [[ ! $path ]]; then path="/$uuid"; fi
            is_path_host_json=",path:\"$path\",headers:{host:\"$host\"}"
            is_json_add="transport:{type:\"$net\"$is_path_host_json,early_data_header_name:\"Sec-WebSocket-Protocol\"}"
            json_str="$is_users,$is_json_add"
            ;;
        tuic*)
            net=tuic
            is_protocol=$net
            if [[ ! $password ]]; then password=$uuid; fi
            is_users="users:[{uuid:\"$uuid\",password:\"$password\"}]"
            json_str="$is_users,congestion_control:\"bbr\",$is_tls_json"
            ;;
        trojan*)
            is_protocol=trojan
            if [[ ! $password ]]; then password=$uuid; fi
            is_users="users:[{password:\"$password\"}]"
            if [[ ! $host ]]; then net=trojan; json_str="$is_users,${is_tls_json/alpn\:\[\"h3\"\],/}"; fi
            ;;
        hysteria2*)
            net=hysteria2
            is_protocol=$net
            if [[ ! $password ]]; then password=$uuid; fi
            json_str="users:[{password:\"$password\"}],$is_tls_json"
            ;;
        shadowsocks*)
            net=ss
            is_protocol=shadowsocks
            if [[ ! $ss_method ]]; then ss_method=$is_random_ss_method; fi
            if [[ ! $ss_password ]]; then
                ss_password=$uuid
                if [[ $(grep 2022 <<<$ss_method) ]]; then ss_password=$(get ss2022); fi
            fi
            json_str="method:\"$ss_method\",password:\"$ss_password\""
            ;;
        direct*)
            net=direct
            is_protocol=$net
            json_str="override_port:$door_port,override_address:\"$door_addr\""
            ;;
        socks*)
            net=socks
            is_protocol=$net
            if [[ ! $is_socks_user ]]; then is_socks_user=luopojunzi; fi
            if [[ ! $is_socks_pass ]]; then is_socks_pass=$uuid; fi
            json_str="users:[{username: \"$is_socks_user\", password: \"$is_socks_pass\"}]"
            ;;
        *) err "无法识别协议: $is_config_file" ;;
        esac
        if [[ $net ]]; then return; fi
        if [[ $host && $is_lower =~ "tls" ]]; then
            if [[ ! $path ]]; then path="/$uuid"; fi
            is_path_host_json=",path:\"$path\",headers:{host:\"$host\"}"
        fi
        case $is_lower in
        *quic*)
            net=quic
            is_json_add="$is_tls_json,transport:{type:\"$net\"}"
            ;;
        *ws*)
            net=ws
            is_json_add="transport:{type:\"$net\"$is_path_host_json,early_data_header_name:\"Sec-WebSocket-Protocol\"}"
            ;;
        *reality*)
            net=reality
            if [[ ! $is_servername ]]; then is_servername=$is_random_servername; fi
            if [[ ! $is_private_key ]]; then get_pbk; fi
            is_json_add="tls:{enabled:true,server_name:\"$is_servername\",reality:{enabled:true,handshake:{server:\"$is_servername\",server_port:443},private_key:\"$is_private_key\",short_id:[\"\"]}}"
            if [[ $is_lower =~ "http" ]]; then
                is_json_add="$is_json_add,transport:{type:\"http\"}"
            else
                is_users=${is_users/uuid/flow:\"xtls-rprx-vision\",uuid}
            fi
            ;;
        *http* | *h2*)
            net=http
            if [[ $is_lower =~ "up" ]]; then net=httpupgrade; fi
            is_json_add="transport:{type:\"$net\"$is_path_host_json}"
            if [[ $is_lower =~ "h2" || ! $is_lower =~ "httpupgrade" && $host ]]; then
                net=h2
                is_json_add="${is_tls_json/alpn\:\[\"h3\"\],/},$is_json_add"
            fi
            ;;
        esac
        json_str="$is_users,$is_json_add"
        ;;
    host-test)
        if [[ $is_no_auto_tls || $is_gen || $is_dont_test_host ]]; then return; fi
        get_ip
        get ping
        if [[ ! $(grep $ip <<<$is_host_dns) ]]; then
            msg "\n请将 ($(_red_bg $host)) 解析到 ($(_red_bg $ip))"
            msg "\n如果使用 Cloudflare, 在 DNS 那; 关闭 (Proxy status / 代理状态), 即是 (DNS only / 仅限 DNS)"
            ask string y "我已经确定解析 [y]:"
            get ping
            if [[ ! $(grep $ip <<<$is_host_dns) ]]; then
                _cyan "\n测试结果: $is_host_dns"
                err "域名 ($host) 没有解析到 ($ip)"
            fi
        fi
        ;;
    ssss | ss2022)
        if [[ $(grep 128 <<<$ss_method) ]]; then
            $is_core_bin generate rand 16 --base64
        else
            $is_core_bin generate rand 32 --base64
        fi
        ;;
    ping)
        is_dns_type="a"
        if [[ $(grep ":" <<<$ip) ]]; then is_dns_type="aaaa"; fi
        is_host_dns=$(_wget -qO- --header="accept: application/dns-json" "https://one.one.one.one/dns-query?name=$host&type=$is_dns_type")
        ;;
    install-caddy)
        _green "\n安装 Caddy 实现自动配置 TLS.\n"
        download caddy
        install_service caddy &>/dev/null
        is_caddy=1
        _green "安装 Caddy 成功.\n"
        ;;
    reinstall)
        is_install_sh=$(cat $is_sh_dir/install.sh)
        uninstall
        bash <<<$is_install_sh
        ;;
    test-run)
        systemctl list-units --full -all &>/dev/null
        if [[ $? != 0 ]]; then
            _yellow "\n无法执行测试, 请检查 systemctl 状态.\n"
            return
        fi
        is_no_manage_msg=1
        if [[ ! $(pgrep -f $is_core_bin) ]]; then
            _yellow "\n测试运行 $is_core_name ..\n"
            manage start &>/dev/null
            if [[ $is_run_fail == $is_core ]]; then
                _red "$is_core_name 运行失败信息:"
                $is_core_bin run -c $is_config_json -C $is_conf_dir
            else
                _green "\n测试通过, 已启动 $is_core_name ..\n"
            fi
        else
            _green "\n$is_core_name 正在运行, 跳过测试\n"
        fi
        if [[ $is_caddy ]]; then
            if [[ ! $(pgrep -f $is_caddy_bin) ]]; then
                _yellow "\n测试运行 Caddy ..\n"
                manage start caddy &>/dev/null
                if [[ $is_run_fail == 'caddy' ]]; then
                    _red "Caddy 运行失败信息:"
                    $is_caddy_bin run --config $is_caddyfile
                else
                    _green "\n测试通过, 已启动 Caddy ..\n"
                fi
            else
                _green "\nCaddy 正在运行, 跳过测试\n"
            fi
        fi
        ;;
    esac
}

query_info() {
    if [[ ! $is_protocol ]]; then get info $1; fi
    is_color=44

    if [[ -z "$custom_remark" ]]; then
        local tmp_name="${is_config_name%.json}"
        local stripped_port="${tmp_name%-[0-9]*}"
        custom_remark="${stripped_port#*-}"
        if [[ -z "$custom_remark" || "$custom_remark" == "$is_protocol" ]]; then
            custom_remark="luopojunzi"
        fi
    fi

    if [[ $is_config_name =~ "CFtunnel" ]]; then
        is_color=45
        is_can_change=(0 2 5)
        is_info_show=(0 1 2 3 4 6 7 8)
        is_info_str=(vless "$host" "443" $uuid ws "$host" "$path" tls)
        is_url="vless://$uuid@$host:443?encryption=none&security=tls&type=ws&host=$host&path=$path#$custom_remark"
        net="cftunnel_handled"
    fi

    if [[ $is_config_name =~ "AnyTLS" ]]; then net="reality"; fi

    case $net in
    ws | tcp | h2 | quic | http*)
        if [[ $host ]]; then
            is_color=45
            is_can_change=(0 1 2 3 5)
            is_info_show=(0 1 2 3 4 6 7 8)
            if [[ $is_protocol == 'vmess' ]]; then
                is_vmess_url=$(jq -c "{v:2,ps:\"$custom_remark\",add:\"$is_addr\",port:\"$is_https_port\",id:\"$uuid\",aid:\"0\",net:\"$net\",host:\"$host\",path:\"$path\",tls:\"tls\"}" <<<{})
                is_url=vmess://$(echo -n $is_vmess_url | base64 -w 0)
            else
                if [[ $is_protocol == "trojan" ]]; then
                    uuid=$password
                    is_can_change=(0 1 2 3 4)
                    is_info_show=(0 1 2 10 4 6 7 8)
                fi
                is_url="$is_protocol://$uuid@$is_addr:$is_https_port?encryption=none&security=tls&type=$net&host=$host&path=$path#$custom_remark"
            fi
            if [[ $is_caddy ]]; then is_can_change+=(11); fi
            is_info_str=($is_protocol $is_addr $is_https_port $uuid $net $host $path 'tls')
        else
            is_type=none
            is_can_change=(0 1 5)
            is_info_show=(0 1 2 3 4)
            is_info_str=($is_protocol $is_addr $port $uuid $net)
            if [[ $net == "http" ]]; then
                net=tcp; is_type=http; is_tcp_http=1
                is_info_show+=(5)
                is_info_str=(${is_info_str[@]/http/tcp http})
            fi
            if [[ $net == "quic" ]]; then
                is_insecure=1
                is_info_show+=(8 9 20)
                is_info_str+=(tls h3 true)
                is_quic_add=",tls:\"tls\",alpn:\"h3\""
            fi
            is_vmess_url=$(jq -c "{v:2,ps:\"$custom_remark\",add:\"$is_addr\",port:\"$port\",id:\"$uuid\",aid:\"0\",net:\"$net\",type:\"$is_type\"$is_quic_add}" <<<{})
            is_url=vmess://$(echo -n $is_vmess_url | base64 -w 0)
        fi
        ;;
    ss)
        is_can_change=(0 1 4 6)
        is_info_show=(0 1 2 10 11)
        is_url="ss://$(echo -n ${ss_method}:${ss_password} | base64 -w 0)@${is_addr}:${port}#$custom_remark"
        is_info_str=($is_protocol $is_addr $port $ss_password $ss_method)
        ;;
    trojan)
        is_insecure=1
        is_can_change=(0 1 4)
        is_info_show=(0 1 2 10 4 8 20)
        is_url="$is_protocol://$password@$is_addr:$port?type=tcp&security=tls&allowInsecure=1#$custom_remark"
        is_info_str=($is_protocol $is_addr $port $password tcp tls true)
        ;;
    hy*)
        is_can_change=(0 1 4)
        is_info_show=(0 1 2 10 8 9 20)
        is_url="$is_protocol://$password@$is_addr:$port?alpn=h3&insecure=1#$custom_remark"
        is_info_str=($is_protocol $is_addr $port $password tls h3 true)
        ;;
    tuic)
        is_insecure=1
        is_can_change=(0 1 4 5)
        is_info_show=(0 1 2 3 10 8 9 20 21)
        is_url="$is_protocol://$uuid:$password@$is_addr:$port?alpn=h3&allow_insecure=1&congestion_control=bbr#$custom_remark"
        is_info_str=($is_protocol $is_addr $port $uuid $password tls h3 true bbr)
        ;;
    reality)
        is_color=41
        is_can_change=(0 1 5 9 10)
        is_info_show=(0 1 2 3 15 4 8 16 17 18)
        is_flow=xtls-rprx-vision
        is_net_type=tcp
        if [[ $net_type =~ "http" || ${is_new_protocol,,} =~ "http" ]]; then
            is_flow=; is_net_type=h2
            is_info_show=(${is_info_show[@]/15/})
        fi
        is_info_str=($is_protocol $is_addr $port $uuid $is_flow $is_net_type reality $is_servername chrome $is_public_key)
        is_url="$is_protocol://$uuid@$is_addr:$port?encryption=none&security=reality&flow=$is_flow&type=$is_net_type&sni=$is_servername&pbk=$is_public_key&fp=chrome#$custom_remark"
        ;;
    direct)
        is_can_change=(0 1 7 8)
        is_info_show=(0 1 2 13 14)
        is_info_str=($is_protocol $is_addr $port $door_addr $door_port)
        ;;
    socks)
        is_can_change=(0 1 12 4)
        is_info_show=(0 1 2 19 10)
        is_info_str=($is_protocol $is_addr $port $is_socks_user $is_socks_pass)
        is_url="socks://$(echo -n ${is_socks_user}:${is_socks_pass} | base64 -w 0)@${is_addr}:${port}#$custom_remark"
        ;;
    esac

    if [[ $is_show_all ]]; then
        echo -e "\e[93m[${is_config_name}]\e[0m 协议: \e[96m${is_protocol}\e[0m | 端口: \e[92m${port}\e[0m"
        echo -e "\e[4;${is_color}m${is_url}\e[0m"
        echo -e "\e[90m-----------------------------------------------------\e[0m"
        return
    fi

    if [[ $is_dont_show_info || $is_gen || $is_dont_auto_exit ]]; then return; fi

    msg "-------------- $is_config_name -------------"
    for ((i = 0; i < ${#is_info_show[@]}; i++)); do
        a=${info_list[${is_info_show[$i]}]}
        if [[ ${#a} -eq 11 || ${#a} -ge 13 ]]; then tt='\t'; else tt='\t\t'; fi
        msg "$a $tt= \e[${is_color}m${is_info_str[$i]}\e[0m"
    done
    if [[ $is_new_install ]]; then warn "首次安装请查看项目文档: $(msg_ul https://github.com/${is_sh_repo})"; fi
    if [[ $is_url ]]; then
        msg "------------- ${info_list[12]} -------------"
        msg "\e[4;${is_color}m${is_url}\e[0m"
        if [[ $is_insecure ]]; then warn "某些客户端导入URL需手动将跳过证书验证设置为 true"; fi
    fi
    if [[ $is_no_auto_tls ]]; then
        msg "------------- no-auto-tls INFO -------------"
        msg "端口(port): $port"
        msg "路径(path): $path"
    fi
    footer_msg
}

query_show_all_nodes() {
    is_dont_auto_exit=1
    is_show_all=1
    clear
    echo -e "\e[96m=====================================================\e[0m"
    echo -e "              Sing-box-EV 节点配置总览"
    echo -e "\e[96m=====================================================\e[0m\n"

    local config_count=0
    local conf_files=()
    mapfile -t conf_files < <(list_conf_json_names '.json$')
    for v in "${conf_files[@]}"; do
        ((config_count++))
        unset is_protocol port uuid password net is_url custom_remark is_json_str
        get info "$v" > /dev/null 2>&1
        info "$v"
    done

    if [[ $config_count -eq 0 ]]; then
        echo -e " \e[91m目前没有找到任何节点配置，请先添加配置。\e[0m\n"
    else
        echo -e "\n \e[92m共为您列出 $config_count 个节点链接，请直接复制上方链接使用。\e[0m\n"
    fi

    is_show_all=
    is_dont_auto_exit=
    pause
}

query_url_qr() {
    is_dont_show_info=1
    info "$2"
    if [[ $is_url ]]; then
        if [[ $1 == 'url' ]]; then
            msg "\n------------- $is_config_name & URL 链接 -------------"
            msg "\n\e[${is_color}m${is_url}\e[0m\n"
            footer_msg
        else
            link="https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=${is_url}"
            msg "\n------------- $is_config_name & QR code 二维码 -------------"
            msg
            if [[ $(type -P qrencode) ]]; then
                qrencode -t ANSI "${is_url}"
            else
                msg "请安装 qrencode: $(_green "$cmd update -y; $cmd install qrencode -y")"
            fi
            msg "\n如果终端无法正常显示二维码, 请复制以下链接到浏览器打开生成:"
            msg "\n\e[4;${is_color}m${link}\e[0m\n"
            footer_msg
        fi
    else
        if [[ $1 == 'url' ]]; then err "($is_config_name) 无法生成 URL 链接."; else err "($is_config_name) 无法生成 QR code 二维码."; fi
    fi
}



