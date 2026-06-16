#!/bin/bash

runtime_doctor_ok() {
    msg "$(ui_success "[OK]") $*"
    ((ok++))
}

runtime_doctor_warn() {
    msg "$(ui_warn "[WARN]") $*"
    ((warn_count++))
}

runtime_doctor_fail() {
    msg "$(ui_error "[FAIL]") $*"
    ((fail++))
}

runtime_doctor_info() {
    msg "$(ui_muted "[INFO]") $*"
}

runtime_doctor_cmd() {
    local cmd=$1 label=${2:-$1}
    if command -v "$cmd" > /dev/null 2>&1; then
        runtime_doctor_ok "依赖可用: $label ($(command -v "$cmd"))"
    else
        runtime_doctor_warn "依赖缺失: $label"
        doctor_missing_cmds="${doctor_missing_cmds} ${cmd}"
    fi
}

runtime_doctor_disk() {
    local target_path=$1 label=$2 usage=""

    if [[ ! -e $target_path ]]; then
        target_path=$(dirname "$target_path")
    fi
    if [[ ! -e $target_path ]] || ! command -v df > /dev/null 2>&1; then
        runtime_doctor_warn "磁盘空间: 无法检查 $label"
        return
    fi

    usage=$(df -Pk "$target_path" 2> /dev/null | awk 'NR == 2 { gsub("%", "", $5); print $5 }')
    if [[ $usage =~ ^[0-9]+$ ]]; then
        if ((usage >= 90)); then
            runtime_doctor_warn "磁盘空间: $label 使用率 ${usage}% 偏高"
        else
            runtime_doctor_ok "磁盘空间: $label 使用率 ${usage}%"
        fi
    else
        runtime_doctor_warn "磁盘空间: 无法解析 $label 使用率"
    fi
}

runtime_doctor_color() {
    local reason=""

    if [[ -n ${NO_COLOR:-} ]]; then
        reason="NO_COLOR=1"
    elif [[ ${TERM:-} == dumb ]]; then
        reason="TERM=dumb"
    elif [[ ! -t 1 ]]; then
        reason="当前输出不是 TTY"
    fi

    if [[ $ui_color_enabled == 1 ]]; then
        runtime_doctor_ok "终端颜色: 已启用基础 ANSI 颜色 (30-37)"
        msg "颜色样例: $(ui_brand "青色标题") $(ui_success "绿色成功") $(ui_warn "黄色提醒") $(ui_error "红色错误") $(ui_muted "灰色提示")"
        runtime_doctor_info "如果上面的样例没有颜色，请检查终端配色方案或 SSH 客户端设置。"
    else
        runtime_doctor_info "终端颜色: 已关闭 (${reason:-原因未知})"
        runtime_doctor_info "这是预期的纯文本模式，适合日志复制、管道输出和 CI。"
    fi
}

runtime_doctor_port_listening() {
    local port=$1

    if command -v ss > /dev/null 2>&1; then
        ss -H -lntu 2> /dev/null | awk '{print $5}' | grep -Eq "(^|:|\\.)${port}$"
        return
    fi
    if command -v netstat > /dev/null 2>&1; then
        netstat -lntu 2> /dev/null | awk 'NR > 2 {print $4}' | grep -Eq "(^|:|\\.)${port}$"
        return
    fi
    return 2
}

