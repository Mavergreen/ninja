#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
R="$ROOT/.github/workflows/release.yml"
fail() { echo "FAIL: $1"; exit 1; }
code="$(grep -v '^[[:space:]]*#' "$R" | sed 's/[[:space:]]#.*$//')"
line_of() { printf '%s\n' "$code" | grep -n -e "$1" | sed -n '1s/:.*//p'; }
has() { printf '%s\n' "$code" | grep -q -e "$1"; }
job() { printf '%s\n' "$code" | awk -v j="$1" '$0 ~ "^  "j":"{f=1;print;next} /^  [a-z][a-z-]*:$/{f=0} f'; }
step_if() { printf '%s\n' "$1" | awk -v p="$2" '/^      - /{if(m)print i; m=0; i=""} /^      - if: |^        if: /{i=$0; sub(/^ *(- )?if: /,"",i)} index($0,p){m=1} END{if(m)print i}'; }

printf '%s\n' "$code" | awk '/^  pull_request:/{f=1;next} f&&/branches:/{print;exit}' | grep -q '\[main\]' \
  || fail "release.yml must build pull requests to main: Renovate's automerge waits on that check"
printf '%s\n' "$code" | awk '/^  push:/{f=1;next} f&&/branches/{print;exit}' | grep -q "branches-ignore: \['renovate/\*\*'\]" \
  || fail "release.yml must build every branch push but Renovate's: a branch goes green before main does"
b="$(job build)"
printf '%s\n' "$b" | grep -q 'runs-on: ubuntu-latest' || fail "build runs on Linux: ninja builds, tests, packages and signs there"
printf '%s\n' "$b" | grep -q 'sh build/build.sh' || fail "the build job must build ninja"
printf '%s\n' "$b" | grep -q 'sh build/package-pkg.sh' || fail "the build job must package ninja"
printf '%s\n' "$b" | grep -q 'run-repo-tests.sh" --strict-host' || fail "the build job must run every host-agnostic test, and fail one that skips"
grep -q 'compat-gate.sh' "$ROOT/build/build.sh" || fail "build.sh must gate ninja as 10.9-safe before staging it"
if has 'rosetta'; then fail "release.yml must not use Rosetta: the shipped x86_64 ninja runs on 10.9, in the vm-test job"; fi
if grep -q '^- rosetta:' "$ROOT/INGREDIENTS.md"; then fail "nothing uses Rosetta any more, so INGREDIENTS.md declares no Rosetta use"; fi
mac="$(printf '%s\n' "$code" | awk '/^  [a-z][a-z-]*:$/{j=$1} /runs-on: macos-/{print j}' | tr -d ':' | xargs)"
[ "$mac" = modern-smoke ] || fail "the one job on a macOS runner is modern-smoke, not '$mac': macOS runners are scarce"
grep -q '^- macos-runner:release.yml:modern-smoke: ' "$ROOT/INGREDIENTS.md" || fail "INGREDIENTS.md must declare the modern-smoke macOS job"

vm="$(job vm-test)"
printf '%s\n' "$vm" | grep -q 'uses: Mavergreen/mavericks-vm@v1' || fail "a vm-test job must boot Mac OS X 10.9 with Mavergreen/mavericks-vm"
printf '%s\n' "$vm" | grep -q 'needs: \[ver, build\]' || fail "vm-test must test the pkg the build job made"
printf '%s\n' "$vm" | grep -q 'packages: write' || fail "vm-test needs packages: write for mavericks-vm's shared guest cache"
printf '%s\n' "$vm" | grep -q 'check-release-on-10.9.sh "$NINJA_FULL_VERSION" "$PWD/nt/ninja_test-x86_64"' \
  || fail "vm-test must pass the x86_64 ninja_test to check-release-on-10.9.sh: it is the only run of that slice's tests"
ms="$(job modern-smoke)"
printf '%s\n' "$ms" | grep -q 'needs: \[ver, build\]' || fail "modern-smoke must test the pkg the build job made"
printf '%s\n' "$ms" | grep -q 'sudo installer -pkg "dist/ninja-$NINJA_FULL_VERSION.pkg"' || fail "modern-smoke must install the pkg"
printf '%s\n' "$ms" | grep -q 'run-ninja-test.sh nt/ninja_test-arm64 tests/known-failures-arm64.txt' \
  || fail "modern-smoke must run the arm64 ninja_test: it is the only run of that slice's tests"
printf '%s\n' "$ms" | grep -q 'build/smoke.sh /usr/local/mavergreen/bin/ninja' || fail "modern-smoke must use the installed ninja"
printf '%s\n' "$ms" | grep -q 'build/launch-updater.sh' || fail "modern-smoke must launch the Linux-built updater on Apple Silicon"
grep -q 'launch-updater.sh' "$ROOT/build/check-release-on-10.9.sh" || fail "the 10.9 check must launch the Linux-built updater"
if printf '%s\n' "$ms" | grep -q 'SPARKLE_PRIVATE_KEY'; then fail "the macOS job never sees the signing key"; fi
guard="github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name != github.repository || startsWith(github.head_ref, 'renovate/')"
for j in vm-test modern-smoke; do
  jj="$(job "$j")"
  if printf '%s\n' "$jj" | grep -q 'continue-on-error'; then fail "$j must fail the run when it fails: no continue-on-error on the job or a step"; fi
  [ "$(printf '%s\n' "$jj" | sed -n 's/^    if: //p')" = "$guard" ] || fail "$j may skip only a fork's pull request: its if: must be the fork-PR guard alone"
  if printf '%s\n' "$jj" | grep -q -e '^      - if: ' -e '^        if: '; then fail "$j's steps run unconditionally: a skipped step is a smoke that did not run"; fi
