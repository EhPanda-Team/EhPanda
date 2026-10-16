---
quick: 261015-tx1
phase: quick-261015-tx1
plan: "01"
subsystem: ui
tags: [library, navigation, swiftui, row-grid, persistence, accessibility]
status: complete
completed: 2026-10-16
requirements-completed: [QUICK-LIBRARY, QUICK-LIST-PRESENTATION, QUICK-CONTINUITY]
provides:
  - Shared Library category navigation with separate Favorites and Downloads groups
  - Independently persisted row/grid presentation and regular adaptive grid
  - Download management parity and current native validation evidence
affects: [app-design, phase-17-capture-routing]
actuals:
  tasks: 3
  commits: 5
  tokens: 56335
tech-stack:
  added: []
  patterns: [native NavigationSplitView, per-source feature state, scoped persisted presentation]
key-files:
  created:
    - AppPackage/Sources/AppFeature/View/Library/LibraryFeature.swift
    - AppPackage/Sources/AppFeature/View/Library/LibraryView.swift
    - AppPackage/Sources/AppModels/Support/GalleryListPresentation.swift
    - AppPackage/Sources/GalleryListComponents/GalleryScrollAnchor.swift
    - Scripts/visual/run-library-validation.py
  modified:
    - AppPackage/Sources/AppModels/Persistent/Setting.swift
    - AppPackage/Sources/GalleryListComponents/GalleryList.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsView.swift
coverage:
  - id: library
    description: Shared category navigation preserves each source's query, path and management identity
    requirement: QUICK-LIBRARY
    verification:
      - kind: unit
        ref: AppPackage/Tests/AppFeatureTests/LibraryNavigationTests.swift
        status: pass
      - kind: automated_ui
        ref: EhPandaUITests/LibraryPresentationUITests.swift
        status: pass
    human_judgment: false
  - id: layouts
    description: Independently remembered row/grid modes migrate old settings and render a regular grid
    requirement: QUICK-LIST-PRESENTATION
    verification:
      - kind: unit
        ref: AppPackage/Tests/AppModelsTests/SchemaMigrationTests.swift
        status: pass
      - kind: automated_ui
        ref: EhPandaUITests/GalleryLayoutUITests.swift
        status: pass
    human_judgment: false
  - id: continuity
    description: Native resize/fold transitions retain Library state and download status
    requirement: QUICK-CONTINUITY
    verification:
      - kind: manual_procedural
        ref: VALIDATION.md
        status: pass
    human_judgment: false
---

# Library and independently remembered row/grid layouts

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Library now combines Favorites and Downloads through the owner-selected shared category navigation,
while each list retains its own presentation preference and management behavior.

## Delivered

- One native Library hierarchy adapts between sequential compact navigation and sidebar/detail.
  Favorites categories and download folders remain separate groups and retain source identity,
  search query, navigation path and visible gallery anchor.
- Frontpage, Popular, Toplists, Favorites, Search and Downloads remember row/grid independently.
  Watched and History have independent scopes; DetailSearch shares Search. A regular aligned lazy
  grid replaces masonry. Column count responds to available space and text size.
- Setting schema v2 maps legacy detail to row and thumbnail to grid once, preserves unrelated
  settings, and removes the retired global picker/key/analytics parameter. New installs and Downloads
  start in row. Category, folder and toplist-period changes stay within their semantic list scope.
- Downloads supports its existing reading, status, move, update/pause/resume and delete paths in
  both renderers. Grid exposes a visible Actions menu and native accessibility actions. Per-gallery
  confirmations retain stable identity/anchors; the manifest and folder-deletion rules are unchanged.
- Native iOS 27 title/search behavior and page-owned soft top scroll edges are retained. No title,
  search-placement or Dynamic Type workaround was added.

## Commits

| Plan work | Commit | Outcome |
|---|---|---|
| Task 1 | `e43ab6bd06` | Library root routing and scoped settings |
| Task 1 tracer | `2b361c1046` | Native presentation menu, regular grid and fixture tracer |
| Task 2 | `f9058a06eb` | Downloads management parity and anchored confirmations |
| Task 3 corrections | `5536aec8ea` | Native category links, pagination and scroll continuity |
| Task 3 gates | `56f906c766` | UI regressions and exact-identity validation runner |

