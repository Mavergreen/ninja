#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
t="$(mktemp -d "${TMPDIR:-/tmp}/ninja-rnt-test.XXXXXX")"; trap 'rm -rf "$t"' EXIT INT TERM
fake() { printf '#!/bin/sh\n' > "$t/nt"; for f in "$@"; do printf 'echo "[  FAILED  ] %s"\n' "$f" >> "$t/nt"; done
         printf 'echo "[==========] 5 tests from 2 test suites ran. (1 ms total)"\nexit %s\n' "$([ $# -gt 0 ] && echo 1 || echo 0)" >> "$t/nt"; chmod +x "$t/nt"; }
printf '# reason per line: <Suite.Test>  # why\n' > "$t/none"
printf 'BuildTest.Foo  # 10.9 lacks X\n' > "$t/one"
fake; sh "$ROOT/build/run-ninja-test.sh" "$t/nt" "$t/none" >/dev/null || fail "no failures, empty list: must pass"
fake BuildTest.Foo; sh "$ROOT/build/run-ninja-test.sh" "$t/nt" "$t/one" >/dev/null || fail "the listed failure only: must pass"
fake BuildTest.Foo; if sh "$ROOT/build/run-ninja-test.sh" "$t/nt" "$t/none" >/dev/null; then fail "an unlisted failure must fail"; fi
fake; if sh "$ROOT/build/run-ninja-test.sh" "$t/nt" "$t/one" > "$t/out"; then fail "a listed test that passes must fail"; fi
grep -q 'now passes' "$t/out" || fail "it must say the known failure now passes"
printf 'BuildTest.Foo\n' > "$t/noreason"; fake BuildTest.Foo
if sh "$ROOT/build/run-ninja-test.sh" "$t/nt" "$t/noreason" >/dev/null 2>&1; then fail "a list entry without a reason must be refused"; fi
printf '#!/bin/sh\necho "[  FAILED  ] BuildTest.Foo"\nexit 139\n' > "$t/nt"; chmod +x "$t/nt"
if sh "$ROOT/build/run-ninja-test.sh" "$t/nt" "$t/one" >/dev/null 2>&1; then fail "a crash after the listed failure must fail"; fi
printf '#!/bin/sh\nexit 0\n' > "$t/nt"; chmod +x "$t/nt"
if sh "$ROOT/build/run-ninja-test.sh" "$t/nt" "$t/none" >/dev/null 2>&1; then fail "no summary line must fail"; fi
printf '#!/bin/sh\necho "[==========] 0 tests from 0 test suites ran. (0 ms total)"\nexit 0\n' > "$t/nt"; chmod +x "$t/nt"
if sh "$ROOT/build/run-ninja-test.sh" "$t/nt" "$t/none" >/dev/null 2>&1; then fail "zero tests run must fail"; fi
printf 'Inst/Suite.Test/0  # param\n' > "$t/param"
fake Inst/Suite.Test/0; if sh "$ROOT/build/run-ninja-test.sh" "$t/nt" "$t/none" >/dev/null; then fail "an unlisted parameterized failure must fail"; fi
fake Inst/Suite.Test/0; sh "$ROOT/build/run-ninja-test.sh" "$t/nt" "$t/param" >/dev/null || fail "a listed parameterized failure must pass"
printf '   BuildTest.Foo  # indented\n' > "$t/indent"
fake BuildTest.Foo; sh "$ROOT/build/run-ninja-test.sh" "$t/nt" "$t/indent" >/dev/null || fail "an indented entry must match"
for a in x86_64 arm64; do [ -f "$ROOT/tests/known-failures-$a.txt" ] || fail "tests/known-failures-$a.txt must exist"; done
echo "PASS: run-ninja-test"
