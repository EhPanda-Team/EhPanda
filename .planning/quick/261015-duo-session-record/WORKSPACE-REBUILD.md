---
type: workspace-rebuild
recorded: 2026-10-15
status: complete
---

# Rebuild from the latest Phase 17 branch

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Owner decision D62 authorizes rebuilding the worktree/branch, switching this session's work to the
new workspace, then removing the previous worktree/branch. No push or update to the source branch
is part of this rebuild.

- Source branch: `feature/gsd-phase-17`.
- Source commit: `e6efecb69f2430365061e81b1eb4547a04aa555f`.
- Active branch: `agent/app-design`.
- Active workspace: `$HOME/.codex/worktrees/app-design/EhPanda`.
- Previous branch: `agent/iphone-duo-support`.
- Previous workspace: `$HOME/.codex/worktrees/iphone-duo-support/EhPanda`.
- Carried design commit: `3c3a12ad36` (previously `3c3a12ad36`).

## Preservation and validation

The source branch has rewritten history and corrected GSD SHA references. Its production source,
tests and scripts already contain the Duo implementation. Only the additional Library/row-grid
design record was cherry-picked, without conflicts. A tree comparison confirms no production-source,
test, script or project changes relative to the new source base; its snapshot research and ignore
rules are retained. No build or runtime test was rerun for this documentation/workspace operation.

The old worktree was clean. Its `.build/integration` evidence (about 41 MB), build logs and xctestrun
manifests were copied to `$HOME/Fork/EhPanda/.build/duo-session-20261014-15/phase17-integration-20261015/`
and then to the same relative `.build` locations in the new workspace. A checksum-based dry run
found no changed or missing integration evidence. Rebuildable products, dependency and index caches
were not copied. Retained test results remain evidence from their original source/run, not newly
executed tests on this rebuilt branch.

The new workspace's existing local-package dependency resolves through the sibling `appshot-cli`
symlink. The original dependency checkout is unchanged. The Codex-managed worktree attachment
identifies the new workspace for this chat; subsequent file and Git operations use that directory.

The proposal preview remains at `http://127.0.0.1:55920/index.html`. Its document root is the stable
archive outside both managed worktrees, so removing the old workspace does not remove the preview.

## Cleanup

The old managed worktree was archived through Codex, retaining a recoverable Git snapshot, and its
checkout was removed. The `agent/iphone-duo-support` branch was then deleted after confirming the
Library design document survived intact. The obsolete sibling dependency symlink was removed if
still present; the dependency checkout itself was not changed. Only `app-design` remains an active
worktree attachment for this chat; the previous one is a recoverable archive.

Final checks confirmed the old worktree is absent from disk and Git's worktree list, the old branch
is absent, and the source `feature/gsd-phase-17` remains unchanged and clean at `e6efecb69f`. The
preview index and all nine screenshots return HTTP 200. No remote operation was performed.
