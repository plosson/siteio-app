#!/usr/bin/env bash
# Builds, signs, notarizes and publishes siteio Companion to GitHub Releases (pkg, zip and Sparkle appcast), then
# updates its Homebrew cask. The steps live in the houlahop-mac-release submodule: see scripts/mac-release/lib.sh
# for what they need.
# Usage: DEVELOPMENT_TEAM=XXXXXXXXXX scripts/release.sh 0.1.0
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ -f scripts/mac-release/lib.sh ]] || git submodule update --init scripts/mac-release
source scripts/mac-release/lib.sh

release_version "${1:-}"
: "${DEVELOPMENT_TEAM:?set DEVELOPMENT_TEAM to your Apple team ID}"
TEAM="$DEVELOPMENT_TEAM"
MACOS="$ROOT/apps/macos"
NAME="siteio Companion"
FILE_NAME="siteio-Companion-$VERSION"
REPO="plosson/siteio-app"
BUNDLE_ID="com.plosson.siteio-companion"
PROJECT="$MACOS/SiteioCompanion.xcodeproj"
SCHEME="SiteioCompanion"
BUILD="$MACOS/build/release"
SPARKLE_ACCOUNT="siteio-companion"
CASK="siteio-companion"
CASK_DESC="Desktop companion for siteio servers"
MIN_MACOS="sonoma"

release_check_clean
release_clean_build

cd "$MACOS"
xcodegen generate
xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -derivedDataPath "$MACOS/build"

release_archive
release_export
release_notarize_app
release_pkg
release_appcast
release_publish
release_cask