done
if has 'secrets: inherit'; then fail "no job inherits every secret: the signing key reaches the build's signing step and scan alone"; fi
pub="$(job publish)"
for j in build vm-test modern-smoke scan; do
  printf '%s\n' "$pub" | grep 'needs:' | grep -q "[[ ]$j[],]" || fail "publish must wait for $j"
done
printf '%s\n' "$b" | grep -q 'SPARKLE_PRIVATE_KEY' || fail "the Linux build job holds the pkg, so it signs"
for x in stand-in-feeds.sh artifact-facts.sh assert_appcast_upgradeable.sh check-artifact-conformance.sh; do
  printf '%s\n' "$b" | grep -q "$x" || fail "the build job must run $x beside the pkg it made"
done
printf '%s\n' "$b" | grep -q 'OTOOL=$CL/bin/llvm-otool' || fail "Linux reads the pkg's Mach-O with clang22's llvm-otool"
printf '%s\n' "$b" | grep -q 'name: ninja-binaries' || fail "the build must upload the stage and updater it packaged, so another host can repackage them byte for byte"
bi="$(step_if "$b" 'ninja-binaries.tar')"
[ "$bi" = "github.event_name == 'workflow_dispatch'
github.event_name == 'workflow_dispatch'" ] \
  || fail "the ninja-binaries tar and its upload run on workflow_dispatch alone, a release or a conversion proof dispatched on a branch, not on every push (got: $bi)"
bb="$(line_of 'sh build/build.sh')"; t="$(line_of 'run-repo-tests.sh')"
[ -n "$bb" ] && [ -n "$t" ] && [ "$bb" -lt "$t" ] || fail "run-repo-tests.sh must run after sh build/build.sh"

notes="$(line_of 'release-notes.sh')"; state="$(line_of 'release-state-record.sh')"
sign="$(line_of 'sign_and_appcast.sh')"; publish="$(line_of 'publish-release.yml')"
[ -n "$notes" ] && [ -n "$state" ] && [ -n "$sign" ] && [ -n "$publish" ] \
  || fail "release.yml must generate notes, record the state, sign the appcast and publish"
[ "$notes" -lt "$state" ] && [ "$state" -lt "$sign" ] && [ "$sign" -lt "$publish" ] \
  || fail "notes, then the state marker, then signing, then publishing: the appcast and the Release must carry the same notes"
has 'sign_and_appcast.sh" --product ninja --feed-dir dist' || fail "the appcast must be ninja.xml, signed by sign_and_appcast.sh"
has 'scan-for-key.yml' || fail "a signing run must scan its logs for the key before publishing"
[ -x "$ROOT/build/check-release-on-10.9.sh" ] || fail "a release needs its real-10.9 check: build/check-release-on-10.9.sh"
printf '%s\n' "$code" | awk '/name: ninja-test$/{f=1} f&&/if-no-files-found: error/{ok=1} END{exit !ok}' \
  || fail "the ninja-test upload must set if-no-files-found: error"
rel="$(printf '%s\n' "$code" | awk '/name: mavergreen-ninja/{f=1;next} f&&/^[[:space:]]*- /{exit} f')"
printf '%s\n' "$rel" | grep -q 'ninja_test' && fail "the release artifact mavergreen-ninja must not include ninja_test"
for j in scan publish; do
  job "$j" | grep -q 'artifact: mavergreen-ninja' || fail "$j must use only the mavergreen-ninja artifact"
done

printf '%s\n' "$code" | grep -q '^      reconcile:$' || fail "workflow_dispatch declares the reconcile input the backstop sets"
has 'release-needed.sh' || fail "a reconcile dispatch publishes only while release-needed.sh says PUBLISH"
grep -q 'dispatch-field: reconcile=true' "$ROOT/.github/workflows/reconcile.yml" || fail "reconcile.yml dispatches with reconcile=true"
job retry | grep -q 'uses: Mavergreen/shipyard/.github/workflows/retry-release.yml@v1' || fail "a retry job re-dispatches a release that lost its tag race"
job retry | grep -q 'needs: \[ver, publish\]' || fail "retry needs publish"
gate="$(job required)"
printf '%s\n' "$gate" | grep -q 'name: required (release)' && printf '%s\n' "$gate" | grep -q 'if: always()' \
  && printf '%s\n' "$gate" | grep -q 'uses: Mavergreen/shipyard/.github/actions/required-gate@v1' \
  || fail "the required job is named 'required (release)', runs if: always() and uses the gate action"
others="$(printf '%s\n' "$code" | sed -n '/^jobs:$/,$s/^  \([a-z][a-z-]*\):$/\1/p' | grep -vx required | sort | xargs)"
gneeds="$(printf '%s\n' "$gate" | sed -n 's/^    needs: \[\(.*\)\]$/\1/p' | tr ',' '\n' | sed 's/ //g' | sort | xargs)"
[ "$others" = "$gneeds" ] || fail "the required job must need every other job ($others), not ($gneeds)"
echo "PASS: workflow invariants"
