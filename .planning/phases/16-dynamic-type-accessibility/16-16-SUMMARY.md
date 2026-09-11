---
phase: 16-dynamic-type-accessibility
plan: 16
subsystem: accessibility
tags: [voiceover, voice-control, accessibility-label, accessibility-value, accessibility-actions, combine, button, catalog, d-20, d-30, contextmenu-not-exposed]

# Dependency graph
requires:
  - phase: 16-13
    provides: "`16-CONTRAST-AUDIT.md § Decisions` — `CONTEXTMENU=not-exposed` with its simulator-tree provenance"
  - phase: 16-15
    provides: "iPhone 17e `67377A20…` holding `app.ehpanda.personal`; the install-over protocol re-derived for round 2"
provides:
  - "Detail header: the favorites `Menu` label is `Label(.accessibilityAddToFavorites, systemSymbol: .heart).labelStyle(.iconOnly)` — VoiceOver label + Voice Control name; the progress-ring centre glyph is hidden"
  - "Both comment cells (Detail strip card, Comments list row) are one combined element; the user's vote travels as a conditional `accessibilityValue` (`accessibility.voted_up` / `accessibility.voted_down`), the thumb glyph is hidden"
  - "Comments rows expose one named custom action per text-run link (`accessibility.open_link`; `accessibility.open_link_to %@` with the host when a comment has several), fed by `LinkedText.linkMatches(in:)` so the actions name exactly the runs the view makes tappable"
  - "Archives: coin glyphs hidden; the Hath download banner is a `Button` (`.disabled` for no selection) with a `ButtonStyle` keeping the pressed / disabled colours and animation"
  - "Torrents: flowed counter glyphs hidden so accessibility sizes announce the counters like the `Label` variant does"
  - "Five `accessibility.*` keys in the DetailFeature catalog, six locales each"
affects: [16-17, 16-19, 16-24, 16-25, 16-26]

# Actuals (#2632) — chars/4 over the realized diff; commits measured from the plan ledger.
actuals:
  tokens: 5069
  tasks: 2
  commits: 2
  plan_head_before: 66aec05363868111df6b09ec5de8a6c71172a930

tech-stack:
  added: []
  patterns:
    - "A `Menu` whose label is a bare glyph gets `Label(.key, systemSymbol:).labelStyle(.iconOnly)`, never a separate `.accessibilityLabel` — the title is the VoiceOver label and the Voice Control name in one move"
    - "A multi-part card or row that reads as one thing is `.accessibilityElement(children: .combine)`; state rides on it as `.accessibilityValue(.key, isEnabled: flag)` — the `isEnabled:` overload is the conditional-modifier idiom, so no empty string and no optional juggling"
    - "A dynamic list of custom actions is `.accessibilityActions { ForEach(items) { Button(resource) { … } } }`; a fixed one is `.accessibilityAction(named:)`"
    - "A gesture-driven control becomes a `Button`; when `.plain` would lose a designed pressed look, a private `ButtonStyle` reading `configuration.isPressed` and `@Environment(\\.isEnabled)` restores it exactly"
    - "Verify VoiceOver semantics with a hit-test (`sim-use describe-ui --point`, returns the AX element's label / value / traits / custom actions); the agent-device node dump lists AX-hidden nodes and `Menu` label nodes too, so it cannot prove hidden-ness on its own"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift
    - AppPackage/Sources/DetailFeature/DetailView+CommentCells.swift
    - AppPackage/Sources/DetailFeature/Comments/CommentsView.swift
    - AppPackage/Sources/DetailFeature/Components/LinkedText.swift
    - AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift
    - AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift
    - AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings

