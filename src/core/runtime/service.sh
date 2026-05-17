#!/bin/bash

runtime_manage() {
    if [[ $is_dont_auto_exit ]]; then return; fi
    case $1 in
        1 | start)
            is_do=start
            is_do_msg=启动
            is_test_run=1
            ;;
        2 | stop)
            is_do=stop
            is_do_msg=停止
            ;;
        3 | r | restart)
            is_do=restart
            is_do_msg=重启
            is_test_run=1
            ;;
        *)
            is_do=$1
            is_do_msg=$1
            ;;
    esac
    case $2 in
        caddy)
            is_do_name=$2
            is_run_bin=$is_caddy_bin
            is_do_name_msg=Caddy
            ;;
        *)
            is_do_name=$is_core
            is_run_bin=$is_core_bin
            is_do_name_msg=$is_core_name
            ;;
    esac

    if [[ $is_dry_run ]]; then
        msg "DRY-RUN: 将执行 systemctl $is_do $is_do_name"
        return
    fi

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
