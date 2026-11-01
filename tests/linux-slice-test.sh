#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
t="$(mktemp -d "${TMPDIR:-/tmp}/linux-host.XXXXXX")"; trap 'rm -rf "$t"' EXIT
mkdir -p "$t/repo" "$t/bin" "$t/source" "$t/gtest" "$t/compiler/bin" "$t/sy"
cp -R "$ROOT/build" "$ROOT/components" "$t/repo/"; cp "$ROOT/UPSTREAM_VERSION" "$t/repo/"
. "$ROOT/build/msc.sh"; cp -R "$SHIPYARD_SCRIPTS"/. "$t/sy/"
printf '#!/bin/sh\nprintf "/sdk-%%s\\n" "${2:-x86_64}"\n' > "$t/sy/fetch_sdk.sh"
printf license > "$t/source/COPYING"
for f in fetch-ninja fetch-googletest fetch-clang22; do
  case "$f" in fetch-ninja) path="$t/source" ;; fetch-googletest) path="$t/gtest" ;; *) path="$t/compiler" ;; esac
  printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "$path" > "$t/repo/build/$f.sh"
done
printf '#!/bin/sh\nexit 0\n' > "$t/repo/build/compat-gate.sh"
for f in fetch-make run-ninja-test smoke; do
  printf '#!/bin/sh\ntouch "$FORBIDDEN"\nexit 1\n' > "$t/repo/build/$f.sh"
done
cat > "$t/compiler/bin/llvm-lipo" <<'SH'
#!/bin/sh
case "$1" in
  -info) if grep -q '^fat$' "$2"; then echo "Architectures in the fat file: $2 are: x86_64 arm64"
         else echo "Non-fat file: $2 is architecture: $(sed -n 2p "$2")"; fi ;;
  -create) printf 'fat\n' > "$5" ;;
  *) exit 1 ;;
esac
SH
cat > "$t/bin/cmake" <<'SH'
#!/bin/sh
if [ "$1" = --version ]; then echo "cmake version 9.9.9"; echo "CMake suite"; exit 0; fi
if [ "$1" = --build ]; then
  a="${2##*/b-}"
  for f in ninja ninja_test; do printf '#!/bin/sh\n%s\ntouch "$FORBIDDEN"\nexit 1\n' "$a" > "$2/$f"; chmod +x "$2/$f"; done
else
  b=; mk=; for x in "$@"; do [ "$prev" = -B ] && b="$x"; case "$x" in -DCMAKE_MAKE_PROGRAM=*) mk="${x#*=}" ;; esac; prev="$x"; done
  mkdir -p "$b"; printf '%s\n' "$@" > "$CONFIG_ARGS-${b##*/}"
  printf 'CMAKE_COMMAND:INTERNAL=%s\nCMAKE_MAKE_PROGRAM:FILEPATH=%s\n' "$0" "$mk" > "$b/CMakeCache.txt"
fi
SH
printf '#!/bin/sh\n[ "$1" = --version ] && echo "1.99.0"\n' > "$t/bin/ninja"; chmod +x "$t/bin/ninja"
chmod +x "$t/compiler/bin/llvm-lipo" "$t/bin/cmake"
export PATH="$t/bin:$PATH" CONFIG_ARGS="$t/args" FORBIDDEN="$t/forbidden" MAVERICKS_MODE=linux MAVERICKS_BUILD_ROOT="$t/work" SHIPYARD_SCRIPTS="$t/sy"
out="$(sh "$t/repo/build/build.sh")" || fail "build.sh failed on Linux"
[ ! -e "$FORBIDDEN" ] || fail "Linux must not run a Mac binary or the family's make"
[ "$(cat "$out")" = fat ] || fail "Linux must stage one ninja merged from both slices with clang22's llvm-lipo"
for a in x86_64 arm64; do
  A="$t/args-b-$a"
  [ -f "$A" ] || fail "Linux must configure the $a slice"
  grep -Fx Ninja "$A" >/dev/null || fail "Linux builds the $a slice with the host's Ninja"
  grep -Fx -- "-DCMAKE_OSX_ARCHITECTURES=$a" "$A" >/dev/null || fail "the $a configure must name its arch"
  grep -Fx -- "-DCMAKE_INSTALL_NAME_TOOL=$t/compiler/bin/llvm-install-name-tool" "$A" >/dev/null || fail "the $a configure must name clang22's install_name_tool"
  grep -Fx -- "-DCMAKE_CXX_COMPILER=$t/compiler/bin/clang++" "$A" >/dev/null || fail "the $a configure must use clang22's clang++"
  [ -x "$t/work/mavergreen-ninja/test/ninja_test-$a" ] || fail "build.sh must keep the $a ninja_test for the job that runs that slice"
done
grep -Fx -- "-DCMAKE_CXX_COMPILER_TARGET=arm64-apple-macos11.0" "$t/args-b-arm64" >/dev/null || fail "the arm64 slice targets arm64-apple-macos11.0"
grep -Fx -- "-DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld --ld-path=$t/compiler/bin/ld64.lld -Wl,-dead_strip_dylibs" "$t/args-b-arm64" >/dev/null \
  || fail "the arm64 slice links with clang22's ld64.lld, never the host's ld"
grep -F -- "-isystem /sdk-arm64/usr/include/c++/v1" "$t/args-b-arm64" >/dev/null || fail "the arm64 slice compiles against the 11.3 SDK's libc++ headers"
[ "$(cat "$t/work/mavergreen-ninja/build-tools.txt")" = "build-cmake=cmake version 9.9.9
build-ninja=1.99.0" ] || fail "Linux must record the runner's cmake and ninja that built the slices, and no make (got: $(cat "$t/work/mavergreen-ninja/build-tools.txt"))"
if MAVERICKS_MODE=native sh "$t/repo/build/build-slice.sh" arm64 >/dev/null 2>&1; then fail "a 10.9 build must refuse the arm64 slice"; fi
echo 'PASS: Linux builds both slices with host CMake/Ninja and clang22, merges them, and runs no target binary'
