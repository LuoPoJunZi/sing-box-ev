#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v shellcheck > /dev/null 2>&1; then
    echo "shellcheck not found. Please install shellcheck first."
    exit 1
fi

if ! command -v shfmt > /dev/null 2>&1; then
    echo "shfmt not found. Please install shfmt first."
    exit 1
fi

echo "[lint] shellcheck"
while IFS= read -r -d '' file; do
    echo "shellcheck: $file"
    shellcheck -S error -e SC2148,SC2068,SC2145,SC2199 "$file"
done < <(find . -type f -name "*.sh" -not -path "./.git/*" -print0)

echo "[lint] shfmt"
shfmt -d -i 4 -ci -sr install.sh sing-box.sh src scripts

echo "[lint] structure"
scripts/check-structure.sh

echo "[lint] release"
bash scripts/check-release.sh

echo "[lint] regression script syntax"
bash -n scripts/regression-cli.sh

echo "[lint] done"
