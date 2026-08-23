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
| `agent-device orientation landscape-left` / `portrait` | `sim-use gesture rotate-cw --angle 90 --device <UDID>` / `rotate-ccw`; verify via the `App:` header tag in `sim-use ui` |
| `agent-device press <alias>` | `sim-use tap --label '…' --device <UDID>` — re-run `ui` before every `@N` tap; disambiguate with `--element-type` / `--frame minY=0.7r` (tab bar) |
| `xcrun simctl ui <UDID> content_size …` | unchanged — this is `simctl`, not a driver verb |

`agent-device` 0.20.8 stays installed as a fallback; a plan that uses it for something `sim-use`
cannot do records which command and why.

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
| 1 | Tab bar shell | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 1 | Tab bar shell | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 1 | Tab bar shell | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 1 | Tab bar shell | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 1 | Tab bar shell | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 1 | Tab bar shell | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 2 | Home root | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 2 | Home root | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 2 | Home root | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 2 | Home root | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 2 | Home root | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 2 | Home root | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 3 | Home › Frontpage | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 3 | Home › Frontpage | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 3 | Home › Frontpage | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 3 | Home › Frontpage | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 3 | Home › Frontpage | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 3 | Home › Frontpage | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 4 | Home › Popular | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 4 | Home › Popular | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 4 | Home › Popular | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 4 | Home › Popular | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 4 | Home › Popular | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 4 | Home › Popular | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 5 | Home › Watched | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 5 | Home › Watched | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 5 | Home › Watched | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 5 | Home › Watched | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 5 | Home › Watched | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 5 | Home › Watched | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 6 | Home › History | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 6 | Home › History | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 6 | Home › History | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 6 | Home › History | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 6 | Home › History | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 6 | Home › History | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 7 | Home › Toplists | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 7 | Home › Toplists | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 7 | Home › Toplists | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 7 | Home › Toplists | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 7 | Home › Toplists | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 7 | Home › Toplists | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 8 | Favorites root | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 8 | Favorites root | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 8 | Favorites root | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 8 | Favorites root | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 8 | Favorites root | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 8 | Favorites root | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 9 | Search root | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 9 | Search root | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 9 | Search root | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 9 | Search root | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 9 | Search root | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 9 | Search root | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 10 | Search results | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 10 | Search results | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 10 | Search results | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 10 | Search results | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 10 | Search results | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 10 | Search results | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 11 | Downloads root | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 11 | Downloads root | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 11 | Downloads root | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 11 | Downloads root | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 11 | Downloads root | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 11 | Downloads root | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 12 | Downloads › Inspector sheet | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 12 | Downloads › Inspector sheet | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 12 | Downloads › Inspector sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 12 | Downloads › Inspector sheet | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 12 | Downloads › Inspector sheet | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 12 | Downloads › Inspector sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 13 | Downloads › Move-to-folder / FolderManager | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 13 | Downloads › Move-to-folder / FolderManager | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 13 | Downloads › Move-to-folder / FolderManager | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 13 | Downloads › Move-to-folder / FolderManager | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 13 | Downloads › Move-to-folder / FolderManager | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 13 | Downloads › Move-to-folder / FolderManager | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |

### iPhone — Group B (#14–#27) — plan 16-05

