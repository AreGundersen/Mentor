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
4. Commit and push to main (and tag: `git tag v<version> && git push --tags`).
5. The GitHub Action "CurseForge upload" (.github/workflows/curseforge.yml)
   sees the new version number in Mentor.toc, builds the zip with
   `tools/package.sh` and uploads it to CurseForge as a Release (game version:
   Forever) with this version's changelog. It needs the repository secret
   `CF_API_KEY`. If the Action can't be used: `tools/package.sh` ->
   `Mentor-<version>.zip`, upload it by hand (Forever, Release) and paste the
   changelog.
6. After the release the next change sets the version to `<version>+dev` again.
