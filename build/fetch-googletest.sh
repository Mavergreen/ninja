#!/bin/sh
# platform: host-agnostic
#   usage: fetch-googletest.sh <ninja-tree>     prints the googletest tree ninja's CMakeLists.txt names
#          The URL and SHA-256 come from ninja's own FetchContent_Declare(googletest ...), so googletest is
#          pinned by the pinned ninja source and moves with UPSTREAM_VERSION. NINJA_GTEST_BASE replaces
#          https://github.com/google/googletest/releases/download (tests serve file://).
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_ROOT/build/versions.sh"
. "$REPO_ROOT/build/msc.sh"
. "$SHIPYARD_SCRIPTS/mavericks_fetch.sh"
N="${1:?usage: fetch-googletest.sh <ninja-tree>}"
CM="$N/CMakeLists.txt"
url="$(sed -n 's|^[[:space:]]*URL[[:space:]]\{1,\}\(https://github.com/google/googletest/releases/download/[^[:space:]]*\)[[:space:]]*$|\1|p' "$CM" | head -1)"
sha="$(sed -n 's/^[[:space:]]*URL_HASH[[:space:]]\{1,\}SHA256=\([0-9a-f]\{64\}\)[[:space:]]*$/\1/p' "$CM" | head -1)"
[ -n "$url" ] && [ -n "$sha" ] || { echo "fetch-googletest: $CM names no googletest URL and SHA256 (FetchContent_Declare); refusing to fetch unverified" >&2; exit 1; }
base="${NINJA_GTEST_BASE:-https://github.com/google/googletest/releases/download}"
url="$base/${url#https://github.com/google/googletest/releases/download/}"
tb="${url##*/}"; dir="${tb%.tar.gz}"
rm -rf "$WORK/src/$dir"
shipyard_fetch_pinned "$url" "$sha" "$WORK/src" "$tb" >&2 || { echo "fetch-googletest: $url did not verify against $sha from $CM" >&2; exit 1; }
[ -f "$WORK/src/$dir/CMakeLists.txt" ] || { echo "fetch-googletest: $tb holds no $dir/CMakeLists.txt" >&2; exit 1; }
echo "$WORK/src/$dir"
