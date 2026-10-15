#!/bin/sh
# platform: host-agnostic
#   usage: upstream-release-notes-url.sh <upstream-version>     prints ninja's notes URL for it
set -eu
printf 'https://github.com/ninja-build/ninja/releases/tag/v%s\n' "${1:?usage: upstream-release-notes-url.sh <upstream-version>}"
