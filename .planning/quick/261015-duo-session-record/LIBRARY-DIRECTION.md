---
type: product-design-discussion
recorded: 2026-10-15
status: implemented
---

# Library: app-wide information architecture

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

## Owner's stated direction

This discussion now concerns the app's overall design, beyond iPhone Duo or wide-screen adaptation.
The owner chose to merge Favorites and Downloads into one Library tab: both emphasize management
slightly more than browsing, and their similar purpose makes them a better fit together. The owner
also identifies the earlier B alternatives as more management-oriented.

The owner invoked `$gsd-quick` on 2026-10-15 to plan and implement this direction, then selected
shared category navigation with separate Favorites and Downloads groups. This authorizes the
combined Library and per-list row/grid implementation, without selecting every old B detail.
The prior nine screenshots remain comparison material; none depicts a merged Library.

## Per-list display modes: owner clarification

Replace the global fixed detail/thumbnail display setting with a row/grid switch belonging to each
list. Independently remember Frontpage, Popular, Toplists, Favorites, Search and Downloads. Library
combines the top-level entry without collapsing Favorites and Downloads into one display preference.

The owner explicitly clarified that this is a layout change. Grid means the proposal's regular,
aligned gallery grid, replacing the existing masonry/waterfall effect. It is not the old thumbnail
layout under a new label. Row is the alternative list presentation. The implemented grid uses aligned adaptive columns and
aspect-fit 2:3 cover slots; text remains scalable without a fixed text height (engineering E05).

The six named lists define the owner-requested scopes. Engineering E02–E03 additionally give Watched
and History independent scopes; DetailSearch shares Search. Category, folder and toplist period
changes retain their list scope. Fresh installs and Downloads default to row; legacy detail maps to
row and thumbnail maps to grid once. Home preview sections remain outside this change.

The implementation uses a consistently placed switch in each list's toolbar, persistence across
app launches, and adapting grid column count to available width without changing the user's chosen
row/grid mode. Switching presentation should preserve query, sorting, selection and the visible
gallery anchor. These interaction details were implemented under D63 and recorded as engineering E04–E06,
not additional owner answers.

## Design implications and selected implementation

- Give Library a shared category/folder navigation structure. Favorites categories and download
  folders can be destinations in that structure, with the selected destination's galleries in the
  main content area. D64 selected this common navigation hierarchy with separate groups.
- Keep organizing and accessing galleries central. Gallery details and download status can open on
  demand instead of permanently consuming the main content column. The implementation retains existing on-demand detail routing and the download-status sheet.
- Preserve the same destination hierarchy on narrow and wide windows: navigation can be sequential
  when narrow and show categories beside content when enough space is available. Use local available
  space, preserve selection/path/query on resize, and apply Duo-specific fold/bar handling only where
  relevant. This is an app-wide design, including ordinary iPhones and resizable iPad windows.
- Distinguish removing a favorite from deleting a local download. A shared tab does not make those
  operations equivalent, or imply that one should cause the other.

## Selected Library structure

On 2026-10-15 the owner selected shared category navigation with separate Favorites and Downloads
groups. Categories and folders share the Library entry; gallery identities and management actions
remain within their existing group. A unified collection with cross-source deduplication is not the
selected design. Implementation is tracked by quick task `261015-tx1`.

## Pre-implementation baseline and continuing constraints

- `AppPackage/Sources/FavoritesFeature/FavoritesView.swift`: signed-in favorites, category selection,
  sorting, search, gallery navigation and download badges already exist.
- `AppPackage/Sources/DownloadsFeature/DownloadsView.swift`: folder filtering, search, reading,
  folder management and a separately presented download inspector already exist.
- `AppPackage/Sources/AppModels/Persistent/Setting.swift` previously stored one `listDisplayMode`;
  `GalleryListComponents/GalleryList.swift` previously read it directly, and
  `SettingFeature/AppearanceSetting/AppearanceSettingView.swift` exposed the picker. The global setting, Appearance picker and analytics dimension are now retired
  together in favor of persisted per-list modes.
- Downloads previously used only its row List. The new grid shares the same per-gallery actions,
  confirmations, manifest-derived status and local cover source.
- Download completeness continues to derive from the persisted manifest. A Library redesign does
  not establish a second status authority or change the user-owned-folder deletion invariant.
- Resizability guidance: `$HOME/.agents/skills/app-resizability/SKILL.md` and
  `$HOME/.agents/skills/iphone-duo/SKILL.md`. Discussion separates stated decisions from open choices;
  no roadmap phase, approved plan or completed GSD phase discussion is claimed.

## Relationship to previous proposal

Favorites and Downloads A/B are now inputs to this combined Library discussion, rather than two
independent tab-layout selections. Search remains a separate unresolved design discussion.
The existing [proposal](proposal/PROPOSAL.md) and preview remain available and unchanged visually.
The earlier discussion changed documentation only. Quick task `261015-tx1` now owns implementation
and current validation; historical prototype screenshots are not implementation evidence.

## Implementation record

Quick task [261015-tx1](../261015-tx1-implement-library-with-shared-favorites-/261015-tx1-PLAN.md)
owns the approved plan, [engineering decisions](../261015-tx1-implement-library-with-shared-favorites-/IMPLEMENTATION-DECISIONS.md)
and [current validation](../261015-tx1-implement-library-with-shared-favorites-/VALIDATION.md).
