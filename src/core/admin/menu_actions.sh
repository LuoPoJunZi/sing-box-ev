#!/bin/bash

admin_menu_run() {
    admin_dispatch_command "$@"
}

admin_menu_run_service_action() {
    case $1 in
        1) admin_menu_run start ;;
        2) admin_menu_run stop ;;
        3) admin_menu_run restart ;;
    esac
}

admin_menu_run_update_action() {
    case $1 in
        1) admin_menu_run update core ;;
        2) admin_menu_run update sh ;;
        3) admin_menu_run update caddy ;;
    esac
}

admin_menu_run_advanced_action() {
    case $1 in
        1) admin_menu_run sub ;;
        2) admin_menu_run all ;;
        3) admin_menu_run bbr ;;
        4) admin_menu_run log ;;
        5) admin_menu_run test ;;
        6) admin_menu_run reinstall ;;
        7) admin_menu_run dns ;;
        8)
            is_tmp_list=("更新$is_core_name" "更新脚本")
            if [[ $is_caddy ]]; then is_tmp_list+=("更新Caddy"); fi
            ask list is_do_update "" "\n请选择手动更新:"
            admin_menu_run_update_action "$REPLY"
            ;;
        9) admin_menu_run doctor ;;
        10) admin_menu_run backup list ;;
        11) admin_menu_run backup create manual-menu ;;
        12) admin_menu_run rollback ;;
    esac
}

admin_menu_run_main_action() {
    case $1 in
        1) admin_menu_run add ;;
        2) admin_menu_run change ;;
        3) admin_menu_run info ;;
        4) admin_menu_run del ;;
        5)
            ask list is_do_manage "启动 停止 重启" "" "\n请选择系统服务状态:"
            admin_menu_run_service_action "$REPLY"
            msg "\n管理状态执行: $(_green $is_do_manage)\n"
            ;;
        6) admin_menu_run cron ;;
        7) admin_menu_run uninstall ;;
        8)
            msg
            admin_menu_run help
            ;;
        9)
            ask list is_do_other "节点订阅(Sub) 一键查看所有节点信息 启用BBR 查看日志 测试运行 重装脚本 设置DNS 手动更新 系统诊断(doctor) 查看快照列表 手动创建快照 回滚快照" "" "\n请选择进阶工具:"
            admin_menu_run_advanced_action "$REPLY"
            ;;
        10) admin_menu_run about ;;
    esac
}
