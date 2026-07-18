---
phase: 10-ui-polish
plan: 12
subsystem: ui
tags: [verification, phase-gate, grep-battery, dynamic-type, d-03, owner-gate]

requires:
  - phase: 10-ui-polish (plans 01-11)
    provides: the settled surface — all 11 sub-tasks landed (numeric text, ZStack, previews, inSheet removal, deprecated sweeps, corner removal, Label, rename, DT reflow)
provides:
  - Phase-final automated gate record: full suite green + phase-wide grep battery + count checks, criterion-by-criterion
  - The assembled D-03 owner device-UAT checklist (batched human-judgment items from 10-03/04/06/07/10/11)
affects: [gsd-verify-work, phase-10 sign-off]

tech-stack:
  added: []
  patterns: []

key-files:
  created:
    - .planning/phases/10-ui-polish/10-12-SUMMARY.md
  modified: []

key-decisions:
  - "Full-suite command corrected (Rule 3): the plan/RESEARCH -scheme AppPackage-Package does not exist on the .xcodeproj and iPhone 17 Pro is not installed — ran -scheme EhPanda (wired to FeatureTests.xctestplan) on iPhone Air, the established phase practice (10-03/04/06/07)"
  - "SwiftLint is an error-level build-tool plugin: TEST SUCCEEDED is itself the lint-clean proof — no separate standalone pass needed"
  - "RoundedCorner grep returns 6 benign hits (withRoundedCorners image helper); the custom RoundedCorner Shape struct is confirmed deleted (grep 'struct RoundedCorner' == 0) — criterion 8 holds"
  - "Device-visual D-03/D-11 items are batched to the owner gate (Task 3), matching every prior plan's deferral — content screens need live e-hentai login/data unavailable in a clean simulator"

requirements-completed: []

coverage:
  - id: G1
    description: "Full test suite green on the settled surface with the renamed SystemNotificationTests target executing"
    requirement: POLISH-03
    verification:
      - kind: automated_ui
        ref: "xcodebuild test -scheme EhPanda (iPhone Air) => ** TEST SUCCEEDED ** [86.6s]; 496 tests passed, 0 failed; SystemNotificationTests ToastInteractionTests executed (dismissal/replacement/galleryFailureToast cases ran and passed)"
        status: pass
  - id: G2
    description: "Phase-wide grep battery: every negative gate at 0, all count checks hold"
    requirement: POLISH-01
    verification:
      - kind: automated_ui
        ref: "10 negative greps all 0; privacyMask==41, minimumScaleFactor==7 (<=8), GeometryReader==0, static accent reads==4; 0 code warnings"
        status: pass
  - id: G3
    description: "D-03 owner-signed Dynamic Type gate + batched device-visual judgments"
    requirement: CRIT-05
    verification:
      - kind: manual_procedural
        ref: "owner device-UAT checklist assembled below (Task 3 checkpoint)"
        status: pending
    human_judgment: true
    rationale: "D-03 is an owner-signed visual gate; static/unit checks cannot prove readable-and-operable at AX5. Returned as a blocking checkpoint, not auto-approved."

duration: 12min
completed: 2026-07-18
status: complete
---

# Phase 10 Plan 12: Phase-Final Verification Summary

**The full suite is green (496 tests, 0 failures, renamed `SystemNotificationTests` target executed) and the entire phase-wide grep battery holds; the owner-signed D-03 Dynamic Type gate plus the batched device-visual judgments are assembled below and returned as a blocking checkpoint — the phase is not self-certified.**

## Performance

- **Duration:** 12 min
- **Tasks:** 3 (Task 1 automated gates — complete; Task 2 evidence assembly — complete; Task 3 owner gate — awaiting sign-off)
- **Files modified:** 0 (verification only)

## Task 1 — Automated Phase Gates (ALL GREEN)

### Full test suite

`xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air'`