| # | Screen | Device | Orientation | Size | Status | Finding |
|---|---|---|---|---|---|---|
| 14 | Gallery Detail | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 14 | Gallery Detail | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 14 | Gallery Detail | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 14 | Gallery Detail | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 14 | Gallery Detail | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 14 | Gallery Detail | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 15 | Detail › Previews | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 15 | Detail › Previews | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 15 | Detail › Previews | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 15 | Detail › Previews | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 15 | Detail › Previews | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 15 | Detail › Previews | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 16 | Detail › Comments | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 16 | Detail › Comments | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 16 | Detail › Comments | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 16 | Detail › Comments | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 16 | Detail › Comments | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 16 | Detail › Comments | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 17 | Detail › Detail Search | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 17 | Detail › Detail Search | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 17 | Detail › Detail Search | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 17 | Detail › Detail Search | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 17 | Detail › Detail Search | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 17 | Detail › Detail Search | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 18 | Detail › Gallery Infos | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 18 | Detail › Gallery Infos | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 18 | Detail › Gallery Infos | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 18 | Detail › Gallery Infos | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 18 | Detail › Gallery Infos | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 18 | Detail › Gallery Infos | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 19 | Detail › Archives sheet | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 19 | Detail › Archives sheet | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 19 | Detail › Archives sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 19 | Detail › Archives sheet | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 19 | Detail › Archives sheet | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 19 | Detail › Archives sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 20 | Detail › Torrents sheet | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 20 | Detail › Torrents sheet | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 20 | Detail › Torrents sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 20 | Detail › Torrents sheet | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 20 | Detail › Torrents sheet | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 20 | Detail › Torrents sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 21 | Detail › Tag Detail sheet | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 21 | Detail › Tag Detail sheet | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 21 | Detail › Tag Detail sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 21 | Detail › Tag Detail sheet | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 21 | Detail › Tag Detail sheet | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 21 | Detail › Tag Detail sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 22 | Detail › NewDawn sheet | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 22 | Detail › NewDawn sheet | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 22 | Detail › NewDawn sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 22 | Detail › NewDawn sheet | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 22 | Detail › NewDawn sheet | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 22 | Detail › NewDawn sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 23 | Detail › download confirmation dialogs | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 23 | Detail › download confirmation dialogs | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 23 | Detail › download confirmation dialogs | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 23 | Detail › download confirmation dialogs | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 23 | Detail › download confirmation dialogs | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 23 | Detail › download confirmation dialogs | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 24 | Reading | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 24 | Reading | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 24 | Reading | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 24 | Reading | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 24 | Reading | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 24 | Reading | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 25 | Reading › Control panel | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 25 | Reading › Control panel | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 25 | Reading › Control panel | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 25 | Reading › Control panel | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 25 | Reading › Control panel | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 25 | Reading › Control panel | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 26 | Reading › Reading Setting sheet | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 26 | Reading › Reading Setting sheet | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 26 | Reading › Reading Setting sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 26 | Reading › Reading Setting sheet | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 26 | Reading › Reading Setting sheet | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 26 | Reading › Reading Setting sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 27 | Reading › Live Text overlay | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 27 | Reading › Live Text overlay | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 27 | Reading › Live Text overlay | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 27 | Reading › Live Text overlay | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 27 | Reading › Live Text overlay | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 27 | Reading › Live Text overlay | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |

### iPhone — Group C (#28–#42) — plan 16-06

| # | Screen | Device | Orientation | Size | Status | Finding |
|---|---|---|---|---|---|---|
| 28 | Setting root | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 28 | Setting root | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 28 | Setting root | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 28 | Setting root | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 28 | Setting root | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 28 | Setting root | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 29 | Setting › Account | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 29 | Setting › Account | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 29 | Setting › Account | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 29 | Setting › Account | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 29 | Setting › Account | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 29 | Setting › Account | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 30 | Setting › Login | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 30 | Setting › Login | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 30 | Setting › Login | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 30 | Setting › Login | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 30 | Setting › Login | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 30 | Setting › Login | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 31 | Setting › General | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 31 | Setting › General | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 31 | Setting › General | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 31 | Setting › General | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 31 | Setting › General | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 31 | Setting › General | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 32 | Setting › General › Activity Logs | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 32 | Setting › General › Activity Logs | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 32 | Setting › General › Activity Logs | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 32 | Setting › General › Activity Logs | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 32 | Setting › General › Activity Logs | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 32 | Setting › General › Activity Logs | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 33 | Setting › Appearance | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 33 | Setting › Appearance | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 33 | Setting › Appearance | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 33 | Setting › Appearance | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 33 | Setting › Appearance | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 33 | Setting › Appearance | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 34 | Setting › Reading | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 34 | Setting › Reading | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 34 | Setting › Reading | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 34 | Setting › Reading | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 34 | Setting › Reading | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 34 | Setting › Reading | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 35 | Setting › Download | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 35 | Setting › Download | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 35 | Setting › Download | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 35 | Setting › Download | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 35 | Setting › Download | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 35 | Setting › Download | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 36 | Setting › Laboratory | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 36 | Setting › Laboratory | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 36 | Setting › Laboratory | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 36 | Setting › Laboratory | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 36 | Setting › Laboratory | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 36 | Setting › Laboratory | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 37 | Setting › About | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 37 | Setting › About | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 37 | Setting › About | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 37 | Setting › About | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 37 | Setting › About | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 37 | Setting › About | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 38 | Setting › EhSetting | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 38 | Setting › EhSetting | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 38 | Setting › EhSetting | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 38 | Setting › EhSetting | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 38 | Setting › EhSetting | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 38 | Setting › EhSetting | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 39 | Filters sheet | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 39 | Filters sheet | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 39 | Filters sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 39 | Filters sheet | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 39 | Filters sheet | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 39 | Filters sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 40 | Quick Search sheet | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 40 | Quick Search sheet | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 40 | Quick Search sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 40 | Quick Search sheet | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 40 | Quick Search sheet | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 40 | Quick Search sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 41 | Date Seek picker | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 41 | Date Seek picker | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 41 | Date Seek picker | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 41 | Date Seek picker | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 41 | Date Seek picker | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 41 | Date Seek picker | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 42 | Error surface | iPhone | portrait | XXL (extra-extra-extra-large) | pending |  |
| 42 | Error surface | iPhone | portrait | AX3 (accessibility-extra-large) | pending |  |
| 42 | Error surface | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 42 | Error surface | iPhone | landscape | XXL (extra-extra-extra-large) | pending |  |
| 42 | Error surface | iPhone | landscape | AX3 (accessibility-extra-large) | pending |  |
| 42 | Error surface | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |

