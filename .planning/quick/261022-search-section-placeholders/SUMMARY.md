# Search section order and empty placeholders — D121

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Date: 2026-10-22

Implementation: `7dea2ee67a3515e2a6abdf0ebd697c5b8200682e`.
Status: complete.

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
