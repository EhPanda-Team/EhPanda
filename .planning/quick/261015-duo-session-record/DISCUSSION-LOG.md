---
type: retrospective-decision-log
recorded: 2026-10-15
source: owner-messages-and-answers-in-this-session
---

# Session decisions

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

The IDs below describe separate decisions, not new phase requirements. “Implemented” refers
to the source branch before integration. Evidence and its limits are in VERIFICATION.md.
Commit references are indexed in SUMMARY.md. “Proposed” is not owner approval.

## Inherited handoff: locked decisions and boundaries

| ID | Decision / provenance | Disposition |
|---|---|---|
| D01 | Handoff: use local size classes for ordinary layout and presentation; supersede Phase 5 D-03's idiom branching. | Implemented by `605b4e4749`, `e03456839a`; capability policies D26/D31 are explicit later exceptions in scope, not geometry inferred from idiom. |
| D02 | Detail and Setting are modal only when both window size classes are regular; otherwise Detail pushes and Setting is inline. An already inline Setting tab must not also open a sheet. Plus/Pro Max landscape keeps push. | Implemented by `605b4e4749`. Existing cold deep-link routing is a separate path, not proof of host-tap routing. |
| D03 | Reader creates/seeds its pager only after measuring its actual container; remove `DeviceClient.isLandscape`, never restore orientation guesses for pager geometry. | Implemented by `7cf9ff16ef`. |
| D04 | Login/NewDawn prose respects horizontal safe areas; decorative backgrounds may bleed. | Implemented by `1c79f36368`. |
| D05 | Handoff excludes ApplicationClient's appearance scene walk, analytics orientation telemetry, VisualSnapshotSupport, full-bleed reader/backdrop safe areas, and Account/EhSetting bottom safe areas. | Retained scope boundary. |
| D06 | Fix ReaderPageProbe's More lookup for both native horizontal and vertical bars, scoped to the reader and still requiring exactly one result. Inspect hierarchy first; validate on Duo and ordinary iPhone. | Implemented by `4191a6bb09`, extended SDK identifier in `c1a0139b1c`; no global ambiguous query. |
| D07 | Verify unfolded Duo, closed landscape, NewDawn ratio and dual-page resume without changing product behavior until authorized. | Pose checks completed; NewDawn resolved by D28. Spread preserved on resume; exact indicator normalization remains a documented observation, not an owner-selected change. |

## Tools, evidence and working rules

| ID | Decision / provenance | Disposition |
|---|---|---|
| D08 | Owner initially requested waiting for their simulator hinge CLI, then supplied an executable path that later moved. | Use the externally configured simulator pose driver and native pose events. Keep local tool names and machine-specific installation paths out of the repository. |
| D09 | Consult a local reference project's GSD docs and implementation for lessons. | Consulted; reproduce lessons without naming the other project in repository artifacts. |
| D10 | Consult Xcode 27.1 resizability guidance. Later explicit correction: use `app-resizability` and `iphone-duo`, not `impeccable`. | Final proposal follows both requested skills. General visual-design guidance is not its authority. |
| D11 | Owner questioned and rejected the need for Device Hub, then requested continued verification and remaining work. | No Device Hub needed or used for the recorded final checks; use dedicated simulator tools and simulator pose driver. |
| D12 | Preserve other sessions' simulators/work and primary checkout changes; run one simulator test process at a time, no push/PR without request. | Preserve isolation and local-only scope. Cross-session serialization superseded by D55; this session still runs its own tests sequentially. Handoff also requires conventional atomic commits, warning-free code/test builds, no weakened assertions or lint suppression. |
| D13 | Handoff: if subagents are used, explicitly request GPT 6.1 Sol, do not inherit full history, and stop on ambiguity. | Dispatch constraint, not proof of any runtime model. Later project GSD dispatch rules apply to GSD roles. |
| D14 | Owner requested actual screenshots for visual choices and proposals. | Crease A/B/C, NewDawn 60/50 and wide-screen A/B comparisons produced; screenshot scope must be labeled. |

## Home, title, tabs and opposite-side presentations

