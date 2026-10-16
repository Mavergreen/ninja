#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
C="$ROOT/build/check-release-on-10.9.sh"
[ -x "$C" ] || fail "build/check-release-on-10.9.sh must exist and be executable"
rc=0; sh "$C" >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] || fail "no version: exit 2 (got $rc)"
t="$(mktemp -d "${TMPDIR:-/tmp}/ninja-crt.XXXXXX")"; trap 'rm -rf "$t"' EXIT INT TERM
printf '#!/bin/sh\necho 14.5\n' > "$t/sw_vers"; chmod +x "$t/sw_vers"
rc=0; PATH="$t:$PATH" sh "$C" 1.13.2-mavericks.1 >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] || fail "not 10.9: exit 2 (got $rc)"
for step in fetch install login-path version smoke uninstall; do
  grep -q "^step $step " "$C" || fail "check-release-on-10.9.sh must run step $step"
done
grep -q 'then step ninja_test ninja_test; else echo "SKIP ninja_test (none given)"; fi' "$C" \
  || fail "check-release-on-10.9.sh must run ninja_test when given one and print SKIP ninja_test (none given) otherwise"
grep -q '/usr/local/mavergreen/bin/ninja' "$C" || fail "the login-path step must name /usr/local/mavergreen/bin/ninja"
echo "PASS: check-release"
