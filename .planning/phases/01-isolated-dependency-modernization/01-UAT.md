---
status: complete
phase: 01-isolated-dependency-modernization
source: [01-VERIFICATION.md]
started: 2026-07-10T13:30:00Z
updated: 2026-07-11T01:45:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Colorful animated gradient visual parity (D-19)
expected: On Home, focus a gallery card in dark and light mode; confirm the soft blurred multicolor animated `ColorfulView` gradient and the gray fallback render as before the phase (Colorful 1.1.1 vs the prior pin), per `01-COLORFUL-UAT.md`. Animated-gradient concept and fallback colors match the pre-phase behavior closely enough; no visual regression.
result: pass
note: |
  Initially FAILED (regression G-01-1) — the mechanical Colorful→ColorfulX API swap did not
  mirror behavior: all cards + light mode painted a full opaque gradient. Fixed inline during
  UAT (gate ColorfulView on `animated`; skip light-mode color calc; seed a neutral color so the
  gradient blooms via ColorfulX's transitionSpeed instead of popping). User verified dark focus,
  side-card suppression, light-mode absence, dark↔light toggle, and the bloom (transitionSpeed 6).
resolved_by: inline fix in GalleryCardCell.swift (see Gaps G-01-1)

### 2. Real-world domain-fronting / SNI behavior (D-15) — informational
expected: Informational only for this phase — the tree retains `DeprecatedAPI` via the approved `document-skip` decision, so domain-fronting behavior is unchanged and no new China/SNI verification is owed. This item becomes a required UAT only if a non-deprecated DF replacement is ever adopted (a future phase), at which point an in-region tester under China/SNI-filtering conditions must confirm gallery/image loading still works. Mark as skipped / N-A for Phase 1.
result: skipped
reason: "N/A for Phase 1 — DeprecatedAPI retained via the approved document-skip decision, so domain-fronting/SNI behavior is unchanged; no new China/SNI verification is owed. Becomes a required UAT only if a non-deprecated DF replacement is adopted in a future phase."

## Summary

total: 2
passed: 1
issues: 0
pending: 0
skipped: 1
blocked: 0

## Gaps

- gap_id: G-01-1
  status: resolved
  resolved_by: "Inline fix in AppPackage/Sources/HomeFeature/GalleryCardCell.swift — (1) gate ColorfulView on `animated` so only the focused dark-mode card paints; (2) defer analyzeImageColors to dark mode via view-layer gate + re-trigger on light→dark; (3) new CardGradientView seeds a neutral color and applies the real palette on appear so ColorfulX lerps (transitionSpeed 6) into a gradual bloom instead of snapping."
  resolved_at: 2026-07-11
  verified_by: "User UAT (live sim): dark focus animates, side cards suppressed, light mode shows no gradient, dark↔light toggle recomputes colors, bloom accepted."
  truth: "Home card-slide gradient (Colorful → ColorfulX migration) must reproduce the pre-migration behavior: only the focused card in dark mode shows the (animated) gradient in its own cover colors; unselected cards and light mode show only the gray fallback."
  prior_status: failed
  reason: "User reported: wrong behavior — all cards now render the selected card's color at full opacity; unselected cards show a static ColorfulX gradient instead of nothing; ColorfulX renders in light mode too. Migration was a mechanical API swap, not a behavior-faithful port."
  severity: major
  test: 1
  root_cause: "Colorful and ColorfulX have different rendering models. Old Colorful (Lakr233/Colorful 1.1.1) drew 32 translucent (opacity 0.5) blurred circles laid out only when `animated == true` (the non-animated code path never re-randomizes against the real view size, so unselected/light-mode cards rendered a degenerate, near-invisible wash). ColorfulX is a full-bleed OPAQUE Metal gradient that always renders; `speed: 0` freezes motion but still paints the full gradient. The port mapped Colorful's `animated` flag onto ColorfulX's `speed` binding (`speed: animated ? animationSpeed : 0`) but left `ColorfulView` unconditionally in the ZStack, so every card and light mode now paint a full gradient. The `colors` binding was always the shared selected-card colors (`store.cardColors`) in both versions; it only looked per-card before because non-focused cards didn't really render."
  artifacts:
    - path: "AppPackage/Sources/HomeFeature/GalleryCardCell.swift"
      issue: "ColorfulView is rendered unconditionally; `animated` only drives `speed`, not whether the view is present. Commit d0364c14 did a 1:1 API substitution without gating render on `animated`."
  missing:
    - "Gate ColorfulView so it is present ONLY when `animated` is true (focused card AND dark mode); otherwise render just Color.gray.opacity(0.2) — reproduces Colorful's effective behavior and satisfies all three reported points."
    - "(Optional / separate) skip analyzeImageColors work in light mode — pre-existing always-on behavior, NOT a migration regression; confirm with user before changing."
