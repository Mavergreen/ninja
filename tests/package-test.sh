#!/bin/sh
# platform: macOS-only -- pkgutil expands the pkg and PlistBuddy reads the updater
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/build/versions.sh"; . "$ROOT/build/msc.sh"
fail() { echo "FAIL: $1"; exit 1; }
set -- "$ROOT"/dist/ninja-*.pkg
[ -f "$1" ] || { echo "not packaged (no dist/ninja-*.pkg) -- run build/build.sh, then build/package-pkg.sh; skipping"; exit 77; }
[ "$#" -eq 1 ] || fail "dist/ holds $# ninja pkgs; one build makes one"
PKG="$1"
mode="${MAVERICKS_MODE:-$(sh "$SHIPYARD_SCRIPTS/mavericks_mode.sh")}"
case "$mode:$(basename "$PKG")" in
  cross:ninja-*-x86_64-dev.pkg) fail "a cross build makes the release pkg, not a -x86_64-dev one" ;;
  native:*-x86_64-dev.pkg) : ;;
  native:*) fail "a 10.9 build must name its pkg -x86_64-dev so it cannot pass for a release" ;;
esac
t="$(mktemp -d "${TMPDIR:-/tmp}/ninja-package-test.XXXXXX")"; trap 'rm -rf "$t"' EXIT INT TERM
pkgutil --expand "$PKG" "$t/x"
comp="$(find "$t/x" -maxdepth 1 -name '*.pkg' ! -name 'mavergreen-base*' | head -1)"
[ -f "$comp/Payload" ] || fail "$PKG holds no ninja component"
mkdir "$t/root"; tar -xf "$comp/Payload" -C "$t/root"
P="$t/root$PREFIX"
for f in bin/ninja share/doc/ninja/COPYING mavergreen.plist; do [ -s "$P/$f" ] || fail "the pkg must install $PREFIX/$f"; done
cmp -s "$P/bin/ninja" "$STAGE/bin/ninja" || fail "the pkg's ninja must be the one build.sh gated"
if [ "$mode" = cross ]; then want="x86_64 arm64"; else want=x86_64; fi
[ "$(lipo -info "$P/bin/ninja" | sed -n "s/.*: //p" | xargs)" = "$want" ] || fail "the pkg's ninja must be '$want'"
app="$t/root/Library/Application Support/Mavergreen/ninja-updater.app"
[ -d "$app" ] || fail "the pkg must install ninja-updater.app"
feed="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$app/Contents/Info.plist")"
[ "$feed" = https://github.com/Mavergreen/ninja/releases/latest/download/ninja.xml ] || fail "the updater must poll ninja's feed (got $feed)"
if otool -L "$app/Contents/MacOS/"* | grep -q "$PREFIX"; then fail "the updater must not link the product it updates"; fi
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
  cross) [ "$declared" = x86_64,arm64 ] || fail "the release pkg installs on Intel and Apple Silicon (declares '$declared')" ;;
  *) [ "$declared" = x86_64 ] || fail "a 10.9 dev pkg declares hostArchitectures x86_64 only (declares '$declared')" ;;
esac
[ "$declared" = "$(lipo -info "$P/bin/ninja" | sed -n "s/.*: //p" | xargs | tr ' ' ',')" ] || fail "the declared host architectures '$declared' must match the payload ninja's slices"
echo "PASS: package"
