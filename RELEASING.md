# How Mentor is updated and released

**Rule: a new version number is only created when Are says the release is finished.**

## While working

- Every change gets a line under `## Unreleased` in `CHANGELOG.md`.
- `## Version` in `Mentor.toc` stays at the last released number with `+dev`
  added (for example `1.9.0+dev`) as soon as there are unreleased changes.
  Bug reports from test builds then show `+dev` and can't be mistaken for a
  real release.
- Test builds are made with `tools/package.sh` and named
  `Mentor-1.9.0+dev.zip`. They are for testing only - never upload them to
  CurseForge.

## Releasing (only when Are says it is finished)

1. Pick the new number: bug fixes only -> `1.9.1`, new features -> `1.10.0`.
2. `Mentor.toc`: set `## Version:` to the new number (remove `+dev`).
3. `CHANGELOG.md`: rename `## Unreleased` to `## <version> - <date>` and add a
   new empty `## Unreleased` section on top.
4. Commit, then tag and push: `git tag v<version> && git push --tags`.
5. `tools/package.sh` -> `Mentor-<version>.zip`. Upload it to CurseForge
   (game version: Forever, type: Release) and paste that version's changelog.
6. After the release the next change sets the version to `<version>+dev` again.
