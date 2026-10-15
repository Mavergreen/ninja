# platform: host-agnostic
#   usage: . build/versions.sh     names, paths and pins every build script uses
: "${REPO_ROOT:=$(cd "$(dirname "$0")/.." && pwd)}"
export REPO_ROOT
NINJA_VERSION="$(tr -d ' \t\n' < "$REPO_ROOT/UPSTREAM_VERSION")"
NINJA_REPO="$(sed -n 's/^REPO=//p' "$REPO_ROOT/components/ninja/source")"
NINJA_DIGEST="$(sed -n 's/^DIGEST=//p' "$REPO_ROOT/components/ninja/source")"
NINJA_TARBALL_SHA256="$(sed -n 's/^TARBALL_SHA256=//p' "$REPO_ROOT/components/ninja/source")"
CLANG22_VERSION="$(tr -d ' \t\n' < "$REPO_ROOT/components/clang22/version")"
# spec: SKILL.md "Build OUT of the source tree" -- a checkout may live on NFS
WORK="${MAVERICKS_BUILD_ROOT:-${TMPDIR:-/tmp}/mm-build}/mavergreen-ninja"
PREFIX=/usr/local/mavergreen/ninja
STAGE_ROOT="$WORK/stage"
STAGE="$STAGE_ROOT$PREFIX"
SHORT=ninja
IDENTIFIER=dev.mavergreen.ninja
export NINJA_VERSION NINJA_REPO NINJA_DIGEST NINJA_TARBALL_SHA256 CLANG22_VERSION WORK PREFIX STAGE_ROOT STAGE SHORT IDENTIFIER
