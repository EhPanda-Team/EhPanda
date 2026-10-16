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
