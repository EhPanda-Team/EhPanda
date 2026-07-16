# Phase 10: UI Polish - Context

**Gathered:** 2026-07-17
**Status:** Ready for planning

<domain>
## Phase Boundary

App-wide UI modernization and refinement, held to strict **appearance/layout parity**
(the milestone forbids any visual redesign — see REQUIREMENTS.md "Out of Scope").
This phase bundles **11 distinct sub-tasks** across three formal requirements plus eight
owner-added success criteria. The authoritative scope is the **12 success criteria in
ROADMAP.md §"Phase 10: UI Polish"** — REQUIREMENTS.md lists only POLISH-01/02/03 and is
NOT the full picture.

The 11 sub-tasks:

1. **POLISH-01** — `monospacedDigit()` + `.contentTransition(.numericText())` on number-bearing text.
2. **POLISH-02** — reduce `ZStack` in favor of `.overlay`/`.background` where a child overlays/underlays primary content (35 `ZStack` sites to audit).
3. **POLISH-03** — migrate all 42 `PreviewProvider` structs to the `#Preview` macro and enrich them (only 1 `#Preview` exists today).
4. **Comprehensive Dynamic Type** (criterion 5) — every user-facing screen readable & operable through the full DT range incl. accessibility sizes.
5. **Remove `\.inSheet`** (criterion 6) — reimplement presentation-context logic via a native/non-custom-environment mechanism (12 refs; key defined in `AppTools/EnvironmentKeys.swift`).
6. **Deprecated SwiftUI API sweep** (criterion 7) — e.g. `foregroundColor`→`foregroundStyle` (43 sites), no new lint/compiler deprecation warnings.
7. **Remove custom `cornerRadius(_:corners:)`** (criterion 8) — replace with `.clipShape(.rect(cornerRadii:))` (`AppComponents/ViewModifiers.swift`).
8. **Empty-string-literal audit** (criterion 9) — `Text("")`/`Label("", …)` → meaningful string or hidden label.
9. **`Label` conversion** (criterion 10) — text+image button labels → `Label` (all buttons); toolbar buttons also text-only/image-only.
10. **Rename `SystemNotificationExt` → `SystemNotification`** (criterion 11) — full impl, not a thin extension (module at `AppPackage/Sources/SystemNotificationExt`, 10 refs).
11. **Migrate `PreviewProvider`** — same as POLISH-03 (criterion 12 is the detailed statement of POLISH-03).

**Owner decision (this discussion):** comprehensive Dynamic Type stays IN Phase 10 rather
than splitting out, so Phase 10 is a large phase mixing a whole-app DT audit with mechanical
polish sweeps.

</domain>

<decisions>
## Implementation Decisions

### Dynamic Type (criterion 5) — the phase's heaviest sub-task
- **D-01:** Full whole-app audit-and-fix, **kept in Phase 10** (not split into its own phase). Every user-facing screen — including sheets — must be readable and operable across the DT range up to the max accessibility size.
- **D-02:** Remediation stance = **reflow, never cap.** Text always grows to the user's chosen size everywhere; layouts adapt (ViewThatFits, wrapping, ScrollView, drop fixed heights / `lineLimit(1)`). **No `dynamicTypeSize(…maxSize)` caps anywhere in the app** — not even on non-essential/compact chrome. This is an absolute; the "cap as last resort" alternative was explicitly rejected.
- **D-03:** Verification = the **`sim-use` skill** driving the iOS Simulator, sampling **XXL + AX3 + AX5**, across **every user-facing screen including sheets**. (Owner-signed visual gate, in the spirit of the Phase 5 rotation/Live-Text gates; static/unit checks cannot prove readable-and-operable.)

