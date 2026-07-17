---
phase: 10-ui-polish
plan: 03
subsystem: ui
tags: [swiftui, clipshape, unevenroundedrectangle, deprecation, ios26]

# Dependency graph
requires:
  - phase: 10-ui-polish
    provides: "10-02 completed the deprecated color-modifier sweep (criterion 7 color portion)"
provides:
  - "Zero bare deprecated corner-radius / autocorrection / status-bar modifier calls remain"
  - "Custom cornerRadius(_:corners:) modifier and UIBezierPath-backed RoundedCorner shape deleted"
  - "CategoryLabel dead corners parameter removed; uneven corner moved to native .rect shorthand at its one caller"
affects: [ui-polish remaining plans]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Even clip via .clipShape(.rect(cornerRadius:)); uneven clip via .clipShape(.rect(bottomLeadingRadius:)) — default .circular style preserves the removed UIBezierPath circular-arc appearance"

key-files:
  created: []
  modified:
    - AppPackage/Sources/AppComponents/ViewModifiers.swift
    - AppPackage/Sources/AppComponents/CategoryView.swift
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift
    - AppPackage/Sources/HomeFeature/HomeView+Sections.swift

key-decisions:
  - "The plan's premise that CategoryLabel's corners param was dead flexibility was inaccurate — GalleryThumbnailCell actively used corners: .bottomLeft. Preserved parity by moving the uneven clip to the caller (.rect(bottomLeadingRadius: 15)) and passing cornerRadius: 0 so the label background stays flat and the outer clip is the sole shape."
  - "No style: argument added to any .rect clip — default .circular exactly matches UIBezierPath byRoundingCorners arcs (Pitfall 3 avoided)."

patterns-established:
  - "Deprecated .cornerRadius(N) → .clipShape(.rect(cornerRadius: N)); uneven corners → .clipShape(.rect(<corner>Radius:)) rather than a custom UIRectCorner shape"

requirements-completed: [CRIT-07, CRIT-08]

coverage:
  - id: D1
    description: "16 bare deprecated corner-radius calls converted to .clipShape(.rect(cornerRadius:)); 6 autocorrection calls to .autocorrectionDisabled; 1 status-bar call to .statusBarHidden"
    requirement: "CRIT-07"
    verification:
      - kind: automated_ui
        ref: "grep -rnF '.cornerRadius(' / 'disableAutocorrection' / '.statusBar(hidden' AppPackage/Sources App ShareExtension == 0 hits"
        status: pass
      - kind: integration
        ref: "xcodebuild build -scheme AppFeature -destination 'iOS Simulator,iPhone 17e' == BUILD SUCCEEDED, 0 warnings, SwiftLint plugin clean"
        status: pass
    human_judgment: false
  - id: D2
    description: "Custom cornerRadius(_:corners:) modifier + UIBezierPath RoundedCorner shape deleted; CategoryLabel corners parameter removed; both remaining call sites on native shorthands"
    requirement: "CRIT-08"
    verification:
      - kind: automated_ui
        ref: "grep -rnF 'RoundedCorner(' / 'UIRectCorner' / 'UIBezierPath' (ViewModifiers) == 0 hits; CategoryView has no corners param; GalleryThumbnailCell contains clipShape(.rect(bottomLeadingRadius: 15"
        status: pass
      - kind: integration
        ref: "xcodebuild build -scheme AppFeature == BUILD SUCCEEDED"
        status: pass
    human_judgment: false
  - id: D3
    description: "Radius-15 corner visual parity (D-11 spot-check): thumbnail bottom-leading corner, card corner, CategoryView chips render identically to pre-change"
    requirement: "CRIT-08"
    verification:
      - kind: automated_ui
        ref: "grep -rnF 'style: .continuous' == NONE (all 22 new .rect clips use default .circular, mathematically identical to removed UIBezierPath circular arcs)"
        status: pass
    human_judgment: true
    rationale: "Plan mandates on-device sim-use screenshots of populated gallery/home/filters surfaces. Live capture of gallery thumbnails and home cards requires authenticated network data unavailable in this headless execution; parity is proven structurally (circular style preserved, no continuous added) but a human should confirm the radius-15 corners on device."

# Metrics
duration: 15min
completed: 2026-07-18
status: complete
---

# Phase 10 Plan 03: Deprecated corner/autocorrection/status-bar sweep + custom corner machinery removal Summary

**Killed the last bare deprecated corner-radius, autocorrection, and status-bar modifier calls and deleted the UIBezierPath-backed RoundedCorner shape, replacing all corner clipping with native SwiftUI .rect shorthands at appearance parity.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-07-17T15:47:00Z
- **Completed:** 2026-07-17T16:02:00Z
- **Tasks:** 3
- **Files modified:** 21

## Accomplishments
- 16 bare `.cornerRadius(N)` → `.clipShape(.rect(cornerRadius: N))`, 6 `.disableAutocorrection` → `.autocorrectionDisabled`, 1 `.statusBar(hidden:)` → `.statusBarHidden` — all four deprecated families now at 0 hits.
- Deleted the custom `cornerRadius(_:corners:)` View modifier and the `UIBezierPath`-backed `RoundedCorner: Shape` from ViewModifiers.swift, removing a UIKit bridge that iOS 26 SwiftUI covers natively.
- Removed `CategoryLabel`'s `corners: UIRectCorner` parameter (its only non-default caller, GalleryThumbnailCell, now applies the uneven clip natively) — `UIRectCorner` is gone from the entire source tree.
- Build + integrated SwiftLint green (0 warnings, 0 violations); no `style: .continuous` introduced, so corner appearance is preserved by construction.