| ID | Decision / provenance | Disposition |
|---|---|---|
| D15 | Half-fold Duo Home: slideshow, Frontpage and Other left; Toplists right. | `8c332e2a21`; expanded device/posture scope by D31, D32. |
| D16 | Clarification answer: each Toplists category vertically lists six galleries, rather than six across. | `8c332e2a21`; retained in split Home. |
| D17 | Left-origin actions present sheets on the right; right-origin actions on the left. Frontpage, Toplists, Popular, Watched and History full lists must also be sheets in split Home. | `8c332e2a21`; nested gallery details reverse side again; list survives child dismissal. Expanded by D31. |
| D18 | Right-pane dragging must not change Home title size or position. Owner explicitly selected this over merely keeping a smaller title visible. | `7319a710b4`: independent native navigation hosts. Failed minimization experiment is not the final solution. |
| D19 | Add a hinge separator and propose several looks. Owner chose “B”. | `2d298eeba6`: 18 pt soft crease; alternatives A one-pixel separator, C 28 pt book-spine treatment were rejected by selection. Decorative overlay, no hit testing/layout width/accessibility entry. |
| D20 | Owner: split/crease only when Duo is half-folded **and landscape**, not portrait. | `5365df2f7d`; portrait exclusion retained. Half-fold-only scope later expanded by D31/D32. |
| D21 | Reduce vertical tabs' space consumption with native APIs. | `8c332e2a21`: native toolbar-first compression when space is limited. Scroll-driven hiding experiments did not work and were removed; do not claim scrolling collapses tabs. |
| D22 | Owner reported tab bar moved to bottom. Preserve native Duo side tabs. | `0b72a1db9d`: split only Home root; pushed destinations retain edge-reaching navigation host. Replaces the temporary global vertical-bar opt-out from `5365df2f7d`. |
| D23 | Owner: Refresh applies to all Home, including Toplists, and can live in side toolbar. | `49b70a328e`: one shared Reload at the edge-reaching host; `fetchAllGalleries` still refreshes slideshow/Popular, Frontpage and all ranking categories. |

## Reader behavior and settings

| ID | Decision / provenance | Disposition |
|---|---|---|
| D24 | Owner approved keeping the page indicator visible while reader controls are visible, using native navigation-bar minimization API. | `4191a6bb09`: installed SDK spelling is `.toolbarMinimizationBehavior(.never, for: .navigationBar)`, not the older `toolbarMinimizeBehavior` proposed in the question. Panel show/hide remains intact. |
| D25 | Show the dual-page toolbar item on every device in landscape, no longer only iPad. | `c1a0139b1c`; ordinary iPhones can use it manually, including from vertical reading. |
| D26 | iPad and Duo only: automatic landscape → horizontal plus dual page; portrait → single page and configurable other direction. Default enabled; settings can disable; landscape RTL/LTR configurable, default RTL; portrait default vertical and configurable. | `c1a0139b1c`; ordinary iPhones excluded. Device capability is separate from measured layout geometry. |
| D27 | Explicit answer: apply automatic reading mode on initial opening as well as rotation. | `c1a0139b1c`; opt-out/reentry/re-enable and page preservation verified. |
| D28 | iPad NewDawn: owner first requested both 60% and 50% screenshots, then chose 50%. | `30ef583d21`: Canvas width ≥500 pt uses 50%; narrower 60%. Actual compact-class iPad sheet is 580 pt; no idiom geometry branch restored. Supersedes unresolved handoff ratio. |
| D29 | Slider preview must remain throughout a long pressed drag, even before release. | `f0f2b435f2`: complete touch lifetime via GestureState; native Slider retains value/accessibility ownership. Multiple editing pairs during one touch were the cause. |
| D30 | Half-fold Duo landscape lower panel uses right half and omits the second bottom Close. | `f23bf58d1c`; default right side retained but movable and extended by D31/D34. |

## Extension to fully open Duo and iPad

