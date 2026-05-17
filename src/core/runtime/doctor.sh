#!/bin/bash

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
        conf_count=$(find "$is_conf_dir" -maxdepth 1 -type f -name '*.json' 2> /dev/null | wc -l)
        msg "[OK] 节点配置数量: $conf_count"
        ((ok++))
    else
        msg "[FAIL] 节点配置目录缺失: $is_conf_dir"
        fail_conf_dir=1
        ((fail++))
    fi

    if systemctl is-active --quiet "$is_core" 2> /dev/null; then
        msg "[OK] 服务状态: $is_core 运行中"
        ((ok++))
    else
        msg "[WARN] 服务状态: $is_core 未运行"
        warn_service=1
        ((warn_count++))
    fi

    if [[ $is_caddy ]]; then
        if systemctl is-active --quiet caddy 2> /dev/null; then
            msg "[OK] 服务状态: caddy 运行中"
            ((ok++))
        else
            msg "[WARN] 服务状态: caddy 未运行"
            warn_caddy=1
            ((warn_count++))
        fi
    fi

    if [[ -x $is_core_bin && -f $is_config_json ]]; then
        if json_check_core_config; then
            msg "[OK] 配置校验: sing-box check 通过"
            ((ok++))
        else
            msg "[FAIL] 配置校验: sing-box check 未通过"
            fail_check=1
            ((fail++))
        fi
    fi

    host_ip=$(curl -s4m6 https://icanhazip.com 2> /dev/null || true)
    if [[ $host_ip ]]; then
        msg "[OK] 出站网络: 可访问公网 (IPv4)"
        ((ok++))
    else
        msg "[WARN] 出站网络: 无法快速获取公网 IPv4"
        warn_network=1
        ((warn_count++))
    fi

    dns_test=$(wget -qO- -t1 -T6 --header="accept: application/dns-json" "https://one.one.one.one/dns-query?name=github.com&type=a" 2> /dev/null || true)
    if [[ $dns_test =~ \"Status\":0 ]]; then
        msg "[OK] DNS over HTTPS: one.one.one.one 可用"
        ((ok++))
    else
        msg "[WARN] DNS over HTTPS: one.one.one.one 测试失败"
        warn_dns=1
        ((warn_count++))
    fi

    if declare -F domain_collect_pool > /dev/null 2>&1; then
        domain_count=$(domain_collect_pool global 2> /dev/null | wc -l)
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
