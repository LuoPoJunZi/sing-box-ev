#!/bin/bash

admin_update() {
    case $1 in
    1 | core | $is_core)
        is_update_name=core
        is_show_name=$is_core_name
        is_run_ver=v${is_core_ver##* }
        ;;
    2 | sh)
        is_update_name=sh
        is_show_name="$is_core_name 脚本"
        is_run_ver=$is_sh_ver
        ;;
    3 | caddy)
        if [[ ! $is_caddy ]]; then err "不支持更新 Caddy."; fi
        is_update_name=caddy
        is_show_name="Caddy"
        is_run_ver=$is_caddy_ver
        ;;
    *)
        err "无法识别 ($1), 请使用: $is_core update [core | sh | caddy] [ver]"
        ;;
    esac

    if [[ $2 ]]; then is_new_ver=v${2#v}; fi

    if [[ $is_run_ver == $is_new_ver ]]; then
        msg "\n自定义版本和当前 $is_show_name 版本一样, 无需更新.\n"
        exit
    fi

    if [[ $is_new_ver ]]; then
        msg "\n使用自定义版本更新 $is_show_name: $(_green $is_new_ver)\n"
    else
        get_latest_version $is_update_name
        if [[ $is_run_ver == $latest_ver ]]; then
            msg "\n$is_show_name 当前已经是最新版本了.\n"
            exit
        fi
        msg "\n发现 $is_show_name 新版本: $(_green $latest_ver)\n"
        is_new_ver=$latest_ver
    fi

    download $is_update_name $is_new_ver
    msg "更新成功, 当前 $is_show_name 版本: $(_green $is_new_ver)\n"

    if [[ $is_update_name != 'sh' ]]; then
        manage restart $is_update_name &
    fi
}

admin_uninstall() {
    snapshot_ensure "pre-uninstall"

    if [[ $is_caddy ]]; then
        is_tmp_list=("卸载 $is_core_name" "卸载 ${is_core_name} & Caddy")
        ask list is_do_uninstall "" "\n请选择卸载:"
    else
        ask string y "是否卸载 ${is_core_name}? [y]: "
    fi

    if [[ $is_dry_run ]]; then
        msg "\nDRY-RUN: 将卸载 $is_core_name 及相关服务/目录（未实际执行）\n"
        return
    fi

    manage stop &>/dev/null
    manage disable &>/dev/null
    crontab -l 2>/dev/null | grep -v -E "sing-box update|/var/log/sing-box" | crontab -

    rm -rf -- "$is_core_dir" "$is_log_dir" "$is_sh_bin" "${is_sh_bin/$is_core/sb}" "/lib/systemd/system/$is_core.service"
    sed -i "/$is_core/d" /root/.bashrc

    if [[ $REPLY == '2' ]]; then
        manage stop caddy &>/dev/null
        manage disable caddy &>/dev/null
        rm -rf -- "$is_caddy_dir" "$is_caddy_bin" "/lib/systemd/system/caddy.service"
    fi
    if [[ $is_install_sh ]]; then return; fi

    _green "\n卸载完成!"
    msg "脚本哪里需要完善? 请反馈: $(msg_ul https://github.com/${is_sh_repo}/issues)\n"
}

