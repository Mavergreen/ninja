#!/bin/sh
# platform: macOS-only -- lipo reads the staged ninja
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/build/versions.sh"; . "$ROOT/build/msc.sh"
fail() { echo "FAIL: $1"; exit 1; }
N="$STAGE/bin/ninja"
[ -x "$N" ] || { echo "not built (no $N) -- skipping"; exit 77; }
if [ "$(sh "$SHIPYARD_SCRIPTS/mavericks_mode.sh")" = cross ]; then want="x86_64 arm64"; else want=x86_64; fi
[ "$(lipo -info "$N" | sed -n "s/.*: //p" | xargs)" = "$want" ] || fail "the staged ninja must be exactly '$want' (got $(lipo -info "$N" | sed -n "s/.*: //p" | xargs))"
[ -s "$STAGE/share/doc/ninja/COPYING" ] || fail "the stage must carry ninja's COPYING (Apache-2.0)"
[ "$(cd "$STAGE" && find . -type f | sort | tr '\n' ' ')" = "./bin/ninja ./share/doc/ninja/COPYING " ] \
  || fail "the stage holds only bin/ninja and its COPYING (got: $(cd "$STAGE" && find . -type f | tr '\n' ' '))"
[ -x "$WORK/test/ninja_test-x86_64" ] || fail "build.sh must keep the x86_64 ninja_test for the 10.9 run"
# platform: a build path or another package manager's prefix in what ships would make ninja depend on a tree a user's Mac doesn't have
strs="$(strings -a "$N")"
[ -n "$strs" ] || fail "strings read nothing from the staged ninja"
rc=0; leak="$(printf '%s\n' "$strs" | grep -E "$WORK|$REPO_ROOT|/opt/pkg|/opt/local|/opt/homebrew|(^|[^a-z])/sw/")" || rc=$?
[ "$rc" -le 1 ] || fail "grep failed (exit $rc) while scanning the staged ninja"
[ -z "$leak" ] || fail "the staged ninja names a build path or another package manager's prefix: $(printf '%s\n' "$leak" | head -3)"
echo "PASS: build"