Initial implementation code/test revision: `56f906c76675441de3b79e5fa372c87e5a8bff65` on `agent/app-design`.
The final documentation commit follows these code commits; no self-referential SHA is invented.

## Evidence

- FeatureTests: **959 exact identities**, comprising **949 passes and 10 individually named existing
  expected diagnostics**; zero failures, skips or repetitions across ten selected targets.
- Native UI: **6/6 on iPhone, 6/6 on iPad and 6/6 on Duo**. These exercise layout persistence,
  searched-detail return, real pagination, native titles/grid at standard/AX1/AX3/AX5, source
  switching and local download management including cancel/confirm deletion.
- Builds report zero warnings/errors; strict SwiftLint reports zero violations in 53 changed Swift
  files. Final source hashes match Duo exactly; iPhone/iPad/FeatureTests share the final production
  sources, with later UI-query-only differences explicitly recorded.
- Manual native checks cover live text-size changes, focused search during native iPad window
  resizing, a retained Download Status sheet during resizing, selected real VoiceOver operations,
  reduced effects, and Duo closed/open/half/portrait transitions with retained query and status.
- Thirteen neutral, unedited screenshots and their source/SHA-256 manifest are tracked in
  `screenshots/`. Exact commands, bundles, failures and probe logs remain under `.build/library/`.

See [VALIDATION.md](VALIDATION.md) for the device matrix, source attribution, failures corrected,
actual screenshots and limitations. This is the selected implementation's validation, not exhaustive
whole-app accessibility or every device/orientation permutation. Physical-device rotor activation,
all RTL languages and a separate live iPad rotation with a gallery detail were not repeated. The
Duo simulator retained search focus/query but did not show its software keyboard on inner captures.

## Decisions and plan amendments

Owner decisions D56–D64 are preserved in the session DISCUSSION-LOG, including D64's explicit choice
of shared navigation with separate groups. Engineering choices E01–E22 are recorded separately in
[IMPLEMENTATION-DECISIONS.md](IMPLEMENTATION-DECISIONS.md). Search A/B is still unselected; only its
independent row/grid mode belongs to this task. The old prototype remains comparison material.

The executor drafted source before the planned red tests; this was recorded as an execution
deviation, and no test-first/TDD claim is made. Later scope changes were checkpointed and the
orchestrator recorded amendments before continuing. Runtime findings required native NavigationLink category rows, per-gallery move-dialog
ownership, shared surviving-anchor logic, minimal native row restoration, a lower grid pagination
visibility threshold, isolated fixture image networking, and semantic queries for native vertical
controls. These fixes preserve the selected product scope. Original failing evidence remains intact.
GSD planner/executor dispatch requested the repository-resolved model/effort; runtime model metadata
was not independently available, so the actual runtime model is not asserted here.

## Cleanup and handoff

All dedicated devices returned to their captured text-size/accessibility/boot baselines. iPad returned
to Full Screen Apps; Duo returned to closed hinge and hardware portrait. Test launches were replaced
by normal launches, fresh Home was checked, then devices shut down. No Device Hub was used.

The previous preview remains running and open at `http://127.0.0.1:55920/index.html`. No new dependency,
external configuration, push or pull request is required. Phase 17 and its unrelated owner review gates
remain unchanged. STATE, the session decision log/commit ledger and scroll-edge inventory are updated.

## Owner review follow-up — 2026-10-16

The cleanup state above describes initial implementation delivery. D65 subsequently retires the
proposal preview and requests a running app; D66 authorizes Device Hub for this one native review.
The iPad is now running Library/Favorites in normal logged-out state for owner inspection.

D67 adds the opaque Library sidebar in `82da111f79`. See [SIDEBAR-BACKGROUND.md](SIDEBAR-BACKGROUND.md)
for the rejected native probes, controlled geometry comparison, focused build/lint checks and four
additional unedited screenshots. Earlier broad test results above remain tied to `56f906c766`;
they are not represented as a rerun against this later appearance-only follow-up.

