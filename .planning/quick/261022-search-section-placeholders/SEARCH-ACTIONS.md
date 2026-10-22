# Search spacing and history actions — D124–D126

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Implementation: `15c4e9ead3ad10da71974bf7a93f87aa2fc976b4`. Date: 2026-10-22.
Status: implemented and delivered to the existing review iPad.

## Owner direction and behavior

- D124: separate Recently Seen and Quick Search visibly. The three-section stack now uses
  24-point spacing; the previous default stack gap left the gallery strip too close to the next heading.
- D125: give Quick Search and Recently Searched the same row height. The recent-keyword delete
  control already reserved 44 points; the common search control now has that same minimum.
  Both keep natural growth for wrapped text and larger text sizes, with existing column adaptation.
- D126: add Remove All to both history sections in the Show All header position. Native Section,
  sectionActions and SectionConfiguration.actions carry the actions through the custom section
  container. Quick Search retains Show All. Empty actions remain visible but disabled.

Each confirmation dialog belongs to its stable triggering button, preserving the native iPad arrow
anchor. Recently Searched clears only its persisted keywords. Recently Seen uses the existing
History policy: all persisted browsing records, including their saved reading positions, are removed.
Its confirmation explicitly names both. On 2026-10-23 the owner explicitly confirmed this policy:
clear all browsing history and reading positions, matching History. This resolves the previously
disclosed implementation assumption; no source change or new verification run is required.
The [verbatim confirmation](../../notes/2026-10-23-confirm-history-clear-policy.md) is retained.
No real review-device history was cleared during verification.

The reducer cancels the history metadata fetch on clear and filters queued responses against the
current persisted history. Clearing all records therefore cannot be undone by a late response.
The original 96-point empty-content floor, top-leading secondary text, native title/search behavior
and top scroll-edge policy remain. No Home, Library or Phase 17 gate changes are included.

## Verification

- Pinned strict SwiftLint and whitespace checks pass. Four module-local catalog additions have
  complete English, German, Japanese, Korean, Simplified Chinese and Traditional Chinese entries;
  all existing catalog values are unchanged.
- All 16 SearchFeatureTests pass exactly once with no failures or skips. Four new tests verify
  keyword removal preserving browsing/saved searches; clearing all 12 persisted gallery records
  even though only ten are displayed, including resume positions; no restoration by queued
  metadata; and normal metadata acceptance for current history. Reconstructed state and tab
  re-entry observe cleared persistence. Pending-fetch cancellation is implemented and reviewed;
  no separate delayed-network cancellation timing test is claimed.
- Native feature, preview and final normal builds succeed with zero compiler/analyzer warnings
  or errors. Final source hashes match those tested before temporary preview seeding.
- On the isolated iPad, native accessibility bounds measure both search controls at 44 points.
  Populated captures show the two-column keyword lists, the added section gap and header actions.
  Cancelling the browsing-history popover preserves its galleries; confirming clears them while
  keywords and saved searches remain. Clearing keywords preserves Quick Search. Both histories
  remain empty after terminating and relaunching without the seed flag; both Remove All buttons
  are disabled. Show All still opens the saved-search editor with fixture entries.

These are focused reducer tests and native agent-device interactions, not a new automated XCTest
UI suite or full accessibility matrix. No fresh iPhone/Duo visual pass is claimed. Existing title,
search-focus and Dynamic Type policies are preserved in source.

## Screenshots and provenance

- Recently Searched and header actions (image removed from repository history)
- Recently Seen / Quick Search spacing and row height (image removed from repository history)
- Native confirmation anchored to its trigger (image removed from repository history)
- Cleared histories with Quick Search retained (image removed from repository history)

The same synthetic 14 recent searches, ten galleries and 12 saved searches used in the earlier
review populate an isolated iPad. Covers use the neutral LibraryCover fixture. The retained
[data-only seed patch](actions-preview-seed.patch) supplies initial state without changing any
view or action behavior. The source is restored byte-for-byte after the preview app is copied,
then the normal app is rebuilt. The existing review iPad receives only that normal build and
launches without fixture flags, preserving its account, data and settings (PID 7278).
The task-created simulator is shut down and deleted after verification.

Evidence: `.build/library/search-actions-feature/`, `.build/library/search-actions-preview/` and
`.build/library/search-actions-final/`. Native agent-device session logs are retained locally under
`$HOME/.agent-device/sessions/ehpanda-search-actions*`. The CLI rejected an unsupported orientation
alias and a skill-documented scroll flag; documented landscape-left / scroll-bottom commands were
used successfully instead. A compact snapshot exposed the confirmation's enclosing cell rather
than its button; the raw snapshot exposed the exact button and the confirmed operation succeeded.
These tooling attempts caused no source or shared-device changes.

## Native API references

Xcode 27.1's SwiftUI interface exposes the action collection. Apple's examples describe custom
section containers rendering their supplied headers and actions:
[SectionConfiguration](https://developer.apple.com/documentation/swiftui/sectionconfiguration),
[actions](https://developer.apple.com/documentation/swiftui/sectionconfiguration/actions-swift.property).
