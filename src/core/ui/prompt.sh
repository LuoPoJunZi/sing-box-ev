#!/bin/bash

ask() {
    case $1 in
        set_ss_method)
            is_tmp_list=(${ss_method_list[@]})
            is_default_arg=$is_random_ss_method
            is_opt_msg="\n请选择加密方式:"
            is_opt_input_msg="➡️ 请选择 \e[92m(输入 0 返回主面板，默认 $is_default_arg)\e[0m: "
            is_ask_set=ss_method
            ;;
        set_protocol)
            echo -e "\e[96m=====================================================\e[0m"
            echo -e "                 请选择要添加的协议"
            echo -e "\e[96m=====================================================\e[0m"
            echo -e "  \e[93m[ 基础协议 ]\e[0m"
            echo -e "  \e[92m(1)\e[0m TUIC        \e[92m(2)\e[0m Trojan       \e[92m(3)\e[0m Hysteria2   \e[92m(4)\e[0m VMess-WS"
            echo -e "  \e[92m(5)\e[0m VMess-TCP   \e[92m(6)\e[0m VMess-HTTP   \e[92m(7)\e[0m VMess-QUIC  \e[92m(8)\e[0m Shadowsocks"
            echo -e "  \e[93m[ TLS 隧道 ]\e[0m"
            echo -e "  \e[92m(9)\e[0m VMess-H2    \e[92m(10)\e[0m VMess-WS   \e[92m(11)\e[0m VLESS-H2   \e[92m(12)\e[0m VLESS-WS"
            echo -e "  \e[92m(13)\e[0m Trojan-H2  \e[92m(14)\e[0m Trojan-WS  \e[92m(15)\e[0m VMess-HU   \e[92m(16)\e[0m VLESS-HU"
            echo -e "  \e[92m(17)\e[0m Trojan-HU\n"
            echo -e "  \e[93m[ 强力抗封锁 ]\e[0m"
            echo -e "  \e[92m(18)\e[0m VLESS-REALITY     \e[92m(19)\e[0m VLESS-HTTP2-REALITY"
            echo -e "  \e[92m(20)\e[0m AnyTLS\n"
            echo -e "  \e[93m[ 隧道穿透 ]\e[0m"
            echo -e "  \e[92m(21)\e[0m CFtunnel          \e[92m(22)\e[0m Socks\n"
            echo -e "  \e[93m[ 取消操作 ]\e[0m"
            echo -e "  \e[92m(0)\e[0m 返回主面板"
            echo -e "\e[90m-----------------------------------------------------\e[0m"
            is_ask_set=is_new_protocol
            is_opt_input_msg="➡️ 请选择协议序号 [\e[91m0-22\e[0m]: "
            ;;
        set_change_list)
            is_tmp_list=()
            for v in ${is_can_change[@]}; do
                is_tmp_list+=("${change_list[$v]}")
            done
            is_opt_msg="\n请选择更改:"
            is_ask_set=is_change_str
            is_opt_input_msg="➡️ 请输入对应的数字 \e[92m(输入 0 返回主面板)\e[0m: "
            ;;
        string)
            is_ask_set=$2
            is_opt_input_msg="${3/:/} \e[92m(输入 0 返回主面板)\e[0m: "
            ;;
        list)
            is_ask_set=$2
            if [[ -n ${3:-} ]]; then
                is_tmp_list=($3)
            elif [[ ${#is_tmp_list[@]} -eq 0 ]]; then
                unset is_tmp_list
            fi
            is_opt_msg=$4
            if [[ ! $is_opt_msg ]]; then
                is_opt_msg="\n请选择:"
            fi
            is_opt_input_msg=$5
            if [[ ! $is_opt_input_msg ]]; then
                is_opt_input_msg="➡️ 请输入对应的数字 \e[92m(输入 0 返回主面板)\e[0m: "
            else
                is_opt_input_msg="${is_opt_input_msg/:/} \e[92m(输入 0 返回主面板)\e[0m: "
            fi
            ;;
        get_config_file)
            is_tmp_list=("${is_all_json[@]}")
            is_opt_msg="\n请选择配置:"
            is_ask_set=is_config_file
            is_opt_input_msg="➡️ 请输入对应的数字 \e[92m(输入 0 返回主面板)\e[0m: "
            ;;
    esac

    if [[ $is_opt_msg ]]; then
        msg "$is_opt_msg"
    fi
    if [[ $is_tmp_list ]]; then
        show_list "${is_tmp_list[@]}"
    fi

    while :; do
        echo -ne "$is_opt_input_msg"
        read REPLY

        if [[ "$REPLY" == "0" ]]; then
            echo -e "\n\e[33m已安全取消当前操作，正在返回主面板...\e[0m"
            sleep 0.5
            is_main_menu
            exit 0
        fi

        if [[ ! $REPLY && $is_emtpy_exit ]]; then
            exit
        fi
        if [[ ! $REPLY && $is_default_arg ]]; then
            export $is_ask_set=$is_default_arg
            break
        fi
        if [[ ! $REPLY && ! $is_default_arg && ! $is_emtpy_exit ]]; then
            continue
        fi

        if [[ $1 == "set_protocol" ]]; then
            if [[ "$REPLY" =~ ^([1-9]|1[0-9]|2[0-2])$ ]]; then
                export $is_ask_set="${protocol_list[$REPLY - 1]}"
                break
            fi
        elif [[ ! $is_tmp_list ]]; then
            if [[ $(grep port <<< $is_ask_set) ]]; then
                if [[ ! $(is_test port "$REPLY") ]]; then
                    msg "$is_err 请输入正确的端口, 可选(1-65535)"
                    continue
                fi
                if [[ $(is_test port_used $REPLY) && $is_ask_set != 'door_port' ]]; then
                    msg "$is_err 无法使用 ($REPLY) 端口."
                    continue
                fi
            fi
            if [[ $(grep path <<< $is_ask_set) && ! $(is_test path "$REPLY") ]]; then
                if [[ ! $tmp_uuid ]]; then
                    get_uuid
                fi
                msg "$is_err 请输入正确的路径, 例如: /$tmp_uuid"
                continue
            fi
            if [[ $(grep uuid <<< $is_ask_set) && ! $(is_test uuid "$REPLY") ]]; then
                if [[ ! $tmp_uuid ]]; then
                    get_uuid
                fi
                msg "$is_err 请输入正确的 UUID, 例如: $tmp_uuid"
                continue
            fi
            if [[ $(grep ^y$ <<< $is_ask_set) ]]; then
                if [[ $(grep -i ^y$ <<< "$REPLY") ]]; then
                    break
                fi
                msg "请输入 (y)"
                continue
            fi
            if [[ $REPLY ]]; then
                export $is_ask_set=$REPLY
                msg "使用: ${!is_ask_set}"
                break
            fi
        else
            if [[ $(is_test number "$REPLY") ]]; then
                is_ask_result=${is_tmp_list[$REPLY - 1]}
            fi
            if [[ $is_ask_result ]]; then
                export $is_ask_set="$is_ask_result"
                msg "选择: ${!is_ask_set}"
                break
            fi
        fi

        msg "输入${is_err}"
    done
    unset is_opt_msg is_opt_input_msg is_tmp_list is_ask_result is_default_arg is_emtpy_exit
}
