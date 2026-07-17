#!/bin/bash

query_uri_encode() {
    local LC_ALL=C
    local input=${1:-} output="" char="" encoded="" i=0

    for ((i = 0; i < ${#input}; i++)); do
        char=${input:i:1}
        case $char in
            [a-zA-Z0-9.~_-]) output+=$char ;;
            *)
                printf -v encoded '%%%02X' "'$char"
                output+=$encoded
                ;;
        esac
    done
    printf '%s' "$output"
}

query_uri_base64url() {
    printf '%s' "${1:-}" | base64 -w 0 | tr '+/' '-_' | tr -d '='
}

query_uri_host_name() {
    local host=${1:-}

    host=${host#[}
    host=${host%]}
    printf '%s' "$host"
}

query_uri_params_reset() {
    is_uri_query=""
}

query_uri_param() {
    local key=$1 value=${2:-}

    if [[ -z $value ]]; then return; fi
    key=$(query_uri_encode "$key")
    value=$(query_uri_encode "$value")
    if [[ $is_uri_query ]]; then
        is_uri_query+="&$key=$value"
    else
        is_uri_query="$key=$value"
    fi
}

query_uri_query() {
    if [[ $is_uri_query ]]; then
        printf '?%s' "$is_uri_query"
    fi
}
