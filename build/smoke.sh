#!/bin/sh
# platform: host-agnostic
#   usage: smoke.sh <ninja>     --version, a two-rule build, a no-op rerun, -t clean
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_ROOT/build/versions.sh"
N="${1:?usage: smoke.sh <ninja>}"
N="$(cd "$(dirname "$N")" && pwd)/$(basename "$N")"
[ "$("$N" --version)" = "$NINJA_VERSION" ] || { echo "smoke: $N --version is '$("$N" --version)', not $NINJA_VERSION"; exit 1; }
w="$(mktemp -d "${TMPDIR:-/tmp}/ninja-smoke.XXXXXX")"; trap 'rm -rf "$w"' EXIT INT TERM
printf 'rule cp\n  command = cp $in $out\nrule cat\n  command = cat $in > $out\nbuild b: cp a\nbuild c: cat b a\n' > "$w/build.ninja"
echo hi > "$w/a"
( cd "$w" && "$N" ) > "$w/1.log" 2>&1 || { cat "$w/1.log"; echo "smoke: the first build failed"; exit 1; }
[ "$(cat "$w/c")" = "hi
hi" ] || { echo "smoke: c is not b then a"; exit 1; }
[ "$(cd "$w" && "$N")" = "ninja: no work to do." ] || { echo "smoke: a second run must do nothing"; exit 1; }
( cd "$w" && "$N" -t clean ) >/dev/null
[ ! -e "$w/b" ] && [ ! -e "$w/c" ] || { echo "smoke: -t clean must remove b and c"; exit 1; }
echo "smoke OK: $N"
