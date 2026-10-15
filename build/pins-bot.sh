#!/bin/sh
# platform: host-agnostic
set -eu
HERE="$(cd "$(dirname "$0")/.." && pwd)"
REL=components/ninja/source
PINS="$HERE/$REL"
KEYS="DIGEST TARBALL_SHA256"
BASEFILE=UPSTREAM_VERSION
USAGE="usage: sh build/pins-bot.sh moved <base-ref> | values | apply DIGEST=<40 hex> TARBALL_SHA256=<64 hex> | fill <base-ref> -- what .github/workflows/pins-bot.yml decides and writes on Renovate's branch. moved: exit 0, printing the changed lines, when UPSTREAM_VERSION differs from where the branch left <base-ref>, else 1. values: prints DIGEST=<commit> TARBALL_SHA256=<hash>. apply: writes them and nothing else, refusing another key, a value that is not 40 (DIGEST) or 64 (TARBALL_SHA256) hex digits or a key given twice, printing changed or unchanged. fill: exit 0 printing nothing unless moved says yes and build/pin-source-tarball.sh --check exits 3, then writes and prints the values; any other status exits 1 having printed nothing"
hexn() { case "$2" in *[!0-9a-f]*|'') return 1 ;; esac; [ "${#2}" -eq "$1" ]; }
lenof() { case "$1" in DIGEST) echo 40 ;; *) echo 64 ;; esac; }
what() { case "$1" in DIGEST) echo "a commit (40 hex digits)" ;; *) echo "a SHA-256" ;; esac; }
case "${1:-}" in
  moved)
    [ $# -eq 2 ] || { echo "$USAGE" >&2; exit 2; }
    base="$(git -C "$HERE" merge-base "$2" HEAD)" || { echo "pins-bot: no merge base with $2" >&2; exit 2; }
    # platform: the diff is taken whole first, as a pipe would read a git that fails as "not moved" (exit 1).
    d="$(git -C "$HERE" diff "$base" HEAD -- "$BASEFILE")" || { echo "pins-bot: git diff $base HEAD -- $BASEFILE failed" >&2; exit 2; }
    lines="$(printf '%s\n' "$d" | grep -E '^[-+][^-+]' || :)"
    [ -n "$lines" ] || exit 1
    printf '%s\n' "$lines" ;;
  values)
    [ $# -eq 1 ] || { echo "$USAGE" >&2; exit 2; }
    out=""
    for k in $KEYS; do
      v="$(sed -n "s/^$k=//p" "$PINS")"
      hexn "$(lenof "$k")" "$v" || { echo "pins-bot: $REL's $k is '$v', not $(what "$k")" >&2; exit 1; }
      out="$out${out:+ }$k=$v"
    done
    echo "$out" ;;
  apply)
    shift; [ $# -gt 0 ] || { echo "$USAGE" >&2; exit 2; }
    seen=" "
    for kv in "$@"; do
      k="${kv%%=*}"; v="${kv#*=}"
      case " $KEYS " in *" $k "*) ;; *) echo "pins-bot: '$k' is not a source pin ($KEYS)" >&2; exit 1 ;; esac
      case "$seen" in *" $k "*) echo "pins-bot: $k given twice" >&2; exit 1 ;; esac
      hexn "$(lenof "$k")" "$v" || { echo "pins-bot: $k's value '$v' is not $(what "$k")" >&2; exit 1; }
      grep -q "^$k=" "$PINS" || { echo "pins-bot: $REL has no $k line" >&2; exit 1; }
      seen="$seen$k "
    done
    tmp="$(mktemp "${TMPDIR:-/tmp}/pins-bot.XXXXXX")"
    awk -v kvs="$*" 'BEGIN { n = split(kvs, a, " "); for (i = 1; i <= n; i++) { j = index(a[i], "="); v[substr(a[i], 1, j - 1)] = substr(a[i], j + 1) } }
      { j = index($0, "="); k = (j > 1) ? substr($0, 1, j - 1) : ""
        if (k in v) $0 = k "=" v[k]
        print }' "$PINS" > "$tmp"
    if cmp -s "$tmp" "$PINS"; then rm -f "$tmp"; echo unchanged; else cat "$tmp" > "$PINS"; rm -f "$tmp"; echo changed; fi ;;
  fill)
    [ $# -eq 2 ] || { echo "$USAGE" >&2; exit 2; }
    rc=0; sh "$HERE/build/pins-bot.sh" moved "$2" >&2 || rc=$?
    case "$rc" in
      0) ;;
      1) echo "pins-bot: UPSTREAM_VERSION did not move: nothing to do" >&2; exit 0 ;;
      *) echo "pins-bot: could not tell whether UPSTREAM_VERSION moved (moved exited $rc)" >&2; exit 1 ;;
    esac
    rc=0; sh "$HERE/build/pin-source-tarball.sh" --check >&2 || rc=$?
    case "$rc" in
      0) echo "pins-bot: the source pin is current: nothing to do" >&2; exit 0 ;;
      3) echo "pins-bot: the source pin is stale: writing it" >&2 ;;
      *) echo "pins-bot: pin-source-tarball.sh --check exited $rc, an error rather than a stale pin: writing nothing" >&2; exit 1 ;;
    esac
    sh "$HERE/build/pin-source-tarball.sh" >&2 || { echo "pins-bot: pin-source-tarball.sh could not write the pin" >&2; exit 1; }
    sh "$HERE/build/pins-bot.sh" values ;;
  *) echo "$USAGE" >&2; exit 2 ;;
esac
