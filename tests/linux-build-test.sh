#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
t="$(mktemp -d "${TMPDIR:-/tmp}/linux-host.XXXXXX")"; trap 'rm -rf "$t"' EXIT
mkdir -p "$t/repo" "$t/sy"
cp -R "$ROOT/build" "$ROOT/components" "$t/repo/"; cp "$ROOT/UPSTREAM_VERSION" "$t/repo/"
cp -R "$SHIPYARD_SCRIPTS"/. "$t/sy/"
cat > "$t/sy/fetch_product_tar.sh" <<'SH'
#!/bin/sh
printf '%s\n' "$@" > "$CALLS"
mkdir -p "$4/bin"
for b in clang clang++ ld64.lld llvm-lipo llvm-ar llvm-ranlib llvm-otool llvm-nm llvm-strings llvm-strip llvm-objdump setup-sdk; do
  printf '#!/bin/sh\nexit 0\n' > "$4/bin/$b"; chmod +x "$4/bin/$b"
done
printf '%s\n' "$4"
SH
cat > "$t/sy/fetch_sdk.sh" <<'SH'
#!/bin/sh
printf '/sdk\n'
SH
V="$(cat "$ROOT/components/clang22/version")"
SHA=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
printf '%s  clang22-%s-linux-x86_64.tar.gz\n' "$SHA" "$V" > "$t/repo/components/clang22/linux-sha256"
export CALLS="$t/calls" SHIPYARD_SCRIPTS="$t/sy" MAVERICKS_BUILD_ROOT="$t/work" MAVERICKS_MODE=linux
prefix="$(sh "$t/repo/build/fetch-clang22.sh")"
[ "$(sed -n 1p "$CALLS")" = clang22 ]
[ "$(sed -n 2p "$CALLS")" = "$V" ]
[ "$(sed -n 3p "$CALLS")" = "$SHA" ]
[ "$(sed -n 4p "$CALLS")" = "$prefix" ]
rm "$CALLS"
printf '%s  clang22-old-linux-x86_64.tar.gz\n' "$SHA" > "$t/repo/components/clang22/linux-sha256"
if sh "$t/repo/build/fetch-clang22.sh"; then echo 'FAIL: accepted a digest for another version'; exit 1; fi
[ ! -e "$CALLS" ]
echo 'PASS: Linux clang fetch uses matching version/digest and refuses stale pins'
