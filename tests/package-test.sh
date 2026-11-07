#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/build/versions.sh"; . "$ROOT/build/msc.sh"
fail() { echo "FAIL: $1"; exit 1; }
set -- "$ROOT"/dist/ninja-*.pkg
[ -f "$1" ] || { echo "not packaged (no dist/ninja-*.pkg) -- run build/build.sh, then build/package-pkg.sh; skipping"; exit 77; }
[ "$#" -eq 1 ] || fail "dist/ holds $# ninja pkgs; one build makes one"
PKG="$1"
mode="$(sh "$ROOT/build/mode.sh")"
case "$mode:$(basename "$PKG")" in
  native:*-x86_64-dev.pkg) : ;;
  native:*) fail "a 10.9 build must name its pkg -x86_64-dev so it cannot pass for a release" ;;
  *:ninja-*-x86_64-dev.pkg) fail "a $mode build makes the release pkg, not a -x86_64-dev one" ;;
esac
CL="$(sh "$ROOT/build/fetch-clang22.sh")"
SD="$(sh "$SHIPYARD_SCRIPTS/fetch_stevedore.sh")"
archs_of() { "$CL/bin/llvm-lipo" -info "$1" | sed -n "s/.*: //p" | xargs; }
t="$(mktemp -d "${TMPDIR:-/tmp}/ninja-package-test.XXXXXX")"; trap 'rm -rf "$t"' EXIT INT TERM
"$SD" expand "$PKG" "$t/x" >/dev/null
comp="$(dirname "$(grep -l "identifier=\"$IDENTIFIER\"" "$t"/x/*/PackageInfo)")"
[ -f "$comp/Payload" ] || fail "$PKG holds no ninja component"
mkdir "$t/root"; gzip -dc < "$comp/Payload" > "$t/payload.cpio" || fail "the pkg's payload must decompress"
( cd "$t/root" && cpio -id --quiet < "$t/payload.cpio" ) || fail "cpio must extract the pkg's payload"
P="$t/root$PREFIX"
for f in bin/ninja share/doc/ninja/COPYING mavergreen.plist; do [ -s "$P/$f" ] || fail "the pkg must install $PREFIX/$f"; done
cmp -s "$P/bin/ninja" "$STAGE/bin/ninja" || fail "the pkg's ninja must be the one build.sh gated"
if [ "$mode" = native ]; then want=x86_64; else want="x86_64 arm64"; fi
[ "$(archs_of "$P/bin/ninja")" = "$want" ] || fail "the pkg's ninja must be '$want'"
app="$t/root/Library/Application Support/Mavergreen/ninja-updater.app"
[ -d "$app" ] || fail "the pkg must install ninja-updater.app"
feed="$("$SD" plist get "$app/Contents/Info.plist" SUFeedURL)"
[ "$feed" = https://github.com/Mavergreen/ninja/releases/latest/download/ninja.xml ] || fail "the updater must poll ninja's feed (got $feed)"
[ "$(archs_of "$app/Contents/MacOS/ninja-updater")" = "$want" ] || fail "the pkg's updater must be '$want': an x86_64-only one prompts for Rosetta on Apple Silicon"
if "$CL/bin/llvm-otool" -L "$app/Contents/MacOS/ninja-updater" | grep -q "$PREFIX"; then fail "the updater must not link the product it updates"; fi
sh "$SHIPYARD_SCRIPTS/assert_sparkle_pristine.sh" "$app/Contents/Frameworks/Sparkle.framework" \
  "$(sh "$SHIPYARD_SCRIPTS/fetch_sparkle_framework.sh")" || fail "the embedded Sparkle.framework must be the pinned one"
[ -f "$t/root/Library/LaunchAgents/dev.mavergreen.ninja-updatecheck.plist" ] || fail "the pkg must install the update-check LaunchAgent"
sh "$SHIPYARD_SCRIPTS/assert_pkg_installs_in_place.sh" "$PKG" || fail "the pkg must neither relocate nor version-skip a bundle"
d="$t/x/Distribution"
grep -q '<os-version min="10.9.5"' "$d" || fail "the Distribution must declare the 10.9.5 install floor"
[ "$(sed -n 's/.*<pkg-ref id="\([^"]*\)".*/\1/p' "$d" | sed -n 1p)" = dev.mavergreen.base ] || fail "dev.mavergreen.base must be first"
grep -q "id=\"$IDENTIFIER\"" "$d" || fail "the pkg must carry $IDENTIFIER"
declared="$(sed -n 's/.*hostArchitectures="\([^"]*\)".*/\1/p' "$d")"
case "$mode" in
  native) [ "$declared" = x86_64 ] || fail "a 10.9 dev pkg declares hostArchitectures x86_64 only (declares '$declared')" ;;
  *) [ "$declared" = x86_64,arm64 ] || fail "the release pkg installs on Intel and Apple Silicon (declares '$declared')" ;;
esac
[ "$declared" = "$(archs_of "$P/bin/ninja" | tr ' ' ',')" ] || fail "the declared host architectures '$declared' must match the payload ninja's slices"
info="$ROOT/dist/build-info-$([ "$mode" = native ] && echo dev || echo release).txt"
[ -f "$info" ] || fail "packaging must write $info"
key() { sed -n "s/^$1=//p" "$info"; }
tool_line() { "$1" --version 2>/dev/null | sed -n 1p | tr -d '\n' | tr -s '[:space:]' '_'; }
cached() { sed -n "s/^$1:[A-Z]*=//p" "$2/CMakeCache.txt"; }
for d in "$WORK"/b-*; do
  [ "$(key build-cmake)" = "$(tool_line "$(cached CMAKE_COMMAND "$d")")" ] \
    || fail "build-info must name the cmake that configured $d ($(tool_line "$(cached CMAKE_COMMAND "$d")")), not '$(key build-cmake)'"
  mp="$(cached CMAKE_MAKE_PROGRAM "$d")"
  case "$(basename "$mp")" in
    ninja) [ "$(key build-ninja)" = "$(tool_line "$mp")" ] || fail "build-info must name the ninja that built $d ($(tool_line "$mp")), not '$(key build-ninja)'"
           [ -z "$(key make)" ] || fail "build-info names make, but $d was built by ninja" ;;
    make) [ "$(key make)" = "$MAKE_VERSION" ] || fail "build-info must name the family make $MAKE_VERSION that built $d, not '$(key make)'" ;;
    *) fail "$d was built by $mp, which build-info cannot name" ;;
  esac
done
for d in "$WORK"/updater-*; do
  [ "$(key updater-cmake)" = "$(tool_line "$(cached CMAKE_COMMAND "$d")")" ] || fail "build-info must name the cmake that configured $d"
  mp="$(cached CMAKE_MAKE_PROGRAM "$d")"
  [ "$(key updater-build-tool)" = "$(basename "$mp"):$(tool_line "$mp")" ] || fail "build-info must name the build tool that built $d ($mp)"
done
echo "PASS: package"
