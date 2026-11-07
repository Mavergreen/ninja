#!/bin/sh
# platform: host-agnostic
#   usage: package-pkg.sh     wraps the staged ninja and its updater into dist/ninja-<version>.pkg
#          (an x86_64-only stage, as a 10.9 build makes: dist/ninja-<version>-x86_64-dev.pkg, never
#          published). NINJA_UPDATER_APP names a built ninja-updater.app to package instead of building one.
#          build-info records the build tools that $WORK/build-tools.txt and the updater's build-tools.txt name.
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_ROOT/build/versions.sh"
. "$REPO_ROOT/build/msc.sh"
# platform: without it, cp on a Mac carries AppleDouble ._ files into the payload
COPYFILE_DISABLE=1; export COPYFILE_DISABLE
[ -x "$STAGE/bin/ninja" ] || { echo "package-pkg: no $STAGE/bin/ninja -- run build/build.sh first" >&2; exit 1; }
CL="$(sh "$REPO_ROOT/build/fetch-clang22.sh")"
archs="$("$CL/bin/llvm-lipo" -info "$STAGE/bin/ninja" | sed -n 's/.*: //p' | xargs)"
case "$archs" in
  "x86_64 arm64") host=x86_64,arm64; suffix=; variant=release ;;
  x86_64) host=x86_64; suffix=-x86_64-dev; variant=dev ;;
  *) echo "package-pkg: the staged ninja is '$archs', neither x86_64 nor x86_64 and arm64" >&2; exit 1 ;;
esac
sh "$REPO_ROOT/build/compat-gate.sh" "$STAGE/bin/ninja" "$archs" >&2
VER="$(sh "$SHIPYARD_SCRIPTS/resolve-version.sh" "$(sh "$SHIPYARD_SCRIPTS/release-mode.sh")")"
pr="$WORK/pkgroot"; scr="$WORK/pkg-scripts"; comp="$WORK/$SHORT-component.pkg"
rm -rf "$pr" "$scr" "$comp"; mkdir -p "$pr$(dirname "$PREFIX")" "$REPO_ROOT/dist"
rm -f "$REPO_ROOT"/dist/"$SHORT"-*.pkg
cp -R "$STAGE" "$pr$PREFIX"
app="${NINJA_UPDATER_APP:-$(sh "$REPO_ROOT/build/build-updater.sh")}"
[ -d "$app" ] || { echo "package-pkg: $app does not exist -- no updater app to package" >&2; exit 1; }
[ -x "$app/Contents/MacOS/$SHORT-updater" ] || { echo "package-pkg: $app has no executable Contents/MacOS/$SHORT-updater -- not a built updater" >&2; exit 1; }
find "$pr" -name '._*' -delete
sh "$SHIPYARD_SCRIPTS/stage_product.sh" --stage "$pr" --product "$SHORT" --name "ninja for Mavericks" \
  --version "$VER" --scripts-out "$scr" --updater-app "$app"
sh "$SHIPYARD_SCRIPTS/build_component_pkg.sh" --root "$pr" --identifier "$IDENTIFIER" --version "$VER" \
  --install-location / --scripts "$scr" --out "$comp" >/dev/null
pkg="$REPO_ROOT/dist/$SHORT-$VER$suffix.pkg"
sh "$SHIPYARD_SCRIPTS/set_install_floor.sh" --identifier "$IDENTIFIER" --title "ninja for Mavericks $VER" \
  --component "$comp" --out "$pkg" --min-os 10.9.5 --host-arch "$host" --require-scripts >/dev/null
rm -f "$comp"
set -- variant="$variant" arch="$host" prefix="$PREFIX" pkg="$(basename "$pkg")" identifier="$IDENTIFIER" \
  ninja="$NINJA_VERSION" clang22="$CLANG22_VERSION"
for f in "$WORK/build-tools.txt" "$(dirname "$app")/build-tools.txt"; do
  [ -s "$f" ] || { echo "package-pkg: no $f -- the build tools that built what ships must be recorded" >&2; exit 1; }
  while IFS= read -r l; do set -- "$@" "$l"; done < "$f"
done
rm -f "$REPO_ROOT"/dist/build-info-*.txt
sh "$SHIPYARD_SCRIPTS/build-info.sh" "$REPO_ROOT/dist/build-info-$variant.txt" "$@"
echo "$pkg"
