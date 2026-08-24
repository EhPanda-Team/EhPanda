# Phase 16 Round 1 — Dynamic Type sweep verdict table

**This file is the round-1 state machine.** Every sweep plan (16-04 … 16-09) appends verdicts to
it, every owner fix is re-verified against it, plan 16-10 reports from it, and the owner signs it
in plan 16-12. It is the *only* committed round-1 artifact: text rows, never images (D-32).

**How to resume:** read § Matrix top to bottom and start at the first row whose Status is
`pending` or `re-verify`. Rows are keyed by (screen #, device, orientation, size) and laid out in
sweep order — device, then group, then screen #, then orientation (portrait before landscape),
then size (XXL → AX3 → AX5) — so verdict order is stable across sessions.

Paths in this file are repository-relative; source paths under § Inventory and § D-04 checklist
are written relative to `AppPackage/Sources/`. The one non-repository path is the evidence root
in § Infrastructure, written literally in its `$HOME/…` form and never expanded.

## Infrastructure

Filled by plan **16-03** on 2026-08-24 (the owner logged in by hand; the agent never handled a
credential — D-09). Every sweep plan reads the values below and addresses the simulators by UDID.

| Key | Value | Filled by |
|---|---|---|
| `IPHONE_UDID` | `ADE09605-A44E-4F00-BE12-235970217355` — iPhone Air, iOS 26.5 | 16-03 |
| `IPAD_UDID` | `8250D97E-9AB0-42FD-99DB-07B0094BF8C7` — iPad Pro 11-inch (M5), iOS 26.5 | 16-03 |
| `BUNDLE_ID` | `app.ehpanda.personal` — see "Why `app.ehpanda.personal`" below | 16-03 |
| `IPHONE_LOGIN` | `present` — confirmed on `BUNDLE_ID` in 16-03 pre-flight (populated Favorites; nothing else read) | 16-03 |
| `IPAD_LOGIN` | `none` — `BUNDLE_ID` on `IPAD_UDID` shows the login prompt on Favorites. iPad rows of login-gated screens (Favorites, Watched, Archives, Torrents, EhSetting, FolderManager, live Detail / Comments / Reading) are recorded `blocked: no iPad session` and surfaced in plan 16-10's report. If the owner logs in on the iPad before wave 6 (plan 16-07), amend this one row to `present` in a separate docs commit and the blocked rows go back to `pending` | 16-03 |
| `SPARE_UDID` | `88B217DA-A166-4BAD-820D-DE13B1C4EB54` — iPhone 17e, iOS 26.4. **UI tests only**; never a sweep target, so the logged-in simulators are never a `xcodebuild test` destination | prefilled |
| `EVIDENCE_ROOT` | `$HOME/Library/Caches/ehpanda-phase16/` | prefilled |

Shell form, for pasting at the start of every sweep session (the same values as the table):

```bash
IPHONE_UDID=ADE09605-A44E-4F00-BE12-235970217355
IPAD_UDID=8250D97E-9AB0-42FD-99DB-07B0094BF8C7
SPARE_UDID=88B217DA-A166-4BAD-820D-DE13B1C4EB54
BUNDLE_ID=app.ehpanda.personal
IPHONE_LOGIN=present
IPAD_LOGIN=none
EVIDENCE_ROOT="$HOME/Library/Caches/ehpanda-phase16"
```

### Why `app.ehpanda.personal`

Both `app.ehpanda` and `app.ehpanda.personal` are installed on both sweep simulators, and the
iPhone happens to hold a session in both. `BUNDLE_ID` is nevertheless not a choice: the project's
`PRODUCT_BUNDLE_IDENTIFIER` is `app.ehpanda$(BUNDLE_ID_SUFFIX)`, and on this machine the
git-ignored `Config/LocalSigning.xcconfig` sets the suffix so that
`xcodebuild -showBuildSettings -scheme EhPanda` resolves `PRODUCT_BUNDLE_IDENTIFIER =
app.ehpanda.personal`. That is the only bundle the § Protocol install-over rule can ever target
here, so it is the only bundle whose sweep verdicts stay valid across owner fix commits. **Never
sweep `app.ehpanda`** on these simulators — it is not the build the project produces, and a fix
installed over `app.ehpanda.personal` would leave it stale. Before any session, make sure only
`BUNDLE_ID` is in the foreground (`xcrun simctl terminate <UDID> app.ehpanda` is safe: it ends
the process and touches no data container).

### Tooling

The owner's choice for the sweep driver is **`sim-use` 0.13.0** (on PATH; preflight passes on
both sweep UDIDs). The § Protocol listings are written in `agent-device` verbs; map them as
follows, always with an explicit `--device <UDID>`:

| § Protocol verb | `sim-use` equivalent |
|---|---|
| `agent-device snapshot` / accessibility tree | `sim-use ui --device <UDID>` (the `App:` header carries the orientation tag; no tag = portrait) |
| `agent-device open <BUNDLE_ID> --foreground` | `xcrun simctl launch <UDID> <BUNDLE_ID>` (no-op if already running), then `sim-use ui` to confirm `App: EhPanda` |
| `agent-device screenshot --out <path> --scale 0.5` | `sim-use screenshot --device <UDID> --output <path>` — writes the full-scale PNG (1260×2736 on the iPhone Air). **Evidence is stored full-scale**; no downscale step. |
| `agent-device scroll down --settle` | `sim-use gesture scroll-up --device <UDID>` (content moves up = page down); repeat until the `ui` outline stops changing |
| `agent-device orientation landscape-left` / `portrait` | **Keep `agent-device orientation …` — `sim-use gesture rotate-cw` does NOT rotate the device.** Corrected by plan 16-04: `gesture rotate-cw` dispatches a two-finger rotate *on the screen*, which the app interprets as a content gesture (in 16-04 it navigated into a pushed screen) and leaves the device orientation untouched. Device rotation needs `agent-device orientation landscape-left` / `portrait`, and `agent-device` keeps its session per working directory, so every `agent-device` call in a session must run from the same cwd or it fails `SESSION_NOT_FOUND`. Verify the result via the `App:` header tag in `sim-use ui` **before** capturing, never by assuming the command took. |
| `agent-device press <alias>` | `sim-use tap --label '…' --device <UDID>` — re-run `ui` before every `@N` tap; disambiguate with `--element-type` / `--frame minY=0.7r` (tab bar) |
| `xcrun simctl ui <UDID> content_size …` | unchanged — this is `simctl`, not a driver verb |

`agent-device` 0.20.8 stays installed as a fallback; a plan that uses it for something `sim-use`
cannot do records which command and why.

Two further mechanics that 16-04 had to discover, recorded so later sweep plans do not:

- **Landscape screenshots come out of `sim-use screenshot` in the device's native portrait
  framebuffer**, i.e. rotated 90°. Straighten each landscape capture with `sips -r 270 <file>`
  right after taking it, so the evidence reads the way the screen did.
- **A page-up/page-down gesture in landscape can land on the home indicator** and switch apps
  instead of scrolling; when that happens `sim-use ui` shows a different bundle in its `App:`
  header. Assert `App: EhPanda` (and the expected orientation tag) before every capture and
  abort the cell rather than screenshotting another app's window.

### Evidence root

`EVIDENCE_ROOT = $HOME/Library/Caches/ehpanda-phase16/` — outside the repository and persistent
across sessions and reboots, which a session scratchpad or a `/tmp` path is not. That persistence
is load-bearing: the D-15 `.large` baselines are captured in plan 16-05 and compared in plan
16-11, with owner checkpoints in between. Create the root and its subfolders with `mkdir -p` at
the start of every session:

| Subfolder | Holds |
|---|---|
| `preflight/` | the 16-03 live-re-layout and XXL-token confirmation shots |
| `sweep/` | round-1 matrix captures (top and bottom of each cell) |
| `d15-baseline/` | the `.large` reference shots of the four `minimumScaleFactor` host surfaces (16-05) |
| `d15-before/` | pre-fix captures accompanying a finding (D-33) |
| `d15-after/` | post-fix captures compared against `d15-baseline/` (16-11) |
| `reverify/` | batched re-verification captures after an owner fix commit |
| `round2/` | round-2 assistive-technology captures |
| `resweep/` | the D-25 targeted re-sweep captures |

### Simulator baseline (read at session start, restored at session end)

| Simulator | `content_size` | `appearance` | `increase_contrast` | Orientation |
|---|---|---|---|---|
| `IPHONE_UDID` | `medium` | `dark` | `disabled` | portrait |
| `IPAD_UDID` | `large` | `light` | `disabled` | portrait |

Recorded by 16-03 on 2026-08-24 before any change, and read back identical after the pre-flight
restore (`content_size` / `appearance` / `increase_contrast` printed the values above on both
simulators; both `sim-use ui` headers carried no orientation tag, and the iPhone's Home heading
frame returned to its baseline 94×41 pt).

The restore value is always the value **recorded** here at session start — never a fixed `large`.
The two simulators differ, so a fixed restore would silently change one of them.

### Forbidden on `IPHONE_UDID` and `IPAD_UDID` (D-09)

These simulators are **phase infrastructure**: they carry the owner's hand-entered login, and
losing it costs the owner a manual re-login.

| Command | Why forbidden |
|---|---|
| `xcrun simctl erase` | destroys the data container and the login |
| `xcrun simctl uninstall` | destroys the app's data container and the login |
| `agent-device settings clear-app-state` | same effect through a different door |
| any `xcodebuild test` destination pointing at these UDIDs | a test run installs a runner and can reset app state; use `SPARE_UDID` |

### Pre-flight

Run by 16-03 on `IPHONE_UDID` only, with `BUNDLE_ID` in the foreground on Home, portrait, from
the `medium` baseline. Evidence under `$EVIDENCE_ROOT/preflight/`: `baseline-medium.png`,
`ax5.png`, `xxl.png` (full-scale, never committed).

| Check | Outcome |
|---|---|
| **A1: live re-layout confirmed.** | `xcrun simctl ui <IPHONE_UDID> content_size accessibility-extra-extra-extra-large` re-laid out the running app within two seconds with no relaunch — same process id before and after, the Home heading grew from 94×41 pt to accessibility size and the section titles wrapped ("Front page"). No sweep cell needs a relaunch after a size change. |
| **A6: XXL = `extra-extra-extra-large` confirmed.** | Switching to `extra-extra-extra-large` rendered visibly smaller than AX5 and larger than the `medium` baseline (Home heading 94×41 → 105×46 pt; "Frontpage" 120×23 → 158×31 pt). This is iOS `xxxLarge`, slider 7, and is the token every XXL cell uses. |
| **Login on `IPHONE_UDID`.** | `present` — Favorites shows a populated list on `BUNDLE_ID`. Nothing else was read. |
| **Login on `IPAD_UDID`.** | `none` — see the `IPAD_LOGIN` row. |
| **Restore.** | `content_size medium`; appearance, Increase Contrast and orientation were never changed. Read-back recorded in § Simulator baseline. |

The pre-flight is not a matrix walk: what the AX5 and XXL shots show on Home is judged by plan
16-04's Home rows, not here.

### D-15 baseline

Captured by plan **16-05** on 2026-08-24, **before any owner edit to a `minimumScaleFactor`
site exists**, so the D-15 half of the parity check ("no visible change at the default size")
can be judged by file name in plan 16-11. Four full-scale PNGs under
`$EVIDENCE_ROOT/d15-baseline/` (written in its `$HOME/…` form, never expanded; never committed
— D-32):

| File | Screen shown | Shrink sites it hosts |
|---|---|---|
| `large-gallery-detail-cell.png` | Home › Frontpage list, four `GalleryDetailCell` rows, the first with a fifteen-character uploader and complete stats (rating, page count, category badge, date with time) | `GalleryListComponents/Cells/GalleryDetailCell.swift:155, :166` |
| `large-detail-header.png` | Gallery Detail top — title, uploader, category badge, action row and the four-item stats strip, of a **Western** gallery (category only; no title, uploader or id is recorded anywhere in this repository) | `DetailFeature/DetailView+HeaderSection.swift:73` (0.72) |
| `large-detail-comment-cells.png` | The same gallery's Detail comment-cells strip (two cards visible, author + date + body) below the previews row | `DetailFeature/DetailView+CommentCells.swift:42` |
| `large-comments-view.png` | The same gallery's full Comments view — navigation header and three comment rows with author, score and timestamp | `DetailFeature/Comments/CommentsView.swift:165` |

Capture conditions: `xcrun simctl ui <IPHONE_UDID> content_size large` (**not** the recorded
`medium` restore value — `large` is the default size D-15 names, and it is set only for this
capture), portrait, `BUNDLE_ID` in the foreground, dark appearance, Increase Contrast disabled,
List Display Mode `Detail`, full-scale 1260×2736 frames.

Build under test: the installed `BUNDLE_ID` bundle reports `CFBundleShortVersionString` **3.0.0**
and `CFBundleVersion` **158**, installed 2026-08-11. The exact commit it was built from is not
recorded, but it necessarily predates every phase-16 source change, because phase 16 has not
changed a single source file yet — plans 16-01 … 16-04 touched only `.swiftlint.yml` and planning
documents. The four shrink sites are therefore at their pre-phase-16 state in these captures.

**Observed at `large`, for the owner's later comparison:** nothing in the four frames is shrunk
below its neighbours' type scale. The Detail header's category badge renders "Western" at the
same glyph height as the surrounding `.headline` text, so the 0.72 factor does **not** engage at
the default size for a seven-character category name; the two `GalleryDetailCell` stats values
(page count, rating row) and both comment-cell/Comments-view author labels likewise render
unshrunk. The one value already incomplete at `large` is the Detail comment **card body**, which
is capped by the card's fixed 300 × `cardHeight` frame and ends in an ellipsis at every size —
a pre-existing state, not a Dynamic Type effect.

## Verdict rule

The owner's rule, verbatim, and the sole verdict basis (D-03):

> degraded means the interface provides less information under larger font size setting. removing
> decoration to save space is okay, but the interface should always provide same contents.

**Fine** — record the cell as verified:

- a label wrapping to 2–3 lines;
- a row growing taller so fewer rows fit on screen;
- decorative chrome (icons, dividers, ornament) dropped to make room.

**Degraded** — record a finding:

- essential *or secondary* text clipped, cut off, or ellipsised;
- content overlapping;
- a control pushed off-screen or unreachable;
- a value abbreviated away.

### D-04 — the strict truncation reading

Any value that reads in full at `.large` but truncates at XXL / AX3 / AX5 is a finding,
**regardless of whether the field is primary or secondary** and regardless of whether the full
value is reachable on another screen.

**Phase 10's secondary-text exemption no longer applies.** Phase 10's 10-10 audit waved through
roughly 20 `lineLimit(1)` sites (uploader, date, page count, category token) on exactly that
exemption. Those sites are back in scope: a Phase-10 verdict of "fine" carries **no** weight here
and must not be inherited. § D-04 checklist lists every one of them for re-judgement.

### Status vocabulary

Matrix cells take one of: `pending` (not yet walked), `pass` (walked, not degraded),
`finding:#N` (degraded, recorded as Findings entry N), `re-verify` (an owner fix touched this
screen; walk it again), `accepted` (degraded but explicitly accepted with the owner's reason
recorded).

D-13 rows close as `fixed` or `accepted (owner reason: …)`. D-04 rows take `pending`, `fine`,
`finding:#N` or `removed-by <commit>`.

## Protocol

The procedure every sweep plan (16-04 … 16-09) follows verbatim, screen by screen. The owner's
words: **max out the font size, open every screen, scroll down to the bottom, confirm nothing is
degraded.** The scroll-to-bottom is not incidental — a screen that looks fine above the fold is
not verified.

### 1. Session start

Read and **record** the simulator's own baseline into § Infrastructure before changing anything,
then create the evidence folders and open the app:

```bash
mkdir -p "$EVIDENCE_ROOT"/{preflight,sweep,d15-baseline,d15-before,d15-after,reverify,round2,resweep}

xcrun simctl ui "$UDID" content_size        # record: this is the restore value
xcrun simctl ui "$UDID" appearance          # record
xcrun simctl ui "$UDID" increase_contrast   # record
agent-device snapshot --platform ios --udid "$UDID"   # the App: header tag carries the orientation

agent-device open "$BUNDLE_ID" --platform ios --udid "$UDID" --foreground
```

Always pass the explicit `--udid` / `<UDID>`, **never `booted`**: two simulators are booted during
this phase and `booted` is ambiguous — it can silently drive the wrong device.

### 2. Navigate

Reach the screen once, via its § Inventory route. Re-run `agent-device snapshot` after every
navigation and after every rotation; alias caches go stale.

### 3. Walk the six cells of that device

For each orientation, then each size:

```bash
agent-device orientation portrait --platform ios --udid "$UDID"        # then: landscape-left
agent-device snapshot --platform ios --udid "$UDID"                    # fresh tree after rotating

xcrun simctl ui "$UDID" content_size extra-extra-extra-large                    # XXL
xcrun simctl ui "$UDID" content_size accessibility-extra-large                  # AX3
xcrun simctl ui "$UDID" content_size accessibility-extra-extra-extra-large      # AX5

agent-device screenshot --platform ios --udid "$UDID" \
  --out "$EVIDENCE_ROOT/sweep/<device>-<orientation>-<size>-<screen#>-top.png" --scale 0.5
agent-device scroll down --settle --platform ios --udid "$UDID"        # repeat to the bottom
agent-device screenshot --platform ios --udid "$UDID" \
  --out "$EVIDENCE_ROOT/sweep/<device>-<orientation>-<size>-<screen#>-bottom.png" --scale 0.5
```

Scroll down repeatedly, with `--settle`, until the screen reaches its bottom — every cell, every
size. One simulator action at a time.

**Judge the cell from the screenshots, not from the snapshot.** A truncated SwiftUI `Text` still
reports its *full* label in the accessibility tree, so the AX snapshot cannot see an ellipsis. The
image is the verdict basis; the snapshot is navigation and a cheap change signal.

### 4. Record and move on

Write the row's Status as `pass`, or as `finding:#N` with a written description plus a new
§ Findings entry. **Never interrupt the sweep to raise a finding** (D-02): record it, continue to
the next screen, and let plan 16-10 report the complete list once every page has been scanned.

### 5. Session end — restore

After the last screen of a session, restore the simulator to exactly what was found:

```bash
xcrun simctl ui "$UDID" content_size "$RECORDED_BASELINE"   # the value recorded in § Infrastructure
agent-device orientation portrait --platform ios --udid "$UDID"
```

The restore value is the **recorded per-simulator baseline** — research observed `medium` on the
iPhone Air and `large` on the iPad Pro 11, so a fixed `large` would silently change the iPhone.
`content_size large` is set only for the explicit D-15 parity captures (the `.large` reference
shots of the four `minimumScaleFactor` host surfaces, plan 16-05), and that capture is itself
followed by the same baseline restore (D-06, D-15).

### Evidence rules

- `EVIDENCE_ROOT = $HOME/Library/Caches/ehpanda-phase16/` — outside the repository and persistent
  across sessions and reboots. Never the session scratchpad and never a `/tmp` path: neither
  survives the owner checkpoints that separate the D-15 baseline capture (16-05) from its
  comparison (16-11). Never a repository path, under any circumstance.
- Every screenshot of **both** rounds goes under it, in the subfolder listed in § Infrastructure.
- Write the path only in its `$HOME/…` form; an expanded home-directory path in a committed file
  leaks the contributor's username in a public repository.
- **No image file ever enters git** — not even of a screen that looks content-free. The repository
  is public, the sweep screenshots real gallery content at AX5, and git history is permanent
  (D-32). Confirm `git status --porcelain` lists no `.png` / `.jpg` / `.jpeg` / `.heic` / `.gif`
  before every commit.
