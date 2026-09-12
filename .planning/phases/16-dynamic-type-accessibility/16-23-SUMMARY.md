---
phase: 16-dynamic-type-accessibility
plan: 23
subsystem: accessibility
tags: [contrast, wcag, color-mix, colorset, rating-star, increase-contrast, d-28, d-22, d-24, d-25]

# Dependency graph
requires:
  - phase: 16-13
    provides: "`16-CONTRAST-AUDIT.md § Non-category colours` rows 1–28, § Findings ids, § Decisions `STARS=B` / `D28=ok`, the pixel-measurement method and the before numbers"
  - phase: 16-14
    provides: "`Color+Contrast.swift` — `contrastingForeground(in:)` used for the Read glyph; `CategoryColorsetInvariantTests` as the category guard"
  - phase: 16-15
    provides: "The `CategoryLabel` pattern (`@Environment(\\.self)` + `contrastingForeground(in:)`) reused for `read-glyph`"
  - phase: 16-22
    provides: "The `log-glyph-error` D-28 hand-over row and the `Level.symbol` extension the new `glyphColor` sits beside; the environment notes (iPhone 17e `67377A20…`, install-over, baselines)"
provides:
  - "`Color.ratingStar` (public, `AppComponents/RatingView.swift`) backed by `AppComponents/Resources/Colors.xcassets/RatingStar.colorset` — light `#A38100`, dark `#FFD600`, light+HC `#A16A00`, dark+HC `#FEDF43`; used at the five star sites and the `RatingView` previews (STARS=B, no escalation)"
  - "`Color.commentLink` (internal, `DetailFeature/Components/LinkedText.swift`) backed by `DetailFeature/Resources/Colors.xcassets/CommentLink.colorset` — light `#54832A`, dark `#96D35F`, HC `#2A4015` / `#E1FFC6`; underline on every comment link run (detected runs in `LinkColoredText`, parsed runs in `CommentsView`)"
  - "Read glyph colour from the resolved accent via `Color.accentColor.contrastingForeground(in: environment)` (`DetailView+HeaderSection.swift`)"
  - "Comment preview date `.primary`; offline notice text `.primary` with the glyph alone `.orange`"
  - "The `Color.mix(with: .black, by:)` idiom (default perceptual space) with doc-commented factors: swipe Pages indigo 0.3, Move teal 0.35, Update orange 0.3; Activity-log `.error` glyph 0.15 via `OSLogEntryLog.Level.glyphColor`; NewDawn light top stop 0.25; General tags warning yellow 0.3"
  - "`16-CONTRAST-AUDIT.md § 16-23 result (contrast)`: before/after table for every changed site in light / dark / light+IC / dark+IC, kept rows, observations, D-25 note (no screen added)"
affects: [16-24 (star and link colours now asset-driven), 16-26 (D-25 unchanged: no new screen; Nutrition Label caveats — `secondary-meta`, system-drawn swipe text labels, Home card dark gradient)]

# Actuals (#2632) — estimateTokens scale (chars/4 over the realized diff); commits measured from the plan ledger.
actuals:
  tokens: 10957
  tasks: 3
  commits: 4
plan_head_before: 54a3453199491d5d570159ad1b29615b73b3785c

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Darken a failing system tint or glyph colour at its use site with `Color.mix(with: .black, by:)` in the default perceptual space; pick the factor by resolving SwiftUI's own `mix` for the audited input colours (a macOS `swiftc` probe reproduces the iOS bytes exactly), take the smallest twentieth that clears the threshold in all four modes, and doc-comment factor and measured ratios"
    - "A colour that needs different values per scheme or contrast lives in a module colorset under `Sources/<Module>/Resources/Colors.xcassets` (picked up by the existing `.process(.resources)` rule) and is exposed once as a `Color` static, never as a `colorScheme` switch at call sites"
    - "A glyph on a tinted control picks black or white from the resolved tint through `contrastingForeground(in:)` with the whole environment captured, so Increase Contrast's accent transform is followed"

