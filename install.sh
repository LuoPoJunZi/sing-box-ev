#!/bin/bash

author="LuoPoJunZi"
# github=https://github.com/LuoPoJunZi/sing-box-ev

# bash fonts colors
ui_color_enabled=1
if [[ -n ${NO_COLOR:-} || ${TERM:-} == dumb || ! -t 1 ]]; then
    ui_color_enabled=0
fi

if [[ $ui_color_enabled == 1 ]]; then
    red='\e[31m'
    yellow='\e[33m'
    gray='\e[90m'
    green='\e[92m'
    blue='\e[94m'
    magenta='\e[95m'
    cyan='\e[96m'
    bold='\e[1m'
    underline='\e[4m'
    red_bg='\e[41m'
    none='\e[0m'
else
    red=''
    yellow=''
    gray=''
    green=''
    blue=''
    magenta=''
    cyan=''
    bold=''
    underline=''
    red_bg=''
    none=''
fi

ui_style() {
    local style=$1
    shift
    echo -e "${style}$*${none}"
}

ui_brand() { ui_style "$cyan" "$@"; }
ui_success() { ui_style "$green" "$@"; }
ui_warn() { ui_style "$yellow" "$@"; }
ui_error() { ui_style "$red" "$@"; }
ui_muted() { ui_style "$gray" "$@"; }
ui_link() { ui_style "${underline}${cyan}" "$@"; }
ui_title() { ui_style "${bold}${cyan}" "$@"; }
ui_key() { ui_style "$green" "$@"; }
ui_value() { ui_style "$blue" "$@"; }
ui_danger_badge() { ui_style "$red_bg" "$@"; }

_red() { ui_error "$@"; }
_blue() { ui_value "$@"; }
_cyan() { ui_brand "$@"; }
_green() { ui_success "$@"; }
_yellow() { ui_warn "$@"; }
_magenta() { ui_style "$magenta" "$@"; }
_red_bg() { ui_danger_badge "$@"; }

is_err=$(_red_bg 错误!)
is_warn=$(_red_bg 警告!)

err() {
    echo -e "\n$is_err $@\n" && exit 1
}

warn() {
    echo -e "\n$is_warn $@\n"
}

# root check
[[ $EUID != 0 ]] && err "当前非 ${yellow}ROOT用户.${none}"

# apt-get, yum or zypper, ubuntu/debian/centos/suse
cmd=$(type -P apt-get || type -P yum || type -P zypper)
[[ ! $cmd ]] && err "此脚本仅支持 ${yellow}(Ubuntu or Debian or CentOS or SUSE)${none}."

# systemd check
[[ ! $(type -P systemctl) ]] && {
    err "此系统缺少 ${yellow}(systemctl)${none}, 请尝试执行:${yellow} ${cmd} update -y;${cmd} install systemd -y ${none}来修复此错误."
}

# wget check
is_wget=$(type -P wget)

# arch check
case $(uname -m) in
    amd64 | x86_64)
        is_arch=amd64
        ;;
    *aarch64* | *armv8*)
        is_arch=arm64
        ;;
    *)
        err "此脚本仅支持 64 位系统..."
        ;;
esac

is_core=sing-box
is_core_name=sing-box
is_core_dir=/etc/$is_core
is_core_bin=$is_core_dir/bin/$is_core
is_core_repo=SagerNet/$is_core
is_conf_dir=$is_core_dir/conf
is_log_dir=/var/log/$is_core
is_sh_bin=/usr/local/bin/$is_core
is_sh_dir=$is_core_dir/sh

# ==================================================================
# 适配新仓库地址
# ==================================================================
is_sh_repo="LuoPoJunZi/sing-box-ev"

is_pkg="wget tar curl"
is_config_json=$is_core_dir/config.json
tmp_var_lists=(
    tmpcore
    tmpsh
    tmpjq
    is_core_ok
    is_sh_ok
    is_jq_ok
    is_pkg_ok
)

tmpdir=$(mktemp -d 2> /dev/null || mktemp -d -t 'tmp-XXXXXX')

for i in ${tmp_var_lists[*]}; do
    export $i=$tmpdir/$i
done

load() {
    . $is_sh_dir/src/$1
}

_wget() {
    wget --no-check-certificate $*
}

