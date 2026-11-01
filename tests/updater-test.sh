#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/build/versions.sh"; . "$ROOT/build/msc.sh"
fail() { echo "FAIL: $1"; exit 1; }
app="$WORK/updater/ninja-updater.app"
bin="$app/Contents/MacOS/ninja-updater"
[ -x "$bin" ] || { echo "not built (no $bin) -- run build/package-pkg.sh; skipping"; exit 77; }
CL="$(sh "$ROOT/build/fetch-clang22.sh")"
if [ "$(sh "$ROOT/build/mode.sh")" = native ]; then want='x86_64 EXECUTE 10.9 10.9'
else want='x86_64 EXECUTE 10.9 10.9
arm64 EXECUTE 11.0 11.3'; fi
got="$(LIPO="$CL/bin/llvm-lipo" OTOOL="$CL/bin/llvm-otool" sh "$SHIPYARD_SCRIPTS/macho-slices.sh" "$bin")"
[ "$got" = "$want" ] || fail "the updater's slices must be
$want
(x86_64 at 10.9 on the 10.9 SDK; arm64 at 11.0 on the 11.3 SDK, or Apple Silicon prompts for Rosetta), got
$got"
SD="$(sh "$SHIPYARD_SCRIPTS/fetch_stevedore.sh")"
feed="$("$SD" plist get "$app/Contents/Info.plist" SUFeedURL)"
[ "$feed" = https://github.com/Mavergreen/ninja/releases/latest/download/ninja.xml ] || fail "the updater must poll ninja's feed (got $feed)"
sh "$SHIPYARD_SCRIPTS/assert_sparkle_pristine.sh" "$app/Contents/Frameworks/Sparkle.framework" \
  "$(sh "$SHIPYARD_SCRIPTS/fetch_sparkle_framework.sh")" || fail "the updater's Sparkle.framework must be the pinned one, symlinks and seal intact"
grep -q 'build/build-updater.sh' "$ROOT/build/package-pkg.sh" || fail "package-pkg.sh must build the updater with build/build-updater.sh"
if grep -n '/usr/bin/clang\|sw_vers' "$ROOT/build/build-updater.sh" | grep -v '^[0-9]*:#'; then
  fail "build-updater.sh builds with clang22 on every host, never Apple's clang"
fi
echo "PASS: updater"