## Native sidebar scroll-edge correction — 2026-10-16

D68 rejects D67's static-color fallback because upward scrolling still exposed a clipped native
blur region. `e257ee2050` removes that fallback and extends only Library's completed
NavigationSplitView through the top container safe area. Native material and progressive blur now
reach behind the status bar, with native controls retaining safe clearance.

See [SIDEBAR-SCROLL-EDGE.md](SIDEBAR-SCROLL-EDGE.md) for scrolled light/dark evidence, iPad rotation,
iPad/iPhone cold and live standard/AX1/AX3/AX5 checks, Duo transitions, clean build/lint, the corrected
AX5 probe timing failure and exact validation limits. Eight additional unedited screenshots are
tracked with hashes. Earlier broad test counts remain historical, not a rerun against `e257ee2050`.
The iPad is open at the scrolled Library for owner review; the proposal preview remains stopped.

## Sidebar navigation and actions — 2026-10-16

`21473abc07` implements D69–D73 with native fixed expanded sidebar preferences, no toggle, Downloads
above Favorites, independent section disclosure, and .sectionActions for folder operations. The
Downloads toolbar no longer duplicates Manage Folders. Create Default Folder shares Detail's
translations and default name, routes to Downloads, and remains guarded through authoritative
refresh; errors are visible and retryable.

Nine focused tests pass with zero compiler warnings/errors; strict lint is clean in eight changed
Swift source/test files. Current native screenshots cover section disclosure, creation, compact
back navigation, four cold/live text sizes, iPad rotation, Duo transitions and retained blur
continuity. See [SIDEBAR-ACTIONS.md](SIDEBAR-ACTIONS.md) for corrected review findings, exact evidence
and limitations. The iPad remains open at Library / Downloads for owner review.

## Header displacement follow-up — owner-deferred

D74 records the owner's intermittent header displacement, also observed with the toggle retained
after sidebar close/reopen. A minimal native app reproduces displacement on Home→Library entry.
No header fix is selected; all failed experiments were reverted. D75 retains the native sidebar
and issue record; the fixed-pane prototype is not adopted. D76 restores the working native
toggle with an initially expanded sidebar, superseding the fixed-open policy. See
[HEADER-STABILITY.md](HEADER-STABILITY.md) and [HEADER-REPRODUCTION.md](HEADER-REPRODUCTION.md).
Earlier build/test passes do not establish header stability.

D76 is implemented in `25848cc4dc`: native column-visibility state restores the functional toggle,
initially expanded. Build and strict lint are clean; iPad hide/show and tab-state retention,
source switching, and iPhone category/back navigation were checked. Four cold/live text sizes
were captured on both devices with native layout differences recorded in the investigation.
The iPad is left running the final app for review; the header issue remains owner-deferred.

## Folder-only Downloads entries — 2026-10-16

