# `ninja` for Mavericks

The ninja build system for Mac OS X 10.9 Mavericks.

## Building Mavericks ninja on Linux

The Linux path uses a pinned Linux clang22 release, host-native CMake and Ninja, and
shipyard's pinned SDK. Set `SHIPYARD_SCRIPTS` to a shipyard checkout's `scripts` directory
(or use its install action in CI), install Python 3.9+, curl and a SHA-256 tool, then run:

```sh
export MAVERICKS_BUILD_ROOT="$HOME/.cache/mavergreen-builds"
sh build/build.sh
```

The result is an x86_64 Mavericks executable, not a Linux executable. The build prints
its staged path and retains `ninja_test-x86_64` under the local work directory for testing
on Mavericks. Linux does not fetch the Mac make package or attempt a universal merge.
The shared clang22 version pin and `components/clang22/linux-sha256` must name the same
release; the pins bot verifies the archive bytes before updating the digest on a compiler
bump. Mac build and packaging workflows remain supported.
