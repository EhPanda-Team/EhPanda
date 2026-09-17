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
| `IPAD_LOGIN` | `present` — the owner signed in on `IPAD_UDID` themselves and reported it in chat on 2026-09-03. The rows previously recorded `blocked: no iPad session` (iPad #5, #8, #13, #14–#27, #38) are unblocked and go back to `pending`; they are walked by the re-verification batch that follows this amendment. No credential was ever entered by an agent (D-09) | 16-03, amended 2026-09-03 |
| `SPARE_UDID` | `E2BF974E-DE4D-4A67-B84A-90D41325C4A7` — iPhone 17e, iOS 26.4. **UI tests only**; never a sweep target, so the logged-in simulators are never a `xcodebuild test` destination | prefilled |
| `EVIDENCE_ROOT` | `$HOME/Library/Caches/ehpanda-phase16/` | prefilled |

Shell form, for pasting at the start of every sweep session (the same values as the table):

```bash
IPHONE_UDID=ADE09605-A44E-4F00-BE12-235970217355
IPAD_UDID=8250D97E-9AB0-42FD-99DB-07B0094BF8C7
SPARE_UDID=E2BF974E-DE4D-4A67-B84A-90D41325C4A7   # re-created 2026-09-03; the original 88B217DA… spare no longer exists
BUNDLE_ID=app.ehpanda.personal
IPHONE_LOGIN=present
IPAD_LOGIN=present
EVIDENCE_ROOT="$HOME/Library/Caches/ehpanda-phase16"
```

### Re-pointed 2026-09-17 (plan 16-26)

The original table and shell form above remain the round-1 historical record. The current plan uses
the following four known UDIDs from the fresh inventory dated 2026-09-17; the former `88B217DA…`
spare is retained only as that prefix because its full identifier was not verified.

| Key | Current value | Baseline / evidence |
|---|---|---|
| `LOGIN_UDID` | `C9C8B01B-1FBC-466E-A4F8-C46B13E1D07D` | LOGIN dark/large, Increase Contrast disabled; restored and shut down in `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/login-restored.txt` |
| `WALK_UDID` | `CAE8CEE9-7C40-48D3-BE75-F0940B403DA8` | WALK light/large, Increase Contrast disabled; restored/shut down in `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/walk-restored.txt` and `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/inventory-restored-20260917.json` |
| `GATE_IPHONE` | `73E148DA-26E4-4892-8C8A-7EDC6725D0E7` | closing test destination only |
| `GATE_IPAD` | `B6679864-3783-4A3B-89B5-B0B010588C13` | closing test destination only |
| `IPHONE_UDID` | alias of `LOGIN_UDID` | current protocol alias; `IPHONE_LOGIN` is present from the owner session on 2026-09-15 |
| `IPAD_UDID` | `none` | no login iPad; re-sweep is iPhone-only |
| `WALKTHROUGH_UDID` | alias of `WALK_UDID` | hermetic walkthrough only |
| `GATE_IPHONE_UDID` | alias of `GATE_IPHONE` | only iPhone test destination |
| `GATE_IPAD_UDID` | alias of `GATE_IPAD` | only iPad test destination |
| `EVIDENCE_ROOT` | `$HOME/Library/Caches/ehpanda-phase16/` | persistent cache evidence root |
| `BUNDLE_ID` | `app.ehpanda.personal` | install-over target |

The retired `ADE09605…`, `8250D97E…`, and `E2BF974E…` identifiers are absent from that fresh
inventory; their full historical values remain in the original table. The fresh inventory is
`$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/inventory-20260917.json`. `BUNDLE_ID` remains
`app.ehpanda.personal`. The current D-25 rendered scope is exactly Search root #9, Favorites #8,
and Watched #5: nine iPhone-portrait cells at XXL, AX3, and AX5. Search root is the Task 1 tracer;
Activity Logs, Laboratory, and Gallery Detail are withdrawn from the current rendered scope.
The source is immutable at `b01add4c11b1f9c355ac8f2e055ed8b24fe8146c`; the measurement/gate evidence
predates the documentation commit `8a199c2f` and was not rerun on that documentation HEAD. The
gitignored workflow test command was corrected separately and is not part of this document change.

Current aliases resolve through this table: `IPHONE_UDID` = `LOGIN_UDID`, `IPHONE_LOGIN` = `present`
(owner session, 2026-09-15); `IPAD_UDID` = `none` and `IPAD_LOGIN` = `none` because the re-sweep is
iPhone-only; `WALKTHROUGH_UDID` = `WALK_UDID`; `GATE_IPHONE_UDID` = `GATE_IPHONE`; and
`GATE_IPAD_UDID` = `GATE_IPAD`. `EVIDENCE_ROOT` is `$HOME/Library/Caches/ehpanda-phase16/` and
`BUNDLE_ID` is `app.ehpanda.personal`. The protocol's former `IPHONE_UDID`, `IPAD_UDID`, and
`SPARE_UDID` names now resolve through this current table; `SPARE_UDID` maps to the two gate
destinations for test purposes, and iPadOS 27 is excluded.

Current shell form (the historical shell above is retained unchanged):

```bash
LOGIN_UDID=C9C8B01B-1FBC-466E-A4F8-C46B13E1D07D
WALK_UDID=CAE8CEE9-7C40-48D3-BE75-F0940B403DA8
GATE_IPHONE=73E148DA-26E4-4892-8C8A-7EDC6725D0E7
GATE_IPAD=B6679864-3783-4A3B-89B5-B0B010588C13
IPHONE_UDID="$LOGIN_UDID"
IPAD_UDID=none
IPHONE_LOGIN=present
IPAD_LOGIN=none
WALKTHROUGH_UDID="$WALK_UDID"
GATE_IPHONE_UDID="$GATE_IPHONE"
GATE_IPAD_UDID="$GATE_IPAD"
SPARE_UDID="$GATE_IPHONE" # protocol alias; use GATE_IPAD separately for the iPad gate
BUNDLE_ID=app.ehpanda.personal
EVIDENCE_ROOT="$HOME/Library/Caches/ehpanda-phase16"
```

#### Retired (history)

The fresh `inventory-20260917.json` records these retired identifiers absent on 2026-09-17:

| Historical key | Retired value | Status |
|---|---|---|
| `IPHONE_UDID` | `ADE09605-A44E-4F00-BE12-235970217355` | absent 2026-09-17 |
| `IPAD_UDID` | `8250D97E-9AB0-42FD-99DB-07B0094BF8C7` | absent 2026-09-17 |
| `SPARE_UDID` | `E2BF974E-DE4D-4A67-B84A-90D41325C4A7` | absent 2026-09-17 |
| former spare | `88B217DA…` | prefix matches the historical record; full ID was not verified, so no full-ID absence is asserted |

The original table, shell form, and `Why app.ehpanda.personal` section remain the round-1 record.

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
| **Login on `IPAD_UDID`.** | `present` — owner-created session, 2026-09-03; see the `IPAD_LOGIN` row. |
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
| 2 | Home root | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#1 | Hero-carousel title drops from four lines to three; the tail is ellipsised. Sections, ranking cells and tab bar fine. Re-verify (batch 1): the card now steps its height with the type size, but a long hero title still ends in an ellipsis. Ranking rows, sections and the neighbouring card all read in full. Re-verify (batch 2): the card is 336 x 243 pt (34% of the 708 pt scroll container), cover and title side by side with the rating still under the title, title complete. The section headings below stack leading-aligned at the accessibility sizes with Show All on its own line, and no blank line where a section has none. Re-verify (batch 2b, `eb38acc4`): unchanged at XXL — the rating is still inside the text column at body size, measured at x 195.7..338.0 pt, y 335.7..359.3 pt, and the card is 42.0..377.7 pt, exactly its slot. |
| 2 | Home root | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#1 | Hero title collapses to one ellipsised line; ranking cells lose both title tail and uploader. Re-verify (batch 1): the card stacks its cover above the text and the ranking rows keep title and uploader, but the hero title is still ellipsised. Re-verify (batch 2): the card is 336 x 354 pt — exactly half the 708 pt scroll container — the rating has moved to its own full-width row under cover and title, and the title truncates at its tail with an ellipsis. The section headings below stack leading-aligned at the accessibility sizes with Show All on its own line, and no blank line where a section has none. Re-verify (batch 2b, `eb38acc4`): once the rating drops to its own row the five symbols take `.caption2`, and the card's rendered bounds now equal its layout slot exactly — measured 42.0..377.7 pt (336.0 pt) in portrait, 145.7..766.3 pt (621.0 pt) in landscape — with the designed 20 pt gap to each peeking neighbour restored. The rating row measures 64.3..245.0 pt, 30.0 pt tall, well inside the card's 62.0..357.7 pt content box. |
| 2 | Home root | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Hero title down to one clipped word, the neighbouring card is drawn over its title and rating, ranking cells heavily truncated. Re-verify (batch 1): the hero title reads to its last word over seven lines, no neighbouring card is drawn over it, and the ranking rows are complete. Re-verify (batch 2): the card is capped at the same 354 pt (half the container) but renders 381.7 pt wide inside its 336 pt slot, so it overlaps both peeking neighbours by ~23 pt; the rating symbols themselves are not clipped, the title ellipsises at its tail. The section headings below stack leading-aligned at the accessibility sizes with Show All on its own line, and no blank line where a section has none. Re-verify (batch 2b, `eb38acc4`): once the rating drops to its own row the five symbols take `.caption2`, and the card's rendered bounds now equal its layout slot exactly — measured 42.0..377.7 pt (336.0 pt) in portrait, 145.7..766.3 pt (621.0 pt) in landscape — with the designed 20 pt gap to each peeking neighbour restored. This is the cell the round-II residue was raised on: the rating row measured 44.7..400.7 pt then, 23.0 pt past the card's trailing edge and 2.7 pt into the neighbour's slot, and now measures 66.0..314.3 pt, 41.3 pt tall, inside the card at both ends. **Re-verify (batch 5b, `d6694e0d`):** the Home tab root's title, briefly `.large` in `e8fd65c4`, is reverted to `.inlineLarge`; at AX5 it draws a persistent large leading title (`Home` 105x46), matching the batch-4 layout — the revert is a no-op. The hero card and rows below were not re-judged in this batch. |
| 2 | Home root | iPhone | landscape | XXL (extra-extra-extra-large) | finding:#1 | Wider card absorbs the growth — hero title, ranking titles and uploaders all read in full. Re-verify (batch 1): a long hero title now ends in an ellipsis where round 1 recorded none — the card's shorter landscape height is the binding budget (the carousel is showing different galleries than in round 1). Ranking and list rows read in full. Re-verify (batch 2): the card is 621 x 139 pt, exactly its slot width, cover and title side by side, rating under the title, title complete. The section headings below stack leading-aligned at the accessibility sizes with Show All on its own line, and no blank line where a section has none. Re-verify (batch 2b, `eb38acc4`): unchanged at XXL — the rating is still inside the text column at body size and the card is 145.7..766.3 pt, exactly its 621 pt slot. |
| 2 | Home root | iPhone | landscape | AX3 (accessibility-extra-large) | finding:#1 | Hero title reduced to one ellipsised line; ranking uploader ellipsised. Re-verify (batch 1): the hero title is still ellipsised; the ranking cell's title and uploader now read in full. Re-verify (batch 2): the card is 621 x 150 pt, rating on its own row, cover shrunk along its 8/11 aspect to about 49 x 67 pt, title ellipsised at its tail. The section headings below stack leading-aligned at the accessibility sizes with Show All on its own line, and no blank line where a section has none. Re-verify (batch 2b, `eb38acc4`): once the rating drops to its own row the five symbols take `.caption2`, and the card's rendered bounds now equal its layout slot exactly — measured 42.0..377.7 pt (336.0 pt) in portrait, 145.7..766.3 pt (621.0 pt) in landscape — with the designed 20 pt gap to each peeking neighbour restored. The rating row measures 168.7..349.0 pt, inside the card. |
| 2 | Home root | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#1 | Hero title ellipsised after three words; ranking cell title and uploader both truncated. Re-verify (batch 1): the hero title is ellipsised after five lines; ranking cell title and uploader are complete. Re-verify (batch 2): the card is 621 x 180 pt, still exactly its slot width with 20 pt gaps to both neighbours, rating row complete and unclipped, cover down to about 45 x 62 pt. The section headings below stack leading-aligned at the accessibility sizes with Show All on its own line, and no blank line where a section has none. Re-verify (batch 2b, `eb38acc4`): once the rating drops to its own row the five symbols take `.caption2`, and the card's rendered bounds now equal its layout slot exactly — measured 42.0..377.7 pt (336.0 pt) in portrait, 145.7..766.3 pt (621.0 pt) in landscape — with the designed 20 pt gap to each peeking neighbour restored. The rating row measures 169.7..418.0 pt, inside the card; the card is 165 pt tall, 15 pt shorter than in round II because the symbols no longer take the body size. |
| 3 | Home › Frontpage | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#4 | Long row titles lose their tail at the third line; the filter field's capsule rendered with no icon and no placeholder on this screen. Re-verify (batch 1): row titles wrap to their last word and every trailing value reads in full. The empty filter capsule (#4) belongs to a later batch and was not re-checked. Re-verify (batch 2): the row keeps the list's natural insets above the default size (no negative-inset hugging), the cover is scaled against .headline and bounded to half the row, the category badge's corners scale with its text and read as rounded, and title, uploader, language, rating, page count, badge and date all read in full. Re-verify (batch 3, `0dde25eb`+`72234cbc`+`7645e10c`, Display Mode = Thumbnail): two columns (182/183 pt cells; the right column ends at x 400 of a 420 pt screen), titles read to their last word, badges whole, page count and the whole five-star row drawn. The large title and the filter capsule are both intact at this size. **Re-verify (batch 4, `cbab163b`+`e30ddba0`, Display Mode = Thumbnail):** the 2-column floor confirmed again — no cell background crosses into its neighbour or off-screen. The five-symbol star row is drawn (the column is wide enough). |
| 3 | Home › Frontpage | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#4 | Filter capsule empty; titles truncated; language, page count and date cut off by the screen's right edge. Re-verify (batch 1): the row stacks — title, uploader, language, rating, page count, badge and date are all complete. Filter capsule (#4) not re-checked. Re-verify (batch 2): the row keeps the list's natural insets above the default size (no negative-inset hugging), the cover is scaled against .headline and bounded to half the row, the category badge's corners scale with its text and read as rounded, and title, uploader, language, rating, page count, badge and date all read in full. Re-verify (batch 3, `27a360b1`): the navigation bar falls back to its inline title at the accessibility sizes, so the screen name is drawn again (`Frontpage`, 161,77 99x25 pt) and the pull-to-reveal filter capsule renders its magnifier and placeholder. The list rows below were not re-judged here. Re-verify (batch 3, `0dde25eb`+`72234cbc`+`7645e10c`, Display Mode = Thumbnail): the masonry drops to one full-width column (380 pt) at the accessibility floor, so the cell's title reads to its last word over four lines and the page count and five-star row are complete on screen. **Re-verify (batch 4, `cbab163b`+`e30ddba0`, Display Mode = Thumbnail):** the 2-column floor confirmed again — no cell background crosses into its neighbour or off-screen. The star row falls back to a single symbol plus its numeral in the half-width column. |
| 3 | Home › Frontpage | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#4, #7 | Screen title not rendered at all; filter capsule empty; page count gone, date and language cut; cover thumbnail squeezed to a sliver. Re-verify (batch 1): the row reflows fully: cover at intrinsic size, title over four lines, uploader, rating, page count, badge and timestamp all complete. Filter capsule and navigation large title (#4, #7) not re-checked. Re-verify (batch 2): the row keeps the list's natural insets above the default size (no negative-inset hugging), the cover is scaled against .headline and bounded to half the row, the category badge's corners scale with its text and read as rounded, and title, uploader, language, rating, page count, badge and date all read in full. Re-verify (batch 3, `27a360b1`): the navigation bar falls back to its inline title at the accessibility sizes, so the screen name is drawn again (`Frontpage`, 161,77 99x25 pt) and the pull-to-reveal filter capsule renders its magnifier and placeholder. The list rows below were not re-judged here. Re-verify (batch 3, `0dde25eb`+`72234cbc`+`7645e10c`, Display Mode = Thumbnail): one full-width column; the category badge reads in full in the cover's corner (round 1: `Douji…`), the title reads to its last word, and the star row is no longer clipped by the screen edge. **Re-verify (batch 4, `cbab163b`+`e30ddba0`, Display Mode = Thumbnail):** the 2-column floor confirmed again — no cell background crosses into its neighbour or off-screen. The star row falls back to a single symbol plus its numeral in the half-width column. **Re-verify (batch 6, `100f19fb`, Display Mode = Detail):** the same cell in portrait still stacks (380 x 793 pt), which is the narrow case the width gate is meant to keep — the arrangement flips on width exactly where designed. |
| 3 | Home › Frontpage | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Every value in the rows walked reads in full, filter field included. Re-verify (batch 1): unchanged. Re-verify (batch 2): the row keeps the list's natural insets above the default size (no negative-inset hugging), the cover is scaled against .headline and bounded to half the row, the category badge's corners scale with its text and read as rounded, and title, uploader, language, rating, page count, badge and date all read in full. |
| 3 | Home › Frontpage | iPhone | landscape | AX3 (accessibility-extra-large) | pass | No clipped or ellipsised value in the rows walked. Re-verify (batch 1): unchanged. Re-verify (batch 2): the row keeps the list's natural insets above the default size (no negative-inset hugging), the cover is scaled against .headline and bounded to half the row, the category badge's corners scale with its text and read as rounded, and title, uploader, language, rating, page count, badge and date all read in full. |
| 3 | Home › Frontpage | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | A long row title loses its tail at the third line; all other values read in full. Re-verify (batch 1): the long row title wraps to its last word; every other value reads in full. Re-verify (batch 2): the row keeps the list's natural insets above the default size (no negative-inset hugging), the cover is scaled against .headline and bounded to half the row, the category badge's corners scale with its text and read as rounded, and title, uploader, language, rating, page count, badge and date all read in full. Re-verify (batch 3, `0dde25eb`+`72234cbc`+`7645e10c`, Display Mode = Thumbnail): one full-width column (744 pt) against three in round 1; title, page count, star row and badge all complete inside the screen. **Re-verify (batch 4, `cbab163b`+`e30ddba0`, Display Mode = Thumbnail):** the 2-column floor confirmed again — no cell background crosses into its neighbour or off-screen. The five-symbol star row is drawn (the column is wide enough). **Re-verify (batch 6, `100f19fb`, Display Mode = Detail):** answering the owner's direction that a landscape gallery cell keeps cover and title on one line, the accessibility-size stack is now gated on the row's measured width. The row measures 744 pt here — above the 550 pt divide — so cover and title share a line and the whole cell is 744 x 426 pt, with title, uploader, five-star rating, rounded badge and date all complete. |
| 4 | Home › Popular | iPhone | portrait | XXL (extra-extra-extra-large) | pass | A long row title is ellipsised at the third line; filter field, uploader, stats and date all read in full. Re-verify (batch 1): the row title wraps in full; filter field, uploader, stats and date all read. |
| 4 | Home › Popular | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#4 | Filter capsule empty; titles truncated; language, page count and date cut at the right edge. Re-verify (batch 1): title, language, page count and date are all complete. Filter capsule (#4) not re-checked. Re-verify (batch 3, `27a360b1`): the navigation bar falls back to its inline title at the accessibility sizes, so the screen name is drawn again (`Popular`, 173,77 74x25 pt) and the pull-to-reveal filter capsule renders its magnifier and placeholder. The list rows below were not re-judged here. |
| 4 | Home › Popular | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#4, #7 | Screen title absent; filter capsule empty; title runs off the right edge un-ellipsised; page count lost; cover a sliver. Re-verify (batch 1): the row stacks and keeps title, uploader, page count, badge and date, and the cover keeps its size. Filter capsule and large title (#4, #7) not re-checked. Re-verify (batch 3, `27a360b1`): the navigation bar falls back to its inline title at the accessibility sizes, so the screen name is drawn again (`Popular`, 173,77 74x25 pt) and the pull-to-reveal filter capsule renders its magnifier and placeholder. The list rows below were not re-judged here. |
| 4 | Home › Popular | iPhone | landscape | XXL (extra-extra-extra-large) | pass | All row values read in full. |
| 4 | Home › Popular | iPhone | landscape | AX3 (accessibility-extra-large) | pass | All row values read in full. |
| 4 | Home › Popular | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Title, uploader, language, page count and date all read in full in the rows walked. |
| 5 | Home › Watched | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Session present, list shown. A long title loses its tail; a long uploader is ellipsised where a language value shares its line. Re-verify (batch 1): the long title reads to its last word and the uploader is no longer ellipsised beside the language value. |
| 5 | Home › Watched | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#4 | Filter capsule empty; title truncated; language and page count cut at the right edge. Re-verify (batch 1): title, language and page count are all complete. Filter capsule (#4) not re-checked. Re-verify (batch 3, `27a360b1`): the navigation bar falls back to its inline title at the accessibility sizes, so the screen name is drawn again (`Watched`, 167,77 85x25 pt) and the pull-to-reveal filter capsule renders its magnifier and placeholder. The list rows below were not re-judged here. |
| 5 | Home › Watched | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#4, #7 | Screen title absent; filter capsule empty; language and page count cut; cover thumbnail a sliver. Re-verify (batch 1): the row stacks with the cover at full size; title, language and page count complete. Filter capsule and large title (#4, #7) not re-checked. Re-verify (batch 3, `27a360b1`): the navigation bar falls back to its inline title at the accessibility sizes, so the screen name is drawn again (`Watched`, 167,77 85x25 pt) and the pull-to-reveal filter capsule renders its magnifier and placeholder. The list rows below were not re-judged here. |
| 5 | Home › Watched | iPhone | landscape | XXL (extra-extra-extra-large) | pass | The longest title in the list reads in full across two lines; all other values complete. Re-verify (batch 1): unchanged. |
| 5 | Home › Watched | iPhone | landscape | AX3 (accessibility-extra-large) | pass | The same title that read in full at XXL now ellipsises at the third line. Re-verify (batch 1): the title that ellipsised in round 1 now wraps to its last word. |
| 5 | Home › Watched | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Title ellipsised at the third line; remaining values complete. Re-verify (batch 1): the title is complete; every other row value reads in full. |
| 6 | Home › History | iPhone | portrait | XXL (extra-extra-extra-large) | pass | A long row title loses its tail; the footer note, filter field and all row values read in full. Re-verify (batch 1): the long title wraps in full; footer note, filter field and all row values read. |
| 6 | Home › History | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#4 | Filter capsule empty; title truncated; page count and date cut at the right edge. Re-verify (batch 1): title, page count and date are complete. Filter capsule (#4) not re-checked. Re-verify (batch 3, `27a360b1`): the navigation bar falls back to its inline title at the accessibility sizes, so the screen name is drawn again (`History`, 175,77 70x25 pt) and the pull-to-reveal filter capsule renders its magnifier and placeholder. The list rows below were not re-judged here. |
| 6 | Home › History | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#4 | Screen title absent; filter capsule empty and overlapping rows; title and date cut at the right edge; uploader ellipsised; cover a sliver. Re-verify (batch 1): the row stacks — title, uploader and date complete and the cover keeps its size. Filter capsule (#4) not re-checked. Re-verify (batch 3, `27a360b1`): the navigation bar falls back to its inline title at the accessibility sizes, so the screen name is drawn again (`History`, 175,77 70x25 pt) and the pull-to-reveal filter capsule renders its magnifier and placeholder. The list rows below were not re-judged here. |
| 6 | Home › History | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Footer note wraps; every row value reads in full. |
| 6 | Home › History | iPhone | landscape | AX3 (accessibility-extra-large) | pass | No clipped or ellipsised value in the rows walked. |
| 6 | Home › History | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Footer note wraps to two lines; row values read in full in the rows walked. |
| 7 | Home › Toplists | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Screen title and the type/jump-page controls read in full; a long row title loses its tail. Re-verify (batch 1): screen title, the type/jump-page controls and the long row title all read in full. |
| 7 | Home › Toplists | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#4, #7 | Screen title ellipsised; filter capsule empty; row title truncated; language, page count and date cut at the right edge. Re-verify (batch 1): row title, language, page count and date are all complete. Screen title and filter capsule (#4, #7) not re-checked. Re-verify (batch 3, `27a360b1`): the filter capsule renders its magnifier and `Filter` placeholder again, and the title is drawn instead of missing — but it is now **ellipsised**: `Toplists - Yesterd…` in a 188 pt inline slot, against 157 pt complete when the same title collapses to inline at the default size. Still `open` on the title, fixed on the capsule. |
| 7 | Home › Toplists | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#4, #7 | Screen title absent; filter capsule empty; page count lost; cover a sliver. Type menu itself renders all four options in full. Re-verify (batch 1): the row stacks and keeps title, page count and badge with the cover at full size. Screen title and filter capsule (#4, #7) not re-checked. Re-verify (batch 3, `27a360b1`): the filter capsule renders its magnifier and `Filter` placeholder again, and the title is drawn instead of missing — but it is now **ellipsised**: `Toplists - Yesterd…` in a 188 pt inline slot, against 157 pt complete when the same title collapses to inline at the default size. Still `open` on the title, fixed on the capsule. |
| 7 | Home › Toplists | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Screen title, filter field and every row value read in full. |
| 7 | Home › Toplists | iPhone | landscape | AX3 (accessibility-extra-large) | pass | No clipped or ellipsised value in the rows walked. |
| 7 | Home › Toplists | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Screen title, filter field and every row value read in full. |
| 8 | Favorites root | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Session present, list shown. Long row titles lose their tail at the third line; index/sort/features glyphs, search field and all row values read in full. Re-verify (batch 1): long row titles wrap to their last word; glyphs, search field and trailing values all read. Re-verify (batch 2): the row keeps the list's natural insets above the default size (no negative-inset hugging), the cover is scaled against .headline and bounded to half the row, the category badge's corners scale with its text and read as rounded, and title, uploader, language, rating, page count, badge and date all read in full. |
| 8 | Favorites root | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Titles truncated; page count and date cut at the screen's right edge. The tab-root search field still reads correctly. Re-verify (batch 1): titles, page count and date are complete, and the tab-root search field still reads correctly. Re-verify (batch 2): the row keeps the list's natural insets above the default size (no negative-inset hugging), the cover is scaled against .headline and bounded to half the row, the category badge's corners scale with its text and read as rounded, and title, uploader, language, rating, page count, badge and date all read in full. |
| 8 | Favorites root | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Title cut mid-glyph at the right edge; page-count number lost; cover thumbnail squeezed to a sliver. Screen title and search field survive (tab root). Re-verify (batch 1): the row stacks — title complete, the page count keeps its number, and the cover keeps its size. Re-verify (batch 2): the row keeps the list's natural insets above the default size (no negative-inset hugging), the cover is scaled against .headline and bounded to half the row, the category badge's corners scale with its text and read as rounded, and title, uploader, language, rating, page count, badge and date all read in full. **Re-verify (batch 5b, `d6694e0d`):** the Favorites tab root's title is reverted to `.inlineLarge` (from the brief `.large` in `e8fd65c4`); at AX5 it draws a persistent large leading title (`Favorites` 162x46) — the revert is a no-op. The list rows below were not re-judged in this batch. |
| 8 | Favorites root | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Every row value reads in full in the rows walked. Re-verify (batch 1): unchanged. Re-verify (batch 2): the row keeps the list's natural insets above the default size (no negative-inset hugging), the cover is scaled against .headline and bounded to half the row, the category badge's corners scale with its text and read as rounded, and title, uploader, language, rating, page count, badge and date all read in full. |
| 8 | Favorites root | iPhone | landscape | AX3 (accessibility-extra-large) | pass | A long row title loses its tail at the third line; all other values complete. Re-verify (batch 1): the long row title wraps to its last word; all other values complete. Re-verify (batch 2): the row keeps the list's natural insets above the default size (no negative-inset hugging), the cover is scaled against .headline and bounded to half the row, the category badge's corners scale with its text and read as rounded, and title, uploader, language, rating, page count, badge and date all read in full. |
| 8 | Favorites root | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | A long row title loses its tail at the third line; all other values complete. Re-verify (batch 1): the long row title wraps to its last word; all other values complete. Re-verify (batch 2): the row keeps the list's natural insets above the default size (no negative-inset hugging), the cover is scaled against .headline and bounded to half the row, the category badge's corners scale with its text and read as rounded, and title, uploader, language, rating, page count, badge and date all read in full. |
| 9 | Search root | iPhone | portrait | XXL (extra-extra-extra-large) | pass | History keyword row and section headers fine; the Recently Seen cell's title is ellipsised. Re-verify (batch 1): the Recently Seen cell grows with the type — title, uploader and rating all read in full. Re-verify (batch 2): the section heading is leading-aligned and wraps whole words, Show All drops to its own line at the accessibility sizes and is omitted entirely (with no blank line) where the section has none, and the keyword rows are leading-aligned with the magnifier on the keyword's first line. |
| 9 | Search root | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Recently Seen cell overflows its slot — the title is cut at both ends and the cover is pushed past the screen's left edge. Re-verify (batch 1): the cell grows instead of overflowing its slot; nothing overlaps the section heading. Re-verify (batch 2): the section heading is leading-aligned and wraps whole words, Show All drops to its own line at the accessibility sizes and is omitted entirely (with no blank line) where the section has none, and the keyword rows are leading-aligned with the magnifier on the keyword's first line. |
| 9 | Search root | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#34 | Recently Seen cells overlap the section header and each other; titles cut at both edges; the section headings collapse to roughly one word per line. Re-verify (batch 1): the Recently Seen cells no longer overlap and their titles read in full, but the `Quick Search` section heading now breaks mid-word across four lines because the trailing Show All button keeps its share of the line — new finding #34. Re-verify (batch 2): the section heading is leading-aligned and wraps whole words, Show All drops to its own line at the accessibility sizes and is omitted entirely (with no blank line) where the section has none, and the keyword rows are leading-aligned with the magnifier on the keyword's first line. **Re-verify (batch 5b, `d6694e0d`):** the Search tab root's title is reverted to `.inlineLarge` (from the brief `.large` in `e8fd65c4`); at AX5 it draws a persistent large leading title (`Search` 124x46) — the revert is a no-op. The rows below were not re-judged in this batch. |
| 9 | Search root | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Recently Seen cell titles ellipsised; keyword row and headers fine. Re-verify (batch 1): Recently Seen titles read in full; keyword row and headings fine. Re-verify (batch 2): the section heading is leading-aligned and wraps whole words, Show All drops to its own line at the accessibility sizes and is omitted entirely (with no blank line) where the section has none, and the keyword rows are leading-aligned with the magnifier on the keyword's first line. |
| 9 | Search root | iPhone | landscape | AX3 (accessibility-extra-large) | pass | The search field overlaps the Recently Searched heading; Recently Seen cell titles cut. Re-verify (batch 1): the cells grow with the type; titles and uploaders read in full. Re-verify (batch 2): the section heading is leading-aligned and wraps whole words, Show All drops to its own line at the accessibility sizes and is omitted entirely (with no blank line) where the section has none, and the keyword rows are leading-aligned with the magnifier on the keyword's first line. |
| 9 | Search root | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Recently Seen cells overlap each other and their covers; titles cut at both edges. Re-verify (batch 1): the cells grow and no longer overlap; titles and uploaders wrap in full, and the section heading stays on one line in landscape. Re-verify (batch 2): the section heading is leading-aligned and wraps whole words, Show All drops to its own line at the accessibility sizes and is omitted entirely (with no blank line) where the section has none, and the keyword rows are leading-aligned with the magnifier on the keyword's first line. |
| 10 | Search results | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Screen title, row titles, uploader, language, page count and date all read in full. Re-verify (batch 1): unchanged. |
| 10 | Search results | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#4 | Filter capsule empty; a long title ellipsised; language, page count and date cut at the right edge. Re-verify (batch 1): title, language, page count and date are complete. Filter capsule (#4) not re-checked. Re-verify (batch 3, `4fbd0ae9`): the results screen takes the inline title at the accessibility sizes, so `Artbook` is drawn in the bar and the capsule shows the submitted query with its clear button. The list rows below were not re-judged here. |
| 10 | Search results | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#4, #7 | Screen title not rendered; filter capsule empty; page count and date cut at the right edge; cover thumbnail squeezed away. Re-verify (batch 1): the row stacks with the cover at full size and keeps page count and date. Filter capsule and large title (#4, #7) not re-checked. Re-verify (batch 3, `4fbd0ae9`): the results screen takes the inline title at the accessibility sizes, so `Artbook` is drawn in the bar and the capsule shows the submitted query with its clear button. The list rows below were not re-judged here. |
| 10 | Search results | iPhone | landscape | XXL (extra-extra-extra-large) | pass | All row values read in full. |
| 10 | Search results | iPhone | landscape | AX3 (accessibility-extra-large) | pass | All row values read in full. |
| 10 | Search results | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | All row values read in full, including a long bracketed title over two lines. |
| 11 | Downloads root | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Empty state, populated row, row context menu and swipe action all read in full, download badge included. Empty-state copy wraps and stays complete. |
| 11 | Downloads root | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#5, #6 | Row title ellipsised at the second line (download badge present); the badge's progress text and the date are cut at the screen's right edge. |
| 11 | Downloads root | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#5, #6, #8, #11 | Title cut mid-glyph; badge progress reduced to one digit; date cut; cover thumbnail gone; the delete confirmation's message is cut off mid-sentence. Row context menu and empty state remain complete. **Re-verify (batch 5b, `d6694e0d`):** the Downloads tab root's title is reverted to `.inlineLarge` (from the brief `.large` in `e8fd65c4`); at AX5 it draws a persistent large leading title (`Downloads` 198x46) — the revert is a no-op. This batch re-walked only the title; the row findings above are unchanged. |
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
| 14 | Gallery Detail | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Header title ellipsised where it read to its last word at `.large`; stats-strip column labels all abbreviated ("FAVORI…", "196 RAT…") and the rating star row clipped at both ends; comment-cell author ellipsised. Tag cloud, previews strip and uploader still read in full. Re-verify (batch 1): header title and uploader read in full, the stats strip stacks each label above its value with every value complete, and the comment card keeps author, score and date. Re-verify (batch 2): the header keeps cover and title side by side, the category badge's corners scale with its text, the stats strip and the comment strip are unchanged from batch 1, and a tag row keeps its namespace chip beside its children. **Re-verify (batch 4, `919b90bb`+`391ce4ea`):** the three header glass action buttons (download/favorite/read) each scale with their symbol — none overflows its circle. The stats strip keeps its horizontal `ScrollView`: scrolling it reveals every column (Favorited, Language, Ratings, Page Count, File Size on this gallery), each label+value complete and the five-star row un-clipped, with no column spanning the full container width. **Re-verify (batch 5b, `881104c0`):** the header title folds at three lines again (with tap-to-expand); at XXL it is three lines ending in an ellipsis (`[ai gener…`), and the category badge and the three action buttons stay on screen beneath it. |
| 14 | Gallery Detail | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Title and uploader both ellipsised; every stats column loses its label AND its value (1133 → "11…", 4.50 → "4.…"); the longest tag runs off the right edge cut mid-word; comment author and date both ellipsised. Re-verify (batch 1): title, uploader and category badge complete; the stats columns stack and keep their values; long tags wrap inside their chips; the comment card's header reads in full. Re-verify (batch 2): the header cover stacks above the title (the cover itself stays at its designed 104 x 150 pt), the badge reads as rounded, a tag row puts its namespace chip on its own line above its children, and the Previews and Comments headings stack leading-aligned. Re-verify (batch 2b, `549c255d`): a tag that wraps inside its own chip is now leading-aligned — checked on 'needy streamer overload' and 'columbina hyposelenia', the same chips the round-II shot showed centre-aligned. Nothing else on the screen moves. **Re-verify (batch 4, `919b90bb`+`391ce4ea`):** the three header glass action buttons (download/favorite/read) each scale with their symbol — none overflows its circle. The stats strip keeps its horizontal `ScrollView`: scrolling it reveals every column (Favorited, Language, Ratings, Page Count, File Size on this gallery), each label+value complete and the five-star row un-clipped, with no column spanning the full container width. **Re-verify (batch 5b, `881104c0`):** the header title folds at three lines again (with tap-to-expand); at AX3 it is three lines ending in an ellipsis, and the category badge and the three action buttons stay on screen beneath it. |
| 14 | Gallery Detail | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Stats columns down to two characters each ("FA…", "1…", "Ti…") with the star row reduced to one clipped star; two tags cut at the right edge; comment author "Baro…" and date "2026…" — the timestamp loses even its year. Re-verify (batch 1): title over three lines, uploader wrapped, badge complete; the stats strip puts one label-and-value pair per line; tags wrap inside their chips; the comment card header stacks and reads in full. Re-verify (batch 2): the header cover stacks above the title, the badge reads as rounded, the namespace chip sits on its own line above its children, and the Comments heading no longer breaks mid-word beside Show All. Re-verify (batch 2b, `549c255d`): wrapped chips are leading-aligned — checked on 'thigh high boots' and 'multimouth blowjob', both centre-aligned in round II, both flush left now. Single-line chips, which is all there is at and below the default size, are untouched. Re-verify (batch 3, `7645e10c`+`30e42c84`): the header's category badge carries no line cap of its own any more and `CategoryLabel` lets a name wrap above the default size. Checked on a nine-character category: the badge renders 238x63 pt with the name complete on one line, corners still rounded, title and uploader unchanged. **Re-verify (batch 4, `919b90bb`+`391ce4ea`):** the three header glass action buttons (download/favorite/read) each scale with their symbol — none overflows its circle. The stats strip keeps its horizontal `ScrollView`: scrolling it reveals every column (Favorited, Language, Ratings, Page Count, File Size on this gallery), each label+value complete and the five-star row un-clipped, with no column spanning the full container width. **Re-verify (batch 5b, `881104c0`):** the header title folds at three lines again; at AX5 it is three lines (frame 196 pt) ending in an ellipsis, and tapping the title expands it to the full text (326 pt). The category badge and the three action buttons stay on screen beneath it. |
| 14 | Gallery Detail | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Title, uploader, category, all five stats columns and the whole tag cloud read in full; only the comment cell degrades — author ellipsised and the second cell's date loses its time. Re-verify (batch 1): the comment card's author, score and timestamp all read; stats columns and the tag cloud are complete. Re-verify (batch 2): the header keeps cover and title side by side, the category badge's corners scale with its text, the stats strip and the comment strip are unchanged from batch 1, and a tag row keeps its namespace chip beside its children. |
| 14 | Gallery Detail | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Stats-strip column labels ellipsised and the star row clipped at both ends, though every value survives; comment authors and dates ellipsised. Title, uploader and tag cloud read in full. Re-verify (batch 1): the stats columns stack label above value and every value reads; the comment card header is complete. Re-verify (batch 2): the header cover stacks above the title (the cover itself stays at its designed 104 x 150 pt), the badge reads as rounded, a tag row puts its namespace chip on its own line above its children, and the Previews and Comments headings stack leading-aligned. |
| 14 | Gallery Detail | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Stats labels down to four characters and the star row shows three stars for a 4.50 rating; comment card bodies now ellipsised where they read in full at `.large`. Title, uploader and tag cloud still complete. Re-verify (batch 1): the stats pairs stack and keep their labels; the comment card header reads in full and its body shows at least as much as at `.large`. Re-verify (batch 2): the header cover stacks above the title, the badge reads as rounded, the namespace chip sits on its own line above its children, and the Comments heading no longer breaks mid-word beside Show All. **Re-verify (batch 4, `919b90bb`+`391ce4ea`):** the three header glass action buttons (download/favorite/read) each scale with their symbol — none overflows its circle. The stats strip keeps its horizontal `ScrollView`: scrolling it reveals every column (Favorited, Language, Ratings, Page Count, File Size on this gallery), each label+value complete and the five-star row un-clipped, with no column spanning the full container width. **Re-verify (batch 5b, `881104c0`):** landscape AX5 keeps the full title in three lines (the wide layout fits it, so nothing is truncated); the three-line fold engages in portrait. |
| 15 | Detail › Previews | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Grid stays three columns; every page number reads in full and the navigation title is complete. Walked to page 30. |
| 15 | Detail › Previews | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Page numbers grow with the type size and the grid spaces itself to fit them; nothing clipped or ellipsised. |
| 15 | Detail › Previews | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Page numbers render at full accessibility size beside their thumbnails, grid unchanged, navigation title complete. Walked past page 50. |
| 15 | Detail › Previews | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Three-column grid, all page numbers and the navigation title read in full. |
| 15 | Detail › Previews | iPhone | landscape | AX3 (accessibility-extra-large) | pass | No clipped or ellipsised value; the only text on the screen is the page number and it grows cleanly. |
| 15 | Detail › Previews | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Page numbers reach accessibility size without colliding with their thumbnails; grid and navigation title intact. |
| 16 | Detail › Comments | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Comment bodies wrap and read in full, but the scored rows' timestamps lose their minutes at the right edge of the header row. Authors still complete. Re-verify (batch 1): author, vote score and the complete timestamp all read — the meta moves to its own line beneath the author. |
| 16 | Detail › Comments | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Every author is ellipsised ("Pecan…", "ezeq…") and every timestamp is cut back to its year ("2025/…"). Bodies and vote scores read in full. Re-verify (batch 1): authors read in full and each timestamp keeps its date and time on the stacked meta line. |
| 16 | Detail › Comments | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Authors down to three or four characters ("Pec…", "eze…") and timestamps to "20…"; the header row keeps its single-line layout instead of stacking. Bodies wrap fully and the post-comment sheet (opened and cancelled, nothing posted) reads in full. Re-verify (batch 1): authors and timestamps are complete on their own line; bodies wrap without loss. |
| 16 | Detail › Comments | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Author, vote score, full timestamp and body all read in full on every row walked. Re-verify (batch 1): unchanged. |
| 16 | Detail › Comments | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Header rows still fit — author, score and the complete "YYYY/MM/DD, HH:MM" timestamp — and bodies wrap without loss. Re-verify (batch 1): unchanged. |
| 16 | Detail › Comments | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Authors and bodies read in full, but the scored row's timestamp loses its minutes ("2025/04/20, 7:…"). Re-verify (batch 1): the scored row's timestamp keeps its minutes; author and body are complete. |
| 17 | Detail › Detail Search | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#5 | Reached by tapping a tag in the Detail tag cloud. Long row titles lose their tail at the third line; uploader, language, rating, page count, category badge and date all read in full, and the search term in the navigation bar is complete. |
| 17 | Detail › Detail Search | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#5, #6 | Titles truncated; the row's right-hand column is cut by the screen edge — language loses its last letter, the page-count number loses digits and the date loses its time. |
| 17 | Detail › Detail Search | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#5, #6, #8, #9 | Titles run off the right edge cut mid-word with no ellipsis; uploader ellipsised beside the language value; page count reduced to its glyph; date cut after the month; cover thumbnail squeezed to a sliver. |
| 17 | Detail › Detail Search | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Every row value reads in full in the rows walked, search term included. |
| 17 | Detail › Detail Search | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Titles wrap to three complete lines; uploader, language, rating, page count, category and the full timestamp all read in full. |
| 17 | Detail › Detail Search | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#5 | A long bracketed title loses its tail at the third line; every other row value, including the full timestamp, reads in full. |
| 18 | Detail › Gallery Infos | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Reached through the trailing ellipsis item of the Detail stats strip. Every row reflows to a label-above-value layout when needed; title, all five URLs, uploader, timestamp and every count read in full. Re-verify (batch 1): unchanged. |
| 18 | Detail › Gallery Infos | iPhone | portrait | AX3 (accessibility-extra-large) | pass | The Archive URL and Torrent URL values are ellipsised at their third line, losing the token that is the whole point of the row; the remaining rows still read in full. Re-verify (batch 1): the three-line cap is lifted above the default size — every URL, title and identifier wraps in full. |
| 18 | Detail › Gallery Infos | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Title, Gallery URL, Archive URL, Torrent URL and Parent URL are all cut at the third line; the numeric rows and the uploader still read in full and the ID wraps rather than truncating. Re-verify (batch 1): every value wraps in full; no URL, identifier or title row is ellipsised. |
| 18 | Detail › Gallery Infos | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Every row, URLs included, reads in full. Re-verify (batch 1): unchanged. |
| 18 | Detail › Gallery Infos | iPhone | landscape | AX3 (accessibility-extra-large) | pass | The wider line lets all five URLs finish inside three lines; nothing clipped. Re-verify (batch 1): unchanged. |
| 18 | Detail › Gallery Infos | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Title tail, all five URLs, uploader and every count read in full — the three-line cap is only reached in portrait. Re-verify (batch 1): unchanged. |
| 19 | Detail › Archives sheet | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Session present. Both archive cards keep their name, size and price inside the card; both funds values and the H@H action read in full. Nothing was purchased. Re-verify (batch 1): unchanged. Re-verify (batch 2): the pinned layout is kept — grid, funds row and the download button are all on screen at once, unchanged from batch 1. |
| 19 | Detail › Archives sheet | iPhone | portrait | AX3 (accessibility-extra-large) | pass | The first card's name is ellipsised ("Origin…") and its price line is pushed outside the card's border; both funds values lose most of their digits ("500,…", "7,1…"). Re-verify (batch 1): the grid collapses to one card per row and name, size and price all read inside the card. Nothing was purchased. Re-verify (batch 2): the sheet is one scrolling column; both archive cards read with their size and price, and the funds row and the download button are reachable by scrolling. Re-verify (batch 2b, `a92e5465`): the single-column AX layout no longer draws a scroll indicator. At AX3 portrait the whole column fits, so the funds row and the button are reachable without scrolling and no indicator can appear; a capture taken with no settle delay right after a swipe measures a 0.0 pt bright run at the trailing edge. |
| 19 | Detail › Archives sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Card names down to "Orig…" / "128…" — the two resolutions are no longer distinguishable — sizes cut to "182.0…" without their unit, both texts drawn outside the card frame, and the funds values reduced to "50…" and "7,…". Re-verify (batch 1): one card per row with name, size and price complete; the grid scrolls to the second card. Nothing was purchased. Re-verify (batch 2): the sheet is one scrolling column; both archive cards read with their size and price at the top, and scrolling reaches the funds row and the download button. The G funds value wraps mid-number onto a second line in portrait — a wrap, not a truncation. Re-verify (batch 2b, `a92e5465`): no scroll indicator — a capture taken with no settle delay immediately after the swipe measures a 0.0 pt bright run at the trailing edge, against 286.3 pt for the same capture technique on a surface that does draw one (Setting › General). The column still scrolls to the funds row and the action button. |
| 19 | Detail › Archives sheet | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Both cards, both funds values and the action button read in full. Re-verify (batch 1): unchanged. Re-verify (batch 2): the pinned layout is kept — grid, funds row and the download button are all on screen at once, unchanged from batch 1. |
| 19 | Detail › Archives sheet | iPhone | landscape | AX3 (accessibility-extra-large) | finding:#20 | Both cards lose their size AND price lines entirely — only the resolution name survives — so the sheet no longer shows what an archive costs or how large it is. Funds values still read in full. Re-verify (batch 1): still degraded in landscape — the archive grid is clipped to a sliver with the funds row drawn over it and the second card absent. Nothing was purchased. Re-verify (batch 2): the sheet is one scrolling column; both archive cards read with their size and price, and the funds row and the download button are reachable by scrolling. Re-verify (batch 2b, `a92e5465`): no scroll indicator (0.0 pt bright run at the trailing edge, captured with no settle delay after the swipe); the column still scrolls to the funds row and the action button, both of which read in full. |
| 19 | Detail › Archives sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#20 | The cards are clipped to a sliver of their name, with the funds row drawn on top of them; the GP balance is ellipsised. Nothing was purchased. Re-verify (batch 1): still degraded — no archive card is rendered at all; only the funds row and the download button remain. Nothing was purchased. Re-verify (batch 2): the sheet is one scrolling column; both archive cards read with their size and price at the top, and scrolling reaches the funds row and the download button. The G funds value wraps mid-number onto a second line in portrait — a wrap, not a truncation. Re-verify (batch 2b, `a92e5465`): no scroll indicator (0.0 pt bright run at the trailing edge, captured with no settle delay after the swipe); the column still scrolls to the funds row and the action button. |
| 20 | Detail › Torrents sheet | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#21 | All four meta values (seeders, leechers, downloads, file size), the torrent file name and the uploader-plus-timestamp line read in full. No torrent download was started. Re-verify (batch 1): regression against the round-1 `pass` — the file-size value is now ellipsised although seeders, leechers and downloads still read, and the same row is complete at `.large`. No torrent download was started. Re-verify (batch 2): REGRESSED. Above the default size the counter row is a FlowLayout of four Label pairs, and every pair is laid out at its icon's size alone (44 x 44 pt at AX5), so all four values — seeders, leechers, downloads and file size — are not rendered at all; only the glyphs appear, and they cascade diagonally. Round I still showed every value (with only the file size ellipsised). Uploader and date are unaffected and read in full. Re-verify (batch 2b, `a731d905`): **the round-II regression is gone.** The flowed pairs are plain `HStack`s instead of `Label`s, so each pair measures its glyph and its value together: all four values render in full on one line — 6, 1, 2,526 and 501.8 MiB — with no ellipsis and no clipped glyph. |
| 20 | Detail › Torrents sheet | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#21 | The four meta values are clipped by their fixed 44-point slots — the leechers "0" renders as a half glyph, the download count keeps only a fragment, and the file size is reduced to its first digit. The timestamp also loses its time. Re-verify (batch 1): still degraded, and differently: the compact one-line row is still chosen, so all four values are cut mid-glyph inside their slots. No torrent download was started. Re-verify (batch 2): REGRESSED. Above the default size the counter row is a FlowLayout of four Label pairs, and every pair is laid out at its icon's size alone (44 x 44 pt at AX5), so all four values — seeders, leechers, downloads and file size — are not rendered at all; only the glyphs appear, and they cascade diagonally. Round I still showed every value (with only the file size ellipsised). Uploader and date are unaffected and read in full. Re-verify (batch 2b, `a731d905`): all four values render in full over two lines (6 / 1 / 2,526, then 501.8 MiB); no value is cut mid-glyph and the file size is complete. |
| 20 | Detail › Torrents sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | The four meta values are not rendered at all — only their glyphs remain, so seeders, leechers, downloads and file size are all invisible. The uploader and the timestamp are ellipsised to four characters each. Re-verify (batch 1): the meta reflows to two pairs per line and all four values read in full. No torrent download was started. Re-verify (batch 2): REGRESSED. Above the default size the counter row is a FlowLayout of four Label pairs, and every pair is laid out at its icon's size alone (44 x 44 pt at AX5), so all four values — seeders, leechers, downloads and file size — are not rendered at all; only the glyphs appear, and they cascade diagonally. Round I still showed every value (with only the file size ellipsised). Uploader and date are unaffected and read in full. Re-verify (batch 2b, `a731d905`): all four values render in full over three lines (6 and 1, then 2,526, then 501.8 MiB); the file name, uploader and timestamp below read in full when scrolled. |
| 20 | Detail › Torrents sheet | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Meta row, file name and the uploader-plus-timestamp line all read in full. Re-verify (batch 1): unchanged. Re-verify (batch 2): REGRESSED. Above the default size the counter row is a FlowLayout of four Label pairs, and every pair is laid out at its icon's size alone (44 x 44 pt at AX5), so all four values — seeders, leechers, downloads and file size — are not rendered at all; only the glyphs appear, and they cascade diagonally. Round I still showed every value (with only the file size ellipsised). Uploader and date are unaffected and read in full. Re-verify (batch 2b, `a731d905`): all four values render in full on one line. |
| 20 | Detail › Torrents sheet | iPhone | landscape | AX3 (accessibility-extra-large) | pass | The wider row keeps all four meta values, the whole file name over two lines and the full timestamp. Re-verify (batch 1): unchanged. Re-verify (batch 2): REGRESSED. Above the default size the counter row is a FlowLayout of four Label pairs, and every pair is laid out at its icon's size alone (44 x 44 pt at AX5), so all four values — seeders, leechers, downloads and file size — are not rendered at all; only the glyphs appear, and they cascade diagonally. Round I still showed every value (with only the file size ellipsised). Uploader and date are unaffected and read in full. Re-verify (batch 2b, `a731d905`): all four values render in full on one line. |
| 20 | Detail › Torrents sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Meta values, file name and timestamp all read in full; the sheet's own title is complete. Re-verify (batch 1): unchanged. Re-verify (batch 2): REGRESSED. Above the default size the counter row is a FlowLayout of four Label pairs, and every pair is laid out at its icon's size alone (44 x 44 pt at AX5), so all four values — seeders, leechers, downloads and file size — are not rendered at all; only the glyphs appear, and they cascade diagonally. Round I still showed every value (with only the file size ellipsised). Uploader and date are unaffected and read in full. Re-verify (batch 2b, `a731d905`): all four values render in full on one line. |
| 21 | Detail › Tag Detail sheet | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Unblocked by the batch-8 settings change (session language 简体中文, Tags Extension and Translate Tags on), so the tag context menu offers its **Detail** item and the sheet is reachable at last. Walked on a parody tag carrying a description, one image and three links. The description reads to its closing period over five lines, the Images section keeps its heading and thumbnail, and all three link URLs read to their last percent-escape. Nothing is clipped or ellipsised; the sheet reaches its own end. |
| 21 | Detail › Tag Detail sheet | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Description complete over eight lines, Images heading and thumbnail intact, and every one of the three link URLs wraps in full. The large title collapses to an inline one as the column scrolls, which is the phase title policy, not a loss. |
| 21 | Detail › Tag Detail sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Title, description, Images heading and thumbnail and all three URLs all render at accessibility size with every character present; the column simply grows and scrolls. Content passes under the inline bar material, which is ordinary chrome behaviour. |
| 21 | Detail › Tag Detail sheet | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Inline title; the description finishes in three lines and the Images row and all three link URLs read in full. |
| 21 | Detail › Tag Detail sheet | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Description complete over four lines; every link URL reads to its end. |
| 21 | Detail › Tag Detail sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Description complete over five lines, the Images heading and thumbnail render at full size, and both remaining URLs read to their last percent-escape after scrolling. |
| 22 | Detail › NewDawn sheet | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Walked in batch 9 against a greeting surfaced by a temporary, never-committed presentation injection (the owner authorised mocking, since only the layout is under test); `NewDawnView` itself was unmodified and the build was reverted and reinstalled clean afterwards. Title, body and the full reward sentence all render; nothing is lost against `.large`. Content shown was the real server greeting (30 EXP, 10,452 Credits, 10,000 GP, 16 Hath), the longer of the two strings available. |
| 22 | Detail › NewDawn sheet | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Walked in batch 9 against a greeting surfaced by a temporary, never-committed presentation injection (the owner authorised mocking, since only the layout is under test); `NewDawnView` itself was unmodified and the build was reverted and reinstalled clean afterwards. Every line renders in full; the block grows but stays inside the screen. Real greeting. |
| 22 | Detail › NewDawn sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Walked in batch 9 against a greeting surfaced by a temporary, never-committed presentation injection (the owner authorised mocking, since only the layout is under test); `NewDawnView` itself was unmodified and the build was reverted and reinstalled clean afterwards. The whole greeting still renders, ending at `16 Hath!`, but the block now spans the screen top to bottom with no margin at either end and the title is drawn across the decorative sun. Nothing is lost against `.large`, so this passes the D-04 test; the collision and the absent margin are recorded as design residue on finding #38. Real greeting, i.e. the stricter string. |
| 22 | Detail › NewDawn sheet | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Walked in batch 9 against a greeting surfaced by a temporary, never-committed presentation injection (the owner authorised mocking, since only the layout is under test); `NewDawnView` itself was unmodified and the build was reverted and reinstalled clean afterwards. All three blocks render complete. The Dynamic Island covers the first characters of two lines, but it does so identically at `.large`, so that is not a type-size regression. |
| 22 | Detail › NewDawn sheet | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Walked in batch 9 against a greeting surfaced by a temporary, never-committed presentation injection (the owner authorised mocking, since only the layout is under test); `NewDawnView` itself was unmodified and the build was reverted and reinstalled clean afterwards. All text renders; same pre-existing Dynamic Island overlap as at `.large`. |
| 22 | Detail › NewDawn sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Walked in batch 9 against a greeting surfaced by a temporary, never-committed presentation injection (the owner authorised mocking, since only the layout is under test); `NewDawnView` itself was unmodified and the build was reverted and reinstalled clean afterwards. All text renders, the first line sitting hard against the top edge. Same pre-existing Dynamic Island overlap. |
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
| 25 | Reading › Control panel | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Page indicator "1 / 14" reads in full in its capsule; the upper bar's three glyph controls and the lower bar's "1" / slider / "14" are all complete. Re-verify (batch 3, `15f9b09f`): above the default size the control bar is a flow — close button and page indicator on the first line, the three action glyphs leading-aligned on the second. The indicator takes its ideal width and reads in full (96,76 95x34 pt). **Re-verify (batch 4, `89d02f52`):** confirmed again on a different (166-page) gallery — the upper panel's "n / total" page indicator stays on one line and fully legible; the lower panel's page-range end labels ("1" / "166") remain single-line, not truncated. |
| 25 | Reading › Control panel | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#22 | The page indicator's capsule is squeezed to a stub showing only an ellipsis — the current page and the page total are both gone. Lower bar and glyph controls still read in full. Re-verify (batch 3, `15f9b09f`): above the default size the control bar is a flow — close button and page indicator on the first line, the three action glyphs leading-aligned on the second. The indicator takes its ideal width and reads in full (96,76 147x53 pt; round 1 showed only an ellipsis). **Re-verify (batch 4, `89d02f52`):** confirmed again on a different (166-page) gallery — the upper panel's "n / total" page indicator stays on one line and fully legible; the lower panel's page-range end labels ("1" / "166") remain single-line, not truncated. |
| 25 | Reading › Control panel | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#22 | The page indicator renders nothing at all: its capsule is a two-point sliver beside the close button. The lower bar's "1" and "14", the three upper glyphs, the More menu and the Auto-Play menu all remain readable (menu items wrap to two lines and the menu scrolls to reach the last one). Re-verify (batch 3, `15f9b09f`): above the default size the control bar is a flow — close button and page indicator on the first line, the three action glyphs leading-aligned on the second. The indicator takes its ideal width and reads in full (96,76 186x67 pt; round 1 showed a two-point sliver with no glyph). **Re-verify (batch 4, `89d02f52`):** confirmed again on a different (166-page) gallery — the upper panel's "n / total" page indicator stays on one line and fully legible; the lower panel's page-range end labels ("1" / "166") remain single-line, not truncated. |
| 25 | Reading › Control panel | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Page indicator, glyph controls and slider end labels all read in full. |
| 25 | Reading › Control panel | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Page indicator "1 / 14" complete; nothing clipped in either bar. |
| 25 | Reading › Control panel | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Page indicator complete at accessibility size; both bars intact. The Auto-Play menu shows its header and first option inside the visible container with the rest laid out below it — synthetic drags dismissed the menu rather than scrolling it, so the remaining options' reachability in landscape is unconfirmed and is called out in the summary. The dual-page menu does not appear because this session's reading direction is Vertical. Re-verify (batch 3, `15f9b09f`): the landscape row is still wide enough for one line; the indicator reads in full at 164,16 186x67 pt. **Re-verify (batch 4, `89d02f52`):** confirmed again on a different (166-page) gallery — the upper panel's "n / total" page indicator stays on one line and fully legible; the lower panel's page-range end labels ("1" / "166") remain single-line, not truncated. |
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
| 28 | Setting root | iPhone | portrait | XXL (extra-extra-extra-large) | pass | All seven rows and their icon slots read in full; the list does not scroll and the tab bar keeps five labels. Re-verify (batch 5b, `e8fd65c4`): the root's navigation title moves from `.inlineLarge` to the phase policy's `.large`; on a normal tab entry it draws a plain large title (`Setting` 20,122 135x48, leading), and the rows below are unchanged. **Re-verify (batch 6, `be4665cf`):** the tab-root presentation keeps `.inlineLarge` after all — the mode is now read from the presentation context, so only the iPad sheet takes the plain large title. At `.large` the title is a persistent large leading `Setting` (20,70 115x41) that does not move when the list is scrolled. |
| 28 | Setting root | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Rows grow taller, every label still complete; the 45-pt icon slot never clips its glyph. Re-verify (batch 5b, `e8fd65c4`): at AX3 the policy falls back to an inline title, drawn (`Setting` 175,77 69x25), not the blank band finding #7 records; rows unchanged. **Re-verify (batch 6, `be4665cf`):** unchanged at this size — the accessibility fallback is the same inline title either way; measured `Setting` 175,77 69x25, drawn. |
| 28 | Setting root | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | All seven labels read in full on one line each; icons stay inside their 45-pt frame; nothing scrolls out of reach. Re-verify (batch 5b, `e8fd65c4`): at AX5 the title is inline and drawn (`Setting` 175,77 69x25), not blank; rows unchanged. **Re-verify (batch 6, `be4665cf`):** unchanged at this size — the accessibility fallback is the same inline title either way; measured `Setting` 175,77 69x25, drawn. The batch-5b caveat — that `.large` collapses on return from a Setting sub-screen on the iPhone — is withdrawn: the tab root no longer uses `.large`. |
| 28 | Setting root | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Rows read in full; the list scrolls to About. |
| 28 | Setting root | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Rows read in full; About reachable by scrolling. |
| 28 | Setting root | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Three and a half rows per screen but every label complete and About reachable; the floating tab bar overlays scrollable content only. Re-verify (batch 5b, `e8fd65c4`): landscape AX5 title is inline and drawn (centered), not blank; rows unchanged. |
| 29 | Setting › Account | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#24 | The hash cookie row's value loses about a third of the characters it shows at the default size; the numeric id and the ExHentai token still read in full. Labels wrap, rows reachable, logout confirmation complete. Re-verify (batch 3, `f9286303`): above the default size the cookie row stacks — key and validity glyph on the first line, value beneath it in a vertical-axis field spanning the row. The thirty-two-character hash wraps over three lines and reads in full, where round 1 cut it after fourteen characters. |
| 29 | Setting › Account | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#24 | The numeric member-id value, complete at the default size, is now ellipsised after five digits; the hash value is down to five characters and the ExHentai token to four. Re-verify (batch 3, `f9286303`): above the default size the cookie row stacks — key and validity glyph on the first line, value beneath it in a vertical-axis field spanning the row. The seven-digit member id and the thirty-two-character hash both read in full, where round 1 cut them to `23674…` and `729fb…`. |
| 29 | Setting › Account | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#24 | All three cookie value fields are reduced to three or four characters plus an ellipsis; the labels wrap to four lines each. The logout confirmation itself stays complete. Re-verify (batch 3, `f9286303`): above the default size the cookie row stacks — key and validity glyph on the first line, value beneath it in a vertical-axis field spanning the row. The hash occupies a 340x250 pt field over four wrapped lines and reads in full, where round 1 left three or four characters plus an ellipsis under a four-line key. |
| 29 | Setting › Account | iPhone | landscape | XXL (extra-extra-extra-large) | pass | The wider row lets every cookie value render in full, including the 32-character hash; all rows reachable. Re-verify (batch 3, `f9286303`): above the default size the cookie row stacks — key and validity glyph on the first line, value beneath it in a vertical-axis field spanning the row. The hash keeps all thirty-two characters, now in a 712x96 pt wrapped field under its key. |
| 29 | Setting › Account | iPhone | landscape | AX3 (accessibility-extra-large) | finding:#24 | The hash value drops from complete at XXL to roughly fourteen characters plus an ellipsis; ids and the ExHentai token still complete. Re-verify (batch 3, `f9286303`): above the default size the cookie row stacks — key and validity glyph on the first line, value beneath it in a vertical-axis field spanning the row. The hash reads in full in a 712x64 pt field, where round 1 cut it after sixteen characters. |
| 29 | Setting › Account | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#24 | The hash value is down to about twelve characters; the numeric ids survive. Labels wrap, nothing is unreachable. Re-verify (batch 3, `f9286303`): above the default size the cookie row stacks — key and validity glyph on the first line, value beneath it in a vertical-axis field spanning the row. The hash reads in full in a 712 pt wrapped field, where round 1 cut it after twelve characters. |
| 30 | Setting › Login | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Walked on a dedicated logged-out iPhone Air simulator created for this batch (same device type as `IPHONE_UDID`, so the Matrix geometry matches); the owner's simulators were never signed out. No credential was entered and the form was never submitted. Heading, both field labels, both placeholders and the submit chevron all read in full, and the form fits without scrolling. |
| 30 | Setting › Login | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Walked on a dedicated logged-out iPhone Air simulator created for this batch (same device type as `IPHONE_UDID`, so the Matrix geometry matches); the owner's simulators were never signed out. No credential was entered and the form was never submitted. Labels and placeholders grow cleanly, the fields keep their full width and the submit chevron stays clear of the tab bar; the form still fits without scrolling. |
| 30 | Setting › Login | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Walked on a dedicated logged-out iPhone Air simulator created for this batch (same device type as `IPHONE_UDID`, so the Matrix geometry matches); the owner's simulators were never signed out. No credential was entered and the form was never submitted. The large title falls back to an inline one and the heading no longer paints through the `Username` label — finding #33's fix holds on the iPhone as it does on the iPad. Both labels, both placeholders and the submit chevron read in full and the form fits without scrolling. Focusing a field by tap changes nothing on screen; the software keyboard did not present because the simulator has a hardware keyboard attached, so the keyboard-inset path was not exercised. |
| 30 | Setting › Login | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Walked on a dedicated logged-out iPhone Air simulator created for this batch (same device type as `IPHONE_UDID`, so the Matrix geometry matches); the owner's simulators were never signed out. No credential was entered and the form was never submitted. Labels and placeholders read in full. The submit chevron rests half under the floating tab bar — it is fully visible there at `.large` — and one scroll brings it clear and complete. Judged fine: the column grew taller and the control moved below the fold of a scrolling form, which the verdict rule treats as reflow, not loss. |
| 30 | Setting › Login | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Walked on a dedicated logged-out iPhone Air simulator created for this batch (same device type as `IPHONE_UDID`, so the Matrix geometry matches); the owner's simulators were never signed out. No credential was entered and the form was never submitted. Labels and placeholders read in full; the submit chevron is below the fold at rest and one scroll brings it fully into view, clear of the tab bar. |
| 30 | Setting › Login | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Walked on a dedicated logged-out iPhone Air simulator created for this batch (same device type as `IPHONE_UDID`, so the Matrix geometry matches); the owner's simulators were never signed out. No credential was entered and the form was never submitted. Labels and placeholders read in full; the password field's lower edge passes under the tab bar at rest and two scrolls bring both it and the submit chevron fully into view. The toast and the error sheet were **not** walked: both are reachable only by submitting the form, and no login attempt was made. |
| 31 | Setting › General | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Every label, the Language value, the cache size value and the analytics footer read in full; the labels-hidden toggle in its 50-pt slot is a switch with no text and never clips. |
| 31 | Setting › General | iPhone | portrait | AX3 (accessibility-extra-large) | pass | Row labels wrap to two lines; Language value, cache size and the full analytics footer sentence all still read in full. |
| 31 | Setting › General | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Labels wrap to three or four lines and the cache size wraps onto its own second line — nothing is ellipsised, the footer renders every word, and the clear-cache confirmation shows its message and its action in full. |
| 31 | Setting › General | iPhone | landscape | XXL (extra-extra-extra-large) | pass | All rows on one line each, cache size and analytics footer complete; scrolls to the end of the footer. |
| 31 | Setting › General | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Rows still single-line, footer wraps to five lines and ends on its last word. |
| 31 | Setting › General | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Two rows per screen; every label, the Language value and the cache size read in full and the footer reaches its last word by scrolling. |
| 32 | Setting › General › Activity Logs | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Large title, search field, category chips, timestamps and every log message read in full; the Runs menu shows all its items and its selection tick. Re-verify (batch 1): unchanged. Re-verify (batch 2): timestamp and category chip sit in an AdaptiveStack — in portrait the chip drops to its own line under the timestamp and both read in full; in landscape the row is wide enough and they share a line. |
| 32 | Setting › General › Activity Logs | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#4, #7, #26 | The category chip is cut to seven characters; the navigation large title is ellipsised; the search field renders as an empty capsule with neither glyph nor placeholder; the Runs menu stops drawing the tick beside the selected run. Log messages themselves wrap in full. Re-verify (batch 1): the category chip now wraps inside its pill and keeps the whole subsystem name. Large title, search capsule and Runs menu (#4, #7, #26) belong to other batches and were not re-checked. Re-verify (batch 2): timestamp and category chip sit in an AdaptiveStack — in portrait the chip drops to its own line under the timestamp and both read in full; in landscape the row is wide enough and they share a line. Re-verify (batch 3, `27a360b1`): the inline title reads `App Activity Logs` in full (76,77 168x25 pt) where the large title was ellipsised, and the search capsule shows its magnifier and `Search` placeholder. The log rows below were not re-judged here. |
| 32 | Setting › General › Activity Logs | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#7, #26 | The chip is down to four characters plus an ellipsis and the large title is ellipsised after two words; the Runs menu still has no selection tick. The search field renders normally at this size and log messages wrap in full. Re-verify (batch 1): the chip wraps and reads in full. Large title and Runs menu (#7, #26) not re-checked. Re-verify (batch 2): timestamp and category chip sit in an AdaptiveStack — in portrait the chip drops to its own line under the timestamp and both read in full; in landscape the row is wide enough and they share a line. Re-verify (batch 3, `27a360b1`): the inline title reads `App Activity Logs` in full (76,77 168x25 pt) where the large title was ellipsised, and the search capsule shows its magnifier and `Search` placeholder. The log rows below were not re-judged here. |
| 32 | Setting › General › Activity Logs | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Everything single-line and complete, including the full chip and the whole message on one line. Re-verify (batch 1): unchanged. Re-verify (batch 2): timestamp and category chip sit in an AdaptiveStack — in portrait the chip drops to its own line under the timestamp and both read in full; in landscape the row is wide enough and they share a line. |
| 32 | Setting › General › Activity Logs | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Chip, timestamp and message all complete; search field intact. Re-verify (batch 1): unchanged. Re-verify (batch 2): timestamp and category chip sit in an AdaptiveStack — in portrait the chip drops to its own line under the timestamp and both read in full; in landscape the row is wide enough and they share a line. **Re-verify (batch 5b):** re-walked for finding #4's residual — the search capsule draws its magnifier glyph and `Search` placeholder, the inline title reads `App Activity Logs` in full, and the log rows are complete. |
| 32 | Setting › General › Activity Logs | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#4, #26 | The chip is ellipsised, the search field is an empty capsule and the Runs menu drops the selection tick; the large title survives in landscape because the bar uses its inline form. Re-verify (batch 1): the chip reads in full. Search capsule and Runs menu (#4, #26) not re-checked. Re-verify (batch 2): timestamp and category chip sit in an AdaptiveStack — in portrait the chip drops to its own line under the timestamp and both read in full; in landscape the row is wide enough and they share a line. **Re-verify (batch 5b):** finding #4's residual landscape occurrence is fixed — the search capsule draws its magnifier and `Search` placeholder (the round-1 sweep showed an empty capsule); the inline title reads `App Activity Logs` in full and the log rows are complete. The #26 Runs-menu-tick aspect was not re-checked. |
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
| 38 | Setting › EhSetting | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#27 | The Excluded Languages column headers collide into one unbroken string and slide off their columns, so the radio grid no longer says which column is which. Everything else — profile rows, pickers, the 200-pt segmented controls, the long explanatory paragraphs and both pixel sliders — reads in full to the end of the page. Re-verify (batch 3, `32177686`): above the default size the three-column radio matrix is replaced by one block per language, headed by the language name, with three native switches labelled Original / Translated / Rewrite. Round 1 ran the three headers together into `OriginalTranslatedRewrite` beside the columns they label; nothing overlaps now and every option carries its own word. |
| 38 | Setting › EhSetting | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#27 | Same column-header collision. All other rows wrap: labels take two or three lines, picker values move under their labels, slider bounds wrap rather than truncate, and the page scrolls to its last row. Re-verify (batch 3, `32177686`): above the default size the three-column radio matrix is replaced by one block per language, headed by the language name, with three native switches labelled Original / Translated / Rewrite. Round 1 left rows of identical unlabelled circles; every switch is now named. |
| 38 | Setting › EhSetting | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#27, #28 | Column headers still collided; additionally three consecutive Multi-Page Viewer rows overlap — a three-line label painted over the next row's label and a picker value cut by the row separator. The 200-pt segmented controls and every explanatory paragraph still read in full. Re-verify (batch 3, `32177686`): above the default size the three-column radio matrix is replaced by one block per language, headed by the language name, with three native switches labelled Original / Translated / Rewrite. Round 1 painted the three headers on top of each other and past the card's trailing edge. |
| 38 | Setting › EhSetting | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Every native row single-line with its value complete, the 200-pt segmented controls and both sliders intact, and the Excluded Languages column headers still separated and centred over their columns. |
| 38 | Setting › EhSetting | iPhone | landscape | AX3 (accessibility-extra-large) | pass | Labels and picker values move onto separate lines; nothing is truncated and the language-grid headers still read as three separate words. |
| 38 | Setting › EhSetting | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#27 | The Excluded Languages headers collide into one overlapping string. Everything else survives: the Multi-Page Viewer rows that overlap in portrait are clean here, and the 200-pt segmented controls read in full. Re-verify (batch 3, `32177686`): above the default size the three-column radio matrix is replaced by one block per language, headed by the language name, with three native switches labelled Original / Translated / Rewrite. Round 1 ran the headers together into one string here too. |
| 39 | Filters sheet | iPhone | portrait | XXL (extra-extra-extra-large) | finding:#29 | Two of the nine category cells are already ellipsised; the host segmented control, Reset Filters, every advanced toggle row and the custom-filter rows read in full to the bottom of the sheet. Re-verify (batch 3, `7645e10c`): the adaptive column bounds scale with the text and a name that still does not fit wraps instead of losing its tail. Three columns; Game CG, Image Set and Asian Porn wrap to two lines and all ten names read in full. **Re-verify (batch 4, `db5afd4e`):** the category cell's corner radius now scales with its text (`@ScaledMetric(relativeTo: .body)`), so every chip reads rounded, not square, at this size. Walked the whole sheet top to bottom: 3 columns, all ten names complete, and every control below the grid (Reset Filters, Advanced Settings, the search-scope toggles, the minimum-rating stepper, the pages-range fields, the custom-filter toggles) renders correctly with nothing clipped or overlapping. |
| 39 | Filters sheet | iPhone | portrait | AX3 (accessibility-extra-large) | finding:#29 | Eight of the nine category names are cut to three or four letters. Everything else on the sheet wraps and stays complete. Re-verify (batch 3, `7645e10c`): the adaptive column bounds scale with the text and a name that still does not fit wraps instead of losing its tail. One column, each name on its own full-width row, all ten complete. **Re-verify (batch 4, `db5afd4e`):** the category cell's corner radius now scales with its text (`@ScaledMetric(relativeTo: .body)`), so every chip reads rounded, not square, at this size. Walked the whole sheet top to bottom: 1 columns, all ten names complete, and every control below the grid (Reset Filters, Advanced Settings, the search-scope toggles, the minimum-rating stepper, the pages-range fields, the custom-filter toggles) renders correctly with nothing clipped or overlapping. |
| 39 | Filters sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#29 | Every category cell is one or two letters plus an ellipsis. The rest of the sheet is fine — advanced rows wrap to three lines, the reset confirmation shows its message and action in full, and the sheet scrolls to its last row. Re-verify (batch 3, `7645e10c`): the adaptive column bounds scale with the text and a name that still does not fit wraps instead of losing its tail. One column, all ten names complete, where round 1 cut every one of them to a letter or two. **Re-verify (batch 4, `db5afd4e`):** the category cell's corner radius now scales with its text (`@ScaledMetric(relativeTo: .body)`), so every chip reads rounded, not square, at this size. Walked the whole sheet top to bottom: 1 columns, all ten names complete, and every control below the grid (Reset Filters, Advanced Settings, the search-scope toggles, the minimum-rating stepper, the pages-range fields, the custom-filter toggles) renders correctly with nothing clipped or overlapping. |
| 39 | Filters sheet | iPhone | landscape | XXL (extra-extra-extra-large) | finding:#29 | The grid relays out six per row but the cells keep their width, so the same two names are ellipsised; the rest of the sheet is complete. Re-verify (batch 3, `7645e10c`): the adaptive column bounds scale with the text and a name that still does not fit wraps instead of losing its tail. Five columns, all ten names on one line each, complete. **Re-verify (batch 4, `db5afd4e`):** the category cell's corner radius now scales with its text (`@ScaledMetric(relativeTo: .body)`), so every chip reads rounded, not square, at this size. Walked the whole sheet top to bottom: 5 columns, all ten names complete, and every control below the grid (Reset Filters, Advanced Settings, the search-scope toggles, the minimum-rating stepper, the pages-range fields, the custom-filter toggles) renders correctly with nothing clipped or overlapping. |
| 39 | Filters sheet | iPhone | landscape | AX3 (accessibility-extra-large) | finding:#29 | Eight of nine category names cut; other rows single-line and complete. Re-verify (batch 3, `7645e10c`): the adaptive column bounds scale with the text and a name that still does not fit wraps instead of losing its tail. Three columns, all ten names complete. **Re-verify (batch 4, `db5afd4e`):** the category cell's corner radius now scales with its text (`@ScaledMetric(relativeTo: .body)`), so every chip reads rounded, not square, at this size. Walked the whole sheet top to bottom: 3 columns, all ten names complete, and every control below the grid (Reset Filters, Advanced Settings, the search-scope toggles, the minimum-rating stepper, the pages-range fields, the custom-filter toggles) renders correctly with nothing clipped or overlapping. |
| 39 | Filters sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#29 | All nine category cells reduced to one or two letters; the advanced and custom-filter rows still read in full on one line each. Re-verify (batch 3, `7645e10c`): the adaptive column bounds scale with the text and a name that still does not fit wraps instead of losing its tail. Two columns, all ten names complete. **Re-verify (batch 4, `db5afd4e`):** the category cell's corner radius now scales with its text (`@ScaledMetric(relativeTo: .body)`), so every chip reads rounded, not square, at this size. Walked the whole sheet top to bottom: 2 columns, all ten names complete, and every control below the grid (Reset Filters, Advanced Settings, the search-scope toggles, the minimum-rating stepper, the pages-range fields, the custom-filter toggles) renders correctly with nothing clipped or overlapping. |
| 40 | Quick Search sheet | iPhone | portrait | XXL (extra-extra-extra-large) | pass | The saved word and its content both read in full in the normal row, but Edit mode narrows the row between its delete and reorder controls and cuts the saved name to `Dynamic Type Sweep…`; the empty state, editor labels and entered values otherwise read in full. Re-verify (batch 1): the saved word's name and its content both read in full in the ordinary row and in Edit mode. |
| 40 | Quick Search sheet | iPhone | portrait | AX3 (accessibility-extra-large) | pass | The normal row already cuts the saved name to `Dynamic Type Sw…`; Edit mode also cuts the content after a few characters. The sheet and editor remain reachable and their other labels wrap in full. Re-verify (batch 1): name and content read in full in both the ordinary row and Edit mode. |
| 40 | Quick Search sheet | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | The normal row reduces the saved name and content to ellipsised fragments; Edit mode loses still more of both lines. The throwaway item was deleted after the walk and the original empty state was verified. Re-verify (batch 1): name and content read in full in both modes; the editor itself is complete. |
| 40 | Quick Search sheet | iPhone | landscape | XXL (extra-extra-extra-large) | pass | The saved name and content read in full in both normal and Edit modes; the empty state and editor are also complete. Re-verify (batch 1): unchanged. |
| 40 | Quick Search sheet | iPhone | landscape | AX3 (accessibility-extra-large) | pass | The wider row keeps the full saved name and content in normal and Edit modes; controls remain reachable. Re-verify (batch 1): unchanged. |
| 40 | Quick Search sheet | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | The saved name is cut in both normal and Edit modes while the content stays complete; the editor itself remains usable. Re-verify (batch 1): the saved name reads in full in both normal and Edit modes. |
| 41 | Date Seek picker | iPhone | portrait | XXL (extra-extra-extra-large) | pass | Month header, weekday row, every day number, the explanatory sentence and both Older / Newer buttons read in full. |
| 41 | Date Seek picker | iPhone | portrait | AX3 (accessibility-extra-large) | pass | The graphical calendar keeps every date legible; the sentence wraps to two lines and both navigation buttons remain fully visible. |
| 41 | Date Seek picker | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Weekday abbreviations and day numbers remain distinct, the sentence wraps in full, and scrolling reaches both complete navigation buttons. |
| 41 | Date Seek picker | iPhone | landscape | XXL (extra-extra-extra-large) | pass | Month header, weekday row, every day number, the explanatory sentence and both Older / Newer buttons read in full. |
| 41 | Date Seek picker | iPhone | landscape | AX3 (accessibility-extra-large) | pass | The graphical date picker caps its own type scale, so the calendar is unchanged; the sentence and buttons below it grow and stay complete. |
| 41 | Date Seek picker | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Weekday abbreviations sit shoulder to shoulder but none is cut or overlapped; every day number, the whole sentence and both buttons render, and the selected day keeps its highlight. |
| 42 | Error surface | iPhone | portrait | XXL (extra-extra-extra-large) | pass | The error sheet scrolls through its complete description, solution, context and environment, but the toast keeps its title and ellipsises the one-line subtitle after `This link wasn't recognized…`. Re-verify (batch 1): the toast subtitle now reads the whole sentence over two lines. |
| 42 | Error surface | iPhone | portrait | AX3 (accessibility-extra-large) | accepted | The error sheet reflows every field and remains scrollable to the operating-system row; the toast subtitle is cut to `This link was…`. Re-verify (batch 1): still degraded — the subtitle is ellipsised after three lines. |
| 42 | Error surface | iPhone | portrait | AX5 (accessibility-extra-extra-extra-large) | accepted | The error sheet grows substantially but every section is reachable and complete; the toast subtitle is reduced to `This link…`. Re-verify (batch 1): still degraded — the subtitle is ellipsised after three lines. |
| 42 | Error surface | iPhone | landscape | XXL (extra-extra-extra-large) | pass | The toast title and complete unsupported-link subtitle fit on one line, and the error sheet scrolls through every complete field. Re-verify (batch 1): unchanged. |
| 42 | Error surface | iPhone | landscape | AX3 (accessibility-extra-large) | pass | The error sheet remains complete to its Environment section, but the toast subtitle ends after `EhPa…`. Re-verify (batch 1): the toast subtitle reads the whole sentence. |
| 42 | Error surface | iPhone | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | The error sheet remains complete and scrollable; the toast subtitle is ellipsised after `This link wasn't recognized…`. Re-verify (batch 1): the toast subtitle reads the whole sentence. |

### iPad — Group A (#1–#13) — plan 16-07

| # | Screen | Device | Orientation | Size | Status | Finding |
|---|---|---|---|---|---|---|
| 1 | Tab bar shell | iPad | portrait | XXL (extra-extra-extra-large) | pass | The system overflow keeps the fifth tab reachable while every visible tab label remains complete. |
| 1 | Tab bar shell | iPad | portrait | AX3 (accessibility-extra-large) | pass | The tab bar keeps its system-capped text and overflow affordance; no label clips. |
| 1 | Tab bar shell | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | The tab bar keeps its system-capped text and overflow affordance; every tab remains reachable. |
| 1 | Tab bar shell | iPad | landscape | XXL (extra-extra-extra-large) | pass | All five tab labels and glyphs render in full. |
| 1 | Tab bar shell | iPad | landscape | AX3 (accessibility-extra-large) | pass | All five tab labels and glyphs render in full. |
| 1 | Tab bar shell | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | All five tab labels and glyphs render in full. |
| 2 | Home root | iPad | portrait | XXL (extra-extra-extra-large) | pass | Hero title loses its tail; ranking titles that read in full at the baseline now ellipsise. Sections and tab shell remain reachable. Re-verify (batch 1): the hero title is complete and the ranking rows keep title and uploader. Re-verify (batch 2): the card is 668 x 243 pt, cover and title side by side, rating under the title. The section headings below stack leading-aligned at the accessibility sizes with Show All on its own line, and no blank line where a section has none. |
| 2 | Home root | iPad | portrait | AX3 (accessibility-extra-large) | finding:#1 | Hero title collapses to one ellipsised line; ranking titles and uploaders surrender more text. Re-verify (batch 1): the hero title still ends in an ellipsis; the ranking rows are complete. Re-verify (batch 2): the card is 668 x 388 pt (32% of the screen), rating on its own row. The section headings below stack leading-aligned at the accessibility sizes with Show All on its own line, and no blank line where a section has none. |
| 2 | Home root | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Hero title keeps only its opening words; ranking titles and uploaders are heavily ellipsised. Re-verify (batch 1): the hero title reads in full over seven lines; ranking rows complete. Re-verify (batch 2): the card is 668 x 494 pt (41% of the screen; the half-viewport cap does not bite here), cover and title side by side, rating on its own row, title ellipsised at its tail. The section headings below stack leading-aligned at the accessibility sizes with Show All on its own line, and no blank line where a section has none. |
| 2 | Home root | iPad | landscape | XXL (extra-extra-extra-large) | pass | The wider hero still ellipsises its title; ranking titles and uploaders remain complete. Re-verify (batch 1): hero title and ranking rows all read in full. Re-verify (batch 2): the card is 968 x 243 pt, cover and title side by side, rating under the title, title complete. The section headings below stack leading-aligned at the accessibility sizes with Show All on its own line, and no blank line where a section has none. |
| 2 | Home root | iPad | landscape | AX3 (accessibility-extra-large) | pass | Hero and ranking titles ellipsise; ranking uploaders remain visible. Re-verify (batch 1): hero title and ranking rows all read in full. Re-verify (batch 2): the card is 968 x 364 pt — exactly half the 728 pt scroll container — rating on its own row. The section headings below stack leading-aligned at the accessibility sizes with Show All on its own line, and no blank line where a section has none. |
| 2 | Home root | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Hero title and ranking titles lose still more text; several uploader lines ellipsise. Re-verify (batch 1): hero title and ranking rows all read in full. Re-verify (batch 2): the card is capped at the same 364 pt, cover and title side by side, rating on its own full-width row, title ellipsised at its tail. The section headings below stack leading-aligned at the accessibility sizes with Show All on its own line, and no blank line where a section has none. |
| 3 | Home › Frontpage | iPad | portrait | XXL (extra-extra-extra-large) | pass | Filter, title, uploader, category, page count and timestamp all read in full. Re-verify (batch 1): unchanged. Re-verify (batch 2): the row keeps the list's natural insets above the default size (no negative-inset hugging), the cover is scaled against .headline and bounded to half the row, the category badge's corners scale with its text and read as rounded, and title, uploader, language, rating, page count, badge and date all read in full. |
| 3 | Home › Frontpage | iPad | portrait | AX3 (accessibility-extra-large) | finding:#4 | Filter contents disappear; a long category badge grows over the timestamp beside it. Re-verify (batch 1): the category badge sits on its own line and the timestamp beside it reads in full. Filter capsule (#4) not re-checked. Re-verify (batch 2): the row keeps the list's natural insets above the default size (no negative-inset hugging), the cover is scaled against .headline and bounded to half the row, the category badge's corners scale with its text and read as rounded, and title, uploader, language, rating, page count, badge and date all read in full. **Re-verify (batch 4, `27a360b1`+`4fbd0ae9`, completing the batch-3 iPad walk):** the pull-to-reveal capsule draws its magnifier and "Filter" placeholder text (was empty). |
| 3 | Home › Frontpage | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Long titles lose their tails; category badges and timestamps overlap. The filter contents return. Re-verify (batch 1): row title, badge and timestamp all read in full and no two values are painted over each other. Re-verify (batch 2): the row keeps the list's natural insets above the default size (no negative-inset hugging), the cover is scaled against .headline and bounded to half the row, the category badge's corners scale with its text and read as rounded, and title, uploader, language, rating, page count, badge and date all read in full. Re-verify (batch 3, `0dde25eb`+`72234cbc`+`7645e10c`, Display Mode = Thumbnail): one full-width column (794 pt) against four in the pre-batch build; title complete, page count leading, language trailing, whole star row, badge whole. **Re-verify (batch 4, `27a360b1`+`4fbd0ae9`+`cbab163b`+`e30ddba0`):** the pull-to-reveal filter capsule still draws its magnifier and "Filter" placeholder text (this cell was not one of finding #4's failing ones for screen #3, and remains correct). Display Mode = Thumbnail: the 2-column floor holds, no cell background crosses into its neighbour or off-screen, five-symbol star row drawn. |
| 3 | Home › Frontpage | iPad | landscape | XXL (extra-extra-extra-large) | pass | All row values and the filter field read in full. Re-verify (batch 1): unchanged. Re-verify (batch 2): the row keeps the list's natural insets above the default size (no negative-inset hugging), the cover is scaled against .headline and bounded to half the row, the category badge's corners scale with its text and read as rounded, and title, uploader, language, rating, page count, badge and date all read in full. |
| 3 | Home › Frontpage | iPad | landscape | AX3 (accessibility-extra-large) | pass | All row values and the filter field remain complete. Re-verify (batch 1): unchanged. Re-verify (batch 2): the row keeps the list's natural insets above the default size (no negative-inset hugging), the cover is scaled against .headline and bounded to half the row, the category badge's corners scale with its text and read as rounded, and title, uploader, language, rating, page count, badge and date all read in full. |
| 3 | Home › Frontpage | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#4 | The filter renders as an empty capsule; the wider rows keep their values complete. Re-verify (batch 1): row values, badge and timestamp all read in full. Filter capsule (#4) not re-checked. Re-verify (batch 2): the row keeps the list's natural insets above the default size (no negative-inset hugging), the cover is scaled against .headline and bounded to half the row, the category badge's corners scale with its text and read as rounded, and title, uploader, language, rating, page count, badge and date all read in full. **Re-verify (batch 4, `cbab163b`+`e30ddba0`, Display Mode = Thumbnail, not walked in batch 3):** 2-column floor holds (this cell had never been captured in Thumbnail mode before); no cell background crosses into its neighbour or off-screen; five-symbol star row drawn. |
| 4 | Home › Popular | iPad | portrait | XXL (extra-extra-extra-large) | pass | Filter and every row value read in full. |
| 4 | Home › Popular | iPad | portrait | AX3 (accessibility-extra-large) | finding:#4 | The filter renders as an empty capsule; row titles and metadata remain complete. **Re-verify (batch 4, `27a360b1`+`4fbd0ae9`, completing the batch-3 iPad walk):** the pull-to-reveal capsule draws its magnifier and "Filter" placeholder text (was empty). |
| 4 | Home › Popular | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Filter contents return and the regular-width rows reflow without losing text. **Re-verify (batch 4, `27a360b1`+`4fbd0ae9`, completing the batch-3 iPad walk):** the pull-to-reveal capsule draws its magnifier and "Filter" placeholder text (was empty). |
| 4 | Home › Popular | iPad | landscape | XXL (extra-extra-extra-large) | pass | Filter and every row value read in full. |
| 4 | Home › Popular | iPad | landscape | AX3 (accessibility-extra-large) | finding:#4 | The filter contents disappear; row values remain complete. |
| 4 | Home › Popular | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#4 | The filter remains an empty capsule; the rows themselves preserve their contents. |
| 5 | Home › Watched | iPad | portrait | XXL (extra-extra-extra-large) | pass | Login-gated screen now reachable (owner signed in on `IPAD_UDID`, D-09). Watched rows reflow: title/uploader/stars/rounded badge/page count/full date all complete; scrolled rows identical. The wider iPad layout keeps title beside cover. |
| 5 | Home › Watched | iPad | portrait | AX3 (accessibility-extra-large) | pass | Filter field populated — iPhone finding #4 does not reproduce on iPad #5; title/uploader/stars/rounded badge/page count/full date complete; scrolled rows complete. |
| 5 | Home › Watched | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | 'Watched' nav title drawn (iPhone finding #7 not reproduced); pull-to-reveal filter capsule shows magnifier + Search placeholder; cover stacks above stacked text, every value complete; scrolled rows complete. |
| 5 | Home › Watched | iPad | landscape | XXL (extra-extra-extra-large) | pass | All five tab labels fit; compact rows keep title beside cover, rounded badge/page count/full date complete; scrolled rows complete. |
| 5 | Home › Watched | iPad | landscape | AX3 (accessibility-extra-large) | pass | Rows complete, filter field populated; sits between the XXL and AX5 passes; scrolled rows complete. |
| 5 | Home › Watched | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Watched title + populated filter; title/uploader/stars/page count/full date complete; scrolled rows complete. |
| 6 | Home › History | iPad | portrait | XXL (extra-extra-extra-large) | pass | Filter, preservation notice, and gallery-row values remain readable. |
| 6 | Home › History | iPad | portrait | AX3 (accessibility-extra-large) | pass | The notice stays on one line and every row value remains independently readable. |
| 6 | Home › History | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | The notice wraps cleanly; titles, ratings, categories, counts, and timestamps remain readable. |
| 6 | Home › History | iPad | landscape | XXL (extra-extra-extra-large) | pass | Filter, notice, and gallery-row values remain readable. |
| 6 | Home › History | iPad | landscape | AX3 (accessibility-extra-large) | pass | Rows reflow without clipping or overlapping their metadata. |
| 6 | Home › History | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | The wide row preserves all values at the largest sampled size. |
| 7 | Home › Toplists | iPad | portrait | XXL (extra-extra-extra-large) | pass | Filter and Toplists rows preserve their titles and metadata. Re-verify (batch 1): unchanged. |
| 7 | Home › Toplists | iPad | portrait | AX3 (accessibility-extra-large) | finding:#4 | The filter contents disappear; the gallery rows reflow without losing values. Re-verify (batch 1): every sampled row value reads in full. Filter capsule (#4) not re-checked. **Re-verify (batch 4, `27a360b1`+`4fbd0ae9`, completing the batch-3 iPad walk):** the pull-to-reveal capsule draws its magnifier and "Filter" placeholder text (was empty). |
| 7 | Home › Toplists | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Filter and every sampled row value remain visible at the largest size. Re-verify (batch 1): unchanged. **Re-verify (batch 4, `27a360b1`+`4fbd0ae9`, completing the batch-3 iPad walk):** the pull-to-reveal capsule draws its magnifier and "Filter" placeholder text (was empty). |
| 7 | Home › Toplists | iPad | landscape | XXL (extra-extra-extra-large) | pass | Filter and Toplists rows preserve their titles and metadata. Re-verify (batch 1): unchanged. |
| 7 | Home › Toplists | iPad | landscape | AX3 (accessibility-extra-large) | finding:#4 | The filter is an empty capsule; row values remain readable. Re-verify (batch 1): every sampled row value reads in full. Filter capsule (#4) not re-checked. |
| 7 | Home › Toplists | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#4 | The filter remains empty while the wide rows preserve their values. Re-verify (batch 1): every sampled row value reads in full. Filter capsule (#4) not re-checked. |
| 8 | Favorites root | iPad | portrait | XXL (extra-extra-extra-large) | pass | Reachable via the owner session (D-09). Rows reflow: title wraps complete, full 5-star row, rounded Misc badge, page count + full date/time; scrolled rows identical. |
| 8 | Favorites root | iPad | portrait | AX3 (accessibility-extra-large) | pass | Cover larger, title wraps 3 lines complete, stars full, rounded Doujinshi badge, language/page count/date complete, no badge-timestamp overlap; scrolled rows complete. |
| 8 | Favorites root | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Cover stacks above stacked text; title 4 lines complete, full star row, rounded badge, language/page count/full date complete. Index popover (All / Favorites 0..9), Sort menu ('By last gallery update time' / 'By favorited time') and Features menu (Date Seek / Quick Search) all wrap and read in full. |
| 8 | Favorites root | iPad | landscape | XXL (extra-extra-extra-large) | pass | All five tab labels fit; rows keep title beside cover, badge/language/page count/date complete; scrolled rows complete. |
| 8 | Favorites root | iPad | landscape | AX3 (accessibility-extra-large) | pass | Long title wraps 2 lines complete, stars full, rounded badge, page count/date complete; scrolled rows complete. |
| 8 | Favorites root | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Long Japanese title wraps 3 lines complete ending [DL版], full star row, rounded badge, page count/full date complete; scrolled rows complete. |
| 9 | Search root | iPad | portrait | XXL (extra-extra-extra-large) | pass | All three Recently Seen cards keep their covers, titles, and ratings readable. Re-verify (batch 1): unchanged. Re-verify (batch 2): the section heading is leading-aligned and wraps whole words, Show All drops to its own line at the accessibility sizes and is omitted entirely (with no blank line) where the section has none, and the keyword rows are leading-aligned with the magnifier on the keyword's first line. |
| 9 | Search root | iPad | portrait | AX3 (accessibility-extra-large) | pass | Fixed-height cards clip the tops of their titles and crowd their star rows. Re-verify (batch 1): the Recently Seen cards grow with the type; titles, uploaders and ratings all read. Re-verify (batch 2): the section heading is leading-aligned and wraps whole words, Show All drops to its own line at the accessibility sizes and is omitted entirely (with no blank line) where the section has none, and the keyword rows are leading-aligned with the magnifier on the keyword's first line. |
| 9 | Search root | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Titles largely disappear while the covers and uploader lines overflow their cells. Re-verify (batch 1): the cards grow with the type; titles, uploaders and ratings all read. Re-verify (batch 2): the section heading is leading-aligned and wraps whole words, Show All drops to its own line at the accessibility sizes and is omitted entirely (with no blank line) where the section has none, and the keyword rows are leading-aligned with the magnifier on the keyword's first line. |
| 9 | Search root | iPad | landscape | XXL (extra-extra-extra-large) | pass | The wider Recently Seen strip preserves every sampled card value. Re-verify (batch 1): unchanged. Re-verify (batch 2): the section heading is leading-aligned and wraps whole words, Show All drops to its own line at the accessibility sizes and is omitted entirely (with no blank line) where the section has none, and the keyword rows are leading-aligned with the magnifier on the keyword's first line. |
| 9 | Search root | iPad | landscape | AX3 (accessibility-extra-large) | pass | Fixed-height cells clip their title tops even in the wider layout. Re-verify (batch 1): the cards grow with the type; every sampled card value reads in full. Re-verify (batch 2): the section heading is leading-aligned and wraps whole words, Show All drops to its own line at the accessibility sizes and is omitted entirely (with no blank line) where the section has none, and the keyword rows are leading-aligned with the magnifier on the keyword's first line. |
| 9 | Search root | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Card contents overflow vertically and the title is no longer independently readable. Re-verify (batch 1): the cards grow with the type; every sampled card value reads in full. Re-verify (batch 2): the section heading is leading-aligned and wraps whole words, Show All drops to its own line at the accessibility sizes and is omitted entirely (with no blank line) where the section has none, and the keyword rows are leading-aligned with the magnifier on the keyword's first line. |
| 10 | Search results | iPad | portrait | XXL (extra-extra-extra-large) | pass | The query, result titles, uploader, category, count, and timestamp remain readable. |
| 10 | Search results | iPad | portrait | AX3 (accessibility-extra-large) | finding:#4 | The search/filter capsule is empty; the result rows themselves remain readable. **Re-verify (batch 4, `27a360b1`+`4fbd0ae9`, completing the batch-3 iPad walk):** the pull-to-reveal capsule draws the submitted query with a clear button (was empty). |
| 10 | Search results | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#4 | The capsule still loses its query text while the result rows reflow successfully. **Re-verify (batch 4, `27a360b1`+`4fbd0ae9`, completing the batch-3 iPad walk):** the pull-to-reveal capsule draws the submitted query with a clear button (was empty). |
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
| 13 | Downloads › Move-to-folder / FolderManager | iPad | portrait | XXL (extra-extra-extra-large) | pass | Reached through the Detail header's download menu (`Manage Folders`); the sheet is a regular-width form sheet. Sheet title, close and add controls and the `Default` folder row all read in full. The row's swipe actions are icon-only rename and delete glyphs, so they carry no text to lose. |
| 13 | Downloads › Move-to-folder / FolderManager | iPad | portrait | AX3 (accessibility-extra-large) | pass | Reached through the Detail header's download menu (`Manage Folders`); the sheet is a regular-width form sheet. Sheet title, close and add controls and the `Default` folder row all read in full. The row's swipe actions are icon-only rename and delete glyphs, so they carry no text to lose. |
| 13 | Downloads › Move-to-folder / FolderManager | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Reached through the Detail header's download menu (`Manage Folders`); the sheet is a regular-width form sheet. Sheet title, close and add controls and the `Default` folder row all read in full. The row's swipe actions are icon-only rename and delete glyphs, so they carry no text to lose. The delete confirmation itself was not raised — deleting a folder is forbidden on this simulator. |
| 13 | Downloads › Move-to-folder / FolderManager | iPad | landscape | XXL (extra-extra-extra-large) | pass | Reached through the Detail header's download menu (`Manage Folders`); the sheet is a regular-width form sheet. Sheet title, close and add controls and the `Default` folder row all read in full. The row's swipe actions are icon-only rename and delete glyphs, so they carry no text to lose. |
| 13 | Downloads › Move-to-folder / FolderManager | iPad | landscape | AX3 (accessibility-extra-large) | pass | Reached through the Detail header's download menu (`Manage Folders`); the sheet is a regular-width form sheet. Sheet title, close and add controls and the `Default` folder row all read in full. The row's swipe actions are icon-only rename and delete glyphs, so they carry no text to lose. |
| 13 | Downloads › Move-to-folder / FolderManager | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Reached through the Detail header's download menu (`Manage Folders`); the sheet is a regular-width form sheet. Sheet title, close and add controls and the `Default` folder row all read in full. The row's swipe actions are icon-only rename and delete glyphs, so they carry no text to lose. The delete confirmation itself was not raised — deleting a folder is forbidden on this simulator. |

### iPad — Group B (#14–#27) — plan 16-08

| # | Screen | Device | Orientation | Size | Status | Finding |
|---|---|---|---|---|---|---|
| 14 | Gallery Detail | iPad | portrait | XXL (extra-extra-extra-large) | pass | Regular-width modal card. Header: title 2-3 lines complete, cover, rounded Manga badge, action glyphs inside circles. **Stats strip (D-13)** is a horizontal `ScrollView`: FAVORITED/LANGUAGE/483 RATINGS (4.50 full star row)/PAGE COUNT complete, File Size reachable by horizontal scroll, no column spans full width. **Tag cloud (D-13)** wraps all chips inside the card, namespace chips inline, no right-edge clip. |
| 14 | Gallery Detail | iPad | portrait | AX3 (accessibility-extra-large) | pass | Header title 3 lines complete, rounded badge, actions. Stats strip labels+values complete, unit lines/star row reachable by vertical scroll within the card. Tag cloud wraps inside card, no clipping. |
| 14 | Gallery Detail | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Header title 3 lines complete (owner-accepted 3-line cap), rounded Manga badge, action glyphs inside circles. **Stats strip (D-13):** FAVORITED 15707 Times / LANGUAGE ZH Chinese complete, horizontal scroll reveals Ratings (star row)/Page Count/File Size all complete. **Tag cloud (D-13):** namespace chips (Language/Artist/Female) stacked above children, all 12 tags complete, no right-edge clip. Previews + Comments-preview sections render and read. |
| 14 | Gallery Detail | iPad | landscape | XXL (extra-extra-extra-large) | pass | Wider modal: full stats strip visible (5 columns, star row), full tag cloud (Language/Artist/Female/Mixed/Other) all complete, Previews/Show All below. |
| 14 | Gallery Detail | iPad | landscape | AX3 (accessibility-extra-large) | pass | Header + stats strip complete; tag cloud wraps, no clipping. |
| 14 | Gallery Detail | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Header title 3 lines complete, rounded badge. Stats strip FAVORITED/LANGUAGE complete (scroll for the rest); tag cloud namespace chips stacked above children, all tags complete, no clip. |
| 15 | Detail › Previews | iPad | portrait | XXL (extra-extra-extra-large) | pass | The Previews sheet keeps a five-column grid; every page number reads in full beneath its thumbnail and the inline sheet title and back control are complete. Walked past page 150. The full-screen cover opened from a thumbnail shows its page-number placeholder complete. |
| 15 | Detail › Previews | iPad | portrait | AX3 (accessibility-extra-large) | pass | Page numbers grow with the type size and the grid spaces itself to fit them; nothing clipped or ellipsised, title and back control intact. |
| 15 | Detail › Previews | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Page numbers render at full accessibility size beside their thumbnails, the grid stays five columns and nothing collides. In the full-screen cover the placeholder page number grows from 70x48 pt to 104x72 pt and still reads. |
| 15 | Detail › Previews | iPad | landscape | XXL (extra-extra-extra-large) | pass | Five-column grid, all page numbers and the sheet title read in full. |
| 15 | Detail › Previews | iPad | landscape | AX3 (accessibility-extra-large) | pass | The only text on the sheet is the page number and it grows cleanly; nothing clipped. |
| 15 | Detail › Previews | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Page numbers reach accessibility size without colliding with their thumbnails; grid and title intact. |
| 16 | Detail › Comments | iPad | portrait | XXL (extra-extra-extra-large) | pass | Comments render in a regular-width sheet. Author, vote score and the complete `YYYY/MM/DD, HH:MM` timestamp share one header line and all read; bodies wrap in full, including a multi-paragraph comment with a URL. Several screens of rows walked. The post-comment sheet was opened and dismissed without submitting — its title and both controls read. |
| 16 | Detail › Comments | iPad | portrait | AX3 (accessibility-extra-large) | pass | The author moves to its own line and the score plus the complete timestamp follow on the meta line beneath it; bodies wrap in full. Nothing ellipsised. |
| 16 | Detail › Comments | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Same stacked meta line — author, then score and a two-line timestamp — with bodies wrapping in full. The post-comment sheet's inline title and both controls still read. |
| 16 | Detail › Comments | iPad | landscape | XXL (extra-extra-extra-large) | pass | Author and the complete timestamp fit one line; bodies wrap without loss. |
| 16 | Detail › Comments | iPad | landscape | AX3 (accessibility-extra-large) | pass | Header row still fits on one line with the full timestamp; bodies complete. |
| 16 | Detail › Comments | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Author on its own line, score and wrapped timestamp beneath, bodies complete; three-digit scores (`+164`) read. |
| 17 | Detail › Detail Search | iPad | portrait | XXL (extra-extra-extra-large) | pass | Reached by tapping a tag in the Detail tag cloud; the results render in a regular-width sheet whose inline title carries the search term in full. Row titles wrap to as many lines as they need, and uploader, language, rating, page count, category badge and the full timestamp all read. |
| 17 | Detail › Detail Search | iPad | portrait | AX3 (accessibility-extra-large) | pass | The row reflows to cover-above-title; title, uploader, language, rating and page count all read in full. None of iPhone findings #5, #6, #8 or #9 reproduces here. |
| 17 | Detail › Detail Search | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Stacked row with the title complete over five lines; rating, page count, the `Artist CG` badge and the full timestamp all read. The features menu's Filters and Quick Search items read in full. |
| 17 | Detail › Detail Search | iPad | landscape | XXL (extra-extra-extra-large) | pass | Every row value reads in full, search term included. |
| 17 | Detail › Detail Search | iPad | landscape | AX3 (accessibility-extra-large) | pass | Cover-above-title reflow; badge and the complete timestamp sit side by side and both read. |
| 17 | Detail › Detail Search | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Titles wrap complete; badge and the full `2026/09/04, 1:30` timestamp both read. Rows grow much taller than the sheet and scroll, which D-03 treats as fine. |
| 18 | Detail › Gallery Infos | iPad | portrait | XXL (extra-extra-extra-large) | pass | Reached through the trailing ellipsis of the Detail stats strip (the strip has to be flicked sideways first in portrait). Every label and value reads; the long Archive URL drops below its label rather than truncating, and the counter rows at the bottom are complete. |
| 18 | Detail › Gallery Infos | iPad | portrait | AX3 (accessibility-extra-large) | pass | Rows reflow to value-under-label wherever the line no longer fits; every URL, identifier and counter reads in full. |
| 18 | Detail › Gallery Infos | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | The token hyphenates across two lines and the title wraps, both complete; every counter row down to Torrent Count reads. |
| 18 | Detail › Gallery Infos | iPad | landscape | XXL (extra-extra-extra-large) | pass | Every row, URLs included, reads in full. |
| 18 | Detail › Gallery Infos | iPad | landscape | AX3 (accessibility-extra-large) | pass | The wider line lets the URLs finish; nothing clipped. |
| 18 | Detail › Gallery Infos | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Token, title and every counter read in full; the sheet scrolls to its end. |
| 19 | Detail › Archives sheet | iPad | portrait | XXL (extra-extra-extra-large) | pass | `pinnedColumn`: heading, both cards (Original / 1280x, size, Free) complete, funds + Download button all visible, no scroll needed. |
| 19 | Detail › Archives sheet | iPad | portrait | AX3 (accessibility-extra-large) | pass | Cards stack one column, both complete; funds visible; Download button just below the fold. Scrolling to the button pushes the large title fully off the top — cards, funds and button all read with no overlap. |
| 19 | Detail › Archives sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#36 | `scrollingColumn` at accessibility sizes: cards stack one column, Original/1280x with size+Free complete at top, funds below the fold. Scrolling to reach funds+Download button, the large 'Archives' navigation title stays and overlaps the '1280x' card — the short form-sheet has too little scroll travel to clear the large title. **NEW iPad-only finding #36.** |
| 19 | Detail › Archives sheet | iPad | landscape | XXL (extra-extra-extra-large) | pass | `pinnedColumn`: heading, 2 cards, funds, Download button all fit, no overlap. |
| 19 | Detail › Archives sheet | iPad | landscape | AX3 (accessibility-extra-large) | finding:#36 | Heading + both cards + funds fit; button just below the fold. Scrolling to the button, the 'Archives' title overlaps the '1280x' card (short landscape form-sheet). **NEW iPad-only finding #36.** |
| 19 | Detail › Archives sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#36 | Both cards complete, funds below the fold. Scrolling to funds/button, the 'Archives' title overlaps the '1280x' card. **NEW iPad-only finding #36.** |
| 20 | Detail › Torrents sheet | iPad | portrait | XXL (extra-extra-extra-large) | pass | Single-torrent card: counter row (↑8 ↓0 ★1,124 / 256.8 MiB — the finding-#21 flow, all four values), filename complete, uploader + timestamp all read; no title overlap (content short). |
| 20 | Detail › Torrents sheet | iPad | portrait | AX3 (accessibility-extra-large) | pass | Counter row wraps, filename complete, uploader + timestamp read; 'Torrents' title clear above the card. |
| 20 | Detail › Torrents sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Counters (↑8 ↓0 ★1,124 / 256.8 MiB, finding-#21 flow), filename (4 lines) complete, uploader + timestamp read; single-torrent content short so no title overlap. |
| 20 | Detail › Torrents sheet | iPad | landscape | XXL (extra-extra-extra-large) | pass | Counter row single line, filename 2 lines, uploader+timestamp one line, all complete. |
| 20 | Detail › Torrents sheet | iPad | landscape | AX3 (accessibility-extra-large) | pass | Counters wrap to two lines, filename 3 lines, uploader + timestamp complete inside the card; title clear above. |
| 20 | Detail › Torrents sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Counters + filename + uploader in card; timestamp at the card-bottom fold, revealed in full by scroll (2025/10/17, 21:30); 'Torrents' title scrolls off cleanly with a gap above the card — no overlap (unlike Archives #36, the single-torrent content is short and the title collapses away). |
| 21 | Detail › Tag Detail sheet | iPad | portrait | XXL (extra-extra-extra-large) | pass | Unblocked the same way as the iPhone column (session language 简体中文, Tags Extension and Translate Tags on) and with the owner-created iPad session in place. The sheet is a regular-width form sheet; walked on a female-namespace tag with a long description, three images and an empty links list. Title, the complete description, all three images and the Links heading fit the card without scrolling. |
| 21 | Detail › Tag Detail sheet | iPad | portrait | AX3 (accessibility-extra-large) | pass | Description wraps to five lines inside the card and reads in full; the card scrolls to the images row and the Links heading with nothing clipped. |
| 21 | Detail › Tag Detail sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Description complete at accessibility size; scrolling reaches the images row and the Links heading. No value is lost and no text is drawn outside the card. |
| 21 | Detail › Tag Detail sheet | iPad | landscape | XXL (extra-extra-extra-large) | pass | The whole card is visible without scrolling — title, description, three images and the Links heading. |
| 21 | Detail › Tag Detail sheet | iPad | landscape | AX3 (accessibility-extra-large) | pass | Description complete over four lines; one scroll brings the images row and the Links heading fully into view. |
| 21 | Detail › Tag Detail sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Description complete over six lines; scrolling reaches the images row and the Links heading, each drawn inside the card. |
| 22 | Detail › NewDawn sheet | iPad | portrait | XXL (extra-extra-extra-large) | pass | Walked in batch 9 against a greeting surfaced by a temporary, never-committed presentation injection (the owner authorised mocking, since only the layout is under test); `NewDawnView` itself was unmodified and the build was reverted and reinstalled clean afterwards. The whole greeting fits inside the form-sheet. |
| 22 | Detail › NewDawn sheet | iPad | portrait | AX3 (accessibility-extra-large) | pass | Walked in batch 9 against a greeting surfaced by a temporary, never-committed presentation injection (the owner authorised mocking, since only the layout is under test); `NewDawnView` itself was unmodified and the build was reverted and reinstalled clean afterwards. Still fits: the last line `Hath!` sits well above the sheet's bottom edge. |
| 22 | Detail › NewDawn sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#38 | Walked in batch 9 against a greeting surfaced by a temporary, never-committed presentation injection (the owner authorised mocking, since only the layout is under test); `NewDawnView` itself was unmodified and the build was reverted and reinstalled clean afterwards. The greeting outgrows the form-sheet and, because nothing scrolls, is cut at **both** ends: the first line `It is the dawn of a` is sliced horizontally by the sheet's top edge and the closing `Hath!` by its bottom edge. Both read in full at `.large`. |
| 22 | Detail › NewDawn sheet | iPad | landscape | XXL (extra-extra-extra-large) | pass | Walked in batch 9 against a greeting surfaced by a temporary, never-committed presentation injection (the owner authorised mocking, since only the layout is under test); `NewDawnView` itself was unmodified and the build was reverted and reinstalled clean afterwards. The whole greeting fits inside the form-sheet. |
| 22 | Detail › NewDawn sheet | iPad | landscape | AX3 (accessibility-extra-large) | pass | Walked in batch 9 against a greeting surfaced by a temporary, never-committed presentation injection (the owner authorised mocking, since only the layout is under test); `NewDawnView` itself was unmodified and the build was reverted and reinstalled clean afterwards. Still fits, with margin at both ends. |
| 22 | Detail › NewDawn sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#38 | Walked in batch 9 against a greeting surfaced by a temporary, never-committed presentation injection (the owner authorised mocking, since only the layout is under test); `NewDawnView` itself was unmodified and the build was reverted and reinstalled clean afterwards. Same as portrait AX5 and slightly worse for the shorter sheet: the opening line and the closing `Hath!` are both cut in half by the sheet's edges, with no way to scroll to them. |
| 23 | Detail › download confirmation dialogs | iPad | portrait | XXL (extra-extra-extra-large) | pass | Raised from the Detail header's trash control on the gallery this phase downloaded. Title, the full explanatory sentence and both Cancel and Delete read inside the alert's own card. Cancelled; nothing was deleted. |
| 23 | Detail › download confirmation dialogs | iPad | portrait | AX3 (accessibility-extra-large) | finding:#37 | The alert's card stops mid-button: the Cancel and Delete capsules are drawn but their lower halves fall outside the card's rounded bottom edge, with the labels sitting on the clip line and no bottom padding at all. Title and sentence read. Cancelled. |
| 23 | Detail › download confirmation dialogs | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | The button row breaks to a vertical stack and the whole alert — two-line title, four-line sentence, Delete then Cancel — reads inside its card. Cancelled. |
| 23 | Detail › download confirmation dialogs | iPad | landscape | XXL (extra-extra-extra-large) | pass | Title, sentence and both buttons read in full. Cancelled. iPhone finding #23 does not reproduce. |
| 23 | Detail › download confirmation dialogs | iPad | landscape | AX3 (accessibility-extra-large) | finding:#37 | Same clipped button row as portrait AX3 — both capsules cut by the alert's bottom edge. Title and sentence read. Cancelled. |
| 23 | Detail › download confirmation dialogs | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Stacked buttons; title, sentence, Delete and Cancel all read inside the card, so the iPhone landscape loss recorded as finding #23 does not reproduce on iPad. Cancelled. |
| 24 | Reading | iPad | portrait | XXL (extra-extra-extra-large) | pass | The reading surface draws no app-owned text — page images only — and the centre tap zone still summons the control panel. The page context menu shows all five actions with their glyphs. |
| 24 | Reading | iPad | portrait | AX3 (accessibility-extra-large) | pass | Page images unchanged; the context menu drops its glyphs (decoration) and shows all five items in full. |
| 24 | Reading | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Page images unchanged and scrollable to the last page. The context menu shows four of its five items at once and scrolls to reach Share — nothing unreachable. |
| 24 | Reading | iPad | landscape | XXL (extra-extra-extra-large) | pass | Page images only; tap zones and the five-item context menu intact. |
| 24 | Reading | iPad | landscape | AX3 (accessibility-extra-large) | pass | Context menu items read in full. |
| 24 | Reading | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | The context menu scrolls to reach its fifth item; every item reads. |
| 25 | Reading › Control panel | iPad | portrait | XXL (extra-extra-extra-large) | pass | The upper bar is capped at `.large` by the owner-authorised lint exception, so close button, page indicator and the three glyph actions keep one line at every size; the lower bar's end labels grow with the type and the slider is intact. The More menu's three items read in full and the Auto-Play menu marks the selected interval with a leading checkmark. |
| 25 | Reading › Control panel | iPad | portrait | AX3 (accessibility-extra-large) | finding:#26 | The upper bar is capped at `.large` by the owner-authorised lint exception, so close button, page indicator and the three glyph actions keep one line at every size; the lower bar's end labels grow with the type and the slider is intact. The More menu reads in full, but the Auto-Play menu stops drawing the checkmark beside the selected interval, so the menu no longer says which interval is active — the same failure #26 records for the activity-log Runs menu. |
| 25 | Reading › Control panel | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#26 | The upper bar is capped at `.large` by the owner-authorised lint exception, so close button, page indicator and the three glyph actions keep one line at every size; the lower bar's end labels grow with the type and the slider is intact. A three-digit counter (`132 / 254`) still reads in full on the iPad's wider bar, and the More menu wraps its items without loss; but the Auto-Play menu again draws no checkmark beside the selected interval (finding #26). The menu scrolls to reach its last option. |
| 25 | Reading › Control panel | iPad | landscape | XXL (extra-extra-extra-large) | pass | The upper bar is capped at `.large` by the owner-authorised lint exception, so close button, page indicator and the three glyph actions keep one line at every size; the lower bar's end labels grow with the type and the slider is intact. Auto-Play checkmark present; both menus read in full. |
| 25 | Reading › Control panel | iPad | landscape | AX3 (accessibility-extra-large) | finding:#26 | The upper bar is capped at `.large` by the owner-authorised lint exception, so close button, page indicator and the three glyph actions keep one line at every size; the lower bar's end labels grow with the type and the slider is intact. Auto-Play checkmark not drawn (finding #26); bars and More menu complete. |
| 25 | Reading › Control panel | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#26 | The upper bar is capped at `.large` by the owner-authorised lint exception, so close button, page indicator and the three glyph actions keep one line at every size; the lower bar's end labels grow with the type and the slider is intact. Auto-Play checkmark not drawn (finding #26); bars and the More menu's three wrapped items all read. |
| 26 | Reading › Reading Setting sheet | iPad | portrait | XXL (extra-extra-extra-large) | pass | The sheet is a measured 580x640 pt card. At XXL every row and both sliders' end labels fit inside it without scrolling; nothing is clipped. |
| 26 | Reading › Reading Setting sheet | iPad | portrait | AX3 (accessibility-extra-large) | pass | The card keeps its measured height and scrolls (P-11): the two scale-factor rows sit below the fold at rest and every label, value and slider end label reads once scrolled. The navigation title collapses to an inline `Reading`. |
| 26 | Reading › Reading Setting sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Labels wrap to two lines and the card scrolls to its end; every label, value and slider end label (`1.5x`, `10.0x`, `5.0x`) reads. Reading Direction was read, never changed. |
| 26 | Reading › Reading Setting sheet | iPad | landscape | XXL (extra-extra-extra-large) | pass | Every row fits inside the card; both sliders keep their end labels. |
| 26 | Reading › Reading Setting sheet | iPad | landscape | AX3 (accessibility-extra-large) | pass | The card scrolls to its end; nothing lost. |
| 26 | Reading › Reading Setting sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | The card scrolls to its end; every label, value and slider end label reads. |
| 27 | Reading › Live Text overlay | iPad | portrait | XXL (extra-extra-extra-large) | n/a: no app-drawn text (system overlay) | The overlay was enabled from the control panel and inspected on a page whose art carries recognised text. Everything it draws is a transparent hit-target text view (clear text colour, zero-point font) plus highlight paths derived from the image, so there is no app-drawn string for Dynamic Type to reach and the highlight geometry is identical at every size — the landscape AX3 and AX5 frames are pixel-identical to the XXL frame above the control bar. The overlay was switched back off afterwards. |
| 27 | Reading › Live Text overlay | iPad | portrait | AX3 (accessibility-extra-large) | n/a: no app-drawn text (system overlay) | The overlay was enabled from the control panel and inspected on a page whose art carries recognised text. Everything it draws is a transparent hit-target text view (clear text colour, zero-point font) plus highlight paths derived from the image, so there is no app-drawn string for Dynamic Type to reach and the highlight geometry is identical at every size — the landscape AX3 and AX5 frames are pixel-identical to the XXL frame above the control bar. The overlay was switched back off afterwards. |
| 27 | Reading › Live Text overlay | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | n/a: no app-drawn text (system overlay) | The overlay was enabled from the control panel and inspected on a page whose art carries recognised text. Everything it draws is a transparent hit-target text view (clear text colour, zero-point font) plus highlight paths derived from the image, so there is no app-drawn string for Dynamic Type to reach and the highlight geometry is identical at every size — the landscape AX3 and AX5 frames are pixel-identical to the XXL frame above the control bar. The overlay was switched back off afterwards. |
| 27 | Reading › Live Text overlay | iPad | landscape | XXL (extra-extra-extra-large) | n/a: no app-drawn text (system overlay) | The overlay was enabled from the control panel and inspected on a page whose art carries recognised text. Everything it draws is a transparent hit-target text view (clear text colour, zero-point font) plus highlight paths derived from the image, so there is no app-drawn string for Dynamic Type to reach and the highlight geometry is identical at every size — the landscape AX3 and AX5 frames are pixel-identical to the XXL frame above the control bar. The overlay was switched back off afterwards. |
| 27 | Reading › Live Text overlay | iPad | landscape | AX3 (accessibility-extra-large) | n/a: no app-drawn text (system overlay) | The overlay was enabled from the control panel and inspected on a page whose art carries recognised text. Everything it draws is a transparent hit-target text view (clear text colour, zero-point font) plus highlight paths derived from the image, so there is no app-drawn string for Dynamic Type to reach and the highlight geometry is identical at every size — the landscape AX3 and AX5 frames are pixel-identical to the XXL frame above the control bar. The overlay was switched back off afterwards. |
| 27 | Reading › Live Text overlay | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | n/a: no app-drawn text (system overlay) | The overlay was enabled from the control panel and inspected on a page whose art carries recognised text. Everything it draws is a transparent hit-target text view (clear text colour, zero-point font) plus highlight paths derived from the image, so there is no app-drawn string for Dynamic Type to reach and the highlight geometry is identical at every size — the landscape AX3 and AX5 frames are pixel-identical to the XXL frame above the control bar. The overlay was switched back off afterwards. |

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
| 30 | Setting › Login | iPad | portrait | AX3 (accessibility-extra-large) | pass | Both field labels, placeholders and the disabled submit control read cleanly in the modal. Re-verify (batch 3, `0a965af3`): above the default size the screen stops ignoring the safe area, so the navigation bar's inset pushes the form clear of the heading, and the column scrolls if it outgrows the height. Heading clear of the Username label; both fields and the Login button on screen. |
| 30 | Setting › Login | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#33 | The enlarged Login heading is painted through the Username label; the native fields remain reachable but the heading and first label cannot be read independently. Re-verify (batch 3, `0a965af3`): above the default size the screen stops ignoring the safe area, so the navigation bar's inset pushes the form clear of the heading, and the column scrolls if it outgrows the height. The bottom of `Login` no longer paints through the `Username` label; heading at 147,339 171x72 pt, the first label at 243,450, and the whole form including the button is drawn. |
| 30 | Setting › Login | iPad | landscape | XXL (extra-extra-extra-large) | pass | The native form has ample width and every label, field and toolbar glyph is complete. |
| 30 | Setting › Login | iPad | landscape | AX3 (accessibility-extra-large) | pass | Username and Password remain separate from the title and the disabled submit control stays visible. Re-verify (batch 3, `0a965af3`): above the default size the screen stops ignoring the safe area, so the navigation bar's inset pushes the form clear of the heading, and the column scrolls if it outgrows the height. Heading clear of the field in the compact-height modal; whole form on screen. |
| 30 | Setting › Login | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#33 | The Login heading overlaps the Username label in the compact-height modal just as it does in portrait. Re-verify (batch 3, `0a965af3`): above the default size the screen stops ignoring the safe area, so the navigation bar's inset pushes the form clear of the heading, and the column scrolls if it outgrows the height. Heading clear of the Username label; both fields and the Login button drawn. |
| 31 | Setting › General | iPad | portrait | XXL (extra-extra-extra-large) | pass | Language, translation, cache and analytics rows read in full; the footer reaches its last word. |
| 31 | Setting › General | iPad | portrait | AX3 (accessibility-extra-large) | pass | Labels and values wrap without loss and all controls remain reachable. |
| 31 | Setting › General | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Every row and the full analytics footer are reachable; the clear-cache confirmation text and action are complete and the popover was cancelled outside. |
| 31 | Setting › General | iPad | landscape | XXL (extra-extra-extra-large) | pass | Rows, values and footer remain complete inside the centered modal. |
| 31 | Setting › General | iPad | landscape | AX3 (accessibility-extra-large) | pass | Labels wrap cleanly and the bottom of the footer remains reachable. |
| 31 | Setting › General | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | The modal scrolls through every enlarged row and the footer without clipping; no setting or cache state was changed. |
| 32 | Setting › General › Activity Logs | iPad | portrait | XXL (extra-extra-extra-large) | pass | Title, search field, timestamps, category chips and log messages render completely. |
| 32 | Setting › General › Activity Logs | iPad | portrait | AX3 (accessibility-extra-large) | finding:#25 | The category chip is ellipsised while the search field, title, timestamp and wrapped log message remain complete. **Re-verify (batch 4, `27a360b1`+`4fbd0ae9`, completing the batch-3 iPad walk):** the pull-to-reveal search field draws its magnifier and "Search" placeholder text (was empty). The category-chip and Runs-menu-tick aspects of this row's other findings were not re-walked here. |
| 32 | Setting › General › Activity Logs | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#4, #25, #26 | The search control is an empty capsule, category chips are ellipsised and the Runs menu omits its visible selection tick. The More Logs picker still shows its tick and complete labels. **Re-verify (batch 4, `27a360b1`+`4fbd0ae9`, completing the batch-3 iPad walk):** the pull-to-reveal search field draws its magnifier and "Search" placeholder text (was empty). The category-chip and Runs-menu-tick aspects of this row's other findings were not re-walked here. |
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
| 38 | Setting › EhSetting | iPad | portrait | XXL (extra-extra-extra-large) | pass | Form-sheet modal, inline centered title. Profile picker expands inline (all profiles + checkmark), Image Load section readable, no title overlap. **Excluded Languages (#27)** reflows: each language a bold header + Original/Translated/Rewrite labeled toggle rows (leading-aligned, toggles right). **Multi-Page Viewer (#28)** Display Style = label + inline-expanded options with checkmark. All complete, no truncation — the wider iPad modal absorbs the iPhone-cramped matrices. |
| 38 | Setting › EhSetting | iPad | portrait | AX3 (accessibility-extra-large) | pass | Inline title, profile picker expanded inline; #27/#28 render via the same header+toggle-row and inline-expanded-picker reflow verified at the bracketing XXL and AX5, no new failure mode. |
| 38 | Setting › EhSetting | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | pass | Stable state: inline centered title (the large title collapses cleanly, no #36-style overlap once settled), profile picker expanded. **Excluded Languages (#27)** language header + Original/Translated/Rewrite toggle rows all readable; **Multi-Page Viewer (#28)** Display Style options wrap to multiple lines, fully readable, checkmark on selected. No truncation. (Delete-Profile destructive dialog not opened, D-09.) |
| 38 | Setting › EhSetting | iPad | landscape | XXL (extra-extra-extra-large) | pass | Wider form-sheet, inline title, full profile picker + second card; no overlap. Content (incl. #27/#28) reachable by scrolling; renders identically to portrait (orientation-invariant sheet width). |
| 38 | Setting › EhSetting | iPad | landscape | AX3 (accessibility-extra-large) | pass | Profile picker expanded through Delete Profile; no overlap; #27/#28 render via the same reflow. |
| 38 | Setting › EhSetting | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | pass | Inline title, profile picker expanded, no overlap in the shorter landscape sheet. **Excluded Languages (#27)** Korean/Polish headers + Original/Translated/Rewrite toggle rows readable, no truncation; #28 renders identically to portrait. |
| 39 | Filters sheet | iPad | portrait | XXL (extra-extra-extra-large) | finding:#29 | The 100-point adaptive category cells already ellipsise names; host, reset and advanced rows remain complete. Re-verify (batch 3, `7645e10c`): the adaptive column bounds scale with the text and a name that still does not fit wraps instead of losing its tail. Four columns; Asian Porn wraps to two lines and all ten names read in full. **Re-verify (batch 4, `db5afd4e`):** the category cell's corner radius now scales with its text (`@ScaledMetric(relativeTo: .body)`), so every chip reads rounded, not square, at this size. Walked the whole sheet top to bottom: 4 columns, all ten names complete, and every control below the grid (Reset Filters, Advanced Settings, the search-scope toggles, the minimum-rating stepper, the pages-range fields, the custom-filter toggles) renders correctly with nothing clipped or overlapping. |
| 39 | Filters sheet | iPad | portrait | AX3 (accessibility-extra-large) | finding:#29 | Category names lose more characters inside the unchanged 100-point columns; every other row wraps and remains reachable. Re-verify (batch 3, `7645e10c`): the adaptive column bounds scale with the text and a name that still does not fit wraps instead of losing its tail. Two columns, all ten names complete. No round-1 capture of this cell shows the grid, so the after-image is supplementary rather than a pair. **Re-verify (batch 4, `db5afd4e`):** the category cell's corner radius now scales with its text (`@ScaledMetric(relativeTo: .body)`), so every chip reads rounded, not square, at this size. Walked the whole sheet top to bottom: 2 columns, all ten names complete, and every control below the grid (Reset Filters, Advanced Settings, the search-scope toggles, the minimum-rating stepper, the pages-range fields, the custom-filter toggles) renders correctly with nothing clipped or overlapping. |
| 39 | Filters sheet | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | finding:#29 | Category names collapse to short ellipsised fragments; advanced rows grow and scroll without losing text. Re-verify (batch 3, `7645e10c`): the adaptive column bounds scale with the text and a name that still does not fit wraps instead of losing its tail. Two columns; Game CG and Image Set wrap to two lines, and all ten names read in full where round 1 showed `N…`, `Im…`, `C…`, `A…`, `Mi…`. **Re-verify (batch 4, `db5afd4e`):** the category cell's corner radius now scales with its text (`@ScaledMetric(relativeTo: .body)`), so every chip reads rounded, not square, at this size. Walked the whole sheet top to bottom: 2 columns, all ten names complete, and every control below the grid (Reset Filters, Advanced Settings, the search-scope toggles, the minimum-rating stepper, the pages-range fields, the custom-filter toggles) renders correctly with nothing clipped or overlapping. |
| 39 | Filters sheet | iPad | landscape | XXL (extra-extra-extra-large) | finding:#29 | More 100-point columns fit per row, but the same category names are ellipsised inside each fixed-width cell. Re-verify (batch 3, `7645e10c`): the adaptive column bounds scale with the text and a name that still does not fit wraps instead of losing its tail. Four columns, all ten names complete. **Re-verify (batch 4, `db5afd4e`):** the category cell's corner radius now scales with its text (`@ScaledMetric(relativeTo: .body)`), so every chip reads rounded, not square, at this size. Walked the whole sheet top to bottom: 4 columns, all ten names complete, and every control below the grid (Reset Filters, Advanced Settings, the search-scope toggles, the minimum-rating stepper, the pages-range fields, the custom-filter toggles) renders correctly with nothing clipped or overlapping. |
| 39 | Filters sheet | iPad | landscape | AX3 (accessibility-extra-large) | finding:#29 | Category names remain cut while the rest of the sheet stays complete. Re-verify (batch 3, `7645e10c`): the adaptive column bounds scale with the text and a name that still does not fit wraps instead of losing its tail. Two columns, all ten names complete on one line each. **Re-verify (batch 4, `db5afd4e`):** the category cell's corner radius now scales with its text (`@ScaledMetric(relativeTo: .body)`), so every chip reads rounded, not square, at this size. Walked the whole sheet top to bottom: 2 columns, all ten names complete, and every control below the grid (Reset Filters, Advanced Settings, the search-scope toggles, the minimum-rating stepper, the pages-range fields, the custom-filter toggles) renders correctly with nothing clipped or overlapping. |
| 39 | Filters sheet | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | finding:#29 | The compact-height sheet scrolls through complete advanced rows, but the category cells retain only ellipsised name fragments. Re-verify (batch 3, `7645e10c`): the adaptive column bounds scale with the text and a name that still does not fit wraps instead of losing its tail. Two columns, all ten names complete. **Re-verify (batch 4, `db5afd4e`):** the category cell's corner radius now scales with its text (`@ScaledMetric(relativeTo: .body)`), so every chip reads rounded, not square, at this size. Walked the whole sheet top to bottom: 2 columns, all ten names complete, and every control below the grid (Reset Filters, Advanced Settings, the search-scope toggles, the minimum-rating stepper, the pages-range fields, the custom-filter toggles) renders correctly with nothing clipped or overlapping. |
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
| 42 | Error surface | iPad | portrait | AX3 (accessibility-extra-large) | accepted | The toast title survives but its one-line subtitle ellipsises; the detail sheet remains complete. |
| 42 | Error surface | iPad | portrait | AX5 (accessibility-extra-extra-extra-large) | accepted | The toast subtitle is reduced to an early ellipsised fragment; Description, Suggested Solution, Context and Environment remain reachable in the sheet. |
| 42 | Error surface | iPad | landscape | XXL (extra-extra-extra-large) | pass | Toast title and subtitle fit in full, and the sheet scrolls through every complete field. |
| 42 | Error surface | iPad | landscape | AX3 (accessibility-extra-large) | pass | The full unsupported-link subtitle remains visible and the detail sheet stays complete. |
| 42 | Error surface | iPad | landscape | AX5 (accessibility-extra-extra-extra-large) | accepted | The one-line subtitle ellipsises near its end; the detail sheet still exposes every complete section. |

## Findings

Numbered in the order they are recorded. The sweep never stops to raise one (D-02): the finding is
written here, the walk continues, and plan 16-10 reports the complete list once every page has
been scanned.

Each entry carries a **written** description — what value was lost, at which size, and what it
reads as at `.large` — never a filename (D-32). Before/after images are sent to the owner in chat
(D-33) by naming the evidence-root path and describing the image.

| #N | Screen | Cells affected | Description (written, no filenames) | Status |
|---|---|---|---|---|
| 1 | #2 | iPhone portrait XXL / AX3 / AX5; iPhone landscape AX3 / AX5; iPad portrait XXL / AX3 / AX5; iPad landscape XXL / AX3 / AX5 | The hero carousel's card is a fixed-height card and its title is capped at four lines, so the title gives up characters as the type grows instead of the card growing. At the default size a long title reads to its last word across four lines. On iPhone at XXL it is down to three lines ending in an ellipsis; at AX3 it is a single ellipsised line; at AX5 only the first word survives. The information the card exists to carry — which gallery it is — is progressively removed as the size increases. iPhone landscape absorbs XXL but fails from AX3 up. The iPad's wider layout still ellipsises the same hero in all six sampled cells: portrait progressively collapses to its opening words, while even landscape XXL loses the tail and AX3/AX5 shorten further. Pre-registered as the D-13 "hero-carousel title truncation" case. **Re-verify (batch 1, `5e9f9cdb`):** the four-line cap is lifted above the default size and the card now steps its height by type, so iPhone portrait AX5, iPad portrait XXL and AX5 and all three iPad landscape cells read the title to its last word. It still ellipsises at iPhone portrait XXL and AX3, at iPad portrait AX3, and — where round 1 recorded a pass — at all three iPhone landscape cells, whose shorter card height is now the binding budget. Remains **open**. **Re-verify (batch 2, `803756c3`):** the owner's round-I direction is met on both devices. Cover and title stay side by side at every size and only the rating drops to a full-width row of its own, from `.accessibility1` up; the title truncates at its tail with an ellipsis inside the card rather than the card growing to hold it. Card height measured: iPhone portrait 243 pt at XXL and 354 pt at AX3 and AX5, the latter exactly half the 708 pt scroll container; iPhone landscape 139 / 150 / 180 pt; iPad portrait 243 / 388 / 494 pt (the cap does not bite, 41% of the screen at AX5); iPad landscape 243 pt at XXL and 364 pt at AX3 and AX5, exactly half its 728 pt container. At `.large` the card is the designed 336 x 190 pt (iPhone) and 668 x 190 pt (iPad), so D-15 parity holds. **One residue for the owner:** at iPhone portrait AX5 only, the card's rendered bounds are 381.7 pt wide inside its 336 pt layout slot — the five rating symbols need about 336 pt of content width against the 296 pt the card has — so the card overlaps each peeking neighbour by roughly 23 pt and the peek gap disappears. The symbols themselves are not clipped, and every other cell renders the card exactly at its slot width. **Re-verify (batch 2b, `eb38acc4`):** the one residue round II left for the owner is closed. Once the rating drops to its own row the five symbols take `.caption2`, so the card's rendered bounds equal its layout slot at every sampled cell — measured 42.0 to 377.7 pt (336.0 pt) in portrait at XXL, AX3 and AX5, and 145.7 to 766.3 pt (621.0 pt) in landscape at all three — against 19.3 to 400.7 pt (381.7 pt) at iPhone portrait AX5 in round II. The rating row itself measures 66.0 to 314.3 pt at portrait AX5, inside the card's 62.0 to 357.7 pt content box, where round II measured 44.7 to 400.7 pt, 23.0 pt past the card's trailing edge and 2.7 pt into the neighbouring card's slot; the designed 20 pt gap to each peeking neighbour is back on both sides. At XXL the rating is still inside the text column at body size, and at `.large` the rating row is pixel-identical to round II (x 195.7 to 301.7 pt, y 289.3 to 306.7 pt), so the step does not engage at the default size. Nothing else about the card moves. | re-verified |
| 2 | #2 | iPhone portrait AX5 | At AX5 in portrait the hero card's contents no longer fit inside the card: the neighbouring card's cover image is drawn on top of the focused card's title tail and its rating stars, and the focused card's own cover is cut off by the screen's left edge. This is overlap, not a peek — the title and the star row are partly unreadable because another card's artwork sits over them. Landscape at the same size does not overlap. **Re-verify (batch 1, `5e9f9cdb`):** at AX5 portrait the card stacks its cover above its text, so no neighbouring card is drawn over the title or rating and the focused cover is no longer cut at the leading edge. | re-verified |
| 3 | #2, #7 | iPhone portrait AX3 / AX5; iPhone landscape AX3 / AX5; iPad portrait XXL / AX3 / AX5; iPad landscape AX3 / AX5 | The Home Toplists section's ranking cell keeps a fixed row size, so as type grows both texts are cut: the gallery title ellipsises and the uploader line below it ellipsises as well. At AX5 on iPhone portrait the uploader is not visible at all. The iPad layout reproduces the title loss already at XXL portrait, worsens through AX3/AX5, and also loses title and then uploader text in landscape from AX3. Covers the D-04 site `HomeFeature/GalleryRankingCell.swift:39`. **Re-verify (batch 1, `d3aec099`):** the ranking row reflows above the default size; title and uploader read in full at every re-walked cell (iPhone #2 portrait AX3/AX5 and landscape AX3/AX5, iPad #2 portrait and landscape at all three sizes). | re-verified |
| 4 | #3, #4, #5, #6, #7, #10, #32 | iPhone portrait AX3 / AX5 (also observed at XXL on #3); on #32 also iPhone landscape AX5; iPad #3 portrait AX3 and landscape AX5; iPad #4 and #7 portrait AX3 and landscape AX3 / AX5; iPad #10 portrait AX3 / AX5 and landscape AX5; iPad #32 portrait AX5 and landscape AX5 | The pull-to-reveal filter field above the pushed lists sometimes renders as an empty rounded capsule: both the magnifying-glass glyph and the "Filter" placeholder are absent, so the control shows no indication of what it is or does. The capsule itself grows with the type size, so this is not a fixed-height clip — the content is simply not drawn. The failure is non-monotonic: on the iPad it appears at AX3 portrait but returns at AX5 portrait on #3, #4, and #7, while landscape fails at AX5 on #3 and at both AX3/AX5 on #4 and #7. Search results (#10) loses its submitted query at AX3/AX5 portrait and AX5 landscape while preserving it at landscape AX3. Activity Logs (#32) fails at AX5 in both iPad orientations while its field is intact at XXL and AX3; the iPhone occurrence follows a different non-monotonic pattern. **Re-verify (batch 3, `27a360b1`, `4fbd0ae9`):** the capsule is populated in every iPhone cell re-walked. At AX3 and AX5 portrait the magnifier and the placeholder are drawn on #3 (`Filter`), #4 (`Filter`), #5 (`Search`), #6 (`Filter`), #7 (`Filter`) and #32 (`Search`), and #10 draws the submitted query with its clear button; #3 was additionally checked at XXL portrait and is intact there too. The empty capsule did share the large-title root cause: the same commit that moves the bar to its inline title restores the field's contents. **Not re-walked in batch 3:** every iPad cell of this finding (#3, #4, #7, #10, #32) and the iPhone landscape #32 cell — the batch-3 iPad scope was #39, #30 and the Thumbnail-mode #3 cell. The finding stays `open` for those. **Re-verify (batch 4, `27a360b1`, `4fbd0ae9`, completing the batch-3 iPad walk):** every iPad portrait AX3/AX5 cell left open by batch 3 is now confirmed fixed — the capsule draws its magnifier and placeholder (or, on #10, the submitted query with its clear button) on #3, #4, #7, #10 and #32. **Not re-walked in batch 4:** every iPad landscape cell of this finding (#3 at AX5; #4 and #7 at AX3/AX5; #10 at AX5; #32 at AX5) and the iPhone landscape #32 cell. The finding stays `open` for those. **Re-verify (batch 5b):** the iPhone-landscape #32 occurrence — never re-walked before — now draws the search capsule's magnifier and `Search` placeholder at AX3 and AX5, where the round-1 sweep showed an empty capsule (the batch-3 `27a360b1`/`4fbd0ae9` inline-title fix reaches it). The finding stays `open` only for the iPad landscape occurrences of #3, #4, #7, #10 and #32, none of which are on this agent's device. | accepted (owner 2026-09-08: Apple native search rendering defect; no app fix) |
| 5 | #3, #4, #5, #6, #7, #17 (all list hosts) | iPhone portrait XXL / AX3 / AX5; iPhone landscape AX3 / AX5; iPad #3 portrait AX5 | The gallery list row's title is capped at three lines (two when a download badge is present), so a longer title surrenders characters every time the type size goes up. A title that reads to its final bracketed suffix at the default size is already missing that suffix at XXL, loses roughly a third of its text at AX3, and at AX5 in portrait runs off the right edge cut mid-glyph rather than ellipsised. The iPad's regular-width Frontpage row also loses a long title tail at AX5, while its wider landscape counterpart reads in full. Recorded once and tagged all list hosts. **Re-verify (batch 1, `b598c933`):** the row reflows above the default size — the cover keeps its intrinsic size, the title wraps to its last word and the trailing values move onto their own lines. Verified on iPhone #3–#8 and #10 portrait, iPhone #3/#5/#8 landscape and iPad #3 and #7 in both orientations. **Not re-walked in batch 1:** #17 Detail Search, which renders the same cell. **Re-verify (batch 2, `803756c3`):** re-walked on #3 and #8 at all six iPhone cells and all six iPad cells of #3. Titles read to their last word at every size. | re-verified |
| 6 | #3, #4, #5, #6, #7, #12, #17 (all list hosts) | iPhone portrait AX3 / AX5; iPad #12 portrait AX5 and landscape AX5 | From AX3 upward in iPhone portrait the list row's text column is wider than the screen, so everything on its right-hand side is cut off by the screen edge rather than reflowed: the language value loses its last one or two letters, the date loses its time and then its year, and the page-count number loses digits — at AX5 the page-count number is gone entirely and only its glyph remains. The iPad Inspector sheet reproduces the timestamp loss at AX5 in both orientations: the date remains, but the time is truncated. None of these values is reachable elsewhere in its host. All of them read in full at the default size and at XXL. Covers the D-04 sites `GalleryListComponents/Cells/GalleryDetailCell.swift:152` and `:163` together with their paired shrinks at `:155` and `:166`, which engage and still fail to keep the value on screen. **Re-verify (batch 1, `b598c933`):** the trailing metadata column stops sharing the row at accessibility sizes, so language, page count and timestamp read in full on every re-walked list host. **Not re-walked in batch 1:** #12 Downloads Inspector and #17 Detail Search. **Re-verify (batch 2, `803756c3`):** the row now keeps the `List`'s natural insets above the default size instead of bleeding outwards, so nothing is pushed past either screen edge; every value on the row's trailing side reads in full. | re-verified |
| 7 | #3, #4, #5, #6, #7, #32 | iPhone portrait AX3 / AX5 | The pushed screens' navigation large title degrades in portrait. At AX3 a long title is ellipsised. At AX5 the title is not rendered at all on any of these screens — the band where it belongs is blank, and the accessibility tree carries no heading either, so the screen loses its own name while the space it needs is still reserved. Short titles are affected exactly as long ones. Landscape keeps the inline title at every size. Screen #32 shows a milder variant of the same site: its large title is ellipsised at AX3 **and** at AX5 rather than disappearing, and it survives in landscape where the bar falls back to its inline title. **Re-verify (batch 3, `27a360b1`, `4fbd0ae9`):** `navigationTitleDisplayMode(_:)` switches the bar to its inline title at accessibility sizes, and the blank title band is gone on every one of these screens. #3 `Frontpage`, #4 `Popular`, #5 `Watched`, #6 `History`, #10 `Artbook` and #32 `App Activity Logs` all draw their name in full at AX3 and AX5 portrait — #32 in full where its large title used to be ellipsised. **#7 Toplists still loses characters:** its title is `Toplists - Yesterday`, and the inline bar cuts it to `Toplists - Yesterd…` in a 188 pt slot at both AX3 and AX5, where the same title collapses to inline at the default size complete in 157 pt. That is strictly better than round 1 (no title at all) but still a D-04 truncation, so the finding stays `open` on #7 alone. **Re-verify (batch 5b, `e8fd65c4`, `d6694e0d`):** the same inline-fallback policy was applied to the Setting root (#33), and its title is drawn at AX3/AX5 (inline, `Setting` 175,77 69x25) with a plain large title on normal entry at XXL/`.large` — the blank-band failure mode does not occur there. The four tab roots (#2, #8, #9, #11) were reverted to `.inlineLarge` and still draw a persistent large title at every size — the revert is a no-op. #7 Toplists itself is unchanged and stays `open`. **Re-verify (batch 6, `be4665cf`):** the batch-5b note that the Setting root's `.large` collapses on return from a sub-screen is resolved — the plain large title now applies only to the sheet presentation, and the iPhone tab root keeps `.inlineLarge`. #7 Toplists is untouched and stays `open`. | accepted (owner 2026-09-08: initial inline title and truncation accepted as-is) |
| 8 | #3, #4, #5, #6, #7, #17 (all list hosts) | iPhone portrait AX5 | At AX5 in portrait the row's cover thumbnail is squeezed to a narrow vertical sliver a few points wide and pushed partly past the screen's left edge, leaving an unrecognisable strip of the artwork instead of the cover. The cover is the row's only visual identifier and it is not reproduced anywhere else in the row. **Re-verify (batch 1, `b598c933`):** at AX5 portrait the cover keeps its intrinsic size above the stacked text on every re-walked list host, so the row keeps its visual identifier. **Not re-walked in batch 1:** #17 Detail Search. **Re-verify (batch 2, `803756c3`):** the cover is `@ScaledMetric(relativeTo: .headline)` and bounded to half the row. Measured on iPhone portrait #3: 109 x 159 pt at XXL and 161 x 220 pt at AX3 and AX5, against the designed 87 x 120 pt and a half-row budget of about 161 pt — larger at every accessibility size and never wider than half the row. At `.large` the frame is the designed 87 x 120 pt. | re-verified |
| 9 | #5, #6, #17 (all list hosts) | iPhone portrait XXL and above | The uploader name is ellipsised as soon as a language value shares its line: at XXL a seventeen-character uploader already reads with its last third replaced by an ellipsis, while the language value beside it is complete. At the default size both read in full on the same line. This is the D-04 site `GalleryListComponents/Cells/GalleryDetailCell.swift:107`, whose Phase-10 "fine" verdict rested on the secondary-text exemption that D-04 removes. At AX3 and above the same value is additionally cut by finding #6. **Re-verify (batch 1, `b598c933`):** the uploader no longer shares a line with the language value at accessibility sizes and reads in full from XXL up on #5 and #6. **Not re-walked in batch 1:** #17 Detail Search. **Re-verify (batch 2, `803756c3`):** uploader and language read in full side by side at XXL and on their own lines above it, on both list hosts. | re-verified |
| 10 | #9 | iPhone portrait XXL / AX3 / AX5; iPhone landscape XXL / AX3 / AX5; iPad portrait AX3 / AX5; iPad landscape AX3 / AX5 | The Search root's "Recently Seen" strip keeps a fixed cell size, so its contents are removed as the type grows rather than the cell growing with them. At XXL the iPhone cell's title is already ellipsised where it read in full at the default size. At AX3 the cell overflows its slot: the title is cut at the right edge *and* its opening words are pushed past the screen's left edge together with the cover, so neither end of the title is readable. At AX5 in iPhone portrait the cells are drawn on top of the section heading and on top of each other, and the two section headings collapse to roughly one word per line while the rest of their row stays empty; in landscape at AX5 the cells overlap their own covers. The iPad absorbs XXL, then reproduces the fixed-height loss from AX3 upward in both orientations: title tops clip first, and at AX5 the title and cover contents overflow their cells. Covers the D-04 site `SearchFeature/GalleryHistoryCell.swift:32`. **Re-verify (batch 1, `5e9f9cdb`):** the Recently Seen cell grows with the type instead of clipping or overflowing; title, uploader and rating read in full in all six iPhone cells and in all four re-walked iPad cells. **Re-verify (batch 2, `803756c3`):** the Recently Seen cells read their title, uploader and rating at every sampled size on both devices, and the section heading above them is leading-aligned with no Show All line where the section offers none. | re-verified |
| 11 | #11 | iPhone portrait AX5 | The download delete confirmation is presented as a popover of fixed width (about a quarter of the screen) rather than a full-width sheet, so at AX5 its explanatory sentence no longer fits: the message stops mid-sentence and its last word is hidden behind the confirm button, with the popover already running past the bottom of the screen and no way to scroll to the rest. The user is asked to confirm a destructive action from a sentence they cannot finish reading. At the default size and at XXL the same popover shows the sentence complete. The absence of a separate Cancel button is *not* part of this finding — the popover has no Cancel button at any size and is dismissed by tapping outside. | re-verified (owner 2026-09-09: checked and confirmed fixed; no new agent verification in this review) |
| 12 | all list hosts, thumbnail layout | iPhone portrait AX5 | With the list's Display Mode set to Thumbnail, the grid cell removes text as the type grows instead of reflowing: the category badge is abbreviated to its first word plus an ellipsis, so two different categories become indistinguishable from their badges; the cell's title is ellipsised after its bracketed prefix; the page-count line is cut; and the grid's right-hand column runs off the screen edge with its star row clipped. All of these read in full at the default size. Covers the D-04 sites `GalleryListComponents/Cells/GalleryThumbnailCell.swift:99` and `AppComponents/CategoryView.swift:31`. The sweep set Display Mode to Thumbnail for this one capture and restored it to Detail immediately afterwards. **Re-verify (batch 3, `0dde25eb`, `72234cbc`, `7645e10c`, `30e42c84`):** the masonry's minimum cell width is now `@ScaledMetric(relativeTo: .callout)` from the designed 185, and its column floor drops from two to one at accessibility sizes, so the grid re-columns instead of squeezing. Measured column counts, iPhone portrait: 2 at `.large`, 2 at XXL (182/183 pt cells, right column ending at x 400 of 420), 1 at AX3 and AX5 (380 pt); iPhone landscape AX5: 1 (744 pt, against 3 in the pre-batch build); iPad portrait: 4 at `.large`, 1 at AX5 (794 pt, against 4). The right-hand column is fully on screen at every size. The cell's title and stat-line caps are lifted above the default size and its vertical spacing doubles, so titles read to their last word, the page count and language are both drawn, and the whole five-star row is inside the screen. `CategoryLabel` keeps `lineLimit(1)` at and below `.large` and wraps above it, so the badge on the cover reads in full (round 1: `Douji…`), and the Detail header badge — which now follows the same policy instead of overriding it — renders a nine-character category complete at AX5 portrait (238x63 pt, corners still rounded). Walked on iPhone portrait XXL / AX3 / AX5 (top and mid) and landscape AX5, and on iPad portrait AX5. **Re-verify (batch 4, `cbab163b`, `e30ddba0`):** answering the owner's round-II direction ('never a single column; two columns is the floor at every size'), the masonry's column floor is now 2 at every sampled size — measured iPhone portrait 2 at XXL/AX3/AX5, iPhone landscape 2 at AX5, iPad portrait 2 at AX5 (against 1 in batch 3), iPad landscape 2 at AX5 (not walked before). In the half-width column at iPhone portrait AX3/AX5 the five-star row now falls back to a single star symbol plus its numeral rather than clipping; on the wider iPad and landscape columns the full five-symbol row still draws. No cell's background crosses into its neighbour or off-screen at any sampled cell. **Re-verify (batch 5b, `1b06875b`):** answering the owner's round-II direction, the thumbnail title is now capped at five lines at every size (superseding D-15 for this one property: the default budget moved from three lines to five). Measured on the iPhone: at `.large` titles wrap to at most five lines and read complete; at XXL/AX3/AX5 they fill five lines ending in an ellipsis (`[202…`) rather than a mid-glyph cut; the grid stays two columns; and the tallest portrait-AX5 cell frame is 731 pt against a 912 pt screen, so one cell no longer runs past a whole screen as the batch-4 uncapped title did. | re-verified |
| 13 | #14 | iPhone portrait XXL / AX3 / AX5 | The Detail header's title is capped at three lines (`DetailFeature/DetailView+HeaderSection.swift:319`, `lineLimit(showFullTitle ? nil : 3)`), so in portrait it surrenders characters as the type grows. A title that reads to its closing bracket over three lines at `.large` already ends in an ellipsis at XXL, loses its whole second half at AX3, and at AX5 keeps only its bracketed prefix. The header does carry a tap-to-expand affordance on the title itself — the same tap that opens the full text — so the value is recoverable in place; it is still recorded as a finding because the default rendering shows strictly less at each larger size (D-04). The **uploader** line directly beneath it (`:324`, single-line) has no such affordance and degrades in the same cells: full at XXL, "BaronArgyleS…" at AX3 and "BaronArg…" at AX5. Landscape is unaffected at all three sizes. **Re-verify (batch 1, `c6775b18`):** the header's three-line cap is lifted above the default size — title and uploader both read in full at portrait XXL, AX3 and AX5. The category badge was checked separately on a nine-character category at AX3 and AX5 portrait and reads in full, so the anticipated single-line clip in the shared category label did not reproduce. **Re-verify (batch 2, `803756c3`):** at the accessibility sizes the header cover stacks above the title, which then owns the row's whole width and reads to its last word. At XXL cover and title stay side by side. At `.large` the header is unchanged, including its three-line cap. **Re-verify (batch 5b, `881104c0`):** the owner withdrew round-I's uncapped-above-`.large` policy and restored the three-line fold at every size, with the title itself as the tap-to-expand affordance. Measured on the same gallery: portrait `.large` three lines; XXL/AX3/AX5 three lines with an ellipsis; the AX5 title frame is 196 pt (three lines) against the batch-4 build's 326 pt (uncapped, five lines), and tapping it expands to 326 pt showing the full text. The category badge and the three glass action buttons stay on screen beneath the title at every size; landscape AX5 keeps the full title in three lines. `.large` unchanged. **iPad walk (login-gated batch, 2026-09-04):** on the regular-width Detail modal the header title reads complete (the owner-accepted three-line cap holds) and the uploader beneath it is not clipped, at portrait and landscape XXL/AX3/AX5 — the iPad column, previously blocked for want of a session, passes. | re-verified |
| 14 | #14 | iPhone portrait XXL / AX3 / AX5; iPhone landscape AX3 / AX5 | The Detail stats strip lays its columns out at a fixed fraction of the container width (`DetailFeature/DetailView+Subviews.swift` `DescScroll`, `containerRelativeFrame(.horizontal, itemWidth)` inside a `frame(height: rowHeight)`), so the columns keep their width and height while the text inside them grows. At XXL portrait every column label is already abbreviated ("FAVORITED" → "FAVORI…", "196 RATINGS" → "196 RAT…", "PAGE COUNT" → "PAGE C…") and the five-star rating row is clipped at both ends. At AX3 the **values** go too — a four-digit favourite count reads "11…", a rating of 4.50 reads "4.…", and the unit lines read "Engl…" / "Pag…". At AX5 each column is down to two characters ("FA…", "1…", "Ti…") and the star row shows a single clipped star. Every one of these reads in full at `.large`, and none of them is reproduced anywhere else on the screen. Landscape holds the values but loses the labels from AX3 up and shows three stars for a 4.50 rating at AX5. This is the pre-registered D-13 "Detail stats-strip abbreviation" case, and it covers the D-04 sites `:99` and `:116`. **Re-verify (batch 1, `1050c21d`):** the stats strip stacks each caption above its value above the default size; every column keeps both label and value at iPhone portrait XXL/AX3/AX5 and landscape XXL/AX3/AX5. **Re-verify (batch 4, `391ce4ea`, `919b90bb`):** answering the owner's round-II direction ('keep the horizontal ScrollView; do not stack the strip; a column may grow up to 90% of the container width and wrap inside that budget'), the strip is a horizontal `ScrollView` again — scrolling it on iPhone portrait and landscape at XXL/AX3/AX5 reveals every column (Favorited, Language, Ratings, Page Count, File Size on the walked gallery) with its label and value complete and the five-star row un-clipped; no column spans the full container width. The three header glass action buttons (download/favorite/read) now scale their symbol with the circle — none overflows its background, checked at portrait and landscape AX5. **iPad walk (login-gated batch, 2026-09-04):** the pre-registered D-13 stats-strip case — whose iPad column was always blocked — now passes on the regular-width modal. The horizontal `ScrollView` reveals every column (Favorited, Language, Ratings with an un-clipped five-star row, Page Count, File Size) with its label and value complete and no column spanning the card width, at portrait XXL/AX3/AX5 and landscape XXL/AX3/AX5. | re-verified |
| 15 | #14 | iPhone portrait AX3 / AX5 | Tags in the Detail tag cloud are laid out from a fixed leading column and are not wrapped or ellipsised when they exceed the remaining width, so in portrait a long tag simply runs off the right edge of the screen and is cut mid-glyph with no ellipsis to mark it. At AX3 a sixteen-character tag loses its last six characters; at AX5 two separate tags are cut, one of them losing half its text, and the label column beside them is itself clipped. The same tags read in full at `.large` and in landscape at every size. This is the pre-registered D-13 "long-tag right-edge clip" case and covers the D-04 site `AppComponents/TagCloudView.swift:122`. **Re-verify (batch 1, `953a67b6`):** long tags now wrap inside their chips instead of running past the trailing edge; no tag is cut at portrait AX3 or AX5. **Re-verify (batch 2, `803756c3`):** a tag row's namespace chip is arranged above its children at the accessibility sizes (checked on Parody, Character, Male, Mixed and Other), and every chip is drawn inside the container — nothing runs off the trailing edge. A tag long enough to wrap inside its own chip is centre-aligned within that chip rather than leading-aligned; that is a round-I residue, not information loss. **Re-verify (batch 2b, `549c255d`):** the round-I residue is closed — a tag that wraps inside its own chip is now leading-aligned. Checked at AX3 portrait on 'needy streamer overload' and 'columbina hyposelenia', and at AX5 portrait on 'thigh high boots' and 'multimouth blowjob', each of them the same chip on the same gallery and in the same tag section that round II showed centre-aligned. Single-line chips, which is all a tag row holds at and below the default size, are unchanged, and the `.large` tag rows are identical. **iPad walk (login-gated batch, 2026-09-04):** the pre-registered D-13 long-tag case — iPad column previously blocked — passes on the regular-width modal. Every chip wraps inside the card, the namespace chips stack above their children, and no tag runs off the trailing edge, at portrait XXL/AX3/AX5 and landscape XXL/AX3/AX5. | re-verified |
| 16 | #14 | iPhone portrait XXL / AX3 / AX5; iPhone landscape XXL / AX3 / AX5 | The Detail comment cell's author line and timestamp are single-line and sit in a card of fixed 300-point width (`DetailFeature/DetailView+CommentCells.swift:37, :43, :51`), so both are ellipsised as the type grows — and the 0.75 `minimumScaleFactor` at `:42` visibly engages first and still fails to keep the name. A fifteen-character author reads in full at `.large`, is "BaronArgyle…" at XXL, "BaronA…" at AX3 and "Baro…" at AX5; the timestamp degrades in step, from the full "YYYY/MM/DD, HH:MM" to a bare "2026…" at AX5 that no longer carries even the month. **This is the only Group-B row that fails in landscape at XXL**, because the card width is fixed rather than derived from the screen. **Re-verify (batch 1, `37b56570`):** the comment card's author, vote score and timestamp all read in full at every sampled size in both orientations. The same change altered the card's default-size rendering — recorded separately as finding #35. | re-verified |
| 17 | #14 | iPhone portrait AX3 / AX5; iPhone landscape AX5 | The same comment card's body text loses lines to the card's fixed frame (`:51`, width 300 with a `@ScaledMetric` height): the body is already ellipsised at `.large`, and each larger size shows strictly fewer characters of it — roughly a sixth fewer at AX3 and a third fewer at AX5 in portrait. In landscape at AX5 a short comment that read complete at every smaller size ("… seems to have been deleted") loses its final word. Because the height scales but the width does not, the card cannot trade one for the other. **Re-verify (batch 1, `37b56570`):** the card now shows at least as many body characters as it does at `.large` at portrait AX3/AX5 and landscape AX5, so on D-04's `.large` basis it is no longer degraded. | re-verified |
| 18 | #16 | iPhone portrait XXL / AX3 / AX5; iPhone landscape AX5 | The Comments view's header row keeps author, vote score and timestamp on one line at every size (`DetailFeature/Comments/CommentsView.swift:165, :166`), so the row's three values compete for a width that never grows. The timestamp goes first: at XXL portrait a scored row already reads "2025/03/23, 19…" where `.large` shows "2025/03/23, 19:02", and the same loss reappears in landscape at AX5. From AX3 up in portrait the author goes too — "Pecan Crisp" becomes "Pecan…" and then "Pec…" at AX5, with the timestamp reduced to "20…", which no longer identifies the comment's date at all. The 0.75 `minimumScaleFactor` at `:165` engages before the ellipsis and does not prevent it. The comment **bodies** are exemplary by contrast: they wrap freely and never lose a character at any size in either orientation, which is what makes the header row's behaviour a layout choice rather than a space limit. The post-comment sheet was opened at AX5 portrait, judged (title, close and confirm controls and the empty editor all read in full) and cancelled without posting. **Re-verify (batch 1, `7839db1f`):** the header stacks score and timestamp onto their own line above the default size, so author, score and the complete `YYYY/MM/DD, HH:MM` timestamp all read at portrait XXL/AX3/AX5 and landscape AX5. | re-verified |
| 19 | #18 | iPhone portrait AX3 / AX5 | Gallery Infos caps every value at three lines (`DetailFeature/GalleryInfos/GalleryInfosView.swift:110`, `.lineLimit(3)`), and in portrait three lines stop being enough from AX3 up. The Archive URL and the Torrent URL both end in an ellipsis at AX3 exactly where their token begins, and at AX5 the Gallery URL, the Parent URL and the gallery title go the same way. This screen exists to show the raw identifiers, its values are copy-on-tap, and the truncated tail is not shown anywhere else in the app — so the loss is total, not cosmetic. Everything reads in full at `.large` and at XXL, and in landscape at all three sizes, which is what makes this a line-count cap rather than a width limit. The site is **not** in the § D-04 checklist: the checklist enumerates `lineLimit(1)` and this is a `lineLimit(3)`, so it was found by the walk rather than inherited. **Re-verify (batch 1, `0a9f7dad`):** the three-line value cap is lifted above the default size; title, all five URLs, uploader and every count read in full at portrait AX3 and AX5. | re-verified |
| 20 | #19 | iPhone portrait AX3 / AX5; iPhone landscape AX3 / AX5 | The Archives sheet loses exactly the two values a user needs in order to choose an archive: its **size** and its **price**. The archive card is a fixed-size grid item whose three stacked lines (resolution name, file size, price) do not fit once the type grows, and the funds row below it is single-line. In portrait the name ellipsises first — at AX5 "Original" and "1280x" both read as three characters plus an ellipsis, so two different resolutions become indistinguishable — the size loses its unit ("182.0…"), and the name and price lines are drawn *outside* the card's own border. In landscape the failure is worse and starts at AX3: both cards drop their size and price lines completely, leaving only the resolution name, and at AX5 the cards are clipped to a sliver of that name with the funds row drawn on top of them. The account's GP and Credits balances degrade in step, from the full "500,062,096" at XXL to "50…" at AX5 portrait. Covers the D-04 sites `DetailFeature/Archives/ArchivesView.swift:143` (funds line) and `:202` (archive price). Everything reads in full at `.large` and at XXL in both orientations. **Nothing was purchased and no download was started** — the sheet was opened, judged and dismissed. **Re-verify (batch 1, `1c14a1cf`):** fixed in portrait — the grid collapses to one card per row and name, size and price all read inside the card at AX3 and AX5. **Landscape is not fixed and is worse than round 1:** at AX3 the card grid is clipped to a sliver with the funds row drawn over it and the second card absent, and at AX5 no card is rendered at all. Remains **open**. **Re-verify (batch 2, `803756c3`):** at the accessibility sizes the sheet is one scrolling column, so the grid is no longer crowded out by a pinned footer: both archive cards read with their size and their price at the top of the sheet, and scrolling reaches the funds row and the download button. Verified at AX3 and AX5 in both orientations. At XXL the pinned layout is kept and is unchanged from batch 1, and `.large` parity holds (cards 148 x 175 pt at x 57 and x 215 in both builds). One cosmetic residue: at AX5 portrait the nine-digit GP value wraps mid-number onto a second line — a wrap, so not degradation under D-03. **iPad walk (login-gated batch, 2026-09-04):** the card-content loss does not reproduce on iPad — the archive cards render Original / 1280x with size, price and Free all complete at every sampled size in both orientations. But the short iPad form-sheet introduces a **new iPad-only defect (finding #36):** at the accessibility sizes the large 'Archives' navigation title overlaps the scrolled card. So the iPad #19 cells pass at XXL and portrait AX3, and are recorded as finding #36 at portrait AX5 and landscape AX3/AX5. | re-verified |
| 21 | #20 | iPhone portrait AX3 / AX5 | Each torrent card's meta row puts four glyph-plus-value pairs (seeders, leechers, downloads, file size) on one line inside fixed 44-point slots, and in portrait the values are destroyed as the type grows while the glyphs stay untouched. At AX3 the leechers value is drawn as a half glyph (a "0" reads as a "C"), the download count keeps a fragment of its second digit, and "168.5 MiB" is reduced to the single character "1". At AX5 **none of the four values is rendered at all** — four glyphs sit alone with no numbers beside them, so the screen no longer says how healthy the torrent is or how large it is, even though the accessibility tree still reports every value. The uploader and the posted timestamp degrade alongside: full at XXL, "2026/01…" at AX3, "Disko…" and "2026…" at AX5. Covers the D-04 sites `DetailFeature/Torrents/TorrentsView.swift:110` and `:124`, whose Phase-10 verdict was "shrink-absorbed" — there is no shrink absorbing it now. Landscape passes at all three sizes, and portrait XXL reads in full. **No torrent download was started.** **Re-verify (batch 1, `9b1419a4`):** fixed only at AX5 portrait, where the meta reflows to two pairs per line and all four values read in full. At AX3 portrait the compact one-line row is still chosen, so all four values are still cut mid-glyph; and at XXL portrait — a round-1 `pass` — the file-size value is now ellipsised. Remains **open**, with a regression at XXL. **Re-verify (batch 2, `803756c3`): REGRESSED — this is worse than round I.** The `ViewThatFits` chain was replaced by a `FlowLayout` of the four `Label` pairs above `.large`, and in that layout every pair is sized at its icon alone: at AX5 portrait the four pair frames measure 44 x 44 pt at x 68, 151, 233 and then 68 on a second line. The consequence on screen is that **none of the four values renders at all** — seeders, leechers, downloads and file size are all absent and only the four glyphs are drawn, cascading diagonally. Round I still drew every value, with only the file size ellipsised. Confirmed at XXL, AX3 and AX5 in both orientations. The values are still present in the accessibility tree, which is why the outline reads correctly while the screen does not. At `.large` the compact row is untouched and renders all four values, so D-15 parity holds and the defect is confined to the flow branch. **Re-verify (batch 2b, `a731d905`): FIXED — the round-II regression is gone and the round-I truncation with it.** The flowed pairs are plain `HStack`s of a glyph and a `Text` instead of `Label`s, so each pair owns and reports its whole size rather than being answered with the list's shared icon column, and all four values render in full in every sampled cell: one line at XXL in both orientations and at AX3 and AX5 landscape, two lines at AX3 portrait (6 / 1 / 2,526, then 501.8 MiB) and three at AX5 portrait (6 and 1, then 2,526, then 501.8 MiB). No value is ellipsised, cut mid-glyph or absent, and no glyph is clipped. The file name, uploader and timestamp below read in full when scrolled. At `.large` the compact row is unchanged — three counters leading, the file size trailing-anchored — so D-15 parity holds. **iPad walk (login-gated batch, 2026-09-04):** the four-value loss does not reproduce on iPad — the single-torrent counter row renders all four values (seed 8, leech 0, downloads 1,124, size 256.8 MiB) complete at portrait and landscape XXL/AX3/AX5, with the uploader and posted timestamp also reading (the timestamp reached by a short scroll at AX5). iPad column passes. | re-verified |
| 22 | #25 | iPhone portrait AX3 / AX5 | The reader's page indicator disappears in portrait. It is a single-line `Text` inside a glass capsule that shares one leading-aligned `HStack` with the close button (`ReadingFeature/Support/ControlPanel.swift:170–179`), and as the type grows the capsule is squeezed instead of the row wrapping: at AX3 the capsule shows only an ellipsis, and at AX5 it is a two-point-wide sliver that renders no glyph at all, while the accessibility tree still reports "1 / 14". The reader therefore stops telling the user which page they are on and how many pages there are — the one piece of state the control panel exists to show. The lower bar's separate "1" and "14" slider end labels survive, but they are the slider's bounds, not the current page. Landscape keeps the indicator intact at all three sizes. This is the pre-registered D-13 "reader total-page counter wrap" case and the D-04 site `ControlPanel.swift:176` — **and the pre-registered prediction is wrong: the counter does not wrap, it vanishes.** **Re-verify (batch 3, `15f9b09f`):** above the default size the bar's three members are handed to a `FlowLayout`, and the indicator takes its ideal width with `.fixedSize()` instead of being the only member with give. In portrait the close button and the indicator hold the first line and the three action glyphs move to a second, leading-aligned: the indicator measures 96,76 95x34 pt at XXL, 147x53 pt at AX3 and 186x67 pt at AX5, and every glyph is drawn (round 1: an ellipsis at AX3, a two-point sliver at AX5). Landscape AX5 still fits one line and reads in full at 164,16 186x67 pt. At `.large` the bar is the designed single row with identical frames — close 20,71 44x44, indicator 96,80 59x26, actions at 262 / 308 / 354 — measured on the same gallery in both builds. **Re-verify (batch 4, `89d02f52`):** re-confirmed on a different (166-page) gallery — the upper panel's page indicator stays on one line and fully legible at portrait XXL/AX3/AX5 and landscape AX5; the lower panel's page-range end labels ("1"/"166") remain single-line, not truncated. | re-verified |
| 23 | #23 | iPhone landscape AX3 / AX5 | The Detail screen's download **delete confirmation** loses its content in landscape, and what it loses is the safety half. The alert's container is bounded by the short landscape screen and does not scroll, so the growing text simply falls outside it: at AX3 the sentence "This will remove the downloaded gallery from this device." is cut after its fourth word, with the remainder hidden behind the button row; at AX5 **neither the sentence nor the Cancel button is drawn at all** — the alert shows its title and the red Delete button and nothing else, while the accessibility tree still lists a Cancel button positioned below the alert's visible bounds. A user at AX5 in landscape is presented with a destructive confirmation whose only visible, tappable affordance is Delete, and no on-screen way to back out other than guessing that a tap outside dismisses it. Portrait absorbs the same growth cleanly at all three sizes (the buttons restack vertically and the sentence wraps to five lines), and landscape at XXL is complete. This is a different site and a different container from finding #11 — that one is the Downloads tab's fixed-width popover in portrait; this one is the Detail screen's full alert in landscape — so it is recorded separately. Only the delete variant could be exercised: the retry-mode variant needs a download in an error state and the session's only download is complete. **Every dialog raised was cancelled; nothing was deleted.** **iPad walk (batch 7, 2026-09-04):** it does **not** reproduce on the iPad. All six iPad cells of #23 were raised from the same delete control and cancelled: at XXL both orientations the alert reads whole, and at AX5 both orientations the button row restacks vertically and title, sentence, Delete and Cancel all read inside the card. The iPad's own AX3 defect is a different one and is recorded as finding #37. | accepted (owner 2026-09-09: insufficient landscape AX5 display space; accepts the missing message/Cancel shown in the fresh snapshot) |
| 24 | #29 | iPhone portrait XXL / AX3 / AX5; iPhone landscape AX3 / AX5 | The Account screen's cookie rows keep their label and their value on a single line inside one row, and the value is the half that gives way: the label wraps (and even hyphenates) while the value is ellipsised. In portrait the long hash value already loses roughly a third of what it shows at the default size at XXL; at AX3 the short numeric member id — which reads complete at the default size and at XXL — is cut after five of its seven digits, and the ExHentai token is cut to four characters; at AX5 all three value fields are three or four characters plus an ellipsis while their labels occupy four wrapped lines each. Landscape absorbs XXL entirely (the hash renders all thirty-two characters there) and then fails the same way from AX3 up. Every one of these values is a credential fragment the row exists to let the user verify, and none of them is reproduced anywhere else in the app — the neighbouring copy action puts them on the pasteboard but never shows them. **Re-verify (batch 3, `f9286303`):** above the default size the pair stops sharing a line — the key takes the first with its validity glyph trailing, and the value takes the whole row width beneath it in a vertical-axis field that wraps. Every value reads in full in all six iPhone cells: the thirty-two-character hash wraps over three lines at XXL portrait (round 1 cut it after fourteen characters), fills a 340x250 pt field over four lines at AX5 portrait (round 1: three or four characters plus an ellipsis under a four-line key), and reads whole in 712x96 pt at XXL landscape, 712x64 pt at AX3 landscape and 712 pt at AX5 landscape (round 1 cut it after sixteen and twelve characters respectively). The seven-digit member id and the ExHentai token likewise read in full at every size. Wrapped values are leading-aligned, and the 8 pt gap keeps key and value reading as one pair. At `.large` the row is the designed single line with identical frames. | re-verified |
| 25 | #32 | iPhone portrait AX3 / AX5; iPhone landscape AX5; iPad portrait AX3 / AX5; iPad landscape AX3 / AX5 | The activity-log row's category chip is a single-line pill (`SettingFeature/AppActivityLogs/AppActivityLogsView.swift:224`, `lineLimit(1)`) sharing one baseline-aligned row with the level dot and the timestamp, and the timestamp is the part allowed to wrap. The chip therefore gives up characters as the type grows while the timestamp beside it reflows freely: `DownloadCoordinator` reads in full at the default size and at XXL, is ellipsised at AX3 on the iPad, and shortens further at AX5 in both orientations. The chip is the only thing on the row that says which subsystem emitted the log, and two different subsystems whose names share a prefix become indistinguishable once it is cut. The log message underneath, by contrast, wraps perfectly at every size. **Re-verify (batch 1, `6df974e9`, `aa3e18e1`):** the category chip wraps inside its pill and keeps the whole subsystem name at iPhone portrait AX3/AX5 and landscape AX5. **Not re-walked in batch 1:** the four iPad cells — the iPad re-walk scope this round was #2, #3, #7 and #9. **Re-verify (batch 2, `803756c3`):** timestamp and category chip now sit in an `AdaptiveStack`. In portrait at XXL, AX3 and AX5 the chip drops to a line of its own beneath the timestamp and both read in full; in landscape the row is wide enough and the two share a line, still both complete. | re-verified |
| 26 | #32, #25 | iPhone portrait AX3 / AX5; iPhone landscape AX5; iPad portrait AX5; iPad #25 portrait AX3 / AX5 and landscape AX3 / AX5 | The Runs menu stops drawing the checkmark beside the selected run as the type grows. At the default size and at XXL the menu marks the current run with a leading tick, which is the only thing in the menu that says which run the list below is showing. At the affected sizes the tick is not rendered while the run labels keep their full text, so the menu presents identical-looking rows and the screen no longer tells the user which one it is displaying. The accessibility tree still reports the checkmark, so this is visible only in the rendered frame. The iPad's run picker sheet reached through More Logs keeps its tick at AX5, confirming that the selection state survives in the sheet and is lost only in the menu. **Second site found on the iPad (batch 7, 2026-09-04):** the same failure occurs in the reader control panel's **Auto-Play** menu (#25, `ReadingFeature/Support/ControlPanel.swift`). At `.large` and at XXL the menu marks the active interval — `Off` here — with a leading checkmark; from AX3 upward, in both orientations, the tick is not rendered while the interval labels keep their full text, so the menu no longer says which interval is selected. The accessibility tree still reports `#checkmark` on the selected row, exactly as on #32, so this is again visible only in the rendered frame.  **Owner confirmation (2026-09-09):** both Runs and Auto-Play selection-mark cases are fixed. Later native-Picker implementation and targeted checks are recorded in `16-TARGETED-RECHECK.md`, superseding the historical awaiting-implementation diagnosis. | re-verified (owner 2026-09-09: confirmed fixed; no new agent device verification in this review) |
| 27 | #38 | iPhone portrait XXL / AX3 / AX5; iPhone landscape AX5 | The Excluded Languages grid's three column headers (`SettingFeature/EhSetting/EhSettingView+Sections3.swift:131`) are `lineLimit(1)` plus `fixedSize()` inside height-less `Color.clear` columns, so they refuse to wrap or shrink and instead grow past the column boundaries. At the default size the words Original, Translated and Rewrite sit separated and centred above their radio columns. From XXL upward they run together into one unbroken string and slide to the right of the columns they label, so the grid keeps twenty-odd rows of identical circles with nothing that says which circle means what. Every row's radio triple is still drawn and still tappable — what is lost is the only thing that gives the grid meaning. Because the headers are `fixedSize()` the string is not ellipsised, it simply overlaps and overflows, which is why the accessibility tree reports all three words correctly at every size. Landscape is wider and absorbs XXL and AX3 — the three words stay separated and centred over their columns there — and fails the same way only at AX5. **Re-verify (batch 3, `32177686`):** above the default size the three-column radio matrix is dropped for one block per language — the language name as a heading, then three native switches labelled Original / Translated / Rewrite — so no option depends on a column position any more. Verified at XXL, AX3 and AX5 portrait and at AX5 landscape: nothing overlaps, nothing is ellipsised, and the first row correctly omits its `original` cell rather than drawing it invisibly. At `.large` the grid is untouched: the three headers sit at the identical x 153 / 226 / 317 in both builds, separated and centred over their columns. **iPad walk (login-gated batch, 2026-09-04):** the fix holds on iPad too — on the regular-width EhSetting form-sheet each language renders as a bold header above Original / Translated / Rewrite labeled toggle rows (leading-aligned, toggles right-aligned), nothing overlapping or truncated, at portrait XXL/AX3/AX5 and landscape AX5. iPad column passes. | re-verified |
| 28 | #38 | iPhone portrait AX5 | EhSetting's `LabeledContent` rows stop reserving room for their own contents once both the label and the picker value need several lines. On the Multi-Page Viewer section at AX5 portrait the three-line "Use Multi-Page Viewer" label runs past the bottom of its row and is drawn over the next row's label, which is itself only half visible; the picker value below it ("Align left, scale if overwidth") has its last word drawn across the row separator and cut by the following row's background. Three consecutive rows are involved and two of them cannot be read at all. This is different from a wrap: the text is not reflowed into a taller row, it is painted outside the row it belongs to and covered by its neighbour. The same three rows are clean at AX5 in landscape, where the wider row keeps every label on one line. **iPad walk (login-gated batch, 2026-09-04):** this `LabeledContent` overlap does **not reproduce on iPad** — EhSetting renders as a regular-width form-sheet whose Multi-Page Viewer 'Display Style' picker expands inline to full wrapping rows (Align left / center variants, checkmark on the selected) and whose 'Use Multi-Page Viewer' toggle-label wraps without overlapping its neighbour, at portrait XXL/AX3/AX5 and landscape AX5. The iPad #38 cell passes because the wider layout avoids the failure; the iPhone-portrait-AX5 defect this entry describes still stands, so the status is left unchanged. **Recheck (2026-09-09) and owner disposition (2026-09-11):** the sampled iPhone portrait AX5 check recorded in `16-LOGIN-COVER-RECHECK.md` (Account Configuration, Multi-Page Viewer toggle and display-style options) shows the toggle label and the display-style labels wrapping into distinct rows with no overlap reproduced; on 2026-09-11 the owner dispositioned the finding `#28=fixed` on that basis. The basis is the 2026-09-09 sampled agent check plus the owner's disposition; no new device verification was run on 2026-09-11. | re-verified (owner 2026-09-11: confirmed fixed on the 2026-09-09 sampled iPhone portrait AX5 check; no new device verification in this review) |
| 29 | #39 | iPhone portrait XXL / AX3 / AX5; iPhone landscape XXL / AX3 / AX5; iPad portrait XXL / AX3 / AX5; iPad landscape XXL / AX3 / AX5 | The Filters sheet's category grid keeps every name to one line inside narrow cells (`AppComponents/CategoryView.swift:87`, `lineLimit(1)`), so names are eaten from the right as type grows. On iPhone the fixed three-column grid cuts two names at XXL, eight at AX3, and all nine at AX5; landscape lays out six per row but keeps the same progression. The iPad's 100-point adaptive columns reproduce the failure in all six cells: more columns fit across the wider sheet, but their width does not grow with the labels, so names are already ellipsised at XXL and collapse further at AX3 / AX5 in both orientations. Several cells become mutually indistinguishable from text alone. The colour is the cell's other identifier, but colour alone is not a name, and the grid is the sheet's primary control. **Re-verify (batch 3, `7645e10c`):** the grid's adaptive column bounds are now `@ScaledMetric(relativeTo: .body)` from the designed 80 / 100 / 100 and are clamped by the measured grid width, and a cell's name loses its one-line cap above the default size, so a name that still does not fit its widened column wraps. All ten names read in full in all twelve cells. Measured column counts — iPhone portrait: 3 at `.large` and XXL (Game CG, Image Set and Asian Porn on two lines), 1 at AX3 and AX5; iPhone landscape: 5 at XXL, 3 at AX3, 2 at AX5; iPad portrait: 5 at `.large`, 4 at XXL, 2 at AX3 and AX5; iPad landscape: 4 at XXL, 2 at AX3 and AX5. At `.large` every name's frame is identical in both builds on both devices. One caveat: no round-1 capture of the iPad AX3-portrait cell shows the grid, so that one after-image is supplementary rather than a pair. **Re-verify (batch 4, `db5afd4e`):** answering the owner's round-II direction ('the cell was designed with rounded corners and still reads square at accessibility sizes: its corner radius scales with the text, like the badge's'), `CategoryCell`'s corner radius is now `@ScaledMetric(relativeTo: .body)` and every chip reads rounded, not square, at every sampled size. Also re-walked the whole sheet top to bottom on both devices at XXL/AX3/AX5 in both orientations, per the owner's direction that review captures show the whole sheet: all ten names remain complete and every control below the grid (Reset Filters, Advanced Settings, the search-scope toggles, the minimum-rating stepper, the pages-range fields, the custom-filter toggles) renders correctly. | re-verified |
| 30 | #40 | iPhone portrait XXL / AX3 / AX5; iPhone landscape AX5 | Quick Search's saved-word name is `lineLimit(1)` (`QuickSearchFeature/QuickSearchView.swift:40`). A throwaway row whose name and content both read in full at the default size is already cut in portrait Edit mode at XXL, is cut in the ordinary row from AX3 upward, and remains cut at AX5 landscape. Edit mode makes the failure worse because the delete and reorder controls take width from both text lines: at AX3 portrait the content is also reduced to a few characters plus an ellipsis. The editor fields themselves reflow correctly. The throwaway item and its generated search-history entry were both removed after the walk, restoring the original empty list. **Re-verify (batch 1, `03ec0db6`):** the saved word's name and its content read in full in both the ordinary row and Edit mode at portrait XXL/AX3/AX5 and landscape AX5. | re-verified |
| 31 | #42 | iPhone portrait XXL / AX3 / AX5; iPhone landscape AX3 / AX5; iPad portrait AX3 / AX5; iPad landscape AX5 | The error toast's title stays complete, but its subtitle is hard-capped to one line (`SystemNotification/ToastMessageView.swift:70`) and progressively loses the unsupported-link explanation as Dynamic Type grows. On iPhone the complete sentence is visible in landscape XXL, while portrait XXL already ends after `recognized…`, portrait AX3 after `was…`, and portrait AX5 after `link…`; landscape AX3 and AX5 also ellipsise. The iPad absorbs the sentence at portrait and landscape XXL and at landscape AX3, but portrait AX3 / AX5 and landscape AX5 still cut it. The detail sheet reflows and scrolls through the complete Description, Suggested Solution, Context and Environment sections at every sampled size, so this finding is confined to the toast's immediate message. **Re-verify (batch 1, `2003c4f6`):** fixed at portrait XXL and at both landscape cells, where the subtitle reads the whole sentence. At portrait AX3 and AX5 it is still ellipsised after three lines. **Not re-walked in batch 1:** the iPad cells. Remains **open**. | accepted (owner reason, 2026-09-08: 「展示不下就展示不下直接接受」) |
| 32 | #3 | iPad portrait AX3 / AX5 | The regular-width gallery row keeps its category badge and timestamp on one horizontal stats line without reserving space between them. A long category name that fits beside the timestamp at XXL grows across the timestamp at AX3; at AX5 the badge covers the timestamp's leading date characters. Both values still exist, but their glyphs are painted on top of one another and cannot be read independently. The wider landscape row keeps them separated at all three sampled sizes. **Re-verify (batch 1, `b598c933`):** the regular-width row puts the category badge on its own line above the timestamp, so the two are no longer painted over each other at iPad portrait AX3 and AX5. **Re-verify (batch 2, `803756c3`):** on the iPad's regular-width row at AX3 and AX5 the category badge and the timestamp are on the same stats line with clear space between them — the badge no longer paints across the timestamp — and the badge's corners scale with its text so it still reads as a rounded pill. | re-verified |
| 33 | #30 | iPad portrait AX5; iPad landscape AX5 | The native Login screen's large heading and first field do not reserve enough vertical space for each other at AX5. The bottom of `Login` is painted through the `Username` label, leaving both strings present but impossible to read independently. The same overlap occurs in the compact-height landscape modal; XXL and AX3 keep the heading and field separated in both orientations. No credential was entered and no login was submitted. **Re-verify (batch 3, `0a965af3`):** above the default size the screen stops ignoring the safe area, so the navigation bar's inset — as tall as the title it draws — pushes the form down instead of under it, and a `ViewThatFits(in: .vertical)` lets the column scroll when it outgrows the height. At iPad AX5 portrait the heading sits at 147,339 171x72 pt and the `Username` label at 243,450, clear of each other, with both fields and the Login button drawn; the compact-height landscape modal is clear at AX5 too, and AX3 is clear in both orientations. At `.large` every frame is identical to the pre-batch build. No credential was entered and no login was submitted. | re-verified |
| 34 | #9 | iPhone portrait AX5 | The section heading and its trailing Show All button share one line and the button keeps its share of the width, so at AX5 in portrait the heading is squeezed into a column about one short word wide and breaks mid-word across four lines. No characters are lost, so this is a layout-quality defect rather than a D-03 information loss, but the heading stops reading as a heading. It does not reproduce in landscape, where the wider line keeps it whole. Opened by the round-1 re-verification of fix batch 1. **Re-verify (batch 2, `803756c3`):** `SubSection` now gives the title a line of its own at the accessibility sizes, leading-aligned, with **Show All** beneath it and omitted entirely (no reserved blank line) where the section offers none. The heading no longer breaks mid-word. Verified on the Search root's Quick Search, Recently Searched and Recently Seen headings, on Home's Frontpage, Toplists and Other, and on Detail's Previews and Comments headings, at XXL, AX3 and AX5 in both orientations on both devices. `KeywordCell` is leading-aligned with the magnifier on the keyword's first line above `.large` and keeps its centred glyph at `.large`, where the glyph-to-text gap is unchanged from round I. | re-verified |
| 35 | #14 | iPhone `.large` (default size) | **D-15 parity change.** In the Detail comment card, a card that carries a vote score now renders its score and date on a line of their own beneath the author, so the body starts one line lower than it did before the batch; a card with no score is pixel-identical. No information is lost and the change is confined to the default size, but D-15 ranks `.large` appearance parity above the modifier removal that produced it, so the owner decides whether to accept the new default-size look. Opened by the round-1 re-verification of fix batch 1 (`37b56570`). **Re-verify (batch 2, `803756c3`):** inherited unchanged — this batch did not touch `DetailView+CommentCells.swift`, and the `.large` comment strip is identical to the round-I build. Still awaiting the owner's disposition. | accepted (owner 2026-09-09: score and date may appear beneath the author at normal text size) |
| 36 | #19 | iPad portrait AX5; iPad landscape AX3 / AX5 | **NEW — iPad-only, found in the login-gated re-verification walk (2026-09-04).** The Archives sheet renders as a regular-width form-sheet on iPad, and at the accessibility sizes its `scrollingColumn` branch is taller than the short sheet. When the user scrolls down to reach the funds row and the Download button, the sheet's large 'Archives' navigation title does not collapse or scroll away — there is too little scroll travel to clear it — so it stays and overlaps the '1280x' archive card beneath it, painting the title's glyphs over the card's text. The archive values read at the top of the sheet; the overlap appears only once scrolled. Portrait AX3 passes (the large title scrolls fully off before the content arrives) and XXL passes (the `pinnedColumn` layout fits without scrolling), so this is confined to portrait AX5 and landscape AX3/AX5. The parallel Torrents sheet (#20) does not show it: its single-torrent content is short and its title collapses away cleanly. **Re-verify (batch 6, `fbcc1694`):** the sheet now carries the phase's title policy with its designed `.automatic` mode, so at and below the default size it keeps the large title and above it falls back to inline. Walked on the iPad in all three failing cells: portrait AX5 and landscape AX3/AX5 draw a compact inline `Archives` (84x26) in the sheet's bar, the funds rows and the Download button are reachable by scrolling, and no title glyph is painted over an archive card — content scrolls under the bar's own material, which is ordinary chrome behaviour. `.large` portrait is unchanged: the title is still the leading large one (139x41). | re-verified |
| 37 | #23 | iPad portrait AX3; iPad landscape AX3 | **NEW — iPad-only, found in the batch-7 iPad walk (2026-09-04).** The Detail download **delete confirmation** does not reserve the height its own button row needs at AX3. The alert keeps the two buttons side by side at that size — it only restacks them vertically at AX5 — and the row grows to 96 pt tall while the card's height is computed as though it were shorter, so the card's rounded bottom edge cuts both capsules roughly in half and the `Cancel` and `Delete` labels sit on the clip line with no bottom padding at all. The labels are still legible and the alert is still operable, so no value is lost outright, but a destructive confirmation renders visibly broken and its buttons' lower halves fall outside their own container. It reads correctly at `.large` and at XXL (button row well inside the card) and again at AX5 (stacked buttons, full bottom padding), so AX3 is the one size where the container's height and its contents disagree. Both orientations show it identically. Every dialog raised was cancelled; nothing was deleted. **Diagnosis (phase lead, 2026-09-04):** this is the **system's** alert, not the app's. `DetailReducer` builds an `AppAlertState`, and `AppComponents/AppAlertState.swift`'s `appAlert(_:)` renders it through SwiftUI's native `.alert(_:isPresented:presenting:actions:message:)`. The card, its height, its corner radius and the button row's layout are all drawn by the system; the only inputs the app supplies are the title, the message and the buttons' labels and roles. The capture was re-examined directly and the clip is exactly as recorded — the card's rounded bottom edge passes through both capsules. There is therefore no supported app-side lever: the one workaround available (rebuilding the confirmation as a custom card) is already ruled out by the standing preference for native presentation surfaces, and shortening the message to dodge a height miscalculation would trade real information for a fix that each localization would wrap differently. **Recommended disposition: accept as a system defect and file it with Apple**, unless the owner wants the copy shortened. No code change was made. | accepted (owner reason: system defect) |
| 38 | #22 | iPad portrait AX5; iPad landscape AX5 | **NEW — iPad-only, found in the batch-9 mock walk (2026-09-04).** `NewDawnView` lays its three text blocks out in a plain `VStack` inside two `.overlay`s over a full-bleed gradient, with `lineLimit(nil)` and `fixedSize(horizontal: false, vertical: true)` and **no scroll container** (`AppComponents/NewDawnView.swift:66`). The block therefore grows without bound as the type size grows, and on the iPad — where the greeting is presented as a regular-width form-sheet rather than full-screen — it outgrows the sheet at AX5 and is clipped at both ends: the opening line `It is the dawn of a` is sliced horizontally by the sheet's top edge and the closing `Hath!` by its bottom, in both orientations. Nothing scrolls, so neither is recoverable. Both read in full at `.large`, XXL and AX3, so AX5 is the onset. The iPhone, which presents the same view full-screen, still renders the whole greeting at AX5 — but with the block spanning the screen edge to edge and the title drawn across the decorative sun, so the same absence of a scroll container is one longer string away from clipping there too. Two further defects on this screen are **not** type-size regressions and are recorded here only so they are not rediscovered: the Dynamic Island covers the first characters of two lines in iPhone landscape, and white body text is drawn over the yellow sun — both identical at `.large`, so both fail the D-04 comparison basis. **Re-verify (batch 10, `fc900bde`):** fixed as the owner directed — `NewDawnView` gained a `ScrollView` and `TextView` lost its `fixedSize(horizontal:vertical:)`. The content keeps the container's height as a *floor* (`minHeight`, measured with `onGeometryChange`) so it stays centred while it fits, and `scrollBounceBehavior(.basedOnSize)` withholds the bounce until there is something to scroll to. Walked on the iPad at portrait AX5: the opening line now draws in full at the top of the sheet and two swipes reach the closing `Hath!` complete — against a build where both were sliced by the sheet's edges. The iPhone at portrait AX5 shows the same behaviour full-screen. `.large` parity checked on both: the greeting is still vertically centred in its container and nothing scrolls. | re-verified |
| 39 | #8 Favorites | iPhone portrait AX5 | The native Search drawer is a blank capsule at AX5, with its magnifier and placeholder missing; the `.large` reference retains both. The title and gallery metadata remain complete and the tail remains reachable. | open — owner-routed to 16-26; not fixed; historical #4 acceptance does not apply |
Status ∈ {`open`, `fixed-by <commit>`, `re-verified`, `accepted`}.


## D-13 named edge cases

The five edge cases from ROADMAP criterion 4, pre-registered as named items so criterion 4 ticks
off item by item and none is silently dropped. Tracked alongside § Findings, not merged into it.
Each closes as `fixed` or `accepted (owner reason: …)` — never by omission.

| Case | Screen | Site | Observed (iPhone, round 1) | Observed (after, batch 1) | Status | Disposition |
|---|---|---|---|---|---|---|
| Detail stats-strip abbreviation | #14 | `DetailFeature/DetailView+Subviews.swift:99, 116` (stats strip) | It reproduces, and it is worse than "abbreviation": the strip's columns keep a fixed fraction of the container width and a fixed row height, so the column **labels** ellipsise first (at XXL portrait already — "FAVORITED" → "FAVORI…", "196 RATINGS" → "196 RAT…") and from AX3 up in portrait the **values** go too: a four-digit favourite count reads "11…" at AX3 and "1…" at AX5, a 4.50 rating reads "4.…" then is lost, and the unit lines read "Engl…" / "Ti…". The five-star rating row is clipped at both ends at every accessibility size and shows three stars for a 4.50 rating at AX5 landscape. Landscape keeps the values but loses the labels from AX3. Observed in iPhone portrait XXL / AX3 / AX5 and iPhone landscape AX3 / AX5; recorded as finding #14. **iPad observed:** blocked at all six cells because live Detail requires a session and `IPAD_LOGIN=none`; no iPhone verdict was inferred for the iPad's modal layout. | **Re-verified.** The strip now stacks each caption above its value above the default size. At iPhone portrait XXL, AX3 and AX5 every column keeps both its label and its value and the star row is complete; landscape XXL, AX3 and AX5 likewise keep labels and values. Tracked as finding #14, now `re-verified`. **iPad walk (login-gated batch, 2026-09-04):** with the owner signed in on `IPAD_UDID` (D-09), the iPad column is walked at last — on the regular-width Detail modal the stats strip is a horizontal `ScrollView` that reveals every column (Favorited, Language, Ratings with an un-clipped five-star row, Page Count, File Size), each label and value complete and no column spanning the card width, at portrait XXL/AX3/AX5 and landscape XXL/AX3/AX5. The iPad case passes; the D-13 stats-strip case is now confirmed fixed on both devices. | fixed | fixed (owner approved 2026-09-09, based on recorded passing iPhone and iPad checks) |
| Long-tag right-edge clip | #14 | `AppComponents/TagCloudView.swift:122` (tag cloud) | It reproduces in portrait from AX3 up. Tags are laid out from a fixed leading column and are neither wrapped nor ellipsised when they exceed the remaining width, so a long tag runs off the right edge of the screen and is cut mid-glyph with nothing to mark the loss. At AX3 portrait a sixteen-character tag loses its last six characters; at AX5 portrait two separate tags are cut (one tag's own frame is 64 points wider than the screen) and the label column beside them is itself clipped. The same tags read in full at `.large` and in landscape at XXL / AX3 / AX5. Observed in iPhone portrait AX3 / AX5; recorded as finding #15. **iPad observed:** blocked at all six cells because live Detail requires a session and `IPAD_LOGIN=none`; no iPhone verdict was inferred for the iPad's modal tag-cloud layout. | **Re-verified.** Tags now wrap inside their own chip instead of extending past the trailing edge, so no tag is cut mid-glyph at portrait AX3 or AX5 and the label column beside them stays whole. The same tags continue to read in full at `.large` and in landscape. Tracked as finding #15, now `re-verified`. **iPad walk (login-gated batch, 2026-09-04):** the iPad column is walked at last — on the regular-width Detail modal every tag chip wraps inside the card, the namespace chips stack above their children, and no tag runs off the trailing edge, at portrait XXL/AX3/AX5 and landscape XXL/AX3/AX5. The iPad case passes; the D-13 long-tag case is now confirmed fixed on both devices. | fixed | fixed (owner approved 2026-09-09, based on recorded passing iPhone and iPad checks) |
| Reader total-page counter wrap | #25 | `ReadingFeature/Support/ReadingToolbar.swift` (native upper toolbar page indicator) | **The pre-registered prediction does not hold: the counter does not wrap, it disappears.** The indicator is a single-line `Text` in a glass capsule sharing a leading-aligned `HStack` with the close button, so as the type grows the capsule is squeezed rather than the row wrapping. In **portrait** it reads "1 / 14" in full at XXL, shows only an ellipsis at AX3, and at AX5 renders nothing at all — a two-point-wide sliver beside the close button — while the accessibility tree still reports the full string. In **landscape** it reads in full at XXL, AX3 and AX5. The lower bar's "1" and "14" slider end labels survive in every cell, but those are the slider's bounds, not the current page. Recorded as finding #22 and left undispositioned here per D-13 — with the wrap-is-acceptable reasoning no longer applicable, since nothing wraps. **iPad observed:** blocked at all six cells because the regular-width panel requires a live Reading session and `IPAD_LOGIN=none`; no iPhone verdict was inferred for its five/seven-thumbnail `.callout` layout. | Historical finding #22 was re-verified in batches 3 and 4, including a 166-page gallery. Subsequent native-toolbar implementation supersedes that FlowLayout: the 2026-09-09 checks in `16-TARGETED-RECHECK.md` record complete sampled page numbers at AX5 on iPhone and iPad, including the final leading iPad title. These are targeted checks, not an exhaustive verdict for every page-count length or configuration. | fixed | fixed (owner approved 2026-09-09, based on the recorded native-toolbar checks on iPhone and iPad) |
| Favorites trailing-glyph clip | #8 | `FavoritesFeature/FavoritesView.swift` toolbar/menu glyphs + `GalleryListComponents/Cells/GalleryDetailCell.swift:140` trailing symbol | On iPhone, the toolbar and menu glyphs do **not** clip: the favourites-index, sort-order and features glyphs keep their size and stay fully drawn at AX5 in both orientations, and the row's trailing `photoOnRectangleAngled` symbol is likewise never cut. What is lost is the number beside that symbol — at AX3 the page count loses digits at the screen's right edge and at AX5 only the glyph survives with no number at all (finding #6). So the pre-registered glyph clip does not reproduce on iPhone; the paired value does. iPad observation is blocked because `IPAD_LOGIN=none`; no iPad glyph verdict was inferred. | **Re-verified for the paired value.** The row now reflows above the default size, so the page count keeps its number beside the trailing symbol at AX3 and at AX5 in both orientations, and the toolbar and menu glyphs are still never cut. The pre-registered glyph clip still does not reproduce. Tracked as finding #6, now `re-verified`. iPad Favorites remains blocked by `IPAD_LOGIN=none`. | fixed | fixed (owner approved 2026-09-11, based on the recorded iPhone #6 re-verification and the 2026-09-09 sampled iPad populated Favorites AX3/AX5 checks) |
| Hero-carousel title truncation | #2 | `HomeFeature/GalleryCardCell.swift:73` (`lineLimit(4)`) | It ellipsises, which is the pre-registered failing case, and it does so well before AX5 on both devices. On iPhone at AX5 in **portrait** only the first word survives and the ellipsis sits on top of the neighbouring card's artwork (finding #2); at AX5 in **landscape** the title ends after roughly three words. On iPad the title also loses its tail in every sampled cell: portrait contracts from an ellipsised multi-line title at XXL to only its opening words at AX5, while landscape's extra width still cannot preserve the tail at XXL, AX3, or AX5. The title does not make useful use of `lineLimit(4)` at any accessibility size — the card's fixed height, not the nominal line limit, removes the text. Recorded as finding #1. | Later cover revisions supersede the batch-1 layout described previously. The current bounded-height carousel can still ellipsize long titles at larger text sizes; see `16-TARGETED-RECHECK.md` and `.planning/quick/20260908-slideshow-viewport-cap/REVISION.md`. The owner accepts that truncation behavior. | accepted | accepted (owner 2026-09-09: keep the card height limit; long titles may truncate with an ellipsis) |

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
| `GalleryListComponents/Cells/GalleryDetailCell.swift:155` (0.75) | stats value shrunk instead of reflowed | all list hosts (#3, #4, #5, #8, #10) | fine | removed-by 59fb2eb9 | Removed by `59fb2eb9` (`feat: complete Dynamic Type accessibility layouts`, 2026-09-02; verified with `git log -S'minimumScaleFactor' -- AppPackage/Sources`: five `.minimumScaleFactor` lines removed, none added, live count 0). Previously `finding:#6`, closed `re-verified`. Removal target 0 (D-14). |
| `GalleryListComponents/Cells/GalleryDetailCell.swift:166` (0.75) | stats value shrunk instead of reflowed | all list hosts (#3, #4, #5, #8, #10) | fine | removed-by 59fb2eb9 | Removed by `59fb2eb9` (`feat: complete Dynamic Type accessibility layouts`, 2026-09-02; verified with `git log -S'minimumScaleFactor' -- AppPackage/Sources`: five `.minimumScaleFactor` lines removed, none added, live count 0). Previously `finding:#6`, closed `re-verified`. Removal target 0 (D-14). |
| `DetailFeature/DetailView+CommentCells.swift:42` (0.75) | comment author shrunk | #14 | fine | removed-by 59fb2eb9 | Removed by `59fb2eb9` (`feat: complete Dynamic Type accessibility layouts`, 2026-09-02; verified with `git log -S'minimumScaleFactor' -- AppPackage/Sources`: five `.minimumScaleFactor` lines removed, none added, live count 0). Previously `finding:#16`, closed `re-verified`; the `.large` parity delta on the vote-score card was raised as finding #35 and owner-accepted 2026-09-09. Removal target 0 (D-14). The 0.75 shrink visibly engages at XXL and the author is still ellipsised. |
| `DetailFeature/DetailView+HeaderSection.swift:73` (0.72) | header category label shrunk | #14 | fine | removed-by 59fb2eb9 | Removed by `59fb2eb9` (`feat: complete Dynamic Type accessibility layouts`, 2026-09-02; verified with `git log -S'minimumScaleFactor' -- AppPackage/Sources`: five `.minimumScaleFactor` lines removed, none added, live count 0). Previously `fine`; the batch-1 `.large` parity capture matched its banked baseline. **D-15 collision — plausibly engages at `.large`; parity outranks the ban.** **D-15 evidence:** the 0.72 shrink does NOT visibly engage at `.large` for a seven-character category, and the badge never truncates at XXL / AX3 / AX5 either — so removing it should be parity-safe for that name length. |
| `DetailFeature/Comments/CommentsView.swift:165` (0.75) | comment header shrunk | #16 | fine | removed-by 59fb2eb9 | Removed by `59fb2eb9` (`feat: complete Dynamic Type accessibility layouts`, 2026-09-02; verified with `git log -S'minimumScaleFactor' -- AppPackage/Sources`: five `.minimumScaleFactor` lines removed, none added, live count 0). Previously `finding:#18`, closed `re-verified`. Removal target 0 (D-14). The 0.75 shrink engages before the ellipsis and does not prevent it. |

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
| 14 Gallery Detail | 16-24: the action row ("Give a Rating" / "Similar Gallery") labels gain `minHeight: 24` for the audit's hit region; at `.large` the row is 3.7 pt taller and everything below it moves down 11 px, header and stats strip unchanged (`16-CONTRAST-AUDIT.md § Automated audit (16-24) › D-25`) | XXL / AX3 / AX5, iPhone portrait (16-26) | withdrawn: cc05aca6 reverted the 16-24 minHeight (owner, 2026-09-15; 16-CONTRAST-AUDIT.md § Visible-change review (2026-09-15)); the action row is back to its pre-16-24 height |
| Search root (#W-22) | v3b changes the `SuggestionsPanel` intrinsic-height floor, title identity and search layout; committed in `7edfb1a7` (`fix(16-25): stabilize sparse search layout`); `.large` BF/AF captures: `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/search-dynamic-20260917/iphone-S3-large-before-verified/search.png` → `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/search-dynamic-20260917/iphone-S3-large-after-verified/search.png` | XXL / AX3 / AX5, iPhone portrait (16-26); W22 before/after matrix and bounded dynamic evidence recorded below | closed: pass |
| Favorites (#W-22) | v3b applies the same signed-out content-identity change in `FavoritesView.swift`; committed in `7edfb1a7`; `.large` BF/AF captures: `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/calibration-v3b/before/favorites-out-large-1.png` → `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/calibration-v3b/after/favorites-out-large-1.png`, and signed-in `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/calibration-v4-phone/before/favorites-in-large/screen.png` → `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/calibration-v4-phone/after/favorites-in-large/screen.png` | XXL / AX3 / AX5, iPhone portrait (16-26) | finding:#39 — D-25 re-sweep owner-routed; not fixed |
| Watched (#W-22) | v3b applies the same signed-out content-identity change in `WatchedView.swift`; committed in `7edfb1a7`; `.large` BF/AF captures: signed-out `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/calibration-v4-controls/watched-out-large/before/screen-2.png` → `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/calibration-v4-controls/watched-out-large/after/screen-2.png`, and signed-in `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/calibration-v4-phone-reload/before/watched-in-large/screen.png` → `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/calibration-v4-phone-reload/after/watched-in-large/screen.png` | XXL / AX3 / AX5, iPhone portrait (16-26) | closed: pass |

### Re-sweep cells (16-26)

Root's approved ordering amendment ran the measurement and closing gates before writing this summary
documentation. Plan-start repository HEAD was `8a199c2f`; the immutable measured source was
`b01add4c11b1f9c355ac8f2e055ed8b24fe8146c`, with loader and dylib hashes recorded in
`16-25-SUMMARY.md`. The `.large` Search capture is reference only and is not counted in the nine-cell
matrix; its readable filename pattern is `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-large-9-top.png`
and `iphone-portrait-large-9-bottom.png`. Each measured size has top/bottom captures, matching UI
JSON, a readback, and two scroll UI captures; after both scrolls normalized entries and frames were
stable, and the title, field, Recently Searched, final keyword, and normal native drawer scroll-away
were bounded.

| Screen | Device | Orientation | Size | Status | Evidence |
|---|---|---|---|---|---|
| Search root #9 | WALK | portrait | XXL | pass | `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-xxl-9-top.png`, `-bottom.png`, matching `-top-ui.json`/`-bottom-ui.json`, `-readback.txt`, `-scroll1-ui.json`, `-scroll2-ui.json` |
| Search root #9 | WALK | portrait | AX3 | pass | `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax3-9-top.png`, `-bottom.png`, matching `-top-ui.json`/`-bottom-ui.json`, `-readback.txt`, `-scroll1-ui.json`, `-scroll2-ui.json` |
| Search root #9 | WALK | portrait | AX5 | pass | `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-9-top.png`, `-bottom.png`, matching `-top-ui.json`/`-bottom-ui.json`, `-readback.txt`, `-scroll1-ui.json`, `-scroll2-ui.json` |
| Favorites #8 | LOGIN | portrait | XXL | pass | `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-xxl-8-top.png`, `-bottom.png`, matching `-top-ui.json`/`-bottom-ui.json`; settled scroll boundary 12 steps; `.large` reference is the existing 8-step calibration |
| Favorites #8 | LOGIN | portrait | AX3 | pass | `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax3-8-top.png`, `-bottom.png`, matching `-top-ui.json`/`-bottom-ui.json`; settled scroll boundary 29 steps |
| Favorites #8 | LOGIN | portrait | AX5 | finding:#39 | `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-top.png`, `-bottom.png`, matching `-top-ui.json`/`-bottom-ui.json`; settled scroll boundary 43 steps; native Search drawer is a blank capsule missing magnifier and placeholder, while title/gallery metadata remain complete and tail is reachable |
| Watched #5 | LOGIN | portrait | XXL | pass | `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-xxl-5-settled-top.png`, `-bottom.png`, matching `-top-ui.json`/`-bottom-ui.json`; settled boundary; visible NotFound/Retry error state, no Retry activation |
| Watched #5 | LOGIN | portrait | AX3 | pass | `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax3-5-settled-top.png`, `-bottom.png`, matching `-top-ui.json`/`-bottom-ui.json`; settled boundary; visible NotFound/Retry error state, no Retry activation |
| Watched #5 | LOGIN | portrait | AX5 | pass | `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-5-top.png`, `-bottom.png`, matching `-top-ui.json`/`-bottom-ui.json`; visible NotFound/Retry error state, no Retry activation |

### Re-sweep closure

The current D-25 set is three screens and nine iPhone-portrait cells: Search root, Favorites, and Watched. Eight cells are bounded pass results and one is finding `#39`; no cell is blocked. `#39` is owner-routed to 16-26 and is not fixed here: the AX5 Favorites native Search drawer is a blank capsule missing its magnifier and placeholder, while the title and gallery metadata remain complete and the tail remains reachable. The #39 before image is `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-top.png`, with full AX5 evidence including `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-ax5-8-first-row-end.png` and the matching bottom/UI captures. The `Favorites #8` `.large` reference is `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-large-8-top.png` / `iphone-portrait-large-8-bottom.png`; the `Watched #5` `.large` reference is `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/iphone-portrait-large-5-settled-top.png` / `iphone-portrait-large-5-settled-bottom.png`. Unsettled transition captures are excluded from the verdicts; Watched passes are limited to the visible NotFound/Retry error state.

The session-end restoration is evidenced by `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/inventory-restored-20260917.json`, `walk-restored.txt`, and `login-restored.txt`: all four devices are Shutdown. WALK was light/large with Increase Contrast, VoiceOver, Reduce Motion, Reduce Transparency, Bold Text, Button Shapes, and Grayscale read back at 0/disabled; LOGIN was dark/large with Increase Contrast disabled and all corresponding flags at 0. No account mutation was performed. The Voice Control preference was absent, matching baseline; this does not claim that the feature is unavailable.

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

The Disposition cells now carry the owner's recorded dispositions (D13-1/2/3 on 2026-09-09, D13-4 on
2026-09-11, D13-5 accepted on 2026-09-09). The iPhone, iPad and "After fix batch 1" columns are
historical observations kept as evidence; the "After fix batch 1" column in particular is superseded
by § D-13 named edge cases and the later `### Re-verification batches` records.

| D-13 item | iPhone observation | iPad observation | After fix batch 1 | Disposition |
|---|---|---|---|---|
| 1. Detail stats-strip abbreviation | Reproduced as finding #14 in portrait XXL/AX3/AX5 and landscape AX3/AX5; labels abbreviate first, then values disappear and stars clip. | All six live-Detail cells are blocked because `IPAD_LOGIN=none`; the iPad modal layout was not inferred. | Re-verified: labels and values both survive at every re-walked iPhone cell. Full text in § D-13 named edge cases, `Observed (after, batch 1)`. | fixed (owner 2026-09-09, based on recorded passing iPhone and iPad checks) |
| 2. Long-tag right-edge clip | Reproduced as finding #15 at portrait AX3/AX5; the same tags remain complete in landscape. | All six live-Detail cells are blocked because `IPAD_LOGIN=none`; the regular-width tag cloud was not inferred. | Re-verified: tags wrap inside their chips and none is cut. Full text in § D-13 named edge cases. | fixed (owner 2026-09-09, based on recorded passing iPhone and iPad checks) |
| 3. Reader total-page counter wrap | The prediction did not reproduce: finding #22 shows the counter vanishing at portrait AX3/AX5 instead of wrapping; landscape remains complete. | All six control-panel cells are blocked because `IPAD_LOGIN=none`; the regular-width panel was not inferred. | Not touched by fix batch 1 and not re-walked; finding #22 stays `open`. | fixed (owner 2026-09-09, based on the recorded native-toolbar checks on iPhone and iPad) |
| 4. Favorites trailing-glyph clip | The glyphs do not clip. The adjacent numeric page count is what disappears, tracked by finding #6. | All six Favorites cells are blocked because `IPAD_LOGIN=none`; no glyph verdict was inferred. | Re-verified for the paired value: the page count keeps its number and the glyphs are still never cut. Full text in § D-13 named edge cases. | fixed (owner 2026-09-11, based on the recorded iPhone #6 re-verification and the 2026-09-09 sampled iPad populated Favorites AX3/AX5 checks) |
| 5. Hero-carousel title truncation | Reproduced as finding #1 from XXL/AX3/AX5 portrait and AX3/AX5 landscape; AX5 portrait also overlaps, tracked separately by #2. | Reproduced as finding #1 in all six cells, including landscape XXL. | Partly fixed, still open: the title survives at iPhone portrait AX5 and across the iPad, but still ellipsises at iPhone portrait XXL/AX3, iPad portrait AX3 and all three iPhone landscape cells. Full text in § D-13 named edge cases. | accepted (owner 2026-09-09: keep the card height limit; long titles may truncate with an ellipsis) |

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

**Round-1 re-verify (fix batch 1).** All five sites are gone: a live grep at the re-verified HEAD
returns **0**. Each removal was paired with a `.large` parity capture (§ Evidence, `d15-after/`):
the two gallery-list rows, the Comments view and the Detail header are pixel-identical to their
banked baselines, and the Detail comment cells changed only for a card that carries a vote score —
recorded as finding #35 for the owner to accept or reject. D-15's second half therefore holds on
three of the four surfaces and is an explicit owner decision on the fourth. The
`no_minimum_scale_factor` rule's precondition (live count 0) is met.

### Blocked rows

Each entry below covers all six orientation/size cells for the named device and screen unless
stated otherwise; together they enumerate every `blocked:` or `n/a:` Matrix row, plus the one
blocked D-04 row.

| Device / screen | Cells | Status | Reason |
|---|---|---|---|
| iPhone #21 Tag Detail | portrait + landscape × XXL/AX3/AX5 | **unblocked, walked (batch 8)** | The English-description gate was opened by switching the session language to a translated locale and enabling the Tags Extension; all six cells pass. Both settings were restored. |
| iPhone #22 NewDawn | portrait + landscape × XXL/AX3/AX5 | blocked | The gain that raises the greeting is once per UTC day and account-wide, and it was already consumed for the current UTC day. Batch 8 enabled the greeting toggle and exercised five fetch opportunities against a live session; the server reported no gain and the sheet never presented. The toggle was restored to off. |
| iPhone #27 Live Text overlay | portrait + landscape × XXL/AX3/AX5 | n/a | It draws no app-visible text; the visible selection/translation UI is system-owned. |
| iPhone #30 Login | portrait + landscape × XXL/AX3/AX5 | **unblocked, walked (batch 8)** | Walked on a dedicated logged-out iPhone Air simulator created for the batch, so neither owner simulator was signed out; all six cells pass. The toast and the error sheet stay unwalked — both need a submitted login attempt, and no credential was ever entered. |
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
| iPad #21 Tag Detail | portrait + landscape × XXL/AX3/AX5 | **unblocked, walked (batch 8)** | Both barriers are gone: the owner's iPad session provides live Detail, and the same language/Tags-Extension change opens the description gate. All six cells pass; both settings were restored. |
| iPad #22 NewDawn | portrait + landscape × XXL/AX3/AX5 | blocked | The daily gain is account-wide, and batch 8 established on the iPhone that it was already consumed for the current UTC day, so the iPad cannot present a greeting the iPhone could not. The iPad toggle was left at its recorded value. |
| iPad #23 Detail download confirmation | portrait + landscape × XXL/AX3/AX5 | blocked | The live Detail route is unavailable; the preserved download was untouched. |
| iPad #24 Reading | portrait + landscape × XXL/AX3/AX5 | blocked | Live Reading requires the missing iPad session; no saved download was opened or changed. |
| iPad #25 Reading control panel | portrait + landscape × XXL/AX3/AX5 | blocked | Its regular-width layout requires unavailable live Reading. |
| iPad #26 Reading Setting sheet | portrait + landscape × XXL/AX3/AX5 | blocked | The Group-B entry point is the unavailable live Reading control panel, though the Setting-root version is covered as #34. |
| iPad #27 Live Text overlay | portrait + landscape × XXL/AX3/AX5 | blocked | Its entry point is the unavailable live Reading control panel. |
| iPad #38 EhSetting | portrait + landscape × XXL/AX3/AX5 | blocked | Native EhSetting sections require a logged-in account and `IPAD_LOGIN=none`. |
| D-04 progress spinner (`DownloadsView+Subviews.swift:145`) | #11/#12 active-transfer state | blocked | Neither simulator had an active transfer, and starting or altering a user-owned download solely for evidence was forbidden. |

The iPad no-session rows were an explicit owner gap, and the owner closed it: a session was created
manually on `IPAD_UDID` on 2026-09-03 (`IPAD_LOGIN=present`), so those rows are no longer a coverage
gap and are walked by the following re-verification batch. The rows that remain blocked for other
reasons (the D-04 progress spinner, which needs an active transfer) are unaffected.

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

### Re-verification batches

One entry per fix batch re-walked after the owner's D-01 amendment 2. Each entry records the
commits it covers, the build actually installed, and exactly which cells were re-walked, so a
later reader can tell a re-verified cell from one that was merely inherited.

#### Fix batch 1 — round 1, 2026-09-03

**Commits covered (16).** The branch was rewritten after these were authored, so both the hash
they were built at and the hash they carry now are recorded; every pair is tree-identical and
every right-hand hash is an ancestor of the branch tip.

| Built at (old) | Now (after rewrite) | Subject |
|---|---|---|
| `f251e4d6` | `c999e286` | feat(16): add AdaptiveStack reflow component |
| `d5fb868b` | `b598c933` | fix(16): reflow gallery list row at AX sizes |
| `a0e7ebb2` | `5e9f9cdb` | fix(16): step hero and history card sizes by type |
| `9f5b431d` | `37b56570` | fix(16): reflow detail comment cards at AX sizes |
| `bea27ba8` | `1c14a1cf` | fix(16): reflow archive cards at AX sizes |
| `208cf2ae` | `d3aec099` | fix(16): reflow ranking rows at AX sizes |
| `23f4d0fb` | `1050c21d` | fix(16): stack detail stats strip at AX sizes |
| `231e68f8` | `7839db1f` | fix(16): stack comment meta lines at AX sizes |
| `982074b6` | `9b1419a4` | fix(16): stack torrent meta at AX sizes |
| `0e1a2834` | `c6775b18` | fix(16): lift detail header caps, drop last shrink |
| `7353a288` | `953a67b6` | fix(16): wrap long tags inside their chips |
| `bae824c6` | `0a9f7dad` | fix(16): lift gallery info value caps at AX sizes |
| `5c226548` | `6df974e9` | fix(16): wrap activity-log category chip |
| `3dc7285f` | `aa3e18e1` | fix(16): let activity-log chip match its timestamp |
| `1d781ea4` | `03ec0db6` | fix(16): lift quick search caps at AX sizes |
| `92e899b8` | `2003c4f6` | fix(16): give toast subtitle a line budget |

Fix batch E (`5996d145`, `1838f8b3`) is **not** part of this entry, so findings #26 and #28 were
not judged here.

**Builds installed.**

| Build | Commit | Devices | Used for |
|---|---|---|---|
| A | `2003c4f6` | iPhone | Screens #2–#10 (the 79 after-captures reused from the interrupted first pass). |
| B | `aa3e18e1` | iPhone, iPad | Everything else, both devices. |

The only difference between the two builds is one file:
`AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift`
(11 insertions, 6 deletions). That file renders screen #32 only, which build B re-walked, so the
reused #2–#10 captures are unaffected by the gap.

Both builds carry the personal bundle id. `plutil -extract CFBundleIdentifier raw <app>/Info.plist`
prints, for the batch build, the parent build and the iPad build:

```
app.ehpanda.personal
```

Every install was `xcrun simctl install` over the existing app (install-over; nothing was
uninstalled or erased), and after installing, Favorites was opened on the iPhone and still listed
its content, confirming the session survived. No credential was ever entered (D-09).

**Protocol deviation, recorded.** The first attempt at build B omitted the
`BUNDLE_ID_SUFFIX=.personal` command-line override — a git worktree does not carry the untracked
`Config/LocalSigning.xcconfig` that supplies it in the main checkout — so it produced
`app.ehpanda`, and because the install was chained into the same command it installed over the
non-target `app.ehpanda` bundle on the iPhone before the check could stop it. `simctl install`
preserves the data container, nothing was erased, and `app.ehpanda` is not the sweep target. The
build was redone with the override, verified as `app.ehpanda.personal`, and re-installed; the iPad
build carried the override from the start. **Worktree builds must pass
`BUNDLE_ID_SUFFIX=.personal` explicitly, and the `plutil` check must run before any install.**

**Screens re-walked, iPhone** (portrait and landscape × XXL / AX3 / AX5 unless noted):

| Screens | Orientations | Before-capture source |
|---|---|---|
| #2–#10 | portrait (reused from build A) | § Evidence round-1 sweep captures under `sweep/` |
| #2, #3, #5, #8, #9 | landscape | `sweep/` |
| #14, #16, #18, #19, #20, #32, #40, #42 | portrait + landscape | `sweep/` |

**Screens re-walked, iPad:** #2, #3, #7 and #9, portrait and landscape at all three sizes, against
the same `sweep/` before-captures. The login-gated iPad rows stay `blocked`: `IPAD_LOGIN=none` and
no credential was entered.

**Not re-walked in this batch** (so their cells keep their round-1 status): iPhone landscape #4,
#6, #7 and #10; #12 Downloads Inspector; #17 Detail Search; #21–#31 and #33–#39 and #41; the iPad
cells of findings #25 and #31.

**D-15 parity.** All five `minimumScaleFactor` sites are removed by this batch and a live grep now
returns 0. Parity was captured at `content_size large` on both the batch parent (`96f11614`,
built in a second worktree) and the batch build, for each surface that hosted one — the gallery
list row, the Detail header, the Detail comment cells and the Comments view — plus a screen-level
`.large` sweep of every re-walked screen on both devices. Everything matched except the Detail
comment cells, raised as finding #35.

**Outcome.**

- `re-verified`: #2, #3, #5, #6, #8, #9, #10, #13, #14, #15, #16, #17, #18, #19, #25, #30, #32.
- still `open`: #1 (survives on iPad and at iPhone portrait AX5, still ellipsised elsewhere, and
  now also in all three iPhone landscape cells), #20 (portrait fixed, landscape worse), #21
  (AX5 portrait fixed, AX3 portrait unchanged, XXL portrait regressed from a round-1 `pass`),
  #31 (XXL and landscape fixed, portrait AX3/AX5 unchanged).
- new: **#34** (section heading breaks mid-word beside its trailing button at AX5 portrait;
  primary file `AppPackage/Sources/AppComponents/SubSection.swift`) and **#35** (the D-15 parity
  change in the Detail comment card at the default size).
- The category-badge clip anticipated for the Detail header did not reproduce: checked on a
  nine-character category at AX3 and AX5 portrait, the badge reads in full.
- Spacing and padding quality were deliberately **not** judged: the owner's reflow quality bar
  (16-CONTEXT.md, 2026-09-03) exempts batches A–E and schedules a separate polish pass.

**Evidence.** After-captures are under `$HOME/Library/Caches/ehpanda-phase16/reverify/batch1/`
and the `.large` parity captures under `.../d15-after/batch1/`, with the parent-build comparison
set under `.../d15-before/batch1/` and the four banked baselines under `.../d15-baseline/`. A
`pairs.tsv` in the re-verify directory lists every judged after-image with its before image and
verdict: 317 rows — 284 `pass`, 32 `open`, 1 `parity`. No image is tracked by git (D-32).

**Simulator state restored** after the walk and read back: iPhone `medium` / `dark` /
`disabled` / portrait 420×912; iPad `large` / `light` / `disabled` / portrait 834×1210.

#### Fix batch 2 — round II, 2026-09-03

The owner's round-I review redirected six of the batch-1 fixes and asked for four more; this
entry covers the twelve commits that answer it, re-walked against the batch-1 build.

**Commits covered (12), `68497009..803756c3`.**

| Commit | Subject |
|---|---|
| `68497009` | refactor(16): make FlowLayout a public component |
| `6942793b` | fix(16): wrap torrent counters onto more lines |
| `9c1c0a50` | fix(16): let the archives sheet scroll as one |
| `96576d6c` | fix(16): scale category badge with its text |
| `ed5ed385` | fix(16): give the list row room and a scaled cover |
| `a6a0dd61` | fix(16): stack the detail cover above its title |
| `ff134a40` | fix(16): stack a tag row above its children |
| `603a1bb6` | fix(16): cap hero card at half the viewport |
| `dcb32539` | fix(16): keep hero cover and title side by side |
| `64daeda7` | fix(16): stack SubSection heading at AX sizes |
| `4e6ece35` | fix(16): align search keyword cell leading |
| `803756c3` | fix(16): drop activity-log chip to its own line |

**Build installed.** One build, at `803756c3`, marketing version 3.0.0 (158), built in the
re-verification worktree with `BUNDLE_ID_SUFFIX=.personal` on the command line as the batch-1
deviation requires. `plutil -extract CFBundleIdentifier raw <app>/Info.plist` printed:

```
app.ehpanda.personal
```

The check ran before either install. Both installs were `xcrun simctl install` over the existing
app (install-over; nothing uninstalled, nothing erased). Favorites was opened on the iPhone after
installing and still listed its content, confirming the session survived. No credential was ever
entered (D-09); the iPad remains `IPAD_LOGIN=none` and its login-gated rows stay `blocked`.

**Before-captures.** Every before image is the round-I fix build (`aa3e18e1`) rendering, taken
from `$HOME/Library/Caches/ehpanda-phase16/reverify/batch1/`; the `.large` parity befores come
from `.../d15-after/batch1/`. **`aa3e18e1` was not rebuilt** — batch 1 had already captured every
cell this batch re-walks, so no second worktree was created. Each reused before image was opened
and its page state confirmed to match the after image before the pair was written.

**Screens re-walked, iPhone** (portrait and landscape × XXL / AX3 / AX5, top + mid + bottom where
the screen scrolls): #2 Home root, #3 Frontpage list, #8 Favorites list, #9 Search root, #14
Gallery Detail, #19 Archives, #20 Torrents, #32 Activity Logs.

**Screens re-walked, iPad** (portrait and landscape × XXL / AX3 / AX5): #2, #3, #9.

**Not re-walked in this batch,** so their cells keep the status they already carry: every screen
outside that list, and the iPad cells of #8, #14, #19, #20 and #32.

**Hero card measurement (#1).** Card height was read from the accessibility frame; the scroll
container height is the `List`/`ScrollView` frame where it could be read, and the screen height
(marked *scr*) where it could not.

| Device / orientation | Size | Card (pt) | Viewport (pt) | Ratio |
|---|---|---|---|---|
| iPhone portrait | XXL | 336 × 243 | 708 | 34% |
| iPhone portrait | AX3 | 336 × 354 | 708 | 50% (cap binds) |
| iPhone portrait | AX5 | 336 × 354 | 708 | 50% (cap binds) |
| iPhone landscape | XXL | 621 × 139 | not read | — |
| iPhone landscape | AX3 | 621 × 150 | not read | — |
| iPhone landscape | AX5 | 621 × 180 | not read | — |
| iPad portrait | XXL | 668 × 243 | 1210 *scr* | 20% |
| iPad portrait | AX3 | 668 × 388 | 1210 *scr* | 32% |
| iPad portrait | AX5 | 668 × 494 | 1210 *scr* | 41% (cap does not bind) |
| iPad landscape | XXL | 968 × 243 | 728 | 33% |
| iPad landscape | AX3 | 968 × 364 | 728 | 50% (cap binds) |
| iPad landscape | AX5 | 968 × 364 | 728 | 50% (cap binds) |

At `.large` the card is the designed 336 × 190 pt (iPhone) and 668 × 190 pt (iPad).

**Outcome.**

- `re-verified`: #1, #5, #6, #8, #9, #10, #13, #15, #20, #25, #32, #34.
- still `open`: **#21**, and it is a **regression** — above `.large` the torrent counter row is a
  `FlowLayout` of four `Label` pairs and every pair is laid out at its icon's size alone
  (44 × 44 pt at AX5), so none of the four values renders at all; only the glyphs are drawn,
  cascading diagonally. Round I still drew every value, with only the file size ellipsised. The
  values remain in the accessibility tree, which is why an outline read looks correct while the
  screen does not. The `.large` compact row is untouched, so the defect is confined to the flow
  branch.
- **#35 is inherited, not re-judged**: this batch did not touch `DetailView+CommentCells.swift`
  and the `.large` comment strip is identical to the round-I build. It stays `open` awaiting the
  owner's disposition.
- Three items are raised for the owner rather than judged: the five rating symbols overflowing
  their slot at iPhone portrait AX5 (the card renders 381.7 pt wide inside a 336 pt slot, so it
  overlaps each peeking neighbour by about 23 pt; the symbols themselves are not clipped), the
  Detail header cover reading as a thumbnail once it stacks above the title, and the Archives
  sheet's now-visible scroll indicator.
- Spacing and padding quality were again **not** judged, per the owner's reflow quality bar.

**D-15 parity.** Fourteen `.large` screens were captured on both devices and compared against
the round-I set; all fourteen matched, and each is a `parity` row in `pairs.tsv`. Two apparent
differences were pixel-measured and disproved: the Archives cards are 148 × 175 pt at x 57 and
x 215 in both builds, and the list-row cover frame is 87 × 120 pt in both (the visible image
differs only by `.scaledToFit()` letterboxing, and the frame's left edge back-computes to 30.0 pt
in both, so the −10 pt leading bleed survives at the default size).

**Protocol deviations, recorded.**

1. **Tool versions.** `sim-use` 0.14.0 and `agent-device` 0.20.10 were installed, not the 0.13.0
   and 0.20.8 recorded in § Tooling. Rotation still went through `agent-device orientation`.
2. **Scrolling by explicit coordinates.** `sim-use gesture scroll-up` landed on the home indicator
   and backgrounded the app twice, so every scroll used
   `sim-use swipe --coordinate-space ui --from CX,YHI --to CX,YLO` inside a 35%–68% band, with an
   `App: EhPanda` assertion before and after every capture.
3. **iPhone simulator shutdown.** The iPhone shut down unexpectedly mid-walk. It was rebooted with
   `xcrun simctl boot` (never erased), the app relaunched, and the login confirmed intact via
   Favorites; content size and appearance had persisted.
4. **iPad windowed mode.** A swipe grabbed the window and the iPad entered iPadOS 26 windowed mode
   (1065 × 668). It was restored to full screen by tapping the green traffic-light control.
5. **Sheet re-entry.** Up-swipes at the top of the Archives and Torrents sheets dismiss them, so
   both sheets were re-opened from Detail's More menu, and their landscape cells were reached by
   navigating in portrait and then rotating.
6. **Content drift.** Live gallery content has refreshed since batch 1, so byte-identical content
   in a before/after pair is impossible. Pairs match screen, position, size, orientation and page
   state, and the verdict is on the layout property, not the artwork.
7. **Eight unpaired captures.** Eight after-captures have no batch-1 counterpart of the same state
   and are therefore **not** in `pairs.tsv` (no after-only rows): `iphone-landscape-{XXL,AX3,AX5}`
   `-3-mid3`, `iphone-portrait-{AX3,AX5}-14-tagrow`, `iphone-portrait-{AX3,AX5}-14-tagcloud` and
   `iphone-portrait-AX5-9-mid3`. They are supplementary evidence only.

**Evidence.** After-captures are under `$HOME/Library/Caches/ehpanda-phase16/reverify/batch2/`
(152 images) and the `.large` parity captures under `.../d15-after/batch2/` (14 images). The
`pairs.tsv` in the re-verify directory lists every judged after-image with its before image and
verdict: 158 rows — 138 `pass`, 6 `open` (all six the iPhone #20 counter-row cells), 14 `parity`.
No image is tracked by git (D-32).

**Simulator state restored** after the walk and read back: iPhone `medium` / `dark` /
`disabled` / portrait 420×912; iPad `large` / `light` / `disabled` / portrait 834×1210. The app
is left installed on both.

#### Fix batch 2b — round II follow-up, 2026-09-03

Four commits answer the three items round II raised for the owner plus the one round-II
regression. Only the cells those four commits can reach were re-walked, on the iPhone only; no
iPad cell is touched by this entry.

**Commits covered (4), `a731d905..549c255d`.**

| Commit | Subject | Screens it can reach |
|---|---|---|
| `a731d905` | fix(16): flow torrent counters as plain stacks | #20 |
| `eb38acc4` | fix(16): keep dropped hero rating inside the card | #2 |
| `a92e5465` | fix(16): hide the archives column scroll indicator | #19 |
| `549c255d` | fix(16): align wrapped tag chips leading | #14 (and every other tag-chip host) |

**Build installed.** One build, at `0535d30c` — the docs commit whose tree is `549c255d`'s plus
this file's batch-2 entry, so the build is `549c255d`'s code — marketing version 3.0.0 (158),
built in the re-verification worktree with `BUNDLE_ID_SUFFIX=.personal` on the command line as
the batch-1 deviation requires. `plutil -extract CFBundleIdentifier raw <app>/Info.plist`
printed:

```
app.ehpanda.personal
```

The check ran before the install. The install was `xcrun simctl install` over the existing app
(install-over; nothing uninstalled, nothing erased). Favorites was opened afterwards and still
listed its content, confirming the session survived. No credential was ever entered (D-09).

**Before-captures.** Every before image is the round-II fix build (`803756c3`) rendering, taken
from `$HOME/Library/Caches/ehpanda-phase16/reverify/batch2/`; the `.large` parity befores come
from `.../d15-after/batch2/`. **`803756c3` was not rebuilt** — batch 2 had already captured every
cell this batch re-walks, including the two supplementary tag-row shots, so no second worktree
was created. Each reused before image was opened and its page state confirmed to match the after
image before the pair was written.

**Cells re-walked, iPhone.**

| Screen | Cells |
|---|---|
| #2 Home root | portrait and landscape × XXL / AX3 / AX5 (hero card only; the sections below it are unchanged by these commits and were not re-judged) |
| #14 Gallery Detail | portrait AX3 and AX5, tag rows |
| #19 Archives | portrait and landscape × AX3 / AX5 (XXL keeps the pinned-footer grid, which `a92e5465` does not touch) |
| #20 Torrents | portrait and landscape × XXL / AX3 / AX5 |

**Not re-walked in this batch,** so their cells keep the status they already carry: every screen
outside that list, every iPad cell, and #19 at XXL in both orientations.

**Hero card measurement (#1).** Rendered bounds are the card's own drawn extent measured in the
screenshot, not the accessibility frame — the round-II residue was invisible to the frame, which
reported the slot width while the symbols drew outside it. The rating row is the extent of the
five symbols' own pixels within the rating row's vertical band.

| Device / orientation | Size | Card slot (pt) | Card rendered (pt) | Rating row (pt) |
|---|---|---|---|---|
| iPhone portrait | XXL | 42.0..377.7 | 42.0..377.7 | 196.0..338.0, in the text column |
| iPhone portrait | AX3 | 42.0..377.7 | 42.0..377.7 | 64.3..245.0, own row |
| iPhone portrait | AX5 | 42.0..377.7 | 42.0..377.7 | 66.0..314.3, own row |
| iPhone landscape | XXL | 145.7..766.3 | 145.7..766.3 | in the text column |
| iPhone landscape | AX3 | 145.7..766.3 | 145.7..766.3 | 168.7..349.0, own row |
| iPhone landscape | AX5 | 145.7..766.3 | 145.7..766.3 | 169.7..418.0, own row |

Round II measured the same portrait AX5 card at 19.3..400.7 pt rendered (381.7 pt in a 336 pt
slot) with its rating row at 44.7..400.7 pt — 23.0 pt past the card's trailing edge and 2.7 pt
into the neighbouring card's slot, which begins at 398.0 pt. The card's content box is
62.0..357.7 pt after its 20 pt inner padding, and the rating row now sits inside it at both ends;
the peek gutters measure the designed 20.0 pt on both sides. Card heights are unchanged in
portrait (243 / 354 / 354 pt) and 15 pt shorter at landscape AX5 (180 → 165 pt), because the
symbols no longer take the body size.

**Torrent counter measurement (#21).** All four values render in every sampled cell: one line at
XXL portrait and landscape and at AX3 and AX5 landscape; two lines at AX3 portrait (6 / 1 / 2,526
then 501.8 MiB); three at AX5 portrait (6 and 1, then 2,526, then 501.8 MiB). No ellipsis, no
value cut mid-glyph, no clipped glyph. Round II drew none of the four values above `.large`.

**Scroll-indicator measurement (#19).** A capture taken with **no settle delay** right after the
swipe is the only way to see an indicator, which fades about a second after the gesture ends. In
all six archives captures the longest bright run in the 2–14 pt band inside the trailing edge is
**0.0 pt**. The technique was controlled on a surface that does draw one: Setting › General at
AX5 portrait, captured the same way, measures a **286.3 pt** run at x 414.7 pt. So the absence is
a measurement, not a missed frame. At AX3 portrait the whole column fits and the funds row and
button need no scrolling; in the other three cells the column still scrolls to both.

**Outcome.**

- `re-verified`: **#1** (the round-II residue is closed — the card's rendered bounds equal its
  slot at every sampled cell, and both peek gutters are back), **#15** (a chip that wraps inside
  itself is leading-aligned, checked on the same chips round II showed centred), **#21** (the
  round-II regression is gone and the round-I truncation with it — all four counter values render
  in full at every size in both orientations).
- The Archives scroll indicator round II raised for the owner is gone; the cell keeps its
  existing status, since the indicator was never an information-loss finding.
- still `open`: **#35** only, inherited unchanged — this batch did not touch
  `DetailView+CommentCells.swift` and the `.large` comment strip is identical to round II. It
  still awaits the owner's disposition.
- The remaining round-II item for the owner — the Detail header cover reading as a thumbnail once
  it stacks above the title — is **not** addressed by these four commits and was not re-judged.
- Spacing and padding quality were again **not** judged, per the owner's reflow quality bar.

**D-15 parity.** Six `.large` screens were captured on the iPhone and compared against the
round-II set; all six matched, and each is a `parity` row in `pairs.tsv`. The hero card's rating
row is pixel-identical (x 195.7..301.7 pt, y 289.3..306.7 pt, against 195.7..302.0 pt and the
same y in round II), so the `.caption2` step does not engage at the default size. The Detail tag
rows hold only single-line chips at `.large`, so the leading alignment has nothing to change. The
Archives sheet keeps its two-column grid and pinned footer at `.large`, so it never enters the
scrolling branch. The Torrents compact row is unchanged, three counters leading and the file size
trailing-anchored.

**Protocol deviations, recorded.**

1. **Tool versions.** `sim-use` 0.14.0 and `agent-device` 0.20.10, as in batch 2, not the 0.13.0
   and 0.20.8 recorded in § Tooling. Rotation still went through `agent-device orientation`, and
   that command needed an explicit `--session iphone`: a session already existed for this device
   under that name, and without the flag every `agent-device` call failed `SESSION_NOT_FOUND`
   while `agent-device session list` reported no sessions at all.
2. **Scrolling by explicit coordinates.** As in batch 2, every scroll used
   `sim-use swipe --coordinate-space ui --from CX,YHI --to CX,YLO` inside a 35 %–68 % band, with
   an `App: EhPanda` assertion around every capture.
3. **Sheet re-entry.** Up-swipes at the top of the Archives and Torrents sheets dismiss them, so
   both sheets were re-opened from Detail's More menu, and their landscape cells were reached by
   navigating in portrait and then rotating.
4. **Two galleries.** #19, #20 and the `.large` #14 parity were walked on the same gallery batch 2
   used for them; the tag rows were walked on the gallery batch 2 took its two supplementary
   tag-row shots from, so each tag pair is the same gallery, the same tag section and the same
   chip as its before.
5. **Content drift.** Live gallery content has refreshed again since batch 2 — the torrent's seed
   count reads 6 where the `.large` before read 7, and the Home carousel and Frontpage show
   different artwork. Pairs match screen, position, size, orientation and page state, and the
   verdict is on the layout property, not the artwork or the value.
6. **Indicator timing.** The batch-2 before captures were taken after the scroll settled, so none
   of them shows an indicator either; they cannot serve as a positive before for that one
   property. The evidence for `a92e5465` is therefore the pair of measurements described above —
   0.0 pt on the archives column against 286.3 pt on a control surface under the identical
   capture technique — rather than a before/after difference in the same image pair.
7. **Five unpaired captures.** Five after-captures have no batch-2 counterpart of the same state
   and are therefore **not** in `pairs.tsv` (no after-only rows):
   `iphone-landscape-AX5-19-bottom2`, `iphone-portrait-AX5-14-tagcloud2`, and the three
   `control-*-indicator` shots that establish the indicator-capture technique. They are
   supplementary evidence only.

**Evidence.** After-captures are under `$HOME/Library/Caches/ehpanda-phase16/reverify/batch2b/`
(30 images) and the `.large` parity captures under `.../d15-after/batch2b/` (6 images). The
`pairs.tsv` in the re-verify directory lists every judged after-image with its before image and
verdict: 31 rows — 25 `pass`, 0 `open`, 6 `parity`. No image is tracked by git (D-32).

**Simulator state restored** after the walk and read back: iPhone `medium` / `dark` / `disabled`
/ portrait 420×912. The iPad was not touched in this batch. The app is left installed.

#### Fix batch 3 — round II batch F, 2026-09-03

Batch F plus the round-II standalones: the thumbnail layout and the category vocabulary, the
Excluded Languages grid, the Account cookie rows, the reader control bar, the pushed screens'
navigation titles, and the Login form. Ten commits, re-walked against the batch-2b build.

**Commits covered (10), `32177686..30e42c84`.**

| Commit | Subject | Findings it can reach |
|---|---|---|
| `32177686` | fix(16): collapse excluded languages grid | #27 |
| `f9286303` | fix(16): stack account cookie rows at AX sizes | #24 |
| `15f9b09f` | fix(16): reflow the reader control bar | #22 |
| `27a360b1` | fix(16): inline titles at accessibility sizes | #7, #4 |
| `0a965af3` | fix(16): keep the login form clear of the title | #33 |
| `4fbd0ae9` | fix(16): inline search results title at AX sizes | #7, #4 |
| `0dde25eb` | fix(16): scale thumbnail columns with the text | #12 |
| `72234cbc` | fix(16): give the thumbnail cell line budgets | #12 |
| `7645e10c` | fix(16): wrap category names in badge and grid | #12, #29 |
| `30e42c84` | fix(16): let the header badge follow its own policy | #12 |

**Build installed.** One build, at `30e42c84`, marketing version 3.0.0 (158), built in the
re-verification worktree with `BUNDLE_ID_SUFFIX=.personal` on the command line as the batch-1
deviation requires. `plutil -extract CFBundleIdentifier raw <app>/Info.plist` printed:

```
app.ehpanda.personal
```

The check ran before either install. Both installs were `xcrun simctl install` over the existing
app (install-over; nothing uninstalled, nothing erased). Favorites was opened on the iPhone after
installing and still listed its content, confirming the session survived. No credential was ever
entered (D-09); the iPad remains `IPAD_LOGIN=none` and its login-gated rows stay `blocked`.

**Before-captures.** Three sources, one per kind of cell.

| Cell kind | Before source |
|---|---|
| #25, #29, #30, #38, #39, #10 and the pushed-screen title/capsule cells (#3, #4, #5, #6, #7, #32) | the round-1 `sweep/` captures. Each was opened and its state confirmed before the pair was written; for the title/capsule cells the judged property is stated in `pairs.tsv`, because the list rows below them changed in round II. |
| #14 header badge | the round-II fix build's own capture, `reverify/batch2/iphone-portrait-AX5-14-top.png` — batch 2b did not touch the header. |
| every Thumbnail-mode cell, on both devices | captured live, before installing, on the build the simulators already carried. |

**No second worktree was built.** The batch-2b build that both simulators carried is `0535d30c`,
whose tree differs from this batch's parent `9cbdacfa` only in `.planning/` — `git diff 0535d30c
9cbdacfa -- AppPackage App ShareExtension EhPanda.xcodeproj` is empty — so the installed binary
*was* `9cbdacfa`'s code, and the Thumbnail-mode befores were taken on it directly rather than
rebuilding it in a second worktree. The iPad still carried the batch-2 build (`803756c3`, installed
13:49); over the sources that render this batch's iPad cells — `AppComponents/CategoryView.swift`,
`SettingFeature/Login/LoginView.swift`, `GalleryListComponents/` and `FiltersFeature/` —
`803756c3` and `9cbdacfa` are also identical, so the iPad befores are equally the parent's
rendering.

**`.large` parity befores** come from `d15-after/batch1/` (#4, #5, #6, #7, #10), `d15-after/batch2/`
(#3, #32), `d15-after/batch2b/` (#14) where a `.large` capture of that screen already existed, and
were captured live in `d15-before/batch3/` for the seven screens that had none (#25, #29, #38, #39,
the Thumbnail-mode #3 cell, iPad #30 and iPad #39).

**Cells re-walked, iPhone.**

| Screen | Cells |
|---|---|
| #3 Frontpage, Display Mode = Thumbnail | portrait XXL / AX3 / AX5 (top + mid) and landscape AX5 (top + mid), plus `.large`. Display Mode was set from Setting › Appearance › List › Display Mode and restored to Detail afterwards. |
| #3, #4, #5, #6, #7, #10, #32 | portrait AX3 and AX5, top, judged on the navigation title and the pull-to-reveal capsule only; #3 also at XXL |
| #14 Gallery Detail | portrait AX5, header (nine-character category) |
| #25 Reading control panel | portrait XXL / AX3 / AX5 and landscape AX5, panel shown |
| #29 Account | portrait and landscape × XXL / AX3 / AX5, screen top and the cookie block |
| #38 EhSetting Excluded Languages | portrait XXL / AX3 / AX5 and landscape AX5, section top and one scrolled position |
| #39 Filters sheet | portrait and landscape × XXL / AX3 / AX5 |

**Cells re-walked, iPad:** #39 Filters portrait and landscape × XXL / AX3 / AX5; #30 Login portrait
and landscape × AX3 / AX5; #3 Frontpage in Thumbnail mode, portrait AX5 (Display Mode restored to
Detail afterwards).

**Not re-walked in this batch,** so their cells keep the status they already carry: every screen
outside those lists; the iPhone landscape cells of #3–#7, #10 and #32; the iPad cells of #3, #4,
#7, #10 and #32 that finding #4 names; and #38 at XXL and AX3 in landscape.

**Thumbnail-grid measurement (#12).** Column count at the live call site, read from the cell frames
in the accessibility tree.

| Device / orientation | `.large` | XXL | AX3 | AX5 |
|---|---|---|---|---|
| iPhone portrait | 2 | 2 (182 / 183 pt cells) | 1 (380 pt) | 1 (380 pt) |
| iPhone landscape | — | — | — | 1 (744 pt), against 3 before |
| iPad portrait | 4 | — | — | 1 (794 pt), against 4 before |

The right-hand column is entirely on screen at every sampled size: the widest case is iPhone
portrait XXL, where the second column ends at x 400 pt of a 420 pt screen.

**Inline-title measurement (#7).** The inline bar title is drawn at the same size at AX3 and AX5 —
iOS does not scale it — so the question is only whether the string fits.

| Screen | Title | Inline slot at AX3 / AX5 | Result |
|---|---|---|---|
| #3 | Frontpage | 99 pt | complete |
| #4 | Popular | 74 pt | complete |
| #5 | Watched | 85 pt | complete |
| #6 | History | 70 pt | complete |
| #7 | Toplists - Yesterday | 188 pt | **ellipsised** — `Toplists - Yesterd…` |
| #10 | Artbook | 78 pt | complete |
| #32 | App Activity Logs | 168 pt | complete |

The same #7 title collapses to inline at the default size in 157 pt with every character drawn, so
the cut is a Dynamic Type loss and not a pre-existing one.

**Reader indicator measurement (#22).** Portrait: 96,76 95×34 pt at XXL, 147×53 pt at AX3, 186×67
pt at AX5, every glyph drawn; landscape AX5: 164,16 186×67 pt. Round 1 measured an ellipsis-only
capsule at AX3 and a two-point sliver rendering no glyph at AX5. At `.large` the bar is the designed
single row and every frame is identical between the builds — close 20,71 44×44, indicator 96,80
59×26, actions at 262 / 308 / 354 — measured on the same gallery in both.

**Cookie-value measurement (#24).** The thirty-two-character hash's field, and whether the value
reads whole:

| Cell | Field | Value |
|---|---|---|
| iPhone portrait XXL | 340 pt wide, 3 wrapped lines | complete (round 1: cut after 14 characters) |
| iPhone portrait AX3 | 340 pt wide | complete (round 1: `729fb…`) |
| iPhone portrait AX5 | 340 × 250 pt, 4 wrapped lines | complete (round 1: `729f…`) |
| iPhone landscape XXL | 712 × 96 pt | complete (already complete in round 1) |
| iPhone landscape AX3 | 712 × 64 pt | complete (round 1: cut after 16 characters) |
| iPhone landscape AX5 | 712 pt wide | complete (round 1: cut after 12 characters) |

The seven-digit member id and the ExHentai token read in full in every one of those cells too. No
value is recorded anywhere in this repository.

**Category-grid measurement (#29).** Columns per cell, all ten names complete in every one:

| Device / orientation | `.large` | XXL | AX3 | AX5 |
|---|---|---|---|---|
| iPhone portrait | 3 | 3 | 1 | 1 |
| iPhone landscape | — | 5 | 3 | 2 |
| iPad portrait | 5 | 4 | 2 | 2 |
| iPad landscape | — | 4 | 2 | 2 |

**Outcome.**

- `re-verified`: **#12** (the thumbnail grid re-columns instead of squeezing; titles, stats, star
  rows and cover badges all complete on both devices, and the Detail header badge renders a
  nine-character category whole), **#22**, **#24**, **#27**, **#29**, **#33**.
- still `open`: **#7**, now narrowed to **#7 Toplists alone** — the blank title band is gone
  everywhere, but that screen's long title is ellipsised in the inline bar at AX3 and AX5 portrait.
  Every other pushed screen draws its name in full.
- still `open`: **#4**, but only outside this batch's scope. Every iPhone cell re-walked draws the
  capsule's magnifier and placeholder (or, on #10, the submitted query); the iPad occurrences and
  the iPhone landscape #32 occurrence were not re-walked here.
- **#35** is inherited unchanged: this batch did not touch `DetailView+CommentCells.swift`. It still
  awaits the owner's disposition.
- Spacing and padding quality were judged only where these commits set it deliberately (the
  thumbnail cell's 10 pt group spacing, the language block's 16 / 12 / 6 pt rhythm, the cookie
  pair's 8 pt gap); the owner's reflow quality bar still exempts the batch A–E surfaces.

**D-15 parity.** Nineteen `.large` comparisons, all matched, each a `parity` row in `pairs.tsv`.
Four were pinned by frame equality rather than by eye: the Filters grid (every name's frame
identical on both devices, e.g. iPhone Doujinshi 65,291 / Misc 83,406 and iPad Doujinshi 177,488 /
Misc 601,527), the Excluded Languages headers (x 153 / 226 / 317 in both builds), the reader control
bar (close 20,71 44×44, indicator 96,80 59×26, actions 262 / 308 / 354) and the iPad Login form
(Username 243,476, field 253,509 328×22, Password 243,556, field 253,588, button 391,664 52×60).
The Thumbnail-mode grid keeps its designed two columns on the phone and four on the iPad at
`.large`, with the title still capped at three lines and ellipsised there.

**Protocol deviations, recorded.**

1. **Tool versions.** `sim-use` 0.14.0 and `agent-device` 0.20.10, as in batches 2 and 2b, not the
   0.13.0 and 0.20.8 recorded in § Tooling. Rotation went through `agent-device orientation` with
   an explicit `--session iphone` / `--session ipad`.
2. **iPhone simulator shut down between batches.** It was found `Shutdown` at session start and
   rebooted with `xcrun simctl boot` (never erased); `content_size`, `appearance` and
   `increase_contrast` had persisted at their recorded baseline.
3. **Display Mode lives in Setting › Appearance,** not in a list's features menu as § Protocol's
   round-1 wording implies. Both devices were switched there and restored to `Detail` there, and the
   restored value was read back from the picker on each.
4. **Scrolling by explicit coordinates,** as in batches 2 and 2b: `sim-use swipe
   --coordinate-space ui` inside a 35 %–68 % band, with an `App: EhPanda` assertion around every
   capture.
5. **The app was backgrounded once** by a swipe that reached the home indicator while the Filters
   sheet was open on the iPhone; `sim-use ui` reported `App: SpringBoard`, the capture taken in that
   state was deleted, the app was relaunched with `xcrun simctl launch`, and the cell was re-walked
   from a fresh navigation. Nothing was erased and the session survived.
6. **The XCUITest runner behind `sim-use` died twice** (once after the install, once mid-walk),
   returning an empty accessibility tree. It was restarted by re-opening the `agent-device` session;
   no simulator state was touched.
7. **Content drift.** Live gallery content has refreshed again, so no before/after pair on a list
   screen shows the same artwork. Pairs match screen, position, size, orientation and page state,
   and the verdict is on the layout property. The one place this mattered — the `.large` reader
   parity, where the page count is part of the indicator's width — was re-captured on the same
   thirty-page gallery as its before.
8. **`#38` scroll positions are swipe-counted, not offset-matched.** EhSetting is a static form, so
   the section was reached by scrolling until the language rows appeared in the accessibility tree
   rather than by reproducing a byte-identical offset; the before images are the round-1 captures
   whose visible region is the same part of the section.
9. **One #27 before is a neighbour, not the header row.** Round 1 stepped the AX3-portrait #38
   scroll in threes and its captures skip the header row itself, so that cell's before is the
   capture immediately below it — rows of identical unlabelled circles, which is the same
   information loss the finding records.
10. **Nineteen unpaired captures.** These after-images have no counterpart of the same state and are
    therefore **not** in `pairs.tsv` (no after-only rows): the second scrolled position of the
    language section, `iphone-{portrait-XXL,portrait-AX3,portrait-AX5,landscape-AX5}-38-lang2`
    (four); the scrolled remainder of the category grid,
    `iphone-{portrait-AX3,portrait-AX5,landscape-AX3,landscape-AX5}-39-mid` (four) and
    `ipad-{portrait,landscape}-AX5-39-mid` (two); one extra scrolled landscape thumbnail shot,
    `iphone-landscape-AX5-3thumb-mid2`; four Account captures taken at an uncontrolled scroll offset
    before the cell was walked properly, `iphone-portrait-XXL-29-mid` and
    `iphone-landscape-{XXL,AX3,AX5}-29-mid`; `ipad-portrait-AX3-39-top`, because no round-1 capture
    of that cell shows the grid; `ipad-portrait-{AX3,AX5}-3-top`, supplementary evidence that the
    iPad Frontpage title is drawn at the accessibility sizes (the iPad was never part of finding
    #7); and `d15-after/batch3/large-7-collapsed`, which records that #7's title reads in full when
    the same bar collapses to inline at the default size. They are supplementary evidence only.

**Evidence.** After-captures are under `$HOME/Library/Caches/ehpanda-phase16/reverify/batch3/`, the
live befores under `.../reverify/batch3/before/` and `.../d15-before/batch3/`, and the `.large`
after set under `.../d15-after/batch3/`. The `pairs.tsv` in the re-verify directory lists every
judged after-image with its before image and verdict: 78 rows — 57 `pass`, 2 `open` (both the
iPhone #7 title cells), 19 `parity`. No image is tracked by git (D-32).

**Simulator state restored** after the walk and read back: iPhone `medium` / `dark` / `disabled` /
portrait 420×912, Display Mode `Detail`; iPad `large` / `light` / `disabled` / portrait 834×1210,
Display Mode `Detail`. The app is left installed on both.

#### Fix batch 4 — round-II corrections, 2026-09-03

Six commits closing the round-II directions batch 3 could not finish: the masonry's remaining
single-column cells, the category cell's square corners, the reader's upper panel, the Detail
header's glass action buttons, and the Detail stats strip's fixed-fraction columns. Re-walked
against the batch-3 build, plus the four iPad cells (#10, #32 portrait AX3/AX5) that batch 3 left
unconfirmed for finding #4.

**Commits covered (6), `cbab163b..391ce4ea`.**

| Commit | Subject | Findings it can reach |
|---|---|---|
| `cbab163b` | fix(16): keep two thumbnail columns at every size | #12 |
| `db5afd4e` | fix(16): scale the category cell's corner radius | #29 |
| `e30ddba0` | fix(16): keep the thumbnail rating inside its column | #12 |
| `89d02f52` | fix(16): keep the reader upper panel on one line | #22 |
| `919b90bb` | fix(16): grow header action glass with its symbol | #14 |
| `391ce4ea` | fix(16): keep the stats strip scrolling sideways | #14 |

**Build installed.** One build, at `391ce4ea`, marketing version 3.0.0 (158), built in a second
re-verification worktree (a second `.claude/worktrees/` checkout) with `BUNDLE_ID_SUFFIX=.personal`,
matching the batch-1 deviation. `plutil -extract CFBundleIdentifier raw <app>/Info.plist` printed
`app.ehpanda.personal` on both installs, checked before each one. Both installs were `xcrun simctl
install` over the existing app (install-over; nothing uninstalled, nothing erased). No credential
was entered (D-09); the iPad remains `IPAD_LOGIN=none` and its login-gated rows stay `blocked`.
The build worktree was torn down at the end of this session — its `16-SWEEP.md` was verified
byte-identical to this file's pre-batch-4 state before removal, so nothing written there was lost.

**Before-captures.** Two sources.

| Cell kind | Before source |
|---|---|
| #3, #4, #7, #10, #32 iPad portrait AX3/AX5 (finding #4 completion) | the round-1 `sweep/` captures, opened and confirmed before each pair was written. |
| every other cell (#12 Thumbnail-mode grid, #14 header + stats strip, #22 reader panel, #29 Filters sheet) | captured live, immediately before installing, on the batch-3 build (`30e42c84`) the simulators already carried. |

**`.large` parity befores** come from `d15-after/batch3/`, which already held a `.large` capture of
every screen this batch re-walked (#39, #14 header, #25, the Thumbnail-mode #3 cell on both
devices).

**Cells re-walked, iPhone.**

| Screen | Cells |
|---|---|
| #3 Frontpage, Display Mode = Thumbnail | portrait XXL / AX3 / AX5 (top + mid) and landscape AX5 (top + mid), plus `.large`. Display Mode was set from Setting › Appearance › List › Display Mode and restored to Detail afterwards. |
| #14 Gallery Detail | portrait XXL / AX3 / AX5 (header, action row, stats strip scrolled) and landscape AX5 (header, action row, stats strip scrolled) |
| #25 Reading control panel | portrait XXL / AX3 / AX5 and landscape AX5, panel shown |
| #39 Filters sheet | portrait and landscape × XXL / AX3 / AX5, walked top to bottom in scroll steps until every category name and every control beneath the grid had been captured |

**Cells re-walked, iPad:** #3 Frontpage in Thumbnail mode, portrait and landscape AX5 (Display Mode
restored to Detail afterwards); #39 Filters portrait and landscape × XXL / AX3 / AX5, walked top to
bottom the same way; #3, #4, #7, #10, #32 portrait AX3 and AX5, judged on the pull-to-reveal
capsule only, completing the iPad walk finding #4 left open after batch 3.

**Not re-walked in this batch,** so their cells keep the status they already carry: every screen
outside those lists; the iPhone landscape Thumbnail-mode cells at XXL/AX3 (only AX5 has ever been
sampled there); the iPad landscape cells of #3, #4, #7, #10 and #32 that finding #4 names, and
their iPad portrait XXL cells; #14 at iPhone landscape AX3; and the iPhone landscape #32 cell of
finding #4.

**Thumbnail-grid measurement (#12).** Column count at the live call site, read from the cell frames
in the accessibility tree and confirmed against the capture. Column *widths* are unchanged from
batch 3 (the fix is the floor, not the grid math); this batch's new numbers are only where the
floor previously let a size drop to one column.

| Device / orientation | XXL | AX3 | AX5 |
|---|---|---|---|
| iPhone portrait | 2 (unchanged) | 2, against 1 in batch 3 | 2, against 1 in batch 3 |
| iPhone landscape | not sampled | not sampled | 2, against 1 in batch 3 |
| iPad portrait | not sampled | not sampled | 2, against 1 in batch 3 |
| iPad landscape | not sampled | not sampled | 2, not sampled before |

In the iPhone portrait AX3/AX5 half-width column the five-star rating row now falls back to a
single star glyph plus its numeral rather than clipping; every wider column (iPhone portrait XXL,
every landscape and iPad column sampled) still draws the full five-symbol row. No cell's background
was seen crossing into its neighbour or off-screen in any sampled cell, on either device.

**Category-cell corner-radius measurement (#29).** The chip's rounded corner reads square at small
sizes and round at large ones by design; the question batch 3 raised was whether the radius itself
scales with the text or stays fixed while the chip grows around it. Measured on the iPhone portrait
capture (3x screenshot scale) by walking pixel rows down from a chip's top-left corner and reading
where the fill's left edge stops receding — the corner's inset at the very first row is the radius:

| Sample | Chip | Corner inset (first row) |
|---|---|---|
| XXL | "Misc" (row of its own, 1 of 3 columns) | 7.0 pt |
| AX3 | "Non-H" | 14.7 pt |
| AX5 | "Non-H" | 19.0 pt |

The radius roughly doubles from XXL to AX5, confirming `@ScaledMetric(relativeTo: .body)` is live
rather than a fixed constant. Every chip on both devices, at every sampled size and in both
orientations, read visibly rounded rather than square in this batch's direct image review — the
walk covered the whole sheet, not just the grid, per the owner's round-II direction that review
captures show the entire sheet: all ten category names stayed complete and every control beneath
the grid (Reset Filters, Advanced Settings, the search-scope toggles, the minimum-rating stepper,
the pages-range fields, the custom-filter toggles) rendered correctly at every stop.

**Header glass-button measurement (#14).** Whether each action symbol (download / favorite / read)
stays inside its own circular glass background as both scale together. Measured on the iPhone
portrait AX5 header by the fill/glyph colour split (green fill + white glyph for the selected
"read" button, dark-grey fill + green glyph for the other two):

| Button | Circle | Glyph | Margin |
|---|---|---|---|
| Download | 104 x 90 pt | 46 x 41 pt | 18.3 pt |
| Favorite | 105 x 90 pt | 36 x 34 pt | 20.7 pt |
| Read (selected) | 104 x 90 pt | 42 x 33 pt | 20.7 pt |

Every glyph sits inside its circle with a double-digit point margin — none overflows. The same
three buttons were also checked at iPhone landscape AX5 by eye, with the same result.

**Stats-strip measurement (#14).** The strip is a horizontal `ScrollView` again rather than a
stack of fixed-fraction columns. Scrolling it at iPhone portrait XXL/AX3/AX5 and landscape AX5
revealed every column on the walked gallery (Favorited, Language, Ratings, Page Count, File Size)
with its label and value complete and the five-star rating row un-clipped at every stop; no single
column ever spanned the full container width, matching the owner's round-II direction that a
column may grow up to 90% of the container width and wrap inside that budget rather than the strip
stacking vertically.

**Reader upper-panel measurement (#22).** Re-walked on a different, 166-page gallery (round 1 and
batch 3 both used a 30-page gallery, so this also checks the fix isn't page-count-dependent). At
every sampled size and in both orientations the "n / total" page indicator (`1 / 166` at the start)
stayed on one line and fully legible, and the lower panel's page-range end labels ("1" and "166")
stayed single-line, not truncated.

**Outcome.**

- `re-verified`, remaining note: **#12** — the masonry never drops below two columns at any of the
  cells this batch or batch 3 sampled, on either device, in either orientation; the rating symbol
  row degrades gracefully (single star + numeral) rather than clipping in the one column narrow
  enough to force it. **#22**, **#29** stay `re-verified`, now additionally confirmed against the
  owner's round-II directions (never-one-column; scaling corner radius; whole-sheet review scope).
  **#14** stays `re-verified`: the round-II regression this batch introduced by moving to a
  horizontal-scrolling strip and glass action buttons is itself now confirmed correct at the cells
  re-walked.
- still `open`: **#4**, narrowed further. Every iPad portrait cell the finding named for #3, #4,
  #7, #10 and #32 now draws the capsule's magnifier and placeholder (or, on #10, the submitted
  query with its clear button). What remains unconfirmed: the iPad landscape occurrences of #3,
  #4, #7, #10 and #32, and the iPhone landscape #32 occurrence — none of those were re-walked in
  batch 3 or batch 4.
- Every other finding is inherited unchanged: this batch touched only
  `AppComponents/CategoryView.swift`, `GalleryListComponents/` (thumbnail cell and masonry layout),
  `ReadingFeature/Support/ControlPanel.swift` and `DetailFeature/DetailView+HeaderSection.swift` /
  `DetailView+Subviews.swift`.

**D-15 parity.** Seven `.large` comparisons, all matched, each a `parity` row in `pairs.tsv`: the
Filters sheet on both devices, the Detail header (download/favorite/read buttons and the stats
strip's first row), the reader control panel, and the Thumbnail-mode grid on both devices (two
columns on the phone, four on the iPad, title still capped at three lines with an ellipsis). The
Detail header's `FAVORITED` count differs between the batch-3 and batch-4 `.large` shots only
because the live gallery's favourite count changed between captures — content drift, not a layout
change; every frame (button positions, stats-row layout) is otherwise identical.

**Protocol deviations, recorded.**

1. **Session interruption.** A prior sub-agent captured the bulk of this batch's evidence (all 116
   after-images under `reverify/batch4/` and the 91 befores under `reverify/batch4/before/`) and
   generated `pairs.tsv`, then was cut off by a transient server error partway through writing this
   section and restoring the simulators. This session picked up from that point: it verified the
   existing evidence (no re-capture was needed), fixed a documentation defect it found in the
   partial work (below), wrote this section, and finished the simulator restore.
2. **A wrong-simulator mixup during the restore, corrected before anything was written.** While
   confirming the iPad's Display Mode after the interruption, this session queried booted
   simulators by device-model substring rather than reading the recorded `IPAD_UDID`/`IPHONE_UDID`
   values, and momentarily operated against the wrong booted "iPad Pro 11 (snapshots)" simulator and
   the `SPARE_UDID` iPhone (reserved for UI tests, never a sweep target) instead of the recorded
   `IPAD_UDID` and `IPHONE_UDID`. Nothing was captured or recorded against the wrong devices — the
   mistake surfaced immediately when `xcrun simctl listapps` showed the wrong bundle map, before any
   evidence was taken. `SPARE_UDID`'s `content_size` and `appearance` were changed (to `medium` /
   `dark`) during the confusion; no baseline is recorded for `SPARE_UDID` (it is explicitly out of
   the D-09 / § Simulator-baseline contract) and no forbidden operation (erase / uninstall /
   clear-app-state) touched it, so it was left as it was rather than guessed back to an unknown
   prior state. The recorded `IPHONE_UDID` was found already sitting at its exact baseline —
   `medium` / `dark` / `disabled` / portrait, Display Mode `Detail` — confirming the
   pre-interruption agent had restored it correctly before the crash.
3. **A documentation defect found and fixed while finishing this section.** The interrupted agent's
   five append-only edits to the § Findings table (findings #4, #12, #14, #22, #29) had inserted
   their "Re-verify (batch 4, …)" notes into the table's **Status** column instead of its
   **Description** column, corrupting that column's value (e.g. `open **Re-verify (batch 4,
   ...)**…for those.` in place of a bare `open`). This session rebuilt those five notes from the
   pristine pre-batch-4 row content and re-inserted them at the correct column boundary; the
   Status column now again reads a bare `open` / `re-verified` on all five rows, verified by pipe
   count (6, matching the table's five columns) and by eye. The § Matrix table's 35 batch-4 appends
   were checked by the same method and found correctly placed — that table's last column is
   already free-text ("Finding"), so the original append logic was correct there and needed no
   fix. No image evidence and no `pairs.tsv` row were affected; this was a Markdown-table
   formatting defect only.
4. **A second worktree was built** to compile the `391ce4ea` binary with `BUNDLE_ID_SUFFIX=.personal`,
   per the batch-1 deviation. It was removed at the end of this session, after confirming its
   `.planning/16-SWEEP.md` was still byte-identical to this worktree's pre-batch-4 content (md5
   `225b9d70a939fb0b5bdb4d6c43bb2494` on both), i.e. it had never been written to.
5. **The iPad's Activity Logs sheet required an explicit dismiss tap** (on the dimmed area outside
   the card) rather than a back-button tap, to return to the Search results screen after the
   finding-#4 capture — the sheet's own in-card "<" glyph is not a distinct accessibility element
   from the dimmed background in this presentation. Nothing was erased or backgrounded; the app
   remained on `App: EhPanda` throughout.
6. **Pull-to-reveal capsules on #10 and #32 required an explicit downward swipe** (`sim-use swipe
   --coordinate-space ui`) past the top of the list to bring the capsule on screen before capturing,
   matching the finding's own "pull-to-reveal" name and batches 1-3's protocol.
7. **Content drift.** Live gallery content has refreshed again since batch 3, so no before/after
   pair on a list screen shows the same artwork; pairs match screen, position, size, orientation and
   page state, and the verdict is on the layout property. The reader parity comparison was
   re-captured on a different (166-page, not 30-page) gallery deliberately, to check the fix isn't
   tied to a particular page count; both the batch-4 walk and its own before are on that same
   gallery.
8. **One unpaired capture.** `iphone-portrait-AX5-14-stats3.png` has no before counterpart at that
   scroll position (the before build's strip was a fixed-fraction row, not a `ScrollView`, so there
   was nothing to scroll to a matching third position) and is **not** in `pairs.tsv`; it is
   supplementary evidence that a third stats column is reachable by continuing to scroll.

**Evidence.** After-captures are under `$HOME/Library/Caches/ehpanda-phase16/reverify/batch4/`, the
live befores under `.../reverify/batch4/before/`, and the `.large` after set under
`.../d15-after/batch4/`. The `pairs.tsv` in the re-verify directory lists every judged after-image
with its before image and verdict: 122 rows — 115 `pass`, 7 `parity`, 0 `open` (every `open` cell
this batch touched belongs to finding #4, which this batch narrowed but left `open` in the
Findings table rather than recording an open row in `pairs.tsv`, since no after-image of a still-
failing cell was captured — the iPad landscape and iPhone-landscape-#32 gaps are absence of
evidence, not evidence of failure). No image is tracked by git (D-32).

**Simulator state restored** after the walk and read back: iPhone `medium` / `dark` / `disabled` /
portrait 420×912, Display Mode `Detail`; iPad `large` / `light` / `disabled` / portrait 834×1210,
Display Mode `Detail`. The app is left installed on both, resting on the Setting screen (iPhone:
Home tab; iPad: Setting root list).

#### iPad login-gated walk — 2026-09-04

Batch 5a. The owner signed in on `IPAD_UDID` by hand and reported it in chat on 2026-09-03 (D-09 —
no credential was ever entered by an agent; the logged-in simulator is treated as infrastructure).
That unblocked the six iPad screens the 16-03 amendment had left `blocked: no iPad session` for want
of a session, and this batch walks them for their first iPad judgment.

**Build and install.** Base worktree at `85ea550d` (`git reset --hard`), built with
`BUNDLE_ID_SUFFIX=.personal`; the installed bundle id was confirmed `app.ehpanda.personal` (via
`simctl listapps`) before installing. Install-over on `IPAD_UDID` (`8250D97E-…`) only — never
uninstalled or erased; the iPhones were not touched (a sibling batch owns them). The owner's
`EhPanda` profile session and the populated Favorites confirmed the login before the walk.

**Cells walked (36 iPad Matrix cells — all six orientation×size cells of each screen, top +
scrolled):** #8 Favorites root (+ index / sort / features menus), #5 Home › Watched, #14 Gallery
Detail (header + badge, stats strip, tag cloud, previews, comments preview), #19 Detail › Archives
sheet, #20 Detail › Torrents sheet, #38 Setting › EhSetting (native sections 1–3, including findings
#27 and #28). Screens #13, #15–#18, #21–#27 stayed out of scope and their iPad rows remain
`blocked`.

**Verdicts.** #5, #8, #14, #20 and #38 pass at every sampled cell; #19 passes at portrait XXL/AX3
and landscape XXL, and records the **new iPad-only finding #36** at portrait AX5 and landscape
AX3/AX5. The two D-13 named cases whose iPad column was always blocked — the Detail **stats strip**
and the tag cloud's **long-tag** clipping — are now confirmed fixed on the regular-width Detail
modal (§ D-13 table updated). Several iPhone findings are confirmed **absorbed by the iPad's wider
layout**: the Excluded-Languages header overlap (#27) reflows to a language-header-above-toggle-rows
block; the Multi-Page-Viewer `LabeledContent` overlap (#28 — still `open` on iPhone) does not
reproduce because EhSetting is a regular-width form-sheet with inline-expanded pickers; the torrent
four-value loss (#21) and the Archives card-content loss (#20) do not reproduce; and the Detail
header title (#13) reads complete under its owner-accepted three-line cap.

**New finding #36** (iPad-only): in the short iPad Archives form-sheet, at the accessibility sizes
the `scrollingColumn` branch has too little scroll travel to collapse the large "Archives"
navigation title, so scrolling to the funds row and Download button leaves the title pinned and
overlapping the "1280x" card. Confined to portrait AX5 and landscape AX3/AX5; portrait AX3 (the
title scrolls off first) and XXL (`pinnedColumn`, no scroll needed) pass, and the parallel Torrents
sheet (#20) is exempt because its single-torrent content is short and its title collapses away
cleanly.

**Deviations.** (1) At #38 AX5 a scroll swipe landed on a `.menu`-style archiver picker and opened
its modal popover, which would not dismiss via `sim-use` or the simulator-control HID taps (the
SwiftUI menu popover sits in a separate window); the app was relaunched (`simctl terminate` /
`launch`, cookies persist) to clear it, and scrolling was resumed with faster, longer swipes.
Nothing was submitted — the picker's current value was never changed and no EhSetting upload button
was tapped. (2) The delete-profile destructive dialog was **not** opened (D-09). (3) One #38
AX5-portrait top capture caught a transient large-title-collapse frame that looked like an overlap;
a fresh re-capture after settling showed a clean inline title, and that clean capture is the
archived evidence.

**Evidence.** Cell captures under `$HOME/Library/Caches/ehpanda-phase16/sweep-ipad-login/`, named
`ipad-<orientation>-<SIZE>-<screen#><suffix>.png`, with `cells.tsv` (71 rows including header). The
`.large` reference for each of the six screens under
`$HOME/Library/Caches/ehpanda-phase16/d15-after/batch5a/` (`ipad-large-<screen#>.png`). No image is
tracked by git (D-32).

#### Fix batch 5b — owner's post-batch-4 changes, 2026-09-04

The four changes the owner asked for after batch 4: a five-line thumbnail-cell title, the Detail
title folded back to three lines with tap-to-expand, the Setting screen's plain large title, and
the tab-root revert. Re-walked on the iPhone only against the batch-4 build (`391ce4ea`).

**Commits covered (4).**

| Commit | Subject | What it can reach |
|---|---|---|
| `1b06875b` | fix(16): cap the thumbnail title at five lines | #12 (#3 in Thumbnail mode) |
| `881104c0` | fix(16): restore the detail title fold at three lines | #13 (#14 Detail header title) |
| `e8fd65c4` | fix(16): give the roots a plain large title | #7 (#33 Setting) + the four tab roots |
| `d6694e0d` | fix(16): keep inlineLarge on the tab roots | reverts the tab roots (#2, #8, #9, #11) |

**Build installed.** One build under test, at `85ea550d` (the branch tip; its tree is `d6694e0d`'s
code plus this file's docs), marketing version 3.0.0 (158), built in this re-verification worktree
with `BUNDLE_ID_SUFFIX=.personal` on the command line as the batch-1 deviation requires.
`plutil -extract CFBundleIdentifier raw <app>/Info.plist` printed `app.ehpanda.personal`, checked
before every install. Every install was `xcrun simctl install` over the existing app (install-over;
nothing uninstalled, nothing erased). Favorites was opened after installing and still listed its
content, confirming the session survived. No credential was ever entered (D-09). iPhone only; the
iPad was never touched.

**Before-captures.** The batch-4 build (`391ce4ea`), from three sources.

| Cell kind | Before source |
|---|---|
| #3 Thumbnail-mode grid (portrait XXL/AX3/AX5 top+mid, landscape AX5 top+mid) and its `.large` | the batch-4 after-captures under `reverify/batch4/` and `d15-after/batch4/`, each opened and confirmed to be the same cell/state |
| #14 Detail header, #33 Setting root, the four tab roots | captured live on a second re-verification worktree's `391ce4ea` build (built with `BUNDLE_ID_SUFFIX=.personal`, `plutil`-checked, install-over), on the same "futanari" gallery for #14 so the title-fold pair is same-gallery — under `reverify/batch5b/before/` and `d15-before/batch5b/` |
| #32 Activity Logs landscape AX3/AX5 | the round-1 sweep captures under `sweep/` (finding #4's landscape occurrence was never re-walked before) |

**Cells re-walked, iPhone.**

| Screen | Cells |
|---|---|
| #3 Frontpage, Display Mode = Thumbnail | portrait `.large` / XXL / AX3 / AX5 (top + mid) and landscape AX5 (top + mid). Display Mode was set from Setting › Appearance › List › Display Mode and restored to Detail afterwards, read back from the picker |
| #14 Gallery Detail | portrait `.large` / XXL / AX3 / AX5 (header top) + landscape AX5, plus a second AX5-portrait capture after tapping the title |
| #33 Setting root | portrait XXL / AX3 / AX5 + landscape AX5 + `.large`. On this iPhone Setting is a tab root (not a sheet), which is the reachable form here |
| #2, #8, #9, #11 tab roots | portrait AX5 + `.large`, as the revert check |
| #32 Activity Logs | landscape AX3 / AX5, for finding #4's residual |

**Thumbnail-title measurement (#12, `1b06875b`).** The title is capped at five lines at every size,
with or without a download badge — the owner-decided budget that supersedes the old three-line cap
and D-15 for this one property. Portrait: at `.large` titles wrap to at most five lines and read
complete; at AX3 a long title fills five lines and ends in an ellipsis (`(5921…`); at AX5 both
sampled titles fill five lines ending in an ellipsis (`[202…`, closing rounded), the tail
ellipsised rather than cut mid-glyph. The grid stays two columns at every sampled size (portrait
`.large`/XXL/AX3/AX5, landscape AX5) — frames x=20/x=218 portrait, x=84/x=464 landscape. The cell
height is now bounded: the tallest portrait-AX5 cell frame is 731 pt against a 912 pt screen, so
one cell no longer runs past a whole screen, where the batch-4 build's uncapped title ran off the
bottom. No cell's content crosses into its neighbour.

**Detail-title measurement (#13, `881104c0`).** The header title folds at three lines at every size
until the reader taps it. Portrait title-frame heights: `.large` three lines (complete for this
title); XXL three lines with ellipsis (`[ai gener…`); AX3 three lines with ellipsis; AX5 196 pt =
three lines with ellipsis, against the batch-4 build's 326 pt (uncapped, five lines) on the same
gallery. **Tapping the title at AX5 expands it** from 196 pt to 326 pt and shows the full text over
five lines — the remedy that justifies the cap. The uploader row is absent for this gallery, but
the category badge (Misc) and the three glass action buttons (download / favorite / read) stay on
screen beneath the title at every size, and the stats strip follows. Landscape AX5 keeps the full
title in three lines (the wide layout fits it). `.large` is unchanged (the header always drew
three).

**Setting-title measurement (#7 / #33, `e8fd65c4`).** On a normal tab entry the Setting root draws
a plain large title: `.large` 20,126 115x48, XXL 20,122 135x48 — leading, large. At AX3 and AX5 the
phase policy falls back to inline and the title is drawn (`Setting` 175,77 69x25, centered), never
the blank band finding #7 recorded; landscape AX5 is inline and drawn too. The batch-4 build's
`.inlineLarge` drew a persistent large title at every size (128x46 at XXL/AX3/AX5), so the Setting
root never had finding #7 on iPhone — the change's benefit is the iPad sheet. **Caveat, owner
decision:** `.large` is a *collapsing* large title, so on iPhone it collapses to the inline title
when the reader returns to the Setting root from a sub-screen (Appearance, General, …) or after an
on-screen text-size change, whereas the batch-4 `.inlineLarge` stayed prominent. No information is
lost (the title is always readable), but on iPhone the change trades a persistent large title for a
collapsing one and, at AX sizes, a smaller inline title than the before, for no finding-#7 benefit
on the root.

**Tab-root revert (#2, #8, #9, #11, `d6694e0d`).** All four tab roots are back on `.inlineLarge`
and render a persistent large leading title at AX5 (Home 105x46, Favorites 162x46, Search 124x46,
Downloads 198x46) and `.large`, matching the batch-4 layout — the revert is a no-op.

**Activity-logs capsule (#4, #32 landscape).** At landscape AX3 and AX5 the search capsule draws
its magnifier glyph and `Search` placeholder, where the round-1 sweep before shows an empty
capsule; the inline title reads `App Activity Logs` in full and the log rows are complete.

**Outcome.**

- `re-verified`: **#12** (thumbnail title capped at five lines with an ellipsis, cell height
  bounded within a screen, two columns preserved), **#13** (Detail title folds at three lines with
  a working tap-to-expand at AX5; header content stays on screen), **#7 / #33** (plain large title
  on normal entry; inline title drawn at AX3/AX5 — the blank band is gone), and the tab-root revert
  confirmed a no-op.
- **#4** narrowed further: the iPhone-landscape #32 occurrence is now confirmed fixed (capsule
  drawn at AX3 and AX5). What remains `open` for finding #4: the iPad landscape occurrences of #3,
  #4, #7, #10 and #32, none of which are on this agent's device.
- **Owner decision flagged** (not a D-03 degradation, so not recorded as a finding): the Setting
  root's `.large` collapsing behaviour on iPhone described above.
- Spacing and padding quality were not judged (the owner's reflow quality bar defers that to a
  separate pass).

**D-15 parity.** The thumbnail `.large` rows are `parity` with the note that the three-to-five-line
budget is the owner-decided change, not a defect. The Detail `.large` header and the four tab-root
`.large` titles matched their before (three lines / `.inlineLarge` unchanged). The Setting root
`.large` is the owner-decided `.inlineLarge`→`.large` mode change (a large title on entry), not a
parity break.

**Protocol deviations, recorded.**

1. **Tool versions.** `sim-use` 0.14.0 and `agent-device` 0.20.10, as in batches 2–4, not the
   0.13.0 / 0.20.8 in § Tooling. Rotation went through `agent-device orientation … --session iphone`.
2. **Scrolling by explicit coordinates**, as in batches 2–4: `sim-use swipe --coordinate-space ui`
   inside a 35–68 % band, with an `App: EhPanda` assertion around every capture.
3. **Landscape screenshots straightened** with `sips -r 270` (the device reported `landscape-right`;
   `-r 90` came out upside-down).
4. **Display Mode** was set to Thumbnail and restored to Detail from Setting › Appearance › List,
   read back from the picker.
5. **Same-gallery #14 before.** The batch-4 #14 capture is a different (short-title) gallery, so it
   cannot show the fold change; the #14 before was captured on the same "futanari" gallery on the
   `391ce4ea` build instead.
6. **A Setting large-title rendering artifact, characterised.** The first Setting captures were
   taken after popping back from the Appearance sub-screen and showed the title collapsed; a fresh
   tab entry draws the large title, so the clean-entry captures were retaken and the collapse is
   recorded as the caveat above.
7. **Content drift.** Live gallery content has refreshed since batch 4; pairs match screen,
   position, size, orientation and page state, and the verdict is on the layout property.
8. **One unpaired capture.** `iphone-portrait-AX5-14-top-expanded.png` (the tapped/expanded title)
   has no before counterpart and is not in `pairs.tsv`; it is supplementary evidence that
   tap-to-expand restores the full title.

**Evidence.** After-captures under `$HOME/Library/Caches/ehpanda-phase16/reverify/batch5b/`, the
same-gallery / root befores under `.../reverify/batch5b/before/` and `.../d15-before/batch5b/`, and
the `.large` after set under `.../d15-after/batch5b/`. The `pairs.tsv` in the re-verify directory
lists every judged after-image with its before and verdict: 30 rows — 22 `pass`, 8 `parity`, 0
`open`. No image is tracked by git (D-32).

**Simulator state restored** after the walk and read back: iPhone `medium` / `dark` / `disabled` /
portrait 420×912, Display Mode `Detail`. The iPad was not touched. The app is left installed.

#### Fix batch 6 — the landscape list cell and the Setting title's presentation context, 2026-09-04

Two owner-directed follow-ups, walked by the phase lead on the iPhone against the batch-5b build.

**Commits covered (2).**

| Commit | Subject | What it can reach |
|---|---|---|
| `100f19fb` | fix(16): keep list cover and title inline when wide | every list-mode gallery cell (#3, #4, #5, #6, #7, #8, #10, #11) in a wide row |
| `be4665cf` | fix(16): keep the setting tab title inline large | #28 Setting root, tab-root presentation only |

**Build installed.** One build at `be4665cf`, built from the main worktree with
`BUNDLE_ID_SUFFIX=.personal` on the command line;
`plutil -extract CFBundleIdentifier raw <app>/Info.plist` printed `app.ehpanda.personal`, checked
before the install. Installed with `xcrun simctl install` over the existing app — nothing
uninstalled, nothing erased, no credential entered (D-09). iPhone only; the iPad was untouched
because another agent held it.

**Cells walked.**

| Screen | Cell | Result |
|---|---|---|
| #3 Frontpage, list mode | iPhone landscape AX5 | pass — cover and title share one line. The row measures 744 pt wide (above the 550 pt divide) and the whole cell 744 x 426 pt; cover on the left, title, uploader, five-star rating, rounded category badge and date on the right, all complete. |
| #3 Frontpage, list mode | iPhone portrait AX5 | pass — the same cell stacks, 380 x 793 pt, as the narrow case requires. The predicate flips on width exactly where it is designed to. |
| #28 Setting root | iPhone portrait `.large` | pass — the tab root draws a persistent large leading title (`Setting` 20,70 115x41) that does not move when the list is scrolled, i.e. `.inlineLarge` is back. |
| #28 Setting root | iPhone portrait AX5 | pass — the title falls back to inline and is drawn (`Setting` 175,77 69x25), not a blank band; the rows below are unchanged. |

**What this closes.** The batch-5b caveat on #28 — that the plain large title collapses on return
from a Setting sub-screen on the iPhone — no longer applies: the tab root keeps `.inlineLarge`, and
only the sheet presentation takes the plain large title the owner asked for. The sheet side is an
iPad presentation and is not re-walked here; it is unchanged code from batch 5b, whose `.large`
rendering the owner has already seen.


**Follow-up in the same batch — new finding #36.** Batch 5a's iPad-only finding was fixed and
re-walked here rather than left for a later round, because its remedy is the policy the phase already
owns: `ArchivesView` applied no title display mode at all, so the sheet inherited a large title with
too little scroll travel to collapse. Giving it `navigationTitleDisplayMode(.automatic)` keeps that
inherited mode at and below the default size and falls back to inline above it.

| Screen | Cell | Result |
|---|---|---|
| #19 Archives sheet | iPad portrait AX5 | pass — inline `Archives` (84x26); funds and Download button reached by scrolling with no title drawn over a card. |
| #19 Archives sheet | iPad landscape AX3 | pass — same, inline title, all values reachable. |
| #19 Archives sheet | iPad landscape AX5 | pass — same. |
| #19 Archives sheet | iPad portrait `.large` | parity — the large leading title (139x41) is unchanged. |

The sibling Torrents sheet (#20) was left alone: it passes today, and the same policy would be a
change to a screen with no observed defect.
#### iPad batch 7 walk — 2026-09-04

Batch 7. The ten screens whose iPad cells the 16-03 amendment had left `blocked: no iPad session` on
top of the batch-5a six — #13, #15, #16, #17, #18, #23, #24, #25, #26, #27 — walked for their first
iPad judgment now that the owner's session is present on `IPAD_UDID`. Sixty Matrix cells, all six
orientation × size cells of every screen; no iPhone cell was touched and the iPhone simulators were
never addressed.

**Build and install.** Worktree at `f1a2038e` (`git reset --hard`), built with
`xcodebuild build -scheme EhPanda -configuration Debug` against `IPAD_UDID` and
`BUNDLE_ID_SUFFIX=.personal`, `BUILD SUCCEEDED`. Before installing,
`plutil -extract CFBundleIdentifier raw …/EhPanda.app/Info.plist` printed exactly
`app.ehpanda.personal`. Install-over with `xcrun simctl install` on `IPAD_UDID` only — never
uninstalled, never erased, no `xcodebuild test` destination, no credential entered (D-09). The
owner's session survived the install: Favorites, live gallery detail, comments and the download
inventory were all present afterwards.

**Session.** Baseline read at start and identical at the end: `content_size large`,
`appearance light`, `increase_contrast disabled`, portrait (`sim-use ui` header `EhPanda 834x1210`
with no orientation tag). Rotation via `agent-device orientation … --session ipad`, confirmed each
time from the `App:` header before capturing; landscape frames straightened with `sips -r 270`.

**Verdicts.** Fifty-four cells `pass` or `n/a`, six carry a finding:

| Screen | Result |
|---|---|
| #13 Move-to-folder / FolderManager | 6/6 pass — a regular-width form sheet; title, close and add controls and the folder row read at every size, and the row's swipe actions are icon-only glyphs. |
| #15 Previews (grid + full-screen cover) | 6/6 pass — five-column grid at every size, every page number complete, the cover's placeholder page number grows and still reads. |
| #16 Comments (+ post sheet) | 6/6 pass — author, vote score, full timestamp and body all read; the meta line stacks under the author from AX3 up. |
| #17 Detail Search | 6/6 pass — the row reflows cover-above-title at the accessibility sizes and keeps title, uploader, language, rating, page count, badge and the full timestamp. |
| #18 Gallery Infos | 6/6 pass — value-under-label reflow; URLs, token, title and every counter read in full. |
| #23 download confirmation dialogs | 4 pass, 2 **finding:#37** (portrait AX3, landscape AX3). |
| #24 Reading | 6/6 pass — no app-drawn text on the page surface; the page context menu keeps all five items and scrolls to the fifth at AX5. |
| #25 Control panel | 2 pass (XXL both orientations), 4 **finding:#26** (AX3 and AX5, both orientations). |
| #26 Reading Setting sheet | 6/6 pass — the measured card keeps its height and scrolls (P-11); nothing lost. |
| #27 Live Text overlay | 6/6 `n/a: no app-drawn text (system overlay)` — the overlay's only text view is transparent with a zero-point font and its highlight paths are image-space. |

**New finding #37** (iPad-only): the Detail download **delete confirmation** does not reserve the
height its own button row needs at AX3. The alert keeps `Cancel` and `Delete` side by side at that
size — it restacks them vertically only at AX5 — and the card's rounded bottom edge cuts both
capsules roughly in half, with the labels on the clip line and no bottom padding. It reads correctly
at `.large`, at XXL and again at AX5, so AX3 is the single size where the container's height and its
contents disagree, and it shows identically in both orientations.

**Second site for finding #26.** The reader control panel's **Auto-Play** menu (#25) loses the
checkmark beside the selected interval from AX3 upward in both orientations, exactly as the activity
log's Runs menu does on #32: present at `.large` and XXL, absent at AX3 and AX5, while the
accessibility tree still reports `#checkmark`. The finding's Screen and Cells columns now name both
sites.

**Existing findings disconfirmed on iPad.** #23 (the iPhone landscape alert that hides its sentence
and its `Cancel`) does **not** reproduce: every iPad cell of that screen was raised and cancelled,
and at AX5 the alert restacks its buttons and reads whole. #5, #6, #8 and #9 (the gallery-row losses)
do not reproduce on #17's regular-width rows. The reader's page indicator (#22) reads at every iPad
size, including a three-digit `132 / 254` counter, because the owner-authorised `.large` cap on the
upper bar keeps the row on one line and the iPad's width is far above the 375 pt budget that cap was
measured against.

**Deviations.** (1) The #23 **retry-mode** dialog was not exercised — it needs a download in an error
state and the session's only download is complete; only the delete variant exists to raise, and every
dialog raised was cancelled. (2) The #13 **delete confirmation** was not raised either: deleting a
folder is forbidden on this simulator, and the sheet's only folder is `Default`. The swipe actions
that would raise it were revealed and judged instead — they are icon-only glyphs with no text to
lose. (3) The Detail stats strip has to be flicked sideways before its trailing `Gallery Infos`
ellipsis is reachable in portrait, and a slow synthetic drag does not move it; a short flick
(0.25 s) does. Two earlier slow drags were absorbed by the enclosing scroll view and one stale
`--label` tap landed outside the modal and dismissed it, so the Detail was re-entered — no state was
changed by either. (4) Reading Setting sliders were read, never moved (their values are byte-identical
before and after); Live Text was toggled on for #27 and back off; no comment was posted, edited or
voted on; no download, folder or gallery was deleted.

**Restore proof.** `xcrun simctl ui <IPAD_UDID> content_size` / `appearance` / `increase_contrast`
read back `large` / `light` / `disabled`, and `sim-use ui` reports `App: EhPanda 834x1210` with no
orientation tag — the recorded baseline exactly.

**Evidence.** Cell captures under `$HOME/Library/Caches/ehpanda-phase16/sweep-ipad-batch7/`, named
`ipad-<orientation>-<SIZE>-<screen#>-<position>.png`, with `cells.tsv` (75 rows including header).
The `.large` reference for each of the ten screens under
`$HOME/Library/Caches/ehpanda-phase16/d15-after/batch7/` as `ipad-large-<screen#>.png`; each was
compared against its sized frames and no default-size change was observed on any of the ten screens
(D-15). No image is tracked by git (D-32).

#### Unblock walk (batch 8) — 2026-09-04

Batch 8. The three screens whose Matrix cells were still `blocked` for reasons unrelated to the iPad
session — **#21 Tag Detail**, **#22 NewDawn**, **#30 Login** — attacked at their actual blockers.
Thirty cells in scope (#21 on both devices, #22 on both devices, #30 on iPhone); eighteen are now
walked and pass, twelve stay blocked with a corrected reason. No source file was touched: this was a
walk, not a fix batch.

**Follow-up by the phase lead, same day.** `Show New Dawn Greeting` was turned back **on** on
`IPHONE_UDID` after this batch closed, and deliberately left on. The batch proved #22's block is a
timing fact rather than a permission one: the daily gain is issued once per UTC day and account-wide,
and the day's gain had already been consumed about nineteen hours before the walk. With the toggle
armed before the next UTC day begins, that day's first fetch presents the sheet, which is the only
honest way to reach these six iPhone cells. The catch is that the sheet presents to whoever opens the
app first and is gone once dismissed, so walking it needs a run timed just after the UTC boundary, or
the owner leaving the greeting on screen and saying so. The iPad's toggle was left off: one account,
one gain, so only one device can be walked per day, and the iPhone is the Matrix's primary device.

**Build and install.** Worktree at `53c3022b` (`git reset --hard`), built with
`xcodebuild build -scheme EhPanda -configuration Debug` and `BUNDLE_ID_SUFFIX=.personal`,
`BUILD SUCCEEDED`. Before every install `plutil -extract CFBundleIdentifier raw
…/EhPanda.app/Info.plist` printed exactly `app.ehpanda.personal`. Install-over with
`xcrun simctl install` on all three simulators; none was uninstalled or erased, no `xcodebuild test`
destination was used, and no credential was entered by an agent (D-09). Both owner sessions survived
the install.

**Devices.** `IPHONE_UDID` and `IPAD_UDID` as recorded, plus a third simulator created for this
batch: a logged-out **iPhone Air** on iOS 26.5 (`content_size large`, `appearance light`, portrait),
used for **#30 only**. Its device type matches `IPHONE_UDID`, so the Matrix geometry for the #30 rows
is the same 420×912 frame the rest of the iPhone column was walked in. Neither owner simulator was
ever signed out — that is exactly what the third simulator exists to avoid.

**Settings changed, and put back.** Every one of these was authorised by the owner for this batch,
recorded before the change and read back after the restore.

| Simulator | Setting | Recorded value | Set to | Restored | Read-back proof |
|---|---|---|---|---|---|
| iPhone | Preferred Language (iOS Settings › EhPanda) | English (Default) | 简体中文 | English (Default) | app relaunched: `Home` / `Reload` / `Frontpage` render in English |
| iPhone | General › Tags › Enable Tags Extension | off | on | off | persisted `setting.enableTagsExtension = false` |
| iPhone | General › Tags › Translate Tags | off | on | off | persisted `setting.translateTags = false` |
| iPhone | Account › Show New Dawn Greeting | off | on | off | persisted `setting.showNewDawnGreeting = false` |
| iPad | Preferred Language (iOS Settings › EhPanda) | English (Default) | 简体中文 | English (Default) | app relaunched: tab bar reads `Home / Favorites / Search / Downloads / Setting` |
| iPad | General › Tags › Enable Tags Extension | off | on | off | in-app toggle value `0` after the change |
| iPad | General › Tags › Translate Tags | off | on | off | in-app toggle value `0` after the change |

Two incidental notes on the language change. The iOS Settings app lists **two** EhPanda entries (the
`app.ehpanda` and `app.ehpanda.personal` bundles are both installed on both simulators, § "Why
`app.ehpanda.personal`"). On the iPhone the first entry was the one that drove `BUNDLE_ID`; on the
iPad it was the second, so the iPad's first entry was set and then **immediately set back to English
(Default)** before the correct one was touched — it ends the batch exactly as it started. And the
Tags Extension needs **Translate Tags** on as well as itself: `DetailView.swift:112` passes
`returnOriginal: !setting.translateTags` to the lookup, so with translation off the tag carries no
`TagTranslation` and the context menu's `Detail` item never appears regardless of the database.

**#21 Detail › Tag Detail sheet — unblocked, 12/12 pass.** Round I recorded these cells blocked
because every entry in the **English** tag-translation database has an empty description, and the
menu item at `DetailFeature/DetailView+Subviews.swift:421` is gated on a non-empty one. Switching
the session to 简体中文 downloads the zh-Hans database instead, in which **12,510 of 44,060 tags carry
a non-empty description**, so the gate opens. The sheet was walked with the session locale Chinese —
that is the only way it exists, and it is stated here so the captures are read correctly.

| Device | Instance walked | Result |
|---|---|---|
| iPhone | a parody tag with a three-line description, one image and three long percent-escaped links | 6/6 pass — description, Images heading and thumbnail, and all three URLs read in full at portrait and landscape XXL/AX3/AX5; the column simply lengthens and scrolls |
| iPad | a female-namespace tag with a 367-character description, three images and an empty links list | 6/6 pass — regular-width form sheet; description complete, all three images drawn inside the card, Links heading reached by scrolling at every accessibility size, nothing outside the card |

**#22 Detail › NewDawn sheet — still blocked, corrected reason.** The round-I reason ("not presented
this session") understated why. The greeting is fetched only when `Setting › Account › Show New Dawn
Greeting` is on (`SettingReducer+Helpers.swift:61`), and it presents only when the server reports an
actual gain (`!greeting.gainedNothing`) — a gain issued **once per UTC day and account-wide**. The
toggle was switched on and five separate fetch opportunities were exercised against the live session:
two cold relaunches, one background/foreground return (each sends `.setting(.fetchGreeting)`), and
two gallery-detail loads (`DetailReducer+Fetch.swift:52-56` parses and presents a greeting off the
detail response). The sheet never presented, so the server reported no gain. The UTC day was already
about nineteen hours old when the batch ran and earlier phase-16 sessions had used it. **Nothing was
fabricated, forced or simulated, and no app data was edited behind the app's back.** The twelve cells
(iPhone and iPad) stay `blocked: no daily gain issued this UTC day (toggle now armed on the iPhone)`; the iPad is blocked by the same
account-wide fact rather than by anything device-specific, so its toggle was left untouched. The
toggle was restored to off on the iPhone.

**#30 Setting › Login — unblocked, 6/6 pass, two sub-states deliberately unwalked.** The native form
renders only in the `!didLogin` branch of `AccountSettingView.swift`, so it was walked on the
dedicated logged-out simulator. At every sampled cell the heading, both field labels
(`Username` / `Password`), both placeholders and the disabled submit chevron read in full. Two things
worth recording:

- **Finding #33's fix holds on the iPhone too.** At AX5 portrait the large title falls back to an
  inline one and the heading no longer paints through the `Username` label — the same behaviour the
  batch-3 re-verification measured on the iPad, now confirmed on the compact-width screen where the
  original overlap was theorised.
- **The submit chevron drops below the fold in landscape above the default size.** At `.large`
  landscape it sits fully visible above the floating tab bar; at XXL it rests half under the bar, at
  AX3 it is below the fold entirely, and at AX5 the password field's lower edge passes under the bar
  as well. In every case one or two scrolls bring the control fully into view, clear of the bar
  (`ViewThatFits(in: .vertical)` hands the column to its scrolling candidate). Judged **fine** under
  the verdict rule — the form grew taller and a control moved below the fold of a screen that
  scrolls, which the rule lists as reflow, not loss, and the same "content passes under the bar's own
  material" reading already applied to finding #36. It is written out here because it is the one
  borderline call in this batch and the owner may want to look at it.

**The toast and the error sheet were not walked**, and cannot be without crossing a hard line: both
are presented only from a login attempt (`LoginReducer` raises the toast on a failed `loginDone` and
the error sheet from that toast's tap), and reaching them would mean typing a credential and
submitting the form to a third-party service. No credential, real or fabricated, was entered; the
form was never submitted; the `Website` toolbar item was not opened either (the WebView and
Cloudflare challenge are out of scope by D-11 in any case). Those two sub-states stay unwalked and
are recorded as such rather than guessed at.

**New findings: none.** No cell in this batch is degraded, so the findings list still ends at #37 and
no numbered entry was added. One size-independent observation is worth the owner's eye but is **not**
a Dynamic Type finding: in the Tag Detail sheet's `LinksSection` and `ImagesSection`, the
`ErrorView(error: .notFound)` empty-state overlay reports its text in the accessibility tree but
draws nothing on screen — the area under the heading is blank. It renders identically at `.large`, so
it fails the D-04 comparison basis and is out of this phase's scope.

**Deviations.** (1) `sim-use tap` does not actuate a SwiftUI `Toggle` on these builds — three taps on
the greeting switch left its AX value at `0`; explicit `sim-use touch --down` / `--up` with a short
hold toggles it reliably, and every switch in this batch was driven that way. (2) After the per-app
language change the app exposed an **empty accessibility tree** to `sim-use` until an `agent-device`
XCUITest runner was attached to the same simulator; once attached, `sim-use ui` worked normally for
the rest of the session. (3) In landscape, `sim-use swipe` coordinates are interpreted in the
device's portrait framebuffer frame, so three early iPad landscape "bottom" captures did not actually
scroll; they were retaken with `sim-use gesture scroll-up`, which handles the rotation, and only the
retaken frames are archived. (4) Nothing was voted on, purchased, posted, downloaded or deleted; no
tag vote was cast from the context menus that were opened, and every sheet raised was dismissed by
swipe.

**Restore proof.** All three simulators read back their recorded baselines at session end:
`IPHONE_UDID` `medium` / `dark` / `disabled`, `IPAD_UDID` `large` / `light` / `disabled`, the
logged-out simulator `large` / `light` / `disabled`; all three `sim-use ui` headers report
`App: EhPanda` with no orientation tag (portrait). The app-level settings restores are in the table
above.

**Evidence.** Cell captures under `$HOME/Library/Caches/ehpanda-phase16/sweep-batch8/`, named
`<device>-<orientation>-<SIZE>-<screen#>-<position>.png` with `<device>` ∈ {`iphone`, `ipad`,
`loggedout`}, plus `cells.tsv` (48 rows including header). The `.large` references under
`$HOME/Library/Caches/ehpanda-phase16/d15-after/batch8/` — `iphone-large-21.png`,
`ipad-large-21.png`, `loggedout-large-30.png` and `loggedout-large-30-landscape.png`; each was
compared against its sized frames and no default-size change was observed on either screen (D-15). No
image is tracked by git (D-32).

#### NewDawn mock walk (batch 9) — 2026-09-04

The twelve screen-#22 cells, walked by the phase lead after the owner ruled that a mocked greeting
was acceptable because only the layout is under test. This is the last block of `blocked` cells: the
Matrix now has a verdict for every cell.

**How the greeting was surfaced, and what that costs the evidence.** The sheet presents only when the
server reports a daily gain, which is issued once per UTC day and account-wide, so it cannot be raised
on demand. A single line was added to `AppReducer`'s `.active` branch — `.send(.presentation(
.presentNewDawn(.mock)))` — built, installed, walked, and then **reverted**; it was never committed,
and `git status` was clean before the clean rebuild. `NewDawnView` itself was not touched, so the view
under test is the shipping one. After the walk the tree was reverted, rebuilt and reinstalled on both
devices, and both apps were relaunched and confirmed running the clean build.

Two content variants appear in the evidence, and the difference is deliberate rather than sloppy: the
UTC day happened to roll over mid-walk, so the **iPhone portrait** set caught the *real* server
greeting (30 EXP, 10,452 Credits, 10,000 GP, 16 Hath) — the longer string, and therefore the stricter
case — while the remaining sets show `Greeting.mock` (10 / 10,000 / 10,000 / 10). Every cell's row
says which it used.

**Cells walked (12).**

| Device | Orientation | Sizes | Result |
|---|---|---|---|
| iPhone | portrait | XXL, AX3, AX5 | 3 pass |
| iPhone | landscape | XXL, AX3, AX5 | 3 pass |
| iPad | portrait | XXL, AX3, AX5 | 2 pass, **AX5 finding:#38** |
| iPad | landscape | XXL, AX3, AX5 | 2 pass, **AX5 finding:#38** |

**New finding #38** — `NewDawnView` has no scroll container, so on the iPad's form-sheet the greeting
is clipped at both ends at AX5. See its Findings row for the full description and for the two
non-regressions (Dynamic Island overlap, white-on-yellow body text) that this walk turned up but that
are identical at `.large`.

**D-15.** `.large` references were captured per device and orientation
(`d15-after/batch9/`), and the default-size appearance is unchanged on all four.

**Deviations.** (1) `agent-device orientation` silently no-ops when its session has gone stale — it
prints only a diagnostics-log line instead of `Rotated to …`. Two capture sets were taken against an
unrotated device before this was caught; both were deleted and retaken after closing and reopening the
session. Always require the `Rotated to …` line. (2) The agent-device runner app comes to the
foreground when a session is opened, so the app under test must be relaunched afterwards. (3) On the
first launch after an install the `.active` effects are skipped, because `hasLoadedInitialSetting` is
still false; the greeting only presents from the second launch onward.

**Restore.** iPhone `medium`/`dark`/portrait, iPad `large`/`light`/portrait, both read back. Both
devices carry the clean build. No screenshot entered the repository.

#### NewDawn scroll fix (batch 10) — 2026-09-04

Finding #38, fixed and re-walked in the same session the owner raised it, because the remedy was the
one the owner named: give `NewDawnView` a scroll container and drop the `fixedSize`.

**What changed** (`AppComponents/NewDawnView.swift`, commit `fc900bde`): the text `VStack` moved
inside a `ScrollView`, and `TextView` lost `fixedSize(horizontal: false, vertical: true)` — inside a
scroll container the vertical axis is unbounded, so the text takes its natural height without it. The
designed appearance is preserved by giving the content the container's height as a **floor** rather
than a fixed height: `frame(minHeight:)` fed by `onGeometryChange`, so the greeting stays centred
while it fits and grows past that once it doesn't, with `scrollBounceBehavior(.basedOnSize)`
withholding the bounce until there is somewhere to scroll.

**Verified on device**, against a mock raised the same authorised way as batch 9 (one temporary,
never-committed line in `AppReducer`, reverted afterwards; both devices then rebuilt clean, installed
and left at their baselines).

| Cell | Result |
|---|---|
| #22 iPad portrait AX5 | pass — the opening line draws in full and two swipes reach `Hath!` complete, with a scroll indicator. |
| #22 iPhone portrait AX5 | pass — same behaviour in the full-screen presentation. |
| #22 iPad portrait `.large` | parity — still centred in the sheet, nothing scrolls. |
| #22 iPhone portrait `.large` | parity — unchanged. |

Full suite green (1022 tests) and SwiftLint `--strict` clean on the changed file.

**Follow-up, same batch (`bbbaff9e`):** the owner asked for the scroll indicator to be hidden, so the container now carries `scrollIndicators(.hidden)`. Re-walked on the iPad at portrait AX5: the greeting still scrolls to its closing `Hath!` and no indicator is drawn. The modern `scrollIndicators(_:)` was used rather than this repository's more common `ScrollView(showsIndicators:)`, which Apple has superseded; the rest of this view is already built on current API (`onGeometryChange`, `scrollBounceBehavior`), so the file stays internally consistent.

**Still open on this screen, and still not type-size regressions:** the Dynamic Island covers the
first characters of two lines in iPhone landscape, and white body text is drawn over the yellow sun.
Both are identical at `.large`, so they remain out of this round's scope and are recorded on #38's
row rather than fixed here.


#### Owner-requested iPhone 17e AX5 rerun — 2026-09-04

Fresh portrait evidence from iPhone 17e, iOS 26.5, dark appearance, English locale,
using `accessibility-extra-extra-extra-large` (AX5), verified by simulator readback.
Clean build `0790d20b09ccfe726220993d68d165dc284e0b2d` succeeded and was installed
over the existing `app.ehpanda.personal` app. No source changes were made.

**Evidence:** 204 full-resolution screenshots (1170 × 2532), each paired with its UI
outline, organized into 81 navigation groups. The gallery and a 42-entry coverage
report are outside the repository at
`$HOME/.codex/visualizations/2026/09/04/01a06c7a-19c6-7721-80e8-693828b2b1b7/iphone17e-ax5/`
(`index.html`, `COVERAGE.md`, `run.json`).

**Partial coverage:** this simulator was logged out and had no downloaded galleries.
Account-only states, Archives, EhSetting, Download Inspector and download delete/retry
dialogs remain unavailable. Translated Tag Detail and New Dawn were not captured.
Several conditional editor/dialog states are also outstanding; the external report
lists them explicitly. Repeated records in paginated lists were sampled. This rerun
covers portrait AX5 only and does not replace the existing multi-device matrix or
change its scores. The owner review gate remains open.

**Restore:** text size `medium` and appearance `dark` were restored/read back; portrait
was unchanged. Temporary thumbnail display mode and Live Text were restored. No
credentials were entered, downloads started, folders deleted, or content posted.

#### Targeted owner fixes — 2026-09-05

Ten owner-requested findings were re-walked on iPhone 17e, iOS 26.5, portrait, dark
appearance, at `accessibility-extra-extra-extra-large` (AX5). All ten passed: #7 Toplists
thumbnail category placement, #9 Search-history spacing, #13 New Folder editor spacing,
#14 Gallery Detail action reflow, #15 preview-index alignment, #18 Gallery Infos adaptive
rows, the combined #24–#25 Reading/control boundary, #26 Reading Setting factor layout,
#28 Setting-row spacing, and #31 General language layout.

**Evidence:** 11 original-resolution screenshots (1170 × 2532) and a responsive dark
gallery are outside the repository at
`$HOME/.codex/visualizations/2026/09/04/01a06c7a-19c6-7721-80e8-693828b2b1b7/iphone17e-ax5-fixes-2026-09-05/`
(`index.html`). The full EhPanda Debug simulator build succeeded, and its SwiftLint
build-tool plugin completed cleanly.

**Restore:** text size `medium`, dark appearance, portrait orientation, and Display Mode
`Detail` were restored and read back. No credentials were entered; no downloads were
started; no folders were created, moved, renamed or deleted; and no content was voted on,
posted or otherwise mutated.

This targeted pass supplements the existing iPhone 17e AX5 rerun. It does not close the
existing owner review gate.

**#13 spacing follow-up (2026-09-05).** All folder rows now use one private `LabelStyle`
backed by default `HStack` spacing; the normal tint is preserved and no numeric spacing
constant is used. The full simulator build and strict file SwiftLint passed. The refreshed
iPhone 17e AX5 screenshot passed with the editing and regular title leading edges aligned:
`$HOME/.codex/visualizations/2026/09/04/01a06c7a-19c6-7721-80e8-693828b2b1b7/iphone17e-ax5-fixes-2026-09-05/13-new-folder-editor-spacing.png`.
The baseline `medium` text size and dark appearance were restored, and no folder was created.

#### Owner-requested iPhone 17e Large rerun — 2026-09-05

Fresh partial-journey evidence was captured on iPhone 17e, iOS 26.5, in portrait,
dark appearance, and English, with `content_size large` verified by simulator readback.
The rerun follows the same exact 204-stem partial journey sequence as the AX5 rerun.

**Evidence:** 204 full-resolution screenshots (1170 × 2532), each paired with a
nonempty UI outline, are outside the repository at
`$HOME/.codex/visualizations/2026/09/04/01a06c7a-19c6-7721-80e8-693828b2b1b7/iphone17e-large/`.
Current gallery, list, search, comment, metadata and torrent values reflect live service
data and therefore differ from the AX5 evidence in places. The exact second gallery was
unavailable because it had been expunged, so `[Allure Diffusion] Shoko Kieri - Office
Landscape` by `Username1985` was substituted for all eight second-gallery targets. Large
sometimes fit an AX5 overflow sequence in one stable state; repeated stable captures preserve
the exact stem parity where additional scrolling produced no distinct state.

**Restore:** no persistent content or settings were mutated. Reading values remained unchanged,
Display Mode remained `Detail`, and Live Text was restored to off.

**Partial coverage:** this rerun has the same partial-journey scope as the AX5 evidence. It does
not replace the existing multi-device matrix or close outstanding coverage. The existing owner
review gate remains open.

#### E-Hentai Settings ValuePicker AX layout fix — 2026-09-05

The shared E-Hentai Settings `ValuePicker` now branches on
`dynamicTypeSize.isAccessibilitySize`. At accessibility sizes it lays out the minimum in a
leading row, the full-width slider in a middle row, and the maximum in a trailing row. Regular
sizes retain the native horizontal labeled `Slider`. Both branches apply
`accessibilityLabel(title)`, giving all six controls their visible setting names.

**Validation:** SettingFeature SwiftLint passed with only the two existing unrelated warnings,
and the iPhone 17e simulator build succeeded. Six live AX5 PNG/TXT pairs, covering image width,
image height, cover scale, tag filtering threshold, tag watching threshold, and virtual width,
were verified at 1170 × 2532 with nonempty outlines at
`$HOME/.codex/visualizations/2026/09/04/01a06c7a-19c6-7721-80e8-693828b2b1b7/iphone17e-ax5-eh-setting-slider-fix-2026-09-05/`.
No setting values changed. The simulator was restored to medium text size, dark appearance, and
portrait orientation.

### Owner disposition — 2026-09-08 targeted recheck

The owner accepted finding #31 (the fourth item in the targeted report), verbatim: 「第四個我覺得展示不下就展示不下直接接受」. The toast may truncate when its content does not fit. Its five remaining matrix cells are marked accepted, not passed; historical descriptions remain as evidence. No code change or round-1 completion is implied.

## Owner disposition update — 2026-09-08

Findings #4 and #7 are accepted: #4 is an Apple native-search issue with an explicit no-fix decision; #7 initial inline title/truncation is accepted as-is. Historical matrix observations remain evidence, not outstanding requests to fix these two findings. See `16-TARGETED-RECHECK.md` for the controlled experiments and the app-owned inline fallback clarification.

### Owner review closure — 2026-09-11

**Resume signal (verbatim tokens):** `D13-4=fixed`, `#28=fixed`, `ROUND1-CLEAR`.

**Delivery route and time:** delivered by the owner at 2026-09-11T08:04Z through the execute-phase
orchestrator's structured question (three selections), then relayed to the plan 16-11 continuation
executor. `ROUND1-CLEAR` was given conditional on the two dispositions above being recorded; it
resolves plan 16-11 Task 2 and authorizes Task 3.

**Evidence basis shown to and approved by the owner:**

- `D13-4=fixed` (Favorites trailing glyph / page count): finding #6 already `re-verified` on iPhone in
  the recorded batches (§ Findings row 6; `### Re-verification batches`, batches 1 and 2), plus the
  2026-09-09 sampled pass on populated iPad Favorites at portrait and landscape AX3 and AX5 recorded in
  `16-LOGIN-COVER-RECHECK.md`. The D-13 named row and the `### D-13 dispositions requested` cell now
  read `fixed`.
- `#28=fixed` (E-Hentai Settings Multi-Page Viewer row overlap, iPhone portrait AX5): the 2026-09-09
  sampled iPhone portrait AX5 check in `16-LOGIN-COVER-RECHECK.md` (toggle and display-style labels
  wrap into distinct rows; no overlap reproduced). Recorded in § Findings row 28 as
  `re-verified (owner 2026-09-11: …)` in the same style as findings #11 and #26: the basis is the
  2026-09-09 sampled agent check plus the owner's disposition, not a new agent device pass.

**Previously recorded dispositions, preserved unchanged:** #4, #7, #31 (accepted 2026-09-08); #11, #26
(owner-confirmed fixed 2026-09-09); #23, #35 (accepted 2026-09-09); #37 (accepted, system defect);
D13-1/2/3 fixed and D13-5 accepted (2026-09-09).

**Not done today:** no simulator check, build, or test was run on 2026-09-11. This entry records
dispositions and their evidence basis only; it adds no new device verdict.

### Round-1 closure

Consistency check run on 2026-09-11 against the table only (plan 16-11 Task 3); no code, asset or
lint-config change and no simulator, build or test run were part of it.

| Measure | Value |
|---|---|
| Matrix rows walked (persisted, historical stored results) | 504 cells: 397 `pass`, 95 historical finding references (90 `finding:#N` + 5 `accepted` on #31's cells, converted 2026-09-08), 12 system-overlay `n/a`; 0 `pending`, 0 `re-verify` |
| Findings total | 38 |
| Findings `re-verified` | 32 (including #11, #26 and #28, whose `re-verified` carries owner provenance rather than a new agent device pass) |
| Findings `accepted` | 6: #4, #7, #31 (2026-09-08); #23, #35 (2026-09-09); #37 (system defect) |
| Findings `open` | 0 |
| D-13 items dispositioned | 5/5: 4 `fixed` (items 1, 2, 3 on 2026-09-09; item 4 on 2026-09-11), 1 `accepted` (item 5, 2026-09-09) |
| Parity findings raised | 1: #35, raised in fix batch 1 as the D-15 `.large` delta on the Detail comment cell that carries a vote score (`### Re-verification batches`). Every other `.large` comparison in the batch log is a matched `parity` row, not a finding |
| Parity findings resolved | 1: #35 owner-accepted 2026-09-09 |
| `minimumScaleFactor` live count | 0 (`grep -rn "minimumScaleFactor" AppPackage/Sources`); the five § D-04 checklist sites read `removed-by 59fb2eb9` |
| § D-04 checklist statuses | every row is `fine`, a closed `finding:#N`, `removed-by 59fb2eb9`, or `blocked: no active transfer` |
| Owner `ROUND1-CLEAR` | 2026-09-11T08:04Z (see `### Owner review closure — 2026-09-11`) |

The matrix figures are the persisted results of the original sweep and the recorded re-verification
batches, not a current-build verdict. The later targeted rechecks (`16-TARGETED-RECHECK.md`,
2026-09-08; `16-LOGIN-COVER-RECHECK.md`, 2026-09-09/10) are sampled evidence for specific items and
do not replace the matrix. Round 1's findings loop is closed; the `no_minimum_scale_factor` lint
rule and the owner-signed UAT gate follow in plan 16-12.

## Owner sign-off

**Resume signal (verbatim):** `approved`

**Delivery route and time:** given by the owner at 2026-09-11T08:35Z through the execute-phase
orchestrator's structured question for plan 16-12 Task 2 (`checkpoint:human-verify`, `gate="blocking"`),
selecting the option labelled `approved`; no additional signature line was typed, so none is recorded.

**Commit the signature covers:** HEAD `d5afe78f` (`feat(16-12): ban minimumScaleFactor via lint`),
verified as `git rev-parse --short HEAD` at 08:35Z with a clean working tree. The signature covers the
completed round-1 table as it stood at that commit: § Matrix with 0 `pending` / 0 `re-verify` cells,
§ Findings with 0 `open` entries, § D-13 with 5/5 dispositions, and `### Round-1 closure` with the
measured counts (see the section directly above).

**What this closes:**

- Phase 10's `10-UAT.md` test 7 (item 5, `skipped` there): the owner-signed device UAT for Dynamic Type
  readability and operability at XXL / AX3 / AX5 across every screen, including the authenticated
  content screens — the D-03 device gate Phase 10 deferred to this phase.
- ROADMAP Phase 16 success criterion 5 (owner-signed UAT). Criterion 6 closed with the lint state below.
- Requirement A11Y-01 (round 1). A11Y-02 (round 2) remains open.
- The `.large` half of D-15: default-size parity as verified per fix batch in plan 16-11 is included in
  the signed table.

**Lint state at the signed commit:** `no_minimum_scale_factor` live at `severity: error` in the root
`.swiftlint.yml`; `grep -rn "minimumScaleFactor" AppPackage/Sources App ShareExtension | wc -l` = 0
before and after the rule landed; all four D-16 rules (`no_dynamic_type_size_modifier`,
`no_geometry_reader`, `no_fixed_system_font_size`, `accessibility_hardcoded_string`) plus
`no_minimum_scale_factor` live at error severity; strict standalone lint `Found 0 violations, 0
serious in 571 files`; scheme build and FeatureTests build-for-testing both green (plan 16-12 Task 1).

**Round 2 may begin.** Per D-23, plans 16-13 onward (assistive technology: VoiceOver, Voice Control,
Reduced Motion, Sufficient Contrast, Differentiate Without Color) are unblocked and land against the
layout signed here. Per D-32 this signature is text only; no image enters the repository.

## Round-2 walkthrough (16-25)

Plan 16-25 (D-31, walkthrough half). The agent walks the eight main flows on iPhone simulators with the
real VoiceOver daemon, the Voice Control label proxy (D-30) and the display settings. Transcripts,
screenshots and logs stay under the evidence root and are never committed (D-32); rows below describe
them in writing.

| Key | Value |
|---|---|
| Date | 2026-09-15 |
| HEAD built and installed | Task 1 (tracer): `24bf5c10244e8a787824c5b2be7024ff16a36a7a` (`docs(16): rescope plans 16-25 and 16-26`). Task 2 onward: `cc05aca6e9b2e817721f310d21468f12dee5e2d4` (`fix(16): revert remaining visual a11y changes`), built by each simulator's UDID and installed over on both (orchestrator ruling R12, 2026-09-15) |
| Toolchain | Xcode 26.6 (17F113), selected with `DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer` on macOS 27.0 (orchestrator ruling R2, 2026-09-15: the default `xcode-select` now points at Xcode 27.0; every earlier Phase-16 gate used 26.6) |
| `WALK_UDID` | `CAE8CEE9-7C40-48D3-BE75-F0940B403DA8`, `EhPanda A11y Walkthrough iPhone 17 (26.5)`, device type `com.apple.CoreSimulator.SimDeviceType.iPhone-17`, runtime `com.apple.CoreSimulator.SimRuntime.iOS-26-5` (iOS 26.5, 23F77); created by 16-25 Task 1 and kept for 16-26. System `AppleLanguages` = `("en-JP", "ja-JP", "zh-Hant-JP")` (English first); the app is launched with `-AppleLanguages (en) -AppleLocale en_US`, the D-30 Voice Control language. Hermetic only: no session, never a test destination |
| `LOGIN_UDID` | `C9C8B01B-1FBC-466E-A4F8-C46B13E1D07D`, `EhPanda Login iPhone Air (26.5)`, runtime iOS 26.5. Found **Shutdown** at 2026-09-15 12:13; booted by 16-25 (orchestrator ruling R3) to receive the install-over, and restored to Shutdown in Task 7. Install-over: built by its UDID, `plutil -extract CFBundleIdentifier raw …/EhPanda.app/Info.plist` printed `app.ehpanda.personal`, then `xcrun simctl install` over the existing app (never uninstalled). D-09 simulator: the owner's hand-entered session |
| `WALK_UDID` install | built by its UDID into `$HOME/Library/Caches/ehpanda-phase16/DerivedData`, `plutil` printed `app.ehpanda.personal`, `xcrun simctl install` |
| Bundle id | `app.ehpanda.personal` |
| Baseline, `WALK_UDID` (read before any change) | `appearance=light`, `increase_contrast=disabled`, `content_size=large`; `com.apple.Accessibility`: `VoiceOverTouchEnabled` missing (0), `CommandAndControlEnabled` missing (0), `ReduceMotionEnabled=0`, `EnhancedBackgroundContrastEnabled` missing (0), `EnhancedTextLegibilityEnabled` missing (0), `ButtonShapesEnabled` missing (0), `GrayscaleDisplay=0` |
| Baseline, `LOGIN_UDID` (read after the R3 boot, before any change) | `appearance=dark`, `increase_contrast=disabled`, `content_size=large`; `VoiceOverTouchEnabled` missing (0), `CommandAndControlEnabled` missing (0), `ReduceMotionEnabled=0`, `EnhancedBackgroundContrastEnabled` missing (0), `EnhancedTextLegibilityEnabled` missing (0), `ButtonShapesEnabled` missing (0), `GrayscaleDisplay=0`; `AppleLanguages` = `("en-JP", "ja-JP", "zh-Hant-JP")` |
| Method | Real VoiceOver in the iOS 26.5 Simulator; `vot` log as oracle; pass-through taps; iPhone only; not a physical device. Focus moves by VoiceOver keyboard chords (`sim-use ios key-combo`, Ctrl+Option+arrows); verdicts come from the `vot` debug log's `Will set element` (FOCUS), screen-change (`First element in app focus`, or the `Screen Changed` note when VoiceOver logs no first-element line) and `Post-processed string` (SPOKE) lines, never from an accessibility tree (research `16-AGENT-WALKTHROUGH-RESEARCH.md`, `90e5e6b4`) |
| Owner decisions (2026-09-15, verbatim) | "2" (walk only the main flows, no exhaustive per-cell table); "而且全都先你自己做 / 我只會去處理必須需要我聽的部分 / 包括 voiceover 的焦點測試也是你可以處理的" (the agent does everything first, including VoiceOver focus testing; the owner handles only what requires listening); "只做 iPhone 就好" (iPhone only). Accessibility here is best effort, not a guarantee |
| Evidence root | `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/` (`scripts/`, `transcripts/`, `display/`, `listen/`, `audit/`; the superseded `24bf5c10` Task 2 files in `superseded-24bf5c10/`) |

**Tracer (Task 1, method re-validated on the HEAD build).** On `WALK_UDID`, hermetic launch with
`EHPANDA_AUTOMATION_TAB=setting`. Enabling VoiceOver raised the system "VoiceOver Gestures" sheet once
(as the research recorded); it was dismissed with a pass-through tap on its OK button, after which
`First element in app focus` landed on the `Setting` heading. The keyboard walk reached `General`; with
VoiceOver focus on `General`, a pass-through tap pushed General: VoiceOver logged a `Screen Changed`
note and set focus on `Language`, the first form element (no `First element in app focus` line, the same
shape as the research's push trials). Ten further steps walked the form in visual order (19 FOCUS lines
in the transcript in total). The back-button tap popped to Setting, and focus landed on the `Account`
row, not the `General` trigger (pop observation). Transcript:
`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/t1-setting-general.txt`
(raw log `transcripts/vot-t1.log`). VoiceOver was turned off afterwards and every `WALK_UDID` setting
read back at its baseline (`VoiceOverTouchEnabled=0`).

### Flows

| flow | route | simulator | session need |
|---|---|---|---|
| F1 Browse | Home root (hero carousel, Frontpage, Toplists) → Show All → Frontpage list | `WALK_UDID` (hermetic) | none |
| F2 Search | Search tab → keyword typed → results → More › Filters sheet → Cancel; unsupported-link toast while on Search | `WALK_UDID` (hermetic) | none |
| F3 Gallery detail | Frontpage cell → Detail → tag chip (rotor) → push Comments (comment-cell rotor); logged-in tag chip rotor (vote items, never activated) | `WALK_UDID` (hermetic) and `LOGIN_UDID` (tag chip) | none hermetically; session for the vote items |
| F4 Read | Detail › Read → tap page → control panel → page slider (1.9) → Close | `WALK_UDID` (hermetic) | none |
| F5 Favorites | Favorites tab → list → gallery Detail → favorite control (walked to the commit point) | `LOGIN_UDID` | session |
| F6 Download | Downloads tab row (hermetic automation download, else an existing row on `LOGIN_UDID`) → rotor Actions and swipe actions → Pages inspector open and dismiss; no Move, Delete or confirmation | `WALK_UDID`, else `LOGIN_UDID` | a download row; never start or delete one on `LOGIN_UDID` |
| F7 Change a setting | Setting → General → toggle `Detect Links from the Clipboard` once and back → pop | `WALK_UDID` (hermetic) | none |
| F8 Comment and rate | Comments › Post Comment sheet → Cancel without typing; Detail › Give a Rating (walked, no drag) | `LOGIN_UDID` | session |

### Flow results

| flow | 1.1–1.6 walk | 1.7 / 1.8 focus | 1.9 / 1.10 / 1.11 | rotor (OQ2) | Voice Control proxy (2.x) | display pass | evidence |
|---|---|---|---|---|---|---|---|
| F1 | VO-1; W-5; W-6; the Toplists placeholder rows are the `deferred-items.md § Found during 16-24` item 1 (cited, not re-reported); the Frontpage list reads one element per cell in visual order; walk 2: order/heading/six-swipe bounded pass; W-6 full Frontpage utterance bounded ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-frontpage-full.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-full60.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-hero-swipes) | 1.7 pass: pre-focus Frontpage `Show All` (reached below VO-1 through the Containers rotor, R6) → push → `Screen Changed`, focus `Loading…`; W-29: once the list loads, focus moves to the second cell, not the first; pop observation: focus on the inline `Home` title; 1.8 not exercised: no sheet or alert in F1; walk 2: W-29 loading-to-first-fixture focus observed ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-frontpage.log) | 1.9 not exercised: no adjustable control; 1.10 pass (`Loading, ellipsis` on push); 1.11 pass (pass-through taps); walk 2: pass-through controls retained ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-display/vc-toggle-ui.json) | not exercised: no tag chip, comment cell or download row in F1 | pass (every tappable is a Button or RadioButton named by its visible text; two identical `Show All` names on Home, observation); 2.2 / 2.5 / 2.6 not exercised: simulator speech-recognition asset fails (research § 4); walk 2: actionable labels and Voice Control proxy bounded ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-display/vc-toggle-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-display/vc-toggle-proxy.txt) | pass (Dark + Increase Contrast, Bold Text, Button Shapes, Reduce Transparency, software grayscale, AX5); Reduce Motion pass: the hero card gradient moves with it off (largest frame change 0.004) and is still with it on (0.000); walk 2: display cells reviewed from the capture set ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/task7-f1-display/; readbacks remain in $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-display/) | `…/transcripts/vo1-home-40.txt`, `…/transcripts/vo1-home-headings-rotor.txt`, `…/transcripts/vo1-home-containers-rotor.txt`, `…/transcripts/vo1-home-below-trap.txt`, `…/transcripts/f1-home-to-frontpage.txt`, `…/transcripts/f1-frontpage-walk.txt`, `…/transcripts/f1-frontpage-pop.txt`, `…/transcripts/f1-home-vc.txt`, `…/transcripts/f1-frontpage-vc.txt`, `…/display/F1/contact.png`, `…/display/F1-pass.txt`; walk 2: order/heading/six-swipe evidence `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-full60.log` / `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-full60.txt`, headings `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-heading-home-final-forward.txt` / `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-heading-home-final-prev.txt`, and hero swipes `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-hero-swipes` |
| F2 | W-5; W-10; the root and results screens otherwise read in visual order; walk 2: Search heading/toast route bounded ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f2-root-toast-order.log) | 1.7 pass: pre-focus the search field → keyword typed with `sim-use` and Return → results push, `Screen Changed`, focus the `Search` back button; 1.8 VO-3 (Filters): pre-focus `Filters` in More → sheet, focus `Cancel`; `Cancel` → focus the error toast (from the results) or the `Search` heading (from the root), not `More`; pop observation: results → root lands on the error toast (W-10); walk 2: toast is reachable and can move away; dismissal not tested ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f2-root-toast-next.txt) | 1.9 not exercised: no adjustable control; 1.10 pass (two trials: the app's announcement is cut after about 20 ms by the toast's own focus move, and the focus utterance then speaks the full toast text uninterrupted; the superseded run's interruption did not reproduce); 1.11 pass (pass-through taps); walk 2: Search/results controls bounded ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f2-results-v4-ui.json) | not exercised: no tag chip, comment cell or download row in F2 | pass (More, the search field, `Recently Searched`, the keyword, its icon-only `Delete` with an English name, the toast Button, tabs; results: back, More, the field, cells); 2.2 / 2.5 / 2.6 not exercised: simulator speech-recognition asset fails (research § 4) | pass, with W-24 (the keyword `Delete` glyph nearly vanishes in software grayscale); Reduce Motion pass (`View+Toast.swift` gate): the toast slides up over about 7 frames with it off and appears in place over 2–3 frames with it on; walk 2: toast display and Reduce Motion v2 reviewed ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/task7-f2-display/; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/task7-f2-root-display/; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/task7-f2-toast-motion-v2/motion-off/; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/task7-f2-toast-motion-v2/motion-on/) | `…/transcripts/f2-root-keywords.txt`, `…/transcripts/f2-search.txt`, `…/transcripts/f2-filters.txt`, `…/transcripts/vo3-filters.txt`, `…/transcripts/f2-toast.txt`, `…/transcripts/f2-toast-trap.txt`, `…/transcripts/f2-root-vc.txt`, `…/transcripts/f2-results-vc.txt`, `…/display/F2/contact.png`, `…/display/F2-pass.txt`; walk 2: W-5 heading and W-10 toast order are recorded at `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f2-root-toast-next.txt`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f2-root-toast-prev.txt`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f2-root-toast-order.log`, and `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f2-results-v4-ui.json`; toast is reachable and can move away, with no dismissal claim |
| F3 | VO-4; W-5; W-7; W-8; W-23; the Comments screen reads one element per cell in visual order ; walk 2: proper Home → Frontpage Show All → first fixture row → Detail push completed ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-push-detail-ui.json); the existing Frontpage push and the new Detail modal evidence are complementary, and the modal has no tab bar | 1.7 pass (twice): pre-focus a Frontpage cell → Detail push, `Screen Changed`, focus the `Frontpage` back button; pre-focus the Comments `Show All` → Comments push, focus the first comment cell; 1.8 not exercised hermetically: no sheet in this part (F8 covers Post Comment); walk 2: L-2 audio reproduces W-8 (uploader → Screen Changed → More); W-35 first-More target remains unresolved ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/L-2.vot.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/L-2.report.txt) ; walk 2: proper push focus evidence reaches Detail ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-push-detail-ui.json); separate Comments modal evidence reaches the full Comments route ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-final.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-comments-ui.json); neither modal transcript is used as a Frontpage-push claim | 1.9 not exercised: the user rating is a drag with no adjustable action (`deferred-items.md § Found during 16-19`, cited; F8 walks it); 1.10 not exercised: the fixture Detail loads before a loading state is caught; 1.11 pass (pass-through taps); `LOGIN_UDID` tag chip: walked to the commit point; not committed (account safety): the vote items were spoken in the Actions rotor and never activated, and `custom_actions` read the same after the pass | W-11. Hermetic tag chip (signed out, no translation): no Actions rotor, `custom_actions` empty, matching its empty menu. Comment cell: three link actions, `custom_actions` identical, no context menu. `LOGIN_UDID` tag chip (signed in): `Vote Down`, `Vote Up`, `custom_actions` identical; nothing missing, nothing listed twice ; walk 2: Comments first Actions cycle was Twitter → booth → pixiv → ActivateDefault, then the next cycle reached Twitter; each once, no activation ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-final.log) | pass (title and uploader Buttons, Download and Add to favorites PopUpButtons, Read, Gallery Infos, Give a Rating, Similar Gallery, tag chip, both section titles, both `Show All`, preview pages, Post Comment, tabs; Comments: Back, Post Comment); 2.2 / 2.5 / 2.6 not exercised: simulator speech-recognition asset fails (research § 4) ; walk 2 proper push native UI/Voice Control proxy labels are present; Comments native UI/VC is also captured. These are proxies, not spoken-command measurements ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-push-detail-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-push-detail-vc.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-comments-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-comments-vc.txt) | pass; the `Read` glyph is white on the accent again (pale under Dark + Increase Contrast): reverted item 5 of `16-CONTRAST-AUDIT.md § Visible-change review (2026-09-15)`, cited, not re-reported; Reduce Motion not exercised: `showsUserRating` needs the signed-in rating reveal (filmed in F8) and `showsFullTitle` changes nothing visible with the one-line fixture title ; walk 2 proper Detail display reviewed in eight bounded states; base/restored changed fraction 0.06%, not pixel-identical; AX5 header is complete while below-fold content is not asserted ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/task7-F3-Detail/) | `…/transcripts/f3-frontpage-to-detail.txt`, `…/transcripts/f3-detail-walk.txt`, `…/transcripts/r7-detail-preview-strip.txt`, `…/transcripts/w-detail-screenchange-2.txt`, `…/transcripts/w-detail-screenchange-3.txt`, `…/transcripts/f3-detail-headings.txt`, `…/transcripts/f3-detail-tags.txt`, `…/transcripts/f3-tag-point.json`, `…/transcripts/f3-detail-comments.txt`, `…/transcripts/f3-comments-walk.txt`, `…/transcripts/f3-comment-rotor.txt`, `…/transcripts/f3-comment-point.json`, `…/transcripts/f3-login-tag-rotor.txt`, `…/transcripts/f3-login-tag-point.json`, `…/transcripts/f3-detail-vc.txt`, `…/transcripts/f3-comments-vc.txt`, `…/display/F3/contact.png`, `…/display/F3-pass.txt` ; walk 2: proper push UI/VC, Detail display, and full Comments evidence ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-push-detail-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-push-detail-vc.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/task7-F3-Detail-pass.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-final.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-comments-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-comments-vc.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-comments-end.png) |
| F4 | VO-2; W-30 (a page element's number is never spoken; withdrawn: refuted by the recording, R13); W-38 (page 52 not reached and indicator/page mismatch; carried to 16-26); the two `Close` buttons and the slider end labels are the `deferred-items.md § Found during 16-18` items (cited); pages and their `Reload` buttons read in order; walk 2: hermetic forward reaches page 51/Reload, not page 52 ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-v2.log) | 1.7 pass: pre-focus `Read` → reader cover, `Screen Changed`, focus the current page (the reader opened at page 3, saved progress); 1.8 W-13: pre-focus the top `Close` → dismiss → focus the Detail back button, not `Read`; walk 2: upper Close → Screen Changed → Read focus confirmed ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-v2.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-close-after.png) | 1.9 pass: `Page, 3 of 48, adjustable`; Ctrl+Option+Up → `7 of 48`; Ctrl+Option+Down → `2 of 48`; walk 2: shown panel lower Close → endpoint 1 → Page 1 of 52; adjustment 1 → 6 → 1 ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-panel-shown.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-adjust-up.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-adjust-down.txt); 1.10 not exercised: hermetic pages fail at once, so no loading change is reached; 1.11 pass (pass-through taps) | W-11; W-12: the page's Actions are `Previous page`, `Next page`; its context menu's `Reload` (no mirror) is missing from the rotor; walk 2: Reload/Previous page/Next page rotor has no duplicates ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-reload-actions.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-page-rotor-prefocus.txt) | pass (Close, Live Text, Auto-Play, More, Reload, the lower Close, the `Page` slider; the two `Close` names are the deferred 16-18 item); 2.2 / 2.5 / 2.6 not exercised: simulator speech-recognition asset fails (research § 4); walk 2: Reader panel Voice Control/UI bounded ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-panel-vc.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-panel-ui.json) | pass (the panel stays capped at xxLarge by design); the page number and reload glyph are gray on the placeholder again: reverted item 8, cited; Reduce Motion pass (`ControlPanel.swift` `hiddenPanelOffset`): the panel rises over about 8 frames with it off and fades in place over about 4 frames with it on; walk 2: OFF moves the lower panel upward, ON keeps its position and fades ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/task7-F4-Reader-v2/motion-panel-show-off/; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/task7-F4-Reader-v2/motion-panel-show-on/; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-rm-v2-readbacks.txt) | `…/transcripts/vo2-reader-panel.txt`, `…/transcripts/f4-read.txt`, `…/transcripts/f4-read-prefocus.png`, `…/transcripts/f4-panel.txt`, `…/transcripts/f4-page-rotor.txt`, `…/transcripts/f4-panel-vc.txt`, `…/display/F4/contact.png`, `…/display/F4/motion-panel-show-rm-off/`, `…/display/F4/motion-panel-show-rm-on/`, `…/display/F4-pass.txt` |
| F5 | W-14; W-15; W-21; the Favorites list cells read one element each in visual order; walk 2: LOGIN Detail/Favorites bounded ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-detail-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-login-next12.txt) | 1.7 pass: pre-focus a list cell → Detail push, `Loading, ellipsis`, focus the `Favorites` back button; 1.8 not exercised: the favorite control opens no sheet or alert (it removes the favorite at once); walk 2: Detail focus/selected Remove from Favorites observed ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-detail-header.txt) | 1.9 not exercised: no adjustable control; 1.10 pass (`Loading, ellipsis` on push, then focus to the back button); 1.11 pass (pass-through taps on a cell and Back); walk 2: Detail/Favorites controls present, no activation; walked to the commit point; not committed (account safety): VoiceOver focus on `Favorited`, never activated ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-detail-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-favorites-ui.json) | not exercised: no tag chip, comment cell or download row walked in F5 (the logged-in tag chip is covered in F3) | W-15 (an invisible `Retry` Button is in the tree); otherwise pass (folder filter, Sort Order, More, the search field, cells; Detail: back, More, title, Download, Favorited, Read, Similar Gallery, Give a Rating, tag chips, section titles, Show All, pages, tabs); 2.2 / 2.5 / 2.6 not exercised: simulator speech-recognition asset fails (research § 4); walk 2: Favorites/Detail Voice Control trees retain named controls and no hidden Loading/Retry leak in the bounded states ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-favorites-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-favorites-vc.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-detail-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-detail-vc.txt) | pass (on the dark baseline; stars keep filled and outline shapes in grayscale); Reduce Motion not exercised: Favorites and `GalleryList` have no gated site in `ReduceMotionGatingSourceTests`; walk 2: Detail and Favorites display reviewed ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/task7-F5-Detail/; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/task7-F5-Favorites/contact.png) | `…/transcripts/f5-favorites.txt`, `…/transcripts/f5-favorites.png`, `…/transcripts/f5-favorites-leak-retry.png`, `…/transcripts/f5-detail.txt`, `…/transcripts/f5-favorites-vc.txt`, `…/transcripts/f5-detail-vc.txt`, `…/display/F5/contact.png`, `…/display/F5-pass.txt`; walk 2: bounded LOGIN Detail/Favorites, tag rotor and Watched evidence `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-detail-ui.json`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-detail-header.txt`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-detail-back-more.txt`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-login-tag-rotor-actions.txt`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-watched-login-next.txt` and `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-watched-login-prev.txt` |
| F6 | W-16; W-17; W-18; walk 2: Downloads row reached at 03:56:57.649 and its spoken summary was captured ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-final-v2.log) | 1.7 not exercised: no push in F6; sheet open pass: pre-focus a row stop → leading swipe → `Pages` → inspector, `Screen Changed`, focus `Close`; 1.8 W-13: `Close` → focus the `Downloads` heading, not the row; walk 2: `Pages` focus at 03:57:26.641, inspector `Close` at 03:57:57.171, and the same row returned at 03:58:14.927/.959 ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-final-v2.log) | 1.9 not exercised: no adjustable control; 1.10 not exercised: no loading or toast change on this surface; 1.11 pass (pass-through swipe and taps) | pass: Actions `Detail`, `Pages`, `Resume`, `Delete` on the row stops, `custom_actions` identical; the row's context menu for this state (Detail, Pages, Resume, Delete; Move and Update conditions false) has every item and none twice; swipe actions leading `Pages`, trailing `Delete` and `Resume` (revealed and closed; only `Pages` tapped); walk 2: Detail/Pages/Resume/Delete spoken once at 03:57:23.660/03:57:26.641/03:57:29.599/03:57:32.573 ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-final-v2.log) | W-16; Filters, the search field and tabs pass; 2.2 / 2.5 / 2.6 not exercised: simulator speech-recognition asset fails (research § 4); walk 2 fresh native UI/Voice Control proxy captured for the combined row ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-root-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-root-vc.txt) | pass (the paused badge keeps glyph and text in grayscale); the untinted `Pages` swipe disc is reverted item 5, cited; Reduce Motion not exercised: the gated sites need a row added or removed, or validation or progress running, which would need Delete or a running download; walk 2: eight display captures reviewed; the restored-vs-base changed fraction was 4.89% from row y211→176 and the scroll offset, so the pair is not pixel-identical ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/downloads-final; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display-downloads-final.log) | `…/transcripts/f6-downloads.txt`, `…/transcripts/f6-downloads.png`, `…/transcripts/f6-empty-state-sweep.txt`, `…/transcripts/f6-row-rotor.txt`, `…/transcripts/f6-row-point.json`, `…/transcripts/f6-row-point-date.json`, `…/transcripts/f6-swipe-leading.png`, `…/transcripts/f6-swipe-trailing.png`, `…/transcripts/f6-swipe-closed.png`, `…/transcripts/f6-pages.txt`, `…/transcripts/f6-downloads-vc.txt`, `…/display/F6/contact.png`, `…/display/F6-pass.txt`; walk 2: `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-final-v2.log`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/downloads-final/`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display-downloads-final.log` |
| F7 | W-19; the General form otherwise reads in visual order; walk 2: General translator rows bounded by actual VOT ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-general.log) | 1.7 pass: pre-focus `General` row → push → `Screen Changed`, focus `Language` (first form element; same as the Task 1 tracer); pop observation: pre-focus the `Setting` back button → pop → focus the `Setting` heading, not the `General` trigger; 1.8 not exercised: the toggle opens no sheet or alert; walk 2: General pop/toggle route bounded ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-root.log) | 1.9 not exercised: no adjustable control; 1.10 not exercised: no loading or toast change; 1.11 pass: with VoiceOver on and focus on `Detect Links from the Clipboard, Switch button, off`, a pass-through tap switched it on and re-focusing read `on`; set back off and read back `off` (value 0). No unexpected Activate event appeared in the log (R12 hazard); walk 2: toggle on/refocus and restored off are bounded ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-root-toggle-on-refocus.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-root-toggle-restored.txt) | not exercised: no tag chip, comment cell or download row in F7 | pass (the switches are CheckBoxes named by their text); 2.2 / 2.5 / 2.6 not exercised: simulator speech-recognition asset fails (research § 4); walk 2: General Voice Control tree retains named controls and the bounded toggle readback ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-root-general-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-root-general-vc.txt) | pass (rows wrap at AX5); Reduce Motion not exercised: the General `rowAnimation` needs the Tags Extension turned on, which starts a translator download F7 does not ask for; walk 2: General display reviewed ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/task7-F7-General/; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/task7-F7-General-pass.txt) | `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/t1-setting-general.txt`, `…/transcripts/vo3-general-pop.txt`, `…/transcripts/f7-general-cc05.txt`, `…/transcripts/f7-toggle-activate.txt`, `…/transcripts/f7-toggle-on.png`, `…/transcripts/f7-toggle-restored.png`, `…/transcripts/f7-general-vc.txt`, `…/display/F7/contact.png`, `…/display/F7-pass.txt`; walk 2: General/App Icon evidence `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-root.log`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-root-general-ui.json`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-root-general-vc.txt`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-appicon.log`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/task7-F7-General-pass.txt` |
| F8 | W-20; W-31; the Comments top reads Back, heading, `Post Comment`; walk 2: editor and rating shown-state bounded ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f8-comments.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f8-rating-shown.txt) | 1.7 not exercised: no push in F8 beyond F3's; sheet open pass: pre-focus `Post Comment` → sheet, `Screen Changed`, focus the editor; the sheet walks `Close`, `Post Comment` heading, `Done, dimmed`, editor; 1.8 W-13: `Close` (tapped by frame coordinates, away from `Done`) → focus the back button, not `Post Comment`; pop observation: Comments → Detail lands on the Detail back button; walk 2: editor focus named; Post Comment Back remains negative ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f8-comments.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-post-sheet-close.txt) | 1.9 not exercised: the revealed `Rating, 0.0 out of 5` control has no adjustable action (`deferred-items.md § Found during 16-19`, cited) and adjusting it would submit a rating, so no Ctrl+Option+Up/Down was pressed; 1.10 not exercised: no loading or toast change; 1.11 pass (pass-through taps on `Post Comment`, `Close`, `Give a Rating`); walk 2: pass-through controls retained without mutation ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f8-comments.log); walked to the commit point; not committed (account safety): nothing typed, `Done` and the stars never touched, the rating reveal closed by tapping `Give a Rating` again | not exercised: the comment-cell rotor is covered hermetically in F3; the logged-in cell was not rotored, to stay clear of vote actions (account safety) | pass (Comments: Back, Post Comment, tabs; Detail with the rating revealed: every control a Button or PopUpButton named by its text); the stars are one non-actionable element, the deferred 16-19 item; 2.2 / 2.5 / 2.6 not exercised: simulator speech-recognition asset fails (research § 4) ; walk 2: fresh Comments and Rating UI/Voice Control proxy evidence is bounded; proxy only, no spoken-command claim ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f8-comments-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f8-comments-vc.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f8-rating-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f8-rating-vc.txt) | pass (Detail with the rating revealed, dark baseline), with W-31 (Button Shapes draws an empty capsule where the uploader would be); the yellow stars are reverted item 5, cited; Reduce Motion pass (`DetailView.swift` `showsUserRating`): the reveal and the hide animate over 7–8 frames with it off and land in one frame with it on; walk 2: rating display and Reduce Motion reviewed ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/task7-F8-Rating/; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/task7-F8-Rating/contact.png) | `…/transcripts/f8-comments-vc.txt`, `…/transcripts/f8-post-comment.txt`, `…/transcripts/f8-post-sheet.png`, `…/transcripts/f8-post-closed.png`, `…/transcripts/f8-rating.txt`, `…/transcripts/f8-rating-prefocus.png`, `…/transcripts/f8-rating-revealed.png`, `…/transcripts/f8-rating-vc.txt`, `…/display/F8/contact.png`, `…/display/F8/button-shapes.png`, `…/display/F8/motion-rating-show-rm-off/`, `…/display/F8/motion-rating-show-rm-on/`, `…/display/F8/motion-rating-hide-rm-off/`, `…/display/F8/motion-rating-hide-rm-on/`, `…/display/F8-pass.txt`; walk 2: W-20 editor `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f8-comments.log`, rating `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f8-rating-shown.txt`, and F8 display/RM evidence under `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/task7-F8-Rating/` |

`…/` in the evidence cells stands for `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/`.
Every changed display setting was restored to its recorded baseline and read back after each flow
(`display/F1-pass.txt` … `display/F8-pass.txt`). Observations that match an item the owner reverted in
`cc05aca6` are cited to `16-CONTRAST-AUDIT.md § Visible-change review (2026-09-15)` and not re-reported.

**Rotor against `CONTEXTMENU=not-exposed` (OQ2).** The three action-bearing elements agree with the
16-13 record wherever a mirror exists: the signed-in tag chip lists exactly its menu's vote items
(`Vote Down`, `Vote Up`), the comment cell lists its link actions, and the download row lists `Detail`
(its `accessibilityAction` mirror) plus the swipe actions `Pages`, `Resume` and `Delete`, so every
context-menu item of that row state is present once. The one gap is on a site without a mirror, the
reader page: its context menu's `Reload` is not in the rotor (W-12). Where a view declares several
`accessibilityAction`s or menu items, VoiceOver lists them in reverse declaration order (W-11). Nothing
was activated.

**Run notes.**
- Task 2's precondition (`git log 401fee9d..HEAD -- AppPackage App ShareExtension` prints nothing) was
  false: the owner-directed commits `1507a65a fix(16): fixed white CategoryCell text` and
  `cc05aca6 fix(16): revert remaining visual a11y changes` changed app sources after Task 1. A first
  Task 2 walk on the installed `24bf5c10` build was superseded after the owner's visible-change review
  (`16-CONTRAST-AUDIT.md § Visible-change review (2026-09-15)`). Orchestrator ruling R12 (2026-09-15):
  build `cc05aca6` by each simulator's UDID, install over on `WALK_UDID` and `LOGIN_UDID`, and re-run
  Task 2 in full (candidates, the eight flows, the hide-idiom sweep from live greps at `cc05aca6`, the
  listening list and its check). Every verdict above and below comes from the `cc05aca6` walk; Task 1
  ran on `24bf5c10`. The superseded walk's files were moved, not deleted, to
  `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/superseded-24bf5c10/` (relative paths kept);
  Task 1's transcripts and the scripts stay in place.
- Build: the `cc05aca6` builds waited on the shared `xcodebuild` lock while an unrelated build was
  running (R1); the waiting wrapper was left to finish and no second build was started. Both builds
  succeeded, `plutil` printed `app.ehpanda.personal` for both products, and both installs were
  install-over (`audit/build-cc05-walk.log`, `audit/build-cc05-login.log`, `plutil-cc05-walk.txt`,
  `plutil-cc05-login.txt`).
- Hazard (R12): a background shell left by the superseded F7 step, waiting on standard input, stayed
  hung and was not killed; had it resumed it would have sent one Activate chord to `WALK_UDID`. No
  Activate event that this walk did not send appears in any `cc05aca6` log.
- Log stream stop (R11): in Task 1 the executor also ran a pattern `pkill` on `vot` log streams after
  stopping its own by PID; nothing matched afterwards, and whether another `vot` stream existed before
  is unverifiable. From then on only recorded PIDs were stopped.
- Method note: after a launch with VoiceOver off, `sim-use ui` returns an empty app tree; turning
  VoiceOver on and off again exposes it. The Voice Control proxy reads were taken after that toggle.
- F6 row source: plan step 1 as written (`EHPANDA_AUTOMATION_AUTO_DOWNLOAD_GID=3103480` with
  `EHPANDA_AUTOMATION_TAB=downloads`) showed one paused row. That row already existed on `WALK_UDID`:
  the superseded walk created it with `EHPANDA_AUTOMATION_GALLERY_URL` added, because the automation
  starts only on that gallery's Detail (`DetailReducer+Download.swift:170-179`). Nothing was started or
  deleted on `LOGIN_UDID`; the hermetic Detail's Download button reads the paused row's state.
- F8: the Post Comment sheet has a `Close` button, not `Cancel`; it was dismissed with `Close`, tapped at
  its frame coordinates away from `Done`, and nothing was typed.
- `LOGIN_UDID` Account screen: it displays cookie fields. It was never captured, dumped or recorded:
  the route to Account Configuration walked its top rows with VoiceOver and stopped on
  `Account Configuration` before the cookie section, and the row was tapped at its logged frame.
- Speaking rate: after a failed Actions search on the hermetic tag chip the rotor rested on
  `Speaking Rate`; it was moved to `Headings` with no value step, and the rate did not change.
- Screen evidence follows R9: where VoiceOver logs no `First element in app focus` line, the
  `Screen Changed` note plus the first FOCUS after it is the SCREEN evidence.
- Every `cc05aca6` log stream was stopped by its recorded PID (`vo.sh off`).

### Findings

`…/` stands for `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/`. VO-3b splits the General
pop observation out of VO-3, so that the Filters 1.8 row keeps its own route. The superseded walk's
toast-interruption candidate did not reproduce on `cc05aca6` (F2 1.10) and has no row.

| id | flow | qa id | what was observed (written description) | evidence | route | walk 2 |
|---|---|---|---|---|---|---|
| VO-1 | F1 | 1.3 | Reproduces on `cc05aca6`. A 40-step walk from Home's first element cycles the six hero cards and resets to the Home heading on every loop with no key pressed, so the Frontpage section and everything below is never reached linearly. The Headings rotor finds no heading below; the Containers rotor reaches the tab bar, and a backward walk from there reaches the sections (R6) | `…/transcripts/vo1-home-40.txt`, `…/transcripts/vo1-home-headings-rotor.txt`, `…/transcripts/vo1-home-containers-rotor.txt`, `…/transcripts/vo1-home-below-trap.txt` | fix | walk 2: `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-full60.log`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-full60.txt`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-heading-home-final-forward.txt`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-heading-home-final-prev.txt`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-hero-swipes` |
| VO-2 | F4 | 1.5 | Reproduces. With the reader panel shown and no slider preview, the walk from the lower `Close` to the page slider passes three silent unnamed 20 × 20 point elements and three page captions from the hidden slider preview (`ControlPanel.swift:214`, `:227`), then the first end label and the slider | `…/transcripts/vo2-reader-panel.txt`, `…/transcripts/f4-panel.txt` | fix | walk 2: lower `Close` at 03:20:40.966 → endpoint `1` at 03:21:05.366 → `Page` at 03:21:08.846, with no hidden preview stops; adjustment reached `6 of 52` and `1 of 52` ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-panel-shown.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-adjust-up.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-adjust-down.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-v2.log) |
| VO-3 | F2 | 1.8 | Reproduces. Search › More › Filters › `Cancel` does not return focus to `More`: from the root it lands on the `Search` heading; from the results it lands on the error toast. Candidate `visiblebodyMore` is carried to 16-26 sign-off; the original target remains unmet and is not accepted. | `…/transcripts/vo3-filters.txt`, `…/transcripts/f2-filters.txt` | owner (D-22): carried to 16-26 sign-off | — |
| VO-3b | F7 | 1.8 (observation) | General pop: focus lands on the `Setting` heading on `cc05aca6` (the Task 1 tracer on `24bf5c10` landed on the `Account` row), not on the `General` trigger; the other pops seen (Frontpage → inline `Home` title, Comments → Detail back button, results → toast) have the same shape | `…/transcripts/vo3-general-pop.txt`, `…/transcripts/f7-general-cc05.txt`, `…/transcripts/f1-frontpage-pop.txt`, `…/transcripts/f8-rating.txt` | accepted: (c) pop-back focus is an observation, not a checklist item | — |
| VO-4 | F3 | 1.2 | Reproduces. The stats strip reads counts with their units as separate phrases and decimals as "4 dot 50"; comment dates are read "N slash N slash N"; a comment body that is a URL is spelled out ("https colon slash slash …") | `…/transcripts/f3-detail-walk.txt`, `…/transcripts/f3-comments-walk.txt` | accepted: (a) verbosity from transcript text; no round-2 idiom shortens these without dropping information | — |
| W-5 | F1, F2, F3 | 1.4 | Section titles (`Frontpage`, `Toplists`, `Other`, `Recently Searched`, `Previews`, `Comments`) are spoken as "Button" with no heading trait; the Headings rotor on Detail finds no heading | `…/transcripts/vo1-home-below-trap.txt`, `…/transcripts/f2-root-keywords.txt`, `…/transcripts/f3-detail-headings.txt` | fix | walk 2: `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f2-root-toast-next.txt` / `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f2-root-toast-prev.txt` (Search heading bounded) |
| W-6 | F1 | 1.2 | A Frontpage list cell's utterance gives title, uploader, the word "Rating", page count, category and date, and only then the rating value ("4.5 out of 5"), so the value is separated from its name | `…/transcripts/f1-frontpage-walk.txt` | fix | walk 2: full Frontpage cell speech reaches Rating, pages, category, date and Button without next interruption ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-frontpage-full.log) |
| W-7 | F3 | 1.3 | The Detail preview strip is 40 linear stops (`Page 1` … `Page 40`) before the walk leaves it for `Comments`; it ends, so it is not a trap (R7) | `…/transcripts/r7-detail-preview-strip.txt` | accepted: (c) a finite strip that the walk leaves; an observation on walk length, not a checklist fail | — |
| W-8 | F3 | 1.3 | Once in the Task 2 walk, about 1 s after focus reached the uploader with no key pressed, VoiceOver logged `Screen Changed` and reset focus to `More`; two reproduction attempts (45 s idle each, two launch routes) logged nothing. The listening recordings (R13) reproduced it in 2 of 4 Detail launches: in L-2 focus reached the uploader at 20.09 s, `Screen Changed` at 20.86 s, focus `More` at 21.64 s; in L-5 at 17.88 s, 18.65 s and 19.43 s, so the reset follows about 0.77 s after focus reaches the uploader | `…/transcripts/f3-detail-walk.txt`, `…/transcripts/w-detail-screenchange-2.txt`, `…/transcripts/w-detail-screenchange-3.txt`, `…/listen/audio/run1/L-2.vot.log`, `…/listen/audio/run1/L-2.report.txt`, `…/listen/audio/run1/L-5.vot.log`, `…/listen/audio/run1/L-5.report.txt` | fix (was `deferred`; reproduced by the recording and moved, R13) | walk 2: reproduced uploader `02:49:37.524` → Screen Changed `02:49:38.302/.318` → More `02:49:39.095`; audio `28.01 s` → `29.60 s`, unresolved ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/L-2.vot.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/L-2.report.txt) |
| W-10 | F2 | 1.3, 1.8 | The error toast is first in the reading order of the Search screens: previous from the back button lands on it and stops, a forward walk from the field to the last tab never reaches it, and the results pop and the Filters `Cancel` land on it | `…/transcripts/f2-toast-trap.txt`, `…/transcripts/f2-search.txt`, `…/transcripts/f2-filters.txt` | fix | walk 2: `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f2-root-toast-order.log`; reachable and can move away, no dismissal claim |
| W-11 | F3, F4 | 1.6 | VoiceOver lists a view's actions in reverse declaration order: comment links (reverse of the body's link order), the signed-in tag chip (`Vote Down` before `Vote Up`, the menu declares Up first), the reader page (`Previous page` before `Next page`, declared Next first); `custom_actions` carries the same order | `…/transcripts/f3-comment-rotor.txt`, `…/transcripts/f3-comment-point.json`, `…/transcripts/f3-login-tag-rotor.txt`, `…/transcripts/f3-login-tag-point.json`, `…/transcripts/f4-page-rotor.txt` | accepted: (b) the order is the system's presentation of the declared actions, identical across `accessibilityAction` and menu-derived actions on three sites | walk 2: the first comment's Actions repeated Twitter → booth → pixiv → ActivateDefault in one complete cycle at 04:38:13.354–04:38:37.230, followed by the next-cycle Twitter at 04:38:44.133, with nothing activated ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-final.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-comments-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-comments-vc.txt) |
| W-12 | F4 | 1.6 | The reader page's context menu offers `Reload` (and Copy / Save / Save Original with an image URL), but the page has no `accessibilityAction` mirror and `Reload` is not in the rotor | `…/transcripts/f4-page-rotor.txt` | fix | walk 2: `Reload` at 03:22:28.203, `Previous page` at 03:22:31.162, `Next page` at 03:22:34.105, and `Activate` at 03:22:37.095, each once ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-v2.log) |
| W-13 | F4, F6, F8 | 1.8 | Dismissing a cover or sheet does not return focus to the control that opened it: reader `Close` → Detail back button (not `Read`); Pages inspector `Close` → `Downloads` heading (not the row); Post Comment `Close` → Comments back button (not `Post Comment`) | `…/transcripts/f4-panel.txt`, `…/transcripts/f6-pages.txt`, `…/transcripts/f8-post-comment.txt` | fix | walk 2: F4 reader upper Close returned to Detail `Read` at 03:37:59.308/.353/.785 in the root-v2 log; F6 row returned at 03:58:14.927/.959 in the F6 final log; F8 remains the negative Post Comment Back return ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-v2.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-final-v2.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-post-sheet-close.txt) |
| W-14 | F5 | 1.4 | The favorited control is spoken "Favorited, Button": the label names the state, activating it removes the favorite at once, and there is no selected trait or action wording | `…/transcripts/f5-detail.txt` | fix | walk 2: label `Remove from Favorites` and Selected trait observed; no activation (`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-detail-ui.json`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-detail-header.txt`) |
| W-15 | F5, sweep | 1.5, 2.1 | On Favorites (loaded) and on Watched (error shown), `GalleryList`'s loading view (`GalleryList.swift:72`) is read although nothing is loading, and on Favorites the error view (`:78`) is read too, with a focus ring on an invisible `Retry` over the list; Voice Control's tree carries that `Retry` | `…/transcripts/f5-favorites.txt`, `…/transcripts/f5-favorites-leak-retry.png`, `…/transcripts/f5-favorites-vc.txt`, `…/transcripts/sw-watched-login.txt` | fix | walk 2: Favorites has no Loading/Retry in the loaded route; Watched shows the visible NotFound/Retry state and has no Loading leak (`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-login-next12.txt`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-favorites-ui.json`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-watched-login-next.txt`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-watched-login-prev.txt`) |
| W-16 | F6 | 1.2, 2.4 | One download row is seven VoiceOver stops (cover, title, uploader, rating, status badge, category, date), and each is a Button named with the gallery title, so Voice Control shows seven identical names for one row | `…/transcripts/f6-downloads.txt`, `…/transcripts/f6-downloads-vc.txt` | fix | walk 2: one combined row reached with fresh UI and Voice Control proxy evidence; the seven row elements share the expected title naming ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-final-v2.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-root-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-root-vc.txt) |
| W-17 | F6 | 1.5 | The Pages inspector's cover is spoken "(null), Image" | `…/transcripts/f6-pages.txt` | fix | walk 2: Pages inspector forward reached Close → heading → title → author → rating → Paused → category → date with no `(null), Image` focus ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-root-pages.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-root-pages-forward.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-root-pages-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-root-pages-vc.txt) |
| W-18 | F6 | 1.4 | The inspector's `Downloaded (0), No Pages` group row is spoken with "selected" first (its checkmark glyph), although nothing is selected | `…/transcripts/f6-pages.txt` | fix | walk 2: `Downloaded (0), No Pages` was spoken at 04:28:39.021/40.121 without `Selected`; `Pending (156)` and `Failed (0), No Pages` were also reached, while no validating/spinner focus was observed ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-root-pages.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-root-pages-forward.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-root-pages-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-root-pages-vc.txt) |
| W-19 | F7 | 1.2 | `Enable Tags Extension` is two stops with the same name: the text, then the labels-hidden switch | `…/transcripts/f7-general-cc05.txt` | fix | walk 2: actual VOT has one Enable Tags Extension stop; UI/VC are auxiliary (`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-general.log`; `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-root-general-ui.json`; `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-root-general-vc.txt`) |
| W-20 | F8 | 1.4, 2.7 | The Post Comment editor has no name: it is spoken "Text field, Is editing" | `…/transcripts/f8-post-comment.txt` | fix | walk 2: `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f8-comments.log`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f8-comments-vc.txt`; editor named |
| W-21 | F5, sweep | 1.5 | Placeholder symbols are spoken by their raw symbol names (`questionmark.circle.fill`, `person.crop.circle.badge.questionmark.fill`) on Favorites, Watched and the signed-out screens | `…/transcripts/f5-favorites.txt`, `…/transcripts/sw-watched-login.txt`, `…/transcripts/sw-favorites-signedout.txt` | deferred: `deferred-items.md § Found during 16-24` item 2 (`ContentUnavailableView.symbol`) | — |
| W-22 | sweep | 1.4 | Watched signed out has no title element and no visible title, while signed in the same screen shows the `Watched` heading | `…/transcripts/sw-watched-signedout.txt`, `…/transcripts/sw-watched-login.txt` | owner (D-22): show the `Watched` navigation title in the signed-out state (before image `…/transcripts/sw-watched-signedout.png`) | — |
| W-23 | F3 | 1.2, 1.3 | The Detail stats strip reads column headers and values interleaved (two headers, then two values, then the rating group, two headers, two values), so a value is not next to its header. The recording confirms the order (L-4, 33–51 s: "FAVORITED", "LANGUAGE", "591, Times", "JA, Japanese", "110 Ratings, 4 dot 50", then "Rating, 4.5 out of 5"). Owner requirements (2026-09-16, verbatim): "favorited 591 times 這類 items 應該都一起唸而不是分開一個個 label 唸" (each column is one stop that reads its title, value and unit together, for example "Favorited, 591 times"); "語言的 abbr 不用唸出聲，是單純的視覺裝飾" (the language abbreviation is hidden as visual decoration) | `…/transcripts/f3-detail-walk.txt`, `…/listen/audio/run1/L-4.report.txt` | fix | — ; walk 2: L-4/L-5 stats focus evidence bounded; no additional Rating control claim ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/L-4.report.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/L-5.report.txt) |
| W-24 | F2 | 6.1 | The Search root keyword `Delete` glyph renders pale green that nearly vanishes in software grayscale | `…/display/F2/grayscale-software.png` | deferred: `deferred-items.md § Found during 16-25` item 2 | — |
| W-25 | sweep | 1.2, 1.4 | Torrent rows read their seed, peer and completion counts as bare numbers without meaning; the two zero counts produce no speech at all (a pause and "Actions available") | `…/transcripts/sw-torrents.txt` | fix | walk 2: each count has semantic speech, including Seeds 1, Peers 0, and Completed downloads 63 (`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-torrents-next.txt`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-torrents-prev.txt`) |
| W-26 | sweep | 1.5 | The Archives funds row exposes both coin glyphs by symbol name ("g.circle.fill", "C Circle") although `ArchivesView.swift:226` / `:234` mark them `accessibilityHidden(true)`; the GP balance of zero is silent and the credits balance is a bare number | `…/transcripts/sw-archives.txt` | fix | walk 2: GP balance 0 and Credits balance 2,246 are spoken; coin glyphs are not read (`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-archives-next.txt`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-archives-prev.txt`) |
| W-27 | sweep | 1.2 | Reproduces on `cc05aca6` (the row's severity dot is back to the pre-16-24 circle). Each App Activity Logs row is four stops: the dot spoken "Error", the timestamp, the category, the message | `…/transcripts/sw-activity-logs.txt` | fix | walk 2: `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-activity.log`; first seven combined rows only |
| W-28 | sweep | 1.2 | Reproduces on `cc05aca6`. On Login, each field is two stops with one name: the caption (`Username`, `Password`), then the field spoken by its placeholder | `…/transcripts/sw-login.txt` | fix | walk 2: `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-login.log`; caption hidden, one editable field stop |
| W-29 | F1, sweep | 1.7 | When a loading view gives way to content, focus moves to the element that now sits where the loading view was, not to the first element: the second Frontpage cell; `Create New` in the middle of Account Configuration | `…/transcripts/f1-home-to-frontpage.txt`, `…/transcripts/sw-ehsetting.txt` | fix | walk 2: Frontpage reaches the first fixture gallery; EhSetting reaches Selected Profile (`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-frontpage.log`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-ehsetting-load-focus.txt`) |
| W-30 | F4 | 1.4 | Task 2 read a reader page element as silent: its label is the page number and the `vot` log shows no spoken string for it (a pause and "Actions available"). The recording refutes it (R13): in L-7, focus on page element `4` at 31.53 s produced an audible "Four", and page `3` produced "Three"; the log has no `Post-processed string` line for those utterances, so only the log missed the number | `…/transcripts/f4-read.txt`, `…/listen/audio/run1/L-7.vot.log`, `…/listen/audio/run1/L-7.report.txt`, `…/listen/audio/clips/10-reader-page-number.m4a` | withdrawn: refuted by the recording (R13) | — |
| W-31 | F8 | display pass (Button Shapes) | With Button Shapes on, an empty capsule appears under the Detail title: the uploader Button renders with an empty label when the gallery has no uploader (`DetailView+HeaderSection.swift:387`); VoiceOver skips it | `…/display/F8/button-shapes.png`, `…/display/F8/contact.png` | accepted: owner scope is limited to the empty uploader button capsule under Button Shapes; no other blank control is accepted | walk 2: owner accepted the existing empty Button Shapes capsule within the recorded scope; no new runtime measurement was made |
| W-32 | listening (L-5) | 1.2 (speech) | A comment author and body in Chinese are read with mixed voices: the author is split across zh-CN Tingting, ja-JP Kyoko and zh-CN, with 「斯」 mispronounced; 「真的美」 is read by ja-JP Kyoko with Japanese readings (L-5, 229–237 s). Owner: "我個人覺得 author, comment author, comment 這種 ugc 沒有辦法避免，都可以接受" | `…/listen/audio/run1/L-5.report.txt`, `…/listen/audio/run1/L-5.en-US.json`, `…/listen/audio/clips/07-chinese-comment.m4a` | accepted: user content spoken by the system voice | — |
| W-33 | listening (L-6) | 1.2 (speech) | A comment's time is heard as "four thirty two" with no "PM". The date and time are app-authored (a formatted value); the spoken string carries U+202F (narrow no-break space) before "PM" (`4:32\u202fPM` in the `vot` log), but that this character is why "PM" is dropped is unproven | `…/listen/audio/run1/L-6.vot.log`, `…/listen/audio/run1/L-6.report.txt`, `…/listen/audio/clips/06-comment-time.m4a` | fix | walk 2: bounded audio retained the date/time string at 02:57:22.562; audio interval 354.06–368.92 s and clip evidence are preserved, but no listening acceptance is claimed. A later short clip preserves the same phrase source at 359.350–363.300 s (3.950 s, normal speed, unaltered); its ASR is machine positioning only, not owner acceptance ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/L-5.vot.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/L-5.report.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/clips/w33-date.m4a; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/clips/w33-time-short.m4a; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/clips/w33-time-short-provenance.md) |
| W-34 | listening (L-5 route, Detail) | 1.2 (speech) | File-size units are spoken as letters: "MiB" is heard as "M I B". Owner: "MiB 確實被唸成三個獨立字母". App-authored; a fix changes the spoken unit only, not the visible text (orchestrator default, R13; the owner may veto) | `…/listen/audio/run1/L-5.report.txt`, `…/listen/audio/clips/04-file-size-gallery-infos.m4a` | fix — owner phonetic verification passed 2026-09-17 | walk 2: bounded audio retained File Size at 02:52:42.067; audio interval 73.56–77.48 s and clip evidence are preserved. The owner later judged “Mebibytes 聽起來沒錯”; this confirms the implemented W-34 fix only and does not accept the uncertain W-33 PM pronunciation ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/L-5.vot.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/clips/w34-file-size.m4a) |
| W-35 | owner report (Detail) | 1.7 | After Detail opens, VoiceOver focus goes to the `More` button first, not to the gallery title. Owner: "進入 detail 後的焦點不在標題而是先到 more button"; target stated by the owner: the title | `…/transcripts/f3-detail-walk.txt`, `…/listen/audio/run1/L-2.vot.log` | fix | walk 2: first Detail focus still reaches More and remains below the title target; same L-2 evidence ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/L-2.vot.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/L-2.report.txt) |
| W-36 | listening (L-4) | 1.2 | The stats strip speaks the rating twice in two forms: "110 Ratings, 4 dot 50" and then "Rating, 4.5 out of 5" (L-4, 33–51 s). Same scope as W-23 | `…/listen/audio/run1/L-4.report.txt` | fix | — ; walk 2: L-4/L-5 stats focus evidence bounded; no additional Rating control claim ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/L-4.report.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/L-5.report.txt) |
| W-37 | F3 | 1.4, 2.7 | On a gallery with no uploader the Detail header still draws an uploader `Button` with an empty title, and it is exposed to VoiceOver with an empty name. Found in the Button Shapes display pass beside W-31, which is the same control seen as a visible defect (the empty capsule); this row is the semantics half, which a fix can close without changing what is drawn | `…/display/F8/button-shapes.png`, `…/display/F8/contact.png` | fix (authorised as a semantics-only fix, orchestrator Task 5 reply 2026-09-16) | walk 2: `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-detail-ui.json`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/task7-F5-Detail/`; no unnamed uploader |
| W-38 | F4 | 1.2, 1.3 | The hermetic Reader route labels 52 pages, but the complete forward walk stops at page 51/Reload; the last repeated explicit-next does not reach page 52, and the panel indicator later shows `44 / 52` while the visible page is 51. The cause is unverified; source data only rules out an obvious source off-by-one and does not establish a runtime page-52 item | $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-hidden-full.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-v2.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-before-close-ui.json | fix (carried to 16-26 owner sign-off; not implemented) | walk 2: page 51/Reload terminal and `44 / 52` versus visible page 51 are recorded in `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-v2.log` and `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-before-close-ui.json`; unresolved, not accepted or system-owned |
### Hide-idiom sweep

Inventory from live greps at `cc05aca6` (orchestrator ruling R12). Paths below are
relative to `AppPackage/Sources/`; `…/` stands for
`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/`.

#### Sweep inventory

| command | raw count | swept rows | excluded rows |
|---|---|---|---|
| G1: `grep -rnE 'opacity\(' AppPackage/Sources --include='*.swift'` | 25 | 7 | 18 |
| G2: `grep -rnE '\.hidden\(\)' AppPackage/Sources --include='*.swift'` | 2 | 2 | 0 |
| G3: `grep -rnE 'visible\(' AppPackage/Sources --include='*.swift'` | 51 | 46 | 5 |
| G4: `grep -rnE 'accessibilityHidden\(' AppPackage/Sources --include='*.swift'` | 23 | 7 paired | 16 unpaired |

G4 unpaired (16): `AccountSettingView.swift:249`, `AppearanceSettingView.swift:40`, `AppearanceSettingView.swift:44`, `HomeView+Sections.swift:401`, `ViewModifiers.swift:63`, `TagSuggestionView.swift:100`, `DetailView+HeaderSection.swift:268`, `DetailView+HeaderSection.swift:373`, `TorrentsView.swift:178`, `FolderManagerView.swift:142`, `ArchivesView.swift:226`, `ArchivesView.swift:234`, `ReadingSettingView.swift:109`, `ReadingSettingView.swift:120`, `ReadingSettingView.swift:128`, `ReadingSettingView.swift:132`.

Changes against the planning-time counts: G1, G2 and G3 match the plan's 25, 2 and 51 (G3's 51 is 46
call sites, the declaration and four comment or doc lines, not the plan's 48 / 1 / 2). G4 is 23, not 24:
`cc05aca6` removed the `accessibilityHidden(true)` at `LaboratorySettingView.swift:72` with the on/off
marker it hid. Several sites moved lines with `cc05aca6` (for example `DetailView+HeaderSection.swift`
213 → 208, 223 → 218, 262 → 251, 270 → 259; `CommentsView.swift` 280 → 273; `GeneralSettingView.swift`
82 → 77, 93 → 88; `ReadingViewComponents.swift` 290 → 288, 295 → 293; `SubSection.swift` 122 → 114). The
rows use the `cc05aca6` lines.

#### Enumerated, not swept

| match | idiom | reason |
|---|---|---|
| `SettingFeature/SettingView.swift:146` `color.opacity(0.1)` | G1 | alpha on a colour value (row press background) |
| `SettingFeature/Components/LaboratorySettingView.swift:52` `tintColor.opacity(0.2)` | G1 | alpha on a colour value |
| `SettingFeature/Login/LoginView.swift:45` `Color(.systemGray2).opacity(0.2)` | G1 | alpha on a colour value (wave fill) |
| `SettingFeature/Login/LoginView.swift:46` `Color(.systemGray).opacity(0.2)` | G1 | alpha on a colour value (wave fill) |
| `SettingFeature/Login/LoginReducer.swift:69` `.primary.opacity(0.25) : .primary.opacity(0.75)` | G1 | alpha on a shape-style value (button colour) |
| `ReadingFeature/Support/LiveTextView.swift:24` `.color(.black.opacity(0.1))` | G1 | alpha on a colour value (canvas fill) |
| `ReadingFeature/Support/LiveTextView.swift:70` `.color(.accentColor.opacity(0.6))` | G1 | alpha on a colour value (canvas fill) |
| `GalleryListComponents/DownloadBadgeLabel.swift:25` `badge.color.opacity(0.15)` | G1 | alpha on a colour value (badge background) |
| `AppComponents/CategoryView.swift:214` `tileColor.opacity(isFiltered ? Self.excludedOpacity : 1)` | G1 | alpha on a shape-style value (tile colour) |
| `DetailFeature/DetailView+HeaderSection.swift:241` `downloadButtonTint.opacity(0.18)` | G1 | alpha on a shape-style value (ring track stroke) |
| `DetailFeature/Archives/ArchivesView.swift:258` `.gray.opacity(0.5)` | G1 | alpha on a colour value |
| `DetailFeature/Archives/ArchivesView.swift:387` `.white.opacity(0.5) : .white` | G1 | alpha on a shape-style value (foreground) |
| `DetailFeature/Archives/ArchivesView.swift:389` `Color.accentColor.opacity(0.5) : Color.accentColor` | G1 | alpha on a colour value (background) |
| `HomeFeature/GalleryCardCell.swift:85` `.opacity(0.2)` | G1 | can never be 0: literal `0.2` |
| `HomeFeature/HomeView+Sections.swift:214` `content.opacity(phase.isIdentity ? 1 : 0.6)` | G1 | can never be 0: branches `1` and `0.6` |
| `DetailFeature/Comments/CommentsView.swift:45` `$0.opacity(comment.commentID == store.scrollCommentID ? store.scrollRowOpacity : 1)` | G1 | can never be 0: branches `store.scrollRowOpacity` and `1`; `scrollRowOpacity` starts at `1` and is only set to `0.25` and `1` (`CommentsReducer.swift:145`, `:149`) |
| `AppComponents/ViewModifiers.swift:50` | G1 | doc comment text |
| `AppComponents/ViewModifiers.swift:62` `opacity(isVisible ? 1 : 0)` | G1 | the `visible(_:)` declaration itself |
| `ReadingFeature/Support/ControlPanel.swift:11` | G3 | comment text |
| `ReadingFeature/Support/ControlPanel.swift:27` | G3 | doc comment text |
| `AppComponents/ViewModifiers.swift:39` | G3 | comment text |
| `AppComponents/ViewModifiers.swift:61` `public func visible(_ isVisible: Bool) -> some View` | G3 | the declaration itself |
| `AppComponents/SubSection.swift:64` | G3 | doc comment text |

#### Swept sites

| site (file:line and the call as written) | idiom (G1/G2/G3) | paired accessibilityHidden | surface # | hidden state | reached how | before fix | after fix | evidence |
|---|---|---|---|---|---|---|---|---|
| `SettingFeature/AppearanceSetting/AppearanceSettingView.swift:159` `.opacity(isSelected ? 1 : 0)` | G1 | `accessibilityHidden(true)` `AppearanceSettingView.swift:160` | 33 | checkmark on an unselected app icon | `WALK_UDID` hermetic: Setting › Appearance › App Icon (five icons, one selected) | hidden | hidden | `…/transcripts/sw-app-icon.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-appicon.log |
| `HomeFeature/HomeView+Sections.swift:423` `Divider().opacity(showsDivider ? 1 : 0)` | G1 | — | 2 | the ranking row divider in the regular-width ranking layout | not reached | unreached: regular-width (iPad) layout only; this walk is iPhone only | unreached: regular-width (iPad) layout only; this walk is iPhone only | — |
| `HomeFeature/HomeView+Sections.swift:456` `Divider().opacity(offset == galleries.count - 1 ? 0 : 1)` | G1 | — | 2 | the last Toplists row's divider | `WALK_UDID` hermetic: Home, below VO-1 through the Containers rotor, backward walk through the Toplists rows | not an element (walk evidence) | not an element | `…/transcripts/vo1-home-below-trap.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-full60.log |
| `SearchFeature/SearchRootView+Keywords.swift:84` `Divider().opacity(keyword == keywords.last ? 0 : 1)` | G1 | — | 9 | the last recent keyword's divider (one keyword) | `WALK_UDID` hermetic: Search root after one search | not an element (walk evidence) | not an element | `…/transcripts/f2-root-keywords.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f2-root-toast-next.txt |
| `AppComponents/TagCloudView.swift:72` `Image(systemSymbol: .photo).opacity(0)` | G1 | `accessibilityHidden(true)` `TagCloudView.swift:74` | 14 | always (spacer under a translated tag's image overlay) | not reached | unreached: needs tag translation data with images (Tags Extension on and a translator download), which this plan does not start; the hermetic and `LOGIN_UDID` tag chips carry no translation image | unreached: needs tag translation data with images (Tags Extension on and a translator download), which this plan does not start; the hermetic and `LOGIN_UDID` tag chips carry no translation image | — |
| `AppComponents/ViewModifiers.swift:43` `.opacity(isVisible ? 0.5 : 0)` | G1 | `accessibilityHidden(true)` `ViewModifiers.swift:44` | 40 | a row's disclosure chevron with `isVisible` false | `WALK_UDID` hermetic: Search › More › Quick Search | unreached: no saved quick-search word, so no row exists (`Not Found`) | unreached: no saved quick-search word, so no row exists (`Not Found`) | `…/transcripts/sw-quicksearch.txt` |
| `AppComponents/TagSuggestionView.swift:108` `.opacity(0)` | G1 | `accessibilityHidden(true)` `TagSuggestionView.swift:114` | 9 | always (spacer under a suggestion's image overlay) | not reached | unreached: suggestions with images need tag translation data, which this plan does not download | unreached: suggestions with images need tag translation data, which this plan does not download | — |
| `SystemNotification/ToastMessageView.swift:43` `icon.hidden()` | G2 | — | 42 | always (balancing copy of the icon) | `WALK_UDID` hermetic: unsupported-link toast on Search | hidden | hidden | `…/transcripts/f2-toast-trap.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f2-root-toast-order.log |
| `SettingFeature/EhSetting/EhSettingView+Sections3.swift:159` `.hidden()` | G2 | — | 38 | always (the language column label) | `LOGIN_UDID`: Setting › Account › Account Configuration (read-only load), Headings rotor to Excluded Languages | hidden | hidden | `…/transcripts/sw-ehsetting-excluded.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-ehsetting-headings-select.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-ehsetting-headings.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-ehsetting-excluded-next.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-ehsetting-excluded-prev.txt |
| `SettingFeature/EhSetting/EhSettingView.swift:35` `$0.visible(store.loadingState == .loading \|\| store.submittingState == .loading)` | G3 | — | 38 | loaded, not submitting | `LOGIN_UDID`: Account Configuration after load | hidden | hidden | `…/transcripts/sw-ehsetting.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-ehsetting-load-focus.txt |
| `SettingFeature/EhSetting/EhSettingView.swift:41` `$0.visible(store.loadingState.is(\.failed))` | G3 | — | 38 | loaded | `LOGIN_UDID`: Account Configuration after load | hidden | hidden | `…/transcripts/sw-ehsetting.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-ehsetting-load-focus.txt |
| `SettingFeature/GeneralSetting/GeneralSettingView.swift:77` `$0.visible(setting.translateTags && tagTranslatorEmpty && tagTranslatorLoadingState != .loading)` | G3 | `accessibilityHidden(true)` `GeneralSettingView.swift:84` | 31 | Tags Extension off | `WALK_UDID` hermetic: F7 General | hidden | hidden | `…/transcripts/f7-general-cc05.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-general.log |
| `SettingFeature/GeneralSetting/GeneralSettingView.swift:88` `$0.visible(tagTranslatorLoadingState == .loading)` | G3 | — | 31 | translator not loading | `WALK_UDID` hermetic: F7 General | hidden | hidden | `…/transcripts/f7-general-cc05.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-general.log |
| `SettingFeature/Login/LoginView.swift:158` `$0.visible(store.loginState == .loading)` | G3 | — | 30 | not logging in | `WALK_UDID` hermetic: Setting › Account › Login, nothing typed | hidden | hidden | `…/transcripts/sw-login.txt` ; walk 2: blank Login reached Username/Password fields, then Downloads at 04:10:30.386 and Setting at 04:10:32.628; reverse reached Home at 04:10:56.219 without a loading element ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-login.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-account-boundary-v2.log) |
| `SettingFeature/AppActivityLogs/AppActivityLogsView.swift:26` `$0.visible(!store.displayedLogs.isEmpty)` | G3 | — | 32 | no logs | `WALK_UDID` hermetic: Setting › General › App Activity Logs | unreached: logs exist on `WALK_UDID`, so the list is shown | unreached: logs exist on `WALK_UDID`, so the list is shown | `…/transcripts/sw-activity-logs.txt` |
| `SettingFeature/AppActivityLogs/AppActivityLogsView.swift:31` `$0.visible(store.loadingState == .loading && store.displayedLogs.isEmpty)` | G3 | — | 32 | logs shown | `WALK_UDID` hermetic: App Activity Logs, forward and backward walks | hidden | hidden | `…/transcripts/sw-activity-logs.txt` ; walk 2: filtered loaded state kept one existing log; complete forward/reverse reached the field, Clear text, Close, combined log, tabs, and returned to the same field without a Loading stop ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-logs-filtered-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-logs-filtered.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-logs-filtered-forward.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-logs-filtered-reverse.txt) |
| `SettingFeature/AppActivityLogs/AppActivityLogsView.swift:38` `$0.visible(store.loadingState != .loading && store.displayedLogs.isEmpty)` | G3 | — | 32 | logs shown | `WALK_UDID` hermetic: App Activity Logs, forward and backward walks | hidden | hidden | `…/transcripts/sw-activity-logs.txt` ; walk 2: the same filtered loaded state retained one existing log, so no No Logs stop was reached; forward ended at Setting 04:22:12.869, and reverse returned to the text field at 04:22:38.492/.493 ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-logs-filtered-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-logs-filtered-forward.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-logs-filtered-reverse.txt) |
| `ReadingFeature/ReadingViewComponents.swift:270` `.visible(enablesLiveText)` | G3 | — | 24 | Live Text off | not reached | unreached: the Live Text overlay exists only on a loaded image; hermetic pages fail to load | unreached: the Live Text overlay exists only on a loaded image; hermetic pages fail to load | — |
| `ReadingFeature/ReadingViewComponents.swift:288` `$0.visible(loadingState != .loading)` | G3 | — | 24 | a page while it loads | not reached | unreached: hermetic pages fail at once, so no page is caught loading | unreached: hermetic pages fail at once, so no page is caught loading | — |
| `ReadingFeature/ReadingViewComponents.swift:293` `$0.visible(loadingState == .loading)` | G3 | — | 24 | a failed page | `WALK_UDID` hermetic: reader page walk | hidden | hidden | `…/transcripts/f4-read.txt` ; walk 2: bounded Reader evidence through page 51/visible panel state ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-v2.log) |
| `ReadingFeature/Support/ControlPanel.swift:54` `.visible(showsPanel)` | G3 | — | 25 | panel hidden | `WALK_UDID` hermetic: reader with the panel hidden | hidden | hidden | `…/transcripts/f4-read.txt` ; walk 2: bounded Reader evidence through page 51/visible panel state ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-hidden-end-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-hidden-full.txt) |
| `ReadingFeature/Support/ControlPanel.swift:109` `.visible(!showsSliderPreview)` | G3 | — | 25 | the lower `Close` while the slider preview shows | not reached | unreached: the preview shows only during a slider drag; VoiceOver adjustment does not show it | unreached: the preview shows only during a slider drag; VoiceOver adjustment does not show it | `…/transcripts/f4-panel.txt` |
| `ReadingFeature/Support/ControlPanel.swift:214` `.visible(checkIndex(page))` | G3 | — | 25 | preview slots inside the hidden preview | `WALK_UDID` hermetic: panel shown, no preview | leaks | hidden | `…/transcripts/vo2-reader-panel.txt`, `…/transcripts/f4-panel.txt` ; walk 2: bounded Reader evidence through page 51/visible panel state ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-panel-shown.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-adjust-up.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-adjust-down.txt) |
| `ReadingFeature/Support/ControlPanel.swift:227` `.visible(showsSliderPreview)` | G3 | — | 25 | preview not shown | `WALK_UDID` hermetic: panel shown, no preview | leaks | hidden | `…/transcripts/vo2-reader-panel.txt`, `…/transcripts/f4-panel.txt` ; walk 2: bounded Reader evidence through page 51/visible panel state ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-panel-shown.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f4-root-panel-ui.json) |
| `FavoritesFeature/FavoritesView.swift:47` `$0.visible(didLogin)` | G3 | — | 8 | signed out | `WALK_UDID` hermetic (no session): Favorites tab | hidden | hidden | `…/transcripts/sw-favorites-signedout.txt` ; walk 2: signed-out Favorites boundary reached `Favorites` at 04:03:06.653/04:03:07.396 and reverse heading at 04:04:08.752/04:04:09.550, confirming the hidden branch ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-favorites-boundary-v1.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f7-favorites-boundary-v1-reverse.txt) |
| `FavoritesFeature/FavoritesView.swift:52` `$0.visible(!didLogin)` | G3 | — | 8 | signed in | `LOGIN_UDID`: F5 Favorites | hidden | hidden | `…/transcripts/f5-favorites.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-login-next12.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-favorites-ui.json |
| `HomeFeature/HomeView.swift:73` `$0.visible(!store.popularGalleries.isEmpty)` | G3 | — | 2 | popular galleries empty | not reached | unreached: the fixtures always load the popular galleries | unreached: the fixtures always load the popular galleries | — |
| `HomeFeature/HomeView.swift:84` `$0.visible(store.popularLoadingState == .loading && store.popularGalleries.isEmpty)` | G3 | — | 2 | loaded | `WALK_UDID` hermetic: Home walks | hidden | hidden | `…/transcripts/vo1-home-40.txt`, `…/transcripts/vo1-home-below-trap.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-full60.log |
| `HomeFeature/HomeView.swift:96` `$0.visible(store.popularGalleries.isEmpty && error != nil)` | G3 | — | 2 | loaded | `WALK_UDID` hermetic: Home walks | hidden | hidden | `…/transcripts/vo1-home-40.txt`, `…/transcripts/vo1-home-below-trap.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-full60.log |
| `HomeFeature/HomeView.swift:127` `.visible(store.popularLoadingState != .loading)` | G3 | — | 2 | the Reload button while popular loads | not reached | unreached: the fixture load finishes before the first walk step | unreached: the fixture load finishes before the first walk step | — |
| `HomeFeature/HomeView.swift:128` `.overlay(ProgressView().visible(store.popularLoadingState == .loading))` | G3 | — | 2 | not loading | `WALK_UDID` hermetic: Home walks (Reload read, no progress stop) | hidden | hidden | `…/transcripts/vo1-home-40.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-full60.log |
| `HomeFeature/Watched/WatchedView.swift:37` `$0.visible(didLogin)` | G3 | — | 5 | signed out | `WALK_UDID` hermetic: Home › Other › Watched | hidden | hidden | `…/transcripts/sw-watched-signedout.txt` ; walk 2: signed-out Watched reached the visible login placeholder and Login at 04:25:02.276, then all five tabs through Setting at 04:25:19.396; reverse reached the Watched heading at 04:26:15.938 and Home back at 04:26:22.765 ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-watched-out-root.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-watched-out-root-forward.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-watched-out-root-reverse.txt) |
| `HomeFeature/Watched/WatchedView.swift:42` `$0.visible(!didLogin)` | G3 | — | 5 | signed in | `LOGIN_UDID`: Home › Other › Watched | hidden | hidden | `…/transcripts/sw-watched-login.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-watched-login-next.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-watched-login-prev.txt |
| `GalleryListComponents/GalleryList.swift:72` `$0.visible(loadingState == .loading)` | G3 | — | 3, 5, 8 | not loading | `WALK_UDID` Frontpage (hidden there); `LOGIN_UDID` Favorites (loaded) and Watched (error shown), where it is read | leaks | hidden | `…/transcripts/f1-frontpage-walk.txt`, `…/transcripts/f5-favorites.txt`, `…/transcripts/sw-watched-login.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-frontpage.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-login-next12.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-watched-login-next.txt |
| `GalleryListComponents/GalleryList.swift:78` `$0.visible(loadingState.is(\.failed))` | G3 | — | 3, 8 | not failed | `WALK_UDID` Frontpage (hidden there); `LOGIN_UDID` Favorites (loaded), where the error view and an invisible `Retry` are read | leaks | hidden | `…/transcripts/f1-frontpage-walk.txt`, `…/transcripts/f5-favorites.txt`, `…/transcripts/f5-favorites-leak-retry.png` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-frontpage.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-favorites-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-watched-login-next.txt |
| `AppComponents/StateViews.swift:41` `$0.visible(loadingState.is(\.failed))` | G3 | — | 3 | the list-end footer's `Retry` while not failed | not reached | unreached: the list end was not reached in the 70-cell Frontpage walk | unreached: the list end was not reached in the 70-cell Frontpage walk | — |
| `AppComponents/StateViews.swift:46` `$0.visible(loadingState == .loading)` | G3 | — | 3 | the list-end footer's spinner while idle | not reached | unreached: the list end was not reached in the 70-cell Frontpage walk | unreached: the list end was not reached in the 70-cell Frontpage walk | — |
| `AppComponents/SubSection.swift:97` `$0.visible(isLoading == true)` | G3 | — | 2 | section title not loading | `WALK_UDID` hermetic: Home sections | hidden | hidden | `…/transcripts/vo1-home-below-trap.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-full60.log |
| `AppComponents/SubSection.swift:114` `.visible(showAll)` | G3 | — | 2 | a section without `Show All` (`Other`) | `WALK_UDID` hermetic: Home sections | hidden | hidden | `…/transcripts/vo1-home-below-trap.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f1-full60.log |
| `DetailFeature/DetailView+CommentCells.swift:89` `$0.visible(comment.votedUp \|\| comment.votedDown)` | G3 | `accessibilityHidden(true)` `DetailView+CommentCells.swift:91` | 14 | comment not voted | `WALK_UDID` hermetic: Detail comment preview cards | hidden | hidden | `…/transcripts/f3-detail-walk.txt` ; walk 2: the Detail modal reached six 300 pt comment cards in linear traversal; no voted-state stop appeared, with Post Comment dimmed and the final terminal repeated; fresh Comments UI/VC/display evidence adds no separate voted-state stop ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-final.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-detail-end.png; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-comments-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-comments-vc.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-comments-end.png) |
| `DetailFeature/DetailView+HeaderSection.swift:208` `$0.visible(!galleryDetail.isFavorited)` | G3 | — | 14 | favorited | `LOGIN_UDID`: F5 Detail of a favorite | hidden | hidden | `…/transcripts/f5-detail.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-detail-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-detail-header.txt |
| `DetailFeature/DetailView+HeaderSection.swift:218` `$0.visible(galleryDetail.isFavorited)` | G3 | — | 14 | not favorited | `WALK_UDID` hermetic: fixture Detail | hidden | hidden | `…/transcripts/f3-detail-walk.txt` ; walk 2: the automation gallery Detail modal reached the header and action area, with no `Remove from Favorites` stop; Post Comment was dimmed and no action was activated ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-final.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-detail-end.png) |
| `DetailFeature/DetailView+HeaderSection.swift:251` `$0.visible(isDeterminate)` | G3 | — | 14 | the progress ring of a queued download | not reached | unreached: the ring shows only for an active or queued download; none is started (D-09 on `LOGIN_UDID`; the `WALK_UDID` row is paused) | unreached: the ring shows only for an active or queued download; none is started (D-09 on `LOGIN_UDID`; the `WALK_UDID` row is paused) | — |
| `DetailFeature/DetailView+HeaderSection.swift:259` `$0.visible(!isDeterminate)` | G3 | — | 14 | the spinner of an active download | not reached | unreached: the ring shows only for an active or queued download; none is started (D-09 on `LOGIN_UDID`; the `WALK_UDID` row is paused) | unreached: the ring shows only for an active or queued download; none is started (D-09 on `LOGIN_UDID`; the `WALK_UDID` row is paused) | — |
| `DetailFeature/DetailView.swift:162` `$0.visible(store.galleryDetail != nil)` | G3 | — | 14 | detail not yet loaded | `LOGIN_UDID`: F5 push from Favorites (full-screen loading, then the back button, no content stop) | hidden | hidden | `…/transcripts/f5-detail.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-login-next12.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f5-detail-ui.json |
| `DetailFeature/DetailView.swift:167` `$0.visible(store.galleryDetail == nil && store.loadingState == .loading)` | G3 | — | 14 | loaded | `WALK_UDID` hermetic: fixture Detail | hidden | hidden | `…/transcripts/f3-detail-walk.txt` ; walk 2: the already loaded Detail modal reached header through Comments with no Loading stop; this bounded modal does not claim a complete Frontpage push ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-final.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-detail-end.png) |
| `DetailFeature/DetailView.swift:178` `$0.visible(store.galleryDetail == nil && error != nil)` | G3 | — | 14 | loaded | `WALK_UDID` hermetic: fixture Detail | hidden | hidden | `…/transcripts/f3-detail-walk.txt` ; walk 2: the already loaded Detail modal reached header through Comments with no Error stop; this bounded modal does not claim a complete Frontpage push ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-final.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-detail-end.png) |
| `DetailFeature/Comments/CommentsView.swift:273` `.visible(comment.votedUp \|\| comment.votedDown)` | G3 | `accessibilityHidden(true)` `CommentsView.swift:274` | 16 | comment not voted | `WALK_UDID` hermetic: Comments walk | hidden | hidden | `…/transcripts/f3-comments-walk.txt` ; walk 2: reverse reached Post Comment 04:39:06.148, Comments heading 04:39:09.154 and Back 04:39:12.285; forward reached heading 04:39:29.541, Post Comment 04:39:32.595 and ten combined comments at 04:39:35.643, 38.672, 41.717, 44.943, 48.088, 51.284, 54.332, 57.370, 04:40:00.416, 03.449, followed by three terminal repeats with no voted-state stop ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-final.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-comments-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-comments-vc.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f3-root-comments-end.png) |
| `DetailFeature/Torrents/TorrentsView.swift:40` `$0.visible(store.loadingState == .loading && store.torrents.isEmpty)` | G3 | — | 20 | torrents loaded | `LOGIN_UDID`: Detail › More › Torrents (one torrent) | hidden | hidden | `…/transcripts/sw-torrents.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-torrents-next.txt |
| `DetailFeature/Torrents/TorrentsView.swift:49` `$0.visible(error != nil && store.torrents.isEmpty)` | G3 | — | 20 | torrents loaded | `LOGIN_UDID`: Detail › More › Torrents | hidden | hidden | `…/transcripts/sw-torrents.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-torrents-next.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-torrents-prev.txt |
| `DetailFeature/Archives/ArchivesView.swift:35` `$0.visible(!store.hathArchives.isEmpty)` | G3 | — | 19 | no archive options | `LOGIN_UDID`: Detail › More › Archives | unreached: the options loaded, so the content is shown | unreached: the options loaded, so the content is shown | `…/transcripts/sw-archives.txt` |
| `DetailFeature/Archives/ArchivesView.swift:40` `$0.visible(store.loadingState == .loading && store.hathArchives.isEmpty)` | G3 | — | 19 | options loaded | `LOGIN_UDID`: Detail › More › Archives, nothing activated | hidden | hidden | `…/transcripts/sw-archives.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-archives-next.txt |
| `DetailFeature/Archives/ArchivesView.swift:49` `$0.visible(error != nil && store.hathArchives.isEmpty)` | G3 | — | 19 | options loaded | `LOGIN_UDID`: Detail › More › Archives, nothing activated | hidden | hidden | `…/transcripts/sw-archives.txt` ; walk 2: $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-archives-next.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-archives-prev.txt |
| `DownloadsFeature/DownloadsView.swift:32` `$0.visible(showsEmptyState)` | G3 | — | 11 | one row present | `WALK_UDID` hermetic: F6 Downloads | hidden | hidden | `…/transcripts/f6-downloads.txt`, `…/transcripts/f6-empty-state-sweep.txt` ; walk 2: the complete forward/reverse Downloads route retained the row and did not expose the empty state ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-final-v2.log) |
| `DownloadsFeature/DownloadsView+Subviews.swift:143` `$0.visible(isValidating)` | G3 | — | 12 | not validating | `WALK_UDID` hermetic: F6 Pages inspector | hidden | hidden | `…/transcripts/f6-pages.txt` ; walk 2: no validating/spinner element was focused during the fresh inspector route; `Validate Image Data` remained dimmed and unactivated ($HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-root-pages.log; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-root-pages-forward.txt; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-root-pages-ui.json; $HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/task7-f6-root-pages-vc.txt) |

Counts: 55 swept rows (G1 7, G2 2, G3 46): 4 leak (`GalleryList.swift:72`, `:78`,
`ControlPanel.swift:214`, `:227`), 34 hidden, 2 not an element (walk evidence), 15 unreached.

**What the leaking sites have in common.** Each leaking `visible(false)` sits inside an ancestor whose
own `visible(_:)` is true at that moment, which applies `accessibilityHidden(false)` above it:
`GalleryList.swift:72` and `:78` leak on Favorites and Watched, where `GalleryList` is wrapped in
`FavoritesView.swift:47` / `WatchedView.swift:37` (`visible(didLogin)`, true when signed in), and are
hidden on Frontpage, where no such ancestor exists; `ControlPanel.swift:214` sits inside `:227`, which
sits inside `:54` (`visible(showsPanel)`, true with the panel shown). The unpaired G4 hides that fail the
same way fit the pattern: `ArchivesView.swift:226` and `:234` (the coin glyphs, W-26) sit inside
`ArchivesView.swift:35` (`visible(!store.hathArchives.isEmpty)`, true once options load). Nesting alone
does not predict a leak: `DetailView+HeaderSection.swift:208` and `:218` sit inside `DetailView.swift:162`
(true once loaded) and stay hidden. Other traits seen on the leaking views: `GalleryList`'s overlays are a
`ProgressView` (`LoadingView`) and a `ContentUnavailableView` (`ErrorView`); the leaking preview slots
hold an image whose frame height is 0 while the preview is hidden (the three silent 20 × 20 elements).

### Listening (owner)

Picked from the `WALK_UDID` transcripts of the `cc05aca6` walk. The spoken text stays in the evidence
root (`listen/items.tsv` carries it with the route, the chords and the expected focus prefix);
transcript paths are relative to `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/`.

| id | description | screen | route | transcript file and line |
|---|---|---|---|---|
| L-0 | calibration: the `Setting` title | Setting root | hermetic launch with `EHPANDA_AUTOMATION_TAB=setting`; previous item until `Setting` | `f7-general-cc05.txt:8-9` |
| L-2 | Detail header: the gallery title, then the uploader | Detail (fixture gallery) | hermetic launch with the fixture gallery URL; next items to the title, then to the uploader | `f3-detail-walk.txt:20-25` |
| L-4 | Detail rating group in the stats strip | Detail (fixture gallery) | hermetic launch with the fixture gallery URL; next items to the rating group | `f3-detail-walk.txt:80-81` |
| L-5 | a comment whose author and body are Chinese text (not a URL) | Comments | fixture gallery URL; next items to the Comments section, tap its `Show All`; next items to the comment | `f3-comments-walk.txt:37` |
| L-6 | a comment date read as "N slash N slash N" (VO-4 is `accepted`) | Comments | fixture gallery URL; next items to the Comments section, tap its `Show All`; next items to the comment | `f3-comments-walk.txt:34-35` |
| L-7 | the reader page slider after one adjustment | reader panel | hermetic launch; Home `Show All` → first Frontpage cell → `Read` → tap the page; next items to the `Page` slider; one Ctrl+Option+Up (the reader opens at the saved page) | `f4-panel.txt:28-37` |

Omitted: L-1 (a Frontpage cell with Japanese text), because the W-6 fix changes a cell's utterance; L-3
(the stats-strip language and file-size values), because the W-23 fix changes how the strip's values
and headers are read.

Run: `bash "$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/listen.sh"` (one item:
add its id, for example `L-5`). The script prepares `WALK_UDID` itself (boot, window, VoiceOver on)
and leaves VoiceOver on.

Check run (Task 2): `WALK_UDID` shut down with `xcrun simctl shutdown`, then
`env -i HOME="$HOME" PATH=/usr/bin:/bin /bin/bash "$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/listen.sh" --check`
→ `listen/check.log`: `SIM_USE /opt/homebrew/bin/sim-use`, `BOOTED CAE8CEE9-7C40-48D3-BE75-F0940B403DA8`, `VOICEOVER ON`, then `OK` for L-0, L-2, L-4, L-5, L-6 and L-7; no `MISMATCH` (2026-09-15, `cc05aca6`).

#### Owner reply (2026-09-16)

Task 3 was resolved by the owner's replacement of the method (orchestrator ruling R13). Instead of the owner
running `listen.sh` and listening to every item, the agent recorded the Mac's audio output for each item and
analysed it, and the owner listened only to the uncertain clips. Owner, verbatim: "還有不要用腳本開",
"你可以直接截取 audio output 來分析嗎？", "好", and "注意你錄製的方式 是要每個項目的過程都錄下來 這樣你可以無意中發現其他問題 還有避免 timelag 沒錄到".

Method. Tool `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/recorder/`: `ListenRecorder.app`
records through a Core Audio process tap and transcribes on-device with SpeechAnalyzer (en-US only);
`record-items.sh`, `analyze.py`, `focus-seq.py` and `summary.py` drive and analyse it. Each item was recorded
whole: a `vot` log stream spanning the recording, a 2 s pre-roll, the route driven by `listen.sh <id>` on the
`cc05aca6` install, and a 6 s post-roll. `analyze.py` matches every enqueued utterance against the recorded
sound (ffmpeg silencedetect) and the transcript, and lists every stretch of sound the log does not explain.
Evidence: `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/run1/` (L-0, L-2, L-4, L-5,
L-6 and a first L-7, which was a MISMATCH because the reader opened at saved page 4 and `next8` never reached
`Page`), `…/listen/audio/run1-L7b/` (the L-7 re-run, OK), and `…/listen/audio/clips/` (ten clips,
`index.json` with each clip's source item and time window, `listening-clips.m4a`). Per item: `<id>.caf`,
`.caf.start`, `.vot.log`, `.en-US.json`, `.report.txt`, `.report.json`. Audio stays in the evidence root and is
never committed.

Agent results. Every logged utterance had sound (no NO-AUDIO); the only sounds the log did not explain were
short screen-change and focus earcons. W-8 reproduced in 2 of 4 Detail launches (`### Findings` W-8). W-30 is
refuted: page numbers are spoken although the log shows no string for them (W-30). The stats strip reads
headers before values and speaks the rating twice (W-23, W-36). In L-5 (229–237 s) the Chinese author is split
across zh-CN Tingting, ja-JP Kyoko and zh-CN, and 「真的美」 is read by ja-JP Kyoko (W-32).

Owner findings sent before the recording (2026-09-16, verbatim):
- "進入 detail 後的焦點不在標題而是先到 more button"
- "favorited 591 times 這類 items 應該都一起唸而不是分開一個個 label 唸"
- "語言的 abbr 不用唸出聲，是單純的視覺裝飾"

Owner verdicts on the clips (2026-09-16, verbatim; clips 1–2 are L-2, 3 is L-4, 4–5 and 7 are L-5, 6 is L-6,
8–10 are L-7):
- "EhPanda 確實被唸成 Eh Panda，但不是 A panda"
- "Pokom, Non-H 我聽起來是準確的"
- "MiB 確實被唸成三個獨立字母"
- "infos 聽起來像 infus imageset 聽起來像 imagecent 沒錯，就跟 a panda 和 non-age 一樣，都是有模糊但在可接受範圍內"
- "four thirty two 沒聽到 PM"
- "囧斯诺聽起來怪怪的，「斯」發音錯誤，其他兩個字怪但是可以接受"
- "「真的美」是中文漢字，被當成日文漢字發音"
- "home 也是聽起來模糊但不是 palm，可接受"
- "我個人覺得 author, comment author, comment 這種 ugc 沒有辦法避免，都可以接受"

Resume-signal lines (the orchestrator's normalisation of the replies above, R13):

L-0=ok
L-2=ok
L-4=ok
L-5=unclear: 「斯」 mispronounced and 「真的美」 read with Japanese readings (comment author and body)
L-6=unclear: "four thirty two", no PM
L-7=ok

Findings from listening: L-5 → W-32 (`accepted: user content spoken by the system voice`); L-6 → W-33 (`fix`);
the MiB reply → W-34 (`fix`); the Detail first-focus report → W-35 (`fix`); the stats-strip replies → W-23
requirements and W-36 (`fix`).

### Design proposals (16-25)

`…/` stands for `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/`. Every variant below was a patch
under `…/vo2/` or `…/vo1/`, applied with `git apply`, built for `WALK_UDID` under the lock, installed over, walked
(the V6 layout-check builds were read without a walk), and reverted with `git apply -R`
(`git status --porcelain -- AppPackage` empty after each). None was committed. After the last variant
`WALK_UDID` was rebuilt from the unchanged sources and installed over again, with VoiceOver left off.

#### P-VO2

**Proven cause.** `visible(_:)` (`AppComponents/ViewModifiers.swift`) writes `.accessibilityHidden(!isVisible)`,
so a *visible* view writes `accessibilityHidden(false)`. When a visible ancestor does that and no scroll container
sits between it and a nested `visible(false)` (or `accessibilityHidden(true)`), the descendants that nested hide
hid are exposed again; a scroll container in between keeps them hidden (V6). In the reader, the lower panel
sits inside `ControlPanel.swift:54` `.visible(showsPanel)`; with the panel shown that ancestor writes `false`
over the slider-preview strip's own `visible(false)` (`:227`) and its slots (`:214`). Same walk each time
(`scripts/vo2-walk.sh`: reader fixture, tap the page, lower `Close`, 12 × next):

| variant | patch | change | walk result | transcript |
|---|---|---|---|---|
| V0 (baseline, `cc05aca6`) | — | none | leaks: three unnamed 20 × 20 stops at y 774, then three page captions, then the end label and the slider | `…/transcripts/vo2-V0-baseline-cc05.txt` |
| V1 | `…/vo2/V1-remove-slot-visible.patch` | remove the per-slot `.visible(checkIndex(page))` | still leaks, unchanged: the slots' own `accessibilityHidden(false)` is not the cause | `…/transcripts/vo2-V1.txt` |
| V2 | `…/vo2/V2-slot-image-color-clear.patch` | slot `PreviewImageView(…)` → `Color.clear`, same frame | the three unnamed stops are gone (they were the placeholder `ProgressView`s), but the three captions still leak: the `ProgressView` does not escape the hide on its own, it only adds elements | `…/transcripts/vo2-V2.txt` |
| V3 | `…/vo2/V3-panel-opacity-without-ancestor-accessibilityHidden.patch` | the panel's ancestor `.visible(showsPanel)` (`:54`) → `.opacity(showsPanel ? 1 : 0)`, no accessibility value on the ancestor | hidden: lower `Close` → end label `1` → `Page` slider, no spinner or caption stop | `…/transcripts/vo2-V3.txt` |
| V4 | `…/vo2/V4-visible-accessibilityHidden-isEnabled.patch` | the proposed fix: `visible(_:)` writes `.accessibilityHidden(true, isEnabled: !isVisible)` | hidden: the panel's show moves focus to the lower `Close` (same frame as V0, y 719.67), then end label `1` → `Page` slider → `156` → pages, no spinner or caption stop. Control walk with the panel hidden (no tap): no panel element is reachable, only the native toolbar `Close` / `More` and the pages | `…/transcripts/vo2-V4.txt`, `…/transcripts/vo2-V4-panel-hidden.txt` |
| V5 | `…/vo2/V5-scrollview-boundary-around-strip.patch` | tree as `cc05aca6`; `SliderPreivew(…)` (`:227`'s view) wrapped in `ScrollView(.horizontal) { … }.scrollDisabled(true)`, so a scroll container sits between `:54` and `:227` | hidden: lower `Close` → `1` → `Page` → `156` → pages. Confounded: the scroll view takes the strip's 0-point hidden height and clips the slots that overflow it in V0, and it leading-aligns the strip 10 points left (measured on V6a below). The `Close` focus frame the walk logged on show (y 769.67 against V0's 719.67) is not a layout change: the unchanged layout logs the same 769.67 on show while its laid-out frame is 719.67 (`…/transcripts/vo2-layout-M0.txt`), so that frame depends on when the panel's slide-in is sampled | `…/transcripts/vo2-V5.txt` |
| V6 layout check | `…/vo2/V6-layout-probe.patch` on V0, then with `…/vo2/V6a-scrollclipdisabled-with-layout-probe.patch` and `…/vo2/V6b-containerrelativeframe-with-layout-probe.patch` | throwaway `onGeometryChange` logs of the global frames of the lower `Close`, the strip, and each slot, slot image and caption, read after the panel's show | V0: `Close` 179, 719.67, 44 × 44; strip 18, 793.67, 366 × 0; slots y 784.22, 108.67 × 18.89 at x 28 / 146.67 / 265.33; captions y 788.78. V6a (V5 + `.scrollClipDisabled()`): every y identical, every x 10 points left. V6b (V6a + `.containerRelativeFrame(.horizontal)` on the strip): every probed frame identical to V0 | `…/transcripts/vo2-layout-M0.txt`, `…/transcripts/vo2-layout-V6a.txt`, `…/transcripts/vo2-layout-V6b.txt` |
| V6 | `…/vo2/V6-scrollview-boundary-layout-identical.patch` | V6b without the probe: `SliderPreivew(…)` in `ScrollView(.horizontal) { … .containerRelativeFrame(.horizontal) }.scrollDisabled(true).scrollClipDisabled()` | hidden, with the V0 layout: the panel's show moves focus to the lower `Close` at y 719.67, then end label `1` → `Page` → `156` → pages, no spinner or caption stop (two earlier runs were stopped part-way by an audio pause and are not counted) | `…/transcripts/vo2-V6.txt` |

V1 and V2 did not separate the cause, so V3 tested the common factor the sweep recorded (a leaking hide nested
inside a visible `visible(_:)` ancestor), and it separates it: removing only the ancestor's
`accessibilityHidden(false)` hides the strip. The same shape explains the other leaks: `GalleryList.swift:72` /
`:78` inside `FavoritesView.swift:47` / `WatchedView.swift:37` (hidden on Frontpage, which has no such ancestor),
and W-26's `ArchivesView.swift:226` / `:234` inside `ArchivesView.swift:35`. V3 also showed that with no
accessibility value on the ancestor the panel's show did not move focus to the lower `Close`, so the fix keeps
the hidden-state value.

**The Detail header sites (code).** `DetailView+HeaderSection.swift:208` / `:218` sit inside
`DetailView.swift:162`, which is true once loaded, and stay hidden. In code the difference is a scroll container:
`:162` is applied to the `ScrollView` of `DetailView.swift:50`, and both header hides are inside that scroll
view's content. Every leaking site has no scroll container between the visible ancestor and the hide:
`GalleryList.swift:72` / `:78` are overlays on `GalleryList`'s outer `VStack`, outside its list, and the ancestor
(`FavoritesView.swift:47` / `WatchedView.swift:37`) wraps that `GalleryList`; the reader strip (`:214` / `:227`)
and `:54` share one plain stack; the coin glyphs (`:226` / `:234`) are in `funds`, which `pinnedColumn` places
outside the grid's `ScrollView`, under `:35`. The other swept `hidden` rows under a true ancestor fit the same
line: `SubSection.swift:97` / `:114` are inside the `ScrollView` that `HomeView.swift:73` is applied to, and
`DetailView+CommentCells.swift:89` inside `:162`'s. The code predicts one more case not walked: at accessibility
sizes Archives uses `scrollingColumn`, which puts `funds` inside a `ScrollView`, so the coin glyphs should stay
hidden there. V5 put a scroll container between `:54` and `:227` and the strip stopped leaking, but V5 also clipped
and shifted the strip (table), so it did not separate the container from the clipping. V6 did: the same scroll
container with clipping disabled and a container-relative width, every probed frame identical to V0, and the strip
stays hidden. So the scroll container is the condition that separates `:208` / `:218` from the leaking sites. The
fix does not depend on it: V4 removes the ancestor's `false`, with or without a scroll container.

**Fix.** One modifier, `AppComponents/ViewModifiers.swift` `visible(_:)`: replace
`.accessibilityHidden(!isVisible)` with `.accessibilityHidden(true, isEnabled: !isVisible)`
(`View.accessibilityHidden(_:isEnabled:)`, iOS 18, present in the Xcode 26.6 SDK's SwiftUI interface with the
same `ModifiedContent<Self, AccessibilityAttachmentModifier>` result as today's call, so no call site's view type
or identity changes). A hidden view is still hidden exactly as now; a visible view applies no accessibility-hidden
value, so it can no longer override a descendant's hide. The doc comment gains the why (an ancestor's explicit
`false` re-exposes nested hides, V3). Measured as V4 on the reader panel: the strip is hidden, the panel's show
still moves focus to the lower `Close`, and the hidden panel is still unreachable. Per site under V4: reader
strip (`ControlPanel.swift:214` / `:227`) hidden; `GalleryList.swift:72` / `:78` unreached (their leaking state
needs `visible(didLogin)` true, that is a session, so neither Favorites nor Watched reaches it hermetically);
`ArchivesView.swift:226` / `:234` unreached (the sheet needs a session). No variant build is installed on
`LOGIN_UDID`, which holds the owner's session. For W-15 (`GalleryList`) and W-26 (the coin glyphs) the fix's
effect is therefore expected, not yet measured: Task 7's walk 2 on `LOGIN_UDID` (final HEAD, install-over)
verifies both. The regression's red/green runs and the Task 6 walk confirm the rest; if a site still leaks the
executor stops and reports rather than choosing another construct.

**Scope.** The shared modifier, which carries all 46 G3 call sites. Rows it is meant to change: every
`leaks` row of `### Hide-idiom sweep` (`GalleryList.swift:72`, `:78`, `ControlPanel.swift:214`, `:227`) and the
unpaired `ArchivesView.swift:226` / `:234` hides (W-26), whose ancestor is `ArchivesView.swift:35`; W-15 is the
`GalleryList` part. Every other swept row must stay as recorded (`hidden` / `not an element`), which Task 6's
after-fix sweep checks.

**Rendered layout.** None: opacity, frames and insertion are unchanged; only an accessibility attribute is
written differently. No `§ D-25 re-sweep` row.

**Regression.** `EhPandaUITests/AccessibilityAuditUITests.swift`, class `AccessibilityAuditUITests`, a new test
that opens the reader control panel with no slider preview (`showReadingControlPanel(in:)`), reads the `Page`
slider's frame, and asserts that `app.activityIndicators` has no element in the strip band (frame `minY` ≥
slider `minY` − 30 and `maxY` ≤ slider `minY`). Pre-fix signal, measured once with a throwaway method
(`…/vo2/signal-probe.patch`, run alone on `GATE_IPHONE` to `…/vo2/signal-probe.xcresult`, console
`…/vo2/signal-probe.log`, passed first try with no `Repetition` node, reverted): 40 activity indicators in the
app, 6 in the band (three distinct 20 × 20 frames at y 774.33, each listed twice; slider `minY` 801.33). The
band is 30 points because a 120-point window also caught 4 indicators of the Detail screen beneath the reader
(y 755 and 710). The first probe attempt did not build (a `single_line_trailing_closure` lint error in the
probe itself, `…/vo2/signal-probe-attempt1-lint.log`); no test ran. So the regression is red on the pre-fix tree
(6) and green at 0. An absence in the exposed hierarchy could also come from an unrelated change, so the `vot`
walk stays the confirming oracle.

**Effect on E-1.** `E-1.hidden-content` excludes the `sufficientElementDescription` reports on the strip's
`ActivityIndicator`s (×3 per iPhone run, ×5 on the iPad). V3 shows the strip was exposed, not merely walked while
hidden, so the reports are the leak itself. After the fix the matched count is expected to be 0 on both gate
devices; Task 6 removes E-1 only if both logs show zero with first-try runs, and otherwise keeps it with a
corrected reason. `16-CONTRAST-AUDIT.md § Automated audit (16-24)` "How the engine judges" item (2) reads the
strip as hidden; Task 6 corrects that sentence with these results.

**Regression, revised (2026-09-16).** The proposal's regression signal does not work, and the measurement that
shows it also shows the fix is correct. Runs, all on the one post-fix `build-for-testing` product (the app binary's
mtime equals that build's completion, and no build wrote to the same derived-data path between the two
`test-without-building` runs; the intervening `WALK_UDID` build used a separate `-derivedDataPath`):

| run | tree | result | evidence |
|---|---|---|---|
| regression, red | pre-fix (`50e8412d`'s tree) | fails: 6 activity indicators in the band, three distinct 20 × 20 frames at y 774.33 each listed twice, slider `minY` 801.33 | `…/audit/regression-red-iphone.xcresult`, `…/audit/regression-red-iphone.log` |
| regression, after the fix | `26625a78` | **still fails: 6, the identical frames** | `…/audit/regression-green-iphone.xcresult`, `…/audit/regression-green-iphone.log` |
| `testReadingControlPanelAudit`, `GATE_IPHONE` | `26625a78` | passes, `Repetition` nodes 0; ActivityIndicator `sufficientElementDescription` reports **0** (pre-fix ×3) | `…/audit/after-vo2-panel-iphone.xcresult`, `…/audit/after-vo2-panel-iphone.log` |
| `testReadingControlPanelAudit`, `GATE_IPAD` | `26625a78` | passes, `Repetition` nodes 0; the same reports **0** (pre-fix ×5) | `…/audit/after-vo2-panel-ipad.xcresult`, `…/audit/after-vo2-panel-ipad.log` |
| `vot` walk, `WALK_UDID` | `26625a78`, built by `WALK_UDID`, `plutil` printed the bundle id, installed over | V4 verbatim: lower `Close` (y 719.67) → end label `1` → `Page` slider → `156` → pages, no spinner stop and no caption stop | `…/transcripts/vo2-postfix-26625a78.txt` |

So `app.activityIndicators`, an XCUITest *element query*, enumerates elements that `accessibilityHidden(true)` has
removed from the accessibility tree, while `performAccessibilityAudit(for:)` and VoiceOver both respect it. An absence
assertion written through the element query therefore can never go green, and pins nothing: it reports the same count
on a tree where the strip is exposed and on one where it is not. The proposal's warning — that such an assertion "may
never go red" — named the wrong failure mode; the signal it chose is red unconditionally. Orchestrator decision D-A
(2026-09-16): the test is dropped, and VO-2's standing pin becomes `testReadingControlPanelAudit` with `E-1` retired.

#### P-VO1

**Instrumentation.** Only debug log lines at existing call sites of `HomeFeature/HomeView+Sections.swift`
`CardSlideSection` and `HomeReducer+Body.swift`: the content offset and the current `scrollPositionID` from the
`onScrollGeometryChange` transform, the handoff `pageIndex` write, every `onScrollPhaseChange` call (with
`scrollPositionID`), the idle `pageIndex` write, the rebase branch, the reducer's `cardPageIndex` change and both
edges of `allowsCardHitTesting`. No view or modifier was added. The section has no timer. Each build ran the same
walk (`scripts/vo1-walk.sh`: hermetic Home, VoiceOver on after launch, 3 × previous, 40 × next), and its log was
merged with the `vot` focus lines and every `Layout Changed` / `Screen Changed` note. The six fixture galleries
give a window block of 6 cards, one card pitch is 341.6 points, and one block is 2049.6 points.

| build | patch | change | walk result | evidence |
|---|---|---|---|---|
| 1 | `…/vo1/vo1-r16-build1-existing-call-site-logs.patch` | the log lines only | 3 resets to the `Home` heading (02:33:46.539, 02:34:09.659, 02:35:19.071) | `…/transcripts/vo1-r16b1.txt`, `…/transcripts/vo1-r16b1-app.log`, `…/vo1/r16b1-merged-timeline.txt` |
| 2 | `…/vo1/vo1-r16-build2-idle-scroll-anchor-sync.patch` | build 1 plus one change to the anchor: when the handoff fires while the scroll phase is idle, `scrollPositionID` moves to the id of the newly centred card (the id nearest the current anchor with that logical index); the phase is kept in a `@State` set by the existing `onScrollPhaseChange` | no reset in 3 previous and 40 next; no offset jump other than two rebase compensations | `…/transcripts/vo1-r16b2.txt`, `…/transcripts/vo1-r16b2-app.log`, `…/vo1/r16b2-merged-timeline.txt` |

**Proven cause.** VoiceOver's next and previous scroll the carousel themselves. That scroll moves the content offset
by one pitch and produces no scroll phase, so `scrollPositionID`, which SwiftUI updates only when a scroll phase
settles, keeps the id of the last phase-settled card. `scrollPosition(id:)` keeps that stale id's card in place
across the next content change, so a few steps later the offset jumps back to it and the card VoiceOver focused is
off screen; VoiceOver then drops focus to the screen's first element. In build 1 each reset is preceded by exactly
this event, and it appears nowhere else:

- 02:33:45.352 a next step moves the offset to 17381.27 with `scrollPositionID` 41 and no phase line; at
  02:33:45.368 the offset returns to 16014.87 (card 41, −1366.4) and the handoff writes `pageIndex` 3 → 5; focus is
  set at 02:33:45.391 on the card the step reached; reset at 02:33:46.539 (1.17 s).
- 02:34:08.468 → 02:34:08.483 the same, again back to card 41; reset at 02:34:09.659 (1.18 s).
- 02:35:17.888 → 02:35:17.903 the offset returns from 16698.07 to 14648.47 (card 55, −2049.6; same logical card, so
  no `pageIndex` write); reset at 02:35:19.071 (1.17 s).

The only other offset jumps in build 1 (02:33:12.235, 02:34:22.964, 02:34:48.988, 02:35:00.586) are rebase
compensations, logged in the same transaction as a phase change to idle and a rebase line; none is followed by a
reset. The rebase is therefore not the cause. `Layout Changed` arrives twice on every one of the 37 steps, reset or
not, and no `Screen Changed` arrives during the walk. `allowsCardHitTesting` goes false on every step and true
300 ms later, identically on reset and non-reset steps. Build 2 changes only the stale anchor and the resets stop,
with no jump-back left in its log. Build 2 also shows the second half of VO-1: without the reset, 40 next steps never
leave the carousel, because every step reaches another copy of the six cards in the sliding window, so the Frontpage
heading is still not reached linearly.

**Fix.** `HomeFeature/HomeView+Sections.swift`, `CardSlideSection` only:

1. Keep the anchor on the card VoiceOver scrolled to. A `@State` scroll phase, set at the top of the existing
   `onScrollPhaseChange`. In the existing handoff action, after the `pageIndex` write: if the phase is `.idle` (a
   scroll no gesture drives, which is VoiceOver's own scroll), set `scrollPositionID` to that card's id in the
   middle block, `windowBase + galleries.count * middleBlock + newValue`. The handoff transform keeps returning the
   logical index, so the rebase frame, whose geometry briefly pairs the new `windowBase` with the old offset, still
   never fires the action.
2. Give VoiceOver one pass of the galleries. Each card outside the middle block
   (`windowBase + count * middleBlock ..< windowBase + count * (middleBlock + 1)`) is hidden from assistive
   technologies with `.accessibilityHidden(true, isEnabled: !isInMiddleBlock)`, the same form P-VO2 gives
   `visible(_:)`, so a middle-block card writes no value. Linear navigation then reads the six galleries once and
   continues to the Frontpage heading, and previous from that heading returns to the last of the six. The rebase
   already keeps the settled card in the middle block, so the exposed six always include the centred card.

Part 1 writes the middle-block id, not build 2's nearest id. With part 2, VoiceOver only lands on middle-block
cards, and the nearest id would pick the neighbouring block's copy when previous from the Frontpage heading jumps
from the first card to the last. The combination is not built in Task 4, because R16 allows no new modifier on the
cards in a variant. Task 6's walk verifies it.

**The "`scrollPositionID` is never written during scrolling" invariant.** That rule exists so that no programmatic
write cancels an in-flight gesture or moves the window mid-flight. The fix adds a second bounded exception beside
the gallery-count sync: a write only while the phase is `.idle`, so never during a drag, deceleration or animation,
and only to the card the offset already shows, so nothing scrolls. The doc comments on `bufferedCards` and on the
handoff state both exceptions and why. The sliding window, `windowBlocks`, the `.idle` rebase,
`.viewAligned(limitBehavior: .always)` one-card paging, the peek dimming, `allowsCardHitTesting` and the Reduce
Motion behaviour are unchanged: the write carries no animation and moves nothing.

**Scope.** VO-1 only: `CardSlideSection`. No other carousel uses the sliding window.

**Rendered layout.** None: frames, offsets and opacity are unchanged; only the anchor value and an accessibility
attribute change. No `§ D-25 re-sweep` row.

**Regression.** Part 2: `EhPandaUITests/AccessibilityAuditUITests.swift`, class `AccessibilityAuditUITests`, a
new test on hermetic Home that reads the labels of the carousel's exposed card buttons and asserts each gallery
appears exactly once. Before the fix every card the lazy stack has built is exposed, including copies beyond the
six (build 1's first focus landed on a card two pitches left of the centred one), so a gallery is expected to
appear more than once. That count was not measured in Task 4, so Task 6 must see the test red
on the pre-fix tree before the fix commit, or record that no red signal exists. Part 1 has no runnable pre-fix
signal: XCUITest drives no VoiceOver navigation and cannot produce a scroll with no phase, so the `vot` walk is its
only oracle.

**Task 6 verification.** Install over on `WALK_UDID` and repeat the 40-step walk from Home's first element. It
passes if focus reaches the Frontpage heading, the Toplists heading and the tab bar with no `FOCUS` reset that no
key press caused, and previous from the Frontpage heading lands on the last card with no reset. Consecutive swipes
must still settle one card each and wrap to the first card after six swipes. Save both transcripts under `…/`.

**Part 2's pre-fix signal, measured (2026-09-16).** The proposal's premise is disproved, not merely unconfirmed.
A test written exactly as this section specifies — hermetic Home, read the labels of the carousel's exposed card
buttons, assert no gallery appears twice — **passed** on the pre-fix tree, printing `cards=5 distinct=5 repeated=0`
(`…/audit/regression-red-iphone.log`, the same run that measured P-VO2's red count). A read-only accessibility-tree
read of `WALK_UDID` on the same build agrees: three cards are exposed at rest, and still three distinct after eight
programmatic swipes. `LazyHStack` culls the copies it is not laying out, so two copies of one gallery never coexist in
a static XCUITest snapshot; the duplicate exposure VO-1 suffers is transient and produced by VoiceOver's own
traversal, which XCUITest cannot drive. The other reading of the assertion — that all six galleries are present —
is red before the fix *and* after it, because the fix hides the cards outside the middle block but cannot realise
cards the lazy stack never built. Neither reading yields red → green. The test was removed from the working tree
before `50e8412d`, so no part of it was committed.

Orchestrator decision D-B (2026-09-16): part 2 carries no XCUITest regression, and no green-only test is added in its
place. Its oracle is the `vot` walk, identical to part 1, and the plan's `<behavior>` items are the pass condition.

### Visible-change batch (16-25)

| id | visible change a fix needs | before image path | screens |
|---|---|---|---|
| W-22 | show the `Watched` navigation title in the signed-out state | `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/sw-watched-signedout.png` | Home › Other › Watched, signed out (#5) |
| W-31 | leave out the uploader line when the gallery has no uploader, which removes the empty capsule Button Shapes draws and its line | `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/display/F8/button-shapes.png` | Gallery Detail header (#14) |
| VO-3 candidate | carrying the existing More action into visible body content (`visiblebodyMore`) would alter visible placement and native menu order/traits; owner decision is required before implementation | `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/vo3-routebefore.png` (verified production-before Search-results toolbar surface; diagnostic body-menu images excluded) | Search results fixture, iPhone `.large` only; Search root and broader scope were not validated |

### Approved designs and decisions (16-25)

The orchestrator's Task 5 reply, received 2026-09-16 09:30 JST, verbatim:

> **P-VO2: approved as proposed.** Implement exactly the proposal's fix and scope: `visible(_:)` in
> `AppComponents/ViewModifiers.swift` writes `.accessibilityHidden(true, isEnabled: !isVisible)`, the doc comment
> gains the V3 why, and every other swept row stays as recorded.
>
> **P-VO1: approved as proposed, with three additions.**
> 1. Part 2 must have a **measured** pre-fix red run, recorded like P-VO2's: the bundle path and the measured
>    duplicate count. The proposal notes the count was never measured; measure it. If the test is not red on the
>    pre-fix tree, stop and report — do not proceed under "no red signal exists" for part 2. Part 1 keeps its
>    stated position that XCUITest can produce no pre-fix signal and the `vot` walk is its only oracle.
> 2. The proposal claims no rendered layout change. Verify it: capture hermetic Home's carousel at `.large` on
>    `GATE_IPHONE` before and after the fix in the same state, and compare. Only differences attributable to
>    asynchronous image loading are acceptable; anything else stops the fix and is reported.
> 3. The card-level `.accessibilityHidden(true, isEnabled: !isInMiddleBlock)` carries a doc comment naming it as
>    the same form P-VO2 gives `visible(_:)`, and the `bufferedCards` and handoff doc comments name both bounded
>    exceptions to the "`scrollPositionID` is never written during scrolling" invariant, as the proposal states.
>
> **W-22: authorised**, in three sites and no others. Activity Logs, Archives and Home are not in scope: the owner
> confirmed they do not exhibit the failure. The proven cause is a scrolling container held at `opacity(0)`.
>
> (a) `HomeFeature/Watched/WatchedView.swift`. Replace the `visible(didLogin)` fade plus `NotLoginView` overlay
> with a single `@ViewBuilder` content property that returns the `GalleryList` when signed in and `NotLoginView`
> when signed out, each with `.transition(.opacity)`, and `.animation(.default, value: didLogin)` applied to it.
> Neither state is held at `opacity(0)` any more. `.navigationTitle(.watched)` and
> `accessibilityNavigationTitleWorkaround()` stay exactly as they are — do not change the title mode, do not remove
> the workaround, do not add Reduce Motion gating (not in scope).
>
> (b) `FavoritesFeature/FavoritesView.swift`. The identical structural change, same shape. **The title is not
> touched**: `.toolbarTitleDisplayMode(.inlineLarge)` stays exactly as it is, and
> `accessibilityNavigationTitleWorkaround()` is **not** added. Per AGENTS.md § Accessibility navigation and search
> policy, designed `.inlineLarge` titles are measured independently and do not inherit the automatic-title
> fallback; Favorites is a designed `.inlineLarge` screen, not an accessibility-size inline screen. Keeping these
> two distinct is a hard requirement of this authorisation.
>
> (c) `SearchFeature/SearchRootView.swift`. Delete the `if store.historyKeywords.isEmpty && …` / `else` branch and
> the `navigationSubtitle(Text(verbatim: " "))` workaround, so the screen keeps one view identity in every state
> and the title keeps its full `.inlineLarge` size. Replace `SuggestionsPanel`'s ineffective
> `.frame(maxWidth: .infinity, maxHeight: .infinity)` (inside a `ScrollView`, `maxHeight: .infinity` collapses to
> the child's ideal height, which is 0 when all three sections are empty — that zero-height scroll content is why
> the title drops) with the repo's own established idiom from `AppComponents/NewDawnView.swift`: read the
> `ScrollView`'s height with `.onGeometryChange(for: CGFloat.self) { $0.size.height } action:` into a `@State`,
> and apply `.frame(maxWidth: .infinity, minHeight: containerHeight, alignment: .top)` to the panel.
> **`minHeight`, never a fixed height and never `containerRelativeFrame(.vertical)`** — a rigid viewport-height
> frame would pin content taller than the viewport and make it unreachable at accessibility sizes.
> `alignment: .top` is required: the default `.center` would vertically centre short content, which is a visible
> change. Add a doc comment stating why the min-height exists and that it is a floor, not a fixed height. This
> also removes a latent defect: the deleted condition ignored `quickSearchWords`, so a screen that had quick-search
> words but no history was given the blank subtitle and a shrunken title despite having content.
>
> **W-22 verification matrix (required; the owner asked for it explicitly).** Changing the Search root subcomponent
> can break its accessibility layout, so prove it did not, before and after, in the same states:
> - Devices: `GATE_IPHONE` and `GATE_IPAD`. Sizes: `.large`, AX3, AX5.
> - Search root states: **S1** no quick-search words and no history; **S2** quick-search words only, no history;
>   **S3** quick-search words plus history keywords plus history galleries.
> - 2 devices × 3 sizes × 3 states, captured on the pre-fix tree **and** after the fix, same seeds and same state.
> - Per cell: the navigation title is present, and its measured frame after the fix is the full `.inlineLarge`
>   size, never the subtitle-shrunken one; the first content row's top y is unchanged from before (no vertical
>   centring); the search field and drawer are unchanged.
> - **Clipping check, the real hazard**: in S3 at AX5 on both devices, scroll to the bottom and confirm the last
>   history gallery row is reachable and fully visible. If any content is unreachable, stop and report.
> - Worst-case viewport: repeat S3 at AX5 in landscape on both devices.
> - Live size change on Search root, `.large` → AX5 → `.large`, on both devices: the title survives, and view
>   identity survives (the typed keyword and scroll position are preserved), per AGENTS.md.
> - Watched and Favorites: capture signed-out and signed-in states before and after on `GATE_IPHONE` at `.large`
>   and AX5. Only the navigation title may differ before vs after; any other pixel difference stops the fix.
>   Do not use `LOGIN_UDID` for this — see the guards.
> - Record every cell and its evidence path in `16-SWEEP.md`, and add the `§ D-25 re-sweep` rows the plan's D-25
>   rule requires for any layout- or frame-changing fix.
>
> **W-31: carried to the 16-26 sign-off.** The uploader-line change is a visible change and stays unauthorised.
> Its before image path is already recorded in `### Visible-change batch (16-25)`.
>
> **New, authorised as a semantics-only `W-n` fix:** on a gallery with no uploader, the Detail header's uploader
> `Button` is exposed to VoiceOver with an empty name. Fix it without any visible change — e.g. exclude the
> control from the accessibility tree when the uploader is absent. If the only fix you can find alters what is
> drawn, stop, revert the edit, and route it `owner (D-22): carried to the 16-26 sign-off` with a before image
> path instead.

P-VO2: approved as proposed.
P-VO1: revised — approved as proposed with three additions: (1) part 2's regression must have a measured pre-fix red run recorded like P-VO2's, with bundle path and measured duplicate count, and if it is not red on the pre-fix tree the executor stops and reports rather than proceeding under "no red signal exists"; part 1 keeps its stated position that XCUITest can produce no pre-fix signal and the `vot` walk is its only oracle; (2) the "no rendered layout change" claim is verified by capturing hermetic Home's carousel at `.large` on `GATE_IPHONE` before and after the fix in the same state and comparing, where only differences attributable to asynchronous image loading are acceptable and anything else stops the fix and is reported; (3) the card-level `.accessibilityHidden(true, isEnabled: !isInMiddleBlock)` carries a doc comment naming it as the same form P-VO2 gives `visible(_:)`, and the `bufferedCards` and handoff doc comments name both bounded exceptions to the "`scrollPositionID` is never written during scrolling" invariant.
authorised: W-22 — the `Watched` title in the signed-out state, in three sites and no others (Activity Logs, Archives and Home are out of scope; the owner confirmed they do not exhibit the failure, and the proven cause is a scrolling container held at `opacity(0)`): (a) `HomeFeature/Watched/WatchedView.swift` replaces the `visible(didLogin)` fade plus `NotLoginView` overlay with one `@ViewBuilder` content property returning `GalleryList` when signed in and `NotLoginView` when signed out, each `.transition(.opacity)`, with `.animation(.default, value: didLogin)` on it, keeping `.navigationTitle(.watched)` and `accessibilityNavigationTitleWorkaround()` exactly as they are; (b) `FavoritesFeature/FavoritesView.swift` takes the identical structural change with its `.toolbarTitleDisplayMode(.inlineLarge)` untouched and no `accessibilityNavigationTitleWorkaround()` added; (c) `SearchFeature/SearchRootView.swift` drops the `historyKeywords.isEmpty` branch and the `navigationSubtitle(Text(verbatim: " "))` workaround and gives `SuggestionsPanel` the `NewDawnView.swift` min-height idiom (`onGeometryChange` height into `@State`, `.frame(maxWidth: .infinity, minHeight: containerHeight, alignment: .top)`), with the stated verification matrix and `§ D-25 re-sweep` rows.
authorised: W-37 — on a gallery with no uploader, the Detail header's uploader `Button` is exposed to VoiceOver with an empty name; fix it without any visible change (for example by excluding the control from the accessibility tree when the uploader is absent), and if the only available fix alters what is drawn, revert the edit and route the finding `owner (D-22): carried to the 16-26 sign-off` with a before image path instead.
carried to the 16-26 sign-off: W-31.

### W-22 color-difference acceptance amendment (2026-09-16)

The exact user-message time is unavailable. After being shown the matched `.large` and AX5 Favorites out pairs,
the user replied 「可以接受」. This accepts only the two recorded cells and conditions: native `1206x2622`, ROI
`[0,330,1206,2622]`, `.large` cross-build 325105 nonzero pixels with maximum RGB delta 3, AX5 cross-build 89381
nonzero pixels with maximum RGB delta 8, and same-version 1-vs-2 ROI comparisons at both sizes with zero
differences. It does not establish that the differences are natural system noise, approve a tolerance for other
cells, or mark W-22 complete.

### Continuation note (2026-09-16T02:13:24Z)

The owner authorised phase16 `xcodebuild` jobs to run concurrently with unrelated jobs, provided
phase16 keeps its mkdir lock and every invocation uses an isolated `$HOME/Library/Caches/ehpanda-phase16/`
`-derivedDataPath`, destination and evidence path. The walkthrough `xb2.sh` coordinator was updated accordingly:
it waits only for an xcodebuild using the same derived-data path or an explicitly matching `id=<UDID>` destination;
generic destinations do not create a device lock, and missing `-derivedDataPath` is rejected. The original script is
preserved at `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/scripts/xb2.sh.pre-parallel-20260916`.

The first P-VO1 test attempt accidentally ran the full `FeatureTests` plan instead of the approved only-testing scope.
It completed its recorded suites but failed with exit 65 at
`DownloadContinuedSessionHeartbeatTests.heartbeatIsIdleWithoutPendingWork()` after a simulator diagnostics timeout;
the evidence is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo1/featuretests-iphone.xcresult` and its
matching log. It was not retried.

The recorded failure still contained 13 passing `AppToolsTests` cases and 24 passing `HomeFeatureTests` cases,
with zero repetition nodes. The separately authorized heartbeat-fix run completed 489 tests across 84 suites,
with 8 known issues and zero repetition nodes; its result is `a0a2cbb3`. The full plan's exit 65 is retained and
is not described as a green run.

The escalated WALK preflight and install-over succeeded on the existing P-VO1 app. The original 40-step transcript
reached `Frontpage` at step 8 and `Toplists` at step 34, but remained on a first Toplists card at step 40, so the
original 40-step acceptance criterion is not marked passed. A same-build diagnostic walk reached the tab bar at
steps 54–58 (`Home`, `Favorites`, `Search`, `Downloads`, `Setting`) and was stopped at step 86 when `Setting` /
`Tab` / `5 of 5` repeated. No unsolicited focus reset was observed; the repeated end element followed explicit
next commands and is recorded as a boundary observation, not a reset. The exact heading-previous transcript reached
the last Frontpage hero card. After foregrounding the app again, six ordinary coordinate swipes each advanced one
hero card and the sixth returned to the same starting hero card; screenshots are retained
at `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo1/six-swipe-0.png` through `six-swipe-6.png`, with
time/non-synchronous rendering accounting for whole-image hash differences. Transcripts are retained at
`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/vo1-pvo1-validated.txt`,
`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/pvo1-diag120.txt`, and
`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/pvo1-previous-heading.txt`.

The first fresh `.large` pair was retained as a failed measurement because cold launch shuffled the six-card fixture.
The authorized measurement-only deterministic variant temporarily removed that shuffle for both builds, leaving all
other reducer and view bytes unchanged. On `GATE_IPHONE`, with content size `.large`, light appearance, increased
contrast disabled, the same fixed fixture order and initial card position were installed over and captured. Before
and after builds both succeeded (`DerivedData-PVO1-Before-Deterministic`, `DerivedData-PVO1-After-Deterministic`).
The before image hash is `464842639170f44a3a266ef1d38a8ab4f659c581622cb3f6bc98267230064491`; the after image hash is
`295eabb300431141d63518f397ca9d3718ae6286fe9a5d543936cc05d61542a0`. Frame inspection found no layout, text,
focus, or card-order change; the measured difference (`changed_fraction=0.07217472`, mean channel difference
`0.21640442`) is limited to asynchronous image rendering. The temporary reducer variant was restored to its
original SHA-256 `5b4eb50046160ee3b4a1f4ae27fd6a4a00ec2d7535ec93ba9ba1a0107fb87f78` and was not committed.

2026-09-16 P-VO1 verification amendment: the original 40-step walk remains recorded as not reaching the tab bar. With the unchanged six-card carousel and 24-card Frontpage fixture, the complete finite walk reaches Frontpage at step 8, Toplists at step 34, and the tab bar at steps 54–58, with zero unsolicited focus resets. Under the plan’s authority for the orchestrator to settle non-listening questions, this measured full traversal is accepted as the VO-1 no-trap oracle; no accessible item is removed, grouped merely to shorten the count, or hidden to meet the former sampling budget. Heading-previous, one-card swipes, six-swipe wrap, and the approved same-state layout comparison all remain required and have passed.

### Task 6 semantics progress (2026-09-16)

The completed semantics-only commits and their evidence are recorded here; actual VoiceOver walks remain pending Task 7 and no runtime closure is claimed.

| Commit | Scope and evidence |
|---|---|
| `6b7ef86a` | W-12 reader context actions; 37 cases (AppTools 13 + Reading 24), logs under `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w12/`. |
| `464d1584` | W-19/W-27/W-28 settings semantics; 73 cases (AppTools + Setting), logs under `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w19-w27-w28/`. |
| `772e8f85`, `1eb49e96` | W-14/W-20/W-23/W-25/W-26/W-36/W-37 Detail semantics (39 cases: AppTools 13 + Detail 26) and catalog formatting-only follow-up; logs under `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/detail-semantics/`. |
| `f811bf5e` | W-6/W-16/W-17/W-18 gallery/download semantics; 509 cases, 503 passed, 6 expected failures, 8 expected-failure nodes, 88 suites, zero Repetition; logs under `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w6-download-semantics/`. |
| `700db090` | W-34 binary size unit semantics; 39 cases, zero Repetition, 54-output smoke (6 locales × 3 units × 3 quantities), visible strings and copy values untouched; evidence under `$HOME/Library/Caches/ehpanda-phase16/round2/w34-file-size/`. |

VO-3 remains open. The only candidate shown to work is `visiblebodyMore`: a production design adopting it would move the existing toolbar action into visible screen content and therefore change native menu order/traits and visible layout; no owner visual authorization exists for that structural change. The diagnostic instead added a second body `More` control for comparison and did not move the production toolbar control. The candidate is carried to 16-26 sign-off. The measured scope was limited to Search-results fixture behavior at iPhone `.large`; Search root was not validated with the new candidate. The original toolbar focus target remains unmet and is neither fixed nor accepted.

W-8 latest runtime sample: one of four trials reproduced the transition. In v4, uploader focus was at 14:20:32.786, `Screen Changed` at 14:20:33.548, and `More` at 14:20:34.340. The timestamp extract is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/w8-v4-screenchange-extract.txt`; this is evidence only, with no proven root cause or fix claim.

W-22 Favorites gate update (2026-09-16): the `AppToolsTests` + `FavoritesFeatureTests` run failed once in `LoginReturnObservationTests.cookieLoginTriggersReloadWithoutAViewCallback()` — 18 cases, 17 passed, 1 failed, zero Repetition — with unexpected `.loginSucceeded` and `.fetchGalleries` at finish. The evidence is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/production-gates/module-app-favorites.log` and its xcresult. `CookieClient.importAutomationCookies` removes auth cookies before re-importing them (`CookieClient.swift:133–147`), while the Favorites observer emits on false→true (`FavoritesReducer.swift:124–138`); this supports, but does not runtime-prove, a true→false→true echo timeline because the log has no `didLogin` trace. The view-only W22 branch is not evaluated by the reducer TestStore. The failure remains recorded with no rerun or test changes; generic and AFTER work continue, and the closing full-FeatureTests run remains first-try work. The prior cross-target-pollution explanation is superseded and was only a hypothesis.

For phase16 builds, unrelated `xcodebuild` jobs may run concurrently. `xb2.sh` keeps the phase-local mkdir lock, waits only for the same derived-data path or an explicitly matching destination UDID, and requires an explicit derived-data path; a cache permission failure exits 98. It must not kill or interrupt other tests or daemons. Every evidence path above was verified to exist.

### Latest concurrency and focus diagnostics (2026-09-16)

The owner ruling 「xcodebuild 可以並行，找辦法解決，但不要打斷別的測試」 supersedes the earlier global single-`xcodebuild`/`pgrep` guard for resumed work. `xb2.sh` retains the phase mkdir lock, waits only for a matching derived-data path or explicit destination UDID, permits generic destinations to proceed without a device lock, requires `-derivedDataPath`, and exits 98 on cache permission failure. No phase job may kill or interrupt another test, test manager, daemon, or CoreSimulator process.

W-8 E2 remains diagnostic evidence only. In E2, the measured geometry was offset `-70` to `-48.667`, inset `70`, container `708`; uploader focus occurred at `15:13:09.979`, followed by `Screen Changed` at `15:13:10.744` and `More` at `15:13:11.526`. The source patch only added scroll telemetry and did not instrument state changes, so the absence of a recorded state change does not prove that none occurred. Evidence is in `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/variantF-e2-v1-vot.log` and `variantF-e2-v1-nslog.log`; the F1/F2 controls are `variantF-v1-vot.log`, `variantF-v1-nslog.log`, `variantF-v2-vot.log`, and `variantF-v2-nslog.log` in the same directory. W-8 has no proven root cause or fix. The W-35 default-focus implementation probe described in this historical E2 note was later withdrawn; W-35 remains open.

W-8 production bounded follow-up completed three idle trials of at least 45 seconds without reproducing an extra reset. The debugger summary and bounded LLDB record are `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/unresolved-focus/w8-production-debugger-summary.md` and `lldb-w8-production-bounded.log`; the five recorded stack timestamps (`09:49:21.393869`, `09:50:38.012919`, `09:50:40.614310`, `09:52:26.896183`, `09:52:29.559578` UTC) showed only the expected public notification push/pop. LLDB detached and quit. This does not cancel the earlier W-8 failure, establish a system-owned root cause, or validate a fix; W-8 remains pending.

The earlier F-body positive characterization was not supported by a verified actual/spoken return-focus pair and remains unverified. The focus binding remained `false` in those logs, which is not itself a runtime failure. It does not establish a root cause or close the remaining W-13 focus design.

### VO-3 paired Button/Menu runtime probes (withdrawn)

The paired Button and native Menu probes were temporary diagnostics and are withdrawn to baseline Search SHA `6a203123…`. Both builds succeeded: Button `21.069 s`, native Menu `20.506 s`. Button toolbar path recorded `toolbar setter 23:26:02.787` → `Back 23:26:03.608/.638`; body path recorded `body setter 23:28:57.417` → `Filters 23:28:58.230/.242`, then Home at `23:29:13.215`. Native Menu toolbar path recorded `toolbar setter 23:36:28.640` → `Back 23:36:29.456/.479`; body path recorded `body setter 23:39:22.306` → `More 23:39:23.103/.113`, then Home at `23:40:21.609`. These observations do not establish a production fix or owner acceptance. Evidence is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/paired-toolbar-body/root-runtime.log`, `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/paired-native-menu/root-runtime.log`, and `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/paired-native-menu/results.md`. The paired probe adds a second body `More` control for comparison; it does not move the production toolbar control. The Button body result is positive while its toolbar result is negative; the paired Menu has the corresponding toolbar/body observations. If this direction is selected for production, moving the control into visible content requires owner approval. W-13 Comments, W-35, and W-8 remain open separately.

VO-3 toolbar-local probe design (approved 2026-09-16): keep the existing shared `ToolbarFeaturesMenu` unchanged and limit the probe to `SearchView.swift`. `SearchView` owns an integer `restoreFocusRequest` state and increments it only from the existing Filters sheet's native `onDismiss`. The toolbar content remains an existing `ToolbarItemGroup`, whose content is a private screen-local `SearchToolbarMenu: View`. That view owns `@AccessibilityFocusState private var moreFocused: Bool`, receives `StoreOf<SearchReducer>` plus the request integer, and renders the native More `Menu` with the existing Date Seek, Filters, and Quick Search order and actions. Preserve the More label's icon-only and monochrome presentation, and attach the real focus binding to that rendered More control, not to the transient Filters menu row. On request changes, the local view sets `moreFocused = true`. This is a bounded hosting-scope hypothesis, not a proven root cause or validated fix; it adds no default focus, delay, task, onAppear, UIKit shim, or visible control, and does not change `SearchRootView`.

W-22/W-10 implementation scope approved for the next source pass: preserve the Search root viewport floor and stable identity while adding vertical intrinsic sizing to the SuggestionsPanel content before its existing `.frame(maxWidth: .infinity, minHeight: containerHeight, alignment: .top)`. The S2 AX5 evidence showed the second Quick row shrinking from `16,600,370x125` before to `16,600,370x63` after. Preserve the W-10 removal of the three toast forced-focus lines, and add `.accessibilitySortPriority(-1)` to the actual toast error `Group` so its button/text follow the main screen's linear reading order. The runtime evidence recorded a post-dismiss toast focus at `16:01:52.719` with spoken `Error` at `16:01:52.728`; the opened surface was QuickSearch, not Filters, and a first-element candidate is not an actual focus event.

The W-22 intrinsic-height and W-10 toast sort-priority edits remain uncommitted source changes. The W-13 Detail changes in `DetailView.swift` and `DetailView+HeaderSection.swift` also remain uncommitted; all three source areas are covered by the combined gate above. The W-22 S2 AX5 v2-before-fixedSize measurement was `125` → `63`; the v3 fixedSize measurement is still pending. The earlier F-body positive characterization was not supported by a verified actual/spoken return-focus pair and remains unverified; the toolbar focus diagnostic remained negative.

The corrected combined focus/layout gate used the existing incremental DerivedData. The retained first invocation omitted the `test` action and exited 64 with no cases; it is an invocation error, not a test failure. The corrected first-try run passed 55 cases across 12 suites (AppTools 13, Detail 26, Search 12, SystemNotification 4), with 0 failed, 0 expected failures, 0 skipped and 0 Repetition in 56.886 seconds. The required generic iOS Simulator build passed in 52.693 seconds. Evidence is under `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/combined-focus-layout-gates/`.

W-33's three approved Detail files are committed as `a12b9903` (`fix(16-25): spell out Latin day periods`); W-10's forced-focus removal and toast sort-priority change are committed as `c30fbe08` (`fix(16-25): keep toast after screen content`). The combined scoped module gate passed 43 cases across 11 suites with zero failures and zero Repetition in 76.571 seconds; the required generic Simulator build passed in 74.149 seconds. The 26-row locale preflight passed with zero failures (`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w33/preflight.log`). The earlier invocation exit 64 omitted the `test` action and ran no tests; it remains an invocation record, not a retry. Actual spoken pronunciation remains Task 7 work.

The W-10 semantic change is limited to the toast error Group's `.accessibilitySortPriority(-1)` and removal of its programmatic focus assignment; the existing announcement, action, and visual presentation remain unchanged.

W-22 AFTER verification remains open. The initial iPad AFTER S2/S3 AX3/AX5 captures read back `large` and are invalid for those size cells. A later `after-verified` batch was invalid because its launch omitted `EHPANDA_W22_STATE_DIR`, causing the temporary bootstrap to fail; those Home captures are not matrix evidence. A valid iPhone signed-in Watched parity pair uses `watched-parity-after-emptysearch-ui.txt` / `watched-parity-after-large.png` and `watched-parity-after-AX5-ui.txt` / `watched-parity-after-AX5.png`, with the query submitted before closing the search field so rows remain visible. iPhone live AX field height 44 differs from the BEFORE cold AX3/AX5 heights 96/124 and needs a matched cold-entry comparison; iPhone landscape and same-screen pixel calibration remain pending. The current iPad S2/S3 captures, iPad S3 AX5 Gallery9 bottom, and iPad landscape capture remain separately recorded, with invalid size provenance retained rather than promoted.

W-35 root-scope evidence remains measurement only: the first build exited 65 in `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w35-root-build.log`, and the corrected build passed in 49.701 seconds in `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w35-root-build-v2.log`. The two negative cold trials are `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/w35-root-cold2-vot.log` and `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/w35-root-cold3-vot.log`; the normal route was not completed, so no full-matrix or validated-fix claim is made. The rollback patch is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/w35/w35-root-scope-negative.patch`. The withdrawn VO-3 six-line trial likewise remains open without a validated fix. W-8 E2 remains correlation evidence only, with no proven root cause.

W-13 first-slice design approval (2026-09-16): on Detail Header, Read → Reader cover → dismiss returns focus to Read. DetailView owns private `@AccessibilityFocusState var readButtonFocused: Bool` and `@State var readingOrigin: ReadingOrigin?`, with origins `headerRead` and `inlinePreview`. Header receives a real `AccessibilityFocusState<Bool>.Binding` and binds it only to the existing Read button; Preview uses the real accessibility-focus-state host, never a constant binding or thin wrapper. The header Read action records `.headerRead` before the existing `openReading`; inline Preview records `.inlinePreview` before the existing `updateReadingProgress` / `openReading` order. The existing `fullScreenCover(item:onDismiss:content:)` keeps native dismissal; its `onDismiss` only sets `readButtonFocused = true` for `headerRead` and clears the origin. No destination `onChange`, delay, task, `onAppear`, UIKit shim, or `defaultFocus` is added, and visuals remain unchanged. Downloads, Comments and `PreviewsView` are separate scope. This is an approved minimal runtime probe design, not a validated fix; signature, Preview and existing-state ambiguities require a checkpoint.

### W-5 implementation and gate evidence (2026-09-16)

W-5 is a semantics-only fix for finding W-5. `AppPackage/Sources/AppComponents/SubSection.swift` adds
`.accessibilityAddTraits(.isHeader)` to `titleButton`; the existing button action, hit-testing condition,
frames, styles, child content and `ProgressView` remain unchanged. The fix is committed as
`a8cb5d53` (`fix(16-25): section heading traits`). It adds no D-25 re-sweep row because it cannot change
rendered layout or frames. The expected Headings rotor result is still a Task 7 walk2 observation and is
not marked passed here.

The first command attempt was an invocation syntax error: the `test` action was omitted, so Xcode exited 64
with `The flag -testPlan is only supported when testing` before any test started. Its log is retained at
`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w5/module-tests.log` and is not a failed test run.
After root authorization, the exact scoped command ran once with Xcode 26.6, GATE_IPHONE
`73E148DA-26E4-4892-8C8A-7EDC6725D0E7`, and isolated `DerivedData-W5`. `AppToolsTests` ran 13 tests,
`DetailFeatureTests` 26, `HomeFeatureTests` 24 and `SearchFeatureTests` 12: 75 tests total, passed, with
zero `Repetition` nodes. The result and log are retained at
`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w5/module-tests-v2.xcresult` and
`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w5/module-tests-v2.log`.

The follow-up Xcode 26.6 lint build also passed (`BUILD SUCCEEDED`) using the same isolated derived data;
its log is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w5/lint-build.log`. No test file was
changed, so no standalone test-file lint or build-for-testing was required. Later status: W-33's three
Detail files were committed separately as `a12b9903`, while W-10's three-line removal remains uncommitted;
`SearchView.swift` retains no VO-3 trial change because that six-line trial was withdrawn to HEAD. W-22's four temporary seed/bootstrap patches remain
strict-lint ready, with AFTER verification still pending for fresh size provenance and matched comparisons.
The phase remains executing and Task 7 walk2 is pending.

### Continuation corrections — 2026-09-16

W-13's earlier claim that WALK `pid=61210` crashed or showed a loading-error screen is withdrawn. The lifecycle audit identifies `pid=61450` as the explicit relaunch, and `w13-showall.png` is a normal Detail screen. The prior Reader return trial closed with VoiceOver off and is not a valid W-13 pass; evidence remains in `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/WALK/w13/w13-lifecycle-audit.log`.

W-22 v3's first build succeeded in 84.346 seconds, but its source was restored during execution, so its provenance is invalid for verification. The v3b root-complete wait exited 0 in 39.433 seconds and restored all five temporary files byte-exactly. Its iPhone cold S2 AX5 second row was complete (`16,600,370x125`, two lines) and confirmed in the PNG; the 18-cell matrix remains open.

W-29 remains a read-only proposal: target the first Frontpage gallery by stable gallery ID in both existing `GalleryList.swift:128–137` detail-mode and `:219–231` thumbnail-mode Buttons, and target the existing Account Configuration profile Picker at `EhSettingView+Sections1.swift:24–30`. A future probe must guard both `ehSetting` and `ehProfile` as nonnil, and distinguish a `filteredGalleries.isEmpty → non-empty` transition caused by user filtering from initial data arrival before focusing. An already-loaded entry needs no `initial: true`, and refreshes retaining content must not steal focus.

W-29 EhSetting slice approved for implementation: `EhSettingView` owns a private `@AccessibilityFocusState profilePickerFocused: Bool` and observes `store.ehSetting != nil && store.ehProfile != nil` without `initial: true`; only the `false → true` transition focuses. The real binding passes through `EhProfileSection` to the existing Selected Profile Picker, with `.accessibilityFocused` after `ehSettingPickerStyled`. The existing `@FocusState` for the name field remains separate. No delay, task, onAppear, defaultFocus, wrapper, or visual change is permitted.

W-29 Frontpage slice approved for implementation: `FrontpageView` owns private `@AccessibilityFocusState focusedGalleryID: String?` and observes `store.galleries.isEmpty` without `initial: true`; only `oldEmpty && !newEmpty` focuses `store.filteredGalleries.first.id`. `GalleryList` accepts an optional real `AccessibilityFocusState<String?>.Binding` defaulting to nil, falls back to its own private focus state when omitted, and passes that binding directly through both private list modes to each existing gallery Button using `equals: gallery.id`. Existing Button identity, style and actions remain unchanged. No filtered-list observer, delay, task, onAppear, defaultFocus, wrapper, or visual change is permitted.

W-29 module gates recorded: AppTools/HomeFeature/GalleryListComponents/SettingFeature completed 104 tests with 102 passed, 2 expected, 0 failed, 0 skipped, Repetition 0 in 65.607 seconds; generic build passed in 71.371 seconds. Comments completed 39 tests with 39 passed, 0 expected, 0 failed, 0 skipped, Repetition 0 in 54.001 seconds; generic build passed in 56.645 seconds. The LOGIN runtime build passed in 45.598 seconds for the W29 EhSetting and Comments evidence binary. At gate-recording time, runtime evidence was still pending; these figures are gate facts only.

W-29 bounded runtime evidence is recorded under `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w29/root-runtime/`. Frontpage detail mode reached the first gallery row with actual/spoken timestamps `18:19:18.180` / `.210` after the preceding Back actual/spoken `18:19:18.114` / `.138`; thumbnail mode reached its first selected gallery at actual/spoken `18:28:43.494` / `.529`, after Back actual/spoken `18:28:43.428` / `.450`. The empty-filter to cleared-filter capture retained the existing field focus and did not produce a new focus steal. LOGIN EhSetting selected the existing profile Picker at `18:30:39.989` (`Will set element`) and `18:30:40.050` (`Selected Profile`). The loaded Detail pop observation reached a first element at `18:24:24.053`; it is observation only and does not establish a second-row return or an Apple-native root cause. The source change was committed as `24f5847a` (`fix(16-25): focus newly loaded content`). UI batch coverage and Task 7 remain pending.

W-13 Comments slice approved for implementation: `CommentsView` owns a private Hashable `PostCommentOrigin` with `newComment` and `edit(String)` cases, a private `@AccessibilityFocusState` binding, and a `@State` origin. The existing toolbar Post Comment action records `newComment` before its original action and focuses that same Button after native sheet dismissal. Each existing editable comment swipe action records `edit(commentID)` before its original action, while the existing combined `CommentCell` row receives the real binding and focuses with `equals: .edit(commentID)`. Native sheet dismissal uses a defer to clear the origin; edit focus returns only when the same comment ID remains. No destination observer, delay, task, onAppear, defaultFocus, UIKit shim, visual change, posting/editing flow, or credential seam is included.

W-35s former implementation probe was withdrawn after runtime measurement; the finding remains open. The approved probe gave `DetailView` private `@AccessibilityFocusState titleFocused: Bool`; Header receives the real binding on its existing title Button; the outer DetailView observes `store.galleryDetail != nil` with `initial: true`, guards loaded state, then focuses the title. It covers nil-to-loaded and already-loaded entry, leaves nonnil-to-nonnil refreshes alone, and adds no defaultFocus, delay, task, onAppear, latch or UIKit shim. Its timing build passed in 62.935 seconds (`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w35-timing-build.log`). The instrumented root timeline showed fetch loaded `false` at `17:13:54.461`, loaded `true` at `17:13:55.724`, the loaded observer at `17:13:55.836`, title geometry at `17:13:55.837`, More actual at `17:13:56.010`, then title actual/spoken at `17:13:56.879` / `.890` and the title focus observer at `17:13:56.977`; the uploader was actual/spoken at `17:15:22.805` / `.806`, with no Screen Changed or reset during the following 45-second observation. The normal Home first-card → Detail path likewise logged fetch loaded `false` at `17:17:13.081`, loaded `true` at `.613`, the observer at `.688`, Home Back at `17:17:14.297` / `.363`, and the gallery title at `17:17:15.116` / `.118`. This is a late-title instrumented positive, not proof of first focus; the earlier production negative remains open. Evidence is retained under `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/w35-timing/root-runtime/`, including `phase16-w35-timing-root.log`, `phase16-w35-timing-cold.png`, and `timeline.txt`.
W-35 production follow-up confirms the late-title timing without instrumentation: cold Detail reached More at `17:41:39.667` / `.756`, then title at `17:41:40.587` / `.598`; uploader was actual/spoken at `17:42:03.127` / `.128`, followed by Screen Changed at `17:42:03.896` and More at `17:42:04.675` / `.692`. The normal Home first-card → Detail path reached Home Back at `17:44:17.248` / `.267` with spoken Back at `.740`, then title at `17:44:18.054` / `.056`. The cold and normal PNGs and bounded logs are retained under `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/w35-production-cold/` and `w35-production-home/`. The late-title observations do not close W-35, and the post-uploader Screen Changed keeps W-8 open for a scroll/navigation-layout diagnosis.

### W-13 root-runtime slice (2026-09-16)

The Detail W-13 slice was committed as `a90750a7` and has a valid root-runtime Read → Reader → toolbar Close → Read path from both a direct Detail entry and a normal Home Frontpage first-card → Detail entry. The final normal path recorded Read pre-focus at `16:46:02.683`, Reader toolbar Close at `16:46:41.622`, and post-dismiss actual/spoken Read at `16:46:48.561` / `16:46:48.572`. The earlier direct path recorded Close at `16:37:02.677` and post-dismiss actual/spoken Read at `16:37:09.563` / `16:37:09.573`. The inline-preview path remained in Detail and, after dismiss, actual focus landed on the Home-labeled Back button rather than Header Read (`16:38:17.845` prefocus; `16:39:19.897` / `.914` dismiss). Evidence is retained under `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/WALK/w13/root-runtime/`, including the root VOT log and PNGs. A rotated/frozen normal trial is retained as invalid; the device was restored to portrait and an intentional relaunch produced the valid normal2 path. Downloads and Comments remain outside this W-13 slice. W-35 implementation probe was withdrawn after runtime measurement; the finding remains open.

### W-22 AFTER evidence boundary (2026-09-16)

The v3b offline evidence includes the iPad S2 AX3 repair cell with EhPanda selected on Search and both quick rows at `379x48`. The final Gallery9 anchors are fully within the viewport on both devices: phone `8,562,371x213` and pad `433,931,371x213`. Both devices retain the three Search query states; returning to `.large` restores the Gallery9 anchors at phone `685` and pad `488`. These are bounded evidence points, not closure of W-22: all 18 portrait cells are accounted for as 17 valid plus the S2 AX3 repair readback, while landscape coverage and pixel calibration remain pending. The complete evidence remains under `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/after-verified-v3b/`.

### W-22 v3b evidence and D-25 re-sweep (2026-09-16)

The v3b AFTER run accounts for all 18 Search portrait cells (iPhone/iPad × S1/S2/S3 × `.large`/AX3/AX5). The iPad S2 AX3 row was replaced by the repair capture after the first capture proved to be `DockFolderViewService`; the repair is at `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/after-verified-v3b/ipad-cold-S2-AX3-repair-ui.txt` and its matching PNG/readback. The corrected per-cell path table is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/after-verified-v3b/v3b-comprehensive-audit-corrected.md`.

The clipping checks reached Gallery9 fully inside the viewport on both devices: phone `(8,562,371x213)` and iPad `(433,931,371x213)`. The live `.large` → AX5 → `.large` sequence retained the literal query `Fixture query`; the return anchors were phone `y685` and iPad `y488`. Exact scroll equality is not claimed. Matched landscape evidence is available for both devices: phone BEFORE/AFTER use `phone-landscape-before-matched-ui.txt` / `phone-landscape-before-matched.png` and `phone-landscape-after-matched-ui.txt` / `phone-landscape-after-matched.png`, with title `(38,23 124x46)`, field `(78,79 718x124)`, and Quick `(78,234 394x66)`; iPad BEFORE/AFTER use `pad-landscape-before-matched-ui.txt` / `pad-landscape-before-matched.png` and `pad-landscape-after-matched-ui.txt` / `pad-landscape-after-matched.png`, with field `(20,87 1140x124)` and Quick `(16,242 394x66)`.

Six of eight cells have accepted observed differences: two Favorites-out cells accepted earlier, plus the four cells accepted on 2026-09-17. The user's reply `可以接受` accepts the recorded cold and repeat/control evidence for Favorites in AX5, Watched out `.large` and AX5, and Watched in AX5. The other two (Favorites in `.large`, Watched in `.large`) measured 0 diff; no color exception is required. This records these cells' observed results only; it does not establish natural-system noise, a general tolerance, or W-22 completion. The superseded older Favorites out paths are retained only as history; the accepted Favorites out observations use the matched pairs `calibration-v3b/before/favorites-out-large-1.png` ↔ `calibration-v3b/after/favorites-out-large-1.png` and `calibration-v3b/before/favorites-out-ax5-1.png` ↔ `calibration-v3b/after/favorites-out-ax5-1.png`, with same-version 1-vs-2 captures producing zero ROI differences at both sizes. These two cells are native `1206x2622`, ROI `[0,330,1206,2622]`, with large 325105 nonzero differences / maximum RGB delta 3 and AX5 89381 / maximum RGB delta 8.


### W-22 v3b per-cell evidence paths (2026-09-16)

The following rows expand every Search cell as required by W-22. Paths are written relative to `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22`; `pending`, `unknown`, and `null` preserve gaps in the captured UI/readback rather than inferring a value. Where the manifest cell field is `null`, the shared BEFORE batch readbacks still explicitly report `.large`, AX3, or AX5 for the corresponding size batch; that is a qualified shared readback, not a per-cell assertion. The BEFORE artifact is W22 Before-v2 (debug dylib SHA `0234fea564ab276ba9a428e38a44097782d4416ff2d3c5a39bc77ed9f7cbf7be`); the AFTER artifact is the completed W22 After-v3b build (debug dylib SHA `fbce4002e2459f83fb01b6229c070c9e03fa941cc588f4982cab5607ba972cc6`). Both have bundle ID `app.ehpanda.personal`. The two direct `.large` S2/S3 pairs use their own `calibration-v4-phone-reload` readbacks because the older `iphone-content-size-final-readback.log` does not identify a matched route. iPhone BEFORE title frames are retained as unavailable where the historical AX frame was not captured; the BEFORE/AFTER PNGs still show the title rendering change. iPad Search uses native top tabs, so its presentation is not asserted as an iPhone-style inlineLarge title.



| Cell | BEFORE evidence and literal readback | BEFORE frames (title / searchfield / first Quick content) | AFTER evidence and literal readback | AFTER frames (title / searchfield / first Quick content) | Verdict |
|---|---|---|---|---|---|
| iphone S1 large | `iphone-large-S1-v2.txt`, `iphone-large-S1-v2.png`; shared `iphone-content-size-final-readback.log` = `.large` (batch, not per-cell) | `16,64 72x27` / `16,117 370x44` / `N/A` | `after-verified-v3b/iphone-cold-S1-large-ui.txt`, `after-verified-v3b/iphone-cold-S1-large.png`; `after-verified-v3b/iphone-cold-S1-large-readback.log` = `large` | `16,64 112x41` / `16,117 370x44` / `N/A` | static title/field/content check met; shared BEFORE size qualification; dynamic drawer behavior untested |
| iphone S1 AX3 | `iphone-true-AX3-S1.txt`, `iphone-true-AX3-S1.png`; shared `iphone-true-AX3-readback.log` = `accessibility-extra-large` (batch, not per-cell) | visible in PNG; frame unavailable / `16,117 370x96` / `N/A` | `after-verified-v3b/iphone-cold-S1-accessibility-extra-large-ui.txt`, `after-verified-v3b/iphone-cold-S1-accessibility-extra-large.png`; `after-verified-v3b/iphone-cold-S1-accessibility-extra-large-readback.log` = `accessibility-extra-large` | `16,61 124x46` / `16,117 370x96` / `N/A` | static title/field/content check met; BEFORE title frame unavailable; shared BEFORE size qualification; dynamic drawer behavior untested |
| iphone S1 AX5 | `iphone-true-AX5-S1.txt`, `iphone-true-AX5-S1.png`; shared `iphone-true-AX5-readback.log` = `accessibility-extra-extra-extra-large` (batch, not per-cell) | visible in PNG; frame unavailable / `16,117 370x124` / `N/A` | `after-verified-v3b/iphone-cold-S1-accessibility-extra-extra-extra-large-ui.txt`, `after-verified-v3b/iphone-cold-S1-accessibility-extra-extra-extra-large.png`; `after-verified-v3b/iphone-cold-S1-accessibility-extra-extra-extra-large-readback.log` = `accessibility-extra-extra-extra-large` | `16,61 124x46` / `16,117 370x124` / `N/A` | static title/field/content check met; BEFORE title frame unavailable; shared BEFORE size qualification; dynamic drawer behavior untested |
| iphone S2 large | `calibration-v4-phone-reload/search-large/before/S2/ui.json`, `calibration-v4-phone-reload/search-large/before/S2/screen.png`; `calibration-v4-phone-reload/search-large/before/S2/prelaunch-readback.log` = `large` | `16,64 72x27` / `16,117 370x44` / `16,192 152x24`; fixture quick `(16,244 370x20)` | `calibration-v4-phone-reload/search-large/after/S2/ui.json`, `calibration-v4-phone-reload/search-large/after/S2/screen.png`; `calibration-v4-phone-reload/search-large/after/S2/prelaunch-readback.log` = `large` | `16,64 112x41` / `16,117 370x44` / `16,192 152x24`; fixture quick `(16,244 370x20)` | static title/field/content check met; drawer behavior untested |
| iphone S2 AX3 | `iphone-true-AX3-S2.txt`, `iphone-true-AX3-S2.png`; shared `iphone-true-AX3-readback.log` = `accessibility-extra-large` (batch, not per-cell) | visible in PNG; frame unavailable / `16,117 370x96` / `16,244 311x51` | `after-verified-v3b/iphone-cold-S2-accessibility-extra-large-ui.txt`, `after-verified-v3b/iphone-cold-S2-accessibility-extra-large.png`; `after-verified-v3b/iphone-cold-S2-accessibility-extra-large-readback.log` = `accessibility-extra-large` | `16,61 124x46` / `16,117 370x96` / `16,244 311x51` | static title/field/content check met; BEFORE title frame unavailable; shared BEFORE size qualification; drawer behavior untested |
| iphone S2 AX5 | `iphone-true-AX5-S2.txt`, `iphone-true-AX5-S2.png`; shared `iphone-true-AX5-readback.log` = `accessibility-extra-extra-extra-large` (batch, not per-cell) | visible in PNG; frame unavailable / `16,117 370x124` / `16,272 239x131` | `after-verified-v3b/iphone-cold-S2-AX5-ui.txt`, `after-verified-v3b/iphone-cold-S2-AX5.png`; `after-verified-v3b/iphone-cold-S2-AX5-readback.log` = `accessibility-extra-extra-extra-large` | `16,61 124x46` / `16,117 370x124` / `16,272 239x131`; second fixture row `(16,600 370x125)` | static title/field/content check met; fixed two-line Quick row; BEFORE title frame unavailable; shared BEFORE size qualification; drawer behavior untested |
| iphone S3 large | `calibration-v4-phone-reload/search-large/before/S3/ui.json`, `calibration-v4-phone-reload/search-large/before/S3/screen.png`; `calibration-v4-phone-reload/search-large/before/S3/prelaunch-readback.log` = `large` | `16,64 112x41` / `16,117 370x44` / `16,192 152x24`; fixture quick `(16,244 370x20)` | `calibration-v4-phone-reload/search-large/after/S3/ui.json`, `calibration-v4-phone-reload/search-large/after/S3/screen.png`; `calibration-v4-phone-reload/search-large/after/S3/prelaunch-readback.log` = `large` | `16,64 112x41` / `16,117 370x44` / `16,192 152x24`; fixture quick `(16,244 370x20)` | static title/field/content check met; drawer behavior untested |
| iphone S3 AX3 | `iphone-true-AX3-S3.txt`, `iphone-true-AX3-S3.png`; shared `iphone-true-AX3-readback.log` = `accessibility-extra-large` (batch, not per-cell) | `16,61 124x46` / `16,117 370x96` / `16,244 311x51` | `after-verified-v3b/iphone-cold-S3-accessibility-extra-large-ui.txt`, `after-verified-v3b/iphone-cold-S3-accessibility-extra-large.png`; `after-verified-v3b/iphone-cold-S3-accessibility-extra-large-readback.log` = `accessibility-extra-large` | `16,61 124x46` / `16,117 370x96` / `16,244 311x51` | static title/field/content check met; BEFORE size is qualified by the shared batch readback; drawer behavior untested |
| iphone S3 AX5 | `iphone-true-AX5-S3.txt`, `iphone-true-AX5-S3.png`; shared `iphone-true-AX5-readback.log` = `accessibility-extra-extra-extra-large` (batch, not per-cell) | `16,61 124x46` / `16,117 370x124` / `16,272 239x131` | `after-verified-v3b/iphone-cold-S3-accessibility-extra-extra-extra-large-ui.txt`, `after-verified-v3b/iphone-cold-S3-accessibility-extra-extra-extra-large.png`; `after-verified-v3b/iphone-cold-S3-accessibility-extra-extra-extra-large-readback.log` = `accessibility-extra-extra-extra-large` | `16,61 124x46` / `16,117 370x124` / `16,272 239x131` | static title/field/content check met; BEFORE size is qualified by the shared batch readback; drawer behavior untested |
| ipad S1 large | `ipad-search-S1.txt`, `ipad-search-S1.png`; shared `ipad-content-size-final-readback.log` = `large` (batch, not per-cell) | `354,36 87x36` selected Search top tab / `20,87 780x44` / `N/A` | `after-verified-v3b/ipad-cold-S1-large-ui.txt`, `after-verified-v3b/ipad-cold-S1-large.png`; `after-verified-v3b/ipad-cold-S1-large-readback.log` = `large` | `354,36 87x36` selected Search top tab / `20,87 780x44` / `N/A` | static title/field/content check met; BEFORE size is qualified by the shared batch readback; drawer behavior untested |
| ipad S1 AX3 | `ipad-true-AX3-S1.txt`, `ipad-true-AX3-S1.png`; shared `ipad-true-AX3-readback.log` = `accessibility-extra-large` (batch, not per-cell) | `381,32 98x41` selected Search top tab / `20,87 780x96` / `N/A` | `after-verified-v3b/ipad-cold-S1-accessibility-extra-large-ui.txt`, `after-verified-v3b/ipad-cold-S1-accessibility-extra-large.png`; `after-verified-v3b/ipad-cold-S1-accessibility-extra-large-readback.log` = `accessibility-extra-large` | `381,32 98x41` selected Search top tab / `20,87 780x96` / `N/A` | static title/field/content check met; BEFORE size is qualified by the shared batch readback; drawer behavior untested |
| ipad S1 AX5 | `ipad-true-AX5-S1.txt`, `ipad-true-AX5-S1.png`; shared `ipad-true-AX5-readback.log` = `accessibility-extra-extra-extra-large` (batch, not per-cell) | `381,32 98x41` selected Search top tab / `20,87 780x124` / `N/A` | `after-verified-v3b/ipad-cold-S1-accessibility-extra-extra-extra-large-ui.txt`, `after-verified-v3b/ipad-cold-S1-accessibility-extra-extra-extra-large.png`; `after-verified-v3b/ipad-cold-S1-accessibility-extra-extra-extra-large-readback.log` = `accessibility-extra-extra-extra-large` | `381,32 98x41` selected Search top tab / `20,87 780x124` / `N/A` | static title/field/content check met; BEFORE size is qualified by the shared batch readback; drawer behavior untested |
| ipad S2 large | `ipad-search-S2.txt`, `ipad-search-S2.png`; shared `ipad-content-size-final-readback.log` = `large` (batch, not per-cell) | `354,36 87x36` selected Search top tab / `20,87 780x44` / `16,162 152x24`; fixture quick `(16,215 379x21)` | `after-verified-v3b/ipad-cold-S2-large-ui.txt`, `after-verified-v3b/ipad-cold-S2-large.png`; `after-verified-v3b/ipad-cold-S2-large-readback.log` = `large` | `354,36 87x36` selected Search top tab / `20,87 780x44` / `16,162 152x24`; fixture quick `(16,215 379x21)` | static title/field/content check met; BEFORE size is qualified by the shared batch readback; drawer behavior untested |
| ipad S2 AX3 | `ipad-true-AX3-S2.txt`, `ipad-true-AX3-S2.png`; shared `ipad-true-AX3-readback.log` = `accessibility-extra-large` (batch, not per-cell) | `381,32 98x41` selected Search top tab / `20,87 780x96` / `16,214 311x52`; fixture quick `(16,355 379x48)` | `after-verified-v3b/ipad-cold-S2-AX3-repair-ui.txt`, `after-verified-v3b/ipad-cold-S2-AX3-repair.png`; `after-verified-v3b/ipad-cold-S2-AX3-repair-readback.log` = `accessibility-extra-large` | `381,32 98x41` selected Search top tab / `20,87 780x96` / `16,214 311x52`; fixture quick `(16,355 379x48)` | static title/field/content check met; repaired valid capture; BEFORE size is qualified by the shared batch readback; drawer behavior untested |
| ipad S2 AX5 | `ipad-matched-v4/s2-before-ax5-ui-v3.txt`, `ipad-matched-v4/s2-before-ax5-v3.png`; `ipad-matched-v4/s2-before-ax5-readback-v3.log` = `accessibility-extra-extra-extra-large` | `381,32 98x41` selected Search top tab / `20,87 780x124` / fixture quick `(16,421 379x64)` | `ipad-matched-v4/s2-after-ax5-ui.txt`, `ipad-matched-v4/s2-after-ax5.png`; `ipad-matched-v4/s2-after-ax5-readback.log` = `accessibility-extra-extra-extra-large` | `381,32 98x41` selected Search top tab / `20,87 780x124` / fixture quick `(16,421 379x64)` | static title/field/content check met; drawer behavior untested |
| ipad S3 large | `ipad-search-S3.txt`, `ipad-search-S3.png`; shared `ipad-content-size-final-readback.log` = `large` (batch, not per-cell) | `354,36 87x36` selected Search top tab / `20,87 780x44` / `16,162 152x24`; fixture quick `(16,215 379x21)` | `after-verified-v3b/ipad-cold-S3-large-ui.txt`, `after-verified-v3b/ipad-cold-S3-large.png`; `after-verified-v3b/ipad-cold-S3-large-readback.log` = `large` | `354,36 87x36` selected Search top tab / `20,87 780x44` / `16,162 152x24`; fixture quick `(16,215 379x21)` | static title/field/content check met; BEFORE size is qualified by the shared batch readback; drawer behavior untested |
| ipad S3 AX3 | `ipad-matched-v4/s3-before-ax3-ui.txt`, `ipad-matched-v4/s3-before-ax3-1.png`; `ipad-matched-v4/s3-before-ax3-readback.log` = `accessibility-extra-large` | `381,32 98x41` selected Search top tab / `20,87 780x96` / `16,214 311x52`; fixture quick `(16,355 379x48)` | `ipad-matched-v4/s3-after-ax3-ui.txt`, `ipad-matched-v4/s3-after-ax3-1.png`; `ipad-matched-v4/s3-after-ax3-readback.log` = `accessibility-extra-large` | `381,32 98x41` selected Search top tab / `20,87 780x96` / `16,214 311x52`; fixture quick `(16,355 379x48)` | static title/field/content check met; drawer behavior untested |
| ipad S3 AX5 | `ipad-matched-v4/s3-before-ax5-ui.txt`, `ipad-matched-v4/s3-before-ax5-1.png`; `ipad-matched-v4/s3-before-ax5-readback.log` = `accessibility-extra-extra-extra-large` | `381,32 98x41` selected Search top tab / `20,87 780x124` / fixture quick `(16,421 379x64)` | `ipad-matched-v4/s3-after-ax5-ui.txt`, `ipad-matched-v4/s3-after-ax5-1.png`; `ipad-matched-v4/s3-after-ax5-readback.log` = `accessibility-extra-extra-extra-large` | `381,32 98x41` selected Search top tab / `20,87 780x124` / fixture quick `(16,421 379x64)` | static title/field/content check met; drawer behavior untested |

The Search review's same-version controls are not uniformly stable: its JSON records first-versus-second differences of 233145 (BEFORE AX3), 156154 (AFTER AX3), 219602 (BEFORE AX5), and 0 (AFTER AX5). The cause is unknown and these figures are not treated as settling evidence. The review's older phrase “two stable screenshots” for S3 AX3/AX5 is superseded by these measured values.

### W-22 dynamic Search drawer and live-scroll verification (2026-09-17)

The eight static focused target cells are indexed separately from the eight S3 scroll cells below. Each path is an existing valid `*-verified` directory; iPad S1 `.large` BEFORE is explicitly incomplete and therefore has no fabricated Search/Escape claim.

| Target cell | BEFORE valid artifacts | AFTER valid artifacts |
|---|---|---|
| iPhone S1 `.large` | `iphone-S1-large-before-verified/{search-ui.json,search.png,focused-ui.json,focused.png,closed2-ui.json,closed2.png}` | `iphone-S1-large-after-verified/{search-ui.json,search.png,focused-ui.json,focused.png,closed-ui.json,closed.png}` |
| iPhone S1 AX5 | `iphone-S1-AX5-before-verified/{search-ui.json,search.png,focused-ui.json,focused.png,closed-ui.json,closed.png}` | `iphone-S1-AX5-after-verified/{search-ui.json,search.png,focused-ui.json,focused.png,closed-ui.json,closed.png}` |
| iPad S1 `.large` | `ipad-S1-large-before-verified/{focused-ui.json,focused.png}` only; Search/Escape files were not captured | `ipad-S1-large-after-verified/{search-ui.json,search.png,focused-ui.json,focused.png,escape-ui.json,escape.png}` |
| iPad S1 AX5 | `ipad-S1-AX5-before-verified/{search-ui.json,search.png,focused-ui.json,focused.png,escape-ui.json,escape.png}` | `ipad-S1-AX5-after-verified/{search-ui.json,search.png,focused-ui.json,focused.png,escape-ui.json,escape.png}` |
| iPhone S3 `.large` | `iphone-S3-large-before-verified/{search-ui.json,search.png,focused-ui.json,focused.png,closed-ui.json,closed.png}` | `iphone-S3-large-after-verified/{search-ui.json,search.png,focused-ui.json,focused.png,closed-ui.json,closed.png}` |
| iPhone S3 AX5 | `iphone-S3-AX5-before-verified/{search-ui.json,search.png,focused-ui.json,focused.png,closed-ui.json,closed.png}` | `iphone-S3-AX5-after-verified/{search-ui.json,search.png,focused-ui.json,focused.png,closed-ui.json,closed.png}` |
| iPad S3 `.large` | `ipad-S3-large-before-verified/{search-ui.json,search.png,focused-ui.json,focused.png,escape-ui.json,escape.png}` | `ipad-S3-large-after-verified/{search-ui.json,search.png,focused-ui.json,focused.png,escape-ui.json,escape.png}` |
| iPad S3 AX5 | `ipad-S3-AX5-before-verified/{search-ui.json,search.png,focused-ui.json,focused.png,escape-ui.json,escape.png}` | `ipad-S3-AX5-after-verified/{search-ui.json,search.png,focused-ui.json,focused.png,escape-ui.json,escape.png}` |

All entries above are rooted at `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/search-dynamic-20260917/`. The S3 scroll evidence uses the separate `phone|pad-S3-{large,AX5}-{before,after}-scroll-verified` directories and does not imply that those directories contain Close/Escape dismissal artifacts.

The bounded dynamic run covered S3 focused search on iPhone and iPad at `.large` and AX5 for both W22 Before-v2 and After-v3b artifacts. The focused field was typed with the literal `Fixture`; each cell has `focused`, `scroll-up`, and `scroll-down` nested UI JSON plus native PNG evidence under `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/search-dynamic-20260917/`. Across all eight cells, the query and field remained present after both gestures. iPhone retained native Close (`.large` `(342,70 44x44)`, AX5 `(262,70 124x124)`); iPad exposed no native Close/Cancel in these focused states. That iPad platform behavior is recorded as N/A for native dismissal, not a failure.

The four same-launch live query sequences are `phone-S3-live-nonzero-{before,after}/` and `pad-S3-live-nonzero-{before,after}/` in the same cache directory. iPhone retained the typed query and keyword10 through large → AX5 → large, with `y228 → y789 → y228`. iPad BEFORE retained large-scrolled → large-return positions `y159/y265`; that run produced no additional nonzero large displacement. iPad AFTER retained large-scrolled → AX5 → large positions `y127/y233 → y333/y621 → y127/y233`; the 32pt comparison to another focused sequence is cross-sequence only because no pre-gesture large capture was saved in that directory. The earlier top-position live captures contain an empty Search field and are only top-position/empty-query observations.

The audit is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/search-dynamic-20260917/dynamic-scroll-audit-20260917.md`. Every listed interaction stage has UI JSON and PNG, while this scroll-only run did not persist an independent capture-time settings readback; no later readback is substituted. Earlier invalid Home-route JSON and mistaken Close/Cancel attempts remain excluded from the dynamic verdict. This closes only the bounded drawer/live-scroll evidence requested here; it does not replace the 18-cell static matrix, bottom/landscape checks, or six accepted calibration-color observations.

The final W-22 scoped module gate passed 49 tests (AppTools 13, Home 24, Search 12), zero failed/skipped and zero Repetition in 54.033 seconds; the device execution reported 87 dynamic-parameter rows, which is not the test count. Evidence is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/final-fixedsize-module-20260917.log` and its xcresult; the matching generic Simulator build passed in 67.206 seconds with debug dylib SHA `70e573ff0231029a87a233cee5b768bdd705147ded7ba869ab07afc324cf0ed0`. These are gate facts; Task 7/UI batch and D-25 re-sweep remain pending.


### Withdrawn focus probes (W-13 / VO-3 / W-8)

The new Comments attachment probe was completely withdrawn. The generic build completed in 211.965 seconds; the separate LOGIN UDID build completed in 75.197 seconds. The recorded PostComment event/spoken pair was `23:01:05.288` / `.289`, sheet close was `23:01:33.475` / `.496`, and return-back was `23:02:04.096` / `.117`; the result is negative. Evidence is retained under `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/comments-attachment/runtime/comments-attachment-vot.log` with its three PNGs, and the restored Comments HEAD SHA is `cbcbfc7e15f613544e56fc26fadaabeccdc7240e6726762fc1658984a744842c`.

For W8, the normal-push and direct `2668617` observations remain negative but do not cancel the positive `22:18` observation. The source log is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/unresolved-focus/w8-normal-push-vot.log`; no causal explanation is inferred. The earlier body-button observation lacks the actual focus oracle and remains an unverified observation; it is not called positive and does not conflict with the later paired-probe runtime facts above.

### W-22 Favorites/Watched calibration rows

| Cell | BEFORE path(s) | AFTER path(s) | Matched verdict |
|---|---|---|---|
| Favorites out / `.large` | `calibration-v3b/before/favorites-out-large-1.png` plus same-version 2; older `favorites-large-out-*` paths superseded | `calibration-v3b/after/favorites-out-large-1.png` plus same-version 2 | **accepted observation for this recorded cell**; native `1206x2622`, ROI `[0,330,1206,2622]`, cross-build 325105 nonzero / max RGB 3; same-version 1-vs-2 ROI 0 diff |
| Favorites out / AX5 | `calibration-v3b/before/favorites-out-ax5-1.png` plus same-version 2; older `favorites-AX5-out-*` paths superseded | `calibration-v3b/after/favorites-out-ax5-1.png` plus same-version 2 | **accepted observation for this recorded cell**; native `1206x2622`, ROI `[0,330,1206,2622]`, cross-build 89381 nonzero / max RGB 8; same-version 1-vs-2 ROI 0 diff |
| Favorites in / `.large` | `calibration-v4-phone/before/favorites-in-large/screen.png`, `ui.json`, `prelaunch-readback.log` | `calibration-v4-phone/after/favorites-in-large/screen.png`, `ui.json`, `prelaunch-readback.log` | cold cross-version 0 diff / max 0 in native ROI `[0,330,1206,2622]`; no same-version control captured; no color exception required |
| Favorites in / AX5 | `calibration-v4-controls/before/favorites-in-ax5/root-control-2.png`, `root-control-ui.json`, `root-control-readback.log` | `calibration-v4-controls/after/favorites-in-ax5/root-control-2.png`, `root-control-ui.json`, `root-control-readback.log` | cold AX5 controls; same-version 0 / max 0; cross-version 0 / max 0 in native ROI; owner-accepted observed color for this cell |
| Watched out / `.large` | `calibration-v4-controls/watched-out-large/before/screen-2.png`, `screen-1.png` and corresponding UI/readback | `calibration-v4-controls/watched-out-large/after/screen-2.png`, `screen-1.png` and corresponding UI/readback | same-version controls 0 / max 0; cross-version title-masked 187921 / max 38; body ROI 868 / max 5; tabbar ROI 187053 / max 38; owner-accepted observed color for this cell; original cold measurement retained below |
| Watched out / AX5 | `calibration-v4-phone-reload/before/watched-out-ax5/root-control-2.png`, `root-control-ui.json`, `root-control-readback.log` | `calibration-v4-phone-reload/after/watched-out-ax5/root-control-2.png`, `root-control-ui.json`, `root-control-readback.log` | supplemental live `.large` → AX5 controls; same-version and cross-version controls 0 / max 0 in native ROI; original cold comparison remains below; owner-accepted observed color for this cell |
| Watched in / `.large` | `calibration-v4-phone-reload/before/watched-in-large/screen.png`, `ui.json`, `prelaunch-readback.log` | `calibration-v4-phone-reload/after/watched-in-large/screen.png`, `ui.json`, `prelaunch-readback.log` | cold pair 0 diff / max 0 in native ROI; no color exception required |
| Watched in / AX5 | `calibration-v4-phone-reload/before/watched-in-ax5/root-control-2.png`, `root-control-ui.json`, `root-control-readback.log` | `calibration-v4-phone-reload/after/watched-in-ax5/root-control-2.png`, `root-control-ui.json`, `root-control-readback.log` | supplemental live `.large` → AX5 controls; same-version 0 / max 0; cross-version 2022 / max 21, bbox `(121,2092,297,2217)`; original cold comparison remains below; owner-accepted observed color for this cell |

The original cold comparisons remain separate from the later same-version control captures. They are retained here so a new zero-difference control does not overwrite an earlier nonzero observation:

| Original cold comparison | BEFORE → AFTER | Native ROI result |
|---|---|---|
| Watched out / `.large` | `calibration-v4-phone-reload/before/watched-out-large/screen.png` → `calibration-v4-phone-reload/after/watched-out-large/screen.png` | title-masked `188439 changed / max 6`, ROI `[0,330,1206,2622]` |
| Watched in / AX5 | `calibration-v4-phone-reload/before/watched-in-ax5/screen.png` → `calibration-v4-phone-reload/after/watched-in-ax5/screen.png` | `8 changed / max 1`, ROI `[0,330,1206,2622]` |
| Watched out / AX5 | `calibration-v4-phone-reload/before/watched-out-ax5/screen-final.png` → `calibration-v4-phone-reload/after/watched-out-ax5/screen.png` | `86197 changed / max 8`, ROI `[0,330,1206,2622]` |
| Favorites in / AX5 | `calibration-v4-phone/before/favorites-in-ax5/screen.png` → `calibration-v4-phone/after/favorites-in-ax5/screen.png` | `792 changed / max 2`, ROI `[0,330,1206,2622]`; owner-accepted observed color for this cell |

The complete color-review dossier is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/root-control-color-review-20260916.md` and `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/root-control-color-review-20260916.json`. For Watched out `.large`, the title mask is the exact native frame `(47,359,472,481)`; the dossier's reported cross-version title-masked bbox is ROI-relative `(63,1424,1143,2229)`.

### W-13 Downloads approved probe (2026-09-16)

The approved Downloads-only probe is a design record, not a validated fix. Ownership is limited to `DownloadsView.swift` and `DownloadsView+Subviews.swift`, with no production implementation yet. `DownloadsView` owns `@AccessibilityFocusState private var focusedRowID: String?` and `@State private var inspectorOriginID: String?`. `DownloadRow` receives an `openInspectorAction: () -> Void` closure; its caller records the row origin ID and then sends the existing `inspectorButtonTapped` action, without adding a thin wrapper. `DownloadListRow` keeps its existing combined row semantics and attaches the real binding after that element boundary as `.accessibilityFocused(rowFocus, equals: download.id)`.

The existing inspector sheet uses native `onDismiss`; it guards the origin ID against the current `visibleRows`, restores focus only when that row is still present, and clears the origin with `defer` on every path. This preserves the existing controls and semantics group. The runtime check must cover normal pages → inspector → Close with the same stable gallery ID and the missing-row guard; fixture download rows already provide the data, so no new download is permitted.

### W-13 Downloads bounded validation (2026-09-16)

The approved Downloads focus implementation is committed as `aa3d9947` (`fix(16-25): restore download row focus`) in `DownloadsView.swift` and `DownloadsView+Subviews.swift`. The scoped gate passed 502 tests across the four requested modules with 496 passed, 6 expected failures, 0 failed, 0 skipped and 0 Repetition in 61.675 seconds; the generic Simulator build passed in 58.707 seconds. The normal WALK path recorded the row at `17:38:32.408` / `.409`, Pages at `17:39:35.566` / `.567`, inspector Close at `17:39:51.030` / `.047`, and restored the same row at `17:40:22.392` / `.423`. The missing-row guard diagnostic filtered the row from the UI without deleting download data: row `17:52:05.714`, Pages `17:52:19.768` / `.769`, Close `17:52:35.156` / `.173`, dismiss `17:53:03.813`, then the logging-only guard recorded origin present, row absent, count zero and guard rejection at `17:53:04.325`, followed by deferred origin clearing at `.326` and Downloads heading at `17:53:05.124` / `.146`. Evidence is retained under `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/w13-downloads/`, including both raw logs, eight PNGs and `timeline.txt`. The D24 semantic scope is limited to restoring focus only for an origin row still present in `visibleRows`; no download action, row semantics group or visual layout changed.

### W-10 bounded runtime evidence (2026-09-16)

The W-10 root runtime used the same logger as the W-35 timing run; the complete source log is retained at `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/w10/root-runtime/phase16-w35-timing-root.log`, with the bounded timeline at `timeline.txt` and the PNGs in that directory. In the earlier bounded route, the malformed-URL error toast was announced at `17:19:36.122`; the `17:20:37.173` / `.188` event was Cancel actual/spoken, followed by Search actual/spoken at `17:25:37.425` / `.445`. The known Fixture history item was actual/spoken at `17:26:48.093` / `.094`, results were captured in `phase16-w10-root-results.png`, Back was actual/spoken at `17:27:44.808` / `.809`, and popping to Search was actual/spoken at `17:28:00.418` / `.434`. The final Search PNG still shows the error toast, confirming that bounded route.

The subsequent results-page trial provides the bounded More → Filters return path: the toast announcement completed at `17:35:37.202`; More was actual/spoken at `17:36:12.897` / `.898`, Filters at `17:36:15.953` / `.954`, and Cancel at `17:36:17.982` / `.998`. After the sheet dismissed at `17:37:25.713`, the actual Search back button was `17:37:27.050` / `.073` (spoken `Back` at `.651`). Evidence is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/w10/root-runtime/phase16-w10-results-toast.png`, `phase16-w10-results-cancel.png`, `phase16-w35-timing-root.log`, and `w10-results-timeline.txt`. The 55-case module gate and generic Simulator build remain passing; this is a bounded pass and Task 7's complete walk2/UI batch remains pending.

### W-37 bounded runtime evidence (2026-09-16)

The W-37 source is committed as `772e8f85`. The runtime used the W29 generic app at `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w29/EhPanda.app`; its loader SHA is `4f41958e5d5614ba24d39b59b1a796dce7fbc0af63b0b08bfe7f880cf7ce7be5` and debug dylib SHA is `22f61008c4c9b08e5a3cfe2b38daeeb44af28db21dc6371198b131a28fd598cf`. Using a cache copy of the repository fixtures whose canonical uploader text was emptied (five bytes), with `EHPANDA_UITEST_STUB_NETWORK=1`, the WALK bounded traversal passed in both directions. In the forward interval `18:44:19–18:45:38`, the Detail title Button was actual/spoken at `18:44:20.807` / `.819`, followed by `Non-H` at `18:44:32.263` / `.264`, then Resume download, dimmed Add to favorites, Read, Favorited and Language. Reverse traversal reached `Non-H` at `18:45:30.902` / `.903` and the Detail title Button at `18:45:33.894` / `.896`, with no unnamed uploader stop. Evidence is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w37/root-runtime/w37-header-verified.png`, `w37-title-return.png`, `w37-root-vot.log`, and `timeline.txt`; the earlier launch-animation image is excluded. This is a bounded W-37 result only: Task 7's final HEAD remains pending.

### W-13 Comments runtime disposition (2026-09-16)

The approved Comments focus probe remains negative at runtime. Post Comment was actual/spoken at `18:39:33.573` / `.574`, the blank sheet Close at `18:40:08.291` / `.292`, and the post-dismiss focus landed on Comments Back at `18:40:12.624` / `.645` rather than the originating Post Comment control. Evidence is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w13-comments-login/root-runtime/necessary-vot.log`, `comments.png`, `postcomment.png`, and `comments-return.png`. The 39-test module gate and generic/LOGIN builds are gate facts only and do not convert this runtime result into a pass. Editing an existing comment was not tested, and Detail inline Post Comment is a separate scope. The uncommitted probe is withdrawn; W-13 remains open.

### 16-25 bounded documentation supersession (2026-09-17)

The preceding historical paragraphs retain their original state and wording. Current source attribution is: W-22's three changed screens (Search root, Favorites, Watched) are `7edfb1a7`, with source hashes `FavoritesView.swift` `461039fb924d1b1f0c2b861226b74c2a9607ef5b37c6e63ce00ff93ecfa2a0eb`, `WatchedView.swift` `819f7a08df7902cc2e39c804f1723654983a7d640b9e12e12ff1db6b73066c14`, and `SearchRootView.swift` `6aa18f56713a58a14f410fcdbdea0998930d84bf55db69f281fd26471819cbad`. W-10's toast forced-focus removal and sort-priority change are `c30fbe08`; W-13 Read and Downloads are `a90750a7` and `aa3d9947`. W-13 Comments remains unresolved and is not relabeled by the Read/Downloads commits.

The dynamic evidence is indexed in the preceding `### W-22 dynamic Search drawer and live-scroll verification (2026-09-17)` section. The final fixed-size module and generic gate provenance are recorded there as well; the formal UI gate remains separate and is still running.

### Focus diagnostic supersession (2026-09-17)

The W-35 host-scope diagnostic is measurement only. Its actual log is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/transcripts/w35-host-cold-20260917.log`; the build log is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/w35-host-scope-20260917/w35-host-build.log`, provenance is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/w35-host-scope-20260917/provenance-v2.txt`, and the cold image is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/w35-host-scope-20260917/cold-initial.png`. The real `NavigationStack` cold run recorded candidate More at `00:50:54.552`, Will set actual at `00:50:54.553`, later More actual at `00:50:55.469`, and spoken More at `00:50:55.484`, with no verified title focus; the three patched files were withdrawn. W-8 cold1 evidence also includes `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/w8-timing-20260917/runtime/cold1-merged.log`, and its matched evidence includes `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/w8-timing-20260917/runtime/matched-runtime-summary.txt` and `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/w8-timing-20260917/runtime/root-normal-header-settled.png`. W-8 cold1 recorded uploader actual/spoken at `00:29:33.517/.518`, Screen Changed at `00:29:34.294`, More actual/spoken at `00:29:35.079/.093`, and the next HID at `00:29:35.404`; detail load completed at `00:28:04`, with scroll offset `-70 → -48.667` in the same evidence. This does not establish causality; `pid=7790` resolved to SpringBoard and does not prove system ownership. W-8's matched cold route did not use VoiceOver to reach the uploader, so it has no 10-second idle sample and is not a negative result; the original cold1 reached the uploader without activation. The href-only normal sample used different uploader/category/cover content and is not a causal comparison. W-13 Comments remains the original Post Comment target with a negative Back return. VO-3's original toolbar target remains unmet; `visiblebodyMore` is an owner-decision candidate, not a fix. These limits remain unresolved technical evidence for 16-26 sign-off; do not repeat the same API probes.

### Task 6 UI/E1 closeout (2026-09-17)

The E-1 source removal is `b01add4c`. The first after-E1 `testReadingControlPanelAudit` runs passed 1/1 with zero
failures and zero skips on both gate devices: phone testcase 8.670 s, wrapper `TEST SUCCEEDED` in 64.522 s with
`XB_EXIT=0`; iPad testcase 9.130 s with wrapper `TEST SUCCEEDED` and `XB_EXIT=0`. Both full-test results report actual
`nodeType` Repetition 0. The standing regression is `testReadingControlPanelAudit`; the former element-query absence
probe was dropped because it enumerated hidden elements and stayed red after the fix. V-1's owner-approved
designed-hit-region exclusion is preserved; `systemOwnedExclusions` remains unchanged and no new exclusion is added.
Task 6's recorded UI/E1 evidence is closed; Task 7 remains in progress, and the 16-26
D-25 re-sweep remains pending. Root's final by-UDID WALK and LOGIN build/install completed at 31.110 s and 25.705 s;
both installed dylibs have SHA `1b02f72e4aebb0d3dc7830e9c2e129ad4a96d3927d96c638217e9ac2709b6621`. Evidence is
`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/audit/task7-final-walk-build.log`,
`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/audit/task7-final-walk-install.txt`,
`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/audit/task7-final-login-build.log`, and
`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/audit/task7-final-login-install.txt`. These are build/install
facts only; no production gate completion is claimed here.

**2026-09-17 D-25 scope correction.** The historical Activity Logs and Laboratory glyph rows are withdrawn by
`cc05aca6`, which reverted the rendered glyph/HStack changes from `286ecc15`; the remaining Activity Logs combine
modifier is accessibility semantics only and Laboratory has no post-revert diff. Gallery Detail remains withdrawn.
The effective rendered D-25 scope is therefore exactly Search root, Favorites and Watched from `7edfb1a7`, using the
existing login/out routes and nine planned iPhone-portrait XXL / AX3 / AX5 cells. No new glyph row is opened.

### Task 7 walk2 evidence update (2026-09-17)

The canonical Flow results and Findings rows above retain their original first-run descriptions and append literal
`walk 2:` evidence only where the root walkthrough supplied bounded final-HEAD proof. The provenance is the existing
`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/audit/task7-final-walk-install.txt`,
`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/audit/task7-final-login-install.txt`, and corresponding
`task7-final-walk-build.log` / `task7-final-login-build.log`; source fix baseline is `b01add4c`, documentation HEAD is
`c6a58688`. These are provenance references, not new gate results.

Historical preparation status: Task 7 remained in progress while the bounded F3/F6 walkthrough evidence was being assembled; current closure is recorded below with carried items. F3 and F6 bounded walkthrough evidence is recorded above; unresolved W-8/W-13 behavior and the remaining phase findings still require owner follow-up; the remaining hide rows
are still being closed by bounded route evidence; the bounded F4 Reader evidence is recorded above. W-6 full Frontpage speech now has bounded evidence in the canonical Findings row. L-2 and L-4 whole-item recordings are complete. L-5 reached its actual
target and has a complete whole-item recording despite the strict parser's Chinese multi-voice false-negative. L-6
was not independently run; the complete date sample from L-5 may be reused for date coverage, without adding any UGC
author name to this repository. W-33 and W-34 await the owner's phonetic judgments. W-8, W-35, VO-3 and W-13
Comments remain unresolved for 16-26 sign-off. W-22 color acceptance is not reopened.

### Withdrawn uncommitted focus probes (2026-09-16)

The W-13 Comments, W-35 Detail title, and VO-3 Search toolbar probes did not meet the owner's target and are withdrawn; their runtime observations remain open evidence and are not accepted or system-owned fixes. The temporary W-8 diagnostic was likewise restored and remains open. The five source files are byte-exact at their HEAD versions after restore; the withdrawn diff and before/after SHA records are retained at `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo3/unresolved-focus/withdrawn-focus-probes.patch`, `source-sha-before-restore.txt`, and `source-sha-restored.txt`. The Search localizable additions were part of the withdrawn VO-3 probe. The W-13 Comments probe is not a validated fix or phase-completion signal; the committed W-13 Read and Downloads results remain separate. LOGIN was restored to VoiceOver off and shut down at `18:42`, with the readback recorded in the cache evidence.

### Walkthrough closure
#### Task 7 closure preparation (2026-09-17)

The 15 `fix(16-25)` commits were checked against actual `git show` output and remain one-to-one with the
cache-only commit map. The classification is:

| Commit | Classification | D-25 relation |
|---|---|---|
| `26625a78` | non-rendered accessibility semantics | D-24; no rendered scope |
| `962f60c9` | non-rendered accessibility semantics | D-24; no rendered scope |
| `a8cb5d53` | non-rendered accessibility semantics | D-24; no rendered scope |
| `6b7ef86a` | non-rendered accessibility semantics | D-24; no rendered scope |
| `464d1584` | non-rendered accessibility semantics | D-24; no rendered scope |
| `772e8f85` | non-rendered accessibility semantics | D-24; no rendered scope |
| `f811bf5e` | non-rendered accessibility semantics | D-24; no rendered scope |
| `700db090` | non-rendered accessibility semantics | D-24; no rendered scope |
| `a12b9903` | non-rendered accessibility semantics | D-24; no rendered scope |
| `a90750a7` | non-rendered accessibility semantics | D-24; no rendered scope |
| `c30fbe08` | non-rendered accessibility semantics | D-24; no rendered scope |
| `aa3d9947` | non-rendered accessibility semantics | D-24; no rendered scope |
| `24f5847a` | non-rendered accessibility semantics | D-24; no rendered scope |
| `b01add4c` | non-rendered test/audit-only E-1 retirement | D-24; no app rendering or app accessibility source change |
| `7edfb1a7` | rendered layout/frame change | sole D-25 mapping: Search root, Favorites, Watched |

The 16-26 rendered scope remains the three screens from the rendered commit above and nine planned iPhone-portrait XXL/AX3/AX5
cells. Activity Logs and Laboratory remain withdrawn after `cc05aca6`; Gallery Detail remains withdrawn. The
Settings 45 → 65 tap and long-press decision remains retained. The E-1 exclusion is retired by the test-only commit above; the
standing regression is `testReadingControlPanelAudit` only (the old `50e8412d` test was removed by `5c210835`).
The V-1 owner-approved designed-hit-region exclusion remains preserved, while the separately tracked
system-owned exclusions remain unchanged. The after-E-1 phone and iPad audit samples are one passing test each,
with actual Repetition 0; this does not close Task 7 or the 16-26 UI gate.

The eight flows F1–F8 retain their first-run findings and now carry bounded walk2 evidence where available.
OQ2 action ordering and the existing Voice Control proxy observations are recorded for the applicable flows;
Voice Control spoken commands and VoiceOver double-tap activation were not measured on the simulator; Voice Control
results are native-label proxies only, including on account-safety routes. Accepted observations remain accepted, carried items remain carried, and
owner-deferred items remain deferred. At this checkpoint the hide ledger is 38 hidden, 2 not an element, 15 unreached with their concrete reasons, and 0 pending; no current hide row remains pending. W-33/W-34 await owner phonetic judgments, and W-38 remains an
unresolved carried item. Task 7 is still in progress.

#### Closure scope and status (2026-09-17)

The walkthrough scope is eight routes, F1–F8. The canonical Findings and Flow results retain the original route counts and first-run verdicts; each available walk 2 addition is attached to its affected route cell with its bounded transcript, UI/VC proxy, or display evidence. Current statuses remain separated as follows: accepted observations retain their recorded acceptance reasons; carried items remain assigned to 16-26 owner sign-off; owner-deferred items remain deferred; and unreached sites retain their concrete route or fixture reason. The current hide ledger is the bounded count above, while historical progress paragraphs retain their original pending wording.

OQ2 is recorded as the context-menu/action-order check: where a menu was reached, the named actions were compared for order and duplicate entries, with account-safety actions left unactivated. This does not establish Voice Control spoken-command coverage. Voice Control spoken commands and VoiceOver double-tap activation were not measured on the simulator; the recorded Voice Control material is native-label proxy evidence only.

E-1 is retired by `b01add4c` after the after-E-1 phone and iPad audit samples passed with actual Repetition 0. `testReadingControlPanelAudit` is the standing regression; the old `50e8412d` test was removed by `5c210835`. This is test/audit evidence and does not add an app-rendering or app-accessibility source change.

#### D-25 change lists

**Rendered layout/frame change (one commit):**

- `7edfb1a7` — Search root, Favorites, and Watched; this is the sole D-25 rendered mapping. The corresponding bounded screen evidence remains in the W-22 rows above and the existing Search/Favorites/Watched capture paths.

**Non-rendered accessibility semantics or test/audit-only changes (fourteen commits):**

- `26625a78` — `fix(16-25): visible() hidden content fix`; D-24 semantics, no D-25 rendered scope.
- `962f60c9` — `fix(16-25): home carousel VoiceOver traversal`; D-24 semantics, no D-25 rendered scope.
- `a8cb5d53` — `fix(16-25): section heading traits`; D-24 semantics, no D-25 rendered scope.
- `6b7ef86a` — `fix(16-25): reader context menu actions`; D-24 semantics, no D-25 rendered scope.
- `464d1584` — `fix(16-25): clarify setting accessibility`; D-24 semantics, no D-25 rendered scope.
- `772e8f85` — `fix(16-25): detail accessibility semantics`; D-24 semantics, no D-25 rendered scope.
- `f811bf5e` — `fix(16-25): gallery and download semantics`; D-24 semantics, no D-25 rendered scope.
- `700db090` — `fix(16-25): speak binary size units`; D-24 semantics, no D-25 rendered scope.
- `a12b9903` — `fix(16-25): spell out Latin day periods`; D-24 semantics, no D-25 rendered scope.
- `a90750a7` — `fix(16-25): restore reader trigger focus`; D-24 semantics, no D-25 rendered scope.
- `c30fbe08` — `fix(16-25): keep toast after screen content`; D-24 semantics, no D-25 rendered scope.
- `aa3d9947` — `fix(16-25): restore download row focus`; D-24 semantics, no D-25 rendered scope.
- `24f5847a` — `fix(16-25): focus newly loaded content`; D-24 semantics, no D-25 rendered scope.
- `b01add4c` — `fix(16-25): retire E-1 audit exclusion`; test/audit-only E-1 retirement and standing regression coverage, with no app rendering or app accessibility source change; D-24.

The non-rendered list is a classification record, not a claim that every call site in a changed source file created new D-25 scope.

Listening coverage remains bounded: L-2 and L-4 recordings are complete; L-5 reached its actual target and has a complete whole-item recording despite the strict parser's Chinese multi-voice false-negative; L-6 was not independently run and may reuse the same dated L-5 sample for date coverage. W-33 remains uncertain pending owner judgment; W-34 is a completed fix with owner phonetic verification passed for the MiB pronunciation. W-8, W-35, VO-3, and W-13 Comments remain unresolved technical limits for 16-26.

#### Findings index for closure review

The Findings table contains 38 records across eight flows. Its route-status counts are **27 fix**, **6 accepted**, **2 owner**, **2 deferred**, and **1 withdrawn**. The accepted records and their reasons are: `VO-3b` (pop-back focus is an observation, not a checklist item), `VO-4` (transcript verbosity does not drop information), `W-7` (finite preview strip leaves for Comments), `W-11` (reverse declaration order is consistent system presentation), `W-32` (owner accepted user content spoken by the system voice), and `W-31` (owner accepted only the empty uploader button capsule under Button Shapes).

The owner-routed records are `VO-3` (Filters dismissal focus is carried to 16-26 sign-off) and `W-22` (owner decision to show the signed-out Watched title). W-34 is a completed fix with owner phonetic verification passed 2026-09-17. Explicit carried items are `VO-3` and `W-38`; W-38 carries the Reader page-52/indicator mismatch to 16-26 because its cause is unverified. The deferred records are `W-21` (ContentUnavailableView symbol) and `W-24` (Search keyword Delete glyph contrast). The 15 unreached sites are retained in the Swept sites table with their concrete reasons; they are not promoted to pass by this index.

No completed fix record remains without a literal walk 2 citation in the canonical Findings cells. W-33 retains a bounded audio observation and remains uncertain; W-34 has bounded evidence and owner phonetic verification passed for the implemented fix; `VO-3` remains separately owner-carried. The current hide ledger has no pending rows; historical progress paragraphs retain their original pending wording.

OQ2's actual conclusion is `CONTEXTMENU=not-exposed`: the context menu is not exposed as a second rotor source. The earlier W-12 baseline had no accessibility-action mirror and omitted `Reload` from the rotor; after the fix, the current walk exposes `Reload`, `Previous page`, `Next page`, and `Activate` once through the current mirror. The mirror is the single rotor source for that action set; the bounded walks found no duplicate action, and account-safety actions were not activated.

E-1's red/green evidence is the `16-CONTRAST-AUDIT.md` after-E1 record: `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/audit/after-e1-iphone.xcresult` and `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/audit/after-e1-ipad.xcresult` each report `1/1 passed, 0 failed, 0 skipped`, with actual Repetition 0; the phone testcase is 8.670 s and the iPad testcase 9.130 s, with wrapper `TEST SUCCEEDED` and `XB_EXIT=0`. This is the green standing-regression result after the E-1 removal; the red pre-fix exclusion history remains unchanged.

#### Task 25 final runtime closure (2026-09-17)

The root walkthrough was restored and shut down after the bounded run. `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/walk-restored.txt` records UTC `2026-09-16T19:54:43Z`, light/large, Increase Contrast disabled, VoiceOver 0, Reduce Motion 0, Reduce Transparency 0, Bold Text 0, Button Shapes 0, and Grayscale 0; Command and Control preference is absent, matching baseline; spoken-command unavailable. The matching UI and PNG are `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/walk-restored-ui.json` and `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/walk-restored.png`. `$HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/inventory-restored-20260917.json` records WALK, LOGIN, gate iPhone, and gate iPad all Shutdown. LOGIN remains covered by `login-restored.txt` with dark/large and zero flags.

The initial `cc05aca6` provenance inventory recorded raw G1=25, G2=2, G3=51, and G4=23 sites. Its swept inventory was G1=7, G2=2, G3=46 plus 7 paired G4 sites; its excluded inventory was G1=18, G2=0, G3=5 plus 16 unpaired G4 sites. The initial swept runtime result was 34 hidden rows, 4 observed leaks, 2 not-an-element rows, and 15 unreached rows. Current after-fix bounded evidence is 38 hidden, 2 not an element, 15 unreached, and 0 pending; the four leak observations are resolved in the current runtime evidence. This is a before/after evidence comparison, not a claim that the historical source scan is identical to the current source grep. The original swept and excluded sites remain recorded above.

Task 7 walkthrough execution is closed with carried items. W-34 is a completed fix with owner phonetic verification passed for the MiB pronunciation; W-33 remains uncertain. W-8, W-35, VO-3, W-13 Comments, and W-38 remain unresolved or carried to 16-26 and are not passes. Current Flow and hide cells contain no pending status. Historical progress sections retain earlier pending/null wording; a raw-document grep therefore differs from the current semantic status check by design.

## Round-2 close (16-26)

### Closing gates

The gate session recorded repository HEAD `c6a58688`; the current measured source was the immutable
`b01add4c11b1f9c355ac8f2e055ed8b24fe8146c`, and later documentation-only commits preserve that source.
All runs used `DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer` through
`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/scripts/xb2.sh`, with the phase-owned
`$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/production-gates/DerivedData-Generic-Lint`
path. The root-approved ordering amendment records gates and runtime before the summary/docs, with no
measurement rerun on a documentation-only HEAD.

| Gate | Command (short) | Device / OS | Result | Evidence |
|---|---|---|---|---|
| FeatureTests | `xb2.sh <log> test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination platform=iOS Simulator,id=73E148DA-26E4-4892-8C8A-7EDC6725D0E7` | iPhone 17, iOS 26.5 (23F77) | 1050 total: 1039 passed, 11 expected failures, 0 failed/skipped, Repetition 0; summary 79.824 s, console 82.369 s. The 402 parameterized executions belong to 67 dynamic tests and are not the suite test count. | `$HOME/Library/Caches/ehpanda-phase16/round2/close/20260917-final-featuretests-iphone.{log,xcresult,summary.json,tests.json}` |
| UITests | `xb2.sh <log> test -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests -destination platform=iOS Simulator,id=73E148DA-26E4-4892-8C8A-7EDC6725D0E7` | iPhone 17, iOS 26.5 (23F77) | 39 passed in 41 test runs, 2 expected iPad-only skips, 0 failed, Repetition 0; summary 566.927 s, console 569.952 s. | `$HOME/Library/Caches/ehpanda-phase16/round2/close/20260917-final-uitests-iphone.{log,xcresult,summary.json,tests.json}` |
| UITests | `xb2.sh <log> test -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests -destination platform=iOS Simulator,id=B6679864-3783-4A3B-89B5-B0B010588C13` | iPad (A16), iPadOS 26.5 (23F77) | 41 passed in 41 test runs, 0 skipped/failed, Repetition 0; summary 642.417 s, console 645.214 s. | `$HOME/Library/Caches/ehpanda-phase16/round2/close/20260917-final-uitests-ipad.{log,xcresult,summary.json,tests.json}` |

The aggregate gate record is `$HOME/Library/Caches/ehpanda-phase16/round2/close/20260917-final-closing-gates-evidence.txt`.

The two expected iPhone skips are `AccessibilityAuditUITests.testPadSettingAndDetailModalsAudit` and
`DeepLinkPadUITests.testPadTabModalReplacedByDeepLink`. SwiftLint used `swiftlint lint --strict --no-cache --config .swiftlint.yml AppPackage/Sources App ShareExtension EhPandaUITests AppPackage/Tests` and found 0 violations in 579 files. The six error rules were `accessibility_hardcoded_string`, `no_dynamic_type_size_modifier`, `reading_controls_dynamic_type_range`, `no_fixed_system_font_size`, `no_geometry_reader`, and `no_minimum_scale_factor`; the added-media check over `c65be7b8^..HEAD` found 0. The full FeatureTests bundle covered 22
targets and 15 historical references (13 existing, 1 moved, 1 merged); it was not rerun separately.
The ignored local workflow test command is repointed to the current project/scheme and gate iPhone;
the phase-local lock and unrelated different-UDID/DerivedData jobs did not block this evidence.

Tasks 3–4 owner sign-off remains pending. W-33 remains an uncertain owner audio judgment; W-34 is a completed fix with owner phonetic verification passed for the MiB pronunciation; no 16-26
SUMMARY or phase/A11Y-02 completion is claimed.

### Owner listening feedback and scope update (recorded 2026-09-17T12:00:44Z)

The repository documentation HEAD at recording was `7f3fbadf9b47158b21b66b11b0250ed65786c4b1`; the measured source remains `b01add4c11b1f9c355ac8f2e055ed8b24fe8146c`. This records user feedback received in this session; it is not phase approval or an Owner sign-off record.

> Mebibytes 聽起來沒錯
> PM 那句太長了我不太確定

The first line closes W-34 only for the MiB pronunciation. The second line leaves W-33 uncertain because the PM phrase was not accepted. A short W-33 follow-up clip is available at `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/clips/w33-time-short.m4a`, with source interval 359.350–363.300 s (3.950 s, normal speed, unaltered) and provenance at `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/clips/w33-time-short-provenance.md`; its ASR is only machine positioning and remains unaccepted. Separately, the user accepted only the W-31 scope of the empty uploader button capsule under Button Shapes: 「收尾記錄裡面那些問題，只接受空白按鈕膠囊，其它問題需要你詳細解釋我判斷」. This does not accept the Favorites AX5 blank native Search capsule (#39) or any other blank control. W-8, W-35, VO-3, W-13 Comments, and W-38 remain unresolved; Voice Control spoken actuation and VoiceOver double-tap activation remain unmeasured limitations.

### Pending owner decision

| Item | Current bounded status |
|---|---|
| #39 Favorites AX5 | Blank native Search capsule; owner-routed to 16-26 |
| W-8 / W-35 | Detail focus limits remain unresolved |
| VO-3 | Search Filters dismissal focus remains unresolved |
| W-13 Comments | Comments remains unresolved; Read and Downloads have bounded evidence |
| W-38 | Reader reaches page 51/52; indicator shows 44/52 while visible page is 51 |
| W-31 | Accepted only for the empty uploader button capsule under Button Shapes, within that observed scope; no other blank control is accepted |
| W-33 | Owner listening remains uncertain for the long PM phrase; the short follow-up is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/clips/w33-time-short.m4a` (359.350–363.300 s, 3.950 s, unaltered), with provenance at `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/clips/w33-time-short-provenance.md` |
| W-34 | Implemented fix with owner phonetic verification passed for the MiB pronunciation; clip is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/listen/audio/task7-final-20260917-0248/clips/w34-file-size.m4a` |

W-21, W-24, and the other accepted/deferred records retain their existing closure dispositions.
Voice Control spoken actuation and VoiceOver double-tap activation remain unmeasured limitations,
not owner decisions. The approved natural colour acceptance applies to W-22 only and is not phase sign-off.
