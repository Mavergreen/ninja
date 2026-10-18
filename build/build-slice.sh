#!/bin/sh
# platform: macOS-only -- links Mach-O for 10.9 or 11.0 with clang22's ld64.lld against shipyard's pinned SDKs
#   usage: build-slice.sh x86_64|arm64     configures ninja with shipyard-cmake (Unix Makefiles), makes ninja
#          and ninja_test, and prints the build dir $WORK/b-<arch>
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_ROOT/build/versions.sh"
. "$REPO_ROOT/build/msc.sh"
A="${1:?usage: build-slice.sh x86_64|arm64}"
case "$A" in x86_64|arm64) : ;; *) echo "build-slice: arch '$A' is neither x86_64 nor arm64" >&2; exit 2 ;; esac
SRC="$(sh "$REPO_ROOT/build/fetch-ninja.sh")"
GT="$(sh "$REPO_ROOT/build/fetch-googletest.sh" "$SRC")"
CL="$(sh "$REPO_ROOT/build/fetch-clang22.sh")"
SC="$(command -v shipyard-cmake || echo /usr/local/mavergreen/bin/shipyard-cmake)"
TC="$(dirname "$SHIPYARD_SCRIPTS")/MavericksToolchain.cmake"
# platform: the family's make by its path, never one PATH or an inherited MAKE offers (CMake picked pkgsrc's
#           gmake in the spike, and 10.9's /usr/bin/make is a Command Line Tools stub)
MK="${NINJA_BUILD_MAKE:-$(sh "$REPO_ROOT/build/fetch-make.sh")/bin/make}"
B="$WORK/b-$A"; rm -rf "$B"
# platform: ninja's CMakeLists.txt turns on LTO for Release, so its archives hold LLVM 22 bitcode that
#           10.9's /usr/bin/ar cannot read; clang22's own llvm-ar and llvm-ranlib read it on every host
set -- -G "Unix Makefiles" -S "$SRC" -B "$B" -DCMAKE_TOOLCHAIN_FILE="$TC" -DCMAKE_OSX_ARCHITECTURES="$A" \
  -DCMAKE_MAKE_PROGRAM="$MK" -DCMAKE_C_COMPILER="$CL/bin/clang" -DCMAKE_CXX_COMPILER="$CL/bin/clang++" \
  -DCMAKE_AR="$CL/bin/llvm-ar" -DCMAKE_RANLIB="$CL/bin/llvm-ranlib" \
  -DCMAKE_BUILD_TYPE=Release -DRE2C=RE2C-NOTFOUND -DNINJA_PYTHON=python3 -DBUILD_TESTING=ON \
  -DCMAKE_DISABLE_FIND_PACKAGE_GTest=ON -DFETCHCONTENT_FULLY_DISCONNECTED=ON -DFETCHCONTENT_SOURCE_DIR_GOOGLETEST="$GT"
if [ "$A" = arm64 ]; then
  # spec: INGREDIENTS.md "Conformance deviations" -- clang22-cross's clang.cfg targets x86_64 10.9 and its
  #       runtimes are x86_64 only, so arm64 runs without it, against the 11.3 SDK's own libc++ headers
  #       (LLVM 22's headers need symbols macOS 11's libc++ lacks)
  SDK113="$(sh "$SHIPYARD_SCRIPTS/fetch_sdk.sh" --arch arm64)"
  set -- "$@" -DCMAKE_C_FLAGS=--no-default-config \
    -DCMAKE_CXX_FLAGS="--no-default-config -nostdinc++ -isystem $SDK113/usr/include/c++/v1" \
    -DCMAKE_EXE_LINKER_FLAGS="--ld-path=$CL/bin/ld64.lld -Wl,-dead_strip_dylibs"
else
  # platform: clang22's clang++.cfg links libobjc and three frameworks ninja never uses unless dead-stripped
  set -- "$@" -DCMAKE_EXE_LINKER_FLAGS=-Wl,-dead_strip_dylibs
fi
"$SC" "$@" >&2
"$MK" -C "$B" -j"$(sysctl -n hw.ncpu)" ninja ninja_test >&2
[ -x "$B/ninja" ] && [ -x "$B/ninja_test" ] || { echo "build-slice: $B lacks ninja or ninja_test" >&2; exit 1; }
echo "$B"
