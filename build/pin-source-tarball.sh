#!/bin/sh
# platform: host-agnostic
set -eu
CHECK=0
case "$#:${1:-}" in
  0:) ;;
  1:--check) CHECK=1 ;;
  *) echo "usage: sh build/pin-source-tarball.sh [--check] -- writes DIGEST (the commit of tag v<UPSTREAM_VERSION>, peeled) and TARBALL_SHA256 (the SHA-256 of GitHub's tarball of that commit) into components/ninja/source, after checking with git that the tarball is exactly that commit's tree; --check writes nothing. Exits 0 current or written, 3 --check found it stale, 1 any failure, 2 usage" >&2; exit 2 ;;
esac
T=""; NEW=""; want=""
trap 'rc=$?; [ -z "$T" ] || rm -rf "$T"; [ -z "$NEW" ] || rm -f "$NEW"; [ "$rc" = "$want" ] || rc=1; exit "$rc"' EXIT
trap 'want=130; exit 130' INT
trap 'want=143; exit 143' TERM
finish() { want=$1; exit "$1"; }
fail() { echo "FAIL: $*" >&2; finish 1; }
SELF="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SELF/.." && pwd)"
. "$SELF/versions.sh"
. "$SELF/msc.sh"
. "$SHIPYARD_SCRIPTS/mavericks_fetch.sh"
PINFILE="$REPO_ROOT/components/ninja/source"
[ -f "$SHIPYARD/fetch_pinned_source.sh" ] || fail "the shipyard at $SHIPYARD has no fetch_pinned_source.sh -- install a newer shipyard pkg"
repo="$NINJA_REPO"; pinned_digest="$NINJA_DIGEST"; pinned="$NINJA_TARBALL_SHA256"; tag="v$NINJA_VERSION"
[ -n "$repo" ] && [ -n "$NINJA_VERSION" ] || fail "$PINFILE has no REPO line, or UPSTREAM_VERSION is empty"
for k in DIGEST TARBALL_SHA256; do grep -q "^$k=" "$PINFILE" || fail "$PINFILE has no $k line"; done
T="$(mktemp -d "${TMPDIR:-/tmp}/pin-source-tarball.XXXXXX")"
NEW="$PINFILE.new.$$"
# platform: a lightweight tag lists one line (the commit); an annotated tag lists the tag object and
#           then, as refs/tags/<tag>^{}, the commit it peels to, which is the line that wins.
tags="$(git ls-remote "$repo" "refs/tags/$tag" "refs/tags/$tag^{}")" || fail "could not list $repo's tags"
digest="$(printf '%s\n' "$tags" | awk -v t="refs/tags/$tag" '$2 == t "^{}" { p = $1 } $2 == t { l = $1 } END { print (p != "") ? p : l }')"
case "$digest" in *[!0-9a-f]*|'') fail "$repo has no tag $tag (UPSTREAM_VERSION $NINJA_VERSION)" ;; esac
[ "${#digest}" -eq 40 ] || fail "$repo's tag $tag resolves to '$digest', not a commit"
echo "==> DIGEST: $tag is $digest"
url="$(sh "$SHIPYARD/fetch_pinned_source.sh" --url "$repo" "$digest")" || fail "shipyard has no tarball URL for $repo at '$digest'"
echo "==> TARBALL_SHA256: $url"
shipyard_curl "$url" "$T/src.tar.gz" || fail "could not fetch $url"
sha="$(shasum -a 256 < "$T/src.tar.gz" | cut -c1-64)"
mkdir -p "$T/x" && tar xzf "$T/src.tar.gz" -C "$T/x" || fail "could not extract $url"
top="$(ls -A "$T/x")"
[ -d "$T/x/$top" ] && [ "$(printf '%s\n' "$top" | wc -l | tr -d ' ')" = 1 ] || fail "$url holds more than one directory: $top"
tree="$T/x/$top"
# platform: git status never looks at an entry named .git (a directory, or a gitdir file) and
#           never reports an empty directory, so a tarball could carry either unseen. Neither is in
#           a commit's tree: git tracks no directory, and ninja's repository has no submodule
#           (whose gitlink git archive writes as an empty directory).
extra="$(find "$tree" \( -name .git -o -type d -empty \) -print | head -5)"
[ -z "$extra" ] || { printf '%s\n' "$extra" >&2; fail "$url is not commit $digest's tree: it holds the .git or empty directory above"; }
sh "$SHIPYARD/clone_pinned.sh" "$repo" "$tag" "$digest" "$T/clone" || fail "could not clone $repo at $digest"
# platform: a macOS clone's own core.ignorecase=true would pass a name that differs only in case, and
#           fileMode, symlinks and autocrlf are set rather than left to the host's git, so the
#           comparison is the same on every host.
diffs="$(git -c core.precomposeunicode=false -c core.ignorecase=false -c core.autocrlf=false -c core.fileMode=true \
  -c core.symlinks=true --git-dir="$T/clone/.git" --work-tree="$tree" status --porcelain --untracked-files=all --ignored)" \
  || fail "git could not compare $url with commit $digest"
[ -z "$diffs" ] || { printf '%s\n' "$diffs" | head -20 >&2; fail "$url is not commit $digest's tree (the differences above)"; }
echo "    $sha (the commit's tree, file for file)"
if [ "$pinned_digest" = "$digest" ] && [ "$pinned" = "$sha" ]; then echo "source: unchanged"; finish 0; fi
if [ "$CHECK" = 1 ]; then
  echo "FAIL: $PINFILE holds DIGEST $pinned_digest and TARBALL_SHA256 $pinned, but $tag is $digest and $url is $sha -- run sh build/pin-source-tarball.sh and commit components/ninja/source" >&2
  finish 3
fi
awk -v d="$digest" -v v="$sha" 'index($0, "DIGEST=") == 1 { $0 = "DIGEST=" d } index($0, "TARBALL_SHA256=") == 1 { $0 = "TARBALL_SHA256=" v } { print }' "$PINFILE" > "$NEW" || fail "could not write the pins"
grep -qx "DIGEST=$digest" "$NEW" && grep -qx "TARBALL_SHA256=$sha" "$NEW" || fail "could not write the pins"
mv "$NEW" "$PINFILE" || fail "could not write $PINFILE"
echo "source: wrote DIGEST and TARBALL_SHA256"
finish 0
