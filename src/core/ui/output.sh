#!/bin/bash

ui_msg() { echo -e "$@"; }

ui_msg_ul() { ui_link "$@"; }

ui_hr() { ui_brand "====================================================="; }

ui_divider() { ui_muted "-----------------------------------------------------"; }

ui_section() { ui_warn "$@"; }

ui_option_num() { ui_key "($1)"; }

ui_range() { ui_error "$@"; }

ui_cancel_msg() { ui_warn "已安全取消当前操作，正在返回主面板..."; }

ui_pause() {
    echo
    echo -ne "按 $(_green Enter 回车键) 继续, 或按 $(_red Ctrl + C) 取消."
    read -rs -d $'\n'
    echo
}

ui_show_list() {
    local index=1 item
    for item in "$@"; do
        if [[ $index -lt 10 ]]; then
            echo "($index)  $item"
        else
            echo "($index) $item"
        fi
        ((index++))
    done
    echo
}

ui_footer_msg() {
    if [[ $is_core_stop && ! $is_new_json ]]; then warn "$is_core_name 当前处于停止状态."; fi
    if [[ $is_caddy_stop && $host ]]; then warn "Caddy 当前处于停止状态."; fi
    msg "------------- END -------------"
    msg "项目(Github): $(msg_ul https://github.com/${is_sh_repo})"
    msg
}
