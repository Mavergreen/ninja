#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
t="$(mktemp -d "${TMPDIR:-/tmp}/ninja-make-test.XXXXXX")"; trap 'rm -rf "$t"' EXIT INT TERM
mkdir -p "$t/sy"
. "$ROOT/build/msc.sh"; cp -R "$SHIPYARD_SCRIPTS"/. "$t/sy/"
cat > "$t/sy/fetch_product_pkg.sh" <<EOF2
#!/bin/sh
echo "\$*" >> "$t/calls"; d="\$(eval echo "\\\${\$#}")"; mkdir -p "\$d/bin"
[ -n "\${FAKE_NO_MAKE:-}" ] || { printf '#!/bin/sh\n' > "\$d/bin/make"; chmod +x "\$d/bin/make"; }
EOF2
run() { SHIPYARD_SCRIPTS="$t/sy" MAVERICKS_BUILD_ROOT="$t/root" sh "$ROOT/build/fetch-make.sh"; }
V="$(cat "$ROOT/components/make/version")"

p="$(run)" || fail "fetch-make failed"
grep -qx -- "make $V $p" "$t/calls" || fail "fetch-make must fetch the family's make $V (calls: $(cat "$t/calls"))"
[ -x "$p/bin/make" ] || fail "fetch-make must print a prefix with bin/make"
: > "$t/calls"; [ "$(run)" = "$p" ] && [ ! -s "$t/calls" ] || fail "a fetched prefix must be reused"
rm -rf "$t/root"; if FAKE_NO_MAKE=1 run >/dev/null 2>&1; then fail "a pkg without bin/make must fail"; fi
grep -q 'fetch-make.sh' "$ROOT/build/build-slice.sh" || fail "build-slice.sh must run the family's make, not the host's"
if grep -n '/usr/bin/make' "$ROOT/build/build-slice.sh" | grep -v '^[0-9]*:#'; then
  fail "build-slice.sh must not run /usr/bin/make: on 10.9 it is a Command Line Tools stub"
fi
echo "PASS: fetch-make"
