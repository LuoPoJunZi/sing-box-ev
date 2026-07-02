#!/bin/bash

query_tls_pin_reset() {
    tls_pin_checked=
    tls_pin_cert_sha256_hex=
    tls_pin_cert_sha256_colon=
    tls_pin_pubkey_sha256_b64=
    tls_pin_error=
    tls_pin_pubkey_error=
}

query_tls_pin_prepare() {
    local fingerprint=""

    if [[ $tls_pin_checked ]]; then return; fi
    tls_pin_checked=1

    if ! command -v openssl > /dev/null 2>&1; then
        tls_pin_error="openssl 缺失，无法计算证书指纹"
        return
    fi
    if [[ ! -f $is_tls_cer ]]; then
        tls_pin_error="证书文件不存在: $is_tls_cer"
        return
    fi

    fingerprint=$(openssl x509 -noout -fingerprint -sha256 -in "$is_tls_cer" 2> /dev/null | sed 's/^.*=//')
    if [[ -z $fingerprint ]]; then
        tls_pin_error="无法读取证书 SHA256 指纹: $is_tls_cer"
        return
    fi

    tls_pin_cert_sha256_colon=$fingerprint
    tls_pin_cert_sha256_hex=$(echo "$fingerprint" | tr -d ':' | tr 'A-F' 'a-f')
    tls_pin_pubkey_sha256_b64=$(openssl x509 -in "$is_tls_cer" -pubkey -noout 2> /dev/null |
        openssl pkey -pubin -outform der 2> /dev/null |
        openssl dgst -sha256 -binary 2> /dev/null |
        openssl enc -base64 2> /dev/null)

    if [[ -z $tls_pin_pubkey_sha256_b64 ]]; then
        tls_pin_pubkey_error="无法计算证书公钥 SHA256 指纹"
    fi
}

query_tls_pin_print_value() {
    local label=$1 value=$2

    if [[ $value ]]; then
        msg "$label = $(ui_key "$value")"
    fi
}

query_tls_pin_print_header() {
    msg "------------- 客户端兼容说明 -------------"
    msg "$(ui_warn "[兼容链接]") 当前 URL 保留导入兼容参数，方便旧客户端继续使用。"
    msg "$(ui_success "[推荐配置]") 新客户端建议关闭跳过证书验证，并按下面配置固定证书指纹。"
}

query_tls_pin_print_next_step() {
    local client_hint=$1

    msg "下一步:"
    msg "  1. 先用上方 URL 导入客户端，确认地址、端口、密码无误。"
    msg "  2. 在客户端 TLS 设置中关闭跳过证书验证。"
    msg "  3. 按 $client_hint 填入下面的证书固定指纹后再测试连通。"
}

query_tls_pin_print_snippet() {
    local profile=$1
    local server_name=${2:-$is_addr}

    query_tls_pin_prepare

    if [[ $profile == "trojan-self-signed" ]]; then
        msg "------------- 客户端兼容说明 -------------"
        msg "$(ui_warn "[兼容策略]") Trojan 保留无域名 / 自签证书路线，优先保证旧配置可继续导入。"
        warn "Trojan 按当前项目策略保留无域名 / 自签证书兼容：分享链接仍包含 allowInsecure=1。"
        msg "建议：如果客户端未来禁用 allowInsecure，请优先新建 Reality、CFtunnel 或有域名 TLS 节点。"
        return
    fi

    query_tls_pin_print_header
    warn "当前分享链接仍保留兼容导入参数；推荐在客户端改用证书固定指纹，避免长期依赖跳过证书验证。"
    if [[ $tls_pin_error ]]; then
        warn "$tls_pin_error"
        return
    fi

    case $profile in
        hysteria2)
            query_tls_pin_print_value "Hysteria2 pinSHA256" "$tls_pin_cert_sha256_colon"
            query_tls_pin_print_next_step "Hysteria2 pinSHA256"
            msg "Hysteria2 客户端示例:"
            msg "tls:"
            msg "  sni: $server_name"
            msg "  insecure: false"
            msg "  pinSHA256: $tls_pin_cert_sha256_colon"
            ;;
        tuic)
            if [[ $tls_pin_pubkey_error ]]; then
                warn "$tls_pin_pubkey_error"
                return
            fi
            query_tls_pin_print_value "sing-box certificate_public_key_sha256" "$tls_pin_pubkey_sha256_b64"
            query_tls_pin_print_next_step "sing-box certificate_public_key_sha256"
            msg "TUIC / sing-box 客户端 TLS 示例:"
            msg "\"tls\": {"
            msg "  \"enabled\": true,"
            msg "  \"server_name\": \"$server_name\","
            msg "  \"insecure\": false,"
            msg "  \"alpn\": [\"h3\"],"
            msg "  \"certificate_public_key_sha256\": [\"$tls_pin_pubkey_sha256_b64\"]"
            msg "}"
            ;;
        vmess-quic)
            query_tls_pin_print_value "Xray pinnedPeerCertSha256" "$tls_pin_cert_sha256_hex"
            query_tls_pin_print_next_step "Xray pinnedPeerCertSha256"
            msg "VMess-QUIC / Xray 客户端 TLS 示例:"
            msg "\"tlsSettings\": {"
            msg "  \"serverName\": \"$server_name\","
            msg "  \"allowInsecure\": false,"
            msg "  \"alpn\": [\"h3\"],"
            msg "  \"pinnedPeerCertSha256\": \"$tls_pin_cert_sha256_hex\""
            msg "}"
            warn "VMess-QUIC 属于兼容性风险较高的旧方案；新建节点时更推荐 Reality、CFtunnel 或有域名 TLS。"
            ;;
    esac
}
