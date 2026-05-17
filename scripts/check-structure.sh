#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail=0

check_file() {
    local file="$1"
    if [[ ! -f $file ]]; then
        echo "[structure] missing: $file"
        fail=1
    fi
}

check_source_targets() {
    local loader="$1"
    local target

    check_file "$loader"
    [[ -f $loader ]] || return

    while IFS= read -r target; do
        [[ -z $target ]] && continue
        check_file "$target"
    done < <(
        sed -nE 's#^[[:space:]]*\.[[:space:]]+"\$is_sh_dir/([^"]+)".*$#\1#p' "$loader"
    )
}

check_lib_targets() {
    local lib_line lib

    lib_line="$(sed -nE 's/.*for lib_name in ([^;]+); do.*/\1/p' src/utils.sh | head -n 1)"
    if [[ -z $lib_line ]]; then
        echo "[structure] unable to find src/utils.sh lib list"
        fail=1
        return
    fi

    for lib in $lib_line; do
        check_file "src/lib/${lib}.sh"
    done
}

check_source_targets src/core/25_domain.sh
check_source_targets src/core/30_runtime.sh
check_source_targets src/core/40_node_query.sh
check_source_targets src/core/50_node_write.sh
check_source_targets src/core/node/add.sh
check_source_targets src/core/node/change.sh
check_lib_targets

if [[ $fail -ne 0 ]]; then
    echo "[structure] failed"
    exit 1
fi

echo "[structure] ok"
