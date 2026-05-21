#!/usr/bin/env bash
set -euo pipefail
TARGET="${1:-$PWD/ai-toolkit}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "${TARGET}"
rsync -av --delete --exclude '.git' --exclude 'dist' --exclude '.cache' "${SRC}/" "${TARGET}/"
echo "Installed toolkit to ${TARGET}"
