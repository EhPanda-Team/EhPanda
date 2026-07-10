---
phase: 01-isolated-dependency-modernization
verified: 2026-07-10T13:25:00Z
status: human_needed
score: 4/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
behavior_unverified_items: []
human_verification:
  - test: "Colorful animated gradient visual parity (D-19). On Home, focus a gallery card in dark and light mode; confirm the soft blurred multicolor animated ColorfulView gradient and the gray fallback render as before the phase (Colorful 1.1.1 vs the prior pin), per 01-COLORFUL-UAT.md."
    expected: "Animated-gradient concept and fallback colors match the pre-phase behavior closely enough; no visual regression from the Colorful update."
    why_human: "Animated gradient appearance is subjective/visual and has no stable automated UI test (D-18/D-19); build succeeds but visual match must be judged by a person."
  - test: "Real-world domain-fronting / SNI behavior (D-15). Only relevant if DEP-06 were revisited — the current tree retains DeprecatedAPI by the approved document-skip decision. If a non-deprecated replacement is ever adopted, have a tester under China/SNI-filtering conditions confirm gallery/image loading still works."
    expected: "Domain-fronting requests still reach the server and load content under SNI-filtering conditions."
    why_human: "China/SNI filtering conditions cannot be reproduced locally; requires an in-region tester. Informational for this phase since DeprecatedAPI is deliberately retained."
---

# Phase 01: Isolated Dependency Modernization Verification Report

**Phase Goal:** Shrink and modernize the isolated third-party surface — the swaps that don't couple to other work — with behavior parity.
**Verified:** 2026-07-10T13:25:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth (Success Criterion) | Status | Evidence |
| --- | --- | --- | --- |
| 1 | SC1 — `ChineseConverter` (Simp/Trad) produces identical output on the forked, modernized SwiftyOpenCC; builds clean on the pinned toolchain | ✓ VERIFIED | Local `SwiftyOpenCC` + internal C++ `copencc` targets exist; `ChineseConverterParityTests` (5) and app-level `FileClientTests` (8) **passed** on the current tree (xcodebuild TEST SUCCEEDED). External SwiftyOpenCC/OpenCC packages absent from `Package.swift`. `DictionaryStore` uses `Synchronization.Mutex` (no `NSLock`/`@unchecked`/`@preconcurrency`). |
| 2 | SC2 — dominant-color extraction (`getColors` → primary/secondary/detail/background) unchanged on forked, modernized UIImageColors | ✓ VERIFIED | Local `UIImageColors` module (`UIImage+Colors.swift` exposes `getColors(quality:)`); `UIImageColorsParityTests` (2) **passed**. `LibraryClient.analyzeImageColors` calls `image.getColors(quality: .lowest)` — boundary preserved. External jathu/UIImageColors package removed. |
| 3 | SC3 — `MarkdownUtil.parseTexts/parseLinks/parseImages` yields identical `TagTranslation` output; DetailView markdown preserved; SwiftCommonMark removed | ✓ VERIFIED | `MarkdownExt.MarkdownUtil` (swift-markdown backed, `import Markdown`) exposes all three parse funcs; `MarkdownUtilParityTests` (11) + `TagTranslationMarkdownTests` (6) **passed**. `TagTranslation+Markdown` imports `MarkdownExt`. DetailFeature has no direct parser import (D-08). SwiftCommonMark/CommonMarkExt removed from manifest & sources; `swift-markdown 0.8.0` from apple/swift-markdown pinned in Package.resolved. |
| 4 | DEP-06 (SC4 consciously superseded → document-skip): DF networking behavior UNCHANGED and retention documented with evidence | ✓ VERIFIED | `01-DEP06-EVIDENCE.md` records the Task-2 human `document-skip` decision + spike proving no warning-free API preserves reserved-`Host`/SNI semantics. `DFRequestSemanticsTests` (part of the passing NetworkingFeature run) **passed**. `DFExtensions.swift` retains `DeprecatedAPI.getCFReadStream` with an explicit DEP-06/D-12 comment. Correct target per critical context — not reported as a gap. |
| 5 | SC5 — `GalleryCardCell` animated gradient renders as before on latest Colorful, version pin updated | ✓ pin+wiring VERIFIED / ⚠️ visual parity → human | Colorful pinned `exact "1.1.1"` (Lakr233) in Package.swift + Package.resolved (rev d673ab1). `GalleryCardCell` imports Colorful and renders `ColorfulView(...)` with `ColorfulView.defaultColorList`. Subjective visual parity is a documented user UAT (D-19, 01-COLORFUL-UAT.md) — routed to human verification. |

