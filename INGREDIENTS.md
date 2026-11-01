# Build ingredients

Everything baked into the shipped `ninja` `.pkg`, where it is pinned, and how a change reaches a release.
The *own upstream* is ninja; an ingredient is anything else the artifact is built with.

| Ingredient | Pinned in | Renovate | On a bump |
|---|---|---|---|
| ninja source (own upstream) | `UPSTREAM_VERSION`, with the tag's commit and tarball SHA-256 in `components/ninja/source` | ✅ `github-tags` on `ninja-build/ninja`; the pins bot writes `components/ninja/source` | cuts `<ver>-mavericks.1` |
| googletest (ninja's tests; not shipped) | ninja's own `CMakeLists.txt` (URL and SHA-256), inside the pinned source | ✅ moves with `UPSTREAM_VERSION` | rebuild and test |
| clang22 N−1 (compiler, linker, Mach-O tools; the x86_64 slice's static libc++ and Recaulk, with the system C++ ABI and unwinder; builds the updater too) | `components/clang22/version`, plus the Linux archive digest in `components/clang22/linux-sha256` | ✅ `github-releases` on `Mavergreen/clang-22`, `-mavericks.N` versioning; pins bot verifies and records the matching Linux archive | repackage → `-mavericks.(N+1)` |
| Recaulk (`librecaulk.a`, bundled in clang22 N−1; x86_64 only: `clock_gettime` and kin for libc++'s chrono) | `components/clang22/version` (moves with clang22) | ✅ via the clang22 pin | repackage → `-mavericks.(N+1)` |
| GNU make (runs a Mac's slice builds; universal, so the same pkg on 10.9 and Apple Silicon; Linux uses the host's Ninja) | `components/make/version` | ✅ `github-releases` on `Mavergreen/make`, `-mavericks.N` versioning | repackage → `-mavericks.(N+1)` |
| Linux host CMake and Ninja (configure and build both slices and, with the runner's make, the updater; a Mac's updater build uses the make on `PATH`) | runner-provided, unpinned; build-info records each `--version` (`build-cmake`, `build-ninja`, `updater-cmake`, `updater-build-tool`) | ❌ untrackable here: the runner image provides them, so no pin exists to track. Exit: a pinned cmake/ninja on Linux hosts (shipyard QUEUE) | none; a runner image update can change them |
| MacOSX10.9 and MacOSX11.3 SDKs | shipyard `fetch_sdk.sh` (pinned by hash) | ✅ moves with shipyard `@v1` | moving tag |
| Sparkle 1.27.3 (embedded in `ninja-updater.app`) | shipyard `fetch_sparkle_framework.sh` (pinned by hash) | ✅ moves with shipyard `@v1` | moving tag |

## ninja source verification

GitHub's tarball of the commit `v<UPSTREAM_VERSION>` names, verified against `TARBALL_SHA256` by shipyard's
`fetch_pinned_source.sh`; no build runs git. On a Renovate bump the pins bot resolves the tag's commit
and writes `DIGEST` and `TARBALL_SHA256` only after the extracted tarball equals a clone of that commit,
file for file. By hand: `sh build/pin-source-tarball.sh` (needs git).

## Build

Each slice is built by clang22 N−1 (shipyard's `fetch_clang22.sh`: the Linux archive on Linux, the cross
pkg on a modern Mac, the native pkg on 10.9) against ninja's own `CMakeLists.txt`: x86_64 against
MacOSX10.9.sdk (10.9), arm64 against MacOSX11.3.sdk (11.0). re2c is never used (the tarball's generated
lexers are). On Linux, the host's CMake and Ninja run the build; on a Mac, `shipyard-cmake -G "Unix
Makefiles"` and the family's GNU `make` (`components/make/version`). Linux and a modern Mac build both
slices and merge them into one file with clang22's `llvm-lipo` (shipyard's `lipo-merge-tree.sh`); 10.9
builds x86_64 alone, packaged as `-x86_64-dev`, never published. The Sparkle updater is built the same
way, one configure per arch with clang22, and merged likewise. Packaging runs on shipyard's stevedore
seams, so CI builds, tests, packages and signs on Linux. The Linux archive digest moves with the clang22
version; it is verified against the release's bytes before the pins bot writes it. Build and cache
paths stay on local disk.

## Running the shipped ninja

Neither slice runs on the Linux build host. The `vm-test` job boots Mac OS X 10.9.5 with
`Mavergreen/mavericks-vm`, installs the built pkg and runs `build/check-release-on-10.9.sh` with the
x86_64 `ninja_test`, which also launches the updater check-only. The `modern-smoke` job installs the
pkg on an Apple Silicon runner, runs the installed ninja, the arm64 `ninja_test` and the updater.
Publishing waits for both.

## Declared state

- upstream: UPSTREAM_VERSION
- ninja-source: components/ninja/source
- clang22: components/clang22/version

## Conformance deviations

- arm64:usr/local/mavergreen/ninja/bin/ninja: developers and CI on Apple Silicon run this ninja to build Mavericks artifacts, so the pkg carries an arm64 (11.0) slice beside the x86_64 (10.9) one.
- macos-runner:release.yml:modern-smoke: the arm64 slice is installed and run on current macOS (spec: modern-slice products); exit: none while the slice ships
- static-cxx-runtime:build/build-slice.sh: the x86_64 slice links LLVM 22's libc++ statically and uses Mavericks' system libc++abi and unwinder, matching clang22's one-ABI contract. Reconsider when the family's runtime policy changes.
- system-cxx-runtime:build/build-slice.sh: the arm64 slice links macOS's /usr/lib/libc++.1.dylib, compiled against the MacOSX11.3 SDK's libc++ headers: no arm64 libcxx exists, and clang22-cross's runtimes are x86_64 only; revisit when an arm64 libcxx exists.