msg() {
    case $1 in
        warn) color=$yellow ;;
        err) color=$red ;;
        ok) color=$green ;;
    esac
    echo -e "${color}$(date +'%T')${none}) ${2}"
}

show_help() {
    echo -e "Usage: $0 [-f xxx | -l | -v xxx | -h]"
    echo -e "  -f, --core-file <path>          自定义 $is_core_name 文件路径"
    echo -e "  -l, --local-install             本地获取安装脚本"
    echo -e "  -v, --core-version <ver>        自定义 $is_core_name 版本"
    echo -e "  -h, --help                      显示此帮助界面\n"
    exit 0
}

install_pkg() {
    cmd_not_found=
    for i in $*; do
        [[ ! $(type -P $i) ]] && cmd_not_found="$cmd_not_found,$i"
    done
    if [[ $cmd_not_found ]]; then
        pkg=$(echo $cmd_not_found | sed 's/,/ /g')
        msg warn "安装依赖包 > ${pkg}"
        $cmd install -y $pkg &> /dev/null
        if [[ $? != 0 ]]; then
            [[ $cmd =~ yum ]] && yum install epel-release -y &> /dev/null
            if [[ $cmd =~ zypper ]]; then
                $cmd --non-interactive refresh &> /dev/null
            else
                $cmd update -y &> /dev/null
            fi
            $cmd install -y $pkg &> /dev/null
            [[ $? == 0 ]] && > $is_pkg_ok
        else
            > $is_pkg_ok
        fi
    else
        > $is_pkg_ok
    fi
}

download() {
    case $1 in
        core)
            [[ ! $is_core_ver ]] && is_core_ver=$(_wget -qO- "https://api.github.com/repos/${is_core_repo}/releases/latest?v=$RANDOM" | grep tag_name | grep -E -o 'v([0-9.]+)')
            [[ $is_core_ver ]] && link="https://github.com/${is_core_repo}/releases/download/${is_core_ver}/${is_core}-${is_core_ver:1}-linux-${is_arch}.tar.gz"
            name=$is_core_name
            tmpfile=$tmpcore
            is_ok=$is_core_ok
            ;;
        sh)
            # =======================================================================
            # 适配新仓库 main 分支打包
            # =======================================================================
            link="https://github.com/${is_sh_repo}/archive/refs/heads/main.tar.gz"
            name="$is_core_name 脚本"
            tmpfile=$tmpsh
            is_ok=$is_sh_ok
            ;;
        jq)
            link=https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-$is_arch
            name="jq"
            tmpfile=$tmpjq
            is_ok=$is_jq_ok
            ;;
    esac

    [[ $link ]] && {
        msg warn "下载 ${name} > ${link}"
        if _wget -t 3 -q -c $link -O $tmpfile; then
            mv -f $tmpfile $is_ok
        fi
    }
}

get_ip() {
    ip=$(curl -s4m8 https://icanhazip.com || wget -qO- -t1 -T8 https://icanhazip.com)
    [[ -z $ip ]] && ip=$(curl -s6m8 https://icanhazip.com || wget -qO- -t1 -T8 https://icanhazip.com)
}

check_status() {
    [[ ! -f $is_pkg_ok ]] && {
        msg err "安装依赖包失败"
        is_fail=1
    }
    if [[ $is_wget ]]; then
        [[ ! -f $is_core_ok ]] && {
            msg err "下载 ${is_core_name} 失败"
            is_fail=1
        }
        [[ ! -f $is_sh_ok ]] && {
            msg err "下载脚本失败"
            is_fail=1
        }
        [[ ! -f $is_jq_ok ]] && {
            msg err "下载 jq 失败"
            is_fail=1
        }
    else
        [[ ! $is_fail ]] && {
            is_wget=1
            [[ ! $is_core_file ]] && download core &
            [[ ! $local_install ]] && download sh &
            [[ $jq_not_found ]] && download jq &
            get_ip
            wait
            check_status
        }
    fi
    [[ $is_fail ]] && exit_and_del_tmpdir
}

pass_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f | --core-file)
                is_core_file=$2
                shift 2
                ;;
            -l | --local-install)
                local_install=1
                shift 1
                ;;
            -v | --core-version)
                is_core_ver=v${2//v/}
                shift 2
                ;;
            -h | --help) show_help ;;
            *)
                echo -e "\n${is_err} ($@) 为未知参数...\n"
                show_help
                ;;
        esac
    done
}

