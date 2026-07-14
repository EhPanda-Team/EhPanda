---
gsd_state_version: 1.0
milestone: v3.0.0
milestone_name: milestone
current_phase: 07
current_phase_name: root-privacy-mask-auto-lock-removal
status: executing
stopped_at: Completed 07-12-PLAN.md
last_updated: "2026-07-14T00:46:15.390Z"
last_activity: 2026-07-14
last_activity_desc: Completed Phase 07 Plan 12 locked-decision specification reconciliation
progress:
  total_phases: 11
  completed_phases: 5
  total_plans: 62
  completed_plans: 61
  percent: 98
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-09)

**Core value:** The load-bearing paths — fetch, parse, read, download galleries — keep working; every task is a foundation change held to behavior/appearance parity.
**Current focus:** Phase 07 — root-privacy-mask-auto-lock-removal

## Current Position

Phase: 07 (root-privacy-mask-auto-lock-removal) — EXECUTING
Plan: 12 of 12
Status: Ready to execute
Last activity: 2026-07-14 — Completed Phase 07 Plan 12 locked-decision specification reconciliation
Next: execute Phase 07 gap-closure plan 07-10

Progress: [██████████] 98% (61/62 plans)

## Performance Metrics

**Velocity:**

- Total plans completed: 61
- Average duration: — min
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 9 | - | - |
| 02 | 4 | - | - |
| 03 | 5 | - | - |
| 04 | 14 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 01 P01 | 8min | 2 tasks | 8 files |
| Phase 01 P02 | 8min | 2 tasks | 8 files |
| Phase 01 P03 | 14min | 3 tasks | 150 files |
| Phase 01 P04 | 5min | 3 tasks | 7 files |
| Phase 01 P05 | 7min | 3 tasks | 10 files |
| Phase 01 P06 | 12min | 3 tasks | 2 files |
| Phase 01 P07 | 20min | 3 tasks | 5 files |
| Phase 02 P01 | 8 | 2 tasks | 5 files |
| Phase 02 P02 | iterative | spike + auto-load | 3 files |
| Phase 02 P03 | 6min | 2 tasks | 2 files |
| Phase 02 P04 | 12min | 2 tasks | 4 files |
| Phase 03 P01 | 13min | 2 tasks | 4 files |
| Phase 03 P02 | 12min | 2 tasks | 1 files |
| Phase 03 P03 | 14min | 2 tasks | 4 files |
| Phase 03 P04 | 10min | 2 tasks | 2 files |
| Phase 04 P01 | 11min | 2 tasks | 29 files |
| Phase 04 P02 | 9min | 2 tasks | 3 files |
| Phase 04 P03 | 25min | 2 tasks | 2 files |
| Phase 04 P04 | 18min | 2 tasks | 2 files |
| Phase 04 P05 | 22min | 2 tasks | 2 files |
| Phase 04 P06 | 7min | 2 tasks | 2 files |
| Phase 04 P07 | 8min | 2 tasks | 2 files |
| Phase 04 P08 | 10min | 2 tasks | 5 files |
| Phase 04 P09 | 9min | 2 tasks | 4 files |
| Phase 04 P10 | 7min | 2 tasks | 9 files |
| Phase 04 P11 | 7min | 2 tasks | 8 files |
| Phase 04 P12 | 7min | 2 tasks | 6 files |
| Phase 04 P13 | 8min | 2 tasks | 12 files |
| Phase 04 P14 | 20min | 3 tasks | 30 files |
| Phase 05 P01 | 6min | 2 tasks | 9 files |
| Phase 05 P02 | 9min | 2 tasks | 18 files |
| Phase 05 P03 | 4min | 2 tasks | 5 files |
| Phase 05 P04 | 4min | 2 tasks | 4 files |
| Phase 05 P05 | 7min | 3 tasks | 7 files |
| Phase 05 P06 | 12min | 2 tasks | 2 files |
| Phase 05 P07 | 6min | 2 tasks | 3 files |
| Phase 05 P08 | 15min | 3 tasks | 6 files |
| Phase 05 P09 | 10min | 3 tasks | 7 files |
| Phase 05 P10 | 7min | 3 tasks | 3 files |
| Phase 05 P11 | 3min | 1 tasks | 1 files |
| Phase 05 P12 | 2min | 1 tasks | 1 files |
| Phase 05 P13 | 2min | 1 tasks | 1 files |
| Phase 05 P14 | 4min | 2 tasks | 4 files |
| Phase 05 P15 | 2min | 1 tasks | 1 files |
| Phase 05 P16 | 8min | 1 tasks | 1 files |
| Phase 05 P17 | 3min | 2 tasks | 2 files |
| Phase 05 P18 | 9 min | 1 tasks | 0 files |
| Phase 07 P01 | 8min | 3 tasks | 3 files |
| Phase 07 P02 | 13min | 3 tasks | 7 files |
| Phase 07 P03 | 8min | 3 tasks | 11 files |
| Phase 07 P04 | 8min | 2 tasks | 9 files |
| Phase 07 P05 | 5min | 2 tasks | 5 files |
| Phase 07 P06 | 5min | 2 tasks | 7 files |
| Phase 07 P07 | 6min | 3 tasks | 11 files |
| Phase 07 P08 | 4h30m | 3 tasks | 6 files |
| Phase 07 P09 | 7min | 2 tasks | 2 files |
| Phase 07 P12 | 3min | 2 tasks | 2 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Roadmap: Combine→async/await (Phase 4) stays in this milestone, sequenced after the isolated dep removals.
- Roadmap: WaterfallGrid→Layout (Phase 2) and SwiftUIPager→native paging ScrollView (Phase 3, construct per D-04 not a TabView) are spike-first — validate feasibility before committing.
- Roadmap: Fold cookies→Keychain + networking/cookie/image tests + `.private.filterValue` fix into their open seams (Phases 8–9); defer Parser/Download refactors.
- Roadmap: LINT-01 split — mechanical rules sweep last (Phase 11); refactor-gated rules land with their refactors (`optional_try`→Phase 9; binding/lifecycle/unchecked-subscript→Phases 5–7).
- [Phase 04]: 04-01: Every Request conformer stores an injected URLSession, including DataRequest, with .shared as the behavior-preserving default.
- [Phase 04]: 04-02: Parity capture accepts a closure formed on each concrete request type to avoid protocol-extension static dispatch.
- [Phase 04]: Fetch errors map inside fetch; parse errors map after fetch returns, so parse failures never retry. — Preserves Combine retry placement and one AppError mapping per thrown boundary.
- [Phase 04]: TagTranslator retries metadata but performs its payload download once. — Preserves the frozen two-step Combine chain asymmetry.
- [Phase 04]: Native URLSession structured cancellation remains attached to the caller task. — Stops cancelled HTTP work while TCA preserves identical user-visible behavior.
- [Phase 04]: Login preserves an optional HTTP response while Igneous requires an HTTP response and maps a failed cast to unknown. — Matches the distinct frozen map and compactMap semantics.
- [Phase 04]: Account form and JSON assembly remains duplicated beside temporary publishers until publisher deletion. — Keeps each intermediate commit compiling while frozen structural assertions prove parity.
- [Phase 04]: Async gallery metadata preserves 25-pair chunks, two in-flight requests, and input-order reconstruction. — These are existing flood-control and presentation-order guarantees around the shared gdata transport.
- [Phase 04]: Metadata task-group children return typed Result values. — Preserves AppError typing and structured cancellation across the task-group boundary.
- [Phase 04]: Detail chains retry their first fetch and leave their second fetch un-retried. — Preserves the frozen publisher retry placement for reverse lookup and archive funds.
- [Phase 04]: Image refetch retries its complete three-step chain four times. — Matches the publisher-level genericRetry placement and frozen per-URL attempt counts.
- [Phase 04]: Image fan-out uses a Sendable result record in its throwing task group. — The compiler crashes on the equivalent labeled-tuple expression; the record preserves identical semantics.
- [Phase 04]: Reducer Done actions and handlers remain Result-based during the async consumer switch. — Limits the migration to request acquisition and preserves literal state-machine parity.
- [Phase 04]: TCA request effects use explicit do throws AppError with no casts or unknown fallback. — Keeps typed catch binding load-bearing and makes every failure send explicit.
- [Phase 04]: Reader image effects preserve cancellation identifiers and send ordering during acquisition conversion. — Protects the highest-frequency request path from reducer behavior drift.
- [Phase 04]: DownloadClient and file-operation run/catch effects remain outside the request consumer sweep. — They do not call the request facade and changing them would exceed the plan boundary.
- [Phase 04]: TagTranslator noUpdates remains an explicit failure action during the typed consumer switch. — Exactly preserves the previous inline Result switch outcome.
- [Phase 04]: Throwing DownloadClient functions await typed responses directly while Result-returning APIs rebuild Result explicitly. — Preserves public signatures and minimizes orchestration changes.
- [Phase 04]: Request now requires typed throws and the package source tree is Combine-free. — Makes the compiler enforce async conformance completeness and removes all publisher bridges.
- [Phase 04]: The D-11 scope expanded to all 66 compiler-reported TCA deprecations. — The owner authorized the authoritative compiler inventory so CONC-02 reaches zero warnings.
- [Phase 04]: Presentation modifiers and reducer behavior remain unchanged while scope arguments use TCA 1.26 forms. — Argument-only migrations preserve UI anchors and state-machine semantics.
- [Phase 05]: DeviceType is the sole device-identity representation; boolean isPad is derived only at branch sites.
- [Phase 05]: Gallery navigation accepts the injected main-actor deviceType closure and resolves it inside its effect.
- [Phase 05]: Removed obsolete AppDelegateClient test overrides with the deleted target. — A test-only compatibility target would preserve dead architecture; affected tests pass without it.
- [Phase 05]: AppComponents declares DeviceClient directly because TagSuggestionView owns the injected device fact. — Direct Swift package dependencies make module ownership explicit and compilable.
- [Phase 05]: EhSetting fractions use current container dimensions instead of the old orientation-independent short edge. — This is the locked adaptive-layout delta for rotation and resized containers.
- [Phase 05]: Alert and placeholder widths use the nearest SwiftUI container while preserving their existing factors.
- [Phase 05]: NewDawnView observes only container width and keeps its iPad-specific factor through the injected DeviceClient.
- [Phase 05]: Direct detail width fractions use containerRelativeFrame without geometry state. — This keeps direct fractions container-relative while avoiding unnecessary view state and invalidation.
- [Phase 05]: Archive cells receive the grid's size-class-selected width. — A single selected value keeps adaptive grid metadata and rendered cell frames identical.
- [Phase 05]: Preview thumbnail downsampling uses a fixed 660-pixel cap. — The former regular-width maximum preserves fidelity without coupling image decoding to layout.
- [Phase 05]: Carousel card width, card pitch, and symmetric peek inset derive from one observed container width. — Keeps the coupled view-aligned geometry consistent during rotation and container resizing.
- [Phase 05]: Ranking layout follows horizontal size class while Toplists and title trimming retain device-class semantics through DeviceClient. — Separates adaptive layout decisions from parity-sensitive device identity branches.
- [Phase 05]: Live Text OCR paths and interactive overlays share one captured nonzero size; Canvas uses its closure size only for the full-surface tint. — This preserves normalized coordinate alignment while guarding the initial geometry pass.
- [Phase 05]: Reader gesture math consumes one outer-container size while existing gesture sources continue supplying locations until Plan 05-09.
- [Phase 05]: PageHandler requires isLandscape at every call site; the construction-time resume seed uses portrait mapping until observed geometry is available.
- [Phase 05]: Reader pinch gestures use MagnifyGesture.startAnchor directly while double taps derive their anchor from SpatialTapGesture.location. — Each native gesture source now supplies the coordinate representation its baseline-locked arithmetic expects.
- [Phase 05]: Reader landscape eligibility derives from captured container width greater than height. — One local size now governs dual-page mapping and reader controls under rotation and resized containers.
- [Phase 05]: ApplicationClient selects the last key window from foreground-active scenes, then falls back to the last window of the last scene, preserving the former behavior locally.
- [Phase 05]: Defaults.FrameSize keeps only the device-independent card height and no longer needs main-actor isolation.
- [Phase 05]: Runtime rotation and Live Text visual checks remain explicit manual gates for phase verification rather than being inferred from static or unit-test evidence.
- [Phase 05]: About metadata is the leading Form section so every navigation-bar style preserves it in the scrollable reading order.
- [Phase 05]: Reader placeholders preserve the full vertical container extent while applying the dual-page divisor only to the horizontal axis. — This lets the fixed aspect ratio choose height-bounded sizing in landscape without changing dual-page behavior.
- [Phase 05]: 05-13: CardSlideSection remains the sole owner of carousel card width, pitch, and centered peek; GalleryCardCell fills the proposed slot.
- [Phase 05]: SettingTextField uses its title only as a localized accessibility label; promptText is the sole visible placeholder source.
- [Phase 05]: Each reusable sheet root owns an untitled cancellation-role button at the stable cancellationAction toolbar placement.
- [Phase 05]: Favorites category switching remains direct while sort, date seek, and quick search move into ToolbarFeaturesMenu.
- [Phase 05]: DateSeekButton continues to own its nil-navigation disabled state, and Favorites reducer behavior remains unchanged.
- [Phase 05]: Reader window-control compensation uses the iOS 26 top-leading container corner exclusion and folds in safe-area dimensions only when that exclusion is nonzero.
- [Phase 05]: Home declares systemBackground at its content root so systemGray6 cards stay distinct without changing normal-window appearance.
- [Phase 05]: Multiple-scene support is disabled while every scene would share the single AppDelegate-owned store.
- [Phase 05]: No non-pad gallery-detail entry path bypassed GalleryNavigation; source inventory and reducer probes all resolved phone entries to push. — The no-repro branch requires human confirmation instead of a speculative source change.
- [Phase 05]: Deep-link, URL, and clipboard gallery entries remain the intentional device-independent modal baseline. — These app-route presentations are documented behavior and are separate from host gallery-tap routing.
- [Phase 07]: 07-01: The privacy-mask blur is transient in-memory state and starts at a true zero on every launch.
- [Phase 07]: 07-01: The privacyMask modifier owns a read-only SharedReader so callers need no store scope or blur argument.
- [Phase 07]: loadUserSettingsDone is the single cold-launch clipboard-detection owner; the active scene branch handles later foreground entries. — Pre-load active transitions are ignored, preventing duplicate cold-launch clipboard detection while preserving later foreground behavior.
- [Phase 07]: privacyMaskIntensity remains a version-1 Setting field with default 10 and no migration. — The pre-release schema policy accepts resetting the renamed key to its parity default.
- [Phase 07]: The Privacy Mask slider owns a localized accessibility label and treats its eye icons as decorative. — This keeps the native adjustable control concise for VoiceOver without announcing redundant symbols.
- [Phase 07]: Detail routing blur inputs temporarily default to zero so Home and Favorites can remove drilling before the DetailFeature sweep. — This keeps sequential module commits compiling without retaining blurRadius tokens in migrated modules; plan 07-06 removes the temporary inputs.
- [Phase 07]: DownloadsView keeps the plan-specified ReadingView blurRadius: 0 bridge until 07-07 while all Downloads-owned blur inputs are removed. — ReadingFeature still requires the parameter until its scheduled sweep.
- [Phase 07]: Both Detail-owned ReadingView presentations retain literal blurRadius zero bridges until 07-07. — ReadingView still requires the compatibility parameter; DetailFeature no longer owns or propagates blur state.
- [Phase 07]: 07-07: Privacy-mask coverage is counted as forty application call sites; the public function declaration and shared-key documentation remain valid non-call matches.
- [Phase 07]: 07-07: The AppActivityLogs mask stays on the RunPickerSheet presented root so native sheet accessibility and stable modal coverage are preserved.
- [Phase 07]: The no-content-leak gate combines automated forty-site coverage with owner device-level approval. — Static checks cannot prove App Switcher snapshot concealment or presentation behavior.
- [Phase 07]: Privacy-mask coverage counts forty executable application calls rather than forty-two raw tokens. — The public function declaration and shared-key documentation are valid non-application matches.
- [Phase 07]: The owner post-checkpoint refinement scopes blur animation to the blur transform and keeps Privacy Mask in the first Appearance section. — The owner intentionally refined presentation after verification; current HEAD was rebuilt and retested without rewriting the commit.
- [Phase 07]: 07-09: Scene-phase privacy writes and background latching run before the settings-loaded guard; settings-dependent effects remain gated. — Protects cold-launch App Switcher snapshots without changing initialization-dependent side-effect semantics.
- [Phase 07]: 07-11: Privacy-mask coverage is derived from 39 explicit runtime roots and reconciled against all 41 source presentation modifiers. — A duplicate can no longer compensate for an uncovered root, and preview-only presentations remain explicit exclusions.
- [Phase 07]: 07-11: Privacy blur transitions use no animation when Reduce Motion is enabled. — The true-zero blur and hit-testing threshold remain unchanged.

### Pending Todos

[From .planning/todos/pending/ — ideas captured during sessions]

None yet.

### Blockers/Concerns

[Issues that affect future work]

- Phase 8 (QUAL-02): NetworkingFeature tests couple to Phase 4's async migration but land in the hygiene phase (where CookieClient/ImageClient are reworked) — verify NetworkingFeature parity tests are written against the migrated async layer, not deferred silently.
- Phases 2 & 3 carry genuine parity risk (spike-gated); a failed spike must surface before committing implementation.

### Roadmap Evolution

- Phase 10 edited: renamed to UI Polish; added POLISH-02 (ZStack->overlay/background)
- Phase 10 edited: edited fields: goal, success_criteria

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none)* | | | |

## Session Continuity

Last session: 2026-07-14T00:46:03.758Z
Stopped at: Completed 07-12-PLAN.md
Resume file: None
