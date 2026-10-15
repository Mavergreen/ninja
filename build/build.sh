#!/bin/sh
# platform: macOS-only -- lipo-merge-tree.sh merges Mach-O slices and the arm64 ninja_test runs only on a Mac
#   usage: build.sh     builds this host's slices (cross: x86_64 + arm64; 10.9: x86_64), tests the one this
#          host can run, gates each, and stages $STAGE/bin/ninja and its COPYING; prints the ninja
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_ROOT/build/versions.sh"
. "$REPO_ROOT/build/msc.sh"
mode="${MAVERICKS_MODE:-$(sh "$SHIPYARD_SCRIPTS/mavericks_mode.sh")}"
case "$mode" in cross) slices="x86_64 arm64" ;; native) slices=x86_64 ;; *) echo "build: mode '$mode'" >&2; exit 2 ;; esac
# platform: never Rosetta -- the slice that runs is the host's own: x86_64 on an Intel Mac or 10.9, arm64 on
#           Apple Silicon, even from a shell Rosetta translates (uname -m says x86_64 there)
run="$(uname -m)"; [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || :)" = 1 ] && run=arm64
for a in $slices; do
  b="$(sh "$REPO_ROOT/build/build-slice.sh" "$a")"
  sh "$REPO_ROOT/build/compat-gate.sh" "$b/ninja" "$a" >&2
  # platform: the other slice cannot run here without Rosetta, which the family never uses; on CI's Apple Silicon runner x86_64 runs on 10.9 in release.yml's vm-test job
  if [ "$a" = "$run" ]; then
    sh "$REPO_ROOT/build/run-ninja-test.sh" "$b/ninja_test" "$REPO_ROOT/tests/known-failures-$a.txt" >&2
    sh "$REPO_ROOT/build/smoke.sh" "$b/ninja" >&2
  fi
done
rm -rf "$STAGE_ROOT" "$WORK/test"; mkdir -p "$STAGE/bin" "$STAGE/share/doc/ninja" "$WORK/test"
if [ "$mode" = cross ]; then
  rm -rf "$WORK/merge"; mkdir -p "$WORK/merge/x86_64/bin" "$WORK/merge/arm64/bin"
  cp "$WORK/b-x86_64/ninja" "$WORK/merge/x86_64/bin/"; cp "$WORK/b-arm64/ninja" "$WORK/merge/arm64/bin/"
  sh "$SHIPYARD_SCRIPTS/lipo-merge-tree.sh" --a "$WORK/merge/x86_64" --b "$WORK/merge/arm64" \
    --out "$WORK/merge/out" --require-archs "x86_64 arm64" >&2
  cp "$WORK/merge/out/bin/ninja" "$STAGE/bin/ninja"
else
  cp "$WORK/b-x86_64/ninja" "$STAGE/bin/ninja"
fi
sh "$REPO_ROOT/build/compat-gate.sh" "$STAGE/bin/ninja" "$slices" >&2
cp "$(sh "$REPO_ROOT/build/fetch-ninja.sh")/COPYING" "$STAGE/share/doc/ninja/COPYING"
cp "$WORK/b-x86_64/ninja_test" "$WORK/test/ninja_test-x86_64"
echo "$STAGE/bin/ninja"