key-decisions:
  - "Comment cells are combined elements: the plan puts the vote *on the cell* as a value, and a value only surfaces on an element, so each cell became one (author, vote, score, date, text in reading order); links then attach to that element as named actions."
  - "Per-link actions use the `accessibilityActions` builder, not a chain of `.accessibilityAction(named:)`: a comment carries any number of links, and the builder is the one SwiftUI form that takes a `ForEach`. The plan's acceptance grep for the literal `accessibilityAction(named: .accessibilityOpenLink` therefore reads 0; the rotor entry it checks for is present (`custom_actions: [\"Open link\"]` on the live row)."
  - "Torrents flowed glyphs are hidden, not combined (Rule 1): combining would read the downloads glyph as `Selected, 62` — the SF Symbol description of `checkmark.circle` — and make the row announce differently above and below `.large`; hidden matches what the compact `Label` variant already announces."
  - "The Hath banner keeps its designed pressed / disabled half-opacity through a private `ButtonStyle` rather than `.buttonStyle(.plain)`, because `.plain` has no hook for the pressed colour the plan requires kept."
  - "No `accessibility.folder_*` keys: at HEAD the two research sites are `Label` icons already hidden by `FolderRowLabelStyle`, and every FolderManager control is a text `Label` or a role button; labelling them would be over-labelling (Pitfall 7)."
  - "`requirements-completed` stays empty as in 16-15: A11Y-02 is the whole of round 2 and is closed by the phase, not by one plan."

patterns-established:
  - "Re-inventory before editing: four of the plan's research-era sites had moved or been resolved by the owner's round-1 commits (page glyph, comment context menu, FolderManager icons, the archive `Button`); each is recorded below with what was found instead."

requirements-completed: []

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Favorites `Menu` labelled from the catalog; ring glyph hidden; comment cells combined with vote value; comment links as named actions; five six-locale keys"
    requirement: "A11Y-02"
    verification:
      - kind: other
        ref: "greps: accessibilityAddToFavorites=1, accessibilityHidden(true) in HeaderSection=1, accessibilityVotedUp|Down in CommentCells=2 and CommentsView=2, accessibilityOpenLink refs in CommentsView=1 line (both keys), swiftlint:disable=0, .accessibilityLabel( added=0; catalog check `17 keys; missing locales: []`; `xcodebuild build -scheme EhPanda -destination 'generic/platform=iOS Simulator'` BUILD SUCCEEDED, 0 Violation lines"
        status: pass
      - kind: automated_ui
        ref: "sim-use describe-ui --point on 67377A20…: favorites = AXPopUpButton 'Add to favorites' traits [PopupButton, NotEnabled, Button]; Detail strip card = AXStaticText combined label, AXValue null (unvoted), children []; Comments row = AXGenericElement combined label, custom_actions ['Open link'], AXValue null"
        status: pass
    human_judgment: false
  - id: D2
    description: "Archives banner is a `Button` with parity style; coin glyphs hidden; Torrents flowed glyphs hidden; FolderManager needs nothing"
    requirement: "A11Y-02"
    verification:
      - kind: other
        ref: "greps: ArchivesView onTapGesture=0, accessibilityHidden(true)|children: .combine=2; TorrentsView accessibilityHidden(true)=1; FolderManagerView accessibilityHidden(true)=1 (pre-existing), Label(.accessibility=0 (nothing to label); lint build BUILD SUCCEEDED, 0 Violation lines"
        status: pass
      - kind: automated_ui
        ref: "Torrents on 67377A20… at AX3 before: Image elements 'Arrow Up Circle' / 'Arrow Down Circle' / 'Selected' / 'document.circle' beside the numbers; after the fix: StaticText '69', '22', '239', '103.5 MiB' only (matches .large). Archives and FolderManager: source-verified only (login-gated, see below)"
        status: pass
    human_judgment: true
    rationale: "Archives and FolderManager were not reachable without a session (the Archives menu item is disabled logged-out; FolderManager needs a signed-in account); their semantics are verified from source and the lint build, and 16-25's device walkthrough covers them live"

# Metrics
duration: 30min
completed: 2026-09-11
status: complete
---

# Phase 16 Plan 16: VoiceOver / Voice Control pass over DetailFeature Summary

**Every icon-only or custom control in Detail, Comments, Archives and Torrents is now a labelled native control in the live accessibility tree: the heart `Menu` reads "Add to favorites", each comment is one element whose vote is a value and whose links are named rotor actions, the Hath download banner is a `Button`, and the glyphs that VoiceOver would have read by their SF Symbol names are hidden — all strings from five new six-locale catalog keys, lint build green with no suppression.**

