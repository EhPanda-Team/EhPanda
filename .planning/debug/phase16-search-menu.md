---
status: resolved
trigger: "搜尋欄空白和勾選消失這兩個問題要幫我調查一下"
created: 2026-09-08
updated: 2026-09-08
---

## Symptoms

- Expected: search prompt and selected Auto-Play policy remain visually identifiable at accessibility sizes.
- Actual: iPhone Toplists search capsule becomes blank at AX5; iPad Auto-Play menu loses its manual checkmark at AX5 but shows it at Large.
- Errors: none observed.
- Timeline: reproduced on iOS 26.5 during the Phase 16 targeted recheck; onset not established.
- Reproduction: see `.planning/phases/16-dynamic-type-accessibility/16-TARGETED-RECHECK.md`.
- Scope: diagnose causes and verify possible remedies; do not change production code. Owner accepted error-toast truncation separately.

## Current Focus

hypothesis: confirmed — iOS 26.5 automatic navigation-bar drawer layout reaches an undersized blank AX5 field, while always-visible drawer layout produces the full native field; manually supplied menu checkmarks are discarded at AX5 while native Picker selection survives
next_action: search accepted as Apple defect with no app fix; title accepted as-is; Auto-Play implementation history under owner discussion

## Evidence

- timestamp: 2026-09-08T22:24:05+0900
  checked: `AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift:255-265`
  found: Auto-Play is a `Menu` of `Button` rows whose labels manually append `Image(systemSymbol: .checkmark)` when the row matches `autoPlayPolicy`; the selection value remains intact when only that image disappears.
  implication: The AX5 symptom is a rendering loss of the app-supplied menu accessory, not lost Auto-Play state.
- timestamp: 2026-09-08T22:24:05+0900
  checked: `AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift:77-129` and the targeted recheck
  found: The Runs menu replaced the same hand-built checkmark pattern with `Picker(selection:)` using `.pickerStyle(.inline)`, and the targeted recheck confirms its selected tick remains visible at AX3 and AX5.
  implication: A native `Picker` is the established in-project remedy for Auto-Play; it gives selection state to the menu system instead of encoding it as a label image.
- timestamp: 2026-09-08T22:24:05+0900
  checked: `AppPackage/Sources/HomeFeature/Toplists/ToplistsView.swift:20-38`, peer searchable screens, and repository-wide search customization search
  found: Toplists uses the standard `.searchable(text:placement:prompt:)` with `.navigationBarDrawer`, as do working peers. No `UISearchBar`, `UITextField`, UIAppearance, fixed search font, or custom search-field styling exists in app source. Toplists chiefly differs through its longer dynamic title and its toolbar controls.
  implication: There is no app-drawn prompt or magnifier to repair; the blank capsule is produced inside the native navigation-bar search presentation. A screen-specific surrounding layout trigger remains possible.
- timestamp: 2026-09-08T22:24:05+0900
  checked: `AppPackage/Sources/AppComponents/NavigationTitleDisplayMode.swift:21-32`, current AX5 capture, and `.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md`
  found: Accessibility sizes already force `.inline`, and the reproduced Toplists capture visibly has an inline title while the search capsule is blank. The earlier sweep inferred that the inline-title change restored the search content, but the symptom has recurred with that condition present.
  implication: Inline title mode alone is not a sufficient fix and is not a currently proven root cause. Title length, toolbar competition, navigation transition state, or an iOS 26.5 native-control defect still need isolation.
- timestamp: 2026-09-08T22:24:05+0900
  checked: current cold-entry and pull-to-reveal captures in the external Phase 16 review evidence
  found: The cold EhPanda AX5 entry showed no drawer after one pull. It did not expose a blank field.
  implication: Cold behavior with the original automatic drawer is inconclusive; it must not be cited as proof of a cold blank-content defect.
- timestamp: 2026-09-08T22:27:31+0900
  checked: standalone native SwiftUI probe on iPhone 17e / iOS 26.5, `probe-search-ax5.png`
  found: A plain `NavigationStack` and `List` with ordinary `.searchable(... placement: .navigationBarDrawer, prompt: "Filter")` and no TCA, app toolbar, appearance customization, or application content reproduces the blank capsule after the search drawer is revealed at Large and Dynamic Type changes to AX5. The AX5 view is inline and its ordinary list content remains visible.
  implication: Toplists title length, toolbar width, `GalleryList`, TCA binding, and application appearance are not necessary causes. The defect is in the iOS 26.5 native navigation-bar search presentation or its response to the live size transition.
