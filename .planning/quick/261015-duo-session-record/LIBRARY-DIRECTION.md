---
type: product-design-discussion
recorded: 2026-10-15
status: direction-under-discussion
---

# Library: app-wide information architecture

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

## Owner's stated direction

This discussion now concerns the app's overall design, beyond iPhone Duo or wide-screen adaptation.
The owner proposes merging Favorites and Downloads into one Library tab: both emphasize management
slightly more than browsing, and their similar purpose makes them a better fit together. The owner
also identifies the earlier B alternatives as more management-oriented.

Treat this as the basis for the next design discussion. It does not select every detail of the old
B prototypes, authorize a production implementation, or resolve the internal Library hierarchy.
The prior nine screenshots remain useful comparison material; none depicts a merged Library.

## Per-list display modes: owner clarification

Replace the global fixed detail/thumbnail display setting with a row/grid switch belonging to each
list. Independently remember Frontpage, Popular, Toplists, Favorites, Search and Downloads. Library
combines the top-level entry without collapsing Favorites and Downloads into one display preference.

The owner explicitly clarified that this is a layout change. Grid means the proposal's regular,
aligned gallery grid, replacing the existing masonry/waterfall effect. It is not the old thumbnail
layout under a new label. Row is the alternative list presentation; exact cell content/metrics and
image-fit behavior will be designed alongside Library.

The named six list types define the currently requested preference scopes. Defaults and migration
from the old setting, any separate preference per favorites category/download folder/toplist period,
and treatment of other lists such as Watched/History remain open. No decision about Home's small
preview sections is inferred from the full-list request.

The assistant recommends a consistently placed switch in each list's toolbar, persistence across
app launches, and adapting grid column count to available width without changing the user's chosen
row/grid mode. Switching presentation should preserve query, sorting, selection and the visible
gallery anchor. These interaction details are recommendations, not additional owner decisions.

## Design implications proposed by the assistant

- Give Library a shared category/folder navigation structure. Favorites categories and download
  folders can be destinations in that structure, with the selected destination's galleries in the
  main content area. This is a proposal, not an owner-selected final hierarchy.
- Keep organizing and accessing galleries central. Gallery details and download status can open on
  demand instead of permanently consuming the main content column. Exact inspector/sheet behavior
  remains to be designed.
- Preserve the same destination hierarchy on narrow and wide windows: navigation can be sequential
  when narrow and show categories beside content when enough space is available. Use local available
  space, preserve selection/path/query on resize, and apply Duo-specific fold/bar handling only where
  relevant. This is an app-wide design, including ordinary iPhones and resizable iPad windows.
- Distinguish removing a favorite from deleting a local download. A shared tab does not make those
  operations equivalent, or imply that one should cause the other.

## Main unresolved product choice

Does Library share one navigation entry while keeping Favorites and Downloads as distinct sections,
or combine gallery identities into a unified collection where favorite/download status are filters
or attributes? Both can support management. The first preserves explicit collection boundaries;
the second needs rules for duplicate galleries, completeness of the collection and search scope.
The owner has not selected either interpretation.

The assistant's starting recommendation is shared category navigation with distinct Favorites and
Downloads groups. This recommendation is not approval and does not rule out a unified collection.

## Existing code and constraints

- `AppPackage/Sources/FavoritesFeature/FavoritesView.swift`: signed-in favorites, category selection,
  sorting, search, gallery navigation and download badges already exist.
- `AppPackage/Sources/DownloadsFeature/DownloadsView.swift`: folder filtering, search, reading,
  folder management and a separately presented download inspector already exist.
- `AppPackage/Sources/AppModels/Persistent/Setting.swift` currently stores one `listDisplayMode`;
  `GalleryListComponents/GalleryList.swift` reads it directly, and
  `SettingFeature/AppearanceSetting/AppearanceSettingView.swift` exposes the picker. Analytics also
  reads that global value, so implementation must handle its retirement consistently.
- Downloads currently uses its own row List, so its grid mode is new rendering work rather than
  simply wiring the existing gallery-list toggle. Preserve download progress and management access.
- Download completeness continues to derive from the persisted manifest. A Library redesign does
  not establish a second status authority or change the user-owned-folder deletion invariant.
- Resizability guidance: `$HOME/.agents/skills/app-resizability/SKILL.md` and
  `$HOME/.agents/skills/iphone-duo/SKILL.md`. Discussion separates stated decisions from open choices;
  no roadmap phase, approved plan or completed GSD phase discussion is claimed.

## Relationship to previous proposal

Favorites and Downloads A/B are now inputs to this combined Library discussion, rather than two
independent tab-layout selections. Search remains a separate unresolved design discussion.
The existing [proposal](proposal/PROPOSAL.md) and preview remain available and unchanged visually.
This turn changes documentation only; no production Swift, prototype or screenshot was changed.
