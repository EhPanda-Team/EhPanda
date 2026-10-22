# Search section order and empty placeholders — D121–D123

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Date: 2026-10-22

Implementation: `7dea2ee67a3515e2a6abdf0ebd697c5b8200682e`.
Status: D127 complete; review iPad updated.

Current follow-up: [consistent spacing around Recently Seen](EQUAL-SECTION-SPACING.md).
D124–D126 remain documented in [section spacing and history actions](SEARCH-ACTIONS.md).

**Current follow-up — D123:** retain D122's 96-point minimum empty-content height, but align
placeholder text to the top leading edge. The D121/D122 screenshots below are historical;
D123 supersedes D122's vertical-centering choice.

## Owner direction

Show Recently Searched, Recently Seen and Quick Search in that order. Keep all three sections
visible when empty, with a short secondary-style text placeholder under each heading.
This refines D120's retain-current decision; it does not adopt either earlier Search A/B proposal.

## Implementation

- Compose the existing sections unconditionally in the requested order.
- Each existing section chooses between its normal content and a localized Text placeholder.
- Use native `.secondary`, subheadline text and leading alignment at the existing horizontal
  margin. The short message occupies one line at ordinary sizes and can wrap at larger text sizes.
- Keep Quick Search's Show All action available even when empty, preserving access to its editor.
- Add all three messages to the module catalog in English, German, Japanese, Korean, Simplified
  Chinese and Traditional Chinese, with translator comments.
- Preserve native titles/search, top scroll-edge policy, data fetching and populated content.

Apply SwiftUI specialist guidance for section boundaries and deferred module-local resources.
The sim-use preflight found version 0.14.0 below the skill's required 0.15.0, so no device
operation used sim-use. The available agent-device skill provided the isolated visual check.
This is a small presentation change; no new implementation-mirroring tests or model changes are
required.

## Verification and delivery

Pinned SwiftLint passes on SearchRootView. The first shell lookup had no global SwiftLint binary;
validation then used the repository's resolved macOS artifact without modifying tool versions.
The first build/device-start approval attempts timed out during workspace routing and did not
execute. The same actions were resubmitted through approval; the interrupted attempts and final
successful build are retained separately.

The generic Simulator SDK build succeeds with zero compiler/analyzer warnings and errors.
Catalog validation confirms exactly three new keys, all six locales populated, and existing keys
unchanged. The recovered review iPad is updated in place and launched without fixture flags.
Agent-device confirms the three empty headings/messages in the requested order and opens the
Quick Search editor through Show All. The native screenshot (image removed from repository history) confirms
leading alignment and single-line secondary placeholders at the standard text size. The dedicated
test device was shut down and deleted; the review device remains open. Evidence is
under `.build/library/search-section-placeholders/` and `.build/library/search-section-device/`.
The original review iPad's data and preferences are preserved. Phase 17 owner gates are unchanged.


## Native tooling interruption

The first device-specific build stalled while Xcode could not discover any simulator destinations;
it eventually reported the review device unavailable. Simulator creation also stalled. Only this
task's known processes received termination requests; no shared services or other devices were
reset. A bounded generic Simulator build succeeded. A subsequent bounded inventory succeeded and
recovered the created task device's UUID, then the review iPad install/launch and isolated boot
completed normally. Failed/aborted attempt logs remain in the evidence directory; none is claimed
as a successful test. This presentation-only change adds no automated tests.


Coverage is bounded to the clean generic Simulator build, pinned lint, complete catalog validation
and this native empty-state/manual action check. No new automated suite, full accessibility matrix
or fresh iPhone/Duo visual pass is claimed. The populated section branches are retained unchanged.


## Empty section height — D122

The owner requests more height even for empty sections. Add `minHeight: 96` only to the three
empty-text frames. Each section's heading remains outside that content area; `.leading` keeps
the text horizontally aligned with the heading and vertically centered in the reserved space.
A minimum, rather than fixed height, lets long translations or larger text grow naturally.
Populated section geometry and D121's order, copy, native styling and actions remain unchanged.

Implementation: `b19295afa2a69925a7ac0de7e73f0008d7681840`. Pinned strict SwiftLint and whitespace validation pass.
The generic Simulator SDK build succeeds with zero compiler/analyzer warnings or errors.
The new native screenshot (image removed from repository history) confirms all three empty sections retain
more height with leading, vertically centered secondary text at the standard iPad text size.
The earlier screenshot above remains the before-spacing record.