## Performance

- **Duration:** 30 min
- **Started:** 2026-09-11T13:33:01Z
- **Completed:** 2026-09-11T14:03:00Z
- **Tasks:** 2
- **Files modified:** 7 (6 Swift, 1 catalog)

## Accomplishments

### Every modifier added, with its semantic reason

| File | Site | Modifier | Reason |
|---|---|---|---|
| `DetailView+HeaderSection.swift` | `favoriteButton` `Menu` label | `Label(.accessibilityAddToFavorites, systemSymbol: .heart).labelStyle(.iconOnly)` replaces the bare `Image` | Icon-only control had no VoiceOver label and no Voice Control name; the title supplies both. The favourited state stays the existing swapped-in `Label(.favorited, …)` (state by presence, not by label text) |
| `DetailView+HeaderSection.swift` | `progressIndicator` centre `Image(systemSymbol: centerSymbol)` | `.accessibilityHidden(true)` | Decorative: the enclosing button already announces status and action via `downloadButtonAccessibilityLabel` |
| `DetailView+CommentCells.swift` | `DetailView.CommentCell` card `VStack` | `.accessibilityElement(children: .combine)` | The card is one thing; four stops per card in a horizontal strip of near-identical cards is noise. Also what makes the value below surface |
| `DetailView+CommentCells.swift` | same | `.accessibilityValue(.accessibilityVotedUp, isEnabled: comment.votedUp)` / `.accessibilityValue(.accessibilityVotedDown, isEnabled: comment.votedDown)` | State as a value, attached only while a vote exists (never an empty string) |
| `DetailView+CommentCells.swift` | thumb `Image` in `metadata` | `.accessibilityHidden(true)` | The vote is carried by the value; the glyph would be read as "Like" / "Dislike" beside it |
| `Comments/CommentsView.swift` | `CommentsView.CommentCell` row `VStack` | `.accessibilityElement(children: .combine)` | Same reasoning as the card; a row of a `List` reads as one comment |
| `Comments/CommentsView.swift` | same | the two conditional `accessibilityValue`s | Same as the card |
| `Comments/CommentsView.swift` | same | `.accessibilityActions { ForEach(links, id: \.self) { Button(openLinkActionName(link, distinguished: links.count > 1)) { linkAction(link) } } }` | The link runs are reached by tap gestures VoiceOver and Voice Control cannot see; one named action per link (`Open link`, or `Open link to <host>` when the comment has several so rotor entries are distinguishable; `mailto:`-style URLs without a host fall back to the whole URL). Tap gestures kept for sighted users |
| `Comments/CommentsView.swift` | thumb `Image` in `metadata` | `.accessibilityHidden(true)` | As above |
| `Components/LinkedText.swift` | `LinkedText` | `static func linkMatches(in:)` (refactor, not a modifier) | The detector's matches are needed by the cell to list the `.plainText` links; one source for both the tappable runs and their actions |
| `Archives/ArchivesView.swift` | `ArchiveFundsView` `Image(systemSymbol: .gCircleFill / .cCircleFill)` | `.accessibilityHidden(true)` | Decorative beside the balance text; would otherwise be read by symbol description |
| `Archives/ArchivesView.swift` | `DownloadButton` | `Button(action:)` + `DownloadBannerStyle: ButtonStyle` + `.disabled(isDisabled)`; `onTapGesture` / `onLongPressGesture` removed | The banner had no role and no name; a `Button` gets both from its visible title, `.disabled` carries the no-selection state, and the style reproduces the designed white-on-accent with half-opacity while pressed or disabled and the animated colour change |
| `Torrents/TorrentsView.swift` | `flowedCounter` `Image(systemSymbol: counter.symbol)` | `.accessibilityHidden(true)` | Above `.large` the pairs are bare `Image` + `Text` in an `HStack`, and each glyph was its own element read by symbol description — including "Selected" for `checkmark.circle`; hidden, the row announces the counters exactly as the compact `Label` variant already does |

