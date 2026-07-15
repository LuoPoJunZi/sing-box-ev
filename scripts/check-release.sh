#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

version="$(grep -oE 'is_sh_ver="[^"]+"' src/init.sh | head -n 1 | cut -d '"' -f 2 || true)"

if [[ -z $version ]]; then
    echo "[release] missing is_sh_ver in src/init.sh"
    exit 1
fi

if [[ ! $version =~ ^v([0-9]{2})\.([1-9]|1[0-2])\.([1-9]|[12][0-9]|3[01])$ ]]; then
    echo "[release] invalid version format: $version"
    echo "[release] expected date version: vYY.M.D (example: v26.7.15)"
    exit 1
fi

release_date="20${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]}"
normalized_version="$(date -d "$release_date" '+v%y.%-m.%-d' 2> /dev/null || true)"
if [[ $normalized_version != "$version" ]]; then
    echo "[release] invalid calendar date: $version"
    exit 1
fi

if [[ ! -f RELEASE_NOTES.md ]]; then
    echo "[release] missing RELEASE_NOTES.md"
    exit 1
fi

notes_body="$(
    awk -v version="$version" '
        $0 == "## " version { in_version=1; next }
        in_version && /^## / { exit }
        in_version && /^### / && !in_section { in_section=1; print; next }
        in_section && /^### / { exit }
        in_section { print }
    ' RELEASE_NOTES.md
)"

if [[ -z ${notes_body//[[:space:]]/} ]]; then
    echo "[release] missing release notes body for $version"
    exit 1
fi

first_notes_line="$(printf '%s\n' "$notes_body" | head -n 1)"
if [[ $first_notes_line != "### 主要变化" ]]; then
    echo "[release] first release notes section must be: ### 主要变化"
    exit 1
fi

if grep -qE '发布流程|验证建议' <<< "$notes_body"; then
    echo "[release] release body for $version contains internal process text"
    exit 1
fi

if git rev-parse -q --verify "refs/tags/$version" > /dev/null; then
    if [[ ${RELEASE_CHECK_STRICT_TAG:-0} == "1" ]]; then
        echo "[release] local tag already exists: $version"
        exit 1
    fi
    echo "[release] note: local tag already exists: $version"
fi

echo "[release] ok: $version"
