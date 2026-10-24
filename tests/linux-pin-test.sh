#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
t="$(mktemp -d "${TMPDIR:-/tmp}/linux-host.XXXXXX")"; trap 'rm -rf "$t"' EXIT
mkdir -p "$t/repo" "$t/rel/Mavergreen/clang-22/releases/download/22.1.8-mavericks.99"
cp -R "$ROOT/build" "$ROOT/components" "$t/repo/"; cp "$ROOT/UPSTREAM_VERSION" "$t/repo/"
printf '%s\n' 22.1.8-mavericks.99 > "$t/repo/components/clang22/version"
asset=clang22-22.1.8-mavericks.99-linux-x86_64.tar.gz
rel="$t/rel/Mavergreen/clang-22/releases/download/22.1.8-mavericks.99"
printf fixture > "$rel/$asset"
sha="$(python3 -c 'import hashlib,pathlib,sys; print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())' "$rel/$asset")"
printf '%s  %s\n' "$sha" "$asset" > "$rel/SHA256SUMS"
export MAVERGREEN_RELEASES="file://$t/rel" MAVERICKS_BUILD_ROOT="$t/work"
values="$(sh "$t/repo/build/pin-linux-clang.sh" values)"
[ "$values" = "22.1.8-mavericks.99 $sha" ]
sh "$t/repo/build/pin-linux-clang.sh" apply 22.1.8-mavericks.99 "$sha"
[ "$(cat "$t/repo/components/clang22/linux-sha256")" = "$sha  $asset" ]
if sh "$t/repo/build/pin-linux-clang.sh" apply wrong "$sha"; then echo 'FAIL: accepts another checkout version'; exit 1; fi
rm -rf "$t/work"
printf '%064d  %s\n' 0 "$asset" > "$rel/SHA256SUMS"
if sh "$t/repo/build/pin-linux-clang.sh" values; then echo 'FAIL: accepts digest without verifying release bytes'; exit 1; fi
echo 'PASS: Linux compiler pins verify bytes and bind digest to checkout version'
