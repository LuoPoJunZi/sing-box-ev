#!/bin/bash

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
