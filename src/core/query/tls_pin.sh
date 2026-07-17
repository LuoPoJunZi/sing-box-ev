#!/bin/bash

query_tls_pin_reset() {
    tls_pin_checked=
    tls_pin_cert_sha256_hex=
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
    msg "$(ui_success "[固定指纹]") 分享链接已携带证书指纹，适配新版 v2rayN / Xray。"
    msg "$(ui_warn "[旧版兼容]") 链接仍携带 insecure=1，未识别指纹字段的客户端会继续按旧方式导入。"
    msg "重新生成服务器证书后指纹会变化，请重新导入节点。"
}

query_tls_pin_print_snippet() {
    local profile=$1
    local server_name=${2:-$is_addr}

    query_tls_pin_prepare
    if [[ $tls_pin_error ]]; then
        msg "------------- 客户端兼容说明 -------------"
        warn "[指纹缺失] $tls_pin_error"
        warn "当前链接只能保留 insecure=1 兼容导入；修复证书或 openssl 后请重新导出。"
        return
    fi
    query_tls_pin_print_header

    case $profile in
        hysteria2)
            query_tls_pin_print_value "Hysteria2 pinSHA256" "$tls_pin_cert_sha256_hex"
            msg "Hysteria2 官方客户端 TLS 示例:"
            msg "tls:"
            msg "  sni: $server_name"
            msg "  insecure: true"
            msg "  pinSHA256: $tls_pin_cert_sha256_hex"
            msg "说明: 自签证书应同时使用 insecure: true 和 pinSHA256；指纹负责锁定证书。"
            ;;
        tuic)
            query_tls_pin_print_value "v2rayN / Xray pcs" "$tls_pin_cert_sha256_hex"
            if [[ $tls_pin_pubkey_error ]]; then
                warn "$tls_pin_pubkey_error"
                return
            fi
            query_tls_pin_print_value "sing-box certificate_public_key_sha256" "$tls_pin_pubkey_sha256_b64"
            msg "TUIC / sing-box 客户端 TLS 示例:"
            msg "\"tls\": {"
            msg "  \"enabled\": true,"
            msg "  \"server_name\": \"$server_name\","
            msg "  \"insecure\": false,"
            msg "  \"alpn\": [\"h3\"],"
            msg "  \"certificate_public_key_sha256\": [\"$tls_pin_pubkey_sha256_b64\"]"
            msg "}"
            ;;
        trojan-self-signed)
            query_tls_pin_print_value "v2rayN / Xray pcs" "$tls_pin_cert_sha256_hex"
            msg "Trojan / Xray 客户端 TLS 示例:"
            msg '"tlsSettings": {'
            msg "  \"serverName\": \"$server_name\","
            msg '  "allowInsecure": false,'
            msg "  \"pinnedPeerCertSha256\": \"$tls_pin_cert_sha256_hex\""
            msg '}'
            msg "说明: 按项目约定继续使用无域名 / 自签证书；新版 v2rayN 会从 URL 的 pcs 读取固定指纹。"
            ;;
        vmess-quic)
            query_tls_pin_print_value "v2rayN / Xray pcs" "$tls_pin_cert_sha256_hex"
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