exit_and_del_tmpdir() {
    rm -rf -- "$tmpdir"
    [[ ! $1 ]] && {
        msg err "安装过程出现错误..."
        echo -e "反馈问题) https://github.com/${is_sh_repo}/issues"
        exit 1
    }
    exit
}

main() {
    [[ -f $is_sh_bin && -d $is_core_dir/bin && -d $is_sh_dir && -d $is_conf_dir ]] && {
        err "检测到脚本已安装, 如需重装请使用${green} ${is_core} reinstall ${none}命令."
    }

    [[ $# -gt 0 ]] && pass_args $@

    clear
    echo
    echo "........... $is_core_name script by $author .........."
    echo

    msg warn "开始安装..."
    [[ $is_core_ver ]] && msg warn "${is_core_name} 版本: ${yellow}$is_core_ver${none}"

    mkdir -p $tmpdir
    [[ $is_core_file ]] && cp -f $is_core_file $is_core_ok
    [[ $local_install ]] && > $is_sh_ok

    timedatectl set-ntp true &> /dev/null
    [[ $? != 0 ]] && is_ntp_on=1

    install_pkg $is_pkg &

    if [[ $(type -P jq) ]]; then
        > $is_jq_ok
    else
        jq_not_found=1
    fi

    [[ $is_wget ]] && {
        [[ ! $is_core_file ]] && download core &
        [[ ! $local_install ]] && download sh &
        [[ $jq_not_found ]] && download jq &
        get_ip
    }

    wait
    check_status

    if [[ $is_core_file ]]; then
        mkdir -p $tmpdir/testzip
        tar zxf $is_core_ok --strip-components 1 -C $tmpdir/testzip &> /dev/null
        [[ $? != 0 || ! -f $tmpdir/testzip/$is_core ]] && {
            msg err "${is_core_name} 文件无法通过测试."
            exit_and_del_tmpdir
        }
    fi

    [[ ! $ip ]] && {
        msg err "获取服务器 IP 失败."
        exit_and_del_tmpdir
    }

    mkdir -p $is_sh_dir
    cat > "$is_sh_dir/.install_manifest" << EOF
dir|$is_core_dir
dir|$is_sh_dir
dir|$is_conf_dir
dir|$is_log_dir
file|$is_sh_bin
file|${is_sh_bin/$is_core/sb}
file|/lib/systemd/system/$is_core.service
line|/root/.bashrc|alias sb=$is_sh_bin
line|/root/.bashrc|alias $is_core=$is_sh_bin
cron|sing-box update
cron|/var/log/sing-box
EOF
    if [[ $local_install ]]; then
        cp -rf $PWD/* $is_sh_dir
    else
        tar zxf $is_sh_ok --strip-components=1 -C $is_sh_dir
    fi

    mkdir -p $is_core_dir/bin
    if [[ $is_core_file ]]; then
        cp -rf $tmpdir/testzip/* $is_core_dir/bin
    else
        tar zxf $is_core_ok --strip-components 1 -C $is_core_dir/bin
    fi

    echo "alias sb=$is_sh_bin" >> /root/.bashrc
    echo "alias $is_core=$is_sh_bin" >> /root/.bashrc

    ln -sf $is_sh_dir/$is_core.sh $is_sh_bin
    ln -sf $is_sh_dir/$is_core.sh ${is_sh_bin/$is_core/sb}

    if [[ $jq_not_found ]]; then
        mv -f $is_jq_ok /usr/bin/jq
        echo "file|/usr/bin/jq" >> "$is_sh_dir/.install_manifest"
    fi

    chmod +x $is_core_bin $is_sh_bin /usr/bin/jq ${is_sh_bin/$is_core/sb}

    mkdir -p $is_log_dir
    msg ok "生成配置文件..."

    # 这里我们不再通过 load systemd.sh 来安装，因为我们重构了目录。
    # 我们直接从 utils.sh 里加载。
    # 由于是初次安装环境还未配置，我们临时加载 utils.sh
    . $is_sh_dir/src/utils.sh
    is_new_install=1
    install_service $is_core &> /dev/null

    mkdir -p $is_conf_dir

    # 模拟环境以供 add reality 运行
    . $is_sh_dir/src/init.sh

    # 强制在静默模式下创建节点，防止备注卡死
    is_main_start=
    add reality

    exit_and_del_tmpdir ok
}

main $@
