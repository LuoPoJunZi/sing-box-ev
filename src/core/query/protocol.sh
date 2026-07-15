#!/bin/bash

query_prepare_protocol() {
    get addr
    is_lower=${1,,}
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
            if [[ ! $is_servername ]]; then is_servername=$(domain_pick_for_reality); fi
            if [[ ! $is_servername ]]; then is_servername=$is_random_servername; fi
            if [[ ! $is_private_key ]]; then get_pbk; fi
            get_reality_short_id
            is_json_add="tls:{enabled:true,server_name:\"$is_servername\",reality:{enabled:true,handshake:{server:\"$is_servername\",server_port:443},private_key:\"$is_private_key\",short_id:[\"$is_short_id\"]}}"
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
            if [[ ! $host ]]; then
                net=trojan
                json_str="$is_users,${is_tls_json/alpn\:\[\"h3\"\],/}"
            fi
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
                if [[ $(grep 2022 <<< $ss_method) ]]; then ss_password=$(get ss2022); fi
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
            if [[ ! $is_servername ]]; then is_servername=$(domain_pick_for_reality); fi
            if [[ ! $is_servername ]]; then is_servername=$is_random_servername; fi
            if [[ ! $is_private_key ]]; then get_pbk; fi
            get_reality_short_id
            is_json_add="tls:{enabled:true,server_name:\"$is_servername\",reality:{enabled:true,handshake:{server:\"$is_servername\",server_port:443},private_key:\"$is_private_key\",short_id:[\"$is_short_id\"]}}"
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
}
