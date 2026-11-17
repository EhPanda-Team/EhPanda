---
quick_id: 261117-tyj
date: "2026-11-17"
source: owner answers, 2026-11-17
---

# Quick task 261117-tyj: owner decisions (locked)

Scope: the two reported bugs in `.planning/notes/2026-11-16-reported-download-library-issues.md`
(item 2, Library picker; item 3, download card). The owner authorized investigating and fixing
these two. Item 1 of that note (download queue operations) and
`.planning/notes/2026-11-17-save-keyword-as-saved-search.md` stay deferred and untouched.

## Bug A: the Library picker does not remember the last selection

### Orchestrator investigation (verified in source)

- `LibraryFeature.State.selection` (`AppPackage/Sources/AppFeature/View/Library/LibraryFeature.swift`)
  is plain in-memory state, initialized to `nil` by `AppReducer.State` (`libraryState`).
- Within one process the selection is kept. On every launch it starts at `nil`, and on a
  compact (non-sidebar) layout `.library(.showInitialFavorites)` in
  `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift` sets `.favorites(favoritesIndex)` with
  `favoritesIndex` defaulting to `-1`. Neither `FavoritesReducer.State.favoritesIndex` nor
  `DownloadsReducer.State.folderFilter` is persisted. So after the system terminates the app, or
  on any relaunch, the Library always opens on Favorites (all).
- Root cause: the selection has no persisted record.

### Decision A-1 (owner): remember the full selection across launches

- Persist the full `LibraryGroup`: the source (Favorites or Downloads) together with the
  favorites category index or the download folder filter.
- On launch, restore it, on the compact title-menu layout and on the iPad / Duo sidebar layout
  alike.
- A persisted download folder that no longer exists falls back to "All" (the existing
  `DownloadsReducer` fallback to `.all` when the folder is missing is the expected route).
- Follow the persistence conventions in `AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift`
  (`@Shared` with `appStorage`, strict decode falling back to the default, `SchemaVersion`
  conventions where they apply).

### Decision A-2 (owner, answering the planner's OQ-3): remember the picker only, not the sidebar

- Only the selection made on the compact layout, where the Library shows its title-menu picker
  (`usesSidebar == false`), is remembered across launches. That includes the favorites category
  or the download folder chosen there, per A-1.
- A selection made in the sidebar layout (iPad, and iPhone Duo when it shows panes) is not
  remembered and does not overwrite the remembered picker choice. Sidebar launches keep today's
  behavior: no restored selection.
- When the compact layout has no selection (cold launch, or switching from the sidebar with
  nothing selected), it opens the remembered picker choice instead of Favorites, and Favorites at
  the current index only when nothing is remembered.
- In-process carry-over between layouts (a resize or a fold) stays as today.

## Bug B: wrong galleries count on the download card

### Orchestrator investigation (verified in source)

- The "download card" is the system continued-processing card. Its subtitle reads
  "X / Y pages · N galleries".
- N is `coverageGalleryCount(for:)` in
  `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift`: live schedulable
  galleries plus every `retiredSessionPages` entry greater than zero (D-G2C-01, plan 15-55).
- `reconcileRetiredSessionPages` retires a departed gallery's finished pages into both X and Y
  regardless of why it departed (D-G2-01: completion, pause, delete, cancel and expiration are
  treated alike). A deleted gallery that had finished pages in the session therefore stays in X,
  in Y and in N for the rest of the session. That is what the owner saw: adding downloads raises
  N, but deleted galleries are still counted.
- The count is recomputed on every push, not tracked as +1/-1 deltas. The owner's impression of
  delta tracking is explained by the ledger keeping deleted galleries.

### Decision B-1 (owner): a deleted gallery leaves the session entirely

- When the user deletes a gallery (`DownloadCoordinator.delete(gid:)`,
  `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift`), its pages leave both X and
  Y and it no longer counts toward N, whatever its state was (active, queued, paused, or
  completed earlier in this session).
- The owner accepts that the progress bar may step back once at the deletion, so X, Y and N stay
  consistent. The numerator's monotonic floor (`lastPushedCompletedPageCount`) must give back the
  deleted gallery's counted portion so later real work is not absorbed. That is the same
  principle as D-G7-01, which today explicitly excludes deletions because they used to be valued
  as departures.
- Unchanged: paused galleries, completed galleries, the queued-work-item cancel and the
  expiration pause-all keep the D-G2-01 retirement and stay counted under D-G2C-01. Only a user
  deletion changes.
- Decision B-2 (owner, answering the planner's OQ-1): deleting a whole download folder
  (`deleteFolder(name:)`) is a user deletion too, so each gallery it removes leaves the session the
  same way.
- Decision B-3 (owner, answering the planner's OQ-2): the refactor that moves the session-start
  seed ahead of the client start's hop is approved, so a deletion during the start window also
  leaves the session.
- D-G2-01, D-G2C-01 and D-G7-01 doc contracts must be rewritten where this decision changes them
  (not annotated), following the project rule to document deliberate designs.
