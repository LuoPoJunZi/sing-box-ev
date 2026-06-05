#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

version="$(grep -oE 'is_sh_ver="[^"]+"' src/init.sh | head -n 1 | cut -d '"' -f 2 || true)"

if [[ -z $version ]]; then
    echo "[release] missing is_sh_ver in src/init.sh"
    exit 1
fi

if [[ ! $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[release] invalid version format: $version"
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
    echo "[release] local tag already exists: $version"
    exit 1
fi

echo "[release] ok: $version"