**Score:** 4/5 truths fully verified; SC5 present + wired (pin updated, gradient rendered) with visual parity pending the D-19 user UAT.

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `AppPackage/Sources/SwiftyOpenCC/*` | Local converter module | ✓ VERIFIED | ChineseConverter/DictionaryStore/Loader/etc. present; parent-linked `.swiftlint.yml`; `Dictionary/` `.ocd2` resources; Mutex-guarded cache |
| `AppPackage/Sources/copencc/*` | Internal C++ OpenCC engine | ✓ VERIFIED | source.cpp/src/deps + module map; excluded from products (`name != cOpenCC`), cxx14 |
| `AppPackage/Sources/UIImageColors/*` | Local color module | ✓ VERIFIED | `UIImage+Colors.swift` + `UIImageColors.swift`; parent-linked lint |
| `AppPackage/Sources/MarkdownExt/MarkdownUtil.swift` | swift-markdown helper | ✓ VERIFIED | Sole owner of `Markdown` product; three parse funcs |
| `AppPackage/Sources/FileClient/TagTranslation+ChtConverted.swift` | Ext moved off OpenCCExt | ✓ VERIFIED | OpenCCExt module removed; ext relocated into FileClient |
| `01-DEP06-EVIDENCE.md` | DEP-06 evidence + decision | ✓ VERIFIED | Status Resolved / document-skip; S1–S6 semantics + spike verdict |
| Colorful pin + Package.resolved | exact 1.1.1 | ✓ VERIFIED | Package.swift `exact "1.1.1"`; resolved rev d673ab1 |
| Removed: OpenCCExt, CommonMarkExt, SwiftCommonMark, external SwiftyOpenCC/UIImageColors | Absent | ✓ VERIFIED | Source dirs gone; no manifest references (only historical comments) |

### Key Link Verification

| From | To | Via | Status |
| --- | --- | --- | --- |
| FileClient.decodeTranslations | SwiftyOpenCC.ChineseConverter | `import SwiftyOpenCC` + convert() | ✓ WIRED |
| copencc C API | SwiftyOpenCC | `.module(.cOpenCC)` dep + module map | ✓ WIRED |
| UIImage.getColors | LibraryClient.analyzeImageColors → GalleryCardCell | `getColors(quality: .lowest)` | ✓ WIRED |
| MarkdownExt.MarkdownUtil | TagTranslationFeature | `import MarkdownExt` computed props | ✓ WIRED |
| Colorful pin | GalleryCardCell gradient | `import Colorful` / `ColorfulView` | ✓ WIRED |
| DFRequest rewrite | DeprecatedAPI.getCFReadStream | `import DeprecatedAPI` (retained) | ✓ WIRED |

### Behavioral Spot-Checks (executed on current tree, single simulator target)

| Behavior | Command (targeted) | Result | Status |
| --- | --- | --- | --- |
| Simp/Trad converter parity | `-only-testing:SwiftyOpenCCTests` | ChineseConverterParityTests 5/5 | ✓ PASS |
| App-level tag conversion parity | `-only-testing:FileClientTests` | 8/8 | ✓ PASS |
| Dominant-color parity | `-only-testing:UIImageColorsTests` | 2/2 | ✓ PASS |
| Markdown parse parity | `-only-testing:MarkdownExtTests` | MarkdownUtilParityTests 11/11 | ✓ PASS |
| TagTranslation markdown output | `-only-testing:TagTranslationFeatureTests` | 6/6 | ✓ PASS |
| DF request semantics (DEP-06) | `-only-testing:NetworkingFeatureTests` | DFRequestSemanticsTests + Galleries 14/14 | ✓ PASS |

