#!/bin/bash
# ──────────────────────────────────────────────────────────
# TunnelGuard — Build with auto-versioning
# ──────────────────────────────────────────────────────────
# Usage:
#   ./scripts/build.sh              # release build
#   ./scripts/build.sh debug        # debug build
# ──────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

CONFIG="${1:-release}"

echo "── Bumping version ──"
"$SCRIPT_DIR/bump-version.sh"

echo ""
echo "── Building ($CONFIG) ──"
swift build -c "$CONFIG"

echo ""
echo "✅ Build complete"
