#!/bin/bash

ui_msg() { echo -e "$@"; }

ui_msg_ul() { echo -e "\e[4m$@\e[0m"; }

ui_pause() {
    echo
    echo -ne "按 $(_green Enter 回车键) 继续, 或按 $(_red Ctrl + C) 取消."
    read -rs -d $'\n'
    echo
}

ui_show_list() {
    PS3=''
    COLUMNS=1
    select i in "$@"; do echo; done &
    wait
}

ui_footer_msg() {
    if [[ $is_core_stop && ! $is_new_json ]]; then warn "$is_core_name 当前处于停止状态."; fi
    if [[ $is_caddy_stop && $host ]]; then warn "Caddy 当前处于停止状态."; fi
    msg "------------- END -------------"
    msg "项目(Github): $(msg_ul https://github.com/${is_sh_repo})"
    msg
}
