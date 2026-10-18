#!/bin/sh
# platform: macOS-only -- installer, sw_vers and the mavergreen helper; meant for real 10.9
#   usage: check-release-on-10.9.sh <version> [<ninja_test>]
#          Run ON Mac OS X 10.9: downloads ninja-<version>.pkg, verifies it against SHA256SUMS, installs it
#          (sudo), uses ninja from a login shell, runs ninja_test if given, and uninstalls it. One PASS/FAIL
#          line per step; exit 1 if any failed. MAVERICKS_RELEASE_BASE replaces the release's URL
#          (file:///path/to/dist rehearses against a local build).
set -u
V="${1:-}"; NT="${2:-}"
[ -n "$V" ] || { echo "usage: check-release-on-10.9.sh <version> [<ninja_test>]   (e.g. 1.13.2-mavericks.1)" >&2; exit 2; }
os="$(sw_vers -productVersion)"
case "$os" in 10.9|10.9.*) : ;; *) echo "check-release-on-10.9.sh: run this on Mac OS X 10.9 (this is $os)" >&2; exit 2 ;; esac
HERE="$(cd "$(dirname "$0")/.." && pwd)"
base="${MAVERICKS_RELEASE_BASE:-https://github.com/Mavergreen/ninja/releases/download/$V}"
pkg="ninja-$V.pkg"
w="$(mktemp -d "${TMPDIR:-/tmp}/ninja-release-check.XXXXXX")"
bad=0
step() { name="$1"; shift
  if ( "$@" ) > "$w/$name.log" 2>&1; then echo "PASS $name"; else echo "FAIL $name (log: $w/$name.log)"; bad=1; fi; }
fetch() { curl -fsSL -o "$w/$pkg" "$base/$pkg" && curl -fsSL -o "$w/SHA256SUMS" "$base/SHA256SUMS" || return 1
  ( cd "$w" && grep " $pkg\$" SHA256SUMS | shasum -a 256 -c - ); }
install_pkg() { sudo installer -pkg "$w/$pkg" -target / && /usr/local/bin/mavergreen check; }
# platform: /usr/local/mavergreen/bin reaches PATH only through a login shell's paths.d
L() { /bin/bash -lc "$1"; }
login_path() { [ "$(L 'command -v ninja')" = /usr/local/mavergreen/bin/ninja ]; }
# platform: a 10.9 box can put another ninja ahead on PATH (pkgsrc's, on ultimate-hat), which would answer instead
version() { [ "$(/usr/local/mavergreen/bin/ninja --version)" = "${V%-mavericks.*}" ]; }
smoke() { sh "$HERE/build/smoke.sh" /usr/local/mavergreen/bin/ninja; }
ninja_test() { sh "$HERE/build/run-ninja-test.sh" "$NT" "$HERE/tests/known-failures-x86_64.txt"; }
uninstall() { sudo /usr/local/bin/mavergreen uninstall ninja && [ ! -e /usr/local/mavergreen/ninja ] && [ ! -e /usr/local/mavergreen/bin/ninja ]; }
step fetch fetch
step install install_pkg
step login-path login_path
step version version
step smoke smoke
if [ -n "$NT" ]; then step ninja_test ninja_test; else echo "SKIP ninja_test (none given)"; fi
step uninstall uninstall
[ "$bad" = 0 ] && rm -rf "$w"
exit "$bad"
