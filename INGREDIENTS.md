# Build ingredients

Everything baked into the shipped `ninja` `.pkg`, where it is pinned, and how a change reaches a release.
The *own upstream* is ninja; an ingredient is anything else the artifact is built with.

| Ingredient | Pinned in | Renovate | On a bump |
|---|---|---|---|
| ninja source (own upstream) | `UPSTREAM_VERSION`, with the tag's commit and tarball SHA-256 in `components/ninja/source` | ✅ `github-tags` on `ninja-build/ninja`; the pins bot writes `components/ninja/source` | cuts `<ver>-mavericks.1` |
| googletest (ninja's tests; not shipped) | ninja's own `CMakeLists.txt` (URL and SHA-256), inside the pinned source | ✅ moves with `UPSTREAM_VERSION` | rebuild and test |
| clang22 N−1 (compiler, linker; the x86_64 slice's static libc++, libc++abi and libunwind) | `components/clang22/version` | ✅ `github-releases` on `Mavergreen/clang-22`, `-mavericks.N` versioning | repackage → `-mavericks.(N+1)` |
| Recaulk (`librecaulk.a`, bundled in clang22 N−1; x86_64 only: `clock_gettime` and kin for libc++'s chrono) | `components/clang22/version` (moves with clang22) | ✅ via the clang22 pin | repackage → `-mavericks.(N+1)` |
| GNU make (runs the slice builds; universal, so the same pkg on 10.9 and the arm64 runner) | `components/make/version` | ✅ `github-releases` on `Mavergreen/make`, `-mavericks.N` versioning | repackage → `-mavericks.(N+1)` |
| MacOSX10.9 and MacOSX11.3 SDKs | shipyard `fetch_sdk.sh` (pinned by hash) | ✅ moves with shipyard `@v1` | moving tag |
| Sparkle 1.27.3 (embedded in `ninja-updater.app`) | shipyard `fetch_sparkle_framework.sh` (pinned by hash) | ✅ moves with shipyard `@v1` | moving tag |

## ninja source verification

GitHub's tarball of the commit `v<UPSTREAM_VERSION>` names, verified against `TARBALL_SHA256` by shipyard's
`fetch_pinned_source.sh`; no build runs git. On a Renovate bump the pins bot resolves the tag's commit
and writes `DIGEST` and `TARBALL_SHA256` only after the extracted tarball equals a clone of that commit,
file for file. By hand: `sh build/pin-source-tarball.sh` (needs git).

## Build

Each slice is configured by `shipyard-cmake -G "Unix Makefiles"` against ninja's own `CMakeLists.txt` and
built by the family's GNU `make` (`components/make/version`), with clang22 N−1: x86_64 against MacOSX10.9.sdk (10.9), arm64 against MacOSX11.3.sdk
(11.0). re2c is never used (the tarball's generated lexers are). On a modern Mac the slices are merged
into one file; on 10.9 the build makes x86_64 alone, named `-x86_64-dev`, never published. The merge uses the host's `lipo` (Xcode's, via shipyard's
`lipo-merge-tree.sh`), not clang22's llvm-lipo.

## Running the shipped ninja

CI builds on an Apple Silicon runner, where the arm64 slice's `ninja_test` and smoke run. The x86_64
slice never runs there: the `vm-test` job boots Mac OS X 10.9.5 with `Mavergreen/mavericks-vm`,
installs the built pkg and runs `build/check-release-on-10.9.sh` with the x86_64 `ninja_test`.
Publishing waits for it.

## Declared state

- upstream: UPSTREAM_VERSION
- ninja-source: components/ninja/source
- clang22: components/clang22/version

## Conformance deviations

- arm64:build/build.sh: developers and CI on Apple Silicon run this ninja to build Mavericks artifacts, so the pkg carries an arm64 (11.0) slice beside the x86_64 (10.9) one.
- static-cxx-runtime:build/build-slice.sh: the x86_64 slice links LLVM 22's libc++, libc++abi and libunwind statically, clang22 N−1's own clang++.cfg default, until clang22 links the family's shared libc++.
- system-cxx-runtime:build/build-slice.sh: the arm64 slice links macOS's /usr/lib/libc++.1.dylib, compiled against the MacOSX11.3 SDK's libc++ headers: no arm64 libcxx exists, and clang22-cross's runtimes are x86_64 only; revisit when an arm64 libcxx exists.
