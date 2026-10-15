#!/bin/sh
# platform: macOS-only -- fetch_product_pkg.sh expands the clang22 pkg with pkgutil
#   usage: fetch-clang22.sh     prints the prefix of clang22 N-1 (components/clang22/version) for this host
# spec: components/clang22/version -- release N of a product is built by clang22 N-1, pinned as an ingredient
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_ROOT/build/versions.sh"
. "$REPO_ROOT/build/msc.sh"
mode="${MAVERICKS_MODE:-$(sh "$SHIPYARD_SCRIPTS/mavericks_mode.sh")}"
inst="${CLANG22_INSTALLED:-/usr/local/mavergreen/clang22}"
ok() { for b in clang clang++ ld64.lld llvm-lipo llvm-ar llvm-ranlib; do [ -x "$1/bin/$b" ] || return 1; done; }
case "$mode" in
  cross) d="$WORK/clang22/$CLANG22_VERSION/cross"
         ok "$d" || sh "$SHIPYARD_SCRIPTS/fetch_product_pkg.sh" --asset "mavericks-clang-22-cross-$CLANG22_VERSION.pkg" \
           clang22-cross "$CLANG22_VERSION" "$d" >/dev/null ;;
  native) have="$(pkgutil --pkg-info dev.mavergreen.clang.clang22 2>/dev/null | sed -n 's/^version: //p')"
          if [ "$have" = "$CLANG22_VERSION" ] && ok "$inst"; then echo "$inst"; exit 0; fi
          d="$WORK/clang22/$CLANG22_VERSION/native"
          ok "$d" || sh "$SHIPYARD_SCRIPTS/fetch_product_pkg.sh" --asset "mavericks-clang-22-native-$CLANG22_VERSION.pkg" \
            clang22 "$CLANG22_VERSION" "$d" >/dev/null ;;
  *) echo "fetch-clang22: unknown mode '$mode'" >&2; exit 2 ;;
esac
ok "$d" || { echo "fetch-clang22: $d lacks clang, clang++, ld64.lld, llvm-lipo, llvm-ar or llvm-ranlib" >&2; exit 1; }
echo "$d"
