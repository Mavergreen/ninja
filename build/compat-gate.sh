#!/bin/sh
# platform: macOS-only -- assert_binary_compatible.sh and otool read Mach-O
#   usage: compat-gate.sh <binary> "<arch ...>"     10.9-safe x86_64, 11.0 arm64, and only the expected dylibs
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_ROOT/build/msc.sh"
B="${1:?usage: compat-gate.sh <binary> \"<arch ...>\"}"; ARCHS="${2:?usage: compat-gate.sh <binary> \"<arch ...>\"}"
# platform: 10.9's libSystem has no clock_gettime, which libc++'s chrono calls; Recaulk (clang22's clang.cfg
#           links librecaulk.a) must define it in the x86_64 slice, the only one the guard reads for this
MAVERICKS_DEVIATIONS_ROOT="$REPO_ROOT" MAVERICKS_ALLOW_ARCHS="$ARCHS" MAVERICKS_REQUIRE_DEFINED_SYMBOLS=_clock_gettime \
  sh "$SHIPYARD_SCRIPTS/assert_binary_compatible.sh" "$B"
for a in $ARCHS; do
  got="$(otool -arch "$a" -L "$B" | sed 1d | sed 's/^[[:space:]]*//; s/ (compatibility.*//' | sort)"
  want="$(sort "$REPO_ROOT/tests/expected-dylibs-$a.txt")"
  [ "$got" = "$want" ] || { echo "compat-gate: $a links
$got
not tests/expected-dylibs-$a.txt:
$want"; exit 1; }
done