runtime_doctor_listen_ports() {
    local port port_count=0 unchecked_count=0
    local ports=()

    if [[ ! -d $is_conf_dir ]]; then
        return
    fi

    mapfile -t ports < <(grep -Rho '"listen_port"[[:space:]]*:[[:space:]]*[0-9]\+' "$is_conf_dir" 2> /dev/null | grep -oE '[0-9]+' | sort -n | uniq)
    if [[ ${#ports[@]} -eq 0 ]]; then
        runtime_doctor_warn "监听端口: 未从节点配置中发现 listen_port"
        return
    fi

    msg "监听端口: ${ports[*]}"
    for port in "${ports[@]}"; do
        if runtime_doctor_port_listening "$port"; then
            ((port_count++))
        elif [[ $? -eq 2 ]]; then
            ((unchecked_count++))
        fi
    done

    if [[ $unchecked_count -gt 0 ]]; then
        runtime_doctor_warn "监听端口: 缺少 ss/netstat，无法确认端口监听状态"
    elif [[ $port_count -gt 0 ]]; then
        runtime_doctor_ok "监听端口: 已检测到 $port_count 个端口正在监听"
    else
        runtime_doctor_warn "监听端口: 未检测到配置端口在监听，若服务未启动请先执行 sb start"
    fi
}

runtime_doctor_manifest() {
    local manifest_file="$is_sh_dir/.install_manifest"
    local manifest_count=0

    if [[ -f $manifest_file ]]; then
        manifest_count=$(wc -l < "$manifest_file" 2> /dev/null)
        runtime_doctor_ok "安装清单: 已记录 $manifest_count 条托管项"
    else
        runtime_doctor_warn "安装清单: 未找到 $manifest_file，完全卸载时只能按兼容规则清理"
    fi
}

runtime_doctor_client_compat() {
    local conf_file="" inbound_type="" transport_type=""
    local trojan_count=0 hysteria2_count=0 tuic_count=0 vmess_quic_count=0 affected_count=0
    local conf_files=()

    if [[ ! -d $is_conf_dir ]]; then
        runtime_doctor_warn "客户端兼容: 节点配置目录不存在，无法扫描"
        return
    fi
    if ! command -v jq > /dev/null 2>&1; then
        runtime_doctor_warn "客户端兼容: jq 缺失，无法扫描协议类型"
        return
    fi

    mapfile -t conf_files < <(find "$is_conf_dir" -maxdepth 1 -type f -name '*.json' 2> /dev/null | sort)
    if [[ ${#conf_files[@]} -eq 0 ]]; then
        runtime_doctor_info "客户端兼容: 未发现节点配置"
        return
    fi

    for conf_file in "${conf_files[@]}"; do
        inbound_type=$(jq -r '.inbounds[0].type // ""' "$conf_file" 2> /dev/null)
        transport_type=$(jq -r '.inbounds[0].transport.type // ""' "$conf_file" 2> /dev/null)
        case $inbound_type in
            trojan)
                ((trojan_count++))
                ;;
            hysteria2)
                ((hysteria2_count++))
                ;;
            tuic)
                ((tuic_count++))
                ;;
            vmess)
                if [[ $transport_type == "quic" ]]; then
                    ((vmess_quic_count++))
                fi
                ;;
        esac
    done

    affected_count=$((hysteria2_count + tuic_count + vmess_quic_count))
    if [[ $trojan_count -gt 0 ]]; then
        runtime_doctor_info "客户端兼容: Trojan $trojan_count 个，按项目策略保留无域名/自签证书兼容"
    fi
    if [[ $affected_count -gt 0 ]]; then
        runtime_doctor_warn "客户端兼容: 发现 $affected_count 个节点建议迁移到证书固定指纹"
        [[ $hysteria2_count -gt 0 ]] && msg "  - Hysteria2: $hysteria2_count 个，建议使用 pinSHA256 并关闭 insecure"
        [[ $tuic_count -gt 0 ]] && msg "  - TUIC: $tuic_count 个，建议使用 certificate_public_key_sha256 并关闭 insecure"
        [[ $vmess_quic_count -gt 0 ]] && msg "  - VMess-QUIC: $vmess_quic_count 个，建议使用 pinnedPeerCertSha256 或迁移到 Reality/CFtunnel"
        msg "  - 运行 sb info <配置名> 可查看当前证书指纹和配置示例"
    else
        runtime_doctor_ok "客户端兼容: 未发现 Hysteria2/TUIC/VMess-QUIC 指纹迁移风险"
    fi
}

runtime_doctor_system_info() {
    local os_name="" kernel="" arch=""

    arch=$(uname -m 2> /dev/null)
    kernel=$(uname -r 2> /dev/null)
    if [[ -f /etc/os-release ]]; then
        os_name=$(grep -E '^PRETTY_NAME=' /etc/os-release 2> /dev/null | cut -d= -f2- | tr -d '"')
    fi

    msg "系统: ${os_name:-unknown} / ${arch:-unknown} / kernel ${kernel:-unknown}"
    if command -v systemctl > /dev/null 2>&1; then
        runtime_doctor_ok "systemd: systemctl 可用"
    else
        runtime_doctor_fail "systemd: systemctl 不可用，本脚本无法正常管理服务"
        fail_systemd=1
    fi
}

runtime_doctor() {
    local ok=0 warn_count=0 fail=0 conf_count=0
    local domain_count=0 snapshot_count=0
    local host_ip="" host_ip6="" dns_test=""
    local doctor_missing_cmds=""
    local fail_core_bin=0 fail_config=0 fail_conf_dir=0 fail_check=0 fail_systemd=0
    local warn_service=0 warn_caddy=0 warn_network=0 warn_dns=0 warn_jq=0

    msg "\n============= 系统诊断 (doctor) ============="

    runtime_doctor_system_info

    msg "------------- 终端颜色 -------------"
    runtime_doctor_color

    msg "------------- 依赖检查 -------------"
    runtime_doctor_cmd wget
    runtime_doctor_cmd curl
    runtime_doctor_cmd tar
    runtime_doctor_cmd jq
    if ! command -v jq > /dev/null 2>&1; then
        warn_jq=1
    fi
    if command -v ss > /dev/null 2>&1; then
        runtime_doctor_ok "依赖可用: ss ($(command -v ss))"
    elif command -v netstat > /dev/null 2>&1; then
        runtime_doctor_ok "依赖可用: netstat ($(command -v netstat))"
    else
        runtime_doctor_warn "依赖缺失: ss/netstat，无法检查端口监听"
    fi

    msg "------------- 文件与配置 -------------"
    if [[ -x $is_core_bin ]]; then
        runtime_doctor_ok "核心二进制: $is_core_bin"
    else
        runtime_doctor_fail "核心二进制不存在: $is_core_bin"
        fail_core_bin=1
    fi

    if [[ -f $is_config_json ]]; then
        runtime_doctor_ok "主配置存在: $is_config_json"
    else
        runtime_doctor_fail "主配置缺失: $is_config_json"
        fail_config=1
    fi

    if [[ -d $is_conf_dir ]]; then
        conf_count=$(find "$is_conf_dir" -maxdepth 1 -type f -name '*.json' 2> /dev/null | wc -l)
        runtime_doctor_ok "节点配置数量: $conf_count"
    else
        runtime_doctor_fail "节点配置目录缺失: $is_conf_dir"
        fail_conf_dir=1
    fi

    runtime_doctor_manifest
    runtime_doctor_disk "$is_core_dir" "/etc/sing-box"
    runtime_doctor_disk "$is_log_dir" "/var/log/sing-box"

    msg "------------- 客户端兼容 -------------"
    runtime_doctor_client_compat

    msg "------------- 服务与端口 -------------"
    if [[ $fail_systemd -eq 0 ]]; then
        if systemctl list-unit-files "$is_core.service" 2> /dev/null | grep -q "^$is_core.service"; then
            runtime_doctor_ok "服务单元存在: $is_core.service"
        else
            runtime_doctor_warn "服务单元缺失: $is_core.service"
        fi

        if systemctl is-active --quiet "$is_core" 2> /dev/null; then
            runtime_doctor_ok "服务状态: $is_core 运行中"
        else
            runtime_doctor_warn "服务状态: $is_core 未运行"
            warn_service=1
        fi

        if [[ $is_caddy ]]; then
            if systemctl is-active --quiet caddy 2> /dev/null; then
                runtime_doctor_ok "服务状态: caddy 运行中"
            else
                runtime_doctor_warn "服务状态: caddy 未运行"
                warn_caddy=1
            fi
        fi
    fi

    runtime_doctor_listen_ports

    msg "------------- 配置校验 -------------"
    if [[ -x $is_core_bin && -f $is_config_json ]]; then
        if json_check_core_config; then
            runtime_doctor_ok "配置校验: sing-box check 通过"
        else
            runtime_doctor_fail "配置校验: sing-box check 未通过"
            fail_check=1
        fi
    fi

    msg "------------- 网络检查 -------------"
    if command -v curl > /dev/null 2>&1; then
        host_ip=$(curl -s4m6 https://icanhazip.com 2> /dev/null || true)
        host_ip6=$(curl -s6m6 https://icanhazip.com 2> /dev/null || true)
        if [[ $host_ip ]]; then
            runtime_doctor_ok "出站网络: IPv4 可访问公网 ($host_ip)"
        else
            runtime_doctor_warn "出站网络: 无法快速获取公网 IPv4"
            warn_network=1
        fi
        if [[ $host_ip6 ]]; then
            runtime_doctor_ok "出站网络: IPv6 可访问公网 ($host_ip6)"
        else
            runtime_doctor_warn "出站网络: 未检测到可用公网 IPv6"
        fi
    else
        runtime_doctor_warn "出站网络: curl 缺失，无法检查公网 IP"
        warn_network=1
    fi

    if command -v wget > /dev/null 2>&1; then
        dns_test=$(wget -qO- -t1 -T6 --header="accept: application/dns-json" "https://one.one.one.one/dns-query?name=github.com&type=a" 2> /dev/null || true)
        if [[ $dns_test =~ \"Status\":0 ]]; then
            runtime_doctor_ok "DNS over HTTPS: one.one.one.one 可用"
        else
            runtime_doctor_warn "DNS over HTTPS: one.one.one.one 测试失败"
            warn_dns=1
        fi
    else
        runtime_doctor_warn "DNS over HTTPS: wget 缺失，无法检查 DoH"
        warn_dns=1
    fi

    msg "------------- 运行资料 -------------"
    if declare -F domain_collect_pool > /dev/null 2>&1; then
        domain_count=$(domain_collect_pool global 2> /dev/null | wc -l)
        runtime_doctor_ok "Reality 域名池条目: $domain_count"
    fi
    if [[ -d $is_sh_dir/snapshots ]]; then
        snapshot_count=$(find "$is_sh_dir/snapshots" -maxdepth 1 -type f -name '*.tar.gz' 2> /dev/null | wc -l)
        runtime_doctor_ok "配置快照数量: $snapshot_count"
    else
        runtime_doctor_warn "配置快照目录不存在: $is_sh_dir/snapshots"
    fi

    msg "----------------------------------------------"
    msg "诊断结果: OK=$ok WARN=$warn_count FAIL=$fail"
    if [[ $fail -gt 0 || $warn_count -gt 0 ]]; then
        msg "------------- 建议修复动作 -------------"
        if [[ $doctor_missing_cmds ]]; then
            msg "1) 依赖缺失：请先安装:${doctor_missing_cmds}"
        fi
        if [[ $fail_systemd -eq 1 ]]; then
            msg "2) systemd 不可用：请确认当前系统支持 systemctl，或改用受支持的 VPS 系统"
        fi
        if [[ $fail_core_bin -eq 1 ]]; then
            msg "3) 核心缺失：尝试执行 sb update core 或重新安装脚本"
        fi
        if [[ $fail_config -eq 1 || $fail_conf_dir -eq 1 ]]; then
            msg "4) 配置缺失：可用 sb rollback 恢复最近快照，或 sb backup list 先检查快照"
        fi
        if [[ $fail_check -eq 1 ]]; then
            msg "5) 配置非法：先执行 sb backup create pre-fix，再用 sb fix-all / sb change 修复"
        fi
        if [[ $warn_service -eq 1 ]]; then
            msg "6) 核心未运行：执行 sb start"
        fi
        if [[ $warn_caddy -eq 1 ]]; then
            msg "7) Caddy 未运行：执行 sb start caddy"
        fi
        if [[ $warn_network -eq 1 || $warn_dns -eq 1 ]]; then
            msg "8) 网络或 DNS 异常：检查服务器出站策略、DNS 解析与防火墙规则"
        fi
        if [[ $warn_jq -eq 1 ]]; then
            msg "9) jq 缺失会影响 JSON 读写：请安装 jq 后再执行配置修改"
        fi
        msg "----------------------------------------"
    fi
    msg "==============================================\n"
}