key-files:
  created:
    - AppPackage/Sources/AppComponents/Resources/Colors.xcassets/RatingStar.colorset/Contents.json
    - AppPackage/Sources/DetailFeature/Resources/Colors.xcassets/CommentLink.colorset/Contents.json
  modified:
    - AppPackage/Sources/AppComponents/RatingView.swift
    - AppPackage/Sources/AppComponents/NewDawnView.swift
    - AppPackage/Sources/DetailFeature/DetailView.swift
    - AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift
    - AppPackage/Sources/DetailFeature/DetailView+CommentCells.swift
    - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
    - AppPackage/Sources/DetailFeature/Components/LinkedText.swift
    - AppPackage/Sources/DetailFeature/Comments/CommentsView.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsView.swift
    - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift
    - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift
    - AppPackage/Sources/HomeFeature/GalleryCardCell.swift
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift
    - .planning/phases/16-dynamic-type-accessibility/16-CONTRAST-AUDIT.md
    - .planning/phases/16-dynamic-type-accessibility/deferred-items.md

key-decisions:
  - "STARS=B without escalation: the Home card re-measured `#A38100` on `#E8E8E9` at exactly 3.0102 from rendered pixels, so the audit's recommended value stands and `#A16A00` was not needed"
  - "Swipe factors clear all four modes (dark+IC included) rather than stopping at the audit's 'platform limit': with `mix` the pastel Increase-Contrast tints darken too, so Pages 0.3 / Move 0.35 / Update 0.3 are the smallest twentieths with no residual"
  - "`comment-link` fixed at the site that actually rendered the audited runs (`CommentsView`'s parsed `.linkedText` / `.singleLink` `Text`s) as well as `LinkColoredText`; one colorset, one underline carrier, for all three"
  - "The `CommentLink` colorset copies the accent's rendered dark and Increase Contrast values instead of referencing the accent, so the variants that already passed change by nothing; the coupling is doc-commented and logged in deferred-items"
  - "Error glyph darkened by 0.15 (3.52 in light), not the swipe's 0.3: different threshold (3:1), different module, smallest step with half a unit of margin everywhere; `Level.color` untouched"

patterns-established:
  - "Rendered-basis validation for source-derived rows: when a state cannot be reached, derive its colour from the same API the code uses (`Color.mix`) on the audit's rendered inputs, and cite the rendered sites where the identical machinery produced byte-exact matches"

requirements-completed: [A11Y-02]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Every `D28=ok` id fixed at its site with doc-commented factors/values (`read-glyph`, `comment-link` incl. underline, `comment-date`, `offline-notice`, `swipe-move`, `swipe-pages`, `swipe-update`, `newdawn`, `log-glyph-error`); `swipe-delete` / `swipe-pause` / `secondary-meta` / toast recorded as kept; no category colorset changed"
    requirement: "A11Y-02"
    verification:
      - kind: unit
        ref: "xcodebuild test -scheme EhPanda -testPlan FeatureTests on 67377A20… — DetailFeatureTests 26/6, SystemNotificationTests 4/2, DownloadsFeatureTests 488/84 (8 pre-declared known issues), SettingFeatureTests 60/13 (2 pre-declared) — TEST SUCCEEDED; `DownloadsSwipeActionSourceTests` 4/4"
        status: pass
      - kind: other
        ref: "`xcodebuild build -scheme EhPanda -destination 'generic/platform=iOS Simulator'` BUILD SUCCEEDED, 0 `Violation:` lines (three runs); `git diff --quiet -- App/Assets.xcassets/Category` exit 0; `swiftlint:disable` added 0; `mix(with:` DownloadsView 3, DetailView 0 (the offline notice is `.primary` text per the audit, not a mix)"
        status: pass
    human_judgment: false
  - id: D2
    description: "`RatingStar.colorset` (light / dark / high-contrast) in `AppComponents/Resources/Colors.xcassets`, `Color.ratingStar` exposed once, five star sites + previews switched"
    requirement: "A11Y-02"
    verification:
      - kind: other
        ref: "`grep -rc 'foregroundStyle(.yellow)'` = 0 at the four non-preview star sites and in RatingView.swift; `RatingStar.colorset/Contents.json` exists with four entries; `AppComponents` already declared `resources: [.process(.resources)]` (no manifest edit)"
        status: pass
      - kind: unit
        ref: "xcodebuild test … -only-testing:GalleryListComponentsTests (7/1) -only-testing:HomeFeatureTests (24/5) -only-testing:DetailFeatureTests (26/6) -only-testing:AppToolsTests (24/4, `CategoryColorsetInvariantTests` passed) — TEST SUCCEEDED"
        status: pass
    human_judgment: false
  - id: D3
    description: "Install-over; four-mode before/after table for every changed site appended as `### 16-23 result (contrast)`; every `after` ≥ threshold; D-25 note; baselines restored"
    requirement: "A11Y-02"
    verification:
      - kind: automated_ui
        ref: "32 captures under `$HOME/Library/Caches/ehpanda-phase16/round2/contrast-after/`, measured by the 16-13 pixel method: stars 3.69 / 12.05 / 4.59 / 11.69 (list) and 3.01 / 5.51 / 3.54 / 6.06 (card); Read 6.37 / 11.75 / 6.93 / 18.17; links 4.51 / 7.82 / 11.40 / 11.09; date 16.73 / 13.94 / 14.78 / 12.06; Pages 10.16 / 7.78 / 11.49 / 5.20; Move 6.18 / 5.47 / 10.63 / 4.98; error glyph 3.52 / 6.20 / 6.54 / 6.80"
        status: pass
      - kind: other
        ref: "`grep -c '### 16-23 result (contrast)'` = 3 (heading + two D-25 references); absolute home paths 0 in the audit, the SUMMARY and deferred-items; image check 0 before every commit; `xcrun simctl ui` read back light / large / disabled; simulator Shutdown"
        status: pass
    human_judgment: true
    rationale: "Whether the darkened stars, tints and link colour still read as the design the owner intended is a visual judgment; the owner reviews the captures listed below against the 16-13 befores (D-33)"