- timestamp: 2026-09-08T22:27:31+0900
  checked: standalone native SwiftUI menu probes on iPhone 17e / iOS 26.5, `probe-manual-menu-ax5.png` and `probe-picker-menu-ax5.png`
  found: At AX5, a plain `Menu` whose selected `Button` label contains `Text` plus `Image(systemName: "checkmark")` loses the visible tick, while a native inline `Picker(selection:)` in the same standalone app visibly marks Off.
  implication: The Auto-Play diagnosis and Picker remedy are experimentally confirmed independently of EhPanda. This is an iOS 26.5 native menu treatment of a manually supplied label image, while native picker selection state uses a rendering path that survives AX5.
- timestamp: 2026-09-08T22:31:21+0900
  checked: standalone fixed-inline, short-title probe with `.navigationBarDrawer(displayMode: .always)` on iPhone 17e / iOS 26.5, `probe-search-cold-fixed-inline-ax5.png` and `probe-search-fixed-inline-transition-ax5.png`
  found: Both cold AX5 and Large-to-AX5 render the magnifier and Filter prompt in a 124-point-high field.
  implication: iOS 26.5 can render the full native search contents at AX5, and the supported always-visible drawer placement avoids the failing path.
- timestamp: 2026-09-08T22:31:21+0900
  checked: standalone original long title and original dynamic automatic/inline title mode, changing only the search placement to `.navigationBarDrawer(displayMode: .always)`, `probe-search-always-transition-ax5.png`
  found: The Large state visibly used its expanded large title; after transition to AX5, the search field remained 124 points high with its magnifier and Filter prompt. The baseline automatic drawer produced a blank 96-point field after the same transition, versus 44 points at Large.
  implication: Fixed-inline mode and a short title are not required for success. The isolated variable is automatic versus always-visible navigation-bar drawer display mode. The measured 96-versus-124-point result supports an automatic-drawer geometry or layout-update failure, but does not reveal Apple's private implementation mechanism.
- timestamp: 2026-09-08T22:31:21+0900
  checked: focused standalone search at AX5, `probe-search-focused-ax5.png`
  found: Typed text is visibly rendered while the search control is focused.
  implication: The binding and text rendering capability remain functional; the observed failure concerns the automatic drawer's unfocused AX5 presentation.

## Eliminated

- Application search-field appearance customization: none exists in the searched Swift source.
- Missing localization value for `Filter`: working peers use the same `.filter` prompt, including Frontpage at AX5.
- Large-title mode as the sufficient search cause: the current reproduced entry is already inline.
- Lost Auto-Play selection state: the selected value and accessibility-reported checkmark survive while only the visible accessory disappears.
- Toplists title length, toolbar controls, `GalleryList`, TCA, and app appearance as necessary search causes: the standalone native probe reproduces without them.
- EhPanda-specific menu styling or state management as the Auto-Play cause: the standalone manual menu reproduces and the native picker succeeds.

## Resolution

root_cause: "Auto-Play: iOS 26.5 drops a manually supplied checkmark Image from a Menu Button label at accessibility sizes; native Picker selection rendering survives. Toplists search: the native automatic navigation-bar drawer reaches a blank, undersized 96-point AX5 presentation after the Large-to-AX5 transition, while the always-visible drawer produces the complete 124-point field; the private framework mechanism is not established."
fix: "Not applied. Verified candidates in the standalone probe are a Picker bound to autoPlayPolicy and `.navigationBarDrawer(displayMode: .always)`; both still require production integration and EhPanda verification if approved."
verification: "Reproduced both failures in EhPanda and standalone SwiftUI on iPhone 17e / iOS 26.5; manual-menu versus Picker and automatic-drawer versus always-visible drawer controlled comparisons passed. Focused search text remained visible."
files_changed: ".planning/debug/phase16-search-menu.md only"

## Owner disposition — 2026-09-08

Search is accepted as an Apple defect and explicitly will not be fixed in the app. The always-visible drawer experiment is not an implementation task. Initial inline title presentation is also accepted; preserve the existing fallback. Auto-Play has no new fix authorization from this disposition.