### iPad — Group A (#1–#13) — plan 16-07

| # | Screen | Device | Orientation | Size | Status | Finding |
|---|---|---|---|---|---|---|
| 1 | Tab bar shell | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 1 | Tab bar shell | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 1 | Tab bar shell | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 1 | Tab bar shell | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 1 | Tab bar shell | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 1 | Tab bar shell | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 2 | Home root | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 2 | Home root | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 2 | Home root | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 2 | Home root | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 2 | Home root | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 2 | Home root | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 3 | Home › Frontpage | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 3 | Home › Frontpage | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 3 | Home › Frontpage | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 3 | Home › Frontpage | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 3 | Home › Frontpage | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 3 | Home › Frontpage | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 4 | Home › Popular | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 4 | Home › Popular | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 4 | Home › Popular | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 4 | Home › Popular | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 4 | Home › Popular | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 4 | Home › Popular | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 5 | Home › Watched | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 5 | Home › Watched | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 5 | Home › Watched | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 5 | Home › Watched | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 5 | Home › Watched | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 5 | Home › Watched | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 6 | Home › History | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 6 | Home › History | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 6 | Home › History | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 6 | Home › History | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 6 | Home › History | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 6 | Home › History | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 7 | Home › Toplists | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 7 | Home › Toplists | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 7 | Home › Toplists | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 7 | Home › Toplists | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 7 | Home › Toplists | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 7 | Home › Toplists | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 8 | Favorites root | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 8 | Favorites root | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 8 | Favorites root | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 8 | Favorites root | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 8 | Favorites root | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 8 | Favorites root | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 9 | Search root | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 9 | Search root | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 9 | Search root | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 9 | Search root | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 9 | Search root | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 9 | Search root | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 10 | Search results | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 10 | Search results | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 10 | Search results | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 10 | Search results | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 10 | Search results | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 10 | Search results | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 11 | Downloads root | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 11 | Downloads root | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 11 | Downloads root | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 11 | Downloads root | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 11 | Downloads root | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 11 | Downloads root | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 12 | Downloads › Inspector sheet | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 12 | Downloads › Inspector sheet | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 12 | Downloads › Inspector sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 12 | Downloads › Inspector sheet | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 12 | Downloads › Inspector sheet | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 12 | Downloads › Inspector sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 13 | Downloads › Move-to-folder / FolderManager | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 13 | Downloads › Move-to-folder / FolderManager | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 13 | Downloads › Move-to-folder / FolderManager | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 13 | Downloads › Move-to-folder / FolderManager | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 13 | Downloads › Move-to-folder / FolderManager | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 13 | Downloads › Move-to-folder / FolderManager | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |

### iPad — Group B (#14–#27) — plan 16-08