D77 is implemented in `b2d1d602dc`: Library removes the generic Downloads navigation row and lists
actual folders. Native section actions and the sidebar toggle remain. The existing source-switching
UI regression now uses a test-owned Inbox folder and passes once on compact iPhone; build and strict
lint are clean. The normal iPad app is updated and left on Library / Default after verifying folder
navigation. See [SIDEBAR-ACTIONS.md](SIDEBAR-ACTIONS.md#folder-only-navigation-follow-up--d77) for the
unedited screenshot, exact evidence and limits.

## Grid appearance and simplified titles — 2026-10-16

Initial D79–D80 delivery in `7b58987a7d` (corner/ratio/line limit superseded by D81) has transparent
containers, square covers with the established adaptive background, and three-line titles centered in flexible space
so every card in a row aligns. Appearance → Gallery adds default-on simplified titles for all
row/grid lists, preserving original stored/search/detail titles and existing settings.

97 model tests and four UI tests pass with no skips/retries, including iPhone/iPad standard and
AX1/AX3/AX5 coverage, setting persistence and Downloads management. Builds and strict lint are clean.
See [GRID-TITLES.md](GRID-TITLES.md) for implementation, failed-attempt corrections, limits and eleven
original screenshots with hashes. The normal iPad is updated and open for review; the prior header
issue remains owner-deferred and the historical proposal preview remains running.

## Cover corners, proportions and title limit — D81

`428897f452` applies the owner's clarification: all four cover corners rounded at 15 points, width:height
2117:3000 from the referenced cover's original metadata, and a two-line grid-title limit. Other
approved appearance and simplified-title behavior is preserved. A native compositing group keeps
the category overlay within the top-right rounded corner.

The final iPad geometry and iPhone native title/grid tests pass at standard, AX1, AX3 and AX5, with
zero build warnings/errors and clean strict lint. Eight unchanged neutral screenshots are retained;
the first visually incorrect attempt and precise verification limits are in
[GRID-TITLES.md](GRID-TITLES.md#cover-correction-verification--d81). Earlier broader tests remain
historical. The review iPad is updated in place and open at Library Favorites; native header
investigation remains deferred and Phase 17 status is unchanged.

## Library grid refinements — D82–D85

`8b2f03519b` implements D82–D84: no horizontal grid metadata padding, ratings hidden for Library
grids only, and native Downloads card context menus replacing visible Actions buttons. The default
rating policy remains enabled elsewhere, and row presentation is unchanged. Confirmation ownership
stays on the originating card with named accessibility actions preserved.

Five focused native UI tests pass across iPad/iPhone with clean builds/lint. Exact selections,
four-size geometry checks, full context-menu operation coverage, corrected text-extent assertion
and fifteen original screenshots are in [GRID-LIBRARY-REFINEMENT.md](GRID-LIBRARY-REFINEMENT.md).
That report also answers D85's inspector question: automatic native adaptation has no public forced
trailing-overlay style. No replacement presentation is selected; Details/Pages stay as implemented.
The updated iPad is open at Library Favorites with its original data and Phase 17 gates unchanged.

## Native floating Downloads trial — D86

`cb029d6db0` implements the owner's request to try floating Details/Pages, using iOS 27 native
trailing form-sheet placement. Wide entry leaves list geometry unchanged; narrow entry keeps
existing navigation. Three final iPad/iPhone UI tests pass, including nested reading/Previews and
rotation; both builds and strict lint are clean. Five original neutral screenshots and the two
discarded overlay variants' findings are recorded in [FLOATING-PANEL-PROTOTYPE.md](FLOATING-PANEL-PROTOTYPE.md).
The review iPad was updated with existing data for that trial. D88 subsequently rejects and
reverts it; the evidence remains historical and does not complete Phase 17.

## Native inspector follow-up — D87

The owner explicitly requests actual SwiftUI inspector after the trailing-sheet trial.
`658ba665b2` was the D87 review candidate: native adaptive inspector for Downloads Details/Pages,
with separate navigation ownership, state-driven Details Close and unchanged card geometry in
the measured iPad overlay. Thirty feature tests and three native UI tests pass with zero build
warnings/errors and zero lint violations. D88 subsequently rejects and reverts the trial because
of its appearance and the recurrence of the top-background continuity issue; Phase 17 is unchanged. [Report and screenshots](NATIVE-INSPECTOR-PROTOTYPE.md).

## Presentation trials rejected and reverted — D88

All non-documentation changes from the D86 “試做一下看看” trial onward are reverted. The prior
Details/Pages routes and sidebar safe-area composition are restored; earlier grid refinements remain.
The sheet effect, inspector transparency and reintroduced top-background discontinuity are the
owner’s rejection reasons. Trial docs and screenshots are retained.
Rollback `b20b6ff8a43d45d8c05d04dcdfb203699201fb9c` restores exact pre-trial source equality.
All 32 selected feature tests and one iPad management UI test pass with clean builds/lint; the
original review iPad is updated in place. See [verification](PRESENTATION-TRIAL-ROLLBACK.md).