### Numeric Text (POLISH-01)
- **D-04:** `monospacedDigit()` and `.contentTransition(.numericText())` are applied **as a pair, and only to values that visibly change on screen.** Static one-off numbers get **neither** — this is the phase's concrete reading of POLISH-01's "where it makes sense." (Note for the verifier: static numbers left untreated are correct, not a coverage gap.)
- **D-05:** The "changing value" set = **live values** (reader current-page indicator on swipe; download progress %/size) **+ user-driven changes** (favorite/comment counts on refresh, rating when tapped, cache size after clearing). Apply best-judgment to any other value that visibly changes.
- **D-06:** No layout jitter on change (POLISH-01 acceptance) — the paired `monospacedDigit()` is what guarantees this for the animated values.

### Preview Enrichment (POLISH-03 / criterion 12)
- **D-07:** Migrate **all 42** `PreviewProvider` structs to `#Preview`; **no `PreviewProvider` may remain** in the codebase.
- **D-08:** Enrichment is **pragmatic by view.** Stateful views (list cells, detail rows, cards, loading/error views) get the full realistic-state matrix — empty / loading / loaded / error + boundary values (min/max rating, counts, page numbers, long vs. short text) — as named `#Preview("…")` cases using modern features (`@Previewable`, preview traits like `.sizeThatFitsLayout`). Trivial leaf views get one clean `#Preview`.
- **D-09:** **Do NOT standardize Dynamic Type or color-scheme preview variants, and do NOT pin a fixed size or scheme.** Previews stay at the default environment and cover realistic **content states** only. DT/appearance is proven by the D-03 `sim-use` pass, not by preview variants. (This narrows criterion 12's "environment/DT/color-scheme variants where useful" to: not a blanket rule.)

### Parity Verification (mechanical sweeps: ZStack, cornerRadius, foregroundStyle, Label, empty-string, inSheet, rename)
- **D-10:** All conversions build clean with **zero new SwiftLint/compiler warnings.**
- **D-11:** **Risk-tiered `sim-use` visual spot-check** — before/after visual check on the **layout-affecting** swaps (`ZStack`→overlay/background, `cornerRadius`→`clipShape`, `Label` conversions), since these can shift sizing (overlay/background is sized to primary content; ZStack is union-sized). **Diff-review is sufficient** for pure-appearance swaps (`foregroundColor`→`foregroundStyle` on `Color`). One tool (`sim-use`) serves both DT (D-03) and parity.
- **D-12:** Per-plan clean-build gate + strictly sequential `xcodebuild` (no overlapping invocations on this machine) carries forward from prior phases.

### Claude's Discretion (mechanical items — rules already fixed by the criteria; not discussed)
These execute to their stated criterion rule; the planner/researcher owns the "how":
- `SystemNotificationExt` → `SystemNotification` rename (criterion 11) — module + every import/reference; keep its `.swiftlint.yml` `parent_config` wiring under the new name.
- `cornerRadius(_:corners:)` → `.clipShape(.rect(cornerRadii:))` at appearance parity, then remove the custom modifier + its `RoundedCorner` shape (criterion 8).
- Deprecated-API sweep incl. `foregroundColor`→`foregroundStyle` (criterion 7).
- Empty-string audit: meaningful string or hidden label (criterion 9).
- `Label` conversion where fitting; toolbar buttons also cover text-only/image-only (criterion 10).
- `\.inSheet` removal (criterion 6) — pick the native/non-custom-environment replacement for the presentation-context logic it drives; surface the chosen mechanism in the plan.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Authoritative scope (read first)
- `.planning/ROADMAP.md` §"Phase 10: UI Polish" — the **12 success criteria** are the authoritative scope. This is broader than REQUIREMENTS.md; do not scope from POLISH-01/02/03 alone.
- `.planning/REQUIREMENTS.md` §POLISH (POLISH-01/02/03) + "Out of Scope" (the "Any visual redesign" parity constraint).

### Project rules that constrain this phase
- `CLAUDE.md` (repo root, a.k.a. AGENTS.md) — SwiftLint-read-first rule + banned-API/custom-regex rules; **labeled localized-format arguments** and **non-translated-keys-need-every-locale** (the empty-string + `Label` audits touch localized string catalogs); **SwiftLint-coverage-for-new-modules** (`parent_config` must survive the `SystemNotification` rename); **confirmation-dialog/alert placement** (relevant if any `Label`/toolbar edits touch dialog anchors); no-suppression-of-lint rule.
- `.swiftlint.yml` (repo root) — the ruleset to conform to from the start. Phase 11 ratchets these to error, so Phase 10 must add **zero** new violations (esp. `lifecycle_modifiers`, `single_line_trailing_closure`, and the deprecated-API sweep).
- `.planning/codebase/CONVENTIONS.md` — established SwiftUI/TCA conventions.

### Key source landmarks
- `AppPackage/Sources/AppComponents/ViewModifiers.swift` — the custom `cornerRadius(_:corners:)` modifier (+ `RoundedCorner` shape) to remove (criterion 8); also `AppPackage/Sources/AppTools/Extensions.swift`.
- `AppPackage/Sources/AppTools/EnvironmentKeys.swift` — `\.inSheet` `EnvironmentKey` definition (criterion 6); consumers include `AppFeature/…/TabBarView.swift`, `HomeFeature/{Popular,Watched,Frontpage}View.swift`, `SearchFeature/SearchRootView.swift`, `AppComponents/Placeholder.swift`, `DetailFeature/DetailView+Subviews.swift`.
- `AppPackage/Sources/SystemNotificationExt/` — module to rename to `SystemNotification` (criterion 11).
- Existing numeric-text patterns to copy (POLISH-01): `ReadingFeature/Support/ControlPanel.swift`, `GalleryListComponents/DownloadBadgeLabel.swift`, `DownloadsFeature/DownloadsView+Subviews.swift`, `DetailFeature/Archives/ArchivesView.swift`, `SettingFeature/Components/DownloadSettingView.swift`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`sim-use` skill** — the single verification mechanism for both the Dynamic Type audit (D-03) and the risk-tiered parity spot-check (D-11). No snapshot-testing infra is being introduced.
- **Existing `monospacedDigit`/`numericText` sites (6/2)** — a working baseline pattern to copy for POLISH-01 rather than inventing one.
- **Modern SwiftUI / accessibility skills available** — `pfw-modern-swiftui`, `swiftui-pro`, `swift-accessibility-skill`, `swiftui-performance-audit` should inform the DT reflow work and the deprecated-API sweep.

### Established Patterns
- **Adaptive layout already landed (Phase 5):** size classes, `onGeometryChange`/`containerRelativeFrame`, `ViewThatFits`, no `GeometryReader`. The DT reflow work builds on these settled surfaces — reuse the same primitives; do not reintroduce `GeometryReader`.
- **Accessibility labels already handled (Phases 5 & 7):** VoiceOver labels + decorative-icon handling exist. **Dynamic Type is the one remaining a11y axis** not yet actively worked — this phase is the first pass at it.
- **Parity discipline:** every prior phase held behavior/appearance parity; the mechanical swaps here are mechanism changes, not re-skins.

### Integration Points
- **Sequential `xcodebuild` only** (no overlapping invocations on this machine) — plans must serialize build/test waves.
- **Phase 11 lint ratchet is downstream** — Phase 10 must not add new lint/deprecation debt; the deprecated-API sweep (criterion 7) is partly a down-payment on LINT-01.
- **`SystemNotification` rename** touches every importer + the module's own `.swiftlint.yml` `parent_config`.

</code_context>

<specifics>
## Specific Ideas

- **Dynamic Type is absolute:** "never cap" means literally no `dynamicTypeSize(…maxSize)` anywhere — the owner rejected even last-resort caps on compact chrome. Every breakage is fixed by reflow.
- **Numeric text is deliberately narrow:** treat only values that visibly change; `monospacedDigit` and `numericText` always travel together. A static number left untouched is the intended outcome.
- **Previews stay minimal on environment:** enrich content states, not size/scheme variants — the owner explicitly did not want a fixed size/scheme or standardized DT/dark variants baked into previews.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. Splitting comprehensive Dynamic Type into its own phase was considered and explicitly rejected (D-01: kept in Phase 10).

</deferred>

---

*Phase: 10-ui-polish*
*Context gathered: 2026-07-17*
