#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/dist"
mkdir -p "${OUT}"
rm -f "${OUT}"/ai-toolkit-*.zip
STAMP="$(date +%Y%m%d-%H%M%S)"
zip -r "${OUT}/ai-toolkit-${STAMP}.zip" "${ROOT}" -x "*/.git/*" "*/dist/*" "*/.cache/*"
echo "Exported ${OUT}/ai-toolkit-${STAMP}.zip"
