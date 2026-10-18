#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
R="$ROOT/.github/workflows/release.yml"
fail() { echo "FAIL: $1"; exit 1; }
code="$(grep -v '^[[:space:]]*#' "$R")"
line_of() { printf '%s\n' "$code" | grep -n -e "$1" | sed -n '1s/:.*//p'; }
has() { printf '%s\n' "$code" | grep -q -e "$1"; }

printf '%s\n' "$code" | awk '/^  pull_request:/{f=1;next} f&&/branches:/{print;exit}' | grep -q '\[main\]' \
  || fail "release.yml must build pull requests to main: Renovate's automerge waits on that check"
printf '%s\n' "$code" | awk '/^  push:/{f=1;next} f&&/branches/{print;exit}' | grep -q "branches-ignore: \['renovate/\*\*'\]" \
  || fail "release.yml must build every branch push but Renovate's: a branch goes green before main does"
has 'sh build/build.sh' || fail "release.yml must build ninja"
grep -q 'compat-gate.sh' "$ROOT/build/build.sh" || fail "build.sh must gate ninja as 10.9-safe before staging it"
has 'sh build/package-pkg.sh' || fail "release.yml must package ninja"
has 'run-repo-tests.sh' || fail "release.yml must run the repo's tests"
if has 'rosetta'; then fail "release.yml must not use Rosetta: the shipped x86_64 ninja runs on 10.9, in the vm-test job"; fi
if grep -q '^- rosetta:' "$ROOT/INGREDIENTS.md"; then fail "nothing uses Rosetta any more, so INGREDIENTS.md declares no Rosetta use"; fi
vm="$(printf '%s\n' "$code" | awk '/^  vm-test:/{f=1;print;next} /^  [a-z][a-z-]*:$/{f=0} f')"
printf '%s\n' "$vm" | grep -q 'uses: Mavergreen/mavericks-vm@v1' || fail "a vm-test job must boot Mac OS X 10.9 with Mavergreen/mavericks-vm"
printf '%s\n' "$vm" | grep -q 'needs: \[ver, build\]' || fail "vm-test must test the pkg the build job made"
printf '%s\n' "$vm" | grep -q 'build/check-release-on-10.9.sh' || fail "vm-test must install and use the pkg on 10.9 with build/check-release-on-10.9.sh"
printf '%s\n' "$vm" | grep -q 'ninja-test-x86_64' || fail "vm-test must download the ninja-test-x86_64 artifact"
printf '%s\n' "$vm" | grep -q 'packages: write' || fail "vm-test needs packages: write for mavericks-vm's shared guest cache"
printf '%s\n' "$code" | awk '/^  publish:/{f=1;next} /^  [a-z][a-z-]*:$/{f=0} f&&/needs:/' | grep -q 'vm-test' \
  || fail "publish must wait for vm-test: a ninja that did not run on 10.9 must not ship"
b="$(line_of 'sh build/build.sh')"; t="$(line_of 'run-repo-tests.sh')"
[ -n "$b" ] && [ -n "$t" ] && [ "$b" -lt "$t" ] || fail "run-repo-tests.sh must run after sh build/build.sh"
has 'check-artifact-conformance.sh' || fail "release.yml must check artifact conformance"

notes="$(line_of 'release-notes.sh')"; state="$(line_of 'release-state-record.sh')"
sign="$(line_of 'sign_and_appcast.sh')"; publish="$(line_of 'publish-release.yml')"
[ -n "$notes" ] && [ -n "$state" ] && [ -n "$sign" ] && [ -n "$publish" ] \
  || fail "release.yml must generate notes, record the state, sign the appcast and publish"
[ "$notes" -lt "$state" ] && [ "$state" -lt "$sign" ] && [ "$sign" -lt "$publish" ] \
  || fail "notes, then the state marker, then signing, then publishing: the appcast and the Release must carry the same notes"
has 'sign_and_appcast.sh" --product ninja --feed-dir dist' || fail "the appcast must be ninja.xml, signed by sign_and_appcast.sh"
has 'scan-for-key.yml' || fail "a signing run must scan its logs for the key before publishing"
[ -x "$ROOT/build/check-release-on-10.9.sh" ] || fail "a release needs its real-10.9 check: build/check-release-on-10.9.sh"
printf '%s\n' "$vm" | grep -q 'check-release-on-10.9.sh "$NINJA_FULL_VERSION" "$PWD/nt/ninja_test-x86_64"' \
  || fail "vm-test must pass the x86_64 ninja_test to check-release-on-10.9.sh: it is the only run of it"
printf '%s\n' "$code" | awk '/name: ninja-test-x86_64/{f=1} f&&/if-no-files-found: error/{ok=1} END{exit !ok}' \
  || fail "the ninja-test-x86_64 upload must set if-no-files-found: error"
rel="$(printf '%s\n' "$code" | awk '/name: mavergreen-ninja/{f=1;next} f&&/^[[:space:]]*- /{exit} f')"
printf '%s\n' "$rel" | grep -q 'ninja_test' && fail "the release artifact mavergreen-ninja must not include ninja_test"
for j in scan publish; do
  printf '%s\n' "$code" | awk -v j="$j" '$0 ~ "^  "j":"{f=1;next} /^  [a-z][a-z-]*:$/{f=0} f' | grep -q 'artifact: mavergreen-ninja' \
    || fail "$j must use only the mavergreen-ninja artifact"
done
echo "PASS: workflow invariants"
