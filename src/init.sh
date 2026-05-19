#!/bin/bash
# ==========================================
# Sing-box-EV Environment Initialization
# ==========================================

author="LuoPoJunZi"
is_sh_ver="v1.3.1"
is_sh_repo="LuoPoJunZi/sing-box-ev"

# --- 1. 终端 UI 颜色定义 ---
red='\e[31m'
yellow='\e[33m'
gray='\e[90m'
green='\e[92m'
blue='\e[94m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'

_red() { echo -e "${red}$@${none}"; }
_blue() { echo -e "${blue}$@${none}"; }
_cyan() { echo -e "${cyan}$@${none}"; }
_green() { echo -e "${green}$@${none}"; }
_yellow() { echo -e "${yellow}$@${none}"; }
_magenta() { echo -e "${magenta}$@${none}"; }
_red_bg() { echo -e "\e[41m$@${none}"; }

_rm() { rm -rf "$@"; }
_cp() { cp -rf "$@"; }
_sed() { sed -i "$@"; }
_mkdir() { mkdir -p "$@"; }

is_err=$(_red_bg "错误!")
is_warn=$(_red_bg "警告!")

err() {
    echo -e "\n$is_err $@\n"
    [[ $is_dont_auto_exit ]] && return
    exit 1
}

warn() {
    echo -e "\n$is_warn $@\n"
}

# --- 2. 核心路径与环境变量 ---
is_core="sing-box"
is_core_name="sing-box"
is_core_dir="/etc/$is_core"
is_core_bin="$is_core_dir/bin/$is_core"
is_core_repo="SagerNet/$is_core"
is_conf_dir="$is_core_dir/conf"
is_log_dir="/var/log/$is_core"
is_sh_bin="/usr/local/bin/$is_core"
is_sh_dir="$is_core_dir/sh"

is_pkg="wget unzip tar qrencode"
is_config_json="$is_core_dir/config.json"

is_caddy_bin="/usr/local/bin/caddy"
is_caddy_dir="/etc/caddy"
is_caddy_repo="caddyserver/caddy"
is_caddyfile="$is_caddy_dir/Caddyfile"
is_caddy_conf="$is_caddy_dir/$author"
is_caddy_service=$(systemctl list-units --full -all 2> /dev/null | grep caddy.service)
is_http_port=80
is_https_port=443

# --- 3. 基础系统工具包装 ---
load() { . "$is_sh_dir/src/$1"; }
_wget() { wget --no-check-certificate "$@"; }
cmd=$(type -P apt-get || type -P yum || type -P zypper)

case $(uname -m) in
    amd64 | x86_64) is_arch="amd64" ;;
    *aarch64* | *armv8*) is_arch="arm64" ;;
    *) err "此脚本仅支持 64 位系统..." ;;
esac

# 提前加载超级工具箱，提供基础功能
load utils.sh

# --- 4. 运行状态与前置检查 ---
is_core_ver=$($is_core_bin version 2> /dev/null | head -n1 | cut -d " " -f3)

# 自动生成缺失的 TLS 证书 (仅用于内部交互)
is_tls_cer="$is_core_dir/bin/tls.cer"
is_tls_key="$is_core_dir/bin/tls.key"
if [[ ! -f $is_tls_cer || ! -f $is_tls_key ]]; then
    is_tls_tmp="${is_tls_key/key/tmp}"
    $is_core_bin generate tls-keypair tls -m 456 > "$is_tls_tmp" 2> /dev/null
    awk '/BEGIN PRIVATE KEY/,/END PRIVATE KEY/' "$is_tls_tmp" > "$is_tls_key"
    awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' "$is_tls_tmp" > "$is_tls_cer"
    rm -f "$is_tls_tmp"
fi

if systemctl is-active --quiet "$is_core" 2> /dev/null || pgrep -f "$is_core_bin" > /dev/null; then
    is_core_status=$(_green "running")
else
    is_core_status=$(_red_bg "stopped")
    is_core_stop=1
fi

if [[ -f $is_caddy_bin && -d $is_caddy_dir && $is_caddy_service ]]; then
    is_caddy=1
    # 修复 Caddy 启动参数
    if ! grep -q '\-\-adapter caddyfile' /lib/systemd/system/caddy.service; then
        install_service caddy
        systemctl restart caddy &> /dev/null &
    fi
    is_caddy_ver=$($is_caddy_bin version 2> /dev/null | head -n1 | cut -d " " -f1)
    is_tmp_http_port=$(grep -E '^ {2,}http_port|^http_port' "$is_caddyfile" 2> /dev/null | grep -oE '[0-9]+')
    is_tmp_https_port=$(grep -E '^ {2,}https_port|^https_port' "$is_caddyfile" 2> /dev/null | grep -oE '[0-9]+')
    [[ $is_tmp_http_port ]] && is_http_port=$is_tmp_http_port
    [[ $is_tmp_https_port ]] && is_https_port=$is_tmp_https_port

    if systemctl is-active --quiet caddy 2> /dev/null || pgrep -f "$is_caddy_bin" > /dev/null; then
        is_caddy_status=$(_green "running")
    else
        is_caddy_status=$(_red_bg "stopped")
        is_caddy_stop=1
    fi
fi

# --- 5. 加载核心业务逻辑 ---
load core.sh
