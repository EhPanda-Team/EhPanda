# Bottom-edge and safe-area-bar review

Status: the owner selected B1–B6 on 2026-10-28. [UI-IMPLEMENTATION.md](UI-IMPLEMENTATION.md) records
integration and the subsequent request to restore the persistent Library title menu. That menu
supersedes B1's compact bottom picker; Library retains the placement-aware bottom-edge policy.
The [18 native before/after pairs](SCREENSHOTS.md) and [prototype patch](UI-PROPOSAL.patch) preserve
the earlier review. The textual inventory below describes that original proposal, not the later menu.
The existing top-edge inventory remains authoritative. This list adds selective bottom treatment;
it does not replace top-edge coverage or claim the complete acceptance matrix passed.

## Before / after choices

Paths are relative to `AppPackage/Sources/`.

| ID | Page / context | Before | Proposed after | Recommendation |
|---|---|---|---|---|
| B1 | Compact Library: Favorites, Downloads and empty selection (`AppFeature/View/Library/LibraryView.swift`) | Source picker uses bottom `safeAreaInset`, trailing alignment, spacing 12, horizontal padding 16 and bottom padding 8; page hosts specify soft top only. Picker disappears on pushed destinations. | Use `safeAreaBar(edge: .bottom, alignment: .trailing, spacing: 12)` with the existing picker and padding. Apply soft bottom treatment to this control-bearing root. Preserve the existing root-only visibility. | Adopt. A persistent control bar is the direct native API use case. |
| B2 | Home (`HomeFeature/HomeNavigationView.swift`, `HomeSectionsView.swift`), including two independent Duo panes | Native tab chrome; each vertical scroll host has soft top and automatic bottom behavior. | Soft bottom effect only while native tab placement is `.bottomBar`; preserve automatic bottom behavior when tabs move to the top/side. Attach at each effective page/navigation root so nested horizontal carousels do not get unrelated side effects. | Adopt with B1. No custom bar is needed. |
| B3 | Search root and pushed results (`SearchFeature/SearchRootView.swift`, `SearchView.swift`; shared `GalleryListComponents/GalleryList.swift`) | Search suggestions/history and results have soft top; native search/tab controls own bottom layout. | Soft bottom treatment in the tab-hosted navigation hierarchy when a bottom tab bar is present. Keep native search placement, query/focus and keyboard avoidance. Do not change the shared GalleryList globally, because it also appears in sheets. | Adopt with B1. |
| B4 | Settings tab and its pushed destinations (`SettingFeature/SettingView.swift`) | Tab and sheet share the view. Soft top; root title is `.inlineLarge` in tabs and `.large` in sheets. | Soft bottom effect for the tab-hosted hierarchy only when tabs occupy the bottom. Sheet keeps its own top policy and automatic bottom behavior. | Adopt with B1. Preserve both title modes. |
| B5 | Expanded Library sidebar/detail (`AppFeature/View/Library/LibraryView.swift`; Favorites/Downloads and their pushed gallery/detail/search/comments/info/preview pages) | Sidebar category selection replaces the compact picker. Soft top at sidebar/detail/page roots; native tab placement varies with available space. | Preserve the sidebar and no custom bottom bar. Soft bottom only in a column that actually meets bottom tab chrome; automatic bottom behavior when no bottom bar is present. Compact pushed detail pages retain the tab effect, but never the root picker. | Include in B1–B4 context checks; no blanket `.vertical` replacement. |
| B6 | Archives sheet, standard text sizes (`DetailFeature/Archives/ArchivesView.swift`) | `VStack`: scrolling archive grid, then pinned funds and download action. Both footer blocks consume layout space outside the scroll host. | Optionally move the existing funds/action block into a bottom `safeAreaBar` on the grid, adding soft bottom. Preserve effective footer spacing and all action/confirmation anchors. At accessibility sizes keep the existing single scrolling column, with no pinned bar. | Optional second migration. Its sizing/spacing needs visual comparison; current layout is functional. |
| R1 | Reader (`ReadingFeature/ReadingView.swift`, `Support/ControlPanel.swift`, `Support/AdvancedList.swift`) | Full-screen image content with transient, animated lower overlay; movable half-width Duo controls and preview tray. | Retain overlay and top policy. A safe-area bar would reserve content height and change paging, image fitting and split-pane behavior. | Retain. Requires a separate reader design decision. |
| R2 | Toast (`SystemNotification/View+Toast.swift`) | Transient bottom overlay; no reserved layout height. | Retain overlay. Moving notices into a bar would shift the underlying page whenever a toast appears. | Retain. |
| R3 | Previews, gallery detail, comments, information, detail-search and home gallery lists when separately presented (`DetailFeature/GallerySheetView.swift`, `HomeFeature/HomeSheetView.swift` and child pages) | Soft top; toolbar actions are above content, no persistent custom bottom control bar. | Retain automatic bottom effect in those presentations. The same pages pushed inside a tab inherit only the actual tab-hosted treatment described above. | Retain separate-presentation behavior. |
| R4 | Archives at AX sizes; folder manager, torrents, tag detail, comment editor, date seek, filters, quick search/editor, reader settings, login/web login/challenge, New Dawn, error details and log-run picker | Separate forms/lists/scroll views/text editor; existing explicit soft top. Actions are toolbar, inline or deliberately scrolling. | Retain existing placement. No persistent custom bottom bar was found on these surfaces. | Retain. |
| R5 | System share/file-import UI and Share extension handoff | System-owned scrolling; extension has no content page. | Keep system interiors untouched; retain explicit app presentation-root top policy. | Retain. |

