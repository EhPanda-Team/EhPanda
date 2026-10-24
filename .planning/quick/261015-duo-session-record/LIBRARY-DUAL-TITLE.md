# Native Library large title plus source menu — D136 follow-up

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

The owner asks whether the smaller source title/menu can coexist with a large Library title and
explicitly rejects custom tab bars. The answer is yes for a native navigation bar containing a
separate native Menu. This is a layout feasibility result, not implementation approval.

## Measured alternatives

A standalone SwiftUI probe compiled against Xcode 27.1 and ran on a task-owned iPhone 17 / iOS 27.0
simulator. It uses a neutral list and a representative trailing Grid action, not the complete app.

| Alternative | Composition | Observed result / tradeoff |
|---|---|---|
| A: stacked title and source menu | `.navigationTitle("Library")`, `.toolbarTitleDisplayMode(.large)`, a native Menu in a `.principal` ToolbarItem | The Favorites menu appears in the toolbar above a separate large Library title. This uses the traditional large-title mode, so the large heading can collapse with scrolling. It changes the current `.inlineLarge` root-title mode and needs owner selection. |
| B: same row | `.navigationTitle("Library")`, `.toolbarTitleDisplayMode(.inlineLarge)`, a native Menu in `.topBarTrailing` | The large Library title and smaller Favorites menu appear on one row. It retains the current title mode but consumes trailing toolbar width; the real app's other actions and Duo placement require testing. |

The small source menu in these alternatives is a SwiftUI `Menu` with a Picker, placed in the
system navigation toolbar. It is distinct from `toolbarTitleMenu`, which attaches its actions
to the navigation title itself. The native tab bar remains unchanged in either alternative.

### A — stacked

Historical screenshot: Native stacked Library title and source menu (image removed from repository history)

### B — same row

Historical screenshot: Native inline-large Library title and trailing source menu (image removed from repository history)

## API distinction and verification boundary

Apple documents separate [title](https://developer.apple.com/documentation/swiftui/toolbaritemplacement/title)
and [largeTitle](https://developer.apple.com/documentation/swiftui/toolbaritemplacement/largetitle)
placements for the inline and out-of-line title states. Their existence alone does not mean two
automatic navigation titles are simultaneously rendered. A direct title-menu plus large-title
replacement probe did not expose both requested elements; alternatives A/B instead use a distinct
native Menu toolbar item.

The [.large title mode](https://developer.apple.com/documentation/swiftui/toolbartitledisplaymode/large)
places the heading below the navigation toolbar and transitions as content scrolls. The
[.inlineLarge mode](https://developer.apple.com/documentation/swiftui/toolbartitledisplaymode/inlinelarge)
places a large title inside the toolbar and can overflow leading/centered items; B therefore uses
a trailing item, not a centered one.

Local probe source/screenshots are retained in `/tmp/ehpanda-dual-title-probe/`. Compilation and
native cold-entry rendering were checked. Full app integration, menu interactions in this new
composition, scrolling, Dynamic Type, search focus, rotation, and Duo/iPad layouts were not tested
in this probe. The earlier app title-menu switching test belongs to the earlier `.inline` prototype,
not these layouts. No production source, navigation title, tab bar or review-device app was changed.
The task-owned simulator was removed after capture. The owner has not selected A or B.
