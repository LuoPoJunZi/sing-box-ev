#!/bin/bash

runtime_cron_task() {
    msg "\n------------- 自动维护任务 (Cron) -------------"
    msg "注意: 日志清理是保持 VPS 稳定运行的必要选项."
    is_tmp_list=("启用: 自动更新核心 + 自动清空日志 (推荐)" "启用: 仅自动清空日志 (手动更新核心)" "关闭: 停止所有自动维护任务")
    ask list is_do_cron "" "\n请选择自动维护任务:"
    case $REPLY in
        1)
            (
                crontab -l 2> /dev/null | grep -v -E "sing-box update core|/var/log/sing-box"
                echo "0 3 * * 1 /usr/local/bin/sing-box update core >/dev/null 2>&1"
                echo "0 4 * * * echo > /var/log/sing-box/access.log 2>/dev/null; echo > /var/log/sing-box/error.log 2>/dev/null"
            ) | crontab -
            _green "\n已设置: 每周一自动更新核心，每天自动清空日志！(无人值守模式已开启)\n"
            ;;
        2)
            (
                crontab -l 2> /dev/null | grep -v -E "sing-box update core|/var/log/sing-box"
                echo "0 4 * * * echo > /var/log/sing-box/access.log 2>/dev/null; echo > /var/log/sing-box/error.log 2>/dev/null"
            ) | crontab -
            _green "\n已设置: 每天凌晨 04:00 自动清空日志释放硬盘空间。\n"
            ;;
        3)
            crontab -l 2> /dev/null | grep -v -E "sing-box update|/var/log/sing-box" | crontab -
            _green "\n已关闭: 所有 Sing-box 相关的定时维护任务\n"
            ;;
    esac
}
