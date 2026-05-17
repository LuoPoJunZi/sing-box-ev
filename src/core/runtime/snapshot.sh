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

    cat > "$snapshot_dir/meta.txt" << EOF
created_at=$(date '+%F %T %z')
reason=$reason
core_version=$is_core_ver
script_version=$is_sh_ver
EOF

    # 保留最近 20 个快照，避免长期占用磁盘
    ls -1dt "$backup_root"/* 2> /dev/null | tail -n +21 | xargs -r rm -rf --

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
    ls -1dt "$backup_root"/* 2> /dev/null | while read -r d; do
        [[ -d $d ]] || continue
        msg "$(basename "$d")"
    done
    msg "----------------------------------------\n"
}
