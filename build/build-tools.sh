#!/bin/sh
# platform: host-agnostic
#   usage: build-tools.sh <build dir> <prefix>     prints the cmake and build tool that configured and built
#          <build dir>, as build-info key=value lines: <prefix>-cmake=<its --version>, and for the build tool
#          make=<components/make/version> when it is the family's make, <prefix>-ninja=<its --version> when
#          ninja, else <prefix>-build-tool=<name>:<its --version>
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_ROOT/build/versions.sh"
D="${1:?usage: build-tools.sh <build dir> <prefix>}"; P="${2:?usage: build-tools.sh <build dir> <prefix>}"
cached() { sed -n "s/^$1:[A-Z]*=//p" "$D/CMakeCache.txt"; }
line() { "$1" --version | sed -n 1p; }
cm="$(cached CMAKE_COMMAND)"; mp="$(cached CMAKE_MAKE_PROGRAM)"
[ -x "$cm" ] && [ -x "$mp" ] || { echo "build-tools: $D/CMakeCache.txt names no runnable cmake and build tool" >&2; exit 1; }
real() { printf '%s/%s\n' "$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)" "$(basename "$1")"; }
echo "$P-cmake=$(line "$cm")"
case "$P:$(real "$mp")" in
  build:"$(real "$WORK/make/$MAKE_VERSION/bin/make")") echo "make=$MAKE_VERSION" ;;
  build:*/ninja) echo "$P-ninja=$(line "$mp")" ;;
  *) echo "$P-build-tool=$(basename "$mp"):$(line "$mp")" ;;
esac