| # | Screen | Device | Orientation | Size | Status | Finding |
|---|---|---|---|---|---|---|
| 14 | Gallery Detail | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 14 | Gallery Detail | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 14 | Gallery Detail | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 14 | Gallery Detail | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 14 | Gallery Detail | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 14 | Gallery Detail | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 15 | Detail › Previews | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 15 | Detail › Previews | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 15 | Detail › Previews | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 15 | Detail › Previews | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 15 | Detail › Previews | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 15 | Detail › Previews | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 16 | Detail › Comments | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 16 | Detail › Comments | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 16 | Detail › Comments | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 16 | Detail › Comments | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 16 | Detail › Comments | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 16 | Detail › Comments | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 17 | Detail › Detail Search | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 17 | Detail › Detail Search | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 17 | Detail › Detail Search | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 17 | Detail › Detail Search | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 17 | Detail › Detail Search | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 17 | Detail › Detail Search | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 18 | Detail › Gallery Infos | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 18 | Detail › Gallery Infos | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 18 | Detail › Gallery Infos | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 18 | Detail › Gallery Infos | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 18 | Detail › Gallery Infos | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 18 | Detail › Gallery Infos | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 19 | Detail › Archives sheet | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 19 | Detail › Archives sheet | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 19 | Detail › Archives sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 19 | Detail › Archives sheet | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 19 | Detail › Archives sheet | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 19 | Detail › Archives sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 20 | Detail › Torrents sheet | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 20 | Detail › Torrents sheet | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 20 | Detail › Torrents sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 20 | Detail › Torrents sheet | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 20 | Detail › Torrents sheet | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 20 | Detail › Torrents sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 21 | Detail › Tag Detail sheet | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 21 | Detail › Tag Detail sheet | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 21 | Detail › Tag Detail sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 21 | Detail › Tag Detail sheet | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 21 | Detail › Tag Detail sheet | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 21 | Detail › Tag Detail sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 22 | Detail › NewDawn sheet | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 22 | Detail › NewDawn sheet | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 22 | Detail › NewDawn sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 22 | Detail › NewDawn sheet | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 22 | Detail › NewDawn sheet | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 22 | Detail › NewDawn sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 23 | Detail › download confirmation dialogs | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 23 | Detail › download confirmation dialogs | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 23 | Detail › download confirmation dialogs | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 23 | Detail › download confirmation dialogs | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 23 | Detail › download confirmation dialogs | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 23 | Detail › download confirmation dialogs | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 24 | Reading | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 24 | Reading | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 24 | Reading | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 24 | Reading | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 24 | Reading | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 24 | Reading | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 25 | Reading › Control panel | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 25 | Reading › Control panel | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 25 | Reading › Control panel | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 25 | Reading › Control panel | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 25 | Reading › Control panel | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 25 | Reading › Control panel | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 26 | Reading › Reading Setting sheet | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 26 | Reading › Reading Setting sheet | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 26 | Reading › Reading Setting sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 26 | Reading › Reading Setting sheet | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 26 | Reading › Reading Setting sheet | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 26 | Reading › Reading Setting sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 27 | Reading › Live Text overlay | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 27 | Reading › Live Text overlay | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 27 | Reading › Live Text overlay | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 27 | Reading › Live Text overlay | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 27 | Reading › Live Text overlay | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 27 | Reading › Live Text overlay | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |

### iPad — Group C (#28–#42) — plan 16-09

