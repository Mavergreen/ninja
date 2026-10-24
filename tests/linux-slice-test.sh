#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
t="$(mktemp -d "${TMPDIR:-/tmp}/linux-host.XXXXXX")"; trap 'rm -rf "$t"' EXIT
mkdir -p "$t/repo" "$t/bin" "$t/source" "$t/gtest" "$t/compiler/bin"
cp -R "$ROOT/build" "$ROOT/components" "$t/repo/"; cp "$ROOT/UPSTREAM_VERSION" "$t/repo/"
printf license > "$t/source/COPYING"
for f in fetch-ninja fetch-googletest fetch-clang22; do
  case "$f" in fetch-ninja) path="$t/source" ;; fetch-googletest) path="$t/gtest" ;; *) path="$t/compiler" ;; esac
  printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "$path" > "$t/repo/build/$f.sh"
done
printf '#!/bin/sh\nexit 0\n' > "$t/repo/build/compat-gate.sh"
for f in fetch-make run-ninja-test smoke; do
  printf '#!/bin/sh\ntouch "$FORBIDDEN"\nexit 1\n' > "$t/repo/build/$f.sh"
done
cat > "$t/bin/cmake" <<'SH'
#!/bin/sh
if [ "$1" = --build ]; then
  mkdir -p "$2"
  for f in ninja ninja_test; do printf '#!/bin/sh\ntouch "$FORBIDDEN"\nexit 1\n' > "$2/$f"; chmod +x "$2/$f"; done
else
  printf '%s\n' "$@" > "$CONFIG_ARGS"
fi
SH
chmod +x "$t/bin/cmake"
export PATH="$t/bin:$PATH" CONFIG_ARGS="$t/args" FORBIDDEN="$t/forbidden" MAVERICKS_MODE=linux MAVERICKS_BUILD_ROOT="$t/work"
out="$(sh "$t/repo/build/build.sh")"
[ -x "$out" ] && [ ! -e "$FORBIDDEN" ]
grep -Fx Ninja "$CONFIG_ARGS"
grep -Fx -- "-DCMAKE_INSTALL_NAME_TOOL=$t/compiler/bin/llvm-install-name-tool" "$CONFIG_ARGS"
grep -Fx -- "-DCMAKE_CXX_COMPILER=$t/compiler/bin/clang++" "$CONFIG_ARGS"
if sh "$t/repo/build/build-slice.sh" arm64; then echo 'FAIL: Linux accepted arm64'; exit 1; fi
echo 'PASS: Linux builds x86_64 with host CMake/Ninja and does not run target binaries'
