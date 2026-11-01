#!/bin/sh
# platform: host-agnostic
#   usage: fetch-make.sh     prints the prefix of the family's GNU make (components/make/version), which a Mac's
#          build runs; its bin/make is universal, so one pkg serves 10.9 and Apple Silicon. Linux builds with
#          the host's CMake and Ninja instead
# platform: 10.9's /usr/bin/make is a Command Line Tools stub, and a modern Mac's is Xcode's
set -eu
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_ROOT/build/versions.sh"
. "$REPO_ROOT/build/msc.sh"
d="$WORK/make/$MAKE_VERSION"
[ -x "$d/bin/make" ] || sh "$SHIPYARD_SCRIPTS/fetch_product_pkg.sh" make "$MAKE_VERSION" "$d" >/dev/null
[ -x "$d/bin/make" ] || { echo "fetch-make: $d lacks bin/make" >&2; exit 1; }
echo "$d"