| ID | Decision / provenance | Disposition |
|---|---|---|
| D31 | Owner asked to extend half-fold behavior, including opposite-side sheets, to fully open Duo and iPad landscape. | `5ab03faff3`: Home-origin opposite-side and nested presentation flow extended. This is not a claim that every sheet in every tab has opposite-side support. |
| D32 | Answer: also wants Home dual columns, conditional on iPad tab placement. Owner then required a separator whenever dual columns are used, not only when folded. | `5ab03faff3`: iPad landscape additionally requires top tab placement and ≥640 pt content width; open/half Duo landscape qualifies; cover/portrait do not. Initial all-device crease superseded for iPad by D38. |
| D33 | Investigate iOS 27 arrangement for a half-width slider while completely open. | Native 27.1 split arrangement feasibility proved at 0.5 ratio; overlay did not force half width. Production keeps shared safe-area-aware geometry and supports deployment target 27.0; arrangement adoption itself was not required by owner. |
| D34 | Add equally tall glass buttons using `inset.filled.lefthalf.arrowtriangle.left.rectangle` and `inset.filled.righthalf.arrowtriangle.right.rectangle` to move slider left/right. | `5ab03faff3`, `24ede29e5f`; typed SF symbols, at least 44 pt row height, physical sides independent of text direction. |
| D35 | Owner: move button belongs on the **other** half, because current slider may be hard to reach. | `24ede29e5f`; supersedes initial same-side button arrangement. |
| D36 | Slider swap must animate; iPad lower Close must stay centered **above the slider** as before. Only Duo landscape omits duplicate lower Close because its main Close is on side. | `24ede29e5f`: slider and iPad Close move together with 0.35 s smooth animation. |
| D37 | Owner saw no transition and questioned Reduce Motion remaining on. | Simulator Reduce Motion caused immediate movement. With it off, recorded intermediate frames establish actual movement; product continues to honor Reduce Motion. Later review session left iPad/Duo Reduce Motion off. Do not remove accessibility support to force animation. |
| D38 | Owner superseded all-device crease: **only Duo uses crease**; iPad Home uses ordinary divider and does not extend into tab bar. | `1eb8bdcdfe`; top content boundary respected, bottom may extend. |
| D39 | Owner requested thicker divider and corrected “vertical padding” to **top padding**. | `52e2547c11`; preserve bottom extent, avoid tab area. |
| D40 | Owner: iPad Toplists cells are too wide, filling entire right half. | `52e2547c11`: restore constrained ranking cell width; six vertical items retained. |
| D41 | Owner: “再粗一點”. | `37461f3980`: final plain iPad divider is **2 pt**, centered overlay that consumes no pane width. |
| D42 | Owner asked to launch iPad for review before continuing move-button changes. | iPad launched for review; simulator remains available. Review request is not automatic approval of unrelated proposals. |

## Verification discoveries and handoff corrections

| ID | Decision / provenance | Disposition |
|---|---|---|
| D43 | Owner reported all reader images failing on open. | Agent had left `EHPANDA_UITEST_STUB_NETWORK=1` and fixture path active; unknown paths returned 404. Normal relaunch cleared flags; live reader smoke passed. No production networking patch. Mandatory cleanup lesson in LEARNINGS.md. |
| D44 | Handoff rotation through XCTest failed on Duo; owner supplied simulator pose driver. | Host pose driver and separate inner/cover mapping used; dedicated-device restart cleared stale display routing. No app workaround for simulator state. |
| D45 | Retain reader exact-page/visible-pixel assertions and scoped More/Close queries while adapting tests to actual toolbar placement. | `4191a6bb09`, `67f5829629` and follow-ups. Fix hit points/identifiers, not expectations. Native inner-display screenshot limitations are disclosed. |
| D46 | Maintain native title/search and top soft scroll edges, including new sheet roots; verify ordinary roots at standard/AX1/AX3/AX5. | Session tests and scroll-edge inventory updated. Search-state continuity was not established by a failed exploratory script and remains a coverage gap. |

## Skill comparison and still-unselected wide-screen proposal

| ID | Decision / provenance | Disposition |
|---|---|---|
| D47 | Owner requested comparing the community iPhone Duo skill with Xcode 27.1 resizability. | Recorded assessment: complementary scopes—Xcode guidance for general local geometry/navigation adaptation, Duo guidance for hinge, reserved regions, bars and arrangement. Verify SDK availability/spelling locally. No blanket “community is better” or skill-authority replacement adopted. Original standalone comparison response is not retained as test evidence. |
| D48 | Owner requested investigation and screenshot proposals for Favorites, Search and Downloads. | Completed native static prototype and nine screenshots; **production changes not approved or implemented**. |
| D49 | Owner explicitly corrected skills to `app-resizability` + `iphone-duo`. | Final prototype uses native NavigationSplitView / inspector. Earlier parallel-stack layout study remains historical only. |
| D50 | Assistant proposal A: Favorites list+detail; Search criteria/Quick Search+results; Downloads list+optional inspector with row tap still reading. B alternatives: category sidebar+grid; results+detail with filter sheet; folders+list with status sheet. | **Proposed, awaiting owner selection**, including search-submit behavior and inspector selection details. See proposal/PROPOSAL.md. |
| D51 | Proposal acceptance limits: native split/inspector does not guarantee exact hinge alignment or opposite-side sheets; resize must retain query, selection, path, results and scroll. Arrangement is content layout, not navigation/presentation. | Implementation acceptance work remains pending; static screenshots are not proof. |
| D52 | Owner: “preview 繼續開著，還沒看完”. | Keep `http://127.0.0.1:55920/index.html` available across migration. No tab closing or review decision inferred. |

## Session recovery and Git migration

