# Remove simplified gallery titles — D119

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Date: 2026-10-22

Implementation: `8fcf087616613319652f6e3a0c38d7094d3f30c5`.

## Owner direction and scope

The owner requests removing title simplification. This supersedes D80's default-enabled option
and D100's extension of that option to Home. Display the stored gallery title directly everywhere
that previously applied the transformation: shared row/grid cells, Home slideshow, Frontpage and
Toplists, including compact cover accessibility labels.

Retain the existing Japanese-title preference, title line budgets, truncation, card alignment,
cover sizing/content modes, rating policy and Liquid Glass tags. In particular, grid still uses
two lines; removing bracket filtering does not mean every title must be fully visible at once.
No gallery data rewrite is needed: simplification only transformed display text.

## Implementation plan

- Remove the Appearance → Gallery toggle and its six-locale string-catalog entry.
- Remove the Setting initializer option, stored optional, accessor, decoder entry and CodingKey.
  Existing version-2 settings can keep the retired JSON key until their next save: normal keyed
  decoding ignores it, and re-encoding no longer emits it. Preserve all other preferences.
- Delete the bracket-removal implementation and its obsolete algorithm tests.
- Render `gallery.title` directly; remove the title-only computed aliases and Home setting readers
  and Sharing imports that existed only for this option.
- Replace the old toggle/algorithm expectations with a saved-settings compatibility regression
  and original-title UI assertions. Keep the existing card-alignment and Home section-layout checks.

## Verification

Strict SwiftLint passes on all ten changed/new Swift files; the edited string catalog parses and
only the retired six-locale entry is removed. Production source contains no simplification API,
preference or control references. `git diff --check` passes.

Native validation uses Xcode 27.1 and a dedicated iPad Pro 11-inch simulator on iPadOS 27.0:

| Check | Result |
|---|---|
| AppModelsTests | 94 exact test identities pass, zero failures/skips. The new parameterized regression covers retired key absent, true and false, verifies all preferences survive and the key is not re-encoded. |
| Grid alignment | Pass at Large, AX1, AX3 and AX5 with original short/long titles, existing two-line limit, leading alignment and Library rating policy. |
| Row/grid and Appearance | Original titles survive both layouts and relaunch. The Appearance page opens and no simplified-title switch exists. |
| Home sections | Slideshow, Frontpage and Toplists retain bracketed original labels; existing section/alignment checks pass. |
| UI gate | Exactly three selected tests pass, zero failures/skips/repetitions. Both final gates verify source hashes unchanged and restore the task device's original Booted/large state. |
| Build for Testing | Both final model/UI builds succeed with zero compiler warnings, analyzer warnings and errors. |

Raw evidence is under `.build/library/remove-simplified-titles/`,
`.build/library/remove-simplified-titles-feature/`,
`.build/library/remove-simplified-titles-feature-02/`,
`.build/library/remove-simplified-titles-feature-03/` and `.build/library/remove-simplified-titles-ui/`.
Native screenshots remain attached to the final UI result bundle. This is focused iPad coverage;
no fresh iPhone/Duo run or full-project suite is claimed.

## Delivery

The existing review iPad was updated in place and launched normally at 12:54 UTC on 2026-10-22,
with account/data/preferences preserved and no automation fixture flags. Launch and exact source
commit are recorded in `.build/library/remove-simplified-titles/review-device-launch.json`.
Only the task-created test simulator was shut down and deleted after both successful gates;
cleanup is recorded beside the delivery evidence. The proposal preview remains available.

Historical screenshots and test results in GRID-TITLES.md and the Home records describe their
original implementations. This retirement does not retroactively invalidate or rewrite that
history, promote screenshot baselines, select a Search redesign or complete Phase 17 owner gates.

## Simulator initialization interruption

The first attempt passed Build for Testing without compiler/analyzer warnings or errors, then
stopped before test enumeration/execution because the new task-owned iPad failed to boot:
`launchd_sim` did not respond (`simctl bootstatus` exit 60). The gate restored it to Shutdown.
The next boot succeeded after the simulator completed its first-run system data migration.
Verification resumes in a fresh evidence directory with unchanged source. The failed boot logs
are retained; no application test failure was hidden or retried. Other simulators are untouched.

The second attempt also passed Build for Testing, but the simulator reported `unknown` for its
content size and changed from Booted to Shutting Down during cleanup. The native gate stopped
before test enumeration/execution, retaining that failed lifecycle restoration. A subsequent
read found the task device Booted with the valid `large` content size; a third attempt uses a
fresh evidence directory. No host-wide simulator service restart or other-device shutdown was
performed. These are infrastructure failures, not passing tests or application test failures.

The third attempt passed 94 model tests with source hashes unchanged and restored the simulator's
original Booted/large state. Its Build for Testing result records zero errors, compiler warnings
and analyzer warnings. The preceding two interrupted attempts did not reach application tests;
this is the first executed model-test pass for the removal.
