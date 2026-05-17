#!/bin/bash

get_latest_version() {
    case $1 in
        core)
            name=$is_core_name
            url="https://api.github.com/repos/${is_core_repo}/releases/latest?v=$RANDOM"
            ;;
        sh)
            name="$is_core_name 脚本"
            url="https://api.github.com/repos/$is_sh_repo/releases/latest?v=$RANDOM"
            ;;
        caddy)
            name="Caddy"
            url="https://api.github.com/repos/$is_caddy_repo/releases/latest?v=$RANDOM"
            ;;
    esac
    latest_ver=$(_wget -qO- $url | grep tag_name | grep -E -o 'v([0-9.]+)')
    [[ ! $latest_ver ]] && err "获取 ${name} 最新版本失败."
    unset name url
}

download() {
    latest_ver=$2
    [[ ! $latest_ver ]] && get_latest_version $1
    tmpdir=$(mktemp -d 2> /dev/null || mktemp -d -t 'tmp-XXXXXX')

    case $1 in
        core)
            name=$is_core_name
            tmpfile=$tmpdir/$is_core.tar.gz
            link="https://github.com/${is_core_repo}/releases/download/${latest_ver}/${is_core}-${latest_ver:1}-linux-${is_arch}.tar.gz"
            download_file
            tar zxf $tmpfile --strip-components 1 -C $is_core_dir/bin
            chmod +x $is_core_bin
            ;;
        sh)
            name="$is_core_name 脚本"
            tmpfile=$tmpdir/sh.tar.gz
            link="https://github.com/${is_sh_repo}/archive/refs/tags/${latest_ver}.tar.gz"
            download_file
            tar zxf $tmpfile --strip-components 1 -C $is_sh_dir
            chmod +x $is_sh_bin ${is_sh_bin/$is_core/sb}
            ;;
        caddy)
            name="Caddy"
            tmpfile=$tmpdir/caddy.tar.gz
            link="https://github.com/${is_caddy_repo}/releases/download/${latest_ver}/caddy_${latest_ver:1}_linux_${is_arch}.tar.gz"
            download_file
            tar zxf $tmpfile -C $tmpdir
            cp -f $tmpdir/caddy $is_caddy_bin
            chmod +x $is_caddy_bin
            managed_record file "$is_caddy_bin"
            managed_record dir "$is_caddy_dir"
            managed_record file /lib/systemd/system/caddy.service
            ;;
    esac
    rm -rf -- "$tmpdir"
    unset latest_ver
}

download_file() {
    if ! _wget -t 5 -c $link -O $tmpfile; then
        rm -rf -- "$tmpdir"
        err "\n下载 ${name} 失败.\n"
    fi
}

# ----------------- BBR 模块 -----------------