## Task Commits

Each task was committed atomically:

1. **Task 1: Bare corner-radius, autocorrection, and status-bar sweeps** - `4a48e23b` (refactor)
2. **Task 2: Delete cornerRadius(_:corners:) + RoundedCorner; convert 2 call sites** - `1e76f0be` (refactor)
3. **Task 3: Build/lint gate — line_length reflow fix surfaced by the build** - `7c2bf26e` (style)

**Plan metadata:** (final docs commit)

## Files Created/Modified
- `AppComponents/ViewModifiers.swift` - Deleted custom corners modifier + RoundedCorner UIBezierPath shape
- `AppComponents/CategoryView.swift` - Dropped CategoryLabel corners param; even clip via .rect; CategoryCell bare conversion
- `GalleryListComponents/Cells/GalleryThumbnailCell.swift` - Uneven chip corner via .rect(bottomLeadingRadius: 15); cell bare conversion
- `HomeFeature/HomeView+Sections.swift` - Two bare conversions; row-image clipShape wrapped for line length
- 17 more files: mechanical 1:1 modifier swaps (SettingView, LaboratorySettingView, GalleryRankingCell, GalleryCardCell, GalleryHistoryCell, TagCloudView, NewDawnView, SettingTextField, Placeholder, DetailView+CommentCells, DetailView+Subviews, AccountSettingView, EhSettingView+Sections3, LoginView, FolderManagerView, QuickSearchView, ReadingView)

## Decisions Made
- **Corner-parameter relocation over deletion of behavior.** The plan described `CategoryLabel.corners` as dead flexibility with both callers on `.allCorners`; in fact `GalleryThumbnailCell` passed `corners: .bottomLeft` to round only the chip's inward corner. Rather than lose that appearance, the uneven clip moved to the caller as `.clipShape(.rect(bottomLeadingRadius: 15))`, with `CategoryLabel` called at `cornerRadius: 0` so its background stays a plain rectangle and the outer clip alone defines the shape — pixel-identical to the old bottom-left-only rounding. A brief comment documents this deliberate `cornerRadius: 0`.
- **No `.continuous` style anywhere.** The removed `UIBezierPath(roundedRect:byRoundingCorners:)` draws circular quarter-arcs; `.rect`'s default `.circular` style is the exact equivalent. Adding `.continuous` would change the curve (Pitfall 3), so it was deliberately omitted — verified by grep.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Line-length violation from a mechanical conversion**
- **Found during:** Task 3 (build/lint gate)
- **Issue:** Converting `.cornerRadius(2)` → `.clipShape(.rect(cornerRadius: 2))` on `HomeView+Sections.swift:284` pushed the already-long `.frame(...).clipShape(...)` line to 121 chars, tripping the `line_length` error (limit 120), failing the build.
- **Fix:** Split `.clipShape(...)` onto its own line under the `.frame(...)` chain.
- **Files modified:** AppPackage/Sources/HomeFeature/HomeView+Sections.swift
- **Verification:** Rebuild → BUILD SUCCEEDED, 0 warnings, SwiftLint clean.
- **Committed in:** `7c2bf26e`

**2. [Rule 3 - Blocking] Build destination/scheme substitution**
- **Found during:** Task 3
- **Issue:** The plan's `AppPackage-Package` scheme is not exposed on the .xcodeproj, and the `iPhone 17 Pro` simulator is not installed.
- **Fix:** Built the `AppFeature` umbrella scheme (transitively covers every touched feature module) against the available `iPhone 17e` simulator by device id.
- **Files modified:** none (build invocation only)
- **Verification:** BUILD SUCCEEDED covering all 21 modified files' modules.
- **Committed in:** n/a

---

**Total deviations:** 2 (1 Rule 1 lint fix, 1 Rule 3 build-invocation substitution)
**Impact on plan:** No scope creep. The lint fix is a formatting-only reflow; the scheme/sim substitution is an environment adaptation of the verification command.

## Issues Encountered
- **D-11 live visual spot-check not captured.** The plan asks for on-device sim-use screenshots of a gallery thumbnail corner, a card corner, and the Filters category chips. Gallery-list and home-card surfaces require authenticated network data to populate, which is unavailable in this headless execution. Corner-shape parity is instead proven structurally: no `style: .continuous` was added (grep confirms 0 hits), so all new `.rect` clips use the default `.circular` style — the exact geometric equivalent of the removed `UIBezierPath` circular arcs. A human sign-off on the radius-15 corners is flagged in coverage D3.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Criterion 7 fully swept (color portion in 10-02, corner/autocorrection/status-bar here); criterion 8 fully satisfied (custom modifier + shape deleted, call sites native).
- Remaining ui-polish plans (10-04..10-12) unaffected; no shared symbols broken.
- Recommended: quick on-device glance at a gallery-list thumbnail's bottom-leading corner to close D3.

## Self-Check: PASSED
- Files verified present: ViewModifiers.swift, 10-03-SUMMARY.md
- Commits verified in history: 4a48e23b, 1e76f0be, 7c2bf26e

---
*Phase: 10-ui-polish*
*Completed: 2026-07-18*