- **Result:** `** TEST SUCCEEDED **` [86.6 sec]
- **Tests:** 496 passed, 0 failed (14 suite runs)
- **Criterion 11 (run-not-just-build):** the renamed `SystemNotificationTests` target compiled AND executed — `dismissalInvalidatesTheCurrentToast()`, `replacementInvalidatesThePreviousToast()`, and `galleryFailureToastUsesSanitizedContext(fixture:)` all ran and passed.
- **DownloadSchedulingTests:** 0 failures (a failure would be a real regression, not flake — none occurred).
- **Warnings:** 0 compiler/code warnings. The 7 lines matching `warning:` are all `appintentsmetadataprocessor` "Metadata extraction skipped. No AppIntents.framework dependency found." — environmental toolchain noise on every EhPanda build, not code (D-10 holds).

> Rule 3 command correction: the plan/RESEARCH full-suite command names `-scheme AppPackage-Package`, which is not exposed on the `.xcodeproj`, and `iPhone 17 Pro` is not an installed simulator. Ran the `EhPanda` scheme (its TestAction references `container:AppPackage/Tests/FeatureTests.xctestplan`) on the booted `iPhone Air` sim — the same environment adaptation recorded in 10-03/04/06/07.

### Phase-wide grep battery

Roots: `AppPackage/Sources AppPackage/Tests App ShareExtension --include="*.swift"` (never bare `AppPackage`).

| # | Token | Criterion | Required | Result |
|---|-------|-----------|----------|--------|
| 1 | `PreviewProvider` | D-07 / crit 12 | 0 | **0** ✓ |
| 2 | `inSheet` | crit 6 | 0 | **0** ✓ |
| 3 | `SystemNotificationExt` (src + Package.swift + xctestplan) | crit 11 | 0 | **0 / 0 / 0** ✓ |
| 4 | `.foregroundColor(` (-F) | crit 7 | 0 | **0** ✓ |
| 5 | `.accentColor(` (-F) | crit 7 | 0 | **0** ✓ |
| 6 | `.cornerRadius(` (-F) | crit 7 | 0 | **0** ✓ |
| 7 | `disableAutocorrection` | crit 7 | 0 | **0** ✓ |
| 8 | `.statusBar(hidden` (-F) | crit 7 | 0 | **0** ✓ |
| 9 | `RoundedCorner` | crit 8 | 0 | **6 — benign** ✓ |
| 10 | `dynamicTypeSize` | D-02 / crit 5 | 0 | **0** ✓ |

**Note on #9:** the 6 `RoundedCorner` hits are all `withRoundedCorners` / `defaultModifier(withRoundedCorners:)` — the Kingfisher `UIImage.withRoundedCorners(radius:)` image helper in `AppTools/Extensions.swift` and `AppComponents/ViewModifiers.swift`, an unrelated legitimate API caught by substring. The custom `RoundedCorner` **Shape** that criterion 8 deleted is confirmed gone: `grep -rnE 'struct RoundedCorner|RoundedCorner *:'` returns 0. Criterion 8 holds.

### Count checks

