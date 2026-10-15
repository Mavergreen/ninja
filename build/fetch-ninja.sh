#!/bin/sh
# platform: host-agnostic
#   usage: fetch-ninja.sh     prints a fresh ninja source tree at components/ninja/source's pin
#          GitHub's tarball of DIGEST, verified against TARBALL_SHA256 by shipyard's fetch_pinned_source.sh
#          (no git; MAVERICKS_CODELOAD replaces codeload.github.com in tests).
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_ROOT/build/versions.sh"
. "$REPO_ROOT/build/msc.sh"
SRC="$WORK/src/ninja"
mkdir -p "$WORK/src"
sh "$SHIPYARD_SCRIPTS/fetch_pinned_source.sh" "$NINJA_REPO" "$NINJA_DIGEST" "$NINJA_TARBALL_SHA256" "$SRC" >&2 \
  || { echo "fetch-ninja: $NINJA_REPO at $NINJA_DIGEST did not verify; if UPSTREAM_VERSION moved, run sh build/pin-source-tarball.sh" >&2; exit 1; }
[ -f "$SRC/CMakeLists.txt" ] || { echo "fetch-ninja: $SRC holds no CMakeLists.txt" >&2; exit 1; }
echo "$SRC"
