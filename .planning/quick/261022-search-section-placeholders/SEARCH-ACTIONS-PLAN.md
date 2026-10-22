# Search spacing and history actions — D124–D126

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Owner request: separate Recently Seen from Quick Search visibly, equalize Quick Search / Recently
Searched row height, and add Remove All beside both history headings in the Show All position.

## Implementation plan

1. Set the Search section stack spacing to 24 points and give the shared keyword search control
   the same 44-point minimum height as the per-keyword removal control. Preserve text growth,
   leading alignment, existing column adaptation and the 96-point empty-content floor.
2. Use native Section / sectionActions for Search's headings and actions, rendered via
   ForEach(sections:) and SectionConfiguration.actions. Keep current title typography and the
   accessibility-size stacked heading arrangement. Retain Quick Search Show All.
3. Add persistent Remove All handling for search history and browsing history with confirmation
   dialogs anchored to the triggering header control. Disable rather than remove empty actions.
   Reuse History's existing clear-records-and-resume-positions behavior and state both in the
   confirmation. An optional question about preserving progress remains unanswered; this is a
   disclosed implementation assumption, not an explicit new owner selection.
4. Verify persisted clearing, cancellation and protection against stale gallery fetch results;
   verify row-height parity, section gaps, action placement and dialog anchors on the dedicated
   iPad. Preserve the normal review iPad's data. Run focused reducer/UI checks and pinned lint,
   capture the populated and emptied layouts, record actual implementation SHAs and update GSD.

## API evidence

Xcode 27.1 exposes SectionConfiguration.actions and native sectionActions. Apple's documentation
shows custom section containers placing these actions alongside section.header:
[SectionConfiguration](https://developer.apple.com/documentation/swiftui/sectionconfiguration),
[actions](https://developer.apple.com/documentation/swiftui/sectionconfiguration/actions-swift.property).
Use these APIs rather than expanding the app-wide SubSection component for this screen.

No Phase 17 owner gate or unrelated Home/Library layout changes are part of this follow-up.

Completed: [implementation, verification and delivery](SEARCH-ACTIONS.md).