| # | Screen | Device | Orientation | Size | Status | Finding |
|---|---|---|---|---|---|---|
| 28 | Setting root | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 28 | Setting root | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 28 | Setting root | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 28 | Setting root | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 28 | Setting root | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 28 | Setting root | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 29 | Setting › Account | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 29 | Setting › Account | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 29 | Setting › Account | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 29 | Setting › Account | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 29 | Setting › Account | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 29 | Setting › Account | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 30 | Setting › Login | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 30 | Setting › Login | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 30 | Setting › Login | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 30 | Setting › Login | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 30 | Setting › Login | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 30 | Setting › Login | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 31 | Setting › General | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 31 | Setting › General | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 31 | Setting › General | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 31 | Setting › General | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 31 | Setting › General | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 31 | Setting › General | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 32 | Setting › General › Activity Logs | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 32 | Setting › General › Activity Logs | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 32 | Setting › General › Activity Logs | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 32 | Setting › General › Activity Logs | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 32 | Setting › General › Activity Logs | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 32 | Setting › General › Activity Logs | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 33 | Setting › Appearance | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 33 | Setting › Appearance | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 33 | Setting › Appearance | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 33 | Setting › Appearance | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 33 | Setting › Appearance | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 33 | Setting › Appearance | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 34 | Setting › Reading | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 34 | Setting › Reading | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 34 | Setting › Reading | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 34 | Setting › Reading | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 34 | Setting › Reading | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 34 | Setting › Reading | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 35 | Setting › Download | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 35 | Setting › Download | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 35 | Setting › Download | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 35 | Setting › Download | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 35 | Setting › Download | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 35 | Setting › Download | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 36 | Setting › Laboratory | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 36 | Setting › Laboratory | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 36 | Setting › Laboratory | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 36 | Setting › Laboratory | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 36 | Setting › Laboratory | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 36 | Setting › Laboratory | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 37 | Setting › About | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 37 | Setting › About | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 37 | Setting › About | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 37 | Setting › About | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 37 | Setting › About | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 37 | Setting › About | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 38 | Setting › EhSetting | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 38 | Setting › EhSetting | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 38 | Setting › EhSetting | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 38 | Setting › EhSetting | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 38 | Setting › EhSetting | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 38 | Setting › EhSetting | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 39 | Filters sheet | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 39 | Filters sheet | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 39 | Filters sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 39 | Filters sheet | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 39 | Filters sheet | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 39 | Filters sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 40 | Quick Search sheet | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 40 | Quick Search sheet | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 40 | Quick Search sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 40 | Quick Search sheet | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 40 | Quick Search sheet | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 40 | Quick Search sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 41 | Date Seek picker | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 41 | Date Seek picker | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 41 | Date Seek picker | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 41 | Date Seek picker | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 41 | Date Seek picker | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 41 | Date Seek picker | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 42 | Error surface | iPad | portrait | XXL (extra-extra-extra-large) | pending |  |
| 42 | Error surface | iPad | portrait | AX3 (accessibility-extra-large) | pending |  |
| 42 | Error surface | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pending |  |
| 42 | Error surface | iPad | landscape | XXL (extra-extra-extra-large) | pending |  |
| 42 | Error surface | iPad | landscape | AX3 (accessibility-extra-large) | pending |  |
| 42 | Error surface | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pending |  |

## Findings

Numbered in the order they are recorded. The sweep never stops to raise one (D-02): the finding is
written here, the walk continues, and plan 16-10 reports the complete list once every page has
been scanned.

Each entry carries a **written** description — what value was lost, at which size, and what it
reads as at `.large` — never a filename (D-32). Before/after images are sent to the owner in chat
(D-33) by naming the evidence-root path and describing the image.

| #N | Screen | Cells affected | Description (written, no filenames) | Status |
|---|---|---|---|---|
| _none yet_ | | | | |

Status ∈ {`open`, `fixed-by <commit>`, `re-verified`, `accepted`}.

## D-13 named edge cases

The five edge cases from ROADMAP criterion 4, pre-registered as named items so criterion 4 ticks
off item by item and none is silently dropped. Tracked alongside § Findings, not merged into it.
Each closes as `fixed` or `accepted (owner reason: …)` — never by omission.

