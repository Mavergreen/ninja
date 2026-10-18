#!/bin/sh
# platform: host-agnostic
# platform: without the Command Line Tools, 10.9's lipo, otool, nm, strings, strip and xcrun are stubs; the
#           build names clang22's tools instead (the family's make: fetch-make-test.sh)
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
S="$ROOT/build/build-slice.sh"; G="$ROOT/build/compat-gate.sh"
grep -q -- '-DCMAKE_STRIP="$CL/bin/llvm-strip"' "$S" || fail "build-slice.sh must name clang22's llvm-strip: CMake runs strip -u -r in every configure"
grep -q -- '-DCMAKE_TAPI=/usr/bin/false' "$S" || fail "build-slice.sh must answer CMAKE_TAPI: CMake asks xcrun --find tapi otherwise"
for v in LIPO OTOOL NM STRINGS; do
  grep -q "^$v=\"\$CL/bin/llvm-\|; $v=\"\$CL/bin/llvm-" "$G" || fail "compat-gate.sh must set $v to clang22's reader for assert_binary_compatible.sh"
done
grep -q '^export LIPO OTOOL NM STRINGS$' "$G" || fail "compat-gate.sh must export the readers"
if grep -nE '(^|[^-_A-Za-z/$.{])(lipo|otool|nm|strings) ' "$G" | grep -vE '^[0-9]+:[[:space:]]*#'; then
  fail "compat-gate.sh must not run a bare Mach-O reader"
fi
echo "PASS: no-clt"
