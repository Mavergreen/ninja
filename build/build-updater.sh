#!/bin/sh
# platform: macOS-only -- builds a Cocoa app with Apple's clang, as shipyard's updater recipe requires
#   usage: build-updater.sh     prints ninja-updater.app: x86_64 10.9 and, on macOS 11+, arm64 11.0, merged
# spec: tests/updater-test.sh -- Apple Silicon installs this pkg too; an x86_64-only updater prompts for Rosetta there
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_ROOT/build/versions.sh"
. "$REPO_ROOT/build/msc.sh"
SC="$(command -v shipyard-cmake || echo /usr/local/mavergreen/bin/shipyard-cmake)"
TC="$(dirname "$SHIPYARD_SCRIPTS")/MavericksToolchain.cmake"
major="$(sw_vers -productVersion | cut -d. -f1)"
slices="x86_64:10.9"; [ "$major" -ge 11 ] && slices="x86_64:10.9 arm64:11.0"
for s in $slices; do
  a="${s%%:*}"; floor="${s#*:}"
  OBJC=/usr/bin/clang "$SC" -S "$REPO_ROOT" -B "$WORK/updater-$a" -DCMAKE_OBJC_COMPILER=/usr/bin/clang \
    -DCMAKE_OSX_ARCHITECTURES="$a" -DCMAKE_OSX_DEPLOYMENT_TARGET="$floor" -DCMAKE_TOOLCHAIN_FILE="$TC" >&2
  "$SC" --build "$WORK/updater-$a" >&2
done
out="$WORK/updater/ninja-updater.app"; rm -rf "$out"; mkdir -p "$WORK/updater"
if [ "$major" -ge 11 ]; then
  sh "$SHIPYARD_SCRIPTS/lipo-merge-tree.sh" --a "$WORK/updater-x86_64/ninja-updater.app" \
    --b "$WORK/updater-arm64/ninja-updater.app" --out "$out" --require-archs "x86_64 arm64" >&2
else
  cp -R "$WORK/updater-x86_64/ninja-updater.app" "$out"
fi
echo "$out"