| Case | Screen | Site | Status | Disposition |
|---|---|---|---|---|
| Detail stats-strip abbreviation | #14 | `DetailFeature/DetailView+Subviews.swift:99, 116` (stats strip) | pending |  |
| Long-tag right-edge clip | #14 | `AppComponents/TagCloudView.swift:122` (tag cloud) | pending |  |
| Reader total-page counter wrap | #25 | `ReadingFeature/Support/ControlPanel.swift:176` (page indicator) | pending |  |
| Favorites trailing-glyph clip | #8 | `FavoritesFeature/FavoritesView.swift` toolbar/menu glyphs + `GalleryListComponents/Cells/GalleryDetailCell.swift:140` trailing symbol | pending |  |
| Hero-carousel title truncation | #2 | `HomeFeature/GalleryCardCell.swift:73` (`lineLimit(4)`) | pending |  |

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
| `DateSeekFeature/DateSeekPickerView.swift:122` | picker row text | #41 | fine | pending |  |
| `SystemNotification/ToastMessageView.swift:65` | toast title | #42 | B1 fixed (toast) | pending |  |
| `SystemNotification/ToastMessageView.swift:70` | toast subtitle | #42 | B1 fixed (toast) | pending | subtitle was not part of B1 |
| `SettingFeature/EhSetting/EhSettingView+Sections3.swift:131` | section value | #38 | B3 / fine | pending |  |
| `SettingFeature/AppActivityLogs/AppActivityLogsView.swift:224` | log category chip | #32 | fine | pending |  |
| `ReadingFeature/Support/ControlPanel.swift:176` | page indicator `n / total` | #25 | fine | pending | **D-13: reader total-page counter wrap** |
| `HomeFeature/GalleryRankingCell.swift:39` | ranking cell subtitle | #2 | fine | pending |  |
| `SearchFeature/GalleryHistoryCell.swift:32` | history cell secondary line | #9 | fine | pending |  |
| `GalleryListComponents/Cells/GalleryDetailCell.swift:107` | uploader | all list hosts (#3, #4, #5, #8, #10) | fine (secondary exemption) | pending | **back in scope — the exemption is gone** |
| `GalleryListComponents/Cells/GalleryDetailCell.swift:152` | stats value | all list hosts (#3, #4, #5, #8, #10) | fine | pending | **back in scope + D-14 (paired shrink at :155)** |
| `GalleryListComponents/Cells/GalleryDetailCell.swift:163` | stats value | all list hosts (#3, #4, #5, #8, #10) | fine | pending | **back in scope + D-14 (paired shrink at :166)** |
| `GalleryListComponents/DownloadBadgeLabel.swift:19` | badge progress text | all list hosts + #11 | fine | pending |  |
| `GalleryListComponents/Cells/GalleryThumbnailCell.swift:99` | thumbnail cell footnote | all list hosts (thumbnail layout) | fine | pending |  |
| `AppComponents/TagCloudView.swift:122` | tag text | #14 | fine | pending | **D-13: long-tag right-edge clip** |
| `AppComponents/CategoryView.swift:31` (`CategoryLabel`) | category name | #14 + all list cells | fine | pending | D-15 collision via the paired 0.72 shrink at the Detail header |
| `AppComponents/CategoryView.swift:87` (`CategoryCell`) | category name | #39 | fine | pending |  |
| `AppComponents/TagSuggestionView.swift:111` | suggestion row title | #10, #17 | fine | pending |  |
| `AppComponents/TagSuggestionView.swift:116` | suggestion row detail | #10, #17 | fine | pending |  |
| `DetailFeature/DetailView+CommentCells.swift:37` | comment author | #14 | fine | pending | **back in scope + D-14 (paired shrink at :42)** |
| `DetailFeature/DetailView+CommentCells.swift:43` | comment date / body line | #14 | fine | pending | **back in scope** |
| `DetailFeature/DetailView+Subviews.swift:99` | stats strip value | #14 | fine | pending | **D-13: Detail stats-strip abbreviation** |
| `DetailFeature/DetailView+Subviews.swift:116` | stats strip value | #14 | fine | pending | **D-13: Detail stats-strip abbreviation** |
| `DetailFeature/DetailView+HeaderSection.swift:72` | header category label | #14 | fine | pending | **D-14 0.72 site at :73; D-15 parity constraint** |
| `DetailFeature/DetailView+HeaderSection.swift:324` | header secondary line | #14 | fine | pending |  |
| `DetailFeature/Comments/CommentsView.swift:166` | comment header | #16 | fine | pending | **back in scope + D-14 (paired shrink at :165)** |
| `DetailFeature/Torrents/TorrentsView.swift:110` | torrent meta | #20 | shrink-absorbed | pending | re-judge — there is no shrink any more |
| `DetailFeature/Torrents/TorrentsView.swift:124` | torrent meta | #20 | shrink-absorbed | pending | re-judge — there is no shrink any more |
| `DetailFeature/Archives/ArchivesView.swift:143` | funds line | #19 | fine | pending |  |
| `DetailFeature/Archives/ArchivesView.swift:202` | archive price | #19 | fine | pending |  |
| `QuickSearchFeature/QuickSearchView.swift:40` | quick-search word name | #40 | fine | pending |  |
| `HomeFeature/GalleryCardCell.swift:73` (`lineLimit(4)`) | hero-carousel gallery title | #2 | fine | pending | **D-13: hero-carousel title truncation** |

### `minimumScaleFactor` — 5 sites, target 0 (D-14)

Banned outright, not judged case by case. The lint rule that makes the target mechanical
(`no_minimum_scale_factor`) is held back to plan 16-12 so it lands with or after the removals.

| Site (file:line at HEAD) | What is shrunk | Screen # | Phase-10 verdict | D-04 status | Note |
|---|---|---|---|---|---|
| `GalleryListComponents/Cells/GalleryDetailCell.swift:155` (0.75) | stats value shrunk instead of reflowed | all list hosts (#3, #4, #5, #8, #10) | fine | pending | removal target 0 (D-14) |
| `GalleryListComponents/Cells/GalleryDetailCell.swift:166` (0.75) | stats value shrunk instead of reflowed | all list hosts (#3, #4, #5, #8, #10) | fine | pending | removal target 0 (D-14) |
| `DetailFeature/DetailView+CommentCells.swift:42` (0.75) | comment author shrunk | #14 | fine | pending | removal target 0 (D-14) |
| `DetailFeature/DetailView+HeaderSection.swift:73` (0.72) | header category label shrunk | #14 | fine | pending | **D-15 collision — plausibly engages at `.large`; parity outranks the ban** |
| `DetailFeature/Comments/CommentsView.swift:165` (0.75) | comment header shrunk | #16 | fine | pending | removal target 0 (D-14) |

### Fixed frames and widths

| Site (file:line at HEAD) | What is constrained | Screen # | Phase-10 verdict | D-04 status | Note |
|---|---|---|---|---|---|
| `SettingFeature/SettingView.swift:109` `.frame(width: 45, height: 45)` | setting-row icon slot | #28 | chrome — OK | pending | re-check: an AX5 `.largeTitle` glyph may exceed 45pt |
| `SettingFeature/AppearanceSetting/AppearanceSettingView.swift:146` `.frame(width: 60, height: 60)` | app-icon image slot | #33 | chrome — OK | pending | chrome; re-check the adjacent label |
| `ReadingFeature/Support/ControlPanel.swift:166` `.frame(width: 44, height: 44)` | touch target | #25 | keep | pending | 44pt minimum — keep |
| `ReadingFeature/Support/ControlPanel.swift:296` `.frame(width: 44, height: 44)` | touch target | #25 | keep | pending | 44pt minimum — keep |
| `DownloadsFeature/DownloadsView+Subviews.swift:145` `.frame(width: 20, height: 20)` | progress spinner slot | #11, #12 | chrome — OK | pending |  |
| `DetailFeature/DetailView+CommentCells.swift:51` `.frame(width: 300, height: cardHeight)` | comment card (height is `@ScaledMetric`) | #14 | B10 — height scaled | pending | width still fixed at 300 — re-check at AX5 iPhone portrait |
| `SettingFeature/GeneralSetting/GeneralSettingView.swift:69` `.frame(width: 50)` | fixed-width control | #31 | fine | pending |  |
| `SettingFeature/EhSetting/EhSettingView+Sections2.swift:44` `.frame(width: 10)` | spacer width | #38 | fine | pending |  |
| `SettingFeature/EhSetting/EhSettingView+Sections2.swift:164` `.frame(width: 200)` | fixed-width control | #38 | fine | pending | re-check: a 200pt control at AX5 |
| `SettingFeature/EhSetting/EhSettingView+Sections2.swift:177` `.frame(width: 200)` | fixed-width control | #38 | fine | pending | re-check: a 200pt control at AX5 |
| `SystemNotification/View+Toast.swift:57` `.frame(minHeight: 44)` | toast minimum height | #42 | fine | pending | a minimum, not a cap |
| `AppComponents/StateViews.swift:49` `.frame(maxWidth: .infinity, minHeight: 50)` | state-view row minimum height | every list host | fine | pending | a minimum, not a cap |

## D-25 re-sweep

Reserved for round 2. Rows are appended by plan **16-26**: every screen where round 2 adds a
visible element — a new glyph or shape for a non-colour indicator, or a contrast change that
alters a rendered element's size — is re-walked at XXL / AX3 / AX5 to close the staleness hole
exactly where it exists. Accessibility labels are not rendered, so the bulk of round 2 cannot
disturb round 1's verified layout (D-24).

| Screen | What round 2 changed | Cells re-walked | Status |
|---|---|---|---|
| _none yet_ | | | |
