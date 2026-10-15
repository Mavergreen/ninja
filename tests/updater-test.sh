#!/bin/sh
# platform: macOS-only -- builds a Cocoa app and reads it with lipo and PlistBuddy
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/build/versions.sh"; . "$ROOT/build/msc.sh"
fail() { echo "FAIL: $1"; exit 1; }
app="$(sh "$ROOT/build/build-updater.sh")" || fail "build-updater.sh failed"
bin="$app/Contents/MacOS/ninja-updater"
[ -x "$bin" ] || fail "no updater binary at $bin"
if [ "$(sh "$SHIPYARD_SCRIPTS/mavericks_mode.sh")" = cross ]; then want="x86_64 arm64"; else want=x86_64; fi
[ "$(lipo -info "$bin" | sed -n "s/.*: //p" | xargs)" = "$want" ] || fail "the updater must be '$want' (got $(lipo -info "$bin" | sed -n "s/.*: //p" | xargs)): an x86_64-only one prompts for Rosetta on Apple Silicon"
feed="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$app/Contents/Info.plist")"
[ "$feed" = https://github.com/Mavergreen/ninja/releases/latest/download/ninja.xml ] || fail "the updater must poll ninja's feed (got $feed)"
echo "PASS: updater"