Recommended selection: **B1–B5**. B6 is a separately reviewable addition. R1–R5 remain unchanged.
No confirmation-dialog anchor moves are necessary for B1–B5.

## API and placement evidence

The installed iOS 27.1 SDK declares vertical `safeAreaBar` with horizontal alignment and optional
spacing. It also declares `TabBarPlacement.bottomBar`, `.topBar` and `.sidebar`. The project targets
iOS 27, so no older-system fallback is needed. Candidate syntax:

```swift
.safeAreaBar(edge: .bottom, alignment: .trailing, spacing: 12) {
    // Existing root-only Library picker, including its existing padding.
}
```

For tab surfaces, read the native placement at a view below the TabView. An environment value read
above the TabView cannot establish its child's actual placement. Resolve the placement at each
existing effective page root; avoid introducing a wrapper whose only job is renaming a modifier.
Use the bottom modifier separately from the required top modifier. A sheet is a new presentation
boundary and must be assessed independently. Native vertical toolbar adaptation remains intact.

Apple describes the native bar API in
[safeAreaBar](https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:)).
The installed SDK and SwiftUI skill guidance corroborate the proposed use of bars for controls.

## Acceptance matrix after selection

| Dimension | Checks |
|---|---|
| iPhone / iPad | Compact and expanded Library; bottom and top/side native tabs; portrait/landscape and resizable windows. |
| Dynamic Type | Standard, AX1, AX3 and AX5, on cold entry and during live size changes. Preserve root titles and native searchable behavior. |
| Scrolling | Top, middle and bottom; final row reachable; row/grid parity; loaded, empty, login-required and loading states. |
| Navigation | Picker visible only at Library root, absent after push; no reservation when hidden; sidebar/detail and sheet presentations unaffected. |
| Search / keyboard | Focus, query preservation, keyboard appearance/dismissal, rotation and live resizing. |
| Actions | Picker remains trailing and tappable; row dialogs stay on their triggering controls; focus/VoiceOver order remains meaningful. |
| Optional B6 | Compare standard footer clearance and spacing; AX1/AX3/AX5 still scroll funds and action together with the grid. |
| Duo | Tab migration to vertical chrome; open/half-fold pane boundaries; no new bottom haze where no bar exists. |

These are required verification cases. The bounded screenshot results and remaining coverage are
recorded in [SCREENSHOTS.md](SCREENSHOTS.md); the complete matrix is not yet verified.
