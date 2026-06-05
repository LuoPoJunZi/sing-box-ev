admin_uninstall_manifest_path() {
    echo "$is_sh_dir/.install_manifest"
}

admin_uninstall_recorded_values() {
    local record_type=$1 manifest
    manifest="$(admin_uninstall_manifest_path)"
    [[ -f $manifest ]] || return
    while IFS='|' read -r item_type item_value _; do
        [[ $item_type == "$record_type" && -n $item_value ]] && echo "$item_value"
    done < "$manifest"
}

admin_uninstall_collect_ports() {
    local manifest
    manifest="$(admin_uninstall_manifest_path)"
    admin_uninstall_recorded_values port
    if [[ -d $is_conf_dir ]]; then
        if command -v jq > /dev/null 2>&1; then
            find "$is_conf_dir" -maxdepth 1 -type f -name '*.json' -print0 2> /dev/null |
                while IFS= read -r -d '' f; do
                    jq -r '.inbounds[]?.listen_port // empty' "$f" 2> /dev/null
                done
        else
            grep -hEo '"listen_port"[[:space:]]*:[[:space:]]*[0-9]+' "$is_conf_dir"/*.json 2> /dev/null | grep -Eo '[0-9]+$'
        fi
    fi
    [[ -f $manifest ]] && grep -E '^service\|cftunnel-[0-9]+\.service' "$manifest" 2> /dev/null | grep -Eo '[0-9]+'
}

admin_uninstall_cleanup_port() {
    local p=$1
    [[ $p =~ ^[0-9]+$ ]] || return
    if command -v ufw > /dev/null 2>&1; then
        ufw delete allow "${p}/tcp" > /dev/null 2>&1 || true
        ufw delete allow "${p}/udp" > /dev/null 2>&1 || true
    fi
    if command -v firewall-cmd > /dev/null 2>&1; then
        firewall-cmd --remove-port="${p}/tcp" --permanent > /dev/null 2>&1 || true
        firewall-cmd --remove-port="${p}/udp" --permanent > /dev/null 2>&1 || true
        firewall-cmd --reload > /dev/null 2>&1 || true
    fi
    if command -v iptables > /dev/null 2>&1; then
        while iptables -D INPUT -p tcp --dport "$p" -j ACCEPT > /dev/null 2>&1; do :; done
        while iptables -D INPUT -p udp --dport "$p" -j ACCEPT > /dev/null 2>&1; do :; done
        [[ -f /etc/sysconfig/iptables ]] && service iptables save > /dev/null 2>&1 || true
        command -v netfilter-persistent > /dev/null 2>&1 && netfilter-persistent save > /dev/null 2>&1 || true
    fi
}

admin_uninstall_cleanup_cftunnel() {
    local unit unit_name
    for unit_name in $(admin_uninstall_recorded_values service | grep -E '^cftunnel-[0-9]+\.service$' 2> /dev/null || true); do
        systemctl disable --now "$unit_name" > /dev/null 2>&1 || true
    done
    for unit in /lib/systemd/system/cftunnel-*.service /etc/systemd/system/cftunnel-*.service; do
        [[ -e $unit ]] || continue
        unit_name="$(basename "$unit")"
        systemctl disable --now "$unit_name" > /dev/null 2>&1 || true
        rm -f -- "$unit"
    done
}

admin_uninstall_cleanup_manifest() {
    local manifest item_type item_value item_extra
    manifest="$(admin_uninstall_manifest_path)"
    [[ -f $manifest ]] || return
    while IFS='|' read -r item_type item_value item_extra; do
        case $item_type in
            file) [[ -n $item_value ]] && rm -f -- "$item_value" ;;
            dir) [[ -n $item_value ]] && rm -rf -- "$item_value" ;;
            line) [[ -n $item_value && -f $item_value && -n $item_extra ]] && sed -i "\#^${item_extra//\//\\/}\$#d" "$item_value" ;;
            cron) [[ -n $item_value ]] && crontab -l 2> /dev/null | grep -Fv "$item_value" | crontab - ;;
            service) [[ -n $item_value ]] && systemctl disable --now "$item_value" > /dev/null 2>&1 || true ;;
        esac
    done < "$manifest"
}

admin_uninstall() {
    ui_warn_msg "卸载不会自动创建快照。如需备份，请先返回主面板，在 (9) 进阶选项 中使用快照功能。"
    msg
    msg "$(ui_danger_text "完全卸载") 将清理本脚本创建的配置、节点、日志、命令、服务、计划任务、CFtunnel、Caddy 与防火墙放行记录。"
    ask string y "是否完全卸载 ${is_core_name}? [y]: "

    if [[ $is_dry_run ]]; then
        msg "\nDRY-RUN: 将完整卸载 $is_core_name，并清理脚本创建的目录、命令、服务、计划任务、防火墙端口与 CFtunnel 残留（未实际执行）\n"
        return
    fi

    manage stop &> /dev/null
    manage disable &> /dev/null
    admin_uninstall_cleanup_cftunnel
    mapfile -t is_uninstall_ports < <(admin_uninstall_collect_ports | sort -u)
    for p in "${is_uninstall_ports[@]}"; do
        admin_uninstall_cleanup_port "$p"
    done

    admin_uninstall_cleanup_manifest
    crontab -l 2> /dev/null | grep -v -E "sing-box update|/var/log/sing-box" | crontab -

    rm -rf -- "$is_core_dir" "$is_log_dir" "$is_sh_bin" "${is_sh_bin/$is_core/sb}" "/lib/systemd/system/$is_core.service"
    sed -i "/$is_core/d" /root/.bashrc

    if [[ $is_caddy || -d $is_caddy_dir || -f $is_caddy_bin ]]; then
        manage stop caddy &> /dev/null
        manage disable caddy &> /dev/null
        rm -rf -- "$is_caddy_dir" "$is_caddy_bin" "/lib/systemd/system/caddy.service"
    fi
    rm -f -- /usr/local/bin/cloudflared
    systemctl daemon-reload
    systemctl reset-failed > /dev/null 2>&1 || true
    if [[ $is_install_sh ]]; then return; fi

    ui_success_msg "卸载完成!"
    msg "脚本哪里需要完善? 请反馈: $(msg_ul https://github.com/${is_sh_repo}/issues)\n"
}
