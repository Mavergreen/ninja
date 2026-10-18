#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
t="$(mktemp -d "${TMPDIR:-/tmp}/ninja-fetch-test.XXXXXX")"; trap 'rm -rf "$t"' EXIT INT TERM
# platform: file:// stands in for GitHub here: a fake ninja tarball and a fake googletest release.
D=1111111111111111111111111111111111111111
mkdir -p "$t/up/ninja-$D/src" "$t/gt/googletest-9.9.9" "$t/codeload/ninja-build/ninja/tar.gz" "$t/rel/v9.9.9"
printf 'project(gt)\n' > "$t/gt/googletest-9.9.9/CMakeLists.txt"
( cd "$t/gt" && tar czf "$t/rel/v9.9.9/googletest-9.9.9.tar.gz" googletest-9.9.9 )
GS="$(shasum -a 256 < "$t/rel/v9.9.9/googletest-9.9.9.tar.gz" | cut -c1-64)"
cat > "$t/up/ninja-$D/CMakeLists.txt" <<EOF
    FetchContent_Declare(
      googletest
      URL https://github.com/google/googletest/releases/download/v9.9.9/googletest-9.9.9.tar.gz
      URL_HASH SHA256=$GS
    )
EOF
( cd "$t/up" && tar czf "$t/codeload/ninja-build/ninja/tar.gz/$D" "ninja-$D" )
NS="$(shasum -a 256 < "$t/codeload/ninja-build/ninja/tar.gz/$D" | cut -c1-64)"
mkdir -p "$t/repo/components/ninja" "$t/repo/components/clang22" "$t/repo/components/make" "$t/repo/build"
cp "$ROOT"/build/*.sh "$t/repo/build/"; cp "$ROOT/UPSTREAM_VERSION" "$t/repo/"; cp "$ROOT/components/clang22/version" "$t/repo/components/clang22/"
cp "$ROOT/components/make/version" "$t/repo/components/make/"
printf 'REPO=https://github.com/ninja-build/ninja.git\nDIGEST=%s\nTARBALL_SHA256=%s\n' "$D" "$NS" > "$t/repo/components/ninja/source"
with() { MAVERICKS_BUILD_ROOT="$t/root" MAVERICKS_SOURCE_CACHE="$t/cache" MAVERICKS_CODELOAD="file://$t/codeload" \
  NINJA_GTEST_BASE="file://$t/rel" "$@"; }

src="$(with sh "$t/repo/build/fetch-ninja.sh")" || fail "fetch-ninja.sh failed on a good pin"
[ -f "$src/CMakeLists.txt" ] || fail "fetch-ninja.sh must print a tree holding CMakeLists.txt (got $src)"
gt="$(with sh "$t/repo/build/fetch-googletest.sh" "$src")" || fail "fetch-googletest.sh failed on a good CMakeLists"
[ -f "$gt/CMakeLists.txt" ] || fail "fetch-googletest.sh must print googletest's tree (got $gt)"
case "$gt" in */googletest-9.9.9) : ;; *) fail "the googletest tree must be googletest-<version> (got $gt)" ;; esac

printf 'REPO=https://github.com/ninja-build/ninja.git\nDIGEST=%s\nTARBALL_SHA256=%064d\n' "$D" 0 > "$t/repo/components/ninja/source"
rm -rf "$t/cache"
if with sh "$t/repo/build/fetch-ninja.sh" >/dev/null 2>&1; then fail "fetch-ninja.sh must refuse a tarball that is not its pinned SHA-256"; fi

sed '/URL_HASH/d' "$src/CMakeLists.txt" > "$t/nohash.txt"; cp "$t/nohash.txt" "$src/CMakeLists.txt"
if with sh "$t/repo/build/fetch-googletest.sh" "$src" > "$t/out" 2>&1; then fail "fetch-googletest.sh must refuse a CMakeLists that names no SHA-256"; fi
grep -q 'CMakeLists.txt' "$t/out" || fail "the refusal must name ninja's CMakeLists.txt (got: $(cat "$t/out"))"
echo "PASS: fetch"