# Metrics
duration: 36min
completed: 2026-09-12
status: complete
---

# Phase 16 Plan 23: Non-category contrast fixes and the rating-star decision Summary

**Every `D28=ok` site now clears its WCAG threshold in light, dark and both Increase Contrast variants from rendered pixels: the rating stars draw from a `RatingStar` colorset (light `#A38100`, re-measured 3.01:1 on the Home card, so no escalation), the Read glyph picks black or white from the resolved accent with the 16-14 helper, comment links are `#54832A` and underlined at all three drawing sites, the preview date and offline-notice text are `.primary`, the Pages / Move / Update swipe tints and the error-log and warning glyphs are the same hues mixed toward black by doc-commented factors, and the NewDawn light gradient's top stop is darkened — colour only, no layout, no category colorset touched.**

## Performance

- **Duration:** 36 min
- **Started:** 2026-09-12T00:21:57Z
- **Completed:** 2026-09-12T00:58:00Z
- **Tasks:** 3
- **Files modified:** 20 (14 Swift, 2 colorsets with their `Colors.xcassets/Contents.json`, 2 planning)

## Accomplishments

- Criterion 10's non-category half is backed by after-measurements: 13 fixed or re-checked sites × 4 modes in `16-CONTRAST-AUDIT.md § 16-23 result (contrast)`, every `after` ≥ threshold, no `accepted residual` (the owner vetoed nothing). The `swipe-delete` / `swipe-pause` platform-convention rows, `secondary-meta` and the toast rows are recorded as kept / already passing.
- `STARS=B` delivered from one source of truth: `Color.ratingStar` in `AppComponents`, backed by a four-entry colorset, at `GalleryCardCell`, `GalleryThumbnailCell`, `GalleryDetailCell`, `DetailView+Subviews` and `RatingView` (+ its three previews). The rendered light card ratio is 3.0102 — the audit's 0.01 margin held, `#A38100` stands.
- The `Color.mix` idiom set for the tree: six factors, each the smallest twentieth clearing its threshold in all four modes, chosen from SwiftUI's own `mix` output (a macOS probe) and confirmed byte-for-byte on the simulator (`#393198`, `#006C74`, `#414A9E`, `#00757D`, `#322A89`, `#004553`, `#66689E`, `#1D7B84`, `#CE701E`, `#CE7525`, `#9E4100`, `#CE8044`), which is what validates the three source-derived rows (Update tint, NewDawn stop, warning glyph).
- The `comment-link` underline the `D28 = ok` slot attributed to 16-22 is now built, and the 16-22 deferred entry is closed.

## Per-id changes