No `.accessibilityLabel` was added anywhere (0 in the diff); no control with visible text received one; no string literal or `Text(` reached an accessibility modifier (lint-enforced, 0 violations).

### New catalog keys (`DetailFeature/Resources/Localizable.xcstrings`, `extractionState: manual`, six locales)

| Key | en | de | ja | ko | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| `accessibility.add_to_favorites` | Add to favorites | Zu Favoriten hinzufügen | お気に入りに追加 | 즐겨찾기에 추가 | 添加到收藏 | 加入收藏 |
| `accessibility.voted_up` | Voted up | Positiv bewertet | 賛成票を投じました | 찬성 투표함 | 已投票赞成 | 已投票贊成 |
| `accessibility.voted_down` | Voted down | Negativ bewertet | 反対票を投じました | 반대 투표함 | 已投票反对 | 已投票反對 |
| `accessibility.open_link` | Open link | Link öffnen | リンクを開く | 링크 열기 | 打开链接 | 開啟連結 |
| `accessibility.open_link_to` | Open link to %@ | Link zu %@ öffnen | %@ へのリンクを開く | %@ 링크 열기 | 打开 %@ 链接 | 開啟 %@ 連結 |

Wording follows the existing `accessibility.*` sentence-case style ("Pause download"). The only argument is a string, kept positional (`%@` → generated `accessibilityOpenLinkTo(_:)`); no numeric argument, so no `%#@variable@` substitution was needed. Catalog check: `17 keys; missing locales: []`. The file was re-serialised with the same `json.dumps(indent=2)` shape it already had (round-trip byte-identical before the insertion); the diff is 205 added lines, 0 removed.

### CONTEXTMENU outcome

`CONTEXTMENU=not-exposed` was applied as instructed, but at HEAD the comment cells have **no `.contextMenu`**: `CommentsView` reaches vote-down / vote-up / edit through `.swipeActions`, and the Detail strip card has no menu at all. Swipe actions are exactly what the owner's simulator read found exposed as custom actions, so nothing needed mirroring; step (f) added nothing. The one `.contextMenu` in a 16-16 file is the tag cell's (`DetailView+Subviews.swift` `TagRow.tagContentView`: Detail / Vote Up / Vote Down / Withdraw Vote) — outside this plan's step (f), which names comment menus; see "Handed to the orchestrator" below.

### AX-tree verification (iPhone 17e `67377A20-A90A-4DB2-9A9C-9965532B0AA9`, iOS 26.5, no session)

Install-over per `16-SWEEP.md § Protocol`: built by UDID into `$HOME/Library/Caches/ehpanda-phase16/DerivedData` (tree at `d4e0c27d` + working Archives edit, then again at `d4e0c27d` + Archives + Torrents edits), `plutil -extract CFBundleIdentifier raw` → `app.ehpanda.personal` both times, `xcrun simctl install` over the existing bundle; nothing uninstalled or erased. Public gallery used: the Home hero carousel entry (Detail, its Comments, its Torrents). The instrument for label / value / traits / actions is `sim-use describe-ui --device <UDID> --point x,y --json` (a VoiceOver hit-test); `agent-device snapshot` provided navigation refs and the raw node tree.

**Live-verified**

