#!/bin/sh
# platform: macOS-only -- ditto, pkgbuild and productbuild make the pkg
#   usage: package-pkg.sh     wraps the staged ninja and its updater into dist/ninja-<version>.pkg
#          (a 10.9 build: dist/ninja-<version>-x86_64-dev.pkg, never published)
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_ROOT/build/versions.sh"
. "$REPO_ROOT/build/msc.sh"
# platform: without it, ditto and pkgbuild carry AppleDouble ._ files into the payload
COPYFILE_DISABLE=1; export COPYFILE_DISABLE
[ -x "$STAGE/bin/ninja" ] || { echo "package-pkg: no $STAGE/bin/ninja -- run build/build.sh first" >&2; exit 1; }
mode="${MAVERICKS_MODE:-$(sh "$SHIPYARD_SCRIPTS/mavericks_mode.sh")}"
if [ "$mode" = cross ]; then archs="x86_64 arm64"; host=x86_64,arm64; suffix=; variant=release
else archs=x86_64; host=x86_64; suffix=-x86_64-dev; variant=dev; fi
sh "$REPO_ROOT/build/compat-gate.sh" "$STAGE/bin/ninja" "$archs" >&2
VER="$(sh "$SHIPYARD_SCRIPTS/resolve-version.sh" "$(sh "$SHIPYARD_SCRIPTS/release-mode.sh")")"
pr="$WORK/pkgroot"; scr="$WORK/pkg-scripts"; comp="$WORK/$SHORT-component.pkg"
rm -rf "$pr" "$scr" "$comp"; mkdir -p "$pr$(dirname "$PREFIX")" "$REPO_ROOT/dist"
rm -f "$REPO_ROOT"/dist/"$SHORT"-*.pkg
# platform: macOS stamps com.apple.provenance on every file a tracked process writes; --noextattr drops the rest
ditto --norsrc --noextattr --noacl "$STAGE" "$pr$PREFIX"
app="$(sh "$REPO_ROOT/build/build-updater.sh")"
find "$pr" -name '._*' -delete
sh "$SHIPYARD_SCRIPTS/stage_product.sh" --stage "$pr" --product "$SHORT" --name "ninja for Mavericks" \
  --version "$VER" --scripts-out "$scr" --updater-app "$app"
sh "$SHIPYARD_SCRIPTS/build_component_pkg.sh" --root "$pr" --identifier "$IDENTIFIER" --version "$VER" \
  --install-location / --scripts "$scr" --out "$comp" >/dev/null
pkg="$REPO_ROOT/dist/$SHORT-$VER$suffix.pkg"
sh "$SHIPYARD_SCRIPTS/set_install_floor.sh" --identifier "$IDENTIFIER" --title "ninja for Mavericks $VER" \
  --component "$comp" --out "$pkg" --min-os 10.9.5 --host-arch "$host" --require-scripts >/dev/null
rm -f "$comp"
sh "$SHIPYARD_SCRIPTS/build-info.sh" "$REPO_ROOT/dist/build-info-$variant.txt" \
  variant="$variant" arch="$host" prefix="$PREFIX" pkg="$(basename "$pkg")" identifier="$IDENTIFIER" \
  ninja="$NINJA_VERSION" clang22="$CLANG22_VERSION"
echo "$pkg"
