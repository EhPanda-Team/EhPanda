---
type: retrospective-decision-log
recorded: 2026-10-15
source: owner-messages-and-answers-in-this-session
---

# Session decisions

The IDs below describe separate decisions, not new phase requirements. “Implemented” refers
to the source branch before integration. Evidence and its limits are in VERIFICATION.md.
Commit references are indexed in SUMMARY.md. “Proposed” is not owner approval.

## Inherited handoff: locked decisions and boundaries

| ID | Decision / provenance | Disposition |
|---|---|---|
| D01 | Handoff: use local size classes for ordinary layout and presentation; supersede Phase 5 D-03's idiom branching. | Implemented by `69f23462e`, `ff58682f9`; capability policies D26/D31 are explicit later exceptions in scope, not geometry inferred from idiom. |
| D02 | Detail and Setting are modal only when both window size classes are regular; otherwise Detail pushes and Setting is inline. An already inline Setting tab must not also open a sheet. Plus/Pro Max landscape keeps push. | Implemented by `69f23462e`. Existing cold deep-link routing is a separate path, not proof of host-tap routing. |
| D03 | Reader creates/seeds its pager only after measuring its actual container; remove `DeviceClient.isLandscape`, never restore orientation guesses for pager geometry. | Implemented by `c4e9347f1`. |
| D04 | Login/NewDawn prose respects horizontal safe areas; decorative backgrounds may bleed. | Implemented by `7fb7fd1a6`. |
| D05 | Handoff excludes ApplicationClient's appearance scene walk, analytics orientation telemetry, VisualSnapshotSupport, full-bleed reader/backdrop safe areas, and Account/EhSetting bottom safe areas. | Retained scope boundary. |
| D06 | Fix ReaderPageProbe's More lookup for both native horizontal and vertical bars, scoped to the reader and still requiring exactly one result. Inspect hierarchy first; validate on Duo and ordinary iPhone. | Implemented by `b564f590a`, extended SDK identifier in `d7d1de88c`; no global ambiguous query. |
| D07 | Verify unfolded Duo, closed landscape, NewDawn ratio and dual-page resume without changing product behavior until authorized. | Pose checks completed; NewDawn resolved by D28. Spread preserved on resume; exact indicator normalization remains a documented observation, not an owner-selected change. |

## Tools, evidence and working rules

| ID | Decision / provenance | Disposition |
|---|---|---|
| D08 | Owner initially requested waiting for their hinge CLI. First path was `$HOME/Fork/.scripts/sim-pose/sim-pose`; later answer replaced it with `$HOME/Fork/.scripts/foldctl`. | Use foldctl/native pose events. Old path is historical and superseded. |
| D09 | Consult a local reference project's GSD docs and implementation for lessons. | Consulted; reproduce lessons without naming the other project in repository artifacts. |
| D10 | Consult Xcode 27.1 resizability guidance. Later explicit correction: use `app-resizability` and `iphone-duo`, not `impeccable`. | Final proposal follows both requested skills. General visual-design guidance is not its authority. |
| D11 | Owner questioned and rejected the need for Device Hub, then requested continued verification and remaining work. | No Device Hub needed or used for the recorded final checks; use dedicated simulator tools and foldctl. |
| D12 | Preserve other sessions' simulators/work and primary checkout changes; run one simulator test process at a time, no push/PR without request. | Continuing constraint. Handoff also requires conventional atomic commits, warning-free code/test builds, no weakened assertions or lint suppression. |
| D13 | Handoff: if subagents are used, explicitly request GPT 6.1 Sol, do not inherit full history, and stop on ambiguity. | Dispatch constraint, not proof of any runtime model. Later project GSD dispatch rules apply to GSD roles. |
| D14 | Owner requested actual screenshots for visual choices and proposals. | Crease A/B/C, NewDawn 60/50 and wide-screen A/B comparisons produced; screenshot scope must be labeled. |

## Home, title, tabs and opposite-side presentations

