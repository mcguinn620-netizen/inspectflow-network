#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_DIR="${ROOT}/.cache/Swift-Agent-Skills"
UPSTREAM_URL="https://github.com/twostraws/Swift-Agent-Skills"
mkdir -p "${ROOT}/.cache"
if [[ -d "${UPSTREAM_DIR}/.git" ]]; then
  git -C "${UPSTREAM_DIR}" pull --ff-only
else
  git clone "${UPSTREAM_URL}" "${UPSTREAM_DIR}"
fi
cp "${UPSTREAM_DIR}/README.md" "${ROOT}/examples/upstream-swift-agent-skills.md"
echo "Synced upstream index into examples/."
