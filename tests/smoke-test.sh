#!/bin/sh
# platform: macOS-only -- runs the built ninja of this Mac's own arch
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/build/versions.sh"
a="$(uname -m)"; N="$WORK/b-$a/ninja"
[ -x "$N" ] || { echo "not built (no $N) -- skipping"; exit 77; }
sh "$ROOT/build/smoke.sh" "$N" || { echo "FAIL: smoke of $N"; exit 1; }
echo "PASS: smoke ($a)"
