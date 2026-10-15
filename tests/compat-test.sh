#!/bin/sh
# platform: macOS-only -- otool and nm read Mach-O, and clang links the fixtures
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/build/versions.sh"; . "$ROOT/build/msc.sh"
fail() { echo "FAIL: $1"; exit 1; }
t="$(mktemp -d "${TMPDIR:-/tmp}/ninja-compat-test.XXXXXX")"; trap 'rm -rf "$t"' EXIT INT TERM
SDK="$(sh "$SHIPYARD_SCRIPTS/fetch_sdk.sh" --arch x86_64)"
printf 'extern void os_unfair_lock_lock(void*);\nint main(void){ os_unfair_lock_lock(0); return 0; }\n' > "$t/b.c"
/usr/bin/clang -arch x86_64 -isysroot "$SDK" -mmacosx-version-min=10.9 -Wl,-U,_os_unfair_lock_lock "$t/b.c" -o "$t/b"
if sh "$ROOT/build/compat-gate.sh" "$t/b" x86_64 > "$t/out" 2>&1; then fail "a binary importing a post-10.9 symbol must fail the gate"; fi
grep -q _os_unfair_lock_lock "$t/out" || fail "the refusal must name the symbol"
printf 'int main(void){ return 0; }\n' > "$t/c.c"
/usr/bin/clang -arch x86_64 -isysroot "$SDK" -mmacosx-version-min=10.9 "$t/c.c" -o "$t/c"
if sh "$ROOT/build/compat-gate.sh" "$t/c" x86_64 > "$t/out" 2>&1; then fail "an x86_64 binary without Recaulk's clock_gettime must fail the gate"; fi
grep -q "required symbol '_clock_gettime'" "$t/out" || fail "the refusal must name _clock_gettime (got: $(cat "$t/out"))"
N="$STAGE/bin/ninja"
[ -x "$N" ] || { echo "not built (no $N) -- skipping the shipped half"; exit 77; }
if [ "$(sh "$SHIPYARD_SCRIPTS/mavericks_mode.sh")" = cross ]; then want="x86_64 arm64"; else want=x86_64; fi
sh "$ROOT/build/compat-gate.sh" "$N" "$want" || fail "the staged ninja must pass the gate as '$want'"
echo "PASS: compat"
