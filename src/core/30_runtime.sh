#!/bin/bash

runtime_manage() {
    if [[ $is_dont_auto_exit ]]; then return; fi
    case $1 in
    1 | start) is_do=start; is_do_msg=启动; is_test_run=1 ;;
    2 | stop) is_do=stop; is_do_msg=停止 ;;
    3 | r | restart) is_do=restart; is_do_msg=重启; is_test_run=1 ;;
    *) is_do=$1; is_do_msg=$1 ;;
    esac
    case $2 in
    caddy) is_do_name=$2; is_run_bin=$is_caddy_bin; is_do_name_msg=Caddy ;;
    *) is_do_name=$is_core; is_run_bin=$is_core_bin; is_do_name_msg=$is_core_name ;;
    esac

    systemctl $is_do $is_do_name

    if [[ $is_test_run && ! $is_new_install ]]; then
        sleep 2
        if [[ ! $(pgrep -f $is_run_bin) ]]; then
            is_run_fail=${is_do_name_msg,,}
            if [[ ! $is_no_manage_msg ]]; then
                msg
                warn "($is_do_msg) $is_do_name_msg 失败"
                _yellow "检测到运行失败, 自动执行测试运行."
                get test-run
                _yellow "测试结束, 请按 Enter 退出."
            fi
        fi
    fi
}

runtime_cron_task() {
    msg "\n------------- 自动维护任务 (Cron) -------------"
    msg "注意: 日志清理是保持 VPS 稳定运行的必要选项."
    msg "1. 启用: 自动更新核心 + 自动清空日志 (推荐)"
    msg "2. 启用: 仅自动清空日志 (手动更新核心)"
    msg "3. 关闭: 停止所有自动维护任务"
    ask list is_do_cron ""
    case $REPLY in
    1)
        (crontab -l 2>/dev/null | grep -v -E "sing-box update core|/var/log/sing-box"; echo "0 3 * * 1 /usr/local/bin/sing-box update core >/dev/null 2>&1"; echo "0 4 * * * echo > /var/log/sing-box/access.log 2>/dev/null; echo > /var/log/sing-box/error.log 2>/dev/null") | crontab -
        _green "\n已设置: 每周一自动更新核心，每天自动清空日志！(无人值守模式已开启)\n"
        ;;
    2)
        (crontab -l 2>/dev/null | grep -v -E "sing-box update core|/var/log/sing-box"; echo "0 4 * * * echo > /var/log/sing-box/access.log 2>/dev/null; echo > /var/log/sing-box/error.log 2>/dev/null") | crontab -
        _green "\n已设置: 每天凌晨 04:00 自动清空日志释放硬盘空间。\n"
        ;;
    3)
        crontab -l 2>/dev/null | grep -v -E "sing-box update|/var/log/sing-box" | crontab -
        _green "\n已关闭: 所有 Sing-box 相关的定时维护任务\n"
        ;;
    esac
}
