# Release notes

The generator (`release-notes.sh`, from shipyard) writes the notes file for every release: the title, a
"What changed" section (with a link to ninja's own notes for a new upstream), a "Build ingredients"
section when a pin moved, and the footer. That one file, `dist/RELEASE_NOTES.md`, becomes the GitHub
Release body and the Sparkle feed's (`ninja.xml`) `<description>`: the same bytes, read twice.

A file here named `<full-version>.md` (e.g. `1.13.2-mavericks.1.md`) is OPTIONAL hand-written prose
for that one release. When present, it is inserted verbatim right after the generated title. It must
NOT start with its own `## ` heading, since the generator already emits the title.

Most releases have no file here, and that's fine: the generator's own sections are the whole note.

## Before trusting a release

On a real Mac OS X 10.9 box, run `sh build/check-release-on-10.9.sh <version>`: it fetches the
release's pkg, verifies it against `SHA256SUMS`, installs it, runs `ninja` from a login shell (its
version and a smoke build), and uninstalls it. CI's `vm-test` job runs the same script, plus the x86_64
`ninja_test`, against each build in a 10.9.5 VM; this run is the one on real hardware, against what was
actually published.