- Table rows carry a **written** description ("uploader name ellipsised at AX3 portrait; reads in
  full at `.large`"), never a filename that implies the image is recoverable from the repo.
- Before/after images per finding go to the owner **in chat** (D-33), by naming the evidence-root
  path and describing what the image shows.
- The D-15 baselines live in `$EVIDENCE_ROOT/d15-baseline/` (plan 16-05) and are compared against
  `$EVIDENCE_ROOT/d15-after/` in plan 16-11.

### Install-over

The **sole** permitted way to put a new build on `IPHONE_UDID` or `IPAD_UDID` — after an owner fix
commit, and every time plans 16-11 and 16-15 … 16-26 need the tree's current state on a sweep
simulator. One simulator at a time.

```bash
# (a) build for that exact simulator — never `xcodebuild test` against a sweep UDID
xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda -configuration Debug \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$EVIDENCE_ROOT/DerivedData"

# (b) confirm the bundle id BEFORE installing
APP="$EVIDENCE_ROOT/DerivedData/Build/Products/Debug-iphonesimulator/EhPanda.app"
plutil -extract CFBundleIdentifier raw "$APP/Info.plist"    # must print exactly BUNDLE_ID

# (c) install over the existing bundle — keeps the data container and the login
xcrun simctl install "$UDID" "$APP"
```

(b) is not optional. The app target's `PRODUCT_BUNDLE_IDENTIFIER` is
`app.ehpanda$(BUNDLE_ID_SUFFIX)`, and the gitignored `Config/LocalSigning.xcconfig` sets that
suffix — so a local build may produce `app.ehpanda.personal` while the owner's login lives in
`app.ehpanda`, or the reverse. Both variants are installed on both sweep simulators, so a mismatched
install silently lands beside the logged-in app instead of over it, and the sweep then walks a
logged-out shell.

If the printed id is not `BUNDLE_ID`: **do not install.** Rebuild with a command-line override
appended to the same `xcodebuild build` invocation — `BUNDLE_ID_SUFFIX=<the suffix that yields
BUNDLE_ID, possibly empty>` — as an argument override, **never** an edit to any xcconfig, and
re-check. If it still mismatches, stop and report to the owner.

(d) Record the HEAD hash and the `plutil` output in the section that motivated the install.

Installing over an existing bundle id preserves the app's data container, which is what keeps the
owner's hand-entered login alive across builds.

### Forbidden on the sweep simulators

Under every circumstance, on `IPHONE_UDID` and `IPAD_UDID`: `xcrun simctl erase`,
`xcrun simctl uninstall`, `agent-device settings clear-app-state`, and any `xcodebuild test`
destination pointing at them. Each destroys or resets the data container that holds the owner's
login, and recovering it costs the owner a manual re-login (D-09). UI tests run on `SPARE_UDID`.

### Resumability

A session starts at the first `pending` or `re-verify` row of § Matrix in layout order. Partial
progress is committed after each screen group with `docs(16): sweep <device> <group> rows`, so an
interrupted session loses nothing.

Re-verification after an owner fix is **batched per fix commit**: the commit touches files, the
§ Inventory "Primary files" column maps those files back to screens, and only those screens are
re-walked at the three sizes — marked `re-verify` first, then resolved. A full 12-cell re-sweep is
reserved for the phase gate.

### Sizes sampled, and why not the small end

Three sample points only — XXL, AX3, AX5 — with AX5 the maximum (D-05, D-06). No `xSmall` pass and
no Bold Text pass (D-07): the rule being verified is about information lost when text **grows**,
and both of those catch a different class of failure that this phase does not claim to cover.

## Inventory

Re-derived against HEAD on the `feature/gsd-phase-16` branch (D-12) — the presentation-site greps
(`.sheet(`, `.fullScreenCover(`, `.popover(`, `.alert(`/`.appAlert(`, `.confirmationDialog(`,
`Menu {`, `.contextMenu`, `.navigationDestination(`, `.searchable(`, `toast`) were re-run and
diffed against the research table. Phase 10's per-screen checklist was used as a diff base only,
never inherited.

A **screen** is a distinct SwiftUI surface the user can land on: a tab root, a pushed path
element, a sheet, a full-screen cover, a popover/menu, an alert/confirmation dialog, or a toast.
Cells are counted with their hosting list — the five gallery-list hosts share `GalleryList` +
`GalleryDetailCell`/`GalleryThumbnailCell`, so a cell finding is recorded once and tagged
"all list hosts". Menus count as popover surfaces because their item text reflows at AX5 too.

Screens that can be content-free (empty Favorites, empty Downloads, empty History, empty Search
history) are still rows: the empty-state view is judged like any other content.

Groups map one-to-one onto the sweep plans: **A** = #1–#13 (16-04 iPhone / 16-07 iPad),
**B** = #14–#27 (16-05 / 16-08), **C** = #28–#42 (16-06 / 16-09).

| # | Screen | Route | Primary files | Login-gated | Group | D-11 |
|---|---|---|---|---|---|---|
| 1 | Tab bar shell | launch | `AppFeature/View/TabBar/TabBarView.swift` (4 presentation sites: NewDawn, ErrorInfo, Setting, Filters) | no | A | in |
| 2 | Home root — hero carousel, Misc/Ranking sections | Home tab | `HomeFeature/HomeView.swift`, `HomeView+Sections.swift`, `GalleryCardCell.swift`, `GalleryRankingCell.swift` | no (popular only) | A | in |
| 3 | Home › Frontpage (+ Filters, DateSeek sheets, search bar) | push | `HomeFeature/Frontpage/FrontpageView.swift` | no | A | in |
| 4 | Home › Popular (+ Filters sheet, search bar) | push | `HomeFeature/Popular/PopularView.swift` | no | A | in |
| 5 | Home › Watched (login placeholder vs list, 3 sheets, features menu) | push | `HomeFeature/Watched/WatchedView.swift` | **yes** | A | in |
| 6 | Home › History (+ clear confirmation dialog, empty state) | push | `HomeFeature/History/HistoryView.swift` | no | A | in |
| 7 | Home › Toplists (+ type menu, jump-page alert with text field) | push | `HomeFeature/Toplists/ToplistsView.swift`, `AppComponents/ToolbarItems.swift` (`ToplistsTypeMenu`, `JumpPageButton`) | no | A | in |
| 8 | Favorites root (+ index menu, sort menu, 2 sheets, features menu, empty state) | Favorites tab | `FavoritesFeature/FavoritesView.swift`, `AppComponents/ToolbarItems.swift` | **yes** | A | in |
| 9 | Search root (history keywords, quick-search chips, features menu, empty state) | Search tab | `SearchFeature/SearchRootView.swift`, `SearchRootView+Keywords.swift`, `GalleryHistoryCell.swift` | no | A | in |
| 10 | Search results (+ 3 sheets, tag-suggestion overlay, features menu) | submit | `SearchFeature/SearchView.swift`, `AppComponents/TagSuggestionView.swift` | no | A | in |
| 11 | Downloads root (rows, swipe actions, sort/filter menu, row context menu, 2 confirmation dialogs, empty state) | Downloads tab | `DownloadsFeature/DownloadsView.swift`, `DownloadsView+Subviews.swift`, `DownloadRowFeature.swift` | no | A | in |
| 12 | Downloads › Inspector sheet (per-page validation rows) | row inspect | `DownloadsFeature/DownloadsView+Subviews.swift` (`DownloadInspectorView`) | no | A | in |
| 13 | Downloads › Move-to-folder / FolderManager (+ delete confirmation dialog) | row action | `DetailFeature/FolderManager/FolderManagerView.swift` | **yes** | A | in |
| 14 | Gallery Detail (header, stats strip, description, tag cloud + tag context menu, previews strip, comments preview, action alert) | any list cell; deep link `ehpanda://e-hentai.org/g/<gid>/<token>/` | `DetailFeature/DetailView.swift`, `DetailView+HeaderSection.swift`, `DetailView+Subviews.swift`, `DetailView+CommentCells.swift`, `DetailView+Navigation.swift` | **yes** (live) | B | in |
| 15 | Detail › Previews (grid + full-screen cover) | push | `DetailFeature/Previews/PreviewsView.swift` | yes | B | in |
| 16 | Detail › Comments (+ post/edit sheet, vote actions) | push; deep link `…/#c<id>` | `DetailFeature/Comments/CommentsView.swift`, `DetailFeature/Components/PostCommentView.swift` | yes | B | in |
| 17 | Detail › Detail Search (+ 2 sheets, tag-suggestion overlay, features menu) | tag tap | `DetailFeature/DetailSearch/DetailSearchView.swift` | yes | B | in |
| 18 | Detail › Gallery Infos | push | `DetailFeature/GalleryInfos/GalleryInfosView.swift` | yes | B | in |
| 19 | Detail › Archives sheet (funds, price rows) | header action | `DetailFeature/Archives/ArchivesView.swift` | **yes** | B | in |
| 20 | Detail › Torrents sheet (+ share sheet) | header action | `DetailFeature/Torrents/TorrentsView.swift` | **yes** | B | in |
| 21 | Detail › Tag Detail sheet | tag context menu | `DetailFeature/Components/TagDetailView.swift` | no | B | in |
| 22 | Detail › NewDawn sheet (greeting) | greeting | `AppComponents/NewDawnView.swift` | — | B | NewDawn in; share sheet = system (out) |
| 23 | Detail › download confirmation dialogs (delete / retry mode) | header download button | `DetailFeature/DetailReducer+Download.swift`, `DetailFeature/DetailView.swift` | yes | B | in |
| 24 | Reading (paging stack, zoom/pan, tap zones, page context menu) | Detail › Read; deep link `ehpanda://e-hentai.org/s/<token>/<gid>-<page>` | `ReadingFeature/ReadingView.swift`, `ReadingViewComponents.swift` | yes | B | in |
| 25 | Reading › Control panel (upper/lower bars, slider preview, 2 menus, features menu) | tap | `ReadingFeature/Support/ControlPanel.swift` | yes | B | in |
| 26 | Reading › Reading Setting sheet | panel gear | `ReadingSettingFeature/ReadingSettingView.swift` | no | B | in |
| 27 | Reading › Live Text overlay | panel | `ReadingFeature/Support/LiveTextView.swift` | yes | B | Live Text overlay in; share sheet = system (out) |
| 28 | Setting root (icon rows) | Setting tab (push, or modal on iPad per `isRegularWidthPad`) | `SettingFeature/SettingView.swift` | no | C | in |
| 29 | Setting › Account (cookie state rows, logout confirmation dialog, toast, WebView sheet) | push | `SettingFeature/AccountSetting/AccountSettingView.swift` | state varies | C | native rows in; WebView sheet out |
| 30 | Setting › Login (native form, toast, error sheet) | push | `SettingFeature/Login/LoginView.swift` | no | C | native chrome in; WebView + Cloudflare challenge out |
| 31 | Setting › General (analytics opt-out row, translations, cache, 2 confirmation dialogs) | push | `SettingFeature/GeneralSetting/GeneralSettingView.swift` | no | C | in |
| 32 | Setting › General › Activity Logs (+ run picker sheet, run menu, log detail, search bar) | push | `SettingFeature/AppActivityLogs/AppActivityLogsView.swift` | no | C | in |
| 33 | Setting › Appearance (+ App Icon picker) | push | `SettingFeature/AppearanceSetting/AppearanceSettingView.swift` | no | C | in |
| 34 | Setting › Reading | push | `ReadingSettingFeature/ReadingSettingView.swift` | no | C | in |
| 35 | Setting › Download | push | `SettingFeature/Components/DownloadSettingView.swift` | no | C | in |
| 36 | Setting › Laboratory | push | `SettingFeature/Components/LaboratorySettingView.swift` | no | C | in |
| 37 | Setting › About | push | `SettingFeature/Components/AboutView.swift` | no | C | in |
| 38 | Setting › EhSetting (native sections 1–3, delete-profile confirmation dialog) | push | `SettingFeature/EhSetting/EhSettingView.swift`, `EhSettingView+Sections1.swift`, `+Sections2.swift`, `+Sections3.swift` | **yes** | C | native sections in; web pages out |
| 39 | Filters sheet (category grid, advanced rows, reset confirmation dialog) | toolbar | `FiltersFeature/FiltersView.swift`, `AppComponents/CategoryView.swift` | no | C | in |
| 40 | Quick Search sheet (+ word editor, delete confirmation dialog) | toolbar | `QuickSearchFeature/QuickSearchView.swift` | no | C | in |
| 41 | Date Seek picker | toolbar | `DateSeekFeature/DateSeekPickerView.swift` | no | C | in |
| 42 | Error surface (`ErrorInfoView` sheet) + toasts | any failure / `toast_message` | `AppComponents/ErrorInfoView.swift`, `SystemNotification/ToastMessageView.swift`, `SystemNotification/View+Toast.swift` | no | C | in |

### Excluded (D-11)

| Surface | Site | Reason |
|---|---|---|
| EhSetting web pages | `SettingFeature/EhSetting/EhSettingView.swift:44` `.sheet(item: $store.destination.webView)` | WebKit renders and lays out the text; SwiftUI Dynamic Type does not reach it (D-11). |
| Account Setting WebView sheet | `SettingFeature/AccountSetting/AccountSettingView.swift:52` | Same: a `WKWebView` page (D-11). |
| Login WebView sheet | `SettingFeature/Login/LoginView.swift:73` | Same: the hand-login page the owner uses in plan 16-03 (D-11). |
| Cloudflare challenge surface | `SettingFeature/Login/LoginView.swift:84` `.sheet(item: $store.destination.challenge)` | WebView-rendered, added after Phase 10; explicitly out (D-11, D-12). |
| ShareExtension | `ShareExtension/` | Not a SwiftUI screen EhPanda draws in-app (D-11). |
| iOS share sheet | `DetailView.swift:243`, `ReadingView.swift:104`, `TorrentsView.swift:50` | System-provided UI (D-11). |
| Photo picker / save-to-library UI | `ReadingFeature` save action | System-provided UI (D-11). |
| `BGContinuedProcessingTask` card | `BackgroundProcessingClient` | System-provided UI (D-11). |

### D-12 diff against the research inventory

Nothing was dropped. The re-grep confirmed all 42 research rows and surfaced no 43rd landing
surface; five presentation sites that the research table did not name individually are folded
into their host row and named explicitly in the Screen column above, so none is lost:

| Sub-surface found by the re-grep | Site | Folded into |
|---|---|---|
| Toplists jump-page alert (an alert with a text field) | `HomeFeature/Toplists/ToplistsView.swift:34` + `AppComponents/ToolbarItems.swift:84` | #7 |
| Reading page context menu | `ReadingFeature/ReadingViewComponents.swift:149` | #24 |
| Downloads row context menu | `DownloadsFeature/DownloadsView.swift:195` | #11 |
| Detail tag context menu (the route to #21) | `DetailFeature/DetailView+Subviews.swift:301` | #14 |
| Activity-logs run picker sheet + run menu | `SettingFeature/AppActivityLogs/AppActivityLogsView.swift:53, 62` | #32 |

Additions since the Phase 10 table, all present above: the Cloudflare challenge destination
(excluded — WebView), the analytics opt-out row in General Settings (#31), Phase 15's download
inspector (#12), per-page validation rows (#12), swipe/context actions and the pause-refusal
toast (#11), the `SystemNotification` toast module (#42), and the App Icon picker (#33).

Login-gated surfaces only the D-09 simulators can reach: #5, #8, #13, #19, #20, #38, and the
*live* variants of #14–#18 and #23–#25.

## Matrix

Twelve cells per in-scope screen: iPhone + iPad × portrait + landscape × XXL / AX3 / AX5 (D-05,
D-06, D-10). **iPad rows are first-class**, never derived from iPhone rows: `isRegularWidthPad`
routes Detail and Setting to different layouts entirely, so iPad AX5 failure modes are genuinely
different.

Size names carry their `simctl ui … content_size` token: **XXL** = `extra-extra-extra-large`
(iOS `xxxLarge`, slider 7, the last non-accessibility size — this is what "XXL" meant in Phase 10
D-03, note the naming skew), **AX3** = `accessibility-extra-large` (slider 10), **AX5** =
`accessibility-extra-extra-extra-large` (slider 12).

AX5 is the **maximum** sampled size: the Larger Text slider has 12 positions and SwiftUI's
`DynamicTypeSize` ends at `.accessibility5`, so "max out the font size" resolves to AX5 and no row
claims a size beyond it (D-06). `content_size large` appears nowhere in this matrix — it is set
only for the explicit D-15 parity captures (§ Protocol).

**D-07 — the large end only.** There is no `xSmall` column and no Bold Text column, by decision:
the owner's rule is about information lost when text *grows*. Both passes catch real failures, but
different ones, and both are out of scope for this phase.

Status ∈ {`pending`, `pass`, `finding:#N`, `re-verify`, `accepted`}. The Finding column carries a
written description only — never a screenshot filename (D-32).

### iPhone — Group A (#1–#13) — plan 16-04

| # | Screen | Device | Orientation | Size | Status | Finding |
|---|---|---|---|---|---|---|
| 1 | Tab bar shell | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Tab bar keeps all five labels and glyphs; no truncation. |
| 1 | Tab bar shell | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Tab bar labels unchanged — the system caps tab-bar text below AX sizes. |
| 1 | Tab bar shell | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Tab bar labels unchanged and all five items reachable. |
| 1 | Tab bar shell | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Tab bar renders all five labels; floating bar overlays scrollable content only. |
| 1 | Tab bar shell | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Tab bar labels unchanged. |
| 1 | Tab bar shell | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Tab bar labels unchanged and all five items reachable. |
| 2 | Home root | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#1 | Hero-carousel title drops from four lines to three; the tail is ellipsised. Sections, ranking cells and tab bar fine. |
| 2 | Home root | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#1, #3 | Hero title collapses to one ellipsised line; ranking cells lose both title tail and uploader. |
| 2 | Home root | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#1, #2, #3 | Hero title down to one clipped word, the neighbouring card is drawn over its title and rating, ranking cells heavily truncated. |
| 2 | Home root | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Wider card absorbs the growth — hero title, ranking titles and uploaders all read in full. |
| 2 | Home root | iPhone | landscape | AX3 (accessibility-extra-large) | finding:#1, #3 | Hero title reduced to one ellipsised line; ranking uploader ellipsised. |
| 2 | Home root | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#1, #3 | Hero title ellipsised after three words; ranking cell title and uploader both truncated. |
| 3 | Home › Frontpage | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#4, #5 | Long row titles lose their tail at the third line; the filter field's capsule rendered with no icon and no placeholder on this screen. |
| 3 | Home › Frontpage | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#4, #5, #6 | Filter capsule empty; titles truncated; language, page count and date cut off by the screen's right edge. |
| 3 | Home › Frontpage | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#4, #5, #6, #7, #8 | Screen title not rendered at all; filter capsule empty; page count gone, date and language cut; cover thumbnail squeezed to a sliver. |
| 3 | Home › Frontpage | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Every value in the rows walked reads in full, filter field included. |
| 3 | Home › Frontpage | iPhone | landscape | AX3 (accessibility-extra-large) | pass | No clipped or ellipsised value in the rows walked. |
| 3 | Home › Frontpage | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#5 | A long row title loses its tail at the third line; all other values read in full. |
| 4 | Home › Popular | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#5 | A long row title is ellipsised at the third line; filter field, uploader, stats and date all read in full. |
| 4 | Home › Popular | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#4, #5, #6 | Filter capsule empty; titles truncated; language, page count and date cut at the right edge. |
| 4 | Home › Popular | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#4, #5, #6, #7, #8 | Screen title absent; filter capsule empty; title runs off the right edge un-ellipsised; page count lost; cover a sliver. |
| 4 | Home › Popular | iPhone | landscape | XXL (extra-extra-extra-large) | pass | All row values read in full. |
| 4 | Home › Popular | iPhone | landscape | AX3 (accessibility-extra-large) | pass | All row values read in full. |
| 4 | Home › Popular | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Title, uploader, language, page count and date all read in full in the rows walked. |
| 5 | Home › Watched | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#5, #9 | Session present, list shown. A long title loses its tail; a long uploader is ellipsised where a language value shares its line. |
| 5 | Home › Watched | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#4, #5, #6 | Filter capsule empty; title truncated; language and page count cut at the right edge. |
| 5 | Home › Watched | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#4, #5, #6, #7, #8 | Screen title absent; filter capsule empty; language and page count cut; cover thumbnail a sliver. |
| 5 | Home › Watched | iPhone | landscape | XXL (extra-extra-extra-large) | pass | The longest title in the list reads in full across two lines; all other values complete. |
| 5 | Home › Watched | iPhone | landscape | AX3 (accessibility-extra-large) | finding:#5 | The same title that read in full at XXL now ellipsises at the third line. |
| 5 | Home › Watched | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#5 | Title ellipsised at the third line; remaining values complete. |
| 6 | Home › History | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#5 | A long row title loses its tail; the footer note, filter field and all row values read in full. |
| 6 | Home › History | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#4, #5, #6 | Filter capsule empty; title truncated; page count and date cut at the right edge. |
| 6 | Home › History | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#4, #5, #6, #8, #9 | Screen title absent; filter capsule empty and overlapping rows; title and date cut at the right edge; uploader ellipsised; cover a sliver. |
| 6 | Home › History | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Footer note wraps; every row value reads in full. |
| 6 | Home › History | iPhone | landscape | AX3 (accessibility-extra-large) | pass | No clipped or ellipsised value in the rows walked. |
| 6 | Home › History | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Footer note wraps to two lines; row values read in full in the rows walked. |
| 7 | Home › Toplists | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#5 | Screen title and the type/jump-page controls read in full; a long row title loses its tail. |
| 7 | Home › Toplists | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#4, #5, #6, #7 | Screen title ellipsised; filter capsule empty; row title truncated; language, page count and date cut at the right edge. |
| 7 | Home › Toplists | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#4, #5, #6, #7, #8 | Screen title absent; filter capsule empty; page count lost; cover a sliver. Type menu itself renders all four options in full. |
| 7 | Home › Toplists | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Screen title, filter field and every row value read in full. |
| 7 | Home › Toplists | iPhone | landscape | AX3 (accessibility-extra-large) | pass | No clipped or ellipsised value in the rows walked. |
| 7 | Home › Toplists | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Screen title, filter field and every row value read in full. |
| 8 | Favorites root | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#5 | Session present, list shown. Long row titles lose their tail at the third line; index/sort/features glyphs, search field and all row values read in full. |
| 8 | Favorites root | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#5, #6 | Titles truncated; page count and date cut at the screen's right edge. The tab-root search field still reads correctly. |
| 8 | Favorites root | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#5, #6, #8 | Title cut mid-glyph at the right edge; page-count number lost; cover thumbnail squeezed to a sliver. Screen title and search field survive (tab root). |
| 8 | Favorites root | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Every row value reads in full in the rows walked. |
| 8 | Favorites root | iPhone | landscape | AX3 (accessibility-extra-large) | finding:#5 | A long row title loses its tail at the third line; all other values complete. |
| 8 | Favorites root | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#5 | A long row title loses its tail at the third line; all other values complete. |
| 9 | Search root | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#10 | History keyword row and section headers fine; the Recently Seen cell's title is ellipsised. |
| 9 | Search root | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#10 | Recently Seen cell overflows its slot — the title is cut at both ends and the cover is pushed past the screen's left edge. |
| 9 | Search root | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#10 | Recently Seen cells overlap the section header and each other; titles cut at both edges; the section headings collapse to roughly one word per line. |
| 9 | Search root | iPhone | landscape | XXL (extra-extra-extra-large) | finding:#10 | Recently Seen cell titles ellipsised; keyword row and headers fine. |
| 9 | Search root | iPhone | landscape | AX3 (accessibility-extra-large) | finding:#10 | The search field overlaps the Recently Searched heading; Recently Seen cell titles cut. |
| 9 | Search root | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#10 | Recently Seen cells overlap each other and their covers; titles cut at both edges. |
| 10 | Search results | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Screen title, row titles, uploader, language, page count and date all read in full. |
| 10 | Search results | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#4, #5, #6 | Filter capsule empty; a long title ellipsised; language, page count and date cut at the right edge. |
| 10 | Search results | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#4, #6, #7, #8 | Screen title not rendered; filter capsule empty; page count and date cut at the right edge; cover thumbnail squeezed away. |
| 10 | Search results | iPhone | landscape | XXL (extra-extra-extra-large) | pass | All row values read in full. |
| 10 | Search results | iPhone | landscape | AX3 (accessibility-extra-large) | pass | All row values read in full. |
| 10 | Search results | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | All row values read in full, including a long bracketed title over two lines. |
| 11 | Downloads root | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Empty state, populated row, row context menu and swipe action all read in full, download badge included. Empty-state copy wraps and stays complete. |
| 11 | Downloads root | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#5, #6 | Row title ellipsised at the second line (download badge present); the badge's progress text and the date are cut at the screen's right edge. |
| 11 | Downloads root | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#5, #6, #8, #11 | Title cut mid-glyph; badge progress reduced to one digit; date cut; cover thumbnail gone; the delete confirmation's message is cut off mid-sentence. Row context menu and empty state remain complete. |
| 11 | Downloads root | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Row title, uploader, badge, category and date all read in full. |
| 11 | Downloads root | iPhone | landscape | AX3 (accessibility-extra-large) | pass | All row values read in full. |
| 11 | Downloads root | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Title over two lines, badge `14/14` and the full timestamp all read in full. |
| 12 | Downloads › Inspector sheet | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Header, the three status rows with their page ranges, and all three action rows read in full. |
| 12 | Downloads › Inspector sheet | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#5, #6 | Header title ellipsised; the badge progress and the timestamp's time are cut at the right edge. |
| 12 | Downloads › Inspector sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#5, #6, #8 | Header title ellipsised; badge and date cut at the right edge; cover thumbnail squeezed away. Status and action rows wrap and stay complete. |
| 12 | Downloads › Inspector sheet | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Header and every status and action row read in full. |
| 12 | Downloads › Inspector sheet | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Header and every status and action row read in full. |
| 12 | Downloads › Inspector sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Header title over two lines, badge `14/14` and the full timestamp all read in full. |
| 13 | Downloads › Move-to-folder / FolderManager | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Reached through the gallery header's download menu (`Manage Folders`) — the Downloads row menu offers Detail / Pages / Delete only. Title, close and add controls and the folder row all read in full. |
| 13 | Downloads › Move-to-folder / FolderManager | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Folder row, sheet title and both toolbar controls read in full. |
| 13 | Downloads › Move-to-folder / FolderManager | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Folder row, sheet title and both toolbar controls read in full; nothing clipped. |
| 13 | Downloads › Move-to-folder / FolderManager | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Folder row, sheet title and both toolbar controls read in full. |
| 13 | Downloads › Move-to-folder / FolderManager | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Folder row, sheet title and both toolbar controls read in full. |
| 13 | Downloads › Move-to-folder / FolderManager | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Folder row, sheet title and both toolbar controls read in full; nothing clipped. |

### iPhone — Group B (#14–#27) — plan 16-05

| # | Screen | Device | Orientation | Size | Status | Finding |
|---|---|---|---|---|---|---|
| 14 | Gallery Detail | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#13, #14, #16 | Header title ellipsised where it read to its last word at `.large`; stats-strip column labels all abbreviated ("FAVORI…", "196 RAT…") and the rating star row clipped at both ends; comment-cell author ellipsised. Tag cloud, previews strip and uploader still read in full. |
| 14 | Gallery Detail | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#13, #14, #15, #16, #17 | Title and uploader both ellipsised; every stats column loses its label AND its value (1133 → "11…", 4.50 → "4.…"); the longest tag runs off the right edge cut mid-word; comment author and date both ellipsised. |
| 14 | Gallery Detail | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#13, #14, #15, #16, #17 | Stats columns down to two characters each ("FA…", "1…", "Ti…") with the star row reduced to one clipped star; two tags cut at the right edge; comment author "Baro…" and date "2026…" — the timestamp loses even its year. |
| 14 | Gallery Detail | iPhone | landscape | XXL (extra-extra-extra-large) | finding:#16 | Title, uploader, category, all five stats columns and the whole tag cloud read in full; only the comment cell degrades — author ellipsised and the second cell's date loses its time. |
| 14 | Gallery Detail | iPhone | landscape | AX3 (accessibility-extra-large) | finding:#14, #16 | Stats-strip column labels ellipsised and the star row clipped at both ends, though every value survives; comment authors and dates ellipsised. Title, uploader and tag cloud read in full. |
| 14 | Gallery Detail | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#14, #16, #17 | Stats labels down to four characters and the star row shows three stars for a 4.50 rating; comment card bodies now ellipsised where they read in full at `.large`. Title, uploader and tag cloud still complete. |
| 15 | Detail › Previews | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Grid stays three columns; every page number reads in full and the navigation title is complete. Walked to page 30. |
| 15 | Detail › Previews | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Page numbers grow with the type size and the grid spaces itself to fit them; nothing clipped or ellipsised. |
| 15 | Detail › Previews | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Page numbers render at full accessibility size beside their thumbnails, grid unchanged, navigation title complete. Walked past page 50. |
| 15 | Detail › Previews | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Three-column grid, all page numbers and the navigation title read in full. |
| 15 | Detail › Previews | iPhone | landscape | AX3 (accessibility-extra-large) | pass | No clipped or ellipsised value; the only text on the screen is the page number and it grows cleanly. |
| 15 | Detail › Previews | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Page numbers reach accessibility size without colliding with their thumbnails; grid and navigation title intact. |
| 16 | Detail › Comments | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#18 | Comment bodies wrap and read in full, but the scored rows' timestamps lose their minutes at the right edge of the header row. Authors still complete. |
| 16 | Detail › Comments | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#18 | Every author is ellipsised ("Pecan…", "ezeq…") and every timestamp is cut back to its year ("2025/…"). Bodies and vote scores read in full. |
| 16 | Detail › Comments | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#18 | Authors down to three or four characters ("Pec…", "eze…") and timestamps to "20…"; the header row keeps its single-line layout instead of stacking. Bodies wrap fully and the post-comment sheet (opened and cancelled, nothing posted) reads in full. |
| 16 | Detail › Comments | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Author, vote score, full timestamp and body all read in full on every row walked. |
| 16 | Detail › Comments | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Header rows still fit — author, score and the complete "YYYY/MM/DD, HH:MM" timestamp — and bodies wrap without loss. |
| 16 | Detail › Comments | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#18 | Authors and bodies read in full, but the scored row's timestamp loses its minutes ("2025/04/20, 7:…"). |
| 17 | Detail › Detail Search | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#5 | Reached by tapping a tag in the Detail tag cloud. Long row titles lose their tail at the third line; uploader, language, rating, page count, category badge and date all read in full, and the search term in the navigation bar is complete. |
| 17 | Detail › Detail Search | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#5, #6 | Titles truncated; the row's right-hand column is cut by the screen edge — language loses its last letter, the page-count number loses digits and the date loses its time. |
| 17 | Detail › Detail Search | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#5, #6, #8, #9 | Titles run off the right edge cut mid-word with no ellipsis; uploader ellipsised beside the language value; page count reduced to its glyph; date cut after the month; cover thumbnail squeezed to a sliver. |
| 17 | Detail › Detail Search | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Every row value reads in full in the rows walked, search term included. |
| 17 | Detail › Detail Search | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Titles wrap to three complete lines; uploader, language, rating, page count, category and the full timestamp all read in full. |
| 17 | Detail › Detail Search | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#5 | A long bracketed title loses its tail at the third line; every other row value, including the full timestamp, reads in full. |
| 18 | Detail › Gallery Infos | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Reached through the trailing ellipsis item of the Detail stats strip. Every row reflows to a label-above-value layout when needed; title, all five URLs, uploader, timestamp and every count read in full. |
| 18 | Detail › Gallery Infos | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#19 | The Archive URL and Torrent URL values are ellipsised at their third line, losing the token that is the whole point of the row; the remaining rows still read in full. |
| 18 | Detail › Gallery Infos | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#19 | Title, Gallery URL, Archive URL, Torrent URL and Parent URL are all cut at the third line; the numeric rows and the uploader still read in full and the ID wraps rather than truncating. |
| 18 | Detail › Gallery Infos | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Every row, URLs included, reads in full. |
| 18 | Detail › Gallery Infos | iPhone | landscape | AX3 (accessibility-extra-large) | pass | The wider line lets all five URLs finish inside three lines; nothing clipped. |
| 18 | Detail › Gallery Infos | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Title tail, all five URLs, uploader and every count read in full — the three-line cap is only reached in portrait. |
| 19 | Detail › Archives sheet | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Session present. Both archive cards keep their name, size and price inside the card; both funds values and the H@H action read in full. Nothing was purchased. |
| 19 | Detail › Archives sheet | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#20 | The first card's name is ellipsised ("Origin…") and its price line is pushed outside the card's border; both funds values lose most of their digits ("500,…", "7,1…"). |
| 19 | Detail › Archives sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#20 | Card names down to "Orig…" / "128…" — the two resolutions are no longer distinguishable — sizes cut to "182.0…" without their unit, both texts drawn outside the card frame, and the funds values reduced to "50…" and "7,…". |
| 19 | Detail › Archives sheet | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Both cards, both funds values and the action button read in full. |
| 19 | Detail › Archives sheet | iPhone | landscape | AX3 (accessibility-extra-large) | finding:#20 | Both cards lose their size AND price lines entirely — only the resolution name survives — so the sheet no longer shows what an archive costs or how large it is. Funds values still read in full. |
| 19 | Detail › Archives sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#20 | The cards are clipped to a sliver of their name, with the funds row drawn on top of them; the GP balance is ellipsised. Nothing was purchased. |
| 20 | Detail › Torrents sheet | iPhone | portrait | XXL (extra-extra-extra-large) | pass | All four meta values (seeders, leechers, downloads, file size), the torrent file name and the uploader-plus-timestamp line read in full. No torrent download was started. |
| 20 | Detail › Torrents sheet | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#21 | The four meta values are clipped by their fixed 44-point slots — the leechers "0" renders as a half glyph, the download count keeps only a fragment, and the file size is reduced to its first digit. The timestamp also loses its time. |
| 20 | Detail › Torrents sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#21 | The four meta values are not rendered at all — only their glyphs remain, so seeders, leechers, downloads and file size are all invisible. The uploader and the timestamp are ellipsised to four characters each. |
| 20 | Detail › Torrents sheet | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Meta row, file name and the uploader-plus-timestamp line all read in full. |
| 20 | Detail › Torrents sheet | iPhone | landscape | AX3 (accessibility-extra-large) | pass | The wider row keeps all four meta values, the whole file name over two lines and the full timestamp. |
| 20 | Detail › Torrents sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Meta values, file name and timestamp all read in full; the sheet's own title is complete. |
| 21 | Detail › Tag Detail sheet | iPhone | portrait | XXL (extra-extra-extra-large) | blocked: unreachable in an English session | The sheet's only entry point is the tag context menu, and that item is gated on the tag carrying a non-empty translated description. The sweep enabled the Tags Extension and Translate Tags, relaunched, and inspected the downloaded English translation cache: every one of its entries has an empty description field, so the gate can never open while the app runs in English. Both settings were switched back off afterwards. |
| 21 | Detail › Tag Detail sheet | iPhone | portrait | AX3 (accessibility-extra-large) | blocked: unreachable in an English session | The sheet's only entry point is the tag context menu, and that item is gated on the tag carrying a non-empty translated description. The sweep enabled the Tags Extension and Translate Tags, relaunched, and inspected the downloaded English translation cache: every one of its entries has an empty description field, so the gate can never open while the app runs in English. Both settings were switched back off afterwards. |
| 21 | Detail › Tag Detail sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: unreachable in an English session | The sheet's only entry point is the tag context menu, and that item is gated on the tag carrying a non-empty translated description. The sweep enabled the Tags Extension and Translate Tags, relaunched, and inspected the downloaded English translation cache: every one of its entries has an empty description field, so the gate can never open while the app runs in English. Both settings were switched back off afterwards. |
| 21 | Detail › Tag Detail sheet | iPhone | landscape | XXL (extra-extra-extra-large) | blocked: unreachable in an English session | The sheet's only entry point is the tag context menu, and that item is gated on the tag carrying a non-empty translated description. The sweep enabled the Tags Extension and Translate Tags, relaunched, and inspected the downloaded English translation cache: every one of its entries has an empty description field, so the gate can never open while the app runs in English. Both settings were switched back off afterwards. |
| 21 | Detail › Tag Detail sheet | iPhone | landscape | AX3 (accessibility-extra-large) | blocked: unreachable in an English session | The sheet's only entry point is the tag context menu, and that item is gated on the tag carrying a non-empty translated description. The sweep enabled the Tags Extension and Translate Tags, relaunched, and inspected the downloaded English translation cache: every one of its entries has an empty description field, so the gate can never open while the app runs in English. Both settings were switched back off afterwards. |
| 21 | Detail › Tag Detail sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: unreachable in an English session | The sheet's only entry point is the tag context menu, and that item is gated on the tag carrying a non-empty translated description. The sweep enabled the Tags Extension and Translate Tags, relaunched, and inspected the downloaded English translation cache: every one of its entries has an empty description field, so the gate can never open while the app runs in English. Both settings were switched back off afterwards. |
| 22 | Detail › NewDawn sheet | iPhone | portrait | XXL (extra-extra-extra-large) | blocked: greeting not presented this session | The New Dawn greeting is server-issued once per day and cannot be summoned; it was not presented during this session, including across a full app relaunch. |
| 22 | Detail › NewDawn sheet | iPhone | portrait | AX3 (accessibility-extra-large) | blocked: greeting not presented this session | The New Dawn greeting is server-issued once per day and cannot be summoned; it was not presented during this session, including across a full app relaunch. |
| 22 | Detail › NewDawn sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: greeting not presented this session | The New Dawn greeting is server-issued once per day and cannot be summoned; it was not presented during this session, including across a full app relaunch. |
| 22 | Detail › NewDawn sheet | iPhone | landscape | XXL (extra-extra-extra-large) | blocked: greeting not presented this session | The New Dawn greeting is server-issued once per day and cannot be summoned; it was not presented during this session, including across a full app relaunch. |
| 22 | Detail › NewDawn sheet | iPhone | landscape | AX3 (accessibility-extra-large) | blocked: greeting not presented this session | The New Dawn greeting is server-issued once per day and cannot be summoned; it was not presented during this session, including across a full app relaunch. |
| 22 | Detail › NewDawn sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: greeting not presented this session | The New Dawn greeting is server-issued once per day and cannot be summoned; it was not presented during this session, including across a full app relaunch. |
| 23 | Detail › download confirmation dialogs | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Raised from the Detail header's download control on the gallery this phase downloaded. Title, the full explanatory sentence and both Cancel and Delete read in full. Cancelled; nothing was deleted. |
| 23 | Detail › download confirmation dialogs | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Title wraps to two lines, the sentence to three, and both buttons stack side by side and read in full. |
| 23 | Detail › download confirmation dialogs | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Title over two lines, the whole sentence over five, and Delete and Cancel stacked vertically — the full-width alert absorbs the growth cleanly. Cancelled. |
| 23 | Detail › download confirmation dialogs | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Title, sentence and both buttons all read in full. |
| 23 | Detail › download confirmation dialogs | iPhone | landscape | AX3 (accessibility-extra-large) | finding:#23 | The explanatory sentence is cut after its fourth word — the rest is hidden behind the button row and the alert does not scroll. Both buttons still read. |
| 23 | Detail › download confirmation dialogs | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#23 | The alert renders only its title and the red Delete button; the explanatory sentence AND the Cancel button are laid out below the alert's own bounds and are neither visible nor tappable, so the only visible affordance on a destructive confirmation is the destructive one. |
| 24 | Reading | iPhone | portrait | XXL (extra-extra-extra-large) | pass | The reading surface itself draws no app-owned text — page images only, unaffected by the type size — and the centre tap zone still summons the control panel. The page context menu's five actions read in full. |
| 24 | Reading | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Page images unchanged; tap zones and the page context menu still reachable and complete. |
| 24 | Reading | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Page images unchanged and scrollable to the end; the page context menu's items wrap to two lines, drop their glyphs and scroll to reach the last of the five — nothing unreachable. |
| 24 | Reading | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Page images only; tap zones and page context menu intact. |
| 24 | Reading | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Page images unchanged; context menu items read in full. |
| 24 | Reading | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Page images unchanged; the context menu shows three of its five items at once and scrolls to the rest, each reading in full. |
| 25 | Reading › Control panel | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Page indicator "1 / 14" reads in full in its capsule; the upper bar's three glyph controls and the lower bar's "1" / slider / "14" are all complete. |
| 25 | Reading › Control panel | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#22 | The page indicator's capsule is squeezed to a stub showing only an ellipsis — the current page and the page total are both gone. Lower bar and glyph controls still read in full. |
| 25 | Reading › Control panel | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#22 | The page indicator renders nothing at all: its capsule is a two-point sliver beside the close button. The lower bar's "1" and "14", the three upper glyphs, the More menu and the Auto-Play menu all remain readable (menu items wrap to two lines and the menu scrolls to reach the last one). |
| 25 | Reading › Control panel | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Page indicator, glyph controls and slider end labels all read in full. |
| 25 | Reading › Control panel | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Page indicator "1 / 14" complete; nothing clipped in either bar. |
| 25 | Reading › Control panel | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Page indicator complete at accessibility size; both bars intact. The Auto-Play menu shows its header and first option inside the visible container with the rest laid out below it — synthetic drags dismissed the menu rather than scrolling it, so the remaining options' reachability in landscape is unconfirmed and is called out in the summary. The dual-page menu does not appear because this session's reading direction is Vertical. |
| 26 | Reading › Reading Setting sheet | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Reached from the control panel's More menu. Every row keeps its label and value on one line, both sliders keep their end labels, and the sheet scrolls to its end. |
| 26 | Reading › Reading Setting sheet | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Rows reflow to value-under-label where the line no longer fits; nothing is clipped and both sliders keep "1.5x" and "10.0x" / "5.0x". |
| 26 | Reading › Reading Setting sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Labels wrap to three lines and values sit beside or beneath them; the slider maximum wraps to two lines but reads in full. Nothing lost. Reading Direction was read, never changed. |
| 26 | Reading › Reading Setting sheet | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Every row on one line, both sliders complete. |
| 26 | Reading › Reading Setting sheet | iPhone | landscape | AX3 (accessibility-extra-large) | pass | All labels, values and slider end labels read in full. |
| 26 | Reading › Reading Setting sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Rows reflow to value-under-label; every label, value and slider end label reads in full to the end of the sheet. |
| 27 | Reading › Live Text overlay | iPhone | portrait | XXL (extra-extra-extra-large) | n/a: no app-drawn text (system overlay) | The overlay was enabled from the control panel and inspected. Everything it draws is a transparent hit-target text view (clear text colour, zero-point font) whose only visible affordance is the system's own selection and translate UI, so there is no app-drawn string for Dynamic Type to reflow. The panel controls that switch it on are judged under screen #25. |
| 27 | Reading › Live Text overlay | iPhone | portrait | AX3 (accessibility-extra-large) | n/a: no app-drawn text (system overlay) | The overlay was enabled from the control panel and inspected. Everything it draws is a transparent hit-target text view (clear text colour, zero-point font) whose only visible affordance is the system's own selection and translate UI, so there is no app-drawn string for Dynamic Type to reflow. The panel controls that switch it on are judged under screen #25. |
| 27 | Reading › Live Text overlay | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | n/a: no app-drawn text (system overlay) | The overlay was enabled from the control panel and inspected. Everything it draws is a transparent hit-target text view (clear text colour, zero-point font) whose only visible affordance is the system's own selection and translate UI, so there is no app-drawn string for Dynamic Type to reflow. The panel controls that switch it on are judged under screen #25. |
| 27 | Reading › Live Text overlay | iPhone | landscape | XXL (extra-extra-extra-large) | n/a: no app-drawn text (system overlay) | The overlay was enabled from the control panel and inspected. Everything it draws is a transparent hit-target text view (clear text colour, zero-point font) whose only visible affordance is the system's own selection and translate UI, so there is no app-drawn string for Dynamic Type to reflow. The panel controls that switch it on are judged under screen #25. |
| 27 | Reading › Live Text overlay | iPhone | landscape | AX3 (accessibility-extra-large) | n/a: no app-drawn text (system overlay) | The overlay was enabled from the control panel and inspected. Everything it draws is a transparent hit-target text view (clear text colour, zero-point font) whose only visible affordance is the system's own selection and translate UI, so there is no app-drawn string for Dynamic Type to reflow. The panel controls that switch it on are judged under screen #25. |
| 27 | Reading › Live Text overlay | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | n/a: no app-drawn text (system overlay) | The overlay was enabled from the control panel and inspected. Everything it draws is a transparent hit-target text view (clear text colour, zero-point font) whose only visible affordance is the system's own selection and translate UI, so there is no app-drawn string for Dynamic Type to reflow. The panel controls that switch it on are judged under screen #25. |

### iPhone — Group C (#28–#42) — plan 16-06

| # | Screen | Device | Orientation | Size | Status | Finding |
|---|---|---|---|---|---|---|
| 28 | Setting root | iPhone | portrait | XXL (extra-extra-extra-large) | pass | All seven rows and their icon slots read in full; the list does not scroll and the tab bar keeps five labels. |
| 28 | Setting root | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Rows grow taller, every label still complete; the 45-pt icon slot never clips its glyph. |
| 28 | Setting root | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | All seven labels read in full on one line each; icons stay inside their 45-pt frame; nothing scrolls out of reach. |
| 28 | Setting root | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Rows read in full; the list scrolls to About. |
| 28 | Setting root | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Rows read in full; About reachable by scrolling. |
| 28 | Setting root | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Three and a half rows per screen but every label complete and About reachable; the floating tab bar overlays scrollable content only. |
| 29 | Setting › Account | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#24 | The hash cookie row's value loses about a third of the characters it shows at the default size; the numeric id and the ExHentai token still read in full. Labels wrap, rows reachable, logout confirmation complete. |
| 29 | Setting › Account | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#24 | The numeric member-id value, complete at the default size, is now ellipsised after five digits; the hash value is down to five characters and the ExHentai token to four. |
| 29 | Setting › Account | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#24 | All three cookie value fields are reduced to three or four characters plus an ellipsis; the labels wrap to four lines each. The logout confirmation itself stays complete. |
| 29 | Setting › Account | iPhone | landscape | XXL (extra-extra-extra-large) | pass | The wider row lets every cookie value render in full, including the 32-character hash; all rows reachable. |
| 29 | Setting › Account | iPhone | landscape | AX3 (accessibility-extra-large) | finding:#24 | The hash value drops from complete at XXL to roughly fourteen characters plus an ellipsis; ids and the ExHentai token still complete. |
| 29 | Setting › Account | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#24 | The hash value is down to about twelve characters; the numeric ids survive. Labels wrap, nothing is unreachable. |
| 30 | Setting › Login | iPhone | portrait | XXL (extra-extra-extra-large) | blocked: no logged-out session | The native login form is rendered only in the `!didLogin` branch of `AccountSettingView.swift` `AccountSection.body`; the Account screen of a logged-in session shows Logout in its place. Reaching it needs a logout, which D-09 forbids on this simulator. |
| 30 | Setting › Login | iPhone | portrait | AX3 (accessibility-extra-large) | blocked: no logged-out session | The native login form is rendered only in the `!didLogin` branch of `AccountSettingView.swift` `AccountSection.body`; the Account screen of a logged-in session shows Logout in its place. Reaching it needs a logout, which D-09 forbids on this simulator. |
| 30 | Setting › Login | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: no logged-out session | The native login form is rendered only in the `!didLogin` branch of `AccountSettingView.swift` `AccountSection.body`; the Account screen of a logged-in session shows Logout in its place. Reaching it needs a logout, which D-09 forbids on this simulator. |
| 30 | Setting › Login | iPhone | landscape | XXL (extra-extra-extra-large) | blocked: no logged-out session | The native login form is rendered only in the `!didLogin` branch of `AccountSettingView.swift` `AccountSection.body`; the Account screen of a logged-in session shows Logout in its place. Reaching it needs a logout, which D-09 forbids on this simulator. |
| 30 | Setting › Login | iPhone | landscape | AX3 (accessibility-extra-large) | blocked: no logged-out session | The native login form is rendered only in the `!didLogin` branch of `AccountSettingView.swift` `AccountSection.body`; the Account screen of a logged-in session shows Logout in its place. Reaching it needs a logout, which D-09 forbids on this simulator. |
| 30 | Setting › Login | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: no logged-out session | The native login form is rendered only in the `!didLogin` branch of `AccountSettingView.swift` `AccountSection.body`; the Account screen of a logged-in session shows Logout in its place. Reaching it needs a logout, which D-09 forbids on this simulator. |
| 31 | Setting › General | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Every label, the Language value, the cache size value and the analytics footer read in full; the labels-hidden toggle in its 50-pt slot is a switch with no text and never clips. |
| 31 | Setting › General | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Row labels wrap to two lines; Language value, cache size and the full analytics footer sentence all still read in full. |
| 31 | Setting › General | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Labels wrap to three or four lines and the cache size wraps onto its own second line — nothing is ellipsised, the footer renders every word, and the clear-cache confirmation shows its message and its action in full. |
| 31 | Setting › General | iPhone | landscape | XXL (extra-extra-extra-large) | pass | All rows on one line each, cache size and analytics footer complete; scrolls to the end of the footer. |
| 31 | Setting › General | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Rows still single-line, footer wraps to five lines and ends on its last word. |
| 31 | Setting › General | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Two rows per screen; every label, the Language value and the cache size read in full and the footer reaches its last word by scrolling. |
| 32 | Setting › General › Activity Logs | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Large title, search field, category chips, timestamps and every log message read in full; the Runs menu shows all its items and its selection tick. |
| 32 | Setting › General › Activity Logs | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#4, #7, #25, #26 | The category chip is cut to seven characters; the navigation large title is ellipsised; the search field renders as an empty capsule with neither glyph nor placeholder; the Runs menu stops drawing the tick beside the selected run. Log messages themselves wrap in full. |
| 32 | Setting › General › Activity Logs | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#7, #25, #26 | The chip is down to four characters plus an ellipsis and the large title is ellipsised after two words; the Runs menu still has no selection tick. The search field renders normally at this size and log messages wrap in full. |
| 32 | Setting › General › Activity Logs | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Everything single-line and complete, including the full chip and the whole message on one line. |
| 32 | Setting › General › Activity Logs | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Chip, timestamp and message all complete; search field intact. |
| 32 | Setting › General › Activity Logs | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#4, #25, #26 | The chip is ellipsised, the search field is an empty capsule and the Runs menu drops the selection tick; the large title survives in landscape because the bar uses its inline form. |
| 33 | Setting › Appearance | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Theme and Display Mode keep label and value on one line and both read in full; the privacy-mask slider keeps both eye glyphs and its footer wraps completely. |
| 33 | Setting › Appearance | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Values drop onto their own line under the label — a wrap, not a loss; the disabled Maximum Number of Tags value still reads in full and the footer renders every word. |
| 33 | Setting › Appearance | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Every label wraps to two or three lines with its value complete below it; the slider keeps both end glyphs; the App Icon picker's names wrap, its 60-pt icon slots never clip and the selection tick grows with the type. |
| 33 | Setting › Appearance | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Every row single-line with its value complete; the slider spans the wider row and keeps both glyphs; footer and Gallery section reachable. |
| 33 | Setting › Appearance | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Theme's value moves under its label; everything still complete and the bottom row is reachable. |
| 33 | Setting › Appearance | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Two rows per screen; labels and values complete, no clipping, and Display Japanese Title at the bottom is reached by scrolling. |
| 34 | Setting › Reading | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Direction, Preload Limit and Separator Height keep label and value on one line; both scale-factor rows show their current value and both slider end labels in full. |
| 34 | Setting › Reading | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Values drop under their labels and the scale-factor labels wrap to two lines; every value and both slider bounds still read in full. |
| 34 | Setting › Reading | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Labels wrap to three lines, the slider track shrinks and its upper bound wraps onto a second line — a wrap, not a truncation. No value is lost and the last row is reachable. |
| 34 | Setting › Reading | iPhone | landscape | XXL (extra-extra-extra-large) | pass | All rows single-line with their values complete; both sliders show their bounds and the last row is reachable. |
| 34 | Setting › Reading | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Rows still single-line; every value, both slider bounds and the current factors read in full. |
| 34 | Setting › Reading | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Roughly one row per screen but nothing is truncated — labels, current values and both slider bounds all complete, and the bottom row is reached by scrolling. |
| 35 | Setting › Download | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Both toggle labels wrap and read in full, the concurrency value stays beside its label, the slider keeps its full track and the four-sentence footer renders every word. |
| 35 | Setting › Download | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Labels wrap to two lines, the concurrency value drops onto its own line, and the footer is complete. |
| 35 | Setting › Download | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Labels wrap to three or four lines (with a soft hyphen), value and slider intact, and the footer renders its last word — reached by scrolling. |
| 35 | Setting › Download | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Both rows single-line with value and toggles complete; the footer is reachable and reads in full. |
| 35 | Setting › Download | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Rows single-line, footer wraps to four lines and ends on its last word. |
| 35 | Setting › Download | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | The concurrency value drops under its label and the footer runs to seven lines, all of them rendered; nothing is clipped and the last line is reached by scrolling. |
| 36 | Setting › Laboratory | iPhone | portrait | XXL (extra-extra-extra-large) | pass | The single feature cell keeps its glyph and its full name on one line; the whole screen fits with no scrolling. |
| 36 | Setting › Laboratory | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Cell grows with the type and the name still reads in full. |
| 36 | Setting › Laboratory | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | The cell's name wraps to three lines beside its glyph and reads in full; the glyph grows with the text and nothing is clipped. (The tinted/gray cell state is a round-2 Differentiate-Without-Color item, not judged here.) |
| 36 | Setting › Laboratory | iPhone | landscape | XXL (extra-extra-extra-large) | pass | The single feature cell keeps its glyph and its full name on one line; the whole screen fits with no scrolling. |
| 36 | Setting › Laboratory | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Cell grows with the type and the name still reads in full. |
| 36 | Setting › Laboratory | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | The cell keeps its name on one line even at AX5 in the wider layout; glyph and text both complete. |
| 37 | Setting › About | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Every link row, section header, copyright line and version string reads in full; the list scrolls to its last acknowledgement. |
| 37 | Setting › About | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Long names wrap with a soft hyphen and read in full; the copyright and version lines sit in the navigation bar's large-subtitle slot, which the system renders at a fixed size, so they neither grow nor lose characters. |
| 37 | Setting › About | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Names wrap to two or three lines each and every one is complete down to the last acknowledgement; nothing is ellipsised. |
| 37 | Setting › About | iPhone | landscape | XXL (extra-extra-extra-large) | pass | All rows single-line and complete; the list scrolls to its last acknowledgement. The copyright/version subtitle is absent in landscape at every size because the bar uses its inline form — an orientation effect, not a type-size one. |
| 37 | Setting › About | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Long dependency names still fit on one line; every row complete to the bottom of the list. |
| 37 | Setting › About | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Only the longest names wrap to two lines; nothing truncates and the final acknowledgement is reachable. |
| 38 | Setting › EhSetting | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#27 | The Excluded Languages column headers collide into one unbroken string and slide off their columns, so the radio grid no longer says which column is which. Everything else — profile rows, pickers, the 200-pt segmented controls, the long explanatory paragraphs and both pixel sliders — reads in full to the end of the page. |
| 38 | Setting › EhSetting | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#27 | Same column-header collision. All other rows wrap: labels take two or three lines, picker values move under their labels, slider bounds wrap rather than truncate, and the page scrolls to its last row. |
| 38 | Setting › EhSetting | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#27, #28 | Column headers still collided; additionally three consecutive Multi-Page Viewer rows overlap — a three-line label painted over the next row's label and a picker value cut by the row separator. The 200-pt segmented controls and every explanatory paragraph still read in full. |
| 38 | Setting › EhSetting | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Every native row single-line with its value complete, the 200-pt segmented controls and both sliders intact, and the Excluded Languages column headers still separated and centred over their columns. |
| 38 | Setting › EhSetting | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Labels and picker values move onto separate lines; nothing is truncated and the language-grid headers still read as three separate words. |
| 38 | Setting › EhSetting | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#27 | The Excluded Languages headers collide into one overlapping string. Everything else survives: the Multi-Page Viewer rows that overlap in portrait are clean here, and the 200-pt segmented controls read in full. |
| 39 | Filters sheet | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#29 | Two of the nine category cells are already ellipsised; the host segmented control, Reset Filters, every advanced toggle row and the custom-filter rows read in full to the bottom of the sheet. |
| 39 | Filters sheet | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#29 | Eight of the nine category names are cut to three or four letters. Everything else on the sheet wraps and stays complete. |
| 39 | Filters sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#29 | Every category cell is one or two letters plus an ellipsis. The rest of the sheet is fine — advanced rows wrap to three lines, the reset confirmation shows its message and action in full, and the sheet scrolls to its last row. |
| 39 | Filters sheet | iPhone | landscape | XXL (extra-extra-extra-large) | finding:#29 | The grid relays out six per row but the cells keep their width, so the same two names are ellipsised; the rest of the sheet is complete. |
| 39 | Filters sheet | iPhone | landscape | AX3 (accessibility-extra-large) | finding:#29 | Eight of nine category names cut; other rows single-line and complete. |
| 39 | Filters sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#29 | All nine category cells reduced to one or two letters; the advanced and custom-filter rows still read in full on one line each. |
| 40 | Quick Search sheet | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#30 | The saved word and its content both read in full in the normal row, but Edit mode narrows the row between its delete and reorder controls and cuts the saved name to `Dynamic Type Sweep…`; the empty state, editor labels and entered values otherwise read in full. |
| 40 | Quick Search sheet | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#30 | The normal row already cuts the saved name to `Dynamic Type Sw…`; Edit mode also cuts the content after a few characters. The sheet and editor remain reachable and their other labels wrap in full. |
| 40 | Quick Search sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#30 | The normal row reduces the saved name and content to ellipsised fragments; Edit mode loses still more of both lines. The throwaway item was deleted after the walk and the original empty state was verified. |
| 40 | Quick Search sheet | iPhone | landscape | XXL (extra-extra-extra-large) | pass | The saved name and content read in full in both normal and Edit modes; the empty state and editor are also complete. |
| 40 | Quick Search sheet | iPhone | landscape | AX3 (accessibility-extra-large) | pass | The wider row keeps the full saved name and content in normal and Edit modes; controls remain reachable. |
| 40 | Quick Search sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#30 | The saved name is cut in both normal and Edit modes while the content stays complete; the editor itself remains usable. |
| 41 | Date Seek picker | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Month header, weekday row, every day number, the explanatory sentence and both Older / Newer buttons read in full. |
| 41 | Date Seek picker | iPhone | portrait | AX3 (accessibility-extra-large) | pass | The graphical calendar keeps every date legible; the sentence wraps to two lines and both navigation buttons remain fully visible. |
| 41 | Date Seek picker | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Weekday abbreviations and day numbers remain distinct, the sentence wraps in full, and scrolling reaches both complete navigation buttons. |
| 41 | Date Seek picker | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Month header, weekday row, every day number, the explanatory sentence and both Older / Newer buttons read in full. |
| 41 | Date Seek picker | iPhone | landscape | AX3 (accessibility-extra-large) | pass | The graphical date picker caps its own type scale, so the calendar is unchanged; the sentence and buttons below it grow and stay complete. |
| 41 | Date Seek picker | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Weekday abbreviations sit shoulder to shoulder but none is cut or overlapped; every day number, the whole sentence and both buttons render, and the selected day keeps its highlight. |
| 42 | Error surface | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#31 | The error sheet scrolls through its complete description, solution, context and environment, but the toast keeps its title and ellipsises the one-line subtitle after `This link wasn't recognized…`. |
| 42 | Error surface | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#31 | The error sheet reflows every field and remains scrollable to the operating-system row; the toast subtitle is cut to `This link was…`. |
| 42 | Error surface | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#31 | The error sheet grows substantially but every section is reachable and complete; the toast subtitle is reduced to `This link…`. |
| 42 | Error surface | iPhone | landscape | XXL (extra-extra-extra-large) | pass | The toast title and complete unsupported-link subtitle fit on one line, and the error sheet scrolls through every complete field. |
| 42 | Error surface | iPhone | landscape | AX3 (accessibility-extra-large) | finding:#31 | The error sheet remains complete to its Environment section, but the toast subtitle ends after `EhPa…`. |
| 42 | Error surface | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#31 | The error sheet remains complete and scrollable; the toast subtitle is ellipsised after `This link wasn't recognized…`. |

### iPad — Group A (#1–#13) — plan 16-07

| # | Screen | Device | Orientation | Size | Status | Finding |
|---|---|---|---|---|---|---|
| 1 | Tab bar shell | iPad | portrait | XXL (extra-extra-extra-large) | pass | The system overflow keeps the fifth tab reachable while every visible tab label remains complete. |
| 1 | Tab bar shell | iPad | portrait | AX3 (accessibility-extra-large) | pass | The tab bar keeps its system-capped text and overflow affordance; no label clips. |
| 1 | Tab bar shell | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | The tab bar keeps its system-capped text and overflow affordance; every tab remains reachable. |
| 1 | Tab bar shell | iPad | landscape | XXL (extra-extra-extra-large) | pass | All five tab labels and glyphs render in full. |
| 1 | Tab bar shell | iPad | landscape | AX3 (accessibility-extra-large) | pass | All five tab labels and glyphs render in full. |
| 1 | Tab bar shell | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | All five tab labels and glyphs render in full. |
| 2 | Home root | iPad | portrait | XXL (extra-extra-extra-large) | finding:#1, #3 | Hero title loses its tail; ranking titles that read in full at the baseline now ellipsise. Sections and tab shell remain reachable. |
| 2 | Home root | iPad | portrait | AX3 (accessibility-extra-large) | finding:#1, #3 | Hero title collapses to one ellipsised line; ranking titles and uploaders surrender more text. |
| 2 | Home root | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#1, #3 | Hero title keeps only its opening words; ranking titles and uploaders are heavily ellipsised. |
| 2 | Home root | iPad | landscape | XXL (extra-extra-extra-large) | finding:#1 | The wider hero still ellipsises its title; ranking titles and uploaders remain complete. |
| 2 | Home root | iPad | landscape | AX3 (accessibility-extra-large) | finding:#1, #3 | Hero and ranking titles ellipsise; ranking uploaders remain visible. |
| 2 | Home root | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#1, #3 | Hero title and ranking titles lose still more text; several uploader lines ellipsise. |
| 3 | Home › Frontpage | iPad | portrait | XXL (extra-extra-extra-large) | pass | Filter, title, uploader, category, page count and timestamp all read in full. |
| 3 | Home › Frontpage | iPad | portrait | AX3 (accessibility-extra-large) | finding:#4, #32 | Filter contents disappear; a long category badge grows over the timestamp beside it. |
| 3 | Home › Frontpage | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#5, #32 | Long titles lose their tails; category badges and timestamps overlap. The filter contents return. |
| 3 | Home › Frontpage | iPad | landscape | XXL (extra-extra-extra-large) | pass | All row values and the filter field read in full. |
| 3 | Home › Frontpage | iPad | landscape | AX3 (accessibility-extra-large) | pass | All row values and the filter field remain complete. |
| 3 | Home › Frontpage | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#4 | The filter renders as an empty capsule; the wider rows keep their values complete. |
| 4 | Home › Popular | iPad | portrait | XXL (extra-extra-extra-large) | pass | Filter and every row value read in full. |
| 4 | Home › Popular | iPad | portrait | AX3 (accessibility-extra-large) | finding:#4 | The filter renders as an empty capsule; row titles and metadata remain complete. |
| 4 | Home › Popular | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Filter contents return and the regular-width rows reflow without losing text. |
| 4 | Home › Popular | iPad | landscape | XXL (extra-extra-extra-large) | pass | Filter and every row value read in full. |
| 4 | Home › Popular | iPad | landscape | AX3 (accessibility-extra-large) | finding:#4 | The filter contents disappear; row values remain complete. |
| 4 | Home › Popular | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#4 | The filter remains an empty capsule; the rows themselves preserve their contents. |
| 5 | Home › Watched | iPad | portrait | XXL (extra-extra-extra-large) | blocked: no iPad session | Login-gated; `IPAD_LOGIN=none`, so no credentials were entered. |
| 5 | Home › Watched | iPad | portrait | AX3 (accessibility-extra-large) | blocked: no iPad session | Login-gated; `IPAD_LOGIN=none`, so no credentials were entered. |
| 5 | Home › Watched | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Login-gated; `IPAD_LOGIN=none`, so no credentials were entered. |
| 5 | Home › Watched | iPad | landscape | XXL (extra-extra-extra-large) | blocked: no iPad session | Login-gated; `IPAD_LOGIN=none`, so no credentials were entered. |
| 5 | Home › Watched | iPad | landscape | AX3 (accessibility-extra-large) | blocked: no iPad session | Login-gated; `IPAD_LOGIN=none`, so no credentials were entered. |
| 5 | Home › Watched | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Login-gated; `IPAD_LOGIN=none`, so no credentials were entered. |
| 6 | Home › History | iPad | portrait | XXL (extra-extra-extra-large) | pass | Filter, preservation notice, and gallery-row values remain readable. |
| 6 | Home › History | iPad | portrait | AX3 (accessibility-extra-large) | pass | The notice stays on one line and every row value remains independently readable. |
| 6 | Home › History | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | The notice wraps cleanly; titles, ratings, categories, counts, and timestamps remain readable. |
| 6 | Home › History | iPad | landscape | XXL (extra-extra-extra-large) | pass | Filter, notice, and gallery-row values remain readable. |
| 6 | Home › History | iPad | landscape | AX3 (accessibility-extra-large) | pass | Rows reflow without clipping or overlapping their metadata. |
| 6 | Home › History | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | The wide row preserves all values at the largest sampled size. |
| 7 | Home › Toplists | iPad | portrait | XXL (extra-extra-extra-large) | pass | Filter and Toplists rows preserve their titles and metadata. |
| 7 | Home › Toplists | iPad | portrait | AX3 (accessibility-extra-large) | finding:#4 | The filter contents disappear; the gallery rows reflow without losing values. |
| 7 | Home › Toplists | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Filter and every sampled row value remain visible at the largest size. |
| 7 | Home › Toplists | iPad | landscape | XXL (extra-extra-extra-large) | pass | Filter and Toplists rows preserve their titles and metadata. |
| 7 | Home › Toplists | iPad | landscape | AX3 (accessibility-extra-large) | finding:#4 | The filter is an empty capsule; row values remain readable. |
| 7 | Home › Toplists | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#4 | The filter remains empty while the wide rows preserve their values. |
| 8 | Favorites root | iPad | portrait | XXL (extra-extra-extra-large) | blocked: no iPad session | Login-gated; `IPAD_LOGIN=none`, so no credentials were entered. |
| 8 | Favorites root | iPad | portrait | AX3 (accessibility-extra-large) | blocked: no iPad session | Login-gated; `IPAD_LOGIN=none`, so no credentials were entered. |
| 8 | Favorites root | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Login-gated; `IPAD_LOGIN=none`, so no credentials were entered. |
| 8 | Favorites root | iPad | landscape | XXL (extra-extra-extra-large) | blocked: no iPad session | Login-gated; `IPAD_LOGIN=none`, so no credentials were entered. |
| 8 | Favorites root | iPad | landscape | AX3 (accessibility-extra-large) | blocked: no iPad session | Login-gated; `IPAD_LOGIN=none`, so no credentials were entered. |
| 8 | Favorites root | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Login-gated; `IPAD_LOGIN=none`, so no credentials were entered. |
| 9 | Search root | iPad | portrait | XXL (extra-extra-extra-large) | pass | All three Recently Seen cards keep their covers, titles, and ratings readable. |
| 9 | Search root | iPad | portrait | AX3 (accessibility-extra-large) | finding:#10 | Fixed-height cards clip the tops of their titles and crowd their star rows. |
| 9 | Search root | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#10 | Titles largely disappear while the covers and uploader lines overflow their cells. |
| 9 | Search root | iPad | landscape | XXL (extra-extra-extra-large) | pass | The wider Recently Seen strip preserves every sampled card value. |
| 9 | Search root | iPad | landscape | AX3 (accessibility-extra-large) | finding:#10 | Fixed-height cells clip their title tops even in the wider layout. |
| 9 | Search root | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#10 | Card contents overflow vertically and the title is no longer independently readable. |
| 10 | Search results | iPad | portrait | XXL (extra-extra-extra-large) | pass | The query, result titles, uploader, category, count, and timestamp remain readable. |
| 10 | Search results | iPad | portrait | AX3 (accessibility-extra-large) | finding:#4 | The search/filter capsule is empty; the result rows themselves remain readable. |
| 10 | Search results | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#4 | The capsule still loses its query text while the result rows reflow successfully. |
| 10 | Search results | iPad | landscape | XXL (extra-extra-extra-large) | pass | Query and all sampled result-row values remain readable. |
| 10 | Search results | iPad | landscape | AX3 (accessibility-extra-large) | pass | The query stays visible and the wide rows preserve all values. |
| 10 | Search results | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#4 | The query capsule becomes empty; result rows remain readable. |
| 11 | Downloads root | iPad | portrait | XXL (extra-extra-extra-large) | pass | The preserved eight-page download exposes its title, uploader, language, rating, category, progress, and timestamp. |
| 11 | Downloads root | iPad | portrait | AX3 (accessibility-extra-large) | pass | The download row grows and keeps every sampled value independently readable. |
| 11 | Downloads root | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Title, metadata, 8/8 progress, and timestamp remain readable at the largest size. |
| 11 | Downloads root | iPad | landscape | XXL (extra-extra-extra-large) | pass | The wide download row preserves all values. |
| 11 | Downloads root | iPad | landscape | AX3 (accessibility-extra-large) | pass | All download metadata remains readable without overlap. |
| 11 | Downloads root | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | The row reflows cleanly and keeps its complete progress and timestamp. |
| 12 | Downloads › Inspector sheet | iPad | portrait | XXL (extra-extra-extra-large) | pass | Header, gallery metadata, status sections, and actions remain readable. |
| 12 | Downloads › Inspector sheet | iPad | portrait | AX3 (accessibility-extra-large) | pass | Wrapped title, metadata, status rows, and action labels remain complete. |
| 12 | Downloads › Inspector sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#6 | The Inspector timestamp is truncated after the date; other metadata and actions reflow. |
| 12 | Downloads › Inspector sheet | iPad | landscape | XXL (extra-extra-extra-large) | pass | Header, metadata, status sections, and actions remain readable. |
| 12 | Downloads › Inspector sheet | iPad | landscape | AX3 (accessibility-extra-large) | pass | The timestamp stays complete and all action labels remain readable. |
| 12 | Downloads › Inspector sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#6 | The timestamp loses its time after the date while the title and actions remain complete. |
| 13 | Downloads › Move-to-folder / FolderManager | iPad | portrait | XXL (extra-extra-extra-large) | blocked: no iPad session | Login-gated; `IPAD_LOGIN=none`, so the folder-management route was not exercised. |
| 13 | Downloads › Move-to-folder / FolderManager | iPad | portrait | AX3 (accessibility-extra-large) | blocked: no iPad session | Login-gated; `IPAD_LOGIN=none`, so the folder-management route was not exercised. |
| 13 | Downloads › Move-to-folder / FolderManager | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Login-gated; `IPAD_LOGIN=none`, so the folder-management route was not exercised. |
| 13 | Downloads › Move-to-folder / FolderManager | iPad | landscape | XXL (extra-extra-extra-large) | blocked: no iPad session | Login-gated; `IPAD_LOGIN=none`, so the folder-management route was not exercised. |
| 13 | Downloads › Move-to-folder / FolderManager | iPad | landscape | AX3 (accessibility-extra-large) | blocked: no iPad session | Login-gated; `IPAD_LOGIN=none`, so the folder-management route was not exercised. |
| 13 | Downloads › Move-to-folder / FolderManager | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Login-gated; `IPAD_LOGIN=none`, so the folder-management route was not exercised. |

### iPad — Group B (#14–#27) — plan 16-08

| # | Screen | Device | Orientation | Size | Status | Finding |
|---|---|---|---|---|---|---|
| 14 | Gallery Detail | iPad | portrait | XXL (extra-extra-extra-large) | blocked: no iPad session | Live Detail is login-gated; Favorites confirms `IPAD_LOGIN=none`, so no credential was entered and no iPhone verdict was inferred. |
| 14 | Gallery Detail | iPad | portrait | AX3 (accessibility-extra-large) | blocked: no iPad session | Live Detail is login-gated; Favorites confirms `IPAD_LOGIN=none`, so no credential was entered and no iPhone verdict was inferred. |
| 14 | Gallery Detail | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Live Detail is login-gated; Favorites confirms `IPAD_LOGIN=none`, so no credential was entered and no iPhone verdict was inferred. |
| 14 | Gallery Detail | iPad | landscape | XXL (extra-extra-extra-large) | blocked: no iPad session | Live Detail is login-gated; Favorites confirms `IPAD_LOGIN=none`, so no credential was entered and no iPhone verdict was inferred. |
| 14 | Gallery Detail | iPad | landscape | AX3 (accessibility-extra-large) | blocked: no iPad session | Live Detail is login-gated; Favorites confirms `IPAD_LOGIN=none`, so no credential was entered and no iPhone verdict was inferred. |
| 14 | Gallery Detail | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Live Detail is login-gated; Favorites confirms `IPAD_LOGIN=none`, so no credential was entered and no iPhone verdict was inferred. |
| 15 | Detail › Previews | iPad | portrait | XXL (extra-extra-extra-large) | blocked: no iPad session | The Previews route requires the unavailable live Detail session; no credential was entered. |
| 15 | Detail › Previews | iPad | portrait | AX3 (accessibility-extra-large) | blocked: no iPad session | The Previews route requires the unavailable live Detail session; no credential was entered. |
| 15 | Detail › Previews | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | The Previews route requires the unavailable live Detail session; no credential was entered. |
| 15 | Detail › Previews | iPad | landscape | XXL (extra-extra-extra-large) | blocked: no iPad session | The Previews route requires the unavailable live Detail session; no credential was entered. |
| 15 | Detail › Previews | iPad | landscape | AX3 (accessibility-extra-large) | blocked: no iPad session | The Previews route requires the unavailable live Detail session; no credential was entered. |
| 15 | Detail › Previews | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | The Previews route requires the unavailable live Detail session; no credential was entered. |
| 16 | Detail › Comments | iPad | portrait | XXL (extra-extra-extra-large) | blocked: no iPad session | Live Comments is login-gated; no credential was entered, and no post or vote surface was opened. |
| 16 | Detail › Comments | iPad | portrait | AX3 (accessibility-extra-large) | blocked: no iPad session | Live Comments is login-gated; no credential was entered, and no post or vote surface was opened. |
| 16 | Detail › Comments | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Live Comments is login-gated; no credential was entered, and no post or vote surface was opened. |
| 16 | Detail › Comments | iPad | landscape | XXL (extra-extra-extra-large) | blocked: no iPad session | Live Comments is login-gated; no credential was entered, and no post or vote surface was opened. |
| 16 | Detail › Comments | iPad | landscape | AX3 (accessibility-extra-large) | blocked: no iPad session | Live Comments is login-gated; no credential was entered, and no post or vote surface was opened. |
| 16 | Detail › Comments | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Live Comments is login-gated; no credential was entered, and no post or vote surface was opened. |
| 17 | Detail › Detail Search | iPad | portrait | XXL (extra-extra-extra-large) | blocked: no iPad session | The Detail Search route requires the unavailable live Detail session; no credential was entered. |
| 17 | Detail › Detail Search | iPad | portrait | AX3 (accessibility-extra-large) | blocked: no iPad session | The Detail Search route requires the unavailable live Detail session; no credential was entered. |
| 17 | Detail › Detail Search | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | The Detail Search route requires the unavailable live Detail session; no credential was entered. |
| 17 | Detail › Detail Search | iPad | landscape | XXL (extra-extra-extra-large) | blocked: no iPad session | The Detail Search route requires the unavailable live Detail session; no credential was entered. |
| 17 | Detail › Detail Search | iPad | landscape | AX3 (accessibility-extra-large) | blocked: no iPad session | The Detail Search route requires the unavailable live Detail session; no credential was entered. |
| 17 | Detail › Detail Search | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | The Detail Search route requires the unavailable live Detail session; no credential was entered. |
| 18 | Detail › Gallery Infos | iPad | portrait | XXL (extra-extra-extra-large) | blocked: no iPad session | Gallery Infos requires the unavailable live Detail session; no credential was entered. |
| 18 | Detail › Gallery Infos | iPad | portrait | AX3 (accessibility-extra-large) | blocked: no iPad session | Gallery Infos requires the unavailable live Detail session; no credential was entered. |
| 18 | Detail › Gallery Infos | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Gallery Infos requires the unavailable live Detail session; no credential was entered. |
| 18 | Detail › Gallery Infos | iPad | landscape | XXL (extra-extra-extra-large) | blocked: no iPad session | Gallery Infos requires the unavailable live Detail session; no credential was entered. |
| 18 | Detail › Gallery Infos | iPad | landscape | AX3 (accessibility-extra-large) | blocked: no iPad session | Gallery Infos requires the unavailable live Detail session; no credential was entered. |
| 18 | Detail › Gallery Infos | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Gallery Infos requires the unavailable live Detail session; no credential was entered. |
| 19 | Detail › Archives sheet | iPad | portrait | XXL (extra-extra-extra-large) | blocked: no iPad session | Archives is login-gated; no credential was entered and nothing was purchased. |
| 19 | Detail › Archives sheet | iPad | portrait | AX3 (accessibility-extra-large) | blocked: no iPad session | Archives is login-gated; no credential was entered and nothing was purchased. |
| 19 | Detail › Archives sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Archives is login-gated; no credential was entered and nothing was purchased. |
| 19 | Detail › Archives sheet | iPad | landscape | XXL (extra-extra-extra-large) | blocked: no iPad session | Archives is login-gated; no credential was entered and nothing was purchased. |
| 19 | Detail › Archives sheet | iPad | landscape | AX3 (accessibility-extra-large) | blocked: no iPad session | Archives is login-gated; no credential was entered and nothing was purchased. |
| 19 | Detail › Archives sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Archives is login-gated; no credential was entered and nothing was purchased. |
| 20 | Detail › Torrents sheet | iPad | portrait | XXL (extra-extra-extra-large) | blocked: no iPad session | Torrents is login-gated; no credential was entered and no torrent action or share sheet was opened. |
| 20 | Detail › Torrents sheet | iPad | portrait | AX3 (accessibility-extra-large) | blocked: no iPad session | Torrents is login-gated; no credential was entered and no torrent action or share sheet was opened. |
| 20 | Detail › Torrents sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Torrents is login-gated; no credential was entered and no torrent action or share sheet was opened. |
| 20 | Detail › Torrents sheet | iPad | landscape | XXL (extra-extra-extra-large) | blocked: no iPad session | Torrents is login-gated; no credential was entered and no torrent action or share sheet was opened. |
| 20 | Detail › Torrents sheet | iPad | landscape | AX3 (accessibility-extra-large) | blocked: no iPad session | Torrents is login-gated; no credential was entered and no torrent action or share sheet was opened. |
| 20 | Detail › Torrents sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Torrents is login-gated; no credential was entered and no torrent action or share sheet was opened. |
| 21 | Detail › Tag Detail sheet | iPad | portrait | XXL (extra-extra-extra-large) | blocked: unreachable in an English session | The entry point requires a live Detail tag with a non-empty translated description; English descriptions are empty, and the unavailable iPad session also prevents opening live Detail. |
| 21 | Detail › Tag Detail sheet | iPad | portrait | AX3 (accessibility-extra-large) | blocked: unreachable in an English session | The entry point requires a live Detail tag with a non-empty translated description; English descriptions are empty, and the unavailable iPad session also prevents opening live Detail. |
| 21 | Detail › Tag Detail sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: unreachable in an English session | The entry point requires a live Detail tag with a non-empty translated description; English descriptions are empty, and the unavailable iPad session also prevents opening live Detail. |
| 21 | Detail › Tag Detail sheet | iPad | landscape | XXL (extra-extra-extra-large) | blocked: unreachable in an English session | The entry point requires a live Detail tag with a non-empty translated description; English descriptions are empty, and the unavailable iPad session also prevents opening live Detail. |
| 21 | Detail › Tag Detail sheet | iPad | landscape | AX3 (accessibility-extra-large) | blocked: unreachable in an English session | The entry point requires a live Detail tag with a non-empty translated description; English descriptions are empty, and the unavailable iPad session also prevents opening live Detail. |
| 21 | Detail › Tag Detail sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: unreachable in an English session | The entry point requires a live Detail tag with a non-empty translated description; English descriptions are empty, and the unavailable iPad session also prevents opening live Detail. |
| 22 | Detail › NewDawn sheet | iPad | portrait | XXL (extra-extra-extra-large) | blocked: greeting not presented this session | The server-issued greeting did not appear when the app was launched for this session and cannot be summoned. |
| 22 | Detail › NewDawn sheet | iPad | portrait | AX3 (accessibility-extra-large) | blocked: greeting not presented this session | The server-issued greeting did not appear when the app was launched for this session and cannot be summoned. |
| 22 | Detail › NewDawn sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: greeting not presented this session | The server-issued greeting did not appear when the app was launched for this session and cannot be summoned. |
| 22 | Detail › NewDawn sheet | iPad | landscape | XXL (extra-extra-extra-large) | blocked: greeting not presented this session | The server-issued greeting did not appear when the app was launched for this session and cannot be summoned. |
| 22 | Detail › NewDawn sheet | iPad | landscape | AX3 (accessibility-extra-large) | blocked: greeting not presented this session | The server-issued greeting did not appear when the app was launched for this session and cannot be summoned. |
| 22 | Detail › NewDawn sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: greeting not presented this session | The server-issued greeting did not appear when the app was launched for this session and cannot be summoned. |
| 23 | Detail › download confirmation dialogs | iPad | portrait | XXL (extra-extra-extra-large) | blocked: no iPad session | The live Detail download route is unavailable without a session; no dialog was opened and the preserved download was untouched. |
| 23 | Detail › download confirmation dialogs | iPad | portrait | AX3 (accessibility-extra-large) | blocked: no iPad session | The live Detail download route is unavailable without a session; no dialog was opened and the preserved download was untouched. |
| 23 | Detail › download confirmation dialogs | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | The live Detail download route is unavailable without a session; no dialog was opened and the preserved download was untouched. |
| 23 | Detail › download confirmation dialogs | iPad | landscape | XXL (extra-extra-extra-large) | blocked: no iPad session | The live Detail download route is unavailable without a session; no dialog was opened and the preserved download was untouched. |
| 23 | Detail › download confirmation dialogs | iPad | landscape | AX3 (accessibility-extra-large) | blocked: no iPad session | The live Detail download route is unavailable without a session; no dialog was opened and the preserved download was untouched. |
| 23 | Detail › download confirmation dialogs | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | The live Detail download route is unavailable without a session; no dialog was opened and the preserved download was untouched. |
| 24 | Reading | iPad | portrait | XXL (extra-extra-extra-large) | blocked: no iPad session | Live Reading is login-gated; no credential was entered and the preserved download was not opened or changed. |
| 24 | Reading | iPad | portrait | AX3 (accessibility-extra-large) | blocked: no iPad session | Live Reading is login-gated; no credential was entered and the preserved download was not opened or changed. |
| 24 | Reading | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Live Reading is login-gated; no credential was entered and the preserved download was not opened or changed. |
| 24 | Reading | iPad | landscape | XXL (extra-extra-extra-large) | blocked: no iPad session | Live Reading is login-gated; no credential was entered and the preserved download was not opened or changed. |
| 24 | Reading | iPad | landscape | AX3 (accessibility-extra-large) | blocked: no iPad session | Live Reading is login-gated; no credential was entered and the preserved download was not opened or changed. |
| 24 | Reading | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Live Reading is login-gated; no credential was entered and the preserved download was not opened or changed. |
| 25 | Reading › Control panel | iPad | portrait | XXL (extra-extra-extra-large) | blocked: no iPad session | The regular-width control panel requires the unavailable live Reading route; no iPhone verdict was inferred. |
| 25 | Reading › Control panel | iPad | portrait | AX3 (accessibility-extra-large) | blocked: no iPad session | The regular-width control panel requires the unavailable live Reading route; no iPhone verdict was inferred. |
| 25 | Reading › Control panel | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | The regular-width control panel requires the unavailable live Reading route; no iPhone verdict was inferred. |
| 25 | Reading › Control panel | iPad | landscape | XXL (extra-extra-extra-large) | blocked: no iPad session | The regular-width control panel requires the unavailable live Reading route; no iPhone verdict was inferred. |
| 25 | Reading › Control panel | iPad | landscape | AX3 (accessibility-extra-large) | blocked: no iPad session | The regular-width control panel requires the unavailable live Reading route; no iPhone verdict was inferred. |
| 25 | Reading › Control panel | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | The regular-width control panel requires the unavailable live Reading route; no iPhone verdict was inferred. |
| 26 | Reading › Reading Setting sheet | iPad | portrait | XXL (extra-extra-extra-large) | blocked: no iPad session | The sheet itself is not account-gated, but its only Group-B entry is the unavailable live Reading control panel. |
| 26 | Reading › Reading Setting sheet | iPad | portrait | AX3 (accessibility-extra-large) | blocked: no iPad session | The sheet itself is not account-gated, but its only Group-B entry is the unavailable live Reading control panel. |
| 26 | Reading › Reading Setting sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | The sheet itself is not account-gated, but its only Group-B entry is the unavailable live Reading control panel. |
| 26 | Reading › Reading Setting sheet | iPad | landscape | XXL (extra-extra-extra-large) | blocked: no iPad session | The sheet itself is not account-gated, but its only Group-B entry is the unavailable live Reading control panel. |
| 26 | Reading › Reading Setting sheet | iPad | landscape | AX3 (accessibility-extra-large) | blocked: no iPad session | The sheet itself is not account-gated, but its only Group-B entry is the unavailable live Reading control panel. |
| 26 | Reading › Reading Setting sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | The sheet itself is not account-gated, but its only Group-B entry is the unavailable live Reading control panel. |
| 27 | Reading › Live Text overlay | iPad | portrait | XXL (extra-extra-extra-large) | blocked: no iPad session | Live Text is reached from the unavailable live Reading control panel; no overlay or system share UI was opened. |
| 27 | Reading › Live Text overlay | iPad | portrait | AX3 (accessibility-extra-large) | blocked: no iPad session | Live Text is reached from the unavailable live Reading control panel; no overlay or system share UI was opened. |
| 27 | Reading › Live Text overlay | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Live Text is reached from the unavailable live Reading control panel; no overlay or system share UI was opened. |
| 27 | Reading › Live Text overlay | iPad | landscape | XXL (extra-extra-extra-large) | blocked: no iPad session | Live Text is reached from the unavailable live Reading control panel; no overlay or system share UI was opened. |
| 27 | Reading › Live Text overlay | iPad | landscape | AX3 (accessibility-extra-large) | blocked: no iPad session | Live Text is reached from the unavailable live Reading control panel; no overlay or system share UI was opened. |
| 27 | Reading › Live Text overlay | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: no iPad session | Live Text is reached from the unavailable live Reading control panel; no overlay or system share UI was opened. |

### iPad — Group C (#28–#42) — plan 16-09

| # | Screen | Device | Orientation | Size | Status | Finding |
|---|---|---|---|---|---|---|
| 28 | Setting root | iPad | portrait | XXL (extra-extra-extra-large) | pass | The modal title and all seven icon rows read in full; the last row is reachable and the modal chrome stays clear. |
| 28 | Setting root | iPad | portrait | AX3 (accessibility-extra-large) | pass | Rows grow with their labels, icons remain inside their slots, and the list scrolls through About. |
| 28 | Setting root | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Every row label remains complete and reachable; the modal back/dismiss affordance and title stay unobscured. |
| 28 | Setting root | iPad | landscape | XXL (extra-extra-extra-large) | pass | All seven rows read in full inside the centered modal. |
| 28 | Setting root | iPad | landscape | AX3 (accessibility-extra-large) | pass | Row labels and icons remain complete; About is reached by scrolling. |
| 28 | Setting root | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | The compact-height modal shows fewer rows at once but all seven remain complete and reachable. |
| 29 | Setting › Account | iPad | portrait | XXL (extra-extra-extra-large) | pass | The logged-out state shows the Login row and three cookie rows whose values are all `None`; labels and values read in full. |
| 29 | Setting › Account | iPad | portrait | AX3 (accessibility-extra-large) | pass | Cookie labels wrap without clipping and every `None` value remains visible; the logged-out state has no Logout confirmation to invoke. |
| 29 | Setting › Account | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Long cookie labels reflow to several lines while their `None` values and the Login row remain complete. |
| 29 | Setting › Account | iPad | landscape | XXL (extra-extra-extra-large) | pass | Login and all logged-out cookie rows are complete in the modal. |
| 29 | Setting › Account | iPad | landscape | AX3 (accessibility-extra-large) | pass | Labels and `None` values remain readable and every row is reachable. |
| 29 | Setting › Account | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Rows reflow and scroll without information loss; no credential or logout action was available or attempted. |
| 30 | Setting › Login | iPad | portrait | XXL (extra-extra-extra-large) | pass | Login title, both empty native fields and the submit glyph remain distinct; no credential was entered or submitted. |
| 30 | Setting › Login | iPad | portrait | AX3 (accessibility-extra-large) | pass | Both field labels, placeholders and the disabled submit control read cleanly in the modal. |
| 30 | Setting › Login | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#33 | The enlarged Login heading is painted through the Username label; the native fields remain reachable but the heading and first label cannot be read independently. |
| 30 | Setting › Login | iPad | landscape | XXL (extra-extra-extra-large) | pass | The native form has ample width and every label, field and toolbar glyph is complete. |
| 30 | Setting › Login | iPad | landscape | AX3 (accessibility-extra-large) | pass | Username and Password remain separate from the title and the disabled submit control stays visible. |
| 30 | Setting › Login | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#33 | The Login heading overlaps the Username label in the compact-height modal just as it does in portrait. |
| 31 | Setting › General | iPad | portrait | XXL (extra-extra-extra-large) | pass | Language, translation, cache and analytics rows read in full; the footer reaches its last word. |
| 31 | Setting › General | iPad | portrait | AX3 (accessibility-extra-large) | pass | Labels and values wrap without loss and all controls remain reachable. |
| 31 | Setting › General | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Every row and the full analytics footer are reachable; the clear-cache confirmation text and action are complete and the popover was cancelled outside. |
| 31 | Setting › General | iPad | landscape | XXL (extra-extra-extra-large) | pass | Rows, values and footer remain complete inside the centered modal. |
| 31 | Setting › General | iPad | landscape | AX3 (accessibility-extra-large) | pass | Labels wrap cleanly and the bottom of the footer remains reachable. |
| 31 | Setting › General | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | The modal scrolls through every enlarged row and the footer without clipping; no setting or cache state was changed. |
| 32 | Setting › General › Activity Logs | iPad | portrait | XXL (extra-extra-extra-large) | pass | Title, search field, timestamps, category chips and log messages render completely. |
| 32 | Setting › General › Activity Logs | iPad | portrait | AX3 (accessibility-extra-large) | finding:#25 | The category chip is ellipsised while the search field, title, timestamp and wrapped log message remain complete. |
| 32 | Setting › General › Activity Logs | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#4, #25, #26 | The search control is an empty capsule, category chips are ellipsised and the Runs menu omits its visible selection tick. The More Logs picker still shows its tick and complete labels. |
| 32 | Setting › General › Activity Logs | iPad | landscape | XXL (extra-extra-extra-large) | pass | Search, title, category and log contents are complete; the list scrolls through the available run. |
| 32 | Setting › General › Activity Logs | iPad | landscape | AX3 (accessibility-extra-large) | finding:#25 | Search and title remain intact, but the category pill loses the end of `DownloadCoordinator`. |
| 32 | Setting › General › Activity Logs | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#4, #25 | The search capsule loses both glyph and placeholder and category chips are ellipsised; timestamps and messages reflow in full. |
| 33 | Setting › Appearance | iPad | portrait | XXL (extra-extra-extra-large) | pass | Theme, privacy mask, list and gallery controls read in full and the footer scrolls cleanly. |
| 33 | Setting › Appearance | iPad | portrait | AX3 (accessibility-extra-large) | pass | Labels and values reflow without clipping; both privacy-mask end glyphs and all bottom rows remain reachable. |
| 33 | Setting › Appearance | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Every label and value remains complete; App Icon names wrap in the picker, its 60-pt icon slots stay intact and the selected icon tick remains visible. |
| 33 | Setting › Appearance | iPad | landscape | XXL (extra-extra-extra-large) | pass | Controls, values, slider glyphs, footer and Gallery section are complete. |
| 33 | Setting › Appearance | iPad | landscape | AX3 (accessibility-extra-large) | pass | Values move under labels where needed; no text or control is lost and the bottom row is reachable. |
| 33 | Setting › Appearance | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Enlarged rows scroll through the compact-height modal with complete labels, values and slider endpoints. |
| 34 | Setting › Reading | iPad | portrait | XXL (extra-extra-extra-large) | pass | Direction, preload, separator and both scale-factor controls read in full. |
| 34 | Setting › Reading | iPad | portrait | AX3 (accessibility-extra-large) | pass | Labels and values reflow while both sliders retain their current values and end bounds. |
| 34 | Setting › Reading | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Every enlarged label, picker value, scale value and slider bound remains complete and reachable. |
| 34 | Setting › Reading | iPad | landscape | XXL (extra-extra-extra-large) | pass | All controls and values fit cleanly in the modal. |
| 34 | Setting › Reading | iPad | landscape | AX3 (accessibility-extra-large) | pass | Labels, values and both sliders remain readable without clipping. |
| 34 | Setting › Reading | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | The modal scrolls through every enlarged picker and slider row; labels, values and bounds remain complete. |
| 35 | Setting › Download | iPad | portrait | XXL (extra-extra-extra-large) | pass | Concurrency label/value, slider, both toggles and the complete explanatory footer remain readable. |
| 35 | Setting › Download | iPad | portrait | AX3 (accessibility-extra-large) | pass | Labels wrap without losing their values and the footer reaches its last word. |
| 35 | Setting › Download | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | The enlarged rows and four-sentence footer remain complete by scrolling; no concurrency or toggle was changed. |
| 35 | Setting › Download | iPad | landscape | XXL (extra-extra-extra-large) | pass | Controls and footer fit and scroll cleanly inside the centered modal. |
| 35 | Setting › Download | iPad | landscape | AX3 (accessibility-extra-large) | pass | Labels, value, slider, toggles and full footer remain complete. |
| 35 | Setting › Download | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | The footer wraps to many lines but reaches its final `Downloads folder.` sentence; all controls remain intact. |
| 36 | Setting › Laboratory | iPad | portrait | XXL (extra-extra-extra-large) | pass | The single Bypass SNI Filtering row keeps its glyph and full label inside the Setting modal. |
| 36 | Setting › Laboratory | iPad | portrait | AX3 (accessibility-extra-large) | pass | The enlarged row and label remain complete without clipping. |
| 36 | Setting › Laboratory | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | The label wraps cleanly beside its intact glyph; no part of the only control is lost. |
| 36 | Setting › Laboratory | iPad | landscape | XXL (extra-extra-extra-large) | pass | The row fits cleanly in the compact-height modal. |
| 36 | Setting › Laboratory | iPad | landscape | AX3 (accessibility-extra-large) | pass | Glyph and label remain fully readable. |
| 36 | Setting › Laboratory | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | The enlarged label remains complete and reachable; no setting was changed. |
| 37 | Setting › About | iPad | portrait | XXL (extra-extra-extra-large) | pass | Every link, contributor and acknowledgement name reads in full, and the list scrolls to its final row. |
| 37 | Setting › About | iPad | portrait | AX3 (accessibility-extra-large) | pass | Long names wrap without ellipsis; the final acknowledgement remains reachable. |
| 37 | Setting › About | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Multi-line names remain complete throughout the scrollable modal. |
| 37 | Setting › About | iPad | landscape | XXL (extra-extra-extra-large) | pass | Links and acknowledgements are complete and the list reaches its last row. |
| 37 | Setting › About | iPad | landscape | AX3 (accessibility-extra-large) | pass | Long names wrap cleanly within the compact-height modal. |
| 37 | Setting › About | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Every enlarged acknowledgement remains complete and reachable by scrolling. |
| 38 | Setting › EhSetting | iPad | portrait | XXL (extra-extra-extra-large) | blocked: no logged-in iPad session | Native EhSetting sections and the delete-profile confirmation require a logged-in account; login was forbidden and no iPhone verdict was inferred. |
| 38 | Setting › EhSetting | iPad | portrait | AX3 (accessibility-extra-large) | blocked: no logged-in iPad session | Native EhSetting sections and the delete-profile confirmation require a logged-in account; login was forbidden and no iPhone verdict was inferred. |
| 38 | Setting › EhSetting | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | blocked: no logged-in iPad session | Native EhSetting sections and the delete-profile confirmation require a logged-in account; login was forbidden and no iPhone verdict was inferred. |
| 38 | Setting › EhSetting | iPad | landscape | XXL (extra-extra-extra-large) | blocked: no logged-in iPad session | Native EhSetting sections and the delete-profile confirmation require a logged-in account; login was forbidden and no iPhone verdict was inferred. |
| 38 | Setting › EhSetting | iPad | landscape | AX3 (accessibility-extra-large) | blocked: no logged-in iPad session | Native EhSetting sections and the delete-profile confirmation require a logged-in account; login was forbidden and no iPhone verdict was inferred. |
| 38 | Setting › EhSetting | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | blocked: no logged-in iPad session | Native EhSetting sections and the delete-profile confirmation require a logged-in account; login was forbidden and no iPhone verdict was inferred. |
| 39 | Filters sheet | iPad | portrait | XXL (extra-extra-extra-large) | finding:#29 | The 100-point adaptive category cells already ellipsise names; host, reset and advanced rows remain complete. |
| 39 | Filters sheet | iPad | portrait | AX3 (accessibility-extra-large) | finding:#29 | Category names lose more characters inside the unchanged 100-point columns; every other row wraps and remains reachable. |
| 39 | Filters sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#29 | Category names collapse to short ellipsised fragments; advanced rows grow and scroll without losing text. |
| 39 | Filters sheet | iPad | landscape | XXL (extra-extra-extra-large) | finding:#29 | More 100-point columns fit per row, but the same category names are ellipsised inside each fixed-width cell. |
| 39 | Filters sheet | iPad | landscape | AX3 (accessibility-extra-large) | finding:#29 | Category names remain cut while the rest of the sheet stays complete. |
| 39 | Filters sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#29 | The compact-height sheet scrolls through complete advanced rows, but the category cells retain only ellipsised name fragments. |
| 40 | Quick Search sheet | iPad | portrait | XXL (extra-extra-extra-large) | pass | The empty-state title, explanation and toolbar controls read in full. |
| 40 | Quick Search sheet | iPad | portrait | AX3 (accessibility-extra-large) | pass | Empty-state text reflows without clipping and the editor remains reachable. |
| 40 | Quick Search sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | The empty state and New Word editor labels and empty fields remain complete; the editor was dismissed without saving. |
| 40 | Quick Search sheet | iPad | landscape | XXL (extra-extra-extra-large) | pass | Empty-state content and toolbar controls fit cleanly. |
| 40 | Quick Search sheet | iPad | landscape | AX3 (accessibility-extra-large) | pass | The empty state remains complete and the editor is reachable. |
| 40 | Quick Search sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Enlarged empty-state and editor content remain complete inside the modal; no saved item was created. |
| 41 | Date Seek picker | iPad | portrait | XXL (extra-extra-extra-large) | pass | Month, weekdays, dates, explanatory text and both Older / Newer buttons read in full. |
| 41 | Date Seek picker | iPad | portrait | AX3 (accessibility-extra-large) | pass | Calendar labels stay distinct and the sentence and buttons remain complete. |
| 41 | Date Seek picker | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | The enlarged content scrolls to both complete navigation buttons; no date was changed or submitted. |
| 41 | Date Seek picker | iPad | landscape | XXL (extra-extra-extra-large) | pass | Calendar, explanation and navigation buttons fit cleanly. |
| 41 | Date Seek picker | iPad | landscape | AX3 (accessibility-extra-large) | pass | Every calendar label remains legible and both buttons are reachable. |
| 41 | Date Seek picker | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | A short scroll reveals both complete navigation buttons below the calendar; no selection was changed. |
| 42 | Error surface | iPad | portrait | XXL (extra-extra-extra-large) | pass | The toast shows its full unsupported-link subtitle, and the detail sheet scrolls through every complete section. |
| 42 | Error surface | iPad | portrait | AX3 (accessibility-extra-large) | finding:#31 | The toast title survives but its one-line subtitle ellipsises; the detail sheet remains complete. |
| 42 | Error surface | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#31 | The toast subtitle is reduced to an early ellipsised fragment; Description, Suggested Solution, Context and Environment remain reachable in the sheet. |
| 42 | Error surface | iPad | landscape | XXL (extra-extra-extra-large) | pass | Toast title and subtitle fit in full, and the sheet scrolls through every complete field. |
| 42 | Error surface | iPad | landscape | AX3 (accessibility-extra-large) | pass | The full unsupported-link subtitle remains visible and the detail sheet stays complete. |
| 42 | Error surface | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#31 | The one-line subtitle ellipsises near its end; the detail sheet still exposes every complete section. |

## Findings

Numbered in the order they are recorded. The sweep never stops to raise one (D-02): the finding is
written here, the walk continues, and plan 16-10 reports the complete list once every page has
been scanned.

Each entry carries a **written** description — what value was lost, at which size, and what it
reads as at `.large` — never a filename (D-32). Before/after images are sent to the owner in chat
(D-33) by naming the evidence-root path and describing the image.

| #N | Screen | Cells affected | Description (written, no filenames) | Status |
|---|---|---|---|---|
| 1 | #2 | iPhone portrait XXL / AX3 / AX5; iPhone landscape AX3 / AX5; iPad portrait XXL / AX3 / AX5; iPad landscape XXL / AX3 / AX5 | The hero carousel's card is a fixed-height card and its title is capped at four lines, so the title gives up characters as the type grows instead of the card growing. At the default size a long title reads to its last word across four lines. On iPhone at XXL it is down to three lines ending in an ellipsis; at AX3 it is a single ellipsised line; at AX5 only the first word survives. The information the card exists to carry — which gallery it is — is progressively removed as the size increases. iPhone landscape absorbs XXL but fails from AX3 up. The iPad's wider layout still ellipsises the same hero in all six sampled cells: portrait progressively collapses to its opening words, while even landscape XXL loses the tail and AX3/AX5 shorten further. Pre-registered as the D-13 "hero-carousel title truncation" case. | open |
| 2 | #2 | iPhone portrait AX5 | At AX5 in portrait the hero card's contents no longer fit inside the card: the neighbouring card's cover image is drawn on top of the focused card's title tail and its rating stars, and the focused card's own cover is cut off by the screen's left edge. This is overlap, not a peek — the title and the star row are partly unreadable because another card's artwork sits over them. Landscape at the same size does not overlap. | open |
| 3 | #2, #7 | iPhone portrait AX3 / AX5; iPhone landscape AX3 / AX5; iPad portrait XXL / AX3 / AX5; iPad landscape AX3 / AX5 | The Home Toplists section's ranking cell keeps a fixed row size, so as type grows both texts are cut: the gallery title ellipsises and the uploader line below it ellipsises as well. At AX5 on iPhone portrait the uploader is not visible at all. The iPad layout reproduces the title loss already at XXL portrait, worsens through AX3/AX5, and also loses title and then uploader text in landscape from AX3. Covers the D-04 site `HomeFeature/GalleryRankingCell.swift:39`. | open |
| 4 | #3, #4, #5, #6, #7, #10, #32 | iPhone portrait AX3 / AX5 (also observed at XXL on #3); on #32 also iPhone landscape AX5; iPad #3 portrait AX3 and landscape AX5; iPad #4 and #7 portrait AX3 and landscape AX3 / AX5; iPad #10 portrait AX3 / AX5 and landscape AX5; iPad #32 portrait AX5 and landscape AX5 | The pull-to-reveal filter field above the pushed lists sometimes renders as an empty rounded capsule: both the magnifying-glass glyph and the "Filter" placeholder are absent, so the control shows no indication of what it is or does. The capsule itself grows with the type size, so this is not a fixed-height clip — the content is simply not drawn. The failure is non-monotonic: on the iPad it appears at AX3 portrait but returns at AX5 portrait on #3, #4, and #7, while landscape fails at AX5 on #3 and at both AX3/AX5 on #4 and #7. Search results (#10) loses its submitted query at AX3/AX5 portrait and AX5 landscape while preserving it at landscape AX3. Activity Logs (#32) fails at AX5 in both iPad orientations while its field is intact at XXL and AX3; the iPhone occurrence follows a different non-monotonic pattern. | open |
| 5 | #3, #4, #5, #6, #7, #17 (all list hosts) | iPhone portrait XXL / AX3 / AX5; iPhone landscape AX3 / AX5; iPad #3 portrait AX5 | The gallery list row's title is capped at three lines (two when a download badge is present), so a longer title surrenders characters every time the type size goes up. A title that reads to its final bracketed suffix at the default size is already missing that suffix at XXL, loses roughly a third of its text at AX3, and at AX5 in portrait runs off the right edge cut mid-glyph rather than ellipsised. The iPad's regular-width Frontpage row also loses a long title tail at AX5, while its wider landscape counterpart reads in full. Recorded once and tagged all list hosts. | open |
| 6 | #3, #4, #5, #6, #7, #12, #17 (all list hosts) | iPhone portrait AX3 / AX5; iPad #12 portrait AX5 and landscape AX5 | From AX3 upward in iPhone portrait the list row's text column is wider than the screen, so everything on its right-hand side is cut off by the screen edge rather than reflowed: the language value loses its last one or two letters, the date loses its time and then its year, and the page-count number loses digits — at AX5 the page-count number is gone entirely and only its glyph remains. The iPad Inspector sheet reproduces the timestamp loss at AX5 in both orientations: the date remains, but the time is truncated. None of these values is reachable elsewhere in its host. All of them read in full at the default size and at XXL. Covers the D-04 sites `GalleryListComponents/Cells/GalleryDetailCell.swift:152` and `:163` together with their paired shrinks at `:155` and `:166`, which engage and still fail to keep the value on screen. | open |
| 7 | #3, #4, #5, #6, #7, #32 | iPhone portrait AX3 / AX5 | The pushed screens' navigation large title degrades in portrait. At AX3 a long title is ellipsised. At AX5 the title is not rendered at all on any of these screens — the band where it belongs is blank, and the accessibility tree carries no heading either, so the screen loses its own name while the space it needs is still reserved. Short titles are affected exactly as long ones. Landscape keeps the inline title at every size. Screen #32 shows a milder variant of the same site: its large title is ellipsised at AX3 **and** at AX5 rather than disappearing, and it survives in landscape where the bar falls back to its inline title. | open |
| 8 | #3, #4, #5, #6, #7, #17 (all list hosts) | iPhone portrait AX5 | At AX5 in portrait the row's cover thumbnail is squeezed to a narrow vertical sliver a few points wide and pushed partly past the screen's left edge, leaving an unrecognisable strip of the artwork instead of the cover. The cover is the row's only visual identifier and it is not reproduced anywhere else in the row. | open |
| 9 | #5, #6, #17 (all list hosts) | iPhone portrait XXL and above | The uploader name is ellipsised as soon as a language value shares its line: at XXL a seventeen-character uploader already reads with its last third replaced by an ellipsis, while the language value beside it is complete. At the default size both read in full on the same line. This is the D-04 site `GalleryListComponents/Cells/GalleryDetailCell.swift:107`, whose Phase-10 "fine" verdict rested on the secondary-text exemption that D-04 removes. At AX3 and above the same value is additionally cut by finding #6. | open |
| 10 | #9 | iPhone portrait XXL / AX3 / AX5; iPhone landscape XXL / AX3 / AX5; iPad portrait AX3 / AX5; iPad landscape AX3 / AX5 | The Search root's "Recently Seen" strip keeps a fixed cell size, so its contents are removed as the type grows rather than the cell growing with them. At XXL the iPhone cell's title is already ellipsised where it read in full at the default size. At AX3 the cell overflows its slot: the title is cut at the right edge *and* its opening words are pushed past the screen's left edge together with the cover, so neither end of the title is readable. At AX5 in iPhone portrait the cells are drawn on top of the section heading and on top of each other, and the two section headings collapse to roughly one word per line while the rest of their row stays empty; in landscape at AX5 the cells overlap their own covers. The iPad absorbs XXL, then reproduces the fixed-height loss from AX3 upward in both orientations: title tops clip first, and at AX5 the title and cover contents overflow their cells. Covers the D-04 site `SearchFeature/GalleryHistoryCell.swift:32`. | open |
| 11 | #11 | iPhone portrait AX5 | The download delete confirmation is presented as a popover of fixed width (about a quarter of the screen) rather than a full-width sheet, so at AX5 its explanatory sentence no longer fits: the message stops mid-sentence and its last word is hidden behind the confirm button, with the popover already running past the bottom of the screen and no way to scroll to the rest. The user is asked to confirm a destructive action from a sentence they cannot finish reading. At the default size and at XXL the same popover shows the sentence complete. The absence of a separate Cancel button is *not* part of this finding — the popover has no Cancel button at any size and is dismissed by tapping outside. | open |
| 12 | all list hosts, thumbnail layout | iPhone portrait AX5 | With the list's Display Mode set to Thumbnail, the grid cell removes text as the type grows instead of reflowing: the category badge is abbreviated to its first word plus an ellipsis, so two different categories become indistinguishable from their badges; the cell's title is ellipsised after its bracketed prefix; the page-count line is cut; and the grid's right-hand column runs off the screen edge with its star row clipped. All of these read in full at the default size. Covers the D-04 sites `GalleryListComponents/Cells/GalleryThumbnailCell.swift:99` and `AppComponents/CategoryView.swift:31`. The sweep set Display Mode to Thumbnail for this one capture and restored it to Detail immediately afterwards. | open |
| 13 | #14 | iPhone portrait XXL / AX3 / AX5 | The Detail header's title is capped at three lines (`DetailFeature/DetailView+HeaderSection.swift:319`, `lineLimit(showFullTitle ? nil : 3)`), so in portrait it surrenders characters as the type grows. A title that reads to its closing bracket over three lines at `.large` already ends in an ellipsis at XXL, loses its whole second half at AX3, and at AX5 keeps only its bracketed prefix. The header does carry a tap-to-expand affordance on the title itself — the same tap that opens the full text — so the value is recoverable in place; it is still recorded as a finding because the default rendering shows strictly less at each larger size (D-04). The **uploader** line directly beneath it (`:324`, single-line) has no such affordance and degrades in the same cells: full at XXL, "BaronArgyleS…" at AX3 and "BaronArg…" at AX5. Landscape is unaffected at all three sizes. | open |
| 14 | #14 | iPhone portrait XXL / AX3 / AX5; iPhone landscape AX3 / AX5 | The Detail stats strip lays its columns out at a fixed fraction of the container width (`DetailFeature/DetailView+Subviews.swift` `DescScroll`, `containerRelativeFrame(.horizontal, itemWidth)` inside a `frame(height: rowHeight)`), so the columns keep their width and height while the text inside them grows. At XXL portrait every column label is already abbreviated ("FAVORITED" → "FAVORI…", "196 RATINGS" → "196 RAT…", "PAGE COUNT" → "PAGE C…") and the five-star rating row is clipped at both ends. At AX3 the **values** go too — a four-digit favourite count reads "11…", a rating of 4.50 reads "4.…", and the unit lines read "Engl…" / "Pag…". At AX5 each column is down to two characters ("FA…", "1…", "Ti…") and the star row shows a single clipped star. Every one of these reads in full at `.large`, and none of them is reproduced anywhere else on the screen. Landscape holds the values but loses the labels from AX3 up and shows three stars for a 4.50 rating at AX5. This is the pre-registered D-13 "Detail stats-strip abbreviation" case, and it covers the D-04 sites `:99` and `:116`. | open |
| 15 | #14 | iPhone portrait AX3 / AX5 | Tags in the Detail tag cloud are laid out from a fixed leading column and are not wrapped or ellipsised when they exceed the remaining width, so in portrait a long tag simply runs off the right edge of the screen and is cut mid-glyph with no ellipsis to mark it. At AX3 a sixteen-character tag loses its last six characters; at AX5 two separate tags are cut, one of them losing half its text, and the label column beside them is itself clipped. The same tags read in full at `.large` and in landscape at every size. This is the pre-registered D-13 "long-tag right-edge clip" case and covers the D-04 site `AppComponents/TagCloudView.swift:122`. | open |
| 16 | #14 | iPhone portrait XXL / AX3 / AX5; iPhone landscape XXL / AX3 / AX5 | The Detail comment cell's author line and timestamp are single-line and sit in a card of fixed 300-point width (`DetailFeature/DetailView+CommentCells.swift:37, :43, :51`), so both are ellipsised as the type grows — and the 0.75 `minimumScaleFactor` at `:42` visibly engages first and still fails to keep the name. A fifteen-character author reads in full at `.large`, is "BaronArgyle…" at XXL, "BaronA…" at AX3 and "Baro…" at AX5; the timestamp degrades in step, from the full "YYYY/MM/DD, HH:MM" to a bare "2026…" at AX5 that no longer carries even the month. **This is the only Group-B row that fails in landscape at XXL**, because the card width is fixed rather than derived from the screen. | open |
| 17 | #14 | iPhone portrait AX3 / AX5; iPhone landscape AX5 | The same comment card's body text loses lines to the card's fixed frame (`:51`, width 300 with a `@ScaledMetric` height): the body is already ellipsised at `.large`, and each larger size shows strictly fewer characters of it — roughly a sixth fewer at AX3 and a third fewer at AX5 in portrait. In landscape at AX5 a short comment that read complete at every smaller size ("… seems to have been deleted") loses its final word. Because the height scales but the width does not, the card cannot trade one for the other. | open |
| 18 | #16 | iPhone portrait XXL / AX3 / AX5; iPhone landscape AX5 | The Comments view's header row keeps author, vote score and timestamp on one line at every size (`DetailFeature/Comments/CommentsView.swift:165, :166`), so the row's three values compete for a width that never grows. The timestamp goes first: at XXL portrait a scored row already reads "2025/03/23, 19…" where `.large` shows "2025/03/23, 19:02", and the same loss reappears in landscape at AX5. From AX3 up in portrait the author goes too — "Pecan Crisp" becomes "Pecan…" and then "Pec…" at AX5, with the timestamp reduced to "20…", which no longer identifies the comment's date at all. The 0.75 `minimumScaleFactor` at `:165` engages before the ellipsis and does not prevent it. The comment **bodies** are exemplary by contrast: they wrap freely and never lose a character at any size in either orientation, which is what makes the header row's behaviour a layout choice rather than a space limit. The post-comment sheet was opened at AX5 portrait, judged (title, close and confirm controls and the empty editor all read in full) and cancelled without posting. | open |
| 19 | #18 | iPhone portrait AX3 / AX5 | Gallery Infos caps every value at three lines (`DetailFeature/GalleryInfos/GalleryInfosView.swift:110`, `.lineLimit(3)`), and in portrait three lines stop being enough from AX3 up. The Archive URL and the Torrent URL both end in an ellipsis at AX3 exactly where their token begins, and at AX5 the Gallery URL, the Parent URL and the gallery title go the same way. This screen exists to show the raw identifiers, its values are copy-on-tap, and the truncated tail is not shown anywhere else in the app — so the loss is total, not cosmetic. Everything reads in full at `.large` and at XXL, and in landscape at all three sizes, which is what makes this a line-count cap rather than a width limit. The site is **not** in the § D-04 checklist: the checklist enumerates `lineLimit(1)` and this is a `lineLimit(3)`, so it was found by the walk rather than inherited. | open |
| 20 | #19 | iPhone portrait AX3 / AX5; iPhone landscape AX3 / AX5 | The Archives sheet loses exactly the two values a user needs in order to choose an archive: its **size** and its **price**. The archive card is a fixed-size grid item whose three stacked lines (resolution name, file size, price) do not fit once the type grows, and the funds row below it is single-line. In portrait the name ellipsises first — at AX5 "Original" and "1280x" both read as three characters plus an ellipsis, so two different resolutions become indistinguishable — the size loses its unit ("182.0…"), and the name and price lines are drawn *outside* the card's own border. In landscape the failure is worse and starts at AX3: both cards drop their size and price lines completely, leaving only the resolution name, and at AX5 the cards are clipped to a sliver of that name with the funds row drawn on top of them. The account's GP and Credits balances degrade in step, from the full "500,062,096" at XXL to "50…" at AX5 portrait. Covers the D-04 sites `DetailFeature/Archives/ArchivesView.swift:143` (funds line) and `:202` (archive price). Everything reads in full at `.large` and at XXL in both orientations. **Nothing was purchased and no download was started** — the sheet was opened, judged and dismissed. | open |
| 21 | #20 | iPhone portrait AX3 / AX5 | Each torrent card's meta row puts four glyph-plus-value pairs (seeders, leechers, downloads, file size) on one line inside fixed 44-point slots, and in portrait the values are destroyed as the type grows while the glyphs stay untouched. At AX3 the leechers value is drawn as a half glyph (a "0" reads as a "C"), the download count keeps a fragment of its second digit, and "168.5 MiB" is reduced to the single character "1". At AX5 **none of the four values is rendered at all** — four glyphs sit alone with no numbers beside them, so the screen no longer says how healthy the torrent is or how large it is, even though the accessibility tree still reports every value. The uploader and the posted timestamp degrade alongside: full at XXL, "2026/01…" at AX3, "Disko…" and "2026…" at AX5. Covers the D-04 sites `DetailFeature/Torrents/TorrentsView.swift:110` and `:124`, whose Phase-10 verdict was "shrink-absorbed" — there is no shrink absorbing it now. Landscape passes at all three sizes, and portrait XXL reads in full. **No torrent download was started.** | open |
| 22 | #25 | iPhone portrait AX3 / AX5 | The reader's page indicator disappears in portrait. It is a single-line `Text` inside a glass capsule that shares one leading-aligned `HStack` with the close button (`ReadingFeature/Support/ControlPanel.swift:170–179`), and as the type grows the capsule is squeezed instead of the row wrapping: at AX3 the capsule shows only an ellipsis, and at AX5 it is a two-point-wide sliver that renders no glyph at all, while the accessibility tree still reports "1 / 14". The reader therefore stops telling the user which page they are on and how many pages there are — the one piece of state the control panel exists to show. The lower bar's separate "1" and "14" slider end labels survive, but they are the slider's bounds, not the current page. Landscape keeps the indicator intact at all three sizes. This is the pre-registered D-13 "reader total-page counter wrap" case and the D-04 site `ControlPanel.swift:176` — **and the pre-registered prediction is wrong: the counter does not wrap, it vanishes.** | open |
| 23 | #23 | iPhone landscape AX3 / AX5 | The Detail screen's download **delete confirmation** loses its content in landscape, and what it loses is the safety half. The alert's container is bounded by the short landscape screen and does not scroll, so the growing text simply falls outside it: at AX3 the sentence "This will remove the downloaded gallery from this device." is cut after its fourth word, with the remainder hidden behind the button row; at AX5 **neither the sentence nor the Cancel button is drawn at all** — the alert shows its title and the red Delete button and nothing else, while the accessibility tree still lists a Cancel button positioned below the alert's visible bounds. A user at AX5 in landscape is presented with a destructive confirmation whose only visible, tappable affordance is Delete, and no on-screen way to back out other than guessing that a tap outside dismisses it. Portrait absorbs the same growth cleanly at all three sizes (the buttons restack vertically and the sentence wraps to five lines), and landscape at XXL is complete. This is a different site and a different container from finding #11 — that one is the Downloads tab's fixed-width popover in portrait; this one is the Detail screen's full alert in landscape — so it is recorded separately. Only the delete variant could be exercised: the retry-mode variant needs a download in an error state and the session's only download is complete. **Every dialog raised was cancelled; nothing was deleted.** | open |
| 24 | #29 | iPhone portrait XXL / AX3 / AX5; iPhone landscape AX3 / AX5 | The Account screen's cookie rows keep their label and their value on a single line inside one row, and the value is the half that gives way: the label wraps (and even hyphenates) while the value is ellipsised. In portrait the long hash value already loses roughly a third of what it shows at the default size at XXL; at AX3 the short numeric member id — which reads complete at the default size and at XXL — is cut after five of its seven digits, and the ExHentai token is cut to four characters; at AX5 all three value fields are three or four characters plus an ellipsis while their labels occupy four wrapped lines each. Landscape absorbs XXL entirely (the hash renders all thirty-two characters there) and then fails the same way from AX3 up. Every one of these values is a credential fragment the row exists to let the user verify, and none of them is reproduced anywhere else in the app — the neighbouring copy action puts them on the pasteboard but never shows them. | open |
| 25 | #32 | iPhone portrait AX3 / AX5; iPhone landscape AX5; iPad portrait AX3 / AX5; iPad landscape AX3 / AX5 | The activity-log row's category chip is a single-line pill (`SettingFeature/AppActivityLogs/AppActivityLogsView.swift:224`, `lineLimit(1)`) sharing one baseline-aligned row with the level dot and the timestamp, and the timestamp is the part allowed to wrap. The chip therefore gives up characters as the type grows while the timestamp beside it reflows freely: `DownloadCoordinator` reads in full at the default size and at XXL, is ellipsised at AX3 on the iPad, and shortens further at AX5 in both orientations. The chip is the only thing on the row that says which subsystem emitted the log, and two different subsystems whose names share a prefix become indistinguishable once it is cut. The log message underneath, by contrast, wraps perfectly at every size. | open |
| 26 | #32 | iPhone portrait AX3 / AX5; iPhone landscape AX5; iPad portrait AX5 | The Runs menu stops drawing the checkmark beside the selected run as the type grows. At the default size and at XXL the menu marks the current run with a leading tick, which is the only thing in the menu that says which run the list below is showing. At the affected sizes the tick is not rendered while the run labels keep their full text, so the menu presents identical-looking rows and the screen no longer tells the user which one it is displaying. The accessibility tree still reports the checkmark, so this is visible only in the rendered frame. The iPad's run picker sheet reached through More Logs keeps its tick at AX5, confirming that the selection state survives in the sheet and is lost only in the menu. | open |
| 27 | #38 | iPhone portrait XXL / AX3 / AX5; iPhone landscape AX5 | The Excluded Languages grid's three column headers (`SettingFeature/EhSetting/EhSettingView+Sections3.swift:131`) are `lineLimit(1)` plus `fixedSize()` inside height-less `Color.clear` columns, so they refuse to wrap or shrink and instead grow past the column boundaries. At the default size the words Original, Translated and Rewrite sit separated and centred above their radio columns. From XXL upward they run together into one unbroken string and slide to the right of the columns they label, so the grid keeps twenty-odd rows of identical circles with nothing that says which circle means what. Every row's radio triple is still drawn and still tappable — what is lost is the only thing that gives the grid meaning. Because the headers are `fixedSize()` the string is not ellipsised, it simply overlaps and overflows, which is why the accessibility tree reports all three words correctly at every size. Landscape is wider and absorbs XXL and AX3 — the three words stay separated and centred over their columns there — and fails the same way only at AX5. | open |
| 28 | #38 | iPhone portrait AX5 | EhSetting's `LabeledContent` rows stop reserving room for their own contents once both the label and the picker value need several lines. On the Multi-Page Viewer section at AX5 portrait the three-line "Use Multi-Page Viewer" label runs past the bottom of its row and is drawn over the next row's label, which is itself only half visible; the picker value below it ("Align left, scale if overwidth") has its last word drawn across the row separator and cut by the following row's background. Three consecutive rows are involved and two of them cannot be read at all. This is different from a wrap: the text is not reflowed into a taller row, it is painted outside the row it belongs to and covered by its neighbour. The same three rows are clean at AX5 in landscape, where the wider row keeps every label on one line. | open |
| 29 | #39 | iPhone portrait XXL / AX3 / AX5; iPhone landscape XXL / AX3 / AX5; iPad portrait XXL / AX3 / AX5; iPad landscape XXL / AX3 / AX5 | The Filters sheet's category grid keeps every name to one line inside narrow cells (`AppComponents/CategoryView.swift:87`, `lineLimit(1)`), so names are eaten from the right as type grows. On iPhone the fixed three-column grid cuts two names at XXL, eight at AX3, and all nine at AX5; landscape lays out six per row but keeps the same progression. The iPad's 100-point adaptive columns reproduce the failure in all six cells: more columns fit across the wider sheet, but their width does not grow with the labels, so names are already ellipsised at XXL and collapse further at AX3 / AX5 in both orientations. Several cells become mutually indistinguishable from text alone. The colour is the cell's other identifier, but colour alone is not a name, and the grid is the sheet's primary control. | open |
| 30 | #40 | iPhone portrait XXL / AX3 / AX5; iPhone landscape AX5 | Quick Search's saved-word name is `lineLimit(1)` (`QuickSearchFeature/QuickSearchView.swift:40`). A throwaway row whose name and content both read in full at the default size is already cut in portrait Edit mode at XXL, is cut in the ordinary row from AX3 upward, and remains cut at AX5 landscape. Edit mode makes the failure worse because the delete and reorder controls take width from both text lines: at AX3 portrait the content is also reduced to a few characters plus an ellipsis. The editor fields themselves reflow correctly. The throwaway item and its generated search-history entry were both removed after the walk, restoring the original empty list. | open |
| 31 | #42 | iPhone portrait XXL / AX3 / AX5; iPhone landscape AX3 / AX5; iPad portrait AX3 / AX5; iPad landscape AX5 | The error toast's title stays complete, but its subtitle is hard-capped to one line (`SystemNotification/ToastMessageView.swift:70`) and progressively loses the unsupported-link explanation as Dynamic Type grows. On iPhone the complete sentence is visible in landscape XXL, while portrait XXL already ends after `recognized…`, portrait AX3 after `was…`, and portrait AX5 after `link…`; landscape AX3 and AX5 also ellipsise. The iPad absorbs the sentence at portrait and landscape XXL and at landscape AX3, but portrait AX3 / AX5 and landscape AX5 still cut it. The detail sheet reflows and scrolls through the complete Description, Suggested Solution, Context and Environment sections at every sampled size, so this finding is confined to the toast's immediate message. | open |
| 32 | #3 | iPad portrait AX3 / AX5 | The regular-width gallery row keeps its category badge and timestamp on one horizontal stats line without reserving space between them. A long category name that fits beside the timestamp at XXL grows across the timestamp at AX3; at AX5 the badge covers the timestamp's leading date characters. Both values still exist, but their glyphs are painted on top of one another and cannot be read independently. The wider landscape row keeps them separated at all three sampled sizes. | open |
| 33 | #30 | iPad portrait AX5; iPad landscape AX5 | The native Login screen's large heading and first field do not reserve enough vertical space for each other at AX5. The bottom of `Login` is painted through the `Username` label, leaving both strings present but impossible to read independently. The same overlap occurs in the compact-height landscape modal; XXL and AX3 keep the heading and field separated in both orientations. No credential was entered and no login was submitted. | open |

Status ∈ {`open`, `fixed-by <commit>`, `re-verified`, `accepted`}.

## D-13 named edge cases

The five edge cases from ROADMAP criterion 4, pre-registered as named items so criterion 4 ticks
off item by item and none is silently dropped. Tracked alongside § Findings, not merged into it.
Each closes as `fixed` or `accepted (owner reason: …)` — never by omission.

| Case | Screen | Site | Observed (iPhone, round 1) | Status | Disposition |
|---|---|---|---|---|---|
| Detail stats-strip abbreviation | #14 | `DetailFeature/DetailView+Subviews.swift:99, 116` (stats strip) | It reproduces, and it is worse than "abbreviation": the strip's columns keep a fixed fraction of the container width and a fixed row height, so the column **labels** ellipsise first (at XXL portrait already — "FAVORITED" → "FAVORI…", "196 RATINGS" → "196 RAT…") and from AX3 up in portrait the **values** go too: a four-digit favourite count reads "11…" at AX3 and "1…" at AX5, a 4.50 rating reads "4.…" then is lost, and the unit lines read "Engl…" / "Ti…". The five-star rating row is clipped at both ends at every accessibility size and shows three stars for a 4.50 rating at AX5 landscape. Landscape keeps the values but loses the labels from AX3. Observed in iPhone portrait XXL / AX3 / AX5 and iPhone landscape AX3 / AX5; recorded as finding #14. **iPad observed:** blocked at all six cells because live Detail requires a session and `IPAD_LOGIN=none`; no iPhone verdict was inferred for the iPad's modal layout. | open |  |
| Long-tag right-edge clip | #14 | `AppComponents/TagCloudView.swift:122` (tag cloud) | It reproduces in portrait from AX3 up. Tags are laid out from a fixed leading column and are neither wrapped nor ellipsised when they exceed the remaining width, so a long tag runs off the right edge of the screen and is cut mid-glyph with nothing to mark the loss. At AX3 portrait a sixteen-character tag loses its last six characters; at AX5 portrait two separate tags are cut (one tag's own frame is 64 points wider than the screen) and the label column beside them is itself clipped. The same tags read in full at `.large` and in landscape at XXL / AX3 / AX5. Observed in iPhone portrait AX3 / AX5; recorded as finding #15. **iPad observed:** blocked at all six cells because live Detail requires a session and `IPAD_LOGIN=none`; no iPhone verdict was inferred for the iPad's modal tag-cloud layout. | open |  |
| Reader total-page counter wrap | #25 | `ReadingFeature/Support/ControlPanel.swift:176` (page indicator) | **The pre-registered prediction does not hold: the counter does not wrap, it disappears.** The indicator is a single-line `Text` in a glass capsule sharing a leading-aligned `HStack` with the close button, so as the type grows the capsule is squeezed rather than the row wrapping. In **portrait** it reads "1 / 14" in full at XXL, shows only an ellipsis at AX3, and at AX5 renders nothing at all — a two-point-wide sliver beside the close button — while the accessibility tree still reports the full string. In **landscape** it reads in full at XXL, AX3 and AX5. The lower bar's "1" and "14" slider end labels survive in every cell, but those are the slider's bounds, not the current page. Recorded as finding #22 and left undispositioned here per D-13 — with the wrap-is-acceptable reasoning no longer applicable, since nothing wraps. **iPad observed:** blocked at all six cells because the regular-width panel requires a live Reading session and `IPAD_LOGIN=none`; no iPhone verdict was inferred for its five/seven-thumbnail `.callout` layout. | open |  |
| Favorites trailing-glyph clip | #8 | `FavoritesFeature/FavoritesView.swift` toolbar/menu glyphs + `GalleryListComponents/Cells/GalleryDetailCell.swift:140` trailing symbol | On iPhone, the toolbar and menu glyphs do **not** clip: the favourites-index, sort-order and features glyphs keep their size and stay fully drawn at AX5 in both orientations, and the row's trailing `photoOnRectangleAngled` symbol is likewise never cut. What is lost is the number beside that symbol — at AX3 the page count loses digits at the screen's right edge and at AX5 only the glyph survives with no number at all (finding #6). So the pre-registered glyph clip does not reproduce on iPhone; the paired value does. iPad observation is blocked because `IPAD_LOGIN=none`; no iPad glyph verdict was inferred. | open |  |
| Hero-carousel title truncation | #2 | `HomeFeature/GalleryCardCell.swift:73` (`lineLimit(4)`) | It ellipsises, which is the pre-registered failing case, and it does so well before AX5 on both devices. On iPhone at AX5 in **portrait** only the first word survives and the ellipsis sits on top of the neighbouring card's artwork (finding #2); at AX5 in **landscape** the title ends after roughly three words. On iPad the title also loses its tail in every sampled cell: portrait contracts from an ellipsised multi-line title at XXL to only its opening words at AX5, while landscape's extra width still cannot preserve the tail at XXL, AX3, or AX5. The title does not make useful use of `lineLimit(4)` at any accessibility size — the card's fixed height, not the nominal line limit, removes the text. Recorded as finding #1. | open |  |

Note on the reader counter: under D-03 a **wrap** is not degradation, so this case may close as
`accepted` on the rule alone. That disposition is still recorded here rather than assumed.

## D-04 checklist

Every site Phase 10 judged under the secondary-text exemption, plus every shrink and every fixed
frame, mapped to the screen where it renders. **A Phase-10 verdict of "fine" does not carry** — it
is recorded here only to show what is being overturned. Each row is dispositioned during the walk
of the screen it maps to.

Sites are `file:line` at HEAD (`feature/gsd-phase-16`, after plan 16-01) — all re-verified by grep
when this table was written. D-04 status ∈ {`pending`, `fine`, `finding:#N`, `removed-by <commit>`}.

### `lineLimit(1)` — 30 sites (+ the one `lineLimit(4)` D-13 site)

| Site (file:line at HEAD) | What is clipped | Screen # | Phase-10 verdict | D-04 status | Note |
|---|---|---|---|---|---|
| `DateSeekFeature/DateSeekPickerView.swift:122` | picker row text | #41 | fine | fine | Walked at all six iPhone cells: month, weekdays, every date and both navigation labels remain complete; the picker caps its own calendar type scale and the surrounding text reflows. |
| `SystemNotification/ToastMessageView.swift:65` | toast title | #42 | B1 fixed (toast) | fine | The `Error` title reads in full at every sampled size and orientation. |
| `SystemNotification/ToastMessageView.swift:70` | toast subtitle | #42 | B1 fixed (toast) | finding:#31 | The complete unsupported-link sentence fits only at landscape XXL; it ellipsises in all three portrait cells and at landscape AX3 / AX5. |
| `SettingFeature/EhSetting/EhSettingView+Sections3.swift:131` | section value | #38 | B3 / fine | finding:#27 | Not ellipsised — `fixedSize()` makes the three headers overflow their columns and run together instead, so the grid loses its column identification from XXL up. |
| `SettingFeature/AppActivityLogs/AppActivityLogsView.swift:224` | log category chip | #32 | fine | finding:#25 | Cut to seven characters at AX3 portrait and four at AX5; complete at the default size and at XXL. |
| `ReadingFeature/Support/ControlPanel.swift:176` | page indicator `n / total` | #25 | fine | finding:#22 | **D-13: reader total-page counter wrap** |
| `HomeFeature/GalleryRankingCell.swift:39` | ranking cell subtitle | #2 | fine | finding:#3 |  |
| `SearchFeature/GalleryHistoryCell.swift:32` | history cell secondary line | #9 | fine | finding:#10 |  |
| `GalleryListComponents/Cells/GalleryDetailCell.swift:107` | uploader | all list hosts (#3, #4, #5, #8, #10) | fine (secondary exemption) | finding:#9 | **back in scope — the exemption is gone** |
| `GalleryListComponents/Cells/GalleryDetailCell.swift:152` | stats value | all list hosts (#3, #4, #5, #8, #10) | fine | finding:#6 | **back in scope + D-14 (paired shrink at :155)** |
| `GalleryListComponents/Cells/GalleryDetailCell.swift:163` | stats value | all list hosts (#3, #4, #5, #8, #10) | fine | finding:#6 | **back in scope + D-14 (paired shrink at :166)** |
| `GalleryListComponents/DownloadBadgeLabel.swift:19` | badge progress text | all list hosts + #11 | fine | finding:#6 |  |
| `GalleryListComponents/Cells/GalleryThumbnailCell.swift:99` | thumbnail cell footnote | all list hosts (thumbnail layout) | fine | finding:#12 |  |
| `AppComponents/TagCloudView.swift:122` | tag text | #14 | fine | finding:#15 | **D-13: long-tag right-edge clip** |
| `AppComponents/CategoryView.swift:31` (`CategoryLabel`) | category name | #14 + all list cells | fine | finding:#12 | D-15 collision via the paired 0.72 shrink at the Detail header. On screen #14 the same component reads in full at every size — the abbreviation is specific to the thumbnail-grid cell's narrow slot, not to `CategoryLabel` itself. |
| `AppComponents/CategoryView.swift:87` (`CategoryCell`) | category name | #39 | fine | finding:#29 | Two of nine cut at XXL, eight at AX3, all nine at AX5, in both orientations. |
| `AppComponents/TagSuggestionView.swift:111` | suggestion row title | #10, #17 | fine | fine | Temporarily enabled the owner's disabled Tags Extension and Search Suggestion toggles, walked all ten `female:big` suggestions at AX5 iPhone portrait, then restored both toggles off. Every displayed title read in full. |
| `AppComponents/TagSuggestionView.swift:116` | suggestion row detail | #10, #17 | fine | fine | Every `female:big …` detail line read in full at AX5 iPhone portrait; the temporary query was cleared without submission and both settings were restored. |
| `DetailFeature/DetailView+CommentCells.swift:37` | comment author | #14 | fine | finding:#16 | **back in scope + D-14 (paired shrink at :42)** |
| `DetailFeature/DetailView+CommentCells.swift:43` | comment date / body line | #14 | fine | finding:#16 | **back in scope** |
| `DetailFeature/DetailView+Subviews.swift:99` | stats strip value | #14 | fine | finding:#14 | **D-13: Detail stats-strip abbreviation** |
| `DetailFeature/DetailView+Subviews.swift:116` | stats strip value | #14 | fine | finding:#14 | **D-13: Detail stats-strip abbreviation** |
| `DetailFeature/DetailView+HeaderSection.swift:72` | header category label | #14 | fine | fine | **D-14 0.72 site at :73; D-15 parity constraint.** Walked at all six iPhone cells: the header's category badge grows with the type and reads in full at XXL, AX3 and AX5 in both orientations — it never truncates, so the `lineLimit(1)` is never reached here. |
| `DetailFeature/DetailView+HeaderSection.swift:324` | header secondary line | #14 | fine | finding:#13 | the uploader line, ellipsised from AX3 up in portrait |
| `DetailFeature/Comments/CommentsView.swift:166` | comment header | #16 | fine | finding:#18 | **back in scope + D-14 (paired shrink at :165)** |
| `DetailFeature/Torrents/TorrentsView.swift:110` | torrent meta | #20 | shrink-absorbed | finding:#21 | re-judge — there is no shrink any more |
| `DetailFeature/Torrents/TorrentsView.swift:124` | torrent meta | #20 | shrink-absorbed | finding:#21 | re-judge — there is no shrink any more |
| `DetailFeature/Archives/ArchivesView.swift:143` | funds line | #19 | fine | finding:#20 |  |
| `DetailFeature/Archives/ArchivesView.swift:202` | archive price | #19 | fine | finding:#20 |  |
| `QuickSearchFeature/QuickSearchView.swift:40` | quick-search word name | #40 | fine | finding:#30 | The saved name cuts first in portrait Edit mode at XXL, in the ordinary portrait row from AX3 upward, and at AX5 landscape. |
| `HomeFeature/GalleryCardCell.swift:73` (`lineLimit(4)`) | hero-carousel gallery title | #2 | fine | finding:#1 | **D-13: hero-carousel title truncation** |

### `minimumScaleFactor` — 5 sites, target 0 (D-14)

Banned outright, not judged case by case. The lint rule that makes the target mechanical
(`no_minimum_scale_factor`) is held back to plan 16-12 so it lands with or after the removals.

| Site (file:line at HEAD) | What is shrunk | Screen # | Phase-10 verdict | D-04 status | Note |
|---|---|---|---|---|---|
| `GalleryListComponents/Cells/GalleryDetailCell.swift:155` (0.75) | stats value shrunk instead of reflowed | all list hosts (#3, #4, #5, #8, #10) | fine | finding:#6 | removal target 0 (D-14) |
| `GalleryListComponents/Cells/GalleryDetailCell.swift:166` (0.75) | stats value shrunk instead of reflowed | all list hosts (#3, #4, #5, #8, #10) | fine | finding:#6 | removal target 0 (D-14) |
| `DetailFeature/DetailView+CommentCells.swift:42` (0.75) | comment author shrunk | #14 | fine | finding:#16 | removal target 0 (D-14). The 0.75 shrink visibly engages at XXL and the author is still ellipsised. |
| `DetailFeature/DetailView+HeaderSection.swift:73` (0.72) | header category label shrunk | #14 | fine | fine | **D-15 collision — plausibly engages at `.large`; parity outranks the ban.** **D-15 evidence:** the 0.72 shrink does NOT visibly engage at `.large` for a seven-character category, and the badge never truncates at XXL / AX3 / AX5 either — so removing it should be parity-safe for that name length. |
| `DetailFeature/Comments/CommentsView.swift:165` (0.75) | comment header shrunk | #16 | fine | finding:#18 | removal target 0 (D-14). The 0.75 shrink engages before the ellipsis and does not prevent it. |

### Fixed frames and widths

| Site (file:line at HEAD) | What is constrained | Screen # | Phase-10 verdict | D-04 status | Note |
|---|---|---|---|---|---|
| `SettingFeature/SettingView.swift:109` `.frame(width: 45, height: 45)` | setting-row icon slot | #28 | chrome — OK | fine | re-check: an AX5 `.largeTitle` glyph may exceed 45pt Walked at all six iPhone cells: the row glyph scales with the type but stays inside its 45-pt slot at XXL, AX3 and AX5 in both orientations, and never overlaps or clips the label beside it. |
| `SettingFeature/AppearanceSetting/AppearanceSettingView.swift:146` `.frame(width: 60, height: 60)` | app-icon image slot | #33 | chrome — OK | fine | chrome; re-check the adjacent label Walked at AX5: the 60-pt icon slot holds a fixed-size image and never clips; the adjacent name wraps to two lines and reads in full, and the selection tick beside it grows with the type. |
| `ReadingFeature/Support/ControlPanel.swift:166` `.frame(width: 44, height: 44)` | touch target | #25 | keep | fine | 44pt minimum — keep. Walked at all six iPhone cells: the close glyph stays inside its 44-point frame at XXL, AX3 and AX5 in both orientations and is never cut — the frame is a touch-target minimum and the glyph does not overflow it. Keep. |
| `ReadingFeature/Support/ControlPanel.swift:296` `.frame(width: 44, height: 44)` | touch target | #25 | keep | fine | 44pt minimum — keep. Same result for the lower bar's close control: the glyph never overflows its 44-point frame at any sampled size in either orientation. Keep. |
| `DownloadsFeature/DownloadsView+Subviews.swift:145` `.frame(width: 20, height: 20)` | progress spinner slot | #11, #12 | chrome — OK | blocked: no active transfer | Neither sweep simulator had an active or in-progress transfer, and the safety protocol forbids starting or altering a user-owned download solely to expose the spinner. |
| `DetailFeature/DetailView+CommentCells.swift:51` `.frame(width: 300, height: cardHeight)` | comment card (height is `@ScaledMetric`) | #14 | B10 — height scaled | finding:#17 | width still fixed at 300 — re-check at AX5 iPhone portrait. Confirmed at AX5 iPhone portrait: the 300-point width does not grow, so the card's body loses characters at every larger size while its height scales. |
| `SettingFeature/GeneralSetting/GeneralSettingView.swift:69` `.frame(width: 50)` | fixed-width control | #31 | fine | fine | The 50-pt frame wraps a labels-hidden switch, which carries no text; the switch renders at its fixed system size at AX5 in both orientations and the row label beside it wraps freely. |
| `SettingFeature/EhSetting/EhSettingView+Sections2.swift:44` `.frame(width: 10)` | spacer width | #38 | fine | fine | A 10-pt colour dot with no text; it neither grows nor clips at any sampled size. |
| `SettingFeature/EhSetting/EhSettingView+Sections2.swift:164` `.frame(width: 200)` | fixed-width control | #38 | fine | fine | re-check: a 200pt control at AX5 Walked at AX5 in both orientations: the segmented control's own labels are drawn at the system's capped size, so Auto / Small / Normal all read in full inside the 200-pt frame while the row label above wraps. |
| `SettingFeature/EhSetting/EhSettingView+Sections2.swift:177` `.frame(width: 200)` | fixed-width control | #38 | fine | fine | re-check: a 200pt control at AX5 Same result for the row-count control: 4 / 8 / 20 / 40 all render inside the 200-pt frame at AX5. |
| `SystemNotification/View+Toast.swift:57` `.frame(minHeight: 44)` | toast minimum height | #42 | fine | fine | A minimum, not a cap: the toast grows from its XXL height through AX3 and AX5, remains fully visible and keeps its tap target. The information loss is the subtitle's separate `lineLimit(1)` finding #31. |
| `AppComponents/StateViews.swift:49` `.frame(maxWidth: .infinity, minHeight: 50)` | state-view row minimum height | every list host | fine | fine | A minimum, not a cap: the empty Quick Search state grows to hold its multi-line title and explanation at AX5 without clipping, and remains reachable in both orientations. |

## D-25 re-sweep

Reserved for round 2. Rows are appended by plan **16-26**: every screen where round 2 adds a
visible element — a new glyph or shape for a non-colour indicator, or a contrast change that
alters a rendered element's size — is re-walked at XXL / AX3 / AX5 to close the staleness hole
exactly where it exists. Accessibility labels are not rendered, so the bulk of round 2 cannot
disturb round 1's verified layout (D-24).

| Screen | What round 2 changed | Cells re-walked | Status |
|---|---|---|---|
| _none yet_ | | | |

## Round-1 report

The full matrix is now closed: every one of its 504 device/orientation/size cells has a written
verdict or an explicit reachability disposition. The 33 findings below are the complete round-1
set. They are reported together at this boundary under D-02; no reflow implementation, patch,
diff, or work order is part of this report (D-01).

| #N | Screen(s) | Device/orientation/size cells | Description | Primary files (from the inventory) |
|---|---|---|---|---|
| 1 | #2 Home root | iPhone portrait XXL/AX3/AX5; iPhone landscape AX3/AX5; iPad portrait and landscape XXL/AX3/AX5 | The fixed-height hero card progressively removes its gallery title as type grows; only the opening word remains at iPhone portrait AX5, and even iPad landscape loses the tail. This is the D-13 hero-carousel case. | `HomeFeature/HomeView+Sections.swift`; `HomeFeature/GalleryCardCell.swift` |
| 2 | #2 Home root | iPhone portrait AX5 | The neighbouring hero card's artwork overlaps the focused card's title and rating while the focused cover is cut at the leading edge, leaving separate contents unreadable. | `HomeFeature/HomeView+Sections.swift`; `HomeFeature/GalleryCardCell.swift` |
| 3 | #2 Home root; #7 Toplists | iPhone portrait and landscape AX3/AX5; iPad portrait XXL/AX3/AX5; iPad landscape AX3/AX5 | Fixed ranking rows ellipsise the gallery title and then the uploader; at iPhone portrait AX5 the uploader disappears entirely. | `HomeFeature/HomeView+Sections.swift`; `HomeFeature/GalleryRankingCell.swift`; `HomeFeature/Toplists/ToplistsView.swift` |
| 4 | #3–#7 pushed lists; #10 Search results; #32 Activity Logs | iPhone #3 portrait XXL/AX3/AX5; iPhone #4–#7 and #10 portrait AX3/AX5; iPhone #32 portrait AX3 and landscape AX5; iPad #3 portrait AX3 and landscape AX5; iPad #4/#7 portrait AX3 and landscape AX3/AX5; iPad #10 portrait AX3/AX5 and landscape AX5; iPad #32 portrait/landscape AX5 | The filter/search capsule non-monotonically loses both its glyph and visible placeholder/query, leaving an unlabeled empty shape even though the surrounding screen remains usable. | `HomeFeature/Frontpage/FrontpageView.swift`; `HomeFeature/Popular/PopularView.swift`; `HomeFeature/Watched/WatchedView.swift`; `HomeFeature/History/HistoryView.swift`; `HomeFeature/Toplists/ToplistsView.swift`; `SearchFeature/SearchView.swift`; `SettingFeature/AppActivityLogs/AppActivityLogsView.swift` |
| 5 | #3–#7 and #17 gallery-list hosts | iPhone portrait XXL/AX3/AX5 and landscape AX3/AX5; iPad #3 portrait AX5 | The gallery title's line cap removes its tail as type grows; at AX5 portrait some titles run off the edge and are cut mid-glyph. | `GalleryListComponents/Cells/GalleryDetailCell.swift`; `HomeFeature/Frontpage/FrontpageView.swift`; `HomeFeature/Popular/PopularView.swift`; `HomeFeature/Watched/WatchedView.swift`; `HomeFeature/History/HistoryView.swift`; `HomeFeature/Toplists/ToplistsView.swift`; `DetailFeature/DetailSearch/DetailSearchView.swift` |
| 6 | #3–#7, #12 and #17 | iPhone portrait AX3/AX5; iPad Inspector portrait and landscape AX5 | The row's right-hand metadata does not reflow: language, page-count and timestamp characters are cut by the edge; at AX5 the count can lose every digit, and the iPad Inspector timestamp loses its time. | `GalleryListComponents/Cells/GalleryDetailCell.swift`; `GalleryListComponents/DownloadBadgeLabel.swift`; `DownloadsFeature/DownloadsView+Subviews.swift` |
| 7 | #3–#7 and #32 | iPhone portrait AX3/AX5 | Pushed-screen large titles ellipsise at AX3 and disappear at AX5; Activity Logs retains a title but shortens it at both accessibility sizes. | `HomeFeature/Frontpage/FrontpageView.swift`; `HomeFeature/Popular/PopularView.swift`; `HomeFeature/Watched/WatchedView.swift`; `HomeFeature/History/HistoryView.swift`; `HomeFeature/Toplists/ToplistsView.swift`; `SettingFeature/AppActivityLogs/AppActivityLogsView.swift` |
| 8 | #3–#7 and #17 gallery-list hosts | iPhone portrait AX5 | The cover thumbnail collapses to a narrow sliver and is partly pushed off-screen, removing the row's only visual identifier. | `GalleryListComponents/Cells/GalleryDetailCell.swift`; `HomeFeature/Frontpage/FrontpageView.swift`; `HomeFeature/Popular/PopularView.swift`; `HomeFeature/Watched/WatchedView.swift`; `HomeFeature/History/HistoryView.swift`; `HomeFeature/Toplists/ToplistsView.swift`; `DetailFeature/DetailSearch/DetailSearchView.swift` |
| 9 | #5, #6 and #17 gallery-list hosts | iPhone portrait XXL and above | A long uploader becomes ellipsised as soon as it shares the line with the language value, despite both reading fully at the baseline. | `GalleryListComponents/Cells/GalleryDetailCell.swift`; `HomeFeature/Watched/WatchedView.swift`; `HomeFeature/History/HistoryView.swift`; `DetailFeature/DetailSearch/DetailSearchView.swift` |
| 10 | #9 Search root | iPhone portrait and landscape XXL/AX3/AX5; iPad portrait and landscape AX3/AX5 | Fixed Recently Seen cells clip titles and covers, overflow their slots, and at the largest sizes overlap the section heading or neighbouring cards. | `SearchFeature/SearchRootView.swift`; `SearchFeature/SearchRootView+Keywords.swift`; `SearchFeature/GalleryHistoryCell.swift` |
| 11 | #11 Downloads root | iPhone portrait AX5 | The fixed-width delete-confirmation popover cuts its destructive-action explanation mid-sentence and provides no scroll route to the hidden tail. | `DownloadsFeature/DownloadsView.swift`; `DownloadsFeature/DownloadsView+Subviews.swift`; `DownloadsFeature/DownloadRowFeature.swift` |
| 12 | All gallery-list hosts in Thumbnail mode | iPhone portrait AX5 | The thumbnail cell abbreviates the category into ambiguity, ellipsises the title and count, and sends the trailing column and star row beyond the screen edge. | `GalleryListComponents/Cells/GalleryThumbnailCell.swift`; `AppComponents/CategoryView.swift` |
| 13 | #14 Gallery Detail | iPhone portrait XXL/AX3/AX5 | The header title's three-line cap removes progressively more text, and the uploader beneath it ellipsises from AX3. Tapping can expand the title, but the default rendering still provides less information. | `DetailFeature/DetailView+HeaderSection.swift` |
| 14 | #14 Gallery Detail | iPhone portrait XXL/AX3/AX5; iPhone landscape AX3/AX5 | Fixed-fraction stats columns first abbreviate their labels, then lose their values and clip the rating stars; a four-digit count becomes `1…` and a 4.50 rating is no longer represented faithfully. This is the D-13 stats-strip case. | `DetailFeature/DetailView+Subviews.swift` |
| 15 | #14 Gallery Detail | iPhone portrait AX3/AX5 | Long tags extend past the trailing screen edge and are cut mid-glyph without wrapping or an ellipsis. This is the D-13 long-tag case. | `DetailFeature/DetailView+Subviews.swift`; `AppComponents/TagCloudView.swift` |
| 16 | #14 Gallery Detail comment cards | iPhone portrait and landscape XXL/AX3/AX5 | A fixed 300-point card ellipsises its author and timestamp at every sampled size; the paired 0.75 shrink engages first but does not preserve the content. | `DetailFeature/DetailView+CommentCells.swift` |
| 17 | #14 Gallery Detail comment cards | iPhone portrait AX3/AX5; iPhone landscape AX5 | The same fixed-width card shows progressively fewer body characters as type grows; at landscape AX5 even a previously complete short comment loses its final word. | `DetailFeature/DetailView+CommentCells.swift` |
| 18 | #16 Comments | iPhone portrait XXL/AX3/AX5; iPhone landscape AX5 | Author, vote score and timestamp stay on one line, so timestamps lose minutes first and authors collapse to a few characters; the 0.75 shrink does not prevent the loss. | `DetailFeature/Comments/CommentsView.swift`; `DetailFeature/Components/PostCommentView.swift` |
| 19 | #18 Gallery Infos | iPhone portrait AX3/AX5 | Three-line value caps remove the tokens from Archive and Torrent URLs at AX3 and truncate additional URLs, the parent link, gallery title and identifiers at AX5. | `DetailFeature/GalleryInfos/GalleryInfosView.swift` |
| 20 | #19 Archives | iPhone portrait and landscape AX3/AX5 | Fixed archive cards lose the size and price needed to choose an archive, make resolution names indistinguishable, draw text outside their borders, and truncate account balances. | `DetailFeature/Archives/ArchivesView.swift` |
| 21 | #20 Torrents | iPhone portrait AX3/AX5 | Four fixed meta slots destroy the seed, leech, download and size values; at AX5 only their glyphs remain while uploader and timestamp are also shortened. | `DetailFeature/Torrents/TorrentsView.swift` |
| 22 | #25 Reading control panel | iPhone portrait AX3/AX5 | The page indicator does not wrap: its capsule shrinks to an ellipsis at AX3 and a blank two-point sliver at AX5, removing both current and total page state. This is the D-13 reader-counter case. | `ReadingFeature/Support/ControlPanel.swift` |
| 23 | #23 Detail download confirmation | iPhone landscape AX3/AX5 | The alert cuts its safety explanation at AX3; at AX5 both the message and Cancel control lie outside the visible/tappable bounds, leaving Delete as the only visible action. | `DetailFeature/DetailReducer+Download.swift`; `DetailFeature/DetailView.swift` |
| 24 | #29 Account | iPhone portrait XXL/AX3/AX5; iPhone landscape AX3/AX5 | Cookie rows allow their credential values to collapse while labels wrap; at AX5 portrait every value is reduced to only three or four characters plus an ellipsis. | `SettingFeature/AccountSetting/AccountSettingView.swift` |
| 25 | #32 Activity Logs | iPhone portrait AX3/AX5 and landscape AX5; iPad portrait and landscape AX3/AX5 | The single-line category chip removes the subsystem name while the adjacent timestamp is allowed to wrap, making similarly prefixed sources indistinguishable. | `SettingFeature/AppActivityLogs/AppActivityLogsView.swift` |
| 26 | #32 Activity Logs | iPhone portrait AX3/AX5 and landscape AX5; iPad portrait AX5 | The Runs menu stops drawing the selected-run checkmark although the underlying selection and accessibility-tree checkmark remain. | `SettingFeature/AppActivityLogs/AppActivityLogsView.swift` |
| 27 | #38 EhSetting | iPhone portrait XXL/AX3/AX5; iPhone landscape AX5 | The three Excluded Languages column headings refuse to wrap, overlap into one string and no longer identify their radio columns. | `SettingFeature/EhSetting/EhSettingView.swift`; `SettingFeature/EhSetting/EhSettingView+Sections3.swift` |
| 28 | #38 EhSetting | iPhone portrait AX5 | Consecutive Multi-Page Viewer rows do not grow for multi-line labels and picker values; their text crosses separators, overlaps neighbours and becomes unreadable. | `SettingFeature/EhSetting/EhSettingView.swift`; `SettingFeature/EhSetting/EhSettingView+Sections1.swift`; `SettingFeature/EhSetting/EhSettingView+Sections2.swift`; `SettingFeature/EhSetting/EhSettingView+Sections3.swift` |
| 29 | #39 Filters | iPhone and iPad portrait/landscape XXL/AX3/AX5 | Fixed/adaptive category columns keep one-line names too narrow; names are already ellipsised at XXL and collapse to ambiguous fragments at AX5 on both devices. | `FiltersFeature/FiltersView.swift`; `AppComponents/CategoryView.swift` |
| 30 | #40 Quick Search | iPhone portrait XXL/AX3/AX5; iPhone landscape AX5 | A saved word's one-line name cap truncates first in Edit mode, then in the ordinary row; at AX3 portrait Edit mode also truncates its content. | `QuickSearchFeature/QuickSearchView.swift` |
| 31 | #42 Error surface | iPhone portrait XXL/AX3/AX5 and landscape AX3/AX5; iPad portrait AX3/AX5 and landscape AX5 | The toast's one-line subtitle progressively removes the unsupported-link explanation while its title and the separate scrollable error-detail sheet remain complete. | `AppComponents/ErrorInfoView.swift`; `SystemNotification/ToastMessageView.swift`; `SystemNotification/View+Toast.swift` |
| 32 | #3 Frontpage | iPad portrait AX3/AX5 | A long regular-width category badge expands over the timestamp on the same stats line, painting the two values on top of each other. | `HomeFeature/Frontpage/FrontpageView.swift`; `GalleryListComponents/Cells/GalleryDetailCell.swift` |
| 33 | #30 Login | iPad portrait AX5; iPad landscape AX5 | The enlarged Login heading overlaps the Username label in both modal orientations, so the two strings cannot be read independently. | `SettingFeature/Login/LoginView.swift` |

### Suggested patterns (D-01 amendment, owner aid)

Per the owner's 2026-08-24 amendment to D-01: each finding below is paired with the reflow
pattern(s) from `16-REFLOW-PATTERNS.md` — a name-free catalogue extracted from a reference
project's Dynamic Type history — that the agent judges applicable. These are prose suggestions
only; no diff, patch, or work order accompanies them, and the owner remains free to fix
differently. Pattern ids (P-01…P-15) refer to that catalogue.

| #N | Pattern(s) | Applying it here |
|---|---|---|
| 1 | P-08 + P-10 | Let the hero card's height step up by `switch dynamicTypeSize` tiers instead of staying fixed, and treat `lineLimit(4)` as a per-tier budget; the title then keeps its tail because the card grows with it. |
| 2 | P-08 | Same root as #1: once the card owns a height that fits its content tier, the neighbour can no longer be painted over the focused card. Fix #1 first and re-check. |
| 3 | P-09 + P-08 | The ranking row is an icon-row: keep rank number and cover at intrinsic size, and at accessibility sizes give the title/uploader the full width below them; drop the fixed row height (stepped if a bound is wanted). |
| 4 | P-05 + P-04 | The capsule's glyph+placeholder vanish because the fixed-height capsule clips its grown content; remove the fixed height (flexible frames sit outside any `ViewThatFits` candidates), and if space is tight at AX sizes drop the magnifying-glass glyph, keep the text. |
| 5 | P-10 + P-04 | Reference `lineLimit` policy: user text gets `nil` (or a raised budget) at accessibility sizes; a `dynamicTypeSize <= .accessibility1`-style gate can keep today's 3-line look below the threshold and lift the cap above it. |
| 6 | P-02 | The trailing language/pages/date column is a space-between stat set: at accessibility sizes it stops sharing the row and stacks beneath the text column, leading-aligned, each pair on its own line — the reference's `hSpaceBetween` degradation, nested so captions fall stepwise. |
| 7 | — (system) | No catalogue pattern: the large-title band is navigation-bar behaviour. Suggest gating `navigationBarTitleDisplayMode(.inline)` at accessibility sizes (the catalogue's cross-cutting rule reserves explicit size branches for moves/removals like this); verify against a minimal repro first in case it is an iOS regression. |
| 8 | P-09 | Exactly the icon-row fallback: the cover keeps intrinsic size; when the HStack no longer fits, the text takes full width beneath the cover instead of compressing it into a sliver. |
| 9 | P-02 | Uploader + language are a stat pair sharing a line; at accessibility sizes stack them (uploader above, language below) rather than letting the pair ellipsise the uploader. |
| 10 | P-08 + P-07 | Step the Recently-Seen card size by type tier so contents fit, or collapse the horizontal strip into a single-column vertical list at accessibility sizes, as the reference collapses wide layouts. |
| 11 | P-11 | The fixed-width popover should become a measured, scroll-on-demand surface: native confirmation presentation already scrolls its message — prefer it (per the project's native-surfaces rule); if the custom popover stays, measure content height and enable scrolling past the fit point. |
| 12 | P-07 + P-10 | At accessibility sizes reduce the thumbnail grid's column count so each cell widens, and give the category/title budgets instead of single lines; the trailing column then stays on-screen. |
| 13 | P-10 | Raise or lift the header title's 3-line cap at accessibility sizes (user text → `nil` per the reference policy) and let the uploader wrap; the tap-to-expand affordance stays as a bonus, not the only route. |
| 14 | P-02 + P-04 | The stats strip is the catalogue's canonical case: keep the horizontal fixed-fraction strip below the gate, and above it let each caption+value pair stack and the pairs flow vertically; values never abbreviate because each pair owns its line. |
| 15 | P-10 | Let a chip's text wrap inside the chip with a small budget (the reference wraps badges with a 3-line budget) instead of extending past the trailing edge; the cloud already flows chips to new rows. |
| 16 | P-08 + P-11 | Step the comment card's width/height by type tier (instead of fixed 300 pt) and make the card scroll once content exceeds the measured tier; removing the paired 0.75 shrink then satisfies D-14 without loss. |
| 17 | P-08 + P-11 | Same card, same fix as #16 — body characters return as the card's budget grows with the tier. |
| 18 | P-02 | Author / score / timestamp are a stat line: stack at accessibility sizes (author first, score+time as a second line) so the timestamp keeps its minutes and the author its characters. |
| 19 | P-03 + P-10 | Info rows are title……value rows: flexible title, intrinsic value, and a per-row vertical flip when the value no longer fits; URLs and identifiers get `nil`/raised budgets at accessibility sizes. |
| 20 | P-07 + P-02 | Collapse the archive card grid to one column at accessibility sizes, and render size/price as stacking stat pairs inside each card so the purchase-deciding values survive. |
| 21 | P-02 + P-04 | The four meta slots are four caption+value pairs: below the gate keep today's compact row; above it let the pairs stack two-by-two or vertically — glyphs keep their numbers because each pair owns its space. |
| 22 | P-12 | The reader bar is the catalogue's one adaptive bar: give slots a `@ScaledMetric` minimum width, measure available width, and overflow what no longer fits into a menu; the page counter keeps intrinsic size (`fixedSize`) instead of compressing to a sliver. |
| 23 | P-11 | If this is a custom alert, replace with the native alert (system alerts scroll their message); if native behaviour still clips at landscape AX5, present as a measured scroll-on-demand sheet at accessibility sizes. Cancel must never be the casualty. |
| 24 | P-03 | Cookie rows are title……value rows with the priorities inverted today: give the value intrinsic size and the label flexibility, and flip the row vertical at accessibility sizes so full values render under their labels. |
| 25 | P-10 | Give the subsystem chip a wrap budget (reference logs use generous budgets) instead of one line; the timestamp already wraps — let the chip match. |
| 26 | P-06 | Make the run picker a native control (`Picker` in a `Menu`): the system draws selection state at every size; hand-drawn checkmark rows are exactly what the reference deleted in its second try. |
| 27 | P-07 | The three-column radio header cannot survive AX widths: collapse to one row per language with its own control at accessibility sizes (explicit size branch — a move/removal, the catalogue's sanctioned use). |
| 28 | P-06 | Let the Form rows grow: remove fixed row heights and keep native `LabeledContent`-style rows — system form rows reflow multi-line labels and picker values on their own; the overlap is the fixed height fighting grown text. |
| 29 | P-07 + P-10 | Fewer category columns at accessibility sizes and a wrap budget for names; note round 2 (plan 16-15) rebuilds `CategoryCell` — coordinate so this fix lands once, there. |
| 30 | P-10 + P-03 | Saved-word name and content get budgets/`nil` at accessibility sizes; the edit-mode row is a title……value row that can flip vertical per-row. |
| 31 | P-10 | The toast subtitle gets a small budget (2–3 lines) at accessibility sizes instead of one line; the toast grows downward, which the reference treats as fine. |
| 32 | P-02 | Badge and timestamp are painted over each other — make them a stacking pair (badge above, timestamp below, trailing-aligned) rather than sharing anchored positions on one line. |
| 33 | — (structural) | No catalogue pattern: the heading and field overlap from fixed spacing/offsets in the login layout; replace the fixed offsets with flowing stack spacing so the heading pushes the form down as it grows. |

Cross-cutting, from the same history: the five D-14 `minimumScaleFactor` sites map onto the
patterns above (#6→P-02, #13/#16→P-08/P-11, #18→P-02); the reference stripped every shrink the
same release it introduced the replacing reflow, which is exactly D-14's target-zero.

### D-13 dispositions requested

Each Disposition cell is intentionally blank for the owner. Valid responses are `fixed` or
`accepted (reason)`.

| D-13 item | iPhone observation | iPad observation | Disposition |
|---|---|---|---|
| 1. Detail stats-strip abbreviation | Reproduced as finding #14 in portrait XXL/AX3/AX5 and landscape AX3/AX5; labels abbreviate first, then values disappear and stars clip. | All six live-Detail cells are blocked because `IPAD_LOGIN=none`; the iPad modal layout was not inferred. |  |
| 2. Long-tag right-edge clip | Reproduced as finding #15 at portrait AX3/AX5; the same tags remain complete in landscape. | All six live-Detail cells are blocked because `IPAD_LOGIN=none`; the regular-width tag cloud was not inferred. |  |
| 3. Reader total-page counter wrap | The prediction did not reproduce: finding #22 shows the counter vanishing at portrait AX3/AX5 instead of wrapping; landscape remains complete. | All six control-panel cells are blocked because `IPAD_LOGIN=none`; the regular-width panel was not inferred. |  |
| 4. Favorites trailing-glyph clip | The glyphs do not clip. The adjacent numeric page count is what disappears, tracked by finding #6. | All six Favorites cells are blocked because `IPAD_LOGIN=none`; no glyph verdict was inferred. |  |
| 5. Hero-carousel title truncation | Reproduced as finding #1 from XXL/AX3/AX5 portrait and AX3/AX5 landscape; AX5 portrait also overlaps, tracked separately by #2. | Reproduced as finding #1 in all six cells, including landscape XXL. |  |

Under D-03, a genuine reader-counter **wrap** would not be degradation, so `accepted` on that
rule alone would be legitimate. The observed counter does not wrap — it disappears — and the
owner decides the actual disposition.

### D-04 outcome

The 48 checklist rows close as **16 `fine`**, **31 `finding:#N`**, and **1 `blocked`**. No D-04
row remains pending. The one blocked row is the 20-point active-transfer spinner and is repeated
under Blocked rows.

Twenty-three Phase-10 `fine`/`B3 fine` line-limit sites became findings under the strict D-04
reading:

| Formerly accepted site | Round-1 outcome |
|---|---|
| `SettingFeature/EhSetting/EhSettingView+Sections3.swift:131` | finding #27 |
| `SettingFeature/AppActivityLogs/AppActivityLogsView.swift:224` | finding #25 |
| `ReadingFeature/Support/ControlPanel.swift:176` | finding #22 |
| `HomeFeature/GalleryRankingCell.swift:39` | finding #3 |
| `SearchFeature/GalleryHistoryCell.swift:32` | finding #10 |
| `GalleryListComponents/Cells/GalleryDetailCell.swift:107` | finding #9 |
| `GalleryListComponents/Cells/GalleryDetailCell.swift:152` | finding #6 |
| `GalleryListComponents/Cells/GalleryDetailCell.swift:163` | finding #6 |
| `GalleryListComponents/DownloadBadgeLabel.swift:19` | finding #6 |
| `GalleryListComponents/Cells/GalleryThumbnailCell.swift:99` | finding #12 |
| `AppComponents/TagCloudView.swift:122` | finding #15 |
| `AppComponents/CategoryView.swift:31` | finding #12 |
| `AppComponents/CategoryView.swift:87` | finding #29 |
| `DetailFeature/DetailView+CommentCells.swift:37` | finding #16 |
| `DetailFeature/DetailView+CommentCells.swift:43` | finding #16 |
| `DetailFeature/DetailView+Subviews.swift:99` | finding #14 |
| `DetailFeature/DetailView+Subviews.swift:116` | finding #14 |
| `DetailFeature/DetailView+HeaderSection.swift:324` | finding #13 |
| `DetailFeature/Comments/CommentsView.swift:166` | finding #18 |
| `DetailFeature/Archives/ArchivesView.swift:143` | finding #20 |
| `DetailFeature/Archives/ArchivesView.swift:202` | finding #20 |
| `QuickSearchFeature/QuickSearchView.swift:40` | finding #30 |
| `HomeFeature/GalleryCardCell.swift:73` (`lineLimit(4)`) | finding #1 |

Two other previously accepted outcomes also failed the strict walk: the B1-fixed toast subtitle
at `SystemNotification/ToastMessageView.swift:70` is finding #31, and the two formerly
`shrink-absorbed` torrent meta sites at `DetailFeature/Torrents/TorrentsView.swift:110,124` are
finding #21. Four formerly fine `minimumScaleFactor` rows are finding-bearing D-14 removals
(#6, #16 and #18); the fifth is visually fine but is still banned and listed below.

### D-14 sites

Live grep at the report boundary returns exactly five sites:

| Site at current HEAD | Factor | Round-1 observation |
|---|---:|---|
| `AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift:155` | 0.75 | Paired stats value still loses content; finding #6. |
| `AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift:166` | 0.75 | Paired stats value still loses content; finding #6. |
| `AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift:73` | 0.72 | The anticipated D-15 collision did not visibly engage for the seven-character baseline category, and the badge stayed complete in the sampled cells; default-size parity nevertheless remains binding. |
| `AppPackage/Sources/DetailFeature/DetailView+CommentCells.swift:42` | 0.75 | Shrink visibly engages and still ellipsises the author; finding #16. |
| `AppPackage/Sources/DetailFeature/Comments/CommentsView.swift:165` | 0.75 | Shrink engages and still loses author/timestamp content; finding #18. |

D-15 makes `.large` appearance parity higher priority than merely deleting a modifier. The
captured baselines under `$HOME/Library/Caches/ehpanda-phase16/d15-baseline/` remain the comparison
authority, especially for the 0.72 Detail-header category site originally identified as the
likely collision. The `no_minimum_scale_factor` SwiftLint rule lands in plan 16-12 only after
the live count reaches **0**.

### Blocked rows

Each entry below covers all six orientation/size cells for the named device and screen unless
stated otherwise; together they enumerate every `blocked:` or `n/a:` Matrix row, plus the one
blocked D-04 row.

| Device / screen | Cells | Status | Reason |
|---|---|---|---|
| iPhone #21 Tag Detail | portrait + landscape × XXL/AX3/AX5 | blocked | Its only entry requires a non-empty translated tag description; the English translation database contains none. |
| iPhone #22 NewDawn | portrait + landscape × XXL/AX3/AX5 | blocked | The server-issued once-per-day greeting was not presented and cannot be summoned. |
| iPhone #27 Live Text overlay | portrait + landscape × XXL/AX3/AX5 | n/a | It draws no app-visible text; the visible selection/translation UI is system-owned. |
| iPhone #30 Login | portrait + landscape × XXL/AX3/AX5 | blocked | The preserved logged-in session cannot expose the native form without a forbidden logout. |
| iPad #5 Watched | portrait + landscape × XXL/AX3/AX5 | blocked | `IPAD_LOGIN=none`; no credential was entered. |
| iPad #8 Favorites | portrait + landscape × XXL/AX3/AX5 | blocked | `IPAD_LOGIN=none`; no credential was entered. |
| iPad #13 FolderManager | portrait + landscape × XXL/AX3/AX5 | blocked | The folder-management route is login-gated and `IPAD_LOGIN=none`. |
| iPad #14 Gallery Detail | portrait + landscape × XXL/AX3/AX5 | blocked | Live Detail requires the missing iPad session; no iPhone modal verdict was inferred. |
| iPad #15 Previews | portrait + landscape × XXL/AX3/AX5 | blocked | Its route starts from unavailable live Detail. |
| iPad #16 Comments | portrait + landscape × XXL/AX3/AX5 | blocked | Live Comments requires the missing session; no post or vote surface was opened. |
| iPad #17 Detail Search | portrait + landscape × XXL/AX3/AX5 | blocked | Its route starts from unavailable live Detail. |
| iPad #18 Gallery Infos | portrait + landscape × XXL/AX3/AX5 | blocked | Its route starts from unavailable live Detail. |
| iPad #19 Archives | portrait + landscape × XXL/AX3/AX5 | blocked | Archives is login-gated; nothing was purchased. |
| iPad #20 Torrents | portrait + landscape × XXL/AX3/AX5 | blocked | Torrents is login-gated; no torrent or share action was opened. |
| iPad #21 Tag Detail | portrait + landscape × XXL/AX3/AX5 | blocked | The English-description gate makes the sheet unreachable, and the missing live Detail session is an additional barrier. |
| iPad #22 NewDawn | portrait + landscape × XXL/AX3/AX5 | blocked | The server-issued greeting was not presented and cannot be summoned. |
| iPad #23 Detail download confirmation | portrait + landscape × XXL/AX3/AX5 | blocked | The live Detail route is unavailable; the preserved download was untouched. |
| iPad #24 Reading | portrait + landscape × XXL/AX3/AX5 | blocked | Live Reading requires the missing iPad session; no saved download was opened or changed. |
| iPad #25 Reading control panel | portrait + landscape × XXL/AX3/AX5 | blocked | Its regular-width layout requires unavailable live Reading. |
| iPad #26 Reading Setting sheet | portrait + landscape × XXL/AX3/AX5 | blocked | The Group-B entry point is the unavailable live Reading control panel, though the Setting-root version is covered as #34. |
| iPad #27 Live Text overlay | portrait + landscape × XXL/AX3/AX5 | blocked | Its entry point is the unavailable live Reading control panel. |
| iPad #38 EhSetting | portrait + landscape × XXL/AX3/AX5 | blocked | Native EhSetting sections require a logged-in account and `IPAD_LOGIN=none`. |
| D-04 progress spinner (`DownloadsView+Subviews.swift:145`) | #11/#12 active-transfer state | blocked | Neither simulator had an active transfer, and starting or altering a user-owned download solely for evidence was forbidden. |

The iPad no-session rows are an explicit owner gap: either create the session manually before
re-verification (`IPAD_LOGIN=present`) or accept the listed rows as a known coverage gap.

### Evidence

All paths below are **chat-only before evidence** under the out-of-repository evidence root. No
image is tracked by git.

| #N | Representative before image path(s) | What the image shows |
|---|---|---|
| 1 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-AX5-2-top.png`; `$HOME/Library/Caches/ehpanda-phase16/sweep/ipad-portrait-ax5-2-top.png` | Hero titles reduced to opening fragments at AX5 on both devices. |
| 2 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-AX5-2-top.png` | Neighbouring artwork painted over the focused hero title/rating. |
| 3 | `$HOME/Library/Caches/ehpanda-phase16/sweep/ipad-portrait-ax5-7-top.png` | Ranking title/uploader loss in Toplists. |
| 4 | `$HOME/Library/Caches/ehpanda-phase16/sweep/ipad-portrait-ax3-3-top.png` | Filter capsule present with neither glyph nor text. |
| 5 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-XXL-3-top.png` | Long gallery-row title already losing its tail at XXL. |
| 6 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-AX5-3-top.png` | Right-side language/count/date values cut by the edge. |
| 7 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-AX5-7-top.png` | Blank navigation-title band at AX5. |
| 8 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-AX5-3-top.png` | Cover squeezed into an off-screen sliver. |
| 9 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-XXL-5-top.png` | Uploader ellipsised while its paired language remains. |
| 10 | `$HOME/Library/Caches/ehpanda-phase16/sweep/ipad-portrait-ax5-9-top.png` | Recently Seen contents overflowing their fixed cards. |
| 11 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-AX5-11-deletedialog.png` | Delete explanation cut inside the fixed popover. |
| 12 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-AX5-thumbnaillayout.png` | Thumbnail-grid text, category and trailing column lost. |
| 13 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-AX5-14-top.png` | Detail header title/uploader shortened at AX5. |
| 14 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-AX5-14-top.png` | Stats labels and values collapsed with clipped stars. |
| 15 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-AX5-14-mid.png` | Tags cut at the trailing screen edge. |
| 16 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-AX5-14-bottom.png` | Fixed-width comment card with shortened author/date. |
| 17 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-AX5-14-bottom.png` | The same card showing fewer body characters. |
| 18 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-AX5-16-bottom.png` | Comment author and timestamp reduced to fragments. |
| 19 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-AX5-18-mid.png` | Gallery-info URLs cut before their identifying tails. |
| 20 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-landscape-AX5-19-top.png` | Archive cards reduced to slivers beneath overlapping funds. |
| 21 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-AX5-20-top.png` | Torrent meta glyphs shown with no numeric values. |
| 22 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-AX5-25-top.png` | Reader page indicator collapsed to a blank sliver. |
| 23 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-landscape-AX5-23-top.png` | Detail alert showing Delete without visible message or Cancel. |
| 24 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-ax5-29-top.png` | Cookie values reduced to short ellipsised fragments. |
| 25 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-ax3-32-top.png` | Activity-log subsystem chip ellipsised. |
| 26 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-ax3-32-runmenu.png` | Runs menu lacking its visible selection tick. |
| 27 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-landscape-AX5-38-langheader.png` | Excluded Languages headings overlapped into one string. |
| 28 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-AX5-38-segmented.png` | Multi-Page Viewer labels and values painted across neighbouring rows. |
| 29 | `$HOME/Library/Caches/ehpanda-phase16/sweep/ipad-portrait-AX5-39-top.png` | Category names collapsed to ellipsised fragments. |
| 30 | `$HOME/Library/Caches/ehpanda-phase16/sweep/iphone-portrait-ax5-40-top.png` | Saved Quick Search name/content truncated. |
| 31 | `$HOME/Library/Caches/ehpanda-phase16/sweep/ipad-portrait-AX5-42-toast.png` | Toast subtitle reduced while its title remains. |
| 32 | `$HOME/Library/Caches/ehpanda-phase16/sweep/ipad-portrait-ax5-3-top.png` | Category badge painted over the adjacent timestamp. |
| 33 | `$HOME/Library/Caches/ehpanda-phase16/sweep/ipad-portrait-AX5-30-top.png` | Login heading overlapping the Username label. |
