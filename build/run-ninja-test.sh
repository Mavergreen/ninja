#!/bin/sh
# platform: host-agnostic
#   usage: run-ninja-test.sh <ninja_test> <known-failures-file>
#          Runs ninja_test; passes iff the failing tests are exactly the file's entries, one per line as
#          "<Suite.Test>  # <reason>" (blank lines and lines starting # ignored). A listed test that now
#          passes fails the run, so the list never goes stale.
set -eu
T="${1:?usage: run-ninja-test.sh <ninja_test> <known-failures-file>}"; L="${2:?usage: run-ninja-test.sh <ninja_test> <known-failures-file>}"
w="$(mktemp -d "${TMPDIR:-/tmp}/run-ninja-test.XXXXXX")"; trap 'rm -rf "$w"' EXIT INT TERM
grep -v '^[[:space:]]*\(#.*\)\{0,1\}$' "$L" > "$w/entries" || :
if grep -v '#[[:space:]]*[^[:space:]]' "$w/entries" | grep -q .; then
  echo "run-ninja-test: every entry in $L needs '# <reason>':"; grep -v '#[[:space:]]*[^[:space:]]' "$w/entries"; exit 1; fi
sed 's/[[:space:]]*#.*//; s/^[[:space:]]*//' "$w/entries" | sort -u > "$w/want"
rc=0; "$T" --gtest_brief=1 > "$w/out" 2>&1 || rc=$?
sed -n 's/^\[  FAILED  \] \([A-Za-z0-9_/]*\.[A-Za-z0-9_/]*\).*/\1/p' "$w/out" | sort -u > "$w/got"
# platform: a killed or crashed run (rc >= 128, or no gtest summary) never ran the remaining tests, so it is no pass
if [ "$rc" -ge 128 ] || ! grep -q '^\[==========\] [1-9][0-9]* tests\{0,1\} from .* ran\.' "$w/out"; then
  echo "run-ninja-test: $T did not complete (exit $rc, or no summary of a non-empty run)"; tail -20 "$w/out"; exit 1; fi
bad=0
comm -13 "$w/want" "$w/got" | while read -r n; do echo "FAIL (unlisted): $n"; done
comm -23 "$w/want" "$w/got" | while read -r n; do echo "known failure now passes, remove it from $L: $n"; done
[ -z "$(comm -3 "$w/want" "$w/got")" ] || bad=1
tail -3 "$w/out"
exit "$bad"
