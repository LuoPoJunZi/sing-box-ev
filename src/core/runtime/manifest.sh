#!/bin/bash

runtime_manifest_path() {
    echo "$is_sh_dir/.install_manifest"
}

runtime_manifest_type_label() {
    case $1 in
        file) echo "文件" ;;
        dir) echo "目录" ;;
        line) echo "配置行" ;;
        cron) echo "计划任务" ;;
        service) echo "服务" ;;
        port) echo "防火墙端口" ;;
        *) echo "$1" ;;
    esac
}

runtime_manifest_require_file() {
    local manifest
    manifest="$(runtime_manifest_path)"
    if [[ -f $manifest ]]; then
        return 0
    fi
    ui_warn_msg "未找到安装清单: $manifest"
    msg "这通常表示当前安装来自旧版本，完全卸载时会按兼容规则预览和清理。"
    return 1
}

runtime_manifest_summary() {
    local manifest total_count=0
    manifest="$(runtime_manifest_path)"

    msg "\n============= 安装清单摘要 ============="
    msg "路径: $manifest"
    if ! runtime_manifest_require_file; then
        msg "========================================\n"
        return
    fi

    total_count=$(wc -l < "$manifest" 2> /dev/null)
    msg "总记录数: $total_count"
    awk -F'|' '
        NF {
            count[$1]++
        }
        END {
            for (type in count) {
                print type "|" count[type]
            }
        }
    ' "$manifest" |
        sort |
        while IFS='|' read -r item_type item_count; do
            msg "- $(runtime_manifest_type_label "$item_type"): $item_count"
        done
    msg "========================================\n"
}

runtime_manifest_list() {
    local manifest index=1 item_type item_value item_extra
    manifest="$(runtime_manifest_path)"

    msg "\n============= 安装清单明细 ============="
    msg "路径: $manifest"
    if ! runtime_manifest_require_file; then
        msg "========================================\n"
        return
    fi

    while IFS='|' read -r item_type item_value item_extra; do
        [[ -z $item_type && -z $item_value ]] && continue
        msg "$(ui_key "$index.") $(ui_warn "$(runtime_manifest_type_label "$item_type")") $item_value"
        if [[ -n $item_extra ]]; then
            msg "    $(ui_muted "附加:") $item_extra"
        fi
        ((index++))
    done < "$manifest"
    msg "========================================\n"
}

runtime_manifest_raw() {
    local manifest
    manifest="$(runtime_manifest_path)"

    msg "\n============= 安装清单原文 ============="
    if ! runtime_manifest_require_file; then
        msg "========================================\n"
        return
    fi
    cat "$manifest"
    msg "========================================\n"
}

runtime_manifest_manage() {
    case "${1:-summary}" in
        summary | show) runtime_manifest_summary ;;
        list | ls) runtime_manifest_list ;;
        raw | cat) runtime_manifest_raw ;;
        *) err "无法识别 manifest 参数, 请使用: sb manifest [summary|list|raw]" ;;
    esac
}
