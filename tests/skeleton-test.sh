#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
cd "$ROOT"
grep -Eqx '[0-9]+\.[0-9]+\.[0-9]+' UPSTREAM_VERSION || fail "UPSTREAM_VERSION must be a bare x.y.z"
[ "$(sed -n 's/^REPO=//p' components/ninja/source)" = https://github.com/ninja-build/ninja.git ] || fail "components/ninja/source: REPO"
sed -n 's/^DIGEST=//p' components/ninja/source | grep -Eqx '[0-9a-f]{40}' || fail "components/ninja/source: DIGEST must be 40 hex"
sed -n 's/^TARBALL_SHA256=//p' components/ninja/source | grep -Eqx '[0-9a-f]{64}' || fail "components/ninja/source: TARBALL_SHA256 must be 64 hex"
[ "$(grep -c '=' components/ninja/source)" = 3 ] || fail "components/ninja/source holds exactly REPO, DIGEST and TARBALL_SHA256"
grep -Eqx '[0-9]+\.[0-9]+\.[0-9]+-mavericks\.[0-9]+' components/clang22/version || fail "components/clang22/version: x.y.z-mavericks.N"
for l in /VERSION /dist/ .superpowers/ .idea/; do grep -qxF "$l" .gitignore || fail ".gitignore must list $l"; done
[ "$(cat comment-reasons)" = "platform
spec" ] || fail "comment-reasons must opt into platform and spec"
. "$ROOT/build/versions.sh"
[ "$NINJA_VERSION" = "$(cat UPSTREAM_VERSION)" ] && [ "$SHORT" = ninja ] && [ "$IDENTIFIER" = dev.mavergreen.ninja ] \
  && [ "$PREFIX" = /usr/local/mavergreen/ninja ] && [ "$STAGE" = "$STAGE_ROOT$PREFIX" ] || fail "build/versions.sh values"
[ "$(sh build/upstream-release-notes-url.sh 1.13.2)" = https://github.com/ninja-build/ninja/releases/tag/v1.13.2 ] || fail "upstream notes URL"
. "$ROOT/build/msc.sh"
cmp -s build/msc.sh "$SHIPYARD_SCRIPTS/templates/msc.sh" || fail "build/msc.sh must equal shipyard's scripts/templates/msc.sh byte for byte (check 17)"
echo "PASS: skeleton"
