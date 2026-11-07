#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/build/versions.sh"; . "$ROOT/build/msc.sh"
fail() { echo "FAIL: $1"; exit 1; }
t="$(mktemp -d "${TMPDIR:-/tmp}/ninja-updater-app.XXXXXX")"; trap 'rm -rf "$t"' EXIT INT TERM
CL="$(sh "$ROOT/build/fetch-clang22.sh")"
SP="$(sh "$SHIPYARD_SCRIPTS/fetch_sparkle_framework.sh")/Versions/A/Sparkle"
mkdir -p "$t/repo" "$t/work/mavergreen-ninja/stage$PREFIX/bin" "$t/empty.app/Contents/MacOS"
cp -R "$ROOT/build" "$ROOT/components" "$t/repo/"; cp "$ROOT/UPSTREAM_VERSION" "$t/repo/"
printf '%s-mavericks.1\n' "$NINJA_VERSION" > "$t/repo/VERSION"
cp "$SP" "$t/work/mavergreen-ninja/stage$PREFIX/bin/ninja"; chmod +x "$t/work/mavergreen-ninja/stage$PREFIX/bin/ninja"
printf '#!/bin/sh\necho %s\n' "$CL" > "$t/repo/build/fetch-clang22.sh"
printf '#!/bin/sh\n:\n' > "$t/repo/build/compat-gate.sh"
printf '#!/bin/sh\necho "build-updater.sh must not run when NINJA_UPDATER_APP names an app" >&2; exit 1\n' > "$t/repo/build/build-updater.sh"
for app in "$t/nope.app" "$t/empty.app"; do
  if out="$(NINJA_UPDATER_APP="$app" MAVERICKS_BUILD_ROOT="$t/work" sh "$t/repo/build/package-pkg.sh" 2>&1)"; then
    fail "package-pkg.sh must refuse NINJA_UPDATER_APP=$app"
  fi
  case "$out" in "package-pkg: $app"*) ;; *) fail "the refusal must name $app before anything else uses it (got: $out)" ;; esac
done
case "$out" in *"Contents/MacOS/ninja-updater"*) ;; *) fail "an app with no executable must be refused for that (got: $out)" ;; esac
[ -z "$(ls "$t/repo/dist" 2>/dev/null)" ] || fail "a refused package must leave no pkg in dist/"
echo "PASS: updater-app"