Two targeted `xcodebuild ... test` invocations were run (one at a time, allowed to finish), both `** TEST SUCCEEDED **`.

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| DEP-01 | 01-01, 01-03 | Fork + modernize SwiftyOpenCC | ✓ SATISFIED | Local module + copencc engine; parity tests pass; external pkg removed |
| DEP-02 | 01-01, 01-04 | Fork + modernize UIImageColors | ✓ SATISFIED | Local module; parity tests pass; external pkg removed |
| DEP-03 | 01-02, 01-05 | Migrate to swift-markdown | ✓ SATISFIED | MarkdownExt; parity tests pass; SwiftCommonMark removed |
| DEP-06 | 01-02, 01-06 | Investigate inlining DeprecatedAPI | ✓ SATISFIED | Evidence spike + document-skip decision; DF semantics tests pass; retention documented |
| DEP-07 | 01-07 | Migrate to latest Colorful | ✓ SATISFIED (visual UAT owed) | Pin exact 1.1.1; ColorfulView wired; D-19 visual check pending |

All five phase requirement IDs are declared in plan frontmatter and marked Complete in REQUIREMENTS.md. No orphaned requirements.

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
| --- | --- | --- | --- |
| `GalleryCardCell.swift:45,72` | Upstream-deprecated `ColorfulView` (2 warnings) | ℹ️ Info | Documented/accepted in deferred-items.md + 01-COLORFUL-UAT.md; upstream-sourced, not suppressed; build succeeds. Not a phase-goal blocker. |
| copencc `source.cpp` (C++ engine) | 01-REVIEW.md advisory cluster (concurrency/leak/crash-hardening), test-coverage gap | ⚠️ Warning | Advisory quality findings from standard review (0 critical, 5 warning, 3 info); not phase-goal blockers per critical context. |

No debt markers (TBD/FIXME/XXX) in phase-modified Swift sources. No stubs — all parity paths wired to real engines/parsers.

### Deferred Items (tracked, not gaps)

| Item | Tracked In | Note |
| --- | --- | --- |
| Acknowledgements still credit SwiftCommonMark, not swift-markdown | deferred-items.md | AboutView localized strings; no build/functional impact; future acknowledgements pass |
| ColorfulView deprecation (no in-package replacement) | deferred-items.md / 01-COLORFUL-UAT.md | Follow-up: ColorfulX/app-owned gradient/accept — out of scope for this phase |
| Pre-existing unrelated warning in DownloadsFeatureTests | deferred-items.md | Not caused by this phase |

### Human Verification Required

1. **Colorful animated gradient visual parity (D-19)** — Focus a Home gallery card in dark and light mode; confirm the animated multicolor ColorfulView gradient + gray fallback render as before the Colorful 1.1.1 update. Expected: visual parity with pre-phase behavior. Why human: subjective/visual, no stable automated UI test.
2. **Real-world domain-fronting / SNI (D-15)** — Informational; only relevant if DEP-06 is revisited (DeprecatedAPI is deliberately retained). Expected: content loads under China/SNI-filtering conditions. Why human: cannot be reproduced locally.

### Gaps Summary

No gaps. Every automatable phase-goal truth is verified against the actual codebase, not just SUMMARY claims: the three isolated dependency swaps (SwiftyOpenCC, UIImageColors, swift-markdown) are behavior-parity-locked by tests that **pass on the current tree**; SwiftCommonMark and the external SwiftyOpenCC/UIImageColors/OpenCCExt/CommonMarkExt modules are gone from the manifest and sources; Colorful is pinned to exact 1.1.1 and wired into GalleryCardCell; and DEP-06's deliberate `document-skip` retention of DeprecatedAPI is properly evidenced with the DF semantics tests green. The phase is functionally complete; status is `human_needed` solely because two non-automatable UATs (Colorful visual parity, and the informational China/SNI check) are legitimately owed.

---

_Verified: 2026-07-10T13:25:00Z_
_Verifier: Claude (gsd-verifier)_
