#!/bin/bash

query_info() {
    if [[ ! $is_protocol ]]; then get info $1; fi
    is_value_style=$blue
    is_insecure=
    is_quic_add=
    is_type=
    is_tls_pin_profile=
    is_tls_pin_server_name=

    if [[ -z "$custom_remark" ]]; then
        local tmp_name="${is_config_name%.json}"
        local stripped_port="${tmp_name%-[0-9]*}"
        custom_remark="${stripped_port#*-}"
        if [[ -z "$custom_remark" || "$custom_remark" == "$is_protocol" ]]; then
            custom_remark="luopojunzi"
        fi
    fi

    if [[ $is_config_name =~ "CFtunnel" ]]; then
        is_value_style=$magenta
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
                is_value_style=$magenta
                is_can_change=(0 1 2 3 5)
                is_info_show=(0 1 2 3 4 6 7 8)
                if [[ $is_protocol == 'vmess' ]]; then
                    is_vmess_url=$(jq -c "{v:2,ps:\"$custom_remark\",add:\"$is_addr\",port:\"$is_https_port\",id:\"$uuid\",aid:\"0\",net:\"$net\",host:\"$host\",path:\"$path\",tls:\"tls\"}" <<< {})
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
                    net=tcp
                    is_type=http
                    is_tcp_http=1
                    is_info_show+=(5)
                    is_info_str=(${is_info_str[@]/http/tcp http})
                fi
                if [[ $net == "quic" ]]; then
                    is_insecure=1
                    is_tls_pin_profile=vmess-quic
                    is_tls_pin_server_name=$is_addr
                    is_info_show+=(8 9 20)
                    is_info_str+=(tls h3 true)
                    is_quic_add=",tls:\"tls\",alpn:\"h3\""
                fi
                is_vmess_url=$(jq -c "{v:2,ps:\"$custom_remark\",add:\"$is_addr\",port:\"$port\",id:\"$uuid\",aid:\"0\",net:\"$net\",type:\"$is_type\"$is_quic_add}" <<< {})
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
            is_tls_pin_profile=trojan-self-signed
            is_tls_pin_server_name=$is_addr
            is_can_change=(0 1 4)
            is_info_show=(0 1 2 10 4 8 20)
            is_url="$is_protocol://$password@$is_addr:$port?type=tcp&security=tls&allowInsecure=1#$custom_remark"
            is_info_str=($is_protocol $is_addr $port $password tcp tls true)
            ;;
        hy*)
            is_tls_pin_profile=hysteria2
            is_tls_pin_server_name=$is_addr
            is_can_change=(0 1 4)
            is_info_show=(0 1 2 10 8 9 20)
            is_url="$is_protocol://$password@$is_addr:$port?alpn=h3&insecure=1#$custom_remark"
            is_info_str=($is_protocol $is_addr $port $password tls h3 true)
            ;;
        tuic)
            is_insecure=1
            is_tls_pin_profile=tuic
            is_tls_pin_server_name=$is_addr
            is_can_change=(0 1 4 5)
            is_info_show=(0 1 2 3 10 8 9 20 21)
            is_url="$is_protocol://$uuid:$password@$is_addr:$port?alpn=h3&allow_insecure=1&congestion_control=bbr#$custom_remark"
            is_info_str=($is_protocol $is_addr $port $uuid $password tls h3 true bbr)
            ;;
        reality)
            is_value_style=$magenta
            is_can_change=(0 1 5 9 10)
            is_info_show=(0 1 2 3 15 4 8 16 17 18)
            is_flow=xtls-rprx-vision
            is_net_type=tcp
            if [[ $net_type =~ "http" || ${is_new_protocol,,} =~ "http" ]]; then
                is_flow=
                is_net_type=h2
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
        ui_link "$is_url"
        return
    fi

    if [[ $is_dont_show_info || $is_gen || $is_dont_auto_exit ]]; then return; fi

    msg "-------------- $is_config_name -------------"
    for ((i = 0; i < ${#is_info_show[@]}; i++)); do
        a=${info_list[${is_info_show[$i]}]}
        if [[ ${#a} -eq 11 || ${#a} -ge 13 ]]; then tt='\t'; else tt='\t\t'; fi
        msg "$a $tt= $(ui_style "$is_value_style" "${is_info_str[$i]}")"
    done
    if [[ $is_new_install ]]; then warn "首次安装请查看项目文档: $(msg_ul https://github.com/${is_sh_repo})"; fi
    if [[ $is_url ]]; then
        msg "------------- ${info_list[12]} -------------"
        msg "$(ui_link "$is_url")"
        if [[ $is_tls_pin_profile ]]; then
            query_tls_pin_print_snippet "$is_tls_pin_profile" "$is_tls_pin_server_name"
        elif [[ $is_insecure ]]; then
            warn "某些客户端导入URL需手动将跳过证书验证设置为 true"
        fi
    fi
    if [[ $is_no_auto_tls ]]; then
        msg "------------- no-auto-tls INFO -------------"
        msg "端口(port): $port"
        msg "路径(path): $path"
    fi
    footer_msg
}