| id | site | change | before → after (L / D / L+IC / D+IC) |
|---|---|---|---|
| `stars-list` | four list/detail star sites | `Color.ratingStar` | 1.51 / 12.05 / 4.59 / 11.69 → **3.69** / 12.05 / 4.59 / 11.69 |
| `stars-card` | `GalleryCardCell` | same colorset | 1.23 / 1.97 / 3.54 / 2.21 → **3.01** / 5.51 / 3.54 / 6.06 (dark on this cover's gradient; caveat stands) |
| `read-glyph` | `HeaderSection.readButton` | `Color.accentColor.contrastingForeground(in: environment)`; `@Environment(\.self)` added | 3.30 / 1.81 / 9.10 / 1.12 → **6.37 / 11.75 / 6.93 / 18.17** |
| `comment-link` | `LinkColoredText` + `CommentsView` `.linkedText` / `.singleLink` | `Color.commentLink` (colorset) + underline | 3.26 / 9.54 / 11.40 / 14.26 → **4.51** / 7.82 / 11.40 / 11.09 |
| `comment-date` | `CommentCell.metadata` | date `.foregroundStyle(.primary)` | 3.13 / 5.29 / 4.74 / 5.85 → **16.73** / 13.94 / 14.78 / 12.06 |
| `offline-notice` | `DetailView.offlineFallbackNotice` | `Label { Text } icon: { Image.foregroundStyle(.orange) }`, text `.primary` | 2.31 / 9.41 / 4.55 / 10.41 → **21.00** ×4 (source-derived) |
| `swipe-pages` | `inspectButton` | `.tint(.indigo.mix(with: .black, by: 0.3))` | 1.68 / 9.12 / 2.21 / 7.56 → **10.16 / 7.78 / 11.49 / 5.20** |
| `swipe-move` | `moveButton` | `.tint(.teal.mix(with: .black, by: 0.35))` | 2.16 / 1.86 / 4.57 / 1.65 → **6.18 / 5.47 / 10.63 / 4.98** |
| `swipe-update` | `updateButton` | `.tint(.orange.mix(with: .black, by: 0.3))` | 2.31 / 2.23 / 4.55 / 2.02 → **5.58 / 5.43 / 9.39 / 4.99** (source-derived) |
| `swipe-delete`, `swipe-pause` | — | kept (platform conventions) | unchanged |
| `secondary-meta` | — | no change (recorded caveat) | unchanged |
| `log-glyph-error` | `AppActivityLogRow` via `Level.glyphColor` | `.error` → `color.mix(with: .black, by: 0.15)` | 2.31 / 9.41 / 4.55 / 10.41 → **3.52** / 6.20 / 6.54 / 6.80 |
| `newdawn` | `NewDawnView.gradientColors` light | `Color(.systemTeal).mix(with: .black, by: 0.25)` top stop | 2.16 / 13.94 / 4.57 / 12.06 → **4.48** / 13.94 / 8.32 / 12.06 (source-derived; no scrim) |
| General tags warning (plan row, deviation) | `GeneralSettingView` | `.yellow.mix(with: .black, by: 0.3)` | 1.51 / 12.05 / 4.59 / 11.69 → **3.86** / 4.66 / 9.42 / 4.51 (source-derived glyph on rendered rows) |
| toast rows 8–10 | `ToastMessageView` | none — byte-identical to the audited `8d462178` | already passing, not redone |

## Colorset values

- `AppComponents/Resources/Colors.xcassets/RatingStar.colorset`: light `#A38100`, dark `#FFD600`, light+HC `#A16A00`, dark+HC `#FEDF43` (dark and HC entries are the bytes `.yellow` rendered in the audit; HC entries are the system's own yellow variants, so Increase Contrast never lowers the star's contrast).
- `DetailFeature/Resources/Colors.xcassets/CommentLink.colorset`: light `#54832A`, dark `#96D35F`, light+HC `#2A4015`, dark+HC `#E1FFC6` (the last three copy the accent's rendered values; doc-commented as a coupling to mirror on any accent change).
- Both modules already declared `resources: [.process(.resources)]` in `AppPackage/Package.swift`; the new `Colors.xcassets` directories were compiled into `AppPackage_AppComponents.bundle` / `AppPackage_DetailFeature.bundle` without a manifest edit (confirmed with `strings … Assets.car`).

## Task Commits

1. **Task 1: D-28 colour fixes** — `0d9945e0` (feat) — nine Swift files + the `CommentLink` colorset
2. **Task 2: Rating star colour per owner decision** — `d778cc08` (feat) — the `RatingStar` colorset, `Color.ratingStar`, five sites + previews
3. **Task 1 follow-up found during Task 3's measurement** — `4d2acc70` (fix) — `CommentsView` parsed link runs coloured and underlined (see Deviations 5)
4. **Task 3: Re-measure and record** — `fcce99d3` (docs) — `### 16-23 result (contrast)`, D-25 rows, deferred-items

**Plan metadata:** the final `docs(16-23)` commit.

## Files Created/Modified

- `AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift` — `@Environment(\.self)`; Read glyph colour from the resolved accent; doc comment.
- `AppPackage/Sources/DetailFeature/Components/LinkedText.swift` — `.commentLink` + `underlineStyle = .single` on detected runs; `Color.commentLink` (internal) with doc comment.
- `AppPackage/Sources/DetailFeature/Comments/CommentsView.swift` — parsed `.linkedText` / `.singleLink` runs draw `Color.commentLink` with `.underline()`.
- `AppPackage/Sources/DetailFeature/DetailView+CommentCells.swift` — date text `.primary`; comment.
- `AppPackage/Sources/DetailFeature/DetailView.swift` — offline notice split into text `.primary` / glyph `.orange`.
- `AppPackage/Sources/DetailFeature/Resources/Colors.xcassets/{Contents.json, CommentLink.colorset/Contents.json}` — new.
- `AppPackage/Sources/DownloadsFeature/DownloadsView.swift` — three mixed tints with the block comment and per-tint measured ratios; Delete block and its Phase 15 comment untouched.
- `AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift` — `Level.glyphColor` beside `symbol`; row uses it.
- `AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift` — warning glyph `.yellow.mix(…, by: 0.3)`.
- `AppPackage/Sources/AppComponents/NewDawnView.swift` — light top stop mixed; doc comment.
- `AppPackage/Sources/AppComponents/RatingView.swift` — `Color.ratingStar`; previews switched.
- `AppPackage/Sources/AppComponents/Resources/Colors.xcassets/{Contents.json, RatingStar.colorset/Contents.json}` — new.
- `GalleryCardCell.swift`, `GalleryThumbnailCell.swift`, `GalleryDetailCell.swift`, `DetailView+Subviews.swift` — `.foregroundStyle(Color.ratingStar)`.
- `.planning/phases/16-dynamic-type-accessibility/16-CONTRAST-AUDIT.md` — `### 16-23 result (contrast)`; D-25 rows and the no-exception note.
- `.planning/phases/16-dynamic-type-accessibility/deferred-items.md` — 16-22 entry closed; `## Found during 16-23`.

## Decisions Made

See `key-decisions` in the frontmatter. In short: `#A38100` stands (3.0102 rendered); swipe factors clear dark+IC too; `comment-link` fixed where it actually renders; the `CommentLink` colorset copies the accent's passing variants; the error glyph's own 0.15 factor.

## Deviations from Plan

No deviation rule 4 case arose. Rule 1 fired once (item 5). The rest are the orchestrator's pre-authorised environment / scope differences, recorded as asked.

1. **Scope = the audit's `D28 = ok` bullet (env fact 1).** Four files outside the plan's `files_modified` were touched for their ids: `DetailView+HeaderSection.swift` (`read-glyph`), `LinkedText.swift` (`comment-link`, incl. the underline that 16-22 deferred — entry closed), `DetailView+CommentCells.swift` (`comment-date`), `NewDawnView.swift` (`newdawn`), plus the new `DetailFeature/Resources/Colors.xcassets`.
2. **General warning glyph (env fact 2).** `.yellow` fails 3:1 in light (1.51 source-derived on the rendered white row), so it was darkened with `mix` by 0.3 (3.86 / 4.66 / 9.42 / 4.51) and recorded as its own audit row. The glyph itself could not be rendered (translations must be enabled and empty); the row backgrounds are rendered (`<mode>-general.png`: `#FFFFFF` / `#1C1C1E` / `#FFFFFF` / `#242426`).
3. **Star sites (env fact 3).** Five sites plus three previews at HEAD (not the plan's line numbers); `AppComponents` needed no manifest edit.
4. **Colorsets for per-scheme values (env fact 4).** `CommentLink` in `DetailFeature` (its `resources:` entry confirmed); no module lacked one, so no checkpoint. `Color.mix` idiom set with a probe rather than guessed.
5. **[Rule 1 — Bug] `comment-link` fixed at the wrong drawing site.** Found during Task 3: after the `d778cc08` install-over the audited link runs still rendered the accent with no underline, because the sampled comment's URLs are parsed `.linkedText` contents drawn by `CommentsView` with `.foregroundStyle(.tint)`, not by `LinkColoredText`. Fix: both parsed-run sites draw `Color.commentLink` with `.underline()`; `commentLink` made internal. Verified: lint build 0 violations, `DetailFeatureTests` 26/6, rebuilt and re-installed `4d2acc70`, all screens re-captured on that build, links 4.51 / 7.82 / 11.40 / 11.09 with underline. Committed in `4d2acc70`.
6. **Plan `<verify>` grep expects `mix(with:` in `DetailView.swift`** — it is 0 there by design: the `D28 = ok` bullet's fix for the offline notice is `.primary` text with `.orange` on the glyph, not a darkened orange. `DownloadsView.swift` prints 3.
7. **Simulator / tooling (env facts 5–6).** iPhone 17e `67377A20…` for the tests, the two install-overs (`d778cc08`, then `4d2acc70`) and the captures; `agent-device open … --device "iPhone 17e"`; `sim-use` by coordinates; swipe revealed on the `4183242` row with `describe-ui` frames, no delete confirmed. NewDawn and the offline notice are login/failure-gated and stay source-derived, as the orchestrator anticipated.
8. **Swipe factors pass dark+IC.** The audit expected dark+IC to remain a platform limit for the re-tinted swipe actions; with `mix` the pastel Increase-Contrast tints darken as well, so the chosen factors clear all four modes and no residual is recorded. The two `kept` rows (Delete, Pause) remain the platform-limit cases, as proposed.
9. **Frontpage content changed between the two install-overs** (the list refreshed), so the star boxes were re-located per capture; the measured cells are two different galleries with identical bytes.
10. **Dark comment cell basis.** The full Comments cell sampled `#2C2C2E` in dark where the audit's row 15 used `#1C1C1E`; the dark link colour is unchanged and passes on both (7.82 / 9.54).

**Total deviations:** 1 auto-fixed (Rule 1); 9 pre-authorised environment / scope differences recorded.
**Impact on plan:** every plan truth met; colour only, no layout; no category colorset changed; no lint suppression; one extra `fix` commit inside the plan.

## Issues Encountered

- The first capture script did not word-split its mode specs under zsh (the modes never switched); fixed with `${=spec}` and the affected captures were deleted and retaken before any measurement.
- A tap on the Detail "Comments" header did not navigate while the scroll was settling; "Show All" did. Back navigation from Comments popped twice with a delay; verified by `describe-ui` before continuing.

## Evidence for the owner (D-33; never committed, D-32)

`$HOME/Library/Caches/ehpanda-phase16/round2/contrast-after/` — 32 files, `<mode>-<screen>.png` with mode ∈ `light-std`, `dark-std`, `light-ic`, `dark-ic` and screen ∈ `home-root` (card stars), `frontpage` (list stars), `detail-top` (Read glyph), `detail-comments` (preview date), `comments-full` (link runs + underline), `swipe-leading` (Pages / Move discs), `general` (row backgrounds for the warning-glyph derivation), `activity-logs` (error glyph). Befores: the 16-13 set under `…/round2/contrast/` with the same screen names (`swipe-leading-move` there corresponds to `swipe-leading` here).

## Known Stubs

None.

## Threat Flags

None — no new network, auth, file-write or schema surface. T-16-05 mitigated (`git diff --quiet -- App/Assets.xcassets/Category` exit 0; `CategoryColorsetInvariantTests` green). T-16-14 mitigated (four ratios per site, rendered / source-derived labelled, kept rows recorded). T-16-01 mitigated (evidence root only; image check 0 before each of the four commits). T-16-03 mitigated (bundle id checked before both install-overs; nothing uninstalled, erased or reset; downloads untouched; baselines restored and read back; simulator shut down).

## User Setup Required

None.

## Next Phase Readiness

- 16-24 (wave 22): the star and link colours are asset-driven; `AccessibilityAuditUITests` can run over the same surfaces with no new exclusion.
- 16-26: D-25 list unchanged (`#32 Activity Logs`, `#36 Laboratory` only). Nutrition Label caveats to carry from this plan: `secondary-meta` (4.00 in light), the system-drawn swipe text labels (3.29 in light, not app-tintable), and the Home card's content-dependent dark gradient behind the stars.
- Owner items in `deferred-items.md § Found during 16-23`: whether the preview-card score follows the date to `.primary`; the `CommentLink` ↔ accent coupling.

---
*Phase: 16-dynamic-type-accessibility*
*Completed: 2026-09-12*

## Self-Check: PASSED

SUMMARY present; both colorsets present; commits `0d9945e0`, `d778cc08`, `4d2acc70`, `fcce99d3` found in history; 0 absolute home paths in the SUMMARY, the audit and `deferred-items.md`; 0 image files in `git status`; simulator restored (light / large / disabled) and Shutdown.