| ID | Decision / provenance | Disposition |
|---|---|---|
| D15 | Half-fold Duo Home: slideshow, Frontpage and Other left; Toplists right. | `fbfc01d1f`; expanded device/posture scope by D31, D32. |
| D16 | Clarification answer: each Toplists category vertically lists six galleries, rather than six across. | `fbfc01d1f`; retained in split Home. |
| D17 | Left-origin actions present sheets on the right; right-origin actions on the left. Frontpage, Toplists, Popular, Watched and History full lists must also be sheets in split Home. | `fbfc01d1f`; nested gallery details reverse side again; list survives child dismissal. Expanded by D31. |
| D18 | Right-pane dragging must not change Home title size or position. Owner explicitly selected this over merely keeping a smaller title visible. | `c005393aa`: independent native navigation hosts. Failed minimization experiment is not the final solution. |
| D19 | Add a hinge separator and propose several looks. Owner chose “B”. | `2a2aef98a`: 18 pt soft crease; alternatives A one-pixel separator, C 28 pt book-spine treatment were rejected by selection. Decorative overlay, no hit testing/layout width/accessibility entry. |
| D20 | Owner: split/crease only when Duo is half-folded **and landscape**, not portrait. | `506d15d14`; portrait exclusion retained. Half-fold-only scope later expanded by D31/D32. |
| D21 | Reduce vertical tabs' space consumption with native APIs. | `fbfc01d1f`: native toolbar-first compression when space is limited. Scroll-driven hiding experiments did not work and were removed; do not claim scrolling collapses tabs. |
| D22 | Owner reported tab bar moved to bottom. Preserve native Duo side tabs. | `1bc342889`: split only Home root; pushed destinations retain edge-reaching navigation host. Replaces the temporary global vertical-bar opt-out from `506d15d14`. |
| D23 | Owner: Refresh applies to all Home, including Toplists, and can live in side toolbar. | `b22b0cd54`: one shared Reload at the edge-reaching host; `fetchAllGalleries` still refreshes slideshow/Popular, Frontpage and all ranking categories. |

## Reader behavior and settings

| ID | Decision / provenance | Disposition |
|---|---|---|
| D24 | Owner approved keeping the page indicator visible while reader controls are visible, using native navigation-bar minimization API. | `b564f590a`: installed SDK spelling is `.toolbarMinimizationBehavior(.never, for: .navigationBar)`, not the older `toolbarMinimizeBehavior` proposed in the question. Panel show/hide remains intact. |
| D25 | Show the dual-page toolbar item on every device in landscape, no longer only iPad. | `d7d1de88c`; ordinary iPhones can use it manually, including from vertical reading. |
| D26 | iPad and Duo only: automatic landscape → horizontal plus dual page; portrait → single page and configurable other direction. Default enabled; settings can disable; landscape RTL/LTR configurable, default RTL; portrait default vertical and configurable. | `d7d1de88c`; ordinary iPhones excluded. Device capability is separate from measured layout geometry. |
| D27 | Explicit answer: apply automatic reading mode on initial opening as well as rotation. | `d7d1de88c`; opt-out/reentry/re-enable and page preservation verified. |
| D28 | iPad NewDawn: owner first requested both 60% and 50% screenshots, then chose 50%. | `19a557ec5`: Canvas width ≥500 pt uses 50%; narrower 60%. Actual compact-class iPad sheet is 580 pt; no idiom geometry branch restored. Supersedes unresolved handoff ratio. |
| D29 | Slider preview must remain throughout a long pressed drag, even before release. | `334a9876d`: complete touch lifetime via GestureState; native Slider retains value/accessibility ownership. Multiple editing pairs during one touch were the cause. |
| D30 | Half-fold Duo landscape lower panel uses right half and omits the second bottom Close. | `2224ba1d9`; default right side retained but movable and extended by D31/D34. |

## Extension to fully open Duo and iPad

