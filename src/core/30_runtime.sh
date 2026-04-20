#!/bin/bash

runtime_snapshot_dir() {
    echo "$is_sh_dir/backups"
}

runtime_snapshot_ensure() {
    local reason="${1:-manual}"
    local backup_root snapshot_id snapshot_dir

    if [[ $is_gen || $is_test_json || $is_disable_snapshot ]]; then
        return
    fi
    if [[ $is_snapshot_id ]]; then
        return
    fi

    if [[ $is_dry_run ]]; then
        is_snapshot_id="dryrun-$(date +%Y%m%d-%H%M%S)-${reason}"
        msg "DRY-RUN: 将创建配置快照: $(_green $is_snapshot_id)"
        return
    fi

    backup_root="$(runtime_snapshot_dir)"
    mkdir -p "$backup_root"

    snapshot_id="$(date +%Y%m%d-%H%M%S)-${reason}"
    snapshot_dir="$backup_root/$snapshot_id"
    mkdir -p "$snapshot_dir"

    if [[ -f $is_config_json ]]; then
        cp -f -- "$is_config_json" "$snapshot_dir/config.json"
    fi
    if [[ -d $is_conf_dir ]]; then
        mkdir -p "$snapshot_dir/conf"
        cp -rf -- "$is_conf_dir/." "$snapshot_dir/conf/"
    fi
    if [[ $is_caddy && -d $is_caddy_conf ]]; then
        mkdir -p "$snapshot_dir/caddy-conf"
        cp -rf -- "$is_caddy_conf/." "$snapshot_dir/caddy-conf/"
    fi

    cat >"$snapshot_dir/meta.txt" <<EOF
created_at=$(date '+%F %T %z')
reason=$reason
core_version=$is_core_ver
script_version=$is_sh_ver
EOF

    # 保留最近 20 个快照，避免长期占用磁盘
    ls -1dt "$backup_root"/* 2>/dev/null | tail -n +21 | xargs -r rm -rf --

    is_snapshot_id="$snapshot_id"
    msg "已创建配置快照: $(_green $snapshot_id)"
}

runtime_snapshot_list() {
    local backup_root
    backup_root="$(runtime_snapshot_dir)"

    if [[ ! -d $backup_root ]]; then
        msg "\n未找到任何快照目录.\n"
        return
    fi

    msg "\n------------- 配置快照列表 -------------"
    ls -1dt "$backup_root"/* 2>/dev/null | while read -r d; do
        [[ -d $d ]] || continue
        msg "$(basename "$d")"
    done
    msg "----------------------------------------\n"
}

runtime_snapshot_restore() {
    local backup_root target_id target_dir latest_id
    local snapshot_items=()
    backup_root="$(runtime_snapshot_dir)"
    target_id="$1"

    if [[ ! -d $backup_root ]]; then
        err "未找到快照目录."
    fi

    if [[ ! $target_id ]]; then
        mapfile -t snapshot_items < <(ls -1dt "$backup_root"/* 2>/dev/null | xargs -r -n 1 basename)
        if [[ ${#snapshot_items[@]} -eq 0 ]]; then
            err "没有可回滚的快照."
        fi

        if [[ $is_dont_auto_exit ]]; then
            target_id="${snapshot_items[0]}"
        else
            is_tmp_list=("${snapshot_items[@]}")
            ask list target_id "" "\n请选择要回滚的快照:"
            unset is_tmp_list
        fi
    fi

    target_dir="$backup_root/$target_id"
    if [[ ! -d $target_dir ]]; then
        err "快照不存在: $target_id"
    fi

    if [[ $is_dry_run ]]; then
        msg "\nDRY-RUN: 将执行回滚 -> $(_green $target_id)"
        msg "DRY-RUN: 将恢复主配置: $is_config_json"
        msg "DRY-RUN: 将恢复节点目录: $is_conf_dir"
        if [[ $is_caddy && -d $target_dir/caddy-conf ]]; then
            msg "DRY-RUN: 将恢复 Caddy 目录: $is_caddy_conf"
        fi
        msg "DRY-RUN: 将重启服务: $is_core $( [[ $is_caddy ]] && echo '和 caddy' )\n"
        return
    fi

    # 回滚前再做一次保护性快照
    unset is_snapshot_id
    runtime_snapshot_ensure "pre-rollback"

    if [[ -f $target_dir/config.json ]]; then
        cp -f -- "$target_dir/config.json" "$is_config_json"
    fi

    if [[ -d $target_dir/conf ]]; then
        rm -rf -- "$is_conf_dir"
        mkdir -p "$is_conf_dir"
        cp -rf -- "$target_dir/conf/." "$is_conf_dir/"
    fi

    if [[ $is_caddy && -d $target_dir/caddy-conf ]]; then
        mkdir -p "$is_caddy_conf"
        rm -rf -- "$is_caddy_conf"/*
        cp -rf -- "$target_dir/caddy-conf/." "$is_caddy_conf/"
    fi

    manage restart &
    if [[ $is_caddy && -d $target_dir/caddy-conf ]]; then
        manage restart caddy &
    fi

    _green "\n回滚完成: $target_id\n"
}

runtime_doctor() {
    local ok=0 warn_count=0 fail=0 conf_count=0
    local domain_count=0
    local host_ip=""
    local dns_test=""
    local fail_core_bin=0 fail_config=0 fail_conf_dir=0 fail_check=0
    local warn_service=0 warn_caddy=0 warn_network=0 warn_dns=0

    msg "\n============= 系统诊断 (doctor) ============="

    if [[ -x $is_core_bin ]]; then
        msg "[OK] 核心二进制: $is_core_bin"
        ((ok++))
    else
        msg "[FAIL] 核心二进制不存在: $is_core_bin"
        fail_core_bin=1
        ((fail++))
    fi

    if [[ -f $is_config_json ]]; then
        msg "[OK] 主配置存在: $is_config_json"
        ((ok++))
    else
        msg "[FAIL] 主配置缺失: $is_config_json"
        fail_config=1
        ((fail++))
    fi

    if [[ -d $is_conf_dir ]]; then
        conf_count=$(find "$is_conf_dir" -maxdepth 1 -type f -name '*.json' 2>/dev/null | wc -l)
        msg "[OK] 节点配置数量: $conf_count"
        ((ok++))
    else
        msg "[FAIL] 节点配置目录缺失: $is_conf_dir"
        fail_conf_dir=1
        ((fail++))
    fi

    if systemctl is-active --quiet "$is_core" 2>/dev/null; then
        msg "[OK] 服务状态: $is_core 运行中"
        ((ok++))
    else
        msg "[WARN] 服务状态: $is_core 未运行"
        warn_service=1
        ((warn_count++))
    fi

    if [[ $is_caddy ]]; then
        if systemctl is-active --quiet caddy 2>/dev/null; then
            msg "[OK] 服务状态: caddy 运行中"
            ((ok++))
        else
            msg "[WARN] 服务状态: caddy 未运行"
            warn_caddy=1
            ((warn_count++))
        fi
    fi

    if [[ -x $is_core_bin && -f $is_config_json ]]; then
        if $is_core_bin check -c "$is_config_json" -C "$is_conf_dir" >/dev/null 2>&1; then
            msg "[OK] 配置校验: sing-box check 通过"
            ((ok++))
        else
            msg "[FAIL] 配置校验: sing-box check 未通过"
            fail_check=1
            ((fail++))
        fi
    fi

    host_ip=$(curl -s4m6 https://icanhazip.com 2>/dev/null || true)
    if [[ $host_ip ]]; then
        msg "[OK] 出站网络: 可访问公网 (IPv4)"
        ((ok++))
    else
        msg "[WARN] 出站网络: 无法快速获取公网 IPv4"
        warn_network=1
        ((warn_count++))
    fi

    dns_test=$(wget -qO- -t1 -T6 --header="accept: application/dns-json" "https://one.one.one.one/dns-query?name=github.com&type=a" 2>/dev/null || true)
    if [[ $dns_test =~ \"Status\":0 ]]; then
        msg "[OK] DNS over HTTPS: one.one.one.one 可用"
        ((ok++))
    else
        msg "[WARN] DNS over HTTPS: one.one.one.one 测试失败"
        warn_dns=1
        ((warn_count++))
    fi

    if declare -F domain_collect_pool >/dev/null 2>&1; then
        domain_count=$(domain_collect_pool global 2>/dev/null | wc -l)
        msg "[OK] Reality 域名池条目: $domain_count"
        ((ok++))
    fi

    msg "----------------------------------------------"
    msg "诊断结果: OK=$ok WARN=$warn_count FAIL=$fail"
    if [[ $fail -gt 0 || $warn_count -gt 0 ]]; then
        msg "------------- 建议修复动作 -------------"
        if [[ $fail_core_bin -eq 1 ]]; then
            msg "1) 核心缺失：尝试执行 sb update core 或重新安装脚本"
        fi
        if [[ $fail_config -eq 1 || $fail_conf_dir -eq 1 ]]; then
            msg "2) 配置缺失：可用 sb rollback 恢复最近快照，或 sb backup list 先检查快照"
        fi
        if [[ $fail_check -eq 1 ]]; then
            msg "3) 配置非法：先执行 sb backup create pre-fix，再用 sb fix-all / sb change 修复"
        fi
        if [[ $warn_service -eq 1 ]]; then
            msg "4) 核心未运行：执行 sb start"
        fi
        if [[ $warn_caddy -eq 1 ]]; then
            msg "5) Caddy 未运行：执行 sb start caddy"
        fi
        if [[ $warn_network -eq 1 || $warn_dns -eq 1 ]]; then
            msg "6) 网络或 DNS 异常：检查服务器出站策略、DNS 解析与防火墙规则"
        fi
        msg "----------------------------------------"
    fi
    msg "==============================================\n"
}

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