| ID | Decision / provenance | Disposition |
|---|---|---|
| D53 | Owner: cherry-pick onto `feature/gsd-phase-17`, rewrite commits so GSD SHA references are correct, move to new worktree and branch, remove old worktree/branch. | Authorized local migration; exact state/mapping in MIGRATION.md. Preserve unrelated dirty/staged primary-checkout work and preview before cleanup. |
| D54 | Owner: GSD docs must record **all decisions in this session**, not just proposals. | This complete retrospective record, historical evidence and commit ledger address the omission. It must migrate with implementation. Future updates belong in tracked GSD docs as decisions occur. |

## Runtime validation scheduling follow-up

| ID | Decision / provenance | Disposition |
|---|---|---|
| D55 | After both integrated test builds passed, another session still had a long-running Xcode test. Owner explicitly answered “允許使用各自的 simulator 並行驗證”. | Supersedes the inherited cross-session single-test restriction for independent dedicated simulators. This session still runs its own test commands sequentially and never controls another session’s devices/processes. |

## App-wide Library design follow-up

| ID | Decision / provenance | Disposition |
|---|---|---|
| D56 | Owner: discussion is now at the app-design level, no longer limited to iPhone Duo. | App-wide scope; subsequently implemented by D63–D64 and quick task 261015-tx1. |
| D57 | Owner proposes merging Favorites and Downloads into one Library tab because both emphasize management slightly more than browsing and share that purpose. | Direction adopted; D64 subsequently selects shared category navigation with separate groups. See LIBRARY-DIRECTION.md. |
| D58 | Owner identifies the previous B alternatives as more management-oriented. | Reconsider the prior A recommendations around Library's management purpose; this is not blanket approval of every B detail. Previous screenshots remain comparison evidence. |

## Per-list row / grid display

| ID | Decision / provenance | Disposition |
|---|---|---|
| D59 | Owner proposes retiring the fixed global detail/thumbnail setting in favor of a row/grid switch on each list. | Adopt per-list display selection for the redesign; the global setting is to be replaced, not retained as the active authority. Implementation and versioned migration completed in quick task 261015-tx1. |
| D60 | Owner explicitly names Frontpage, Popular, Toplists, Favorites, Search and Downloads as independently remembered lists. | Six separate remembered choices. Favorites and Downloads retain separate preferences even when reached through Library. Initial defaults, finer category/folder scopes and unlisted lists are not decided here. |
| D61 | Owner clarification: the modes are row/grid, and the current waterfall effect becomes the proposal's grid layout. | This changes the layout itself: regular aligned grid based on the proposal replaces masonry/waterfall. Do not merely rename detail/thumbnail or keep the old waterfall renderer as grid. Exact cell metrics and image-fit treatment remain design details. |

## Rebuild workspace from the rewritten Phase 17 branch

| ID | Decision / provenance | Disposition |
|---|---|---|
| D62 | Owner requests a new worktree and branch from the latest feature/gsd-phase-17, moving this session's workspace there, then deleting the current worktree and branch. | New active worktree is app-design on agent/app-design, based on e6efecb69f. Carry forward the Library/row-grid record; preserve the target's rewritten SHA references and existing implementation. Exact completion/evidence in WORKSPACE-REBUILD.md. |

## Authorized Library implementation

| ID | Decision / provenance | Disposition |
|---|---|---|
| D63 | Owner invokes `$gsd-quick` to plan and implement the decided app-wide design direction. | Quick task `261015-tx1` owns Library and independent row/grid implementation and validation. Search A/B redesign is still not selected. |
| D64 | Owner selects shared category navigation with separate Favorites / Downloads groups. | Library replaces the separate tabs; category/folder navigation is shared, while source identity, list preferences and management operations remain separate. |

## Implementation follow-through

Quick task `261015-tx1` records the implementation plan and engineering decisions in
`../261015-tx1-implement-library-with-shared-favorites-/IMPLEMENTATION-DECISIONS.md`.
These do not turn unspecified details into owner decisions. Current native validation is tracked
with that task; the previous proposal screenshots remain historical comparison evidence.

## Outstanding decisions / limits

- Library structure is selected and implementation authorized (D63–D64). Search A/B remains
  unselected. Keep the previous proposal preview open.
- Exact dual-page indicator normalization was observed; no owner request to change it was recorded.
- The earlier Duo/reader evidence did not establish physical-device, full VoiceOver or RTL coverage.
  Quick task 261015-tx1 adds current Library interactive iPad resizing, native-search continuity,
  selected VoiceOver flows and Duo transition evidence; its VALIDATION.md defines the exact limits.
- Migration completion and post-integration validation are separately tracked; historical passes
  must not be reported as testing a rewritten integrated tree.