Agent-device session startup timed out, and the attempted follow-up screenshot found no active
session. The final image was captured directly through Simulator's native screenshot command;
no successful automation interaction run is claimed for D122. D121's prior Show All check remains
historical evidence. No new automated suite, accessibility matrix or iPhone/Duo visual pass is
claimed for this three-line presentation change. Evidence is under
`.build/library/search-empty-height/` and `.build/library/search-empty-height-device/`.
The first review-iPad install and isolated-device shutdown timed out. A bounded inventory then
confirmed both devices available, and one sequential retry succeeded: the review iPad was updated
in place and launched normally (PID 46211), without fixture flags or data/settings changes. The
task-created test iPad was shut down and deleted. Initial attempts and successful retry results
are retained separately; no shared Simulator service or other session's device was reset.
Phase 17 owner gates remain unchanged.


## Top-aligned empty text — D123

The owner requests that empty-section text not be vertically centered. Change only the three
empty-text frame alignments from `.leading` to `.topLeading`, preserving their 96-point minimum
height and existing heading-to-content spacing. Copy, styling, horizontal margins and populated
content remain unchanged. This uses the existing native SwiftUI frame modifier, following the
SwiftUI specialist guidance without adding view wrappers or branches.

Implementation: `35957ec4ebd19fba24800dee725fdbc8514a443a`. Pinned strict SwiftLint and whitespace validation pass.
The generic Simulator SDK build succeeds with zero compiler/analyzer warnings or errors. The
review iPad is updated in place and launched normally (PID 58304), without fixture flags or
data/settings changes. No new automated suite was run for this alignment-only adjustment.
At the owner's follow-up request, the updated native iPad screenshot (image removed from repository history)
confirms top-leading placeholders and the retained section height. D122 images remain historical.
The capture uses the same final-source build on an isolated fresh iPad, entering Search with
network stubbing so all three sections are empty; review-device data is untouched. The first
capture caught SpringBoard during initial setup and is not app evidence. After a settled relaunch,
the final light-appearance capture was visually inspected. Evidence is under
`.build/library/search-empty-top-alignment/`. Phase 17 owner gates are unchanged.

The task-created capture iPad was shut down and deleted after the final screenshot was retained.


## Populated Search review — 2026-10-22

The owner requests a view with data in all three sections. The
populated native iPad screenshot (image removed from repository history) uses 14 recent search terms,
10 recent galleries and 12 saved Quick Search entries. Gallery covers reuse the neutral
`EhPandaUITests/Fixtures/LibraryCover.png` fixture; titles and search terms are synthetic.
The screenshot shows the existing two-column keyword lists and horizontal history-gallery row.
This is review evidence, not a new layout decision or a change to the user's stored history.

A temporary DEBUG-only [state-seeding patch](populated-preview-seed.patch) supplied data before
rendering on an isolated iPad. No production view or layout was changed. The preview used the
existing offline network/image fixture path and only ran on the task-created device. The initial
fixture lint attempt found a single-line trailing-closure violation; it was corrected, and strict
lint plus the preview build passed. Source was restored byte-for-byte immediately after copying
the preview app, and a normal restoration build also passed. Both builds have zero compiler or
analyzer warnings and errors. The original review iPad was not changed. The dedicated preview
iPad was shut down and deleted after the screenshot was inspected and retained.

Base source: `35957ec4ebd19fba24800dee725fdbc8514a443a` (documentation HEAD at capture preparation:
`1a76125fb0fd5f6051d3de55efc1b139cc44f752`). Commands, lint/build results, the original and seeded
source hashes, capture parameters and cleanup evidence are in `.build/library/search-populated-review/`.
No new automated suite, behavior verification or Phase 17 gate change is claimed.


## Search spacing and history actions — D124–D126

`15c4e9ead3ad10da71974bf7a93f87aa2fc976b4` adds 24-point section spacing, equal 44-point minimum keyword-control
heights and native header Remove All actions. Confirmations anchor to their triggers. Sixteen
Search tests, clean native builds, catalog/lint checks and isolated iPad actions pass. The review
iPad is updated normally and its data is preserved.
[Behavior, confirmed history policy, screenshots and precise verification](SEARCH-ACTIONS.md).


## Consistent section spacing — D127

`105950892dbe7b28e4b2e80ce85a447378f9f5a9` removes nested keyword vertical padding and the invisible last
separator footprint. Native iPad measurements confirm 24-point gaps on both sides of Recently
Seen, with 8-point heading/content gaps. Clean build/lint; review iPad updated normally.
[Cause, screenshot, measurements and verification limits](EQUAL-SECTION-SPACING.md).
