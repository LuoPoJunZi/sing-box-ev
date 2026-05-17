#!/bin/bash

domain_manage() {
    domain_init_store
    local action="${1:-list}"
    local d w r line src region total ok_cnt fail_cnt last health

    case "${action,,}" in
        list | ls)
            region="$(domain_sanitize_region "$2")"
            msg "\n[Domain Pool] region=$region (global 会自动参与)"
            msg "domain | source | weight | region | health(cache)"
            while IFS= read -r line; do
                IFS='|' read -r d src w r <<< "$line"
                last="$(grep -E "^${d//./\\.}\|" "$domain_health_file" 2> /dev/null | tail -n 1)"
                health="-"
                if [[ $last ]]; then
                    IFS='|' read -r _ _ health <<< "$last"
                fi
                msg "$d | $src | $w | $r | $health"
            done < <(domain_collect_pool "$region" | sort)
            msg
            ;;
        add)
            d="$(domain_normalize "$2")"
            w="${3:-5}"
            r="$(domain_sanitize_region "${4:-global}")"
            if [[ -z $d || ! $(is_test domain "$d") ]]; then
                err "请提供有效域名. 用法: sb domain add <domain> [weight] [region]"
            fi
            if [[ ! $w =~ ^[0-9]+$ ]]; then
                err "weight 需要是数字 (1-20)."
            fi
            [[ $w -lt 1 ]] && w=1
            [[ $w -gt 20 ]] && w=20

            grep -Fvx "$d" "$domain_disabled_file" > "${domain_disabled_file}.tmp" 2> /dev/null || true
            mv -f "${domain_disabled_file}.tmp" "$domain_disabled_file" 2> /dev/null || true
            grep -Ev "^${d//./\\.}\|" "$domain_custom_file" > "${domain_custom_file}.tmp" 2> /dev/null || true
            mv -f "${domain_custom_file}.tmp" "$domain_custom_file" 2> /dev/null || true
            echo "$d|$w|$r" >> "$domain_custom_file"
            msg "\n已添加域名: $d (weight=$w, region=$r)\n"
            ;;
        del | rm)
            d="$(domain_normalize "$2")"
            if [[ -z $d ]]; then
                err "请提供要删除的域名. 用法: sb domain del <domain>"
            fi
            grep -Ev "^${d//./\\.}\|" "$domain_custom_file" > "${domain_custom_file}.tmp" 2> /dev/null || true
            mv -f "${domain_custom_file}.tmp" "$domain_custom_file" 2> /dev/null || true
            if ! grep -Fxq "$d" "$domain_disabled_file"; then
                echo "$d" >> "$domain_disabled_file"
            fi
            msg "\n已移除域名: $d (内置域名将进入禁用列表)\n"
            ;;
        test)
            if [[ $2 && $(is_test domain "$(domain_normalize "$2")") ]]; then
                d="$(domain_normalize "$2")"
                if domain_is_healthy "$d"; then
                    msg "\n[OK] $d 可用\n"
                else
                    err "[FAIL] $d 不可用"
                fi
                return
            fi

            region="$(domain_sanitize_region "$2")"
            if [[ $3 ]]; then
                d="$(domain_normalize "$3")"
                if domain_is_healthy "$d"; then
                    msg "\n[OK] $d 可用\n"
                else
                    err "[FAIL] $d 不可用"
                fi
                return
            fi
            ok_cnt=0
            fail_cnt=0
            total=0
            msg "\n开始健康检查 region=$region ..."
            while IFS= read -r line; do
                IFS='|' read -r d src w r <<< "$line"
                ((total++))
                if domain_is_healthy "$d"; then
                    ((ok_cnt++))
                    msg "[OK] $d"
                else
                    ((fail_cnt++))
                    msg "[FAIL] $d"
                fi
            done < <(domain_collect_pool "$region" | sort)
            msg "\n检查完成: total=$total ok=$ok_cnt fail=$fail_cnt\n"
            ;;
        pick)
            region="$(domain_sanitize_region "$2")"
            d="$(domain_pick_for_reality "$region")"
            msg "$d"
            ;;
        *)
            msg
            msg "Domain 管理命令:"
            msg "  sb domain list [region]"
            msg "  sb domain add <domain> [weight] [region]"
            msg "  sb domain del <domain>"
            msg "  sb domain test [region] [domain]"
            msg "  sb domain pick [region]"
            msg
            ;;
    esac
}