admin_is_main_menu() {
    is_main_start=1
    while :; do
        clear
        echo -e "\e[96m=====================================================\e[0m"
        echo -e "\e[96m          Sing-box-EV 魔改管理面板 $is_sh_ver\e[0m"
        echo -e "\e[96m=====================================================\e[0m"

        local caddy_show=""
        if [[ $is_caddy ]]; then
            caddy_show=" | Caddy: ${is_caddy_status}"
        fi
        echo -e "  [状态] Core: ${is_core_ver} (${is_core_status})${caddy_show}"
        echo -e "\e[90m-----------------------------------------------------\e[0m"

        echo -e "  \e[93m◈ 节点管理\e[0m"
        echo -e "    \e[92m(1)\e[0m 添加配置        \e[92m(2)\e[0m 更改配置"
        echo -e "    \e[92m(3)\e[0m 查看单节点      \e[92m(4)\e[0m 删除配置\n"

        echo -e "  \e[93m◈ 系统控制\e[0m"
        echo -e "    \e[92m(5)\e[0m 启动/停止       \e[92m(6)\e[0m 自动更新/清理"
        echo -e "    \e[92m(7)\e[0m 完全卸载        \e[92m(8)\e[0m 帮助文档\n"

        echo -e "  \e[93m◈ 高级工具\e[0m"
        echo -e "    \e[92m(9)\e[0m 进阶选项       \e[92m(10)\e[0m 关于本脚本"
        echo -e "    \e[92m(0)\e[0m 退出面板"
        echo -e "\e[90m-----------------------------------------------------\e[0m"

        echo -ne "➡️ 请输入对应的数字进行操作 [\e[91m0-10\e[0m]: "
        read REPLY

        if [[ ! $REPLY ]]; then continue; fi
        if [[ "$REPLY" == "0" ]]; then exit; fi
        if [[ "$REPLY" =~ ^([1-9]|10)$ ]]; then break; fi
        echo -e "\e[31m输入错误, 请输入 0-10 之间的数字\e[0m"
        sleep 1
    done

    case $REPLY in
    1) add ;;
    2) change ;;
    3) info ;;
    4) del ;;
    5)
        ask list is_do_manage "启动 停止 重启" "" "\n请选择系统服务状态:"
        manage $REPLY &
        msg "\n管理状态执行: $(_green $is_do_manage)\n"
        ;;
    6) cron_task ;;
    7) uninstall ;;
    8)
        msg
        load help.sh
        show_help
        ;;
    9)
        ask list is_do_other "节点订阅(Sub) 一键查看所有节点信息 启用BBR 查看日志 测试运行 重装脚本 设置DNS 手动更新 系统诊断(doctor) 查看快照列表 手动创建快照 回滚快照" "" "\n请选择进阶工具:"
        case $REPLY in
        1) gen_sub ;;
        2) show_all_nodes ;;
        3) _try_enable_bbr ;;
        4) log_set ;;
        5) get test-run ;;
        6) get reinstall ;;
        7) dns_set ;;
        8)
            is_tmp_list=("更新$is_core_name" "更新脚本")
            if [[ $is_caddy ]]; then is_tmp_list+=("更新Caddy"); fi
            ask list is_do_update "" "\n请选择手动更新:"
            update $REPLY
            ;;
        9) doctor ;;
        10) backup_list ;;
        11) unset is_snapshot_id; snapshot_ensure "manual-menu" ;;
        12) rollback ;;
        esac
        ;;
    10)
        load help.sh
        about
        ;;
    esac
}

