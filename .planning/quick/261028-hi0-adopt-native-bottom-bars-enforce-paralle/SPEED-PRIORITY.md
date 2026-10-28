# Release speed priority — 2026-10-28

The owner prioritizes runtime speed over executable size and explicitly asks to drop the optimization
commit. Commit `32bf2a307` is removed from `feature/gsd-phase-17` by replaying its six later commits onto
`f195b7eaaf`. No remote branch is changed. A local recovery reference,
`refs/backup/release-speed-20261028`, preserves the original history and measurement provenance.

## Retained behavior

- Project Release optimization returns to `-O`; Debug remains `-Onone` and whole-module Release
  compilation remains enabled.
- The package's explicit `-Osize` unsafe flag and the build-wide size xcconfig are removed.
- Both deployment workflows again pass `SWIFT_OPTIMIZATION_LEVEL=-O`.
- Preview-only helpers and the frozen identifier table remain excluded from Release. All UI changes,
  test parallelism policy and fixture repairs remain in the branch.
- The old 29,793,340-byte payload and 12.35% saving describe the withdrawn `-Osize` experiment.
  The current `-O` plus preview-cleanup payload has not been remeasured. No speed percentage is claimed.

## History mapping

All six replayed patches are byte-identical to their originals. Before the documentation update,
only the optimization commit's five files differ from the previous branch tip, and those five files
exactly match their pre-optimization versions. The dropped commit is no longer an ancestor of this
branch. Capture and measurement commit links now identify corresponding retained changes.
Historical artifact hashes and configuration records remain unchanged. The full old-to-new
mapping is retained outside the repository in the verification evidence.

| Retained change | Current commit |
|---|---|
| Preview fixture exclusions | `279897ed0c` |
| Size and screenshot record | `f45d526203` |
| Persistent Library title menu | `25649f32c2` |
| Bottom edges and Archives bar | `adaf3d6017` |
| UI verification record | `96f4276c27` |
| Final Library control choice | `6e99373f5e` |

## Verification

- `git range-diff` marks all six replayed patches unchanged; exact patch-byte checks agree.
- Xcode resolves Release to `SWIFT_OPTIMIZATION_LEVEL=-O` with `SWIFT_COMPILATION_MODE=wholemodule`.
- Xcode resolves Debug to `SWIFT_OPTIMIZATION_LEVEL=-Onone`.
- The package manifest parses and contains no `-Osize` setting; strict SwiftLint passes it.
- Both deployment YAML files parse and pass `-O`; the Xcode project passes plist validation.
- Runtime source and tests are unchanged. This configuration restoration uses settings previously
  built and tested; no new runtime test suite or size archive is represented as executed here.

Evidence is under `/tmp/ehpanda-drop-osize-history.json` and
`/tmp/ehpanda-261028-speed-{release,debug}-settings.json`.
The serial-runner discussion remains deferred, and the quick task and Phase 17 gates are unchanged.

## UTC+8 rewrite of the 12 unpushed commits

The owner requests UTC+8 author and committer offsets and in-place repair of GSD commit
references. All 12 unpushed commits are rebuilt and re-signed, preserving identities, Unix
timestamps, messages, commit order and every non-planning tree. Full and abbreviated commit
links are updated in each historical GSD snapshot, including stale aliases from the earlier
optimization-commit drop. The dropped optimization commit itself has no replacement and
remains identified as a dropped experiment.

The branch still contains exactly 12 unpushed commits; this record is folded into the existing
final documentation commit. The upstream base and remote refs are unchanged. Verification
checks all parent links, signatures, identities, timestamp instants, +0800 offsets, non-planning
trees and reference substitutions. No obsolete retained-commit SHA remains in the rewritten
GSD snapshots. No build, runtime test or remote push is part of this metadata/documentation work.

Recovery is available through `refs/backup/quick-261028-before-utc8`; the mapping and audit
are under `/tmp/ehpanda-261028-utc8/`. Quick-task and Phase 17 gates remain unchanged.