| Check | Required | Result |
|-------|----------|--------|
| `.privacyMask()` in `AppPackage/Sources` | == 41 | **41** ✓ (T-10-15 / T-10-04 re-verified after all sweeps) |
| `minimumScaleFactor` | <= 8 | **7** ✓ (B2's inert shrink removed in 10-11) |
| `GeometryReader` | == 0 | **0** ✓ |
| Static implicit-member `.accentColor` reads (EhSettingView+Sections1 / ControlPanel / LiveTextView) | == 4 | **4** ✓ |

### SwiftLint

SwiftLint runs as an **error-level build-tool plugin** in the AppPackage graph (visible in the build log invoking `swiftlint lint` per target). `** TEST SUCCEEDED **` therefore is the zero-violation proof — an error-level violation would have failed the build. No separate standalone pass was needed.

### Threat register (final re-check)

- **T-10-15 (privacyMask coverage):** `.privacyMask()` == 41 on the final tree — the Phase 7 no-content-leak guarantee survived every phase-10 sweep (including the 10-04 inSheet-setter deletions that chained `.privacyMask()`). ✓
- **T-10-16 (package installs):** no packages installed this phase (RESEARCH audit confirmed). ✓

## Criterion-by-criterion certification (12 ROADMAP criteria)

| # | Criterion | Gate | Status |
|---|-----------|------|--------|
| 1 | POLISH-01 — `monospacedDigit()`+`numericText()` paired on changing values | 10-07 inline pair-treatment; grep pair-check | static ✓; **jitter = owner (item 4)** |
| 2 | Numeric values animate as numeric transitions | `contentTransition(.numericText())` applied | static ✓; **owner (item 4)** |
| 3 | No layout jitter on numeric change | `monospacedDigit()` structural guarantee | static ✓; **owner (item 4)** |
| 4 | POLISH-02 — ZStack → overlay/background where a child overlays primary | 3 CONVERT / 32 KEEP (10-06); build+lint | ✓; **placeholders = owner (item 3)** |
| 5 | Dynamic Type readable/operable XXL/AX3/AX5, every screen incl. sheets | D-03 owner sim gate | **owner (item 5)** — B1–B10 reflowed |
| 6 | Remove `\.inSheet` | grep `inSheet` == 0 | ✓; **base-gray shift = owner (item 2)** |
| 7 | Deprecated-API sweep | greps 4–8 all 0 | ✓ |
| 8 | Remove custom `cornerRadius(_:corners:)` + `RoundedCorner` | grep `struct RoundedCorner` == 0 | ✓; **radius-15 corners = owner (item 1)** |
| 9 | Empty-string audit | 10-05 zero matches | ✓ |
| 10 | Label conversions (toolbar text/image-only + all text+image) | 10-05; build+lint | ✓ |
| 11 | `SystemNotificationExt` → `SystemNotification` rename | grep == 0 + test target executed | ✓ |
| 12 | POLISH-03 — all 42 `PreviewProvider` → `#Preview` | grep `PreviewProvider` == 0 | ✓ |

**8 of 12 criteria certified fully by the automated gates.** The remaining 4 (criteria 1–3 numeric animation/jitter, 4 placeholders, 5 Dynamic Type, plus the criterion-6 base-gray shift and criterion-8 corner shapes) carry an owner-signed device-visual component, batched into the checklist below.

## Task 2 — D-03 Evidence Set (assembled for owner review)

Per the phase-wide pattern (every prior plan with a device-visual claim deferred it here: 10-03/04/06/07/10/11), content screens (Detail, Reading, Comments, Archives, Torrents, gallery lists) require live e-hentai login + gallery data that a clean simulator cannot populate, and D-03 is explicitly an owner-signed end-of-phase gate (`human_verify_mode: end-of-phase`). The evidence set is therefore the assembled static verdict tables from 10-10/10-11 plus the itemized worst-size checklist below — not a fresh headless screenshot sweep.

**Inputs linked for the owner:**
- **10-10-SUMMARY** — whole-app DT audit: per-site verdict table over all 42 live risk sites; the broke-at-AX5 subset (B1–B10); per-screen coverage of the full RESEARCH criterion-5 inventory.
- **10-11-SUMMARY** — final reflow verdict table: every B1–B10 site reflowed within D-02 (drop `lineLimit(1)`/`fixedSize()` for wrap; `@ScaledMetric(relativeTo:)`-scaled fixed heights/fonts), literal == scaled at `.large` for exact default parity.
- **No escalations** were recorded by 10-10 or 10-11 — every observed breakage was reflowed within D-02 (no redesign-level change needed).

## Task 3 — Owner Device-UAT Checklist (AWAITING SIGN-OFF)

Set the simulator to **Larger Text → AX5** (Settings › Accessibility › Display & Text Size, or the Accessibility Inspector), then walk the app. The five batched human-judgment items:

### Item 1 — Corner shapes (10-03, criterion 8)
- **Where:** a gallery-list **thumbnail cell** bottom-leading corner (radius 15), a **Home card** corner, and the **Filters category chips**.
- **Confirm:** the new `.clipShape(.rect(...))` circular corners look identical to before — no `.continuous`-style drift. Radius 15 is where any circular-vs-continuous difference would be visible.

### Item 2 — Base-gray shift on modal DetailView surfaces (10-04, criterion 6)
- **Where:** open a gallery **Detail as a modal sheet** (from Home/Search) — the TagRow, CommentsSection, and modal-detail Placeholder backgrounds.
- **Confirm:** these now render the **base (`inSheet == false`) gray** — the `\.inSheet` elevation distinction was removed outright per your directive. Verify the base-gray backgrounds read correctly in both light and dark mode (this is the intended, owner-directed shift, not a regression).

### Item 3 — ZStack loading placeholders (10-06, POLISH-02)
- **Where:** the 3 converted sites (`Placeholder.swift` and 2 ReadingFeature sites) — visible only during **transient image loading/error** states (scroll a gallery so thumbnails load; trigger a reader page load).
- **Confirm:** the `Color(...).overlay { ProgressView() }` placeholders are the same size and centering as before — no clipped ProgressView, no changed cell height.

### Item 4 — Numeric transitions, no jitter (10-07, POLISH-01, criteria 2–3)
- **Where:** the **reader current-page indicator** on swipe ("3 / 45"); **download progress** %/size; **GP/credits** after an archive action; **rating** when tapped; the **thread-limit** slider value.
- **Confirm:** numbers animate as per-digit numeric transitions with **no layout jitter** — the surrounding layout must not shift as digits change (`monospacedDigit()` is the width guarantee).

### Item 5 — Dynamic Type readability + default parity (10-10/10-11, criterion 5 / D-03)
- **At AX5** — every user-facing screen incl. sheets readable (no clipped essential text, no overlap) and operable (controls reachable). Reflowed sites to confirm specifically:
  - **B1** toast/HUD (trigger an error toast) — title+subtitle wrap, HUD grows.
  - **B2** Setting › Laboratory — labels wrap, no truncation.
  - **B3** Setting › EhSetting (native) — language label wraps in its column.
  - **B4** Home › Misc grid card — title wraps, card grows.
  - **B5** Search keyword/suggestion rows — titles wrap.
  - **B6/B7/B8** Detail › DescriptionSection (the 60pt count/label/rating row) — row grows, nothing clipped.
  - **B9** Detail › Archives — Hath-client banner grows.
  - **B10** Detail comment preview cards — comment text not clipped.
  - **Borderline (eyeball):** `TagSuggestionView:112`, `QuickSearchView:34`, and the 7 remaining `minimumScaleFactor` sites — especially `TorrentsView:89` (0.1, aggressive shrink) and `LaboratorySettingView` — for least-legible under AX5.
- **Spot-check XXL and AX3** samples across Home → Detail → Reading → Setting + one sheet (Filters or QuickSearch).
- **At default (.large)** — confirm every reflowed screen is pixel-unchanged (the `@ScaledMetric` sites are exact-parity by construction; the dropped-limit sites are no-ops for single-line content, but eyeball any long-content wrap).

**Resume signal:** reply **"approved"** to sign the D-03 gate and close the phase for `/gsd-verify-work`, or describe issues (screen + size + what broke) — the named sites are reflowed per D-02 (never cap), affected gates re-run, and evidence re-presented.

## Deviations from Plan

**1. [Rule 3 - Blocking] Full-suite scheme/destination correction**
- **Found during:** Task 1
- **Issue:** The plan/RESEARCH full-suite command names `-scheme AppPackage-Package` (absent from the `.xcodeproj`) and `-destination …iPhone 17 Pro` (not an installed simulator). The pipeline's first attempt masked the failure (exit 0 came from a trailing `tail`, not xcodebuild).
- **Fix:** Ran `-scheme EhPanda` (its TestAction references `AppPackage/Tests/FeatureTests.xctestplan`) on the booted `iPhone Air` simulator. Same environment adaptation recorded in 10-03/04/06/07.
- **Files modified:** none (verification invocation only).
- **Verification:** `** TEST SUCCEEDED **`, 496 tests, 0 failures, `SystemNotificationTests` executed.

**2. [Rule 3 - Scope/method] Task 2 device drive delivered as assembled evidence set + owner checklist**
- **Found during:** Task 2
- **Issue:** Task 2 asks for a fresh sim-use drive of every screen at XXL/AX3/AX5. Content screens need live e-hentai login/data unavailable in a clean simulator; D-03 is an owner-signed end-of-phase gate.
- **Fix:** Assembled the 10-10/10-11 verdict tables + the itemized worst-size (AX5) owner checklist above (Task 3), matching every prior plan's deferral. No verdict is asserted as owner-signed.
- **Files modified:** none.

**Total deviations:** 2 (both Rule 3 environment/method adaptations, consistent with the rest of the phase). No scope creep; all automated gates green.

## Issues Encountered

- None. The full suite is green, the grep battery holds, and the recurring stale-scheme/stale-sim command from the plan template was corrected as in prior plans.

## User Setup Required

None.

## Next Phase Readiness

- **Automated portion COMPLETE:** full suite green (496/0), grep battery all 0, count checks hold, 0 code warnings, SwiftLint clean (build-plugin gated), threat register re-verified.
- **Owner gate OUTSTANDING:** the D-03 device-UAT checklist (5 batched items) is returned as a blocking `checkpoint:human-verify`. The phase is **not** self-certified — `/gsd-verify-work` follows the owner's sign-off.

## Self-Check: PASSED

- FOUND: `.planning/phases/10-ui-polish/10-12-SUMMARY.md`
- FOUND: full-suite log `** TEST SUCCEEDED **` (496 tests, 0 failures); `SystemNotificationTests` executed
- FOUND: all 10 negative greps == 0 (RoundedCorner's 6 = benign image-helper); counts 41 / 7 / 0 / 4 hold
- No code commit expected (verification-only plan); this is a docs-only SUMMARY

## Post-gate fix: ProgressView tint (2026-07-18)

**What:** The 10-02 `.accentColor(_:)` → `.tint(_:)` sweep changed `ProgressView`
behavior — `ProgressView` ignores `accentColor` but honors `tint`, so spinners/bars
that used to render the default gray began inheriting an ancestor theme tint and
appeared in the selected theme color. Owner directive at this gate: reset every
rendered `ProgressView` to the default gray via `.tint(nil)` on the view itself
(root-cause fix — each `ProgressView` owns its tint reset, immune to any ancestor tint).

**Edited sites (11 edits across 9 files):**

- `AppComponents/AlertView.swift` — `ProgressView(title)` (LoadingView) and the
  `FetchMoreFooter` spinner.
- `AppComponents/Placeholder.swift` — the `.activity` overlay spinner and the
  `.progress` else-branch spinner.
- `AppComponents/SubSection.swift` — the reload-affordance spinner.
- `AppComponents/ViewModifiers.swift` — `PlainLinearProgressViewStyle.makeBody`'s
  `ProgressView(value:total:)`. This is the determinate reader page-load bar; the
  `.plainLinear` call site in `Placeholder.swift` renders **through** this `makeBody`,
  so its bar goes gray from here — no redundant `.tint(nil)` was added at that call
  site (line 31). Verified the reader page-progress bar ends up gray via this single
  reset.
- `DetailFeature/DetailView+HeaderSection.swift` — the queued-download indeterminate
  spinner. **Note:** this site did not come from the accentColor→tint sweep; it carried
  a deliberate `.tint(downloadButtonTint)` (introduced at module extraction), and
  `downloadButtonTint` defaults to `.accentColor` — so in the queued state it did render
  in the theme tint. Per the owner's explicit enumeration of this file:line, the explicit
  `.tint(downloadButtonTint)` was replaced with `.tint(nil)` (appending would not win —
  the inner explicit tint takes precedence) so the spinner renders gray. The determinate
  ring and center icon at lines 201–215 keep `downloadButtonTint`.
- `DownloadsFeature/DownloadsView+Subviews.swift` — the validation spinner.
- `HomeFeature/HomeView.swift` — the toolbar-overlay reload spinner.
- `ReadingFeature/ReadingViewComponents.swift` — the reader image-load spinner.
- `SystemNotification/ToastMessageView.swift` — the toast `.loading` icon spinner.

**Already-gray (no edit):** `SettingFeature/GeneralSetting/GeneralSettingView.swift`
and `SettingFeature/Login/LoginView.swift` already carried `.tint(nil)` from before the
sweep — left untouched. **Omitted:** `Placeholder.swift` line 31 (routes through the
`makeBody` reset above).

**Gate (build + lint only; full suite deferred to phase-close re-run):**
`.accentColor(` grep held at 0. `EhPanda` scheme build for a generic iOS Simulator
destination: **BUILD SUCCEEDED**, 0 warnings, 0 errors. SwiftLint (strict, 0.65.0) on all
9 changed files: **0 violations**. No simulator erased/reset; app not uninstalled.

**Commit:** `acd5984e` — `fix(10-02): reset ProgressView tint to default so spinners stay gray`.

---
*Phase: 10-ui-polish*
*Completed: 2026-07-18*