| Control | Excerpt |
|---|---|
| Favorites `Menu` (header) | agent-device: `@e15 [button] "Add to favorites" [disabled]`. sim-use: `role AXPopUpButton, AXLabel "Add to favorites", AXValue null, traits ["PopupButton","NotEnabled","Button","Scrollable"], enabled false` — the disabled state is a trait, the label carries no state |
| Download `Menu` (header, no badge) | sim-use: `role AXPopUpButton, AXLabel "Download", traits ["PopupButton","Scrollable","Button"], children []` — one element (see "Observations" for the raw-node note) |
| Detail comments strip card | agent-device: `@e38 [cell] "Dummy Stash    , 2026/09/11, 20:24, Download torrents from "Dummy Stash", that's the source …"`. sim-use at the card: `role AXStaticText, AXLabel <the same combined text>, AXValue null, custom_actions [], children []` — one element, no vote → no value, hidden thumb not present |
| Comments list row | sim-use: `role AXGenericElement, AXLabel <author, date, text combined>, AXValue null, traits ["Scrollable"], custom_actions ["Open link"]` — the action comes from the `t.me/…` URL the detector found inside a `.plainText` run. agent-device `--actions`: `actions: ["Open link"]` on every child node of the row |
| Torrents counters, `.large` | sim-use enumeration: `StaticText '26'`, `'4'`, `'62'`, `'186.4 MiB'`; hit-tests at the three glyph positions return the scroll container, not an image element — the `Label` variant never exposed the glyphs |
| Torrents counters, AX3, **before** the fix | `Image 'Arrow Up Circle'`, `Image 'Arrow Down Circle'`, `Image 'Selected'`, `Image 'document.circle'` beside `StaticText '26' / '4' / '62' / '186.4 MiB'` |
| Torrents counters, AX3, **after** the fix (second install-over) | `StaticText '69'`, `'22'`, `'239'`, `'103.5 MiB'` only, followed by the file-name `Button`, uploader and date — no image elements |

**Source-verified only** (not reachable without a session; the summary makes no live claim for these)

| Control | Why not live | What the source guarantees |
|---|---|---|
| Archives sheet (coin glyphs, Hath banner `Button`) | The Detail `More` menu shows `Archives` **disabled** for a logged-out session (no archive URL without login), so the sheet cannot be opened | `ArchivesView.swift`: `onTapGesture` = 0; `DownloadButton.body` is `Button(action:) { Text(.downloadToHathClient) … }.buttonStyle(DownloadBannerStyle()).disabled(isDisabled)`; both coin `Image`s carry `.accessibilityHidden(true)`; lint build green |
| FolderManager | Favorites folders need a signed-in account | Re-inventoried at HEAD: the research sites `:81` / `:90` are `Label` icons for the new-folder / rename `TextField` rows, already `.accessibilityHidden(true)` in `FolderRowLabelStyle`; the toolbar is `Button(role: .close)` (system label) and `Label(.newFolder, systemSymbol: .plus)`; swipe actions are `Label(.RLocalizable.delete, …)` / `Label(.renameFolder, …)`. No icon-only control exists, so no key was added and no line changed |
| Voted-comment value | `votedUp` / `votedDown` are the *user's own* votes, so no public gallery shows one without a session; nothing was voted (D-09) | Both cells: `.accessibilityValue(.accessibilityVotedUp, isEnabled: comment.votedUp)` / `(.accessibilityVotedDown, isEnabled: comment.votedDown)`; `isEnabled: false` attaches nothing, so the unvoted case (verified live: `AXValue null`) is the same code path |
| Multi-link comment (`Open link to <host>`) | The reachable comment had one link | `openLinkActionName(_:distinguished:)` returns `.accessibilityOpenLinkTo(link.host() ?? link.absoluteString)` when `links.count > 1` |

Simulator baselines read before and after (`appearance light`, `content_size large`); the AX3 switch used for the Torrents check was restored to `large` each time (read back). `agent-device close --session default` run at the end (`sessions: []`); device shut down. No screenshot entered the repository (`git status` image count 0); the three scratch screenshots used for navigation lived in the session scratchpad only.

## Task Commits

1. **Task 1: Header, subviews, comment cells, Comments view** — `d4e0c27d` (feat)
2. **Task 2: Archives, Torrents, FolderManager** — `c032c243` (feat)

**Plan metadata:** recorded in the docs commit that carries this file.

## Files Created/Modified

- `AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift` — favorites `Menu` label, hidden ring glyph.
- `AppPackage/Sources/DetailFeature/DetailView+CommentCells.swift` — combined card, vote value, hidden thumb.
- `AppPackage/Sources/DetailFeature/Comments/CommentsView.swift` — combined row, vote value, per-link actions, `links` / `openLinkActionName`.
- `AppPackage/Sources/DetailFeature/Components/LinkedText.swift` — `linkMatches(in:)` shared detector entry point.
- `AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift` — hidden coin glyphs; banner `Button` + `DownloadBannerStyle`.
- `AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift` — hidden flowed glyphs.
- `AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings` — five keys × six locales.
- `.planning/phases/16-dynamic-type-accessibility/deferred-items.md` — created (out-of-scope findings, below).

