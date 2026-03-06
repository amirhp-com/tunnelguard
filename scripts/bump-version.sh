#!/bin/bash
# ──────────────────────────────────────────────────────────
# TunnelGuard — Auto Version & Build Number Script
# ──────────────────────────────────────────────────────────
# Usage:
#   ./scripts/bump-version.sh          # update Info.plist then build
#   ./scripts/bump-version.sh --dry    # preview without writing
#
# Version:  derived from the latest git tag (e.g. v1.2.0 → 1.2.0)
# Build:    git commit count on current branch
#
# How to tag a release:
#   git tag v1.1.0
#   git push --tags
# ──────────────────────────────────────────────────────────

set -euo pipefail

PLIST="Info.plist"
DRY_RUN=false

if [[ "${1:-}" == "--dry" ]]; then
    DRY_RUN=true
fi

# Ensure we're in the project root (where Info.plist lives)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

if [[ ! -f "$PLIST" ]]; then
    echo "Error: $PLIST not found in $PROJECT_DIR"
    exit 1
fi

# ── Build number: total git commit count ──
if git rev-parse --git-dir > /dev/null 2>&1; then
    BUILD=$(git rev-list --count HEAD 2>/dev/null || echo "1")
else
    echo "Warning: not a git repo, using build number 1"
    BUILD="1"
fi

# ── Version: latest git tag (strip leading 'v'), fallback to current plist value ──
if git rev-parse --git-dir > /dev/null 2>&1; then
    TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [[ -n "$TAG" ]]; then
        VERSION="${TAG#v}"
    else
        VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST" 2>/dev/null || echo "1.0.0")
        echo "Warning: no git tags found, keeping current version $VERSION"
    fi
else
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST" 2>/dev/null || echo "1.0.0")
fi

# ── Apply ──
echo "╔══════════════════════════════════════╗"
echo "║  TunnelGuard Version Bump            ║"
echo "╠══════════════════════════════════════╣"
echo "║  Version : $VERSION"
echo "║  Build   : $BUILD"
echo "╚══════════════════════════════════════╝"

if [[ "$DRY_RUN" == true ]]; then
    echo "(dry run — no files modified)"
    exit 0
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"

echo "✅ Info.plist updated"