| ID | Decision / provenance | Disposition |
|---|---|---|
| D31 | Owner asked to extend half-fold behavior, including opposite-side sheets, to fully open Duo and iPad landscape. | `7527c96bb`: Home-origin opposite-side and nested presentation flow extended. This is not a claim that every sheet in every tab has opposite-side support. |
| D32 | Answer: also wants Home dual columns, conditional on iPad tab placement. Owner then required a separator whenever dual columns are used, not only when folded. | `7527c96bb`: iPad landscape additionally requires top tab placement and ≥640 pt content width; open/half Duo landscape qualifies; cover/portrait do not. Initial all-device crease superseded for iPad by D38. |
| D33 | Investigate iOS 27 arrangement for a half-width slider while completely open. | Native 27.1 split arrangement feasibility proved at 0.5 ratio; overlay did not force half width. Production keeps shared safe-area-aware geometry and supports deployment target 27.0; arrangement adoption itself was not required by owner. |
| D34 | Add equally tall glass buttons using `inset.filled.lefthalf.arrowtriangle.left.rectangle` and `inset.filled.righthalf.arrowtriangle.right.rectangle` to move slider left/right. | `7527c96bb`, `52c668497`; typed SF symbols, at least 44 pt row height, physical sides independent of text direction. |
| D35 | Owner: move button belongs on the **other** half, because current slider may be hard to reach. | `52c668497`; supersedes initial same-side button arrangement. |
| D36 | Slider swap must animate; iPad lower Close must stay centered **above the slider** as before. Only Duo landscape omits duplicate lower Close because its main Close is on side. | `52c668497`: slider and iPad Close move together with 0.35 s smooth animation. |
| D37 | Owner saw no transition and questioned Reduce Motion remaining on. | Simulator Reduce Motion caused immediate movement. With it off, recorded intermediate frames establish actual movement; product continues to honor Reduce Motion. Later review session left iPad/Duo Reduce Motion off. Do not remove accessibility support to force animation. |
| D38 | Owner superseded all-device crease: **only Duo uses crease**; iPad Home uses ordinary divider and does not extend into tab bar. | `5859cf619`; top content boundary respected, bottom may extend. |
| D39 | Owner requested thicker divider and corrected “vertical padding” to **top padding**. | `8ca48f567`; preserve bottom extent, avoid tab area. |
| D40 | Owner: iPad Toplists cells are too wide, filling entire right half. | `8ca48f567`: restore constrained ranking cell width; six vertical items retained. |
| D41 | Owner: “再粗一點”. | `79a59892e`: final plain iPad divider is **2 pt**, centered overlay that consumes no pane width. |
| D42 | Owner asked to launch iPad for review before continuing move-button changes. | iPad launched for review; simulator remains available. Review request is not automatic approval of unrelated proposals. |

## Verification discoveries and handoff corrections

| ID | Decision / provenance | Disposition |
|---|---|---|
| D43 | Owner reported all reader images failing on open. | Agent had left `EHPANDA_UITEST_STUB_NETWORK=1` and fixture path active; unknown paths returned 404. Normal relaunch cleared flags; live reader smoke passed. No production networking patch. Mandatory cleanup lesson in LEARNINGS.md. |
| D44 | Handoff rotation through XCTest failed on Duo; owner supplied foldctl. | Host pose driver and separate inner/cover mapping used; dedicated-device restart cleared stale display routing. No app workaround for simulator state. |
| D45 | Retain reader exact-page/visible-pixel assertions and scoped More/Close queries while adapting tests to actual toolbar placement. | `b564f590a`, `c8a4294f9` and follow-ups. Fix hit points/identifiers, not expectations. Native inner-display screenshot limitations are disclosed. |
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

## Outstanding decisions / limits

- Owner has not selected Favorites/Search/Downloads A or B; keep review open.
- Exact dual-page indicator normalization was observed; no owner request to change it was recorded.
- Physical device, full VoiceOver, interactive iPad resizing, live RTL-language UI and native-search
  continuity are not established by the retained simulator evidence.
- Migration completion and post-integration validation are separately tracked; historical passes
  must not be reported as testing a rewritten integrated tree.