admin_main() {
    if [[ $1 == 'dry-run' || $1 == '--dry-run' || $1 == 'drun' ]]; then
        is_dry_run=1
        shift
        if [[ ! $1 ]]; then
            err "请使用: sb dry-run <command> [args...]"
        fi
        msg "\n已启用 DRY-RUN 模式，本次不会执行写入或服务变更.\n"
    fi

    case $1 in
    a | add | gen | no-auto-tls)
        if [[ $1 == 'gen' ]]; then is_gen=1; fi
        if [[ $1 == 'no-auto-tls' ]]; then is_no_auto_tls=1; fi
        add ${@:2}
        ;;
    bin | pbk | check | completion | format | generate | geoip | geosite | merge | rule-set | run | tools)
        is_run_command=$1
        if [[ $1 == 'bin' ]]; then
            $is_core_bin ${@:2}
        else
            if [[ $is_run_command == 'pbk' ]]; then is_run_command="generate reality-keypair"; fi
            $is_core_bin $is_run_command ${@:2}
        fi
        ;;
    bbr) _try_enable_bbr ;;
    c | config | change) change ${@:2} ;;
    d | del | rm) del $2 ;;
    dd | ddel | fix | fix-all)
        case $1 in
        fix)
            if [[ $2 ]]; then change $2 full; else is_change_id=full && change; fi
            return
            ;;
        fix-all)
            is_dont_auto_exit=1; msg
            local conf_files=()
            mapfile -t conf_files < <(list_conf_json_names '.json$')
            for v in "${conf_files[@]}"; do
                msg "fix: $v"; change "$v" full
            done
            _green "\nfix 完成.\n"
            ;;
        *)
            is_dont_auto_exit=1
            if [[ ! $2 ]]; then err "无法找到需要删除的参数"; else for v in ${@:2}; do del $v; done; fi
            ;;
        esac
        is_dont_auto_exit=
        manage restart &
        if [[ $is_del_host ]]; then manage restart caddy & fi
        ;;
    dns) dns_set ${@:2} ;;
    domain | domains) domain ${@:2} ;;
    doctor | diag) doctor ;;
    backup)
        case "${2:-list}" in
        list | ls) backup_list ;;
        create) unset is_snapshot_id; snapshot_ensure "${3:-manual}" ;;
        *) err "无法识别 backup 参数, 请使用: sb backup [list|create [reason]]" ;;
        esac
        ;;
    rollback | restore) rollback "$2" ;;
    cron) cron_task ;;
    sub) gen_sub ;;
    all) show_all_nodes ;;
    debug)
        is_debug=1; get info $2
        warn "如果需要复制; 请把 *uuid, *password, *host, *key 的值改写, 以避免泄露."
        ;;
    fix-config.json) create config.json ;;
    fix-caddyfile)
        if [[ $is_caddy ]]; then
            load caddy.sh
            caddy_config new
            manage restart caddy &
            _green "\nfix 完成.\n"
        else
            err "无法执行此操作"
        fi
        ;;
    i | info) info $2 ;;
    ip) get_ip; msg $ip ;;
    in | import) load import.sh ;;
    log) log_set $2 ;;
    url | qr) url_qr $@ ;;
    un | uninstall) uninstall ;;
    u | up | update | U | update.sh)
        is_update_name=$2; is_update_ver=$3
        if [[ ! $is_update_name ]]; then is_update_name=core; fi
        if [[ $1 == 'U' || $1 == 'update.sh' ]]; then is_update_name=sh; is_update_ver=; fi
        update $is_update_name $is_update_ver
        ;;
    ssss | ss2022) get $@ ;;
    s | status)
        msg "\n$is_core_name $is_core_ver: $is_core_status\n"
        if [[ $is_caddy ]]; then msg "Caddy $is_caddy_ver: $is_caddy_status\n"; fi
        ;;
    start | stop | r | restart)
        if [[ $2 && $2 != 'caddy' ]]; then err "无法识别 ($2), 请使用: $is_core $1 [caddy]"; fi
        manage $1 $2 &
        ;;
    t | test) get test-run ;;
    reinstall) get $1 ;;
    get-port) get_port; msg $tmp_port ;;
    main) is_main_menu ;;
    v | ver | version)
        if [[ $is_caddy_ver ]]; then is_caddy_ver="/ $(_blue Caddy $is_caddy_ver)"; fi
        msg "\n$(_green $is_core_name $is_core_ver) / $(_cyan LuoPo Script $is_sh_ver) $is_caddy_ver\n"
        ;;
    h | help | --help) load help.sh; show_help ${@:2} ;;
    *)
        is_try_change=1
        change test $1
        if [[ $is_change_id ]]; then
            unset is_try_change
            if [[ $2 ]]; then change $2 $1 ${@:3}; else change; fi
        else
            err "无法识别 ($1), 获取帮助请使用: sb help"
        fi
        ;;
    esac
}