`DetailView+Subviews.swift` and `FolderManager/FolderManagerView.swift` are in the plan's file list but were not changed — see the re-inventory notes.

## Decisions Made

See `key-decisions` in the frontmatter.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Torrents flowed glyphs hidden instead of combined**
- **Found during:** Task 2 (Torrents live check at AX3)
- **Issue:** Combining each glyph + number as the task text says would keep the SF Symbol description in the announcement: "Arrow Up Circle, 26", and for the downloads counter "Selected, 62" (`checkmark.circle`'s description) — a wrong state word beside a count — while the `.large` `Label` variant announces the bare numbers. The must-haves allow "hidden or combined".
- **Fix:** `.accessibilityHidden(true)` on the flowed `Image`; both arrangements now announce identically (verified before/after at AX3).
- **Files modified:** `Torrents/TorrentsView.swift`
- **Committed in:** `c032c243`

**2. [Rule 3 - Blocking] `ButtonStyle` instead of `.buttonStyle(.plain)` for the Hath banner**
- **Found during:** Task 2
- **Issue:** The task requires the conversion to keep "the same layout, colours and the colour animation"; `.plain` has no hook for the pressed half-opacity the gesture-driven original drew, so the two requirements could not both be met with `.plain`.
- **Fix:** private `DownloadBannerStyle: ButtonStyle` reading `configuration.isPressed` and `@Environment(\.isEnabled)`, drawing the same white / accent colours at 0.5 opacity while pressed or disabled inside the same `.animation(.default) { $0.background(…) }`, `.clipShape(.rect(cornerRadius: 30))`, `.glassEffect(.regular.interactive())`. The plan's `DownloadListRow` fallback triple was not needed.
- **Files modified:** `Archives/ArchivesView.swift`
- **Committed in:** `c032c243`

### Re-inventory at HEAD (plan step "re-inventory because the owner's round-1 commits moved lines")

3. **Step (d), page-count glyph:** `DetailView+Subviews.swift` no longer has a `photoOnRectangleAngled` glyph beside the page count — the stat is a text-only `DescScrollItem`; the only remaining `photoOnRectangleAngled` is the icon of the "Similar Gallery" `Label` (text-bearing, no work). Nothing added; the file is unchanged.
4. **Step (f), comment context menu:** none exists (swipe actions instead — exposed per the owner's read). Nothing added.
5. **Task 2 "archive option cell":** at HEAD the option cells are already `Button`s (`HathArchivesView`); the remaining `.onTapGesture` with an `isDisabled` guard (the research's `:252`) is the Hath download banner, which is what was converted.
6. **FolderManager icon-only controls:** none at HEAD (see the source-verified table); no `accessibility.folder_*` keys were created, and the acceptance grep `Label(.accessibility` = 0 is correct rather than a miss.
7. **Acceptance grep `accessibilityAction(named: .accessibilityOpenLink` = 0:** the per-link actions use the `accessibilityActions` builder (dynamic count); the live row exposes `custom_actions ["Open link"]`, which is what the check stands for.

### Environment deviations (pre-authorised by the orchestrator, recorded as required)

8. **Simulator:** iPhone 17e `67377A20-A90A-4DB2-9A9C-9965532B0AA9` (iOS 26.5) instead of the `16-SWEEP.md § Infrastructure` UDIDs; booted from Shutdown, restored and shut down.
9. **agent-device session:** `open` refused with `DEVICE_IN_USE` (session "default", owned by the orchestrator's earlier CONTEXTMENU read from another cwd); the one authorised `agent-device close` found no session in this cwd, so the tool's own hint was followed and the device was reused with `--session default`; that session was closed at the end (`agent-device close --session default` → `Closed: default`). No fallback to the MCP inspector was needed; `sim-use describe-ui` supplied the element-level reads.
10. **Archives not live-reachable:** the `More` menu's `Archives` item is disabled for a logged-out session (env fact 3 expected the sheet to open); source-verified as recorded above.
11. **No voted comment in reach:** as env fact 4 anticipated; source-verified, nothing voted.
12. **`.accessibilityValue` conditional form:** the `isEnabled:` overload rather than an `if` around the modifier — the same semantics (nothing attached when false), lint-clean, no wrapper.

### Observations (no change made)

- The agent-device raw node list shows a second node at the download `Menu`'s rect — `@e14 [button] "Icloud Download"` beside `@e13 [button] "Download"` — and also lists AX-hidden nodes (the opacity-0, `.accessibilityHidden` thumb glyph appears as `[image] "Dislike"`), so that list is the node tree, not the VoiceOver element list. The VoiceOver hit-test at the same point returns a single `AXPopUpButton "Download"` with `children: []`. A speculative `.accessibilityHidden(true)` on the menu's icon was tried and **reverted** (no verified semantic reason). Plan 16-25's physical-device rotor pass should confirm the header reads Download → Add to favorites → Read with no duplicate stop.
- Comment cells' linked images are `Button`s wrapping a `KFImage` with no text; under `.combine` they merge into the row. They were outside this plan's "link runs"; whether the rotor names them is for 16-25 to observe.

---

**Total deviations:** 2 auto-fixed (1 Rule 1, 1 Rule 3); 5 re-inventory differences; 5 pre-authorised environment deviations.
**Impact on plan:** Every plan truth met; two acceptance greps (`accessibilityAction(named: .accessibilityOpenLink`, `Label(.accessibility` in FolderManager) read 0 for the reasons above, with the underlying property verified another way. No layout changed, no visible element added (D-24) — no D-25 re-sweep candidate from this plan.

## Issues Encountered

- `agent-device press` on hero-carousel refs twice reported "off-screen"; a fresh `snapshot -i` plus pressing the currently rendered card resolved it. Diff-emitted refs cannot be pressed without a full snapshot (the tool says so); a full snapshot before each press fixed it.
- A `zsh` quirk: `echo ===` and `--include=*.swift` need quoting (`=cmd` expansion / glob); harmless, noted for the next executor.

## Handed to the orchestrator (not this plan's scope)

- **Tag-cloud context menu ownership gap.** Under `CONTEXTMENU=not-exposed`, `16-CONTRAST-AUDIT.md` says 16-16 / 16-19 mirror every context-menu item including "tag cells in the tag cloud". 16-16's step (f) names only comment menus; 16-19's Task targets `AppComponents/TagCloudView.swift` (its acceptance grep is on that file), but the tag cell's `.contextMenu` (Detail / Vote Up / Vote Down / Withdraw Vote) lives in `DetailFeature/DetailView+Subviews.swift` `TagRow.tagContentView`. Neither plan as written edits that menu; the owner should assign it (16-19 is the natural home since it already handles the tag cell).
- **Unit-less counters for VoiceOver.** Torrents counters ("26", "4", "62", "186.4 MiB") and Archive balances are announced as bare numbers at every size — the glyph *was* the unit. A labelled element ("Seeds 26" / "Gallery points 20,000") would need new keys the plan did not authorise; recorded for the Nutrition Label recommendation (16-26) and the owner.

## Known Stubs

None.

## Threat Flags

None — no new network, auth, file-write or schema surface. T-16-16 mitigated (no label on text-bearing controls; every string a catalog symbol; lint 0 violations). T-16-03 mitigated (bundle id checked before both install-overs; nothing uninstalled, erased or reset; baselines restored; text evidence only).

## User Setup Required

None.

## Next Phase Readiness

Wave 14 closed; next is 16-17 (wave 15, Setting screens + DateSeek). The `sim-use describe-ui --point` hit-test is the instrument later VoiceOver plans should use for label / value / trait / custom-action evidence; agent-device's node dump is for navigation and structure.

## Self-Check: PASSED

All 9 files present; commits `d4e0c27d` and `c032c243` present in `git log`.
