---
phase: 01-isolated-dependency-modernization
verified: 2026-07-11T03:05:00Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
behavior_unverified_items: []
re_verification:
  previous_status: human_needed
  previous_score: 4/5
  gaps_closed:
    - "SC5 — Colorful animated-gradient visual parity (D-19): user-verified PASS live on simulator after the G-01-1 fix (01-UAT.md test 1, 01-COLORFUL-UAT.md)."
    - "DEP-06 — the external DeprecatedAPI package was inlined into a local warning-suppressed LegacyCFReadStream module (SC4 'inlined warning-free' now literally met, superseding the prior document-skip retention)."
  gaps_remaining: []
  regressions: []
---

# Phase 01: Isolated Dependency Modernization Verification Report

**Phase Goal:** Shrink and modernize the isolated third-party surface — the swaps that don't couple to other work — with behavior parity.
**Verified:** 2026-07-11T03:05:00Z
**Status:** passed
**Re-verification:** Yes — the prior 2026-07-10T13:25 report described an intermediate tree (external DeprecatedAPI retained via document-skip; Colorful 1.1.1 pin; local SwiftyOpenCC/copencc/UIImageColors modules). The tree has since advanced (01-08 ColorfulX migration + G-01-1 fix, 01-09 DeprecatedAPI inline, DEP-01 de-vendor to external OpenCC fork, ImageColors rename). This report verifies the current sources.

## Goal Achievement

### Observable Truths

| # | Truth (Success Criterion) | Status | Evidence |
| --- | --- | --- | --- |
| 1 | SC1 — `ChineseConverter` (Simp/Trad) produces identical output on the forked, modernized SwiftyOpenCC; project builds clean | ✓ VERIFIED | `FileClient/TagTranslation+ChtConverted.swift` does `import OpenCC`, builds `ChineseConverter.Options` (`.traditionalize` / `.hkStandard` / `.twStandard`/`.twIdiom`) and calls `converter.convert(...)`. `Package.swift` declares the external app-owned fork `EhPanda-Team/SwiftyOpenCC` exact `2.1.0` (product `OpenCC`); `FileClient` target depends on `.openCC`. `Package.resolved` pins SwiftyOpenCC 2.1.0 (rev cc776a3c). Local `AppPackage/Sources/SwiftyOpenCC` + `copencc` module dirs are GONE. `SwiftyOpenCCTests` (4 `@Test`, Swift Testing) + `FileClientTests` (8) pass on the current tree (fresh `** TEST SUCCEEDED **`). |
| 2 | SC2 — dominant-color extraction unchanged on the modernized local color module | ✓ VERIFIED | Local `ImageColors` module: `ImageColors.colors(from:quality:) -> Colors?` with public `Colors { background, primary, secondary, detail }`; modern CGImage-in / SwiftUI-Color-out API. `LibraryClient.analyzeImageColors` does `import ImageColors` and calls `ImageColors.colors(from: cgImage, quality: .lowest)`. No `UIImageColors` module/import remains (only historical doc comments). `ImageColorsTests` (3 `@Test`) pass. External jathu/UIImageColors absent from manifest & resolved. |
| 3 | SC3 — `MarkdownUtil.parseTexts/parseLinks/parseImages` yields identical `TagTranslation` output; DetailView markdown preserved; SwiftCommonMark removed | ✓ VERIFIED | `MarkdownExt/MarkdownUtil.swift` does `import Markdown` and exposes all three public parse funcs. `TagTranslationFeature/TagTranslation+Markdown.swift` does `import MarkdownExt` and drives every field through `MarkdownUtil.parse*`. `DetailFeature` has NO direct markdown-parser import (routes via TagTranslation — D-08). `Package.swift` sole-owns `swift-markdown` `from 0.8.0` on the `MarkdownExt` target; `Package.resolved` pins 0.8.0. SwiftCommonMark/CommonMarkExt/OpenCCExt removed from manifest & sources. `MarkdownExtTests` (11) + `TagTranslationFeatureTests` (6) pass. |
| 4 | SC4 — DeprecatedAPI is gone; the `getCFReadStream` path is inlined warning-free with DF behavior unchanged | ✓ VERIFIED | External `EhPanda-Team/DeprecatedAPI` package removed from manifest & `Package.resolved`. Local `LegacyCFReadStream` module isolates the single `CFReadStreamCreateForHTTPRequest` call, compiled with `-suppress-warnings` via `swiftSettings` and excluded from `products` (`name != legacyCFReadStream`). `NetworkingFeature/DFExtensions.swift` does `import LegacyCFReadStream` and calls `LegacyCFReadStream.create(...)` preserving the `.autorelease().takeUnretainedValue()` ownership contract and the reserved-`Host`/persistent-connection semantics. `NetworkingFeatureTests` (14, incl. `DFRequestSemanticsTests`) pass. Real-world China/SNI check accepted PASS (informational; request path byte-identical — 01-UAT.md test 2). |
| 5 | SC5 — `GalleryCardCell`'s animated gradient renders as before on the latest Colorful, with the version pin updated | ✓ VERIFIED | `GalleryCardCell.swift` does `import ColorfulX`; `Package.swift` pins `Lakr233/ColorfulX` exact `6.1.0` (`Package.resolved` rev bdf19698), and `Colorful` (old) is absent. The G-01-1 regression fix is present in code: the `ColorfulView` is gated behind `if animated` (dark mode AND `gallery.gid == currentID`), light-mode cover-color analysis is skipped (`handleCoverSuccess` guards `colorScheme == .dark`), and a neutral-seed `CardGradientView` (`displayedColors = [.black]` → real palette on appear, `transitionSpeed: .constant(6)`) blooms the gradient in. Visual parity (D-19) user-verified PASS live on simulator (iPhone Air, iOS 26.5) — 01-UAT.md test 1 = pass, 01-COLORFUL-UAT.md all checks pass. |

**Score:** 5/5 truths verified (0 present-but-behavior-unverified). SC5's runtime gradient behavior is confirmed by the recorded human UAT (D-19 PASS), so it is behaviorally verified, not merely present.

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `AppPackage/Sources/FileClient/TagTranslation+ChtConverted.swift` | `import OpenCC` + regional conversion | ✓ VERIFIED | Imports external `OpenCC`; builds `ChineseConverter.Options`, `converter.convert`; `full color`→`全彩` custom mapping preserved |
| `AppPackage/Sources/ImageColors/ImageColors.swift` | Local CGImage→Colors module | ✓ VERIFIED | `public enum ImageColors` + `colors(from:quality:)`, `public struct Colors`, `Quality`; downsampling + edge/accent selection intact |
| `AppPackage/Sources/MarkdownExt/MarkdownUtil.swift` | swift-markdown helper | ✓ VERIFIED | Sole owner of `Markdown` product; three public parse funcs (`parseTexts/parseLinks/parseImages`) |
| `AppPackage/Sources/LegacyCFReadStream/LegacyCFReadStream.swift` | Warning-suppressed CFReadStream isolation | ✓ VERIFIED | `public enum LegacyCFReadStream.create(_:_:)` wraps the one deprecated call; target `-suppress-warnings`; excluded from products |
| `AppPackage/Sources/NetworkingFeature/DFExtensions.swift` | DF path via LegacyCFReadStream | ✓ VERIFIED | `import LegacyCFReadStream`; ownership + reserved-Host + persistent-connection semantics preserved |
| `AppPackage/Sources/HomeFeature/GalleryCardCell.swift` | ColorfulX gradient w/ G-01-1 fix | ✓ VERIFIED | `import ColorfulX`; `if animated` gate; dark-only color analysis; neutral-seed `CardGradientView` bloom |
| `AppPackage/Package.swift` / `Package.resolved` | Modernized pins | ✓ VERIFIED | ColorfulX exact 6.1.0; SwiftyOpenCC exact 2.1.0 (product OpenCC); swift-markdown from 0.8.0; resolved matches |
| Removed: local SwiftyOpenCC/copencc/UIImageColors modules, OpenCCExt, CommonMarkExt, SwiftCommonMark, external DeprecatedAPI/Colorful/jathu pins | Absent | ✓ VERIFIED | No such source dirs (only external fork checkouts under `.build`); no manifest/resolved references to old pins |

### Key Link Verification

| From | To | Via | Status |
| --- | --- | --- | --- |
| `FileClient.chtConverted` | `OpenCC.ChineseConverter` | `import OpenCC` + `.openCC` target dep + `convert()` | ✓ WIRED |
| `LibraryClient.analyzeImageColors` | `ImageColors.colors(from:quality:)` | `import ImageColors` + `.imageColors` target dep | ✓ WIRED |
| `TagTranslation+Markdown` | `MarkdownExt.MarkdownUtil` | `import MarkdownExt` + `.markdownExt` dep + `parse*` calls | ✓ WIRED |
| `NetworkingFeature.DFExtensions` | `LegacyCFReadStream.create` | `import LegacyCFReadStream` + `.legacyCFReadStream` dep | ✓ WIRED |
| `GalleryCardCell` | ColorfulX gradient | `import ColorfulX` + `ColorfulView` in gated `CardGradientView` | ✓ WIRED |

### Behavioral Spot-Checks (fresh, single simulator invocation, current tree)

| Behavior | Command (targeted) | Result | Status |
| --- | --- | --- | --- |
| Simp/Trad converter parity | `-only-testing:SwiftyOpenCCTests` | 4 `@Test`, Swift Testing | ✓ PASS |
| App-level tag conversion parity | `-only-testing:FileClientTests` | 8 tests | ✓ PASS |
| Dominant-color parity | `-only-testing:ImageColorsTests` | 3 `@Test` | ✓ PASS |
| Markdown parse parity | `-only-testing:MarkdownExtTests` | 11 `@Test` | ✓ PASS |
| TagTranslation markdown output | `-only-testing:TagTranslationFeatureTests` | 6 `@Test` | ✓ PASS |
| DF request semantics (SC4) | `-only-testing:NetworkingFeatureTests` | 14 `@Test` incl. DFRequestSemanticsTests | ✓ PASS |

One `xcodebuild ... test` invocation (from `AppPackage/`, allowed to finish): `** TEST SUCCEEDED ** [35.830 sec]`. The XCTest "Executed 0 tests" summary lines are the expected artifact for Swift Testing (`import Testing` / `@Test`) suites, which do not increment XCTest counters; 46 `@Test` cases across the six goal-critical targets compiled and ran green. The full `AppPackage-Package` suite was also reported green on this tree.

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| DEP-01 | 01-01/03 | Fork + modernize SwiftyOpenCC | ✓ SATISFIED | De-vendored to external `EhPanda-Team/SwiftyOpenCC` 2.1.0 (product OpenCC); FileClient wired; parity tests pass; local modules removed |
| DEP-02 | 01-01/04 | Fork + modernize UIImageColors | ✓ SATISFIED | Local `ImageColors` (renamed, modern CGImage/Color API); LibraryClient wired; parity tests pass; external pkg removed |
| DEP-03 | 01-02/05 | Migrate to swift-markdown | ✓ SATISFIED | `MarkdownExt` sole-owns swift-markdown 0.8.0; parity tests pass; SwiftCommonMark removed from manifest |
| DEP-06 | 01-02/06/09 | Inline DeprecatedAPI warning-free | ✓ SATISFIED | External DeprecatedAPI inlined into local `-suppress-warnings` `LegacyCFReadStream`; DF semantics tests pass; behavior unchanged |
| DEP-07 | 01-07/08 | Migrate to latest Colorful | ✓ SATISFIED | Migrated to ColorfulX 6.1.0 (Metal); GalleryCardCell rewired with G-01-1 fix; visual parity UAT PASS |

All five requirement IDs are declared in plan frontmatter and marked Complete in REQUIREMENTS.md (rows DEP-01/02/03/06/07 → Phase 1 → Complete). No orphaned requirements.

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
| --- | --- | --- | --- |
| `AboutView.swift:186-187` | Acknowledgements still credit SwiftCommonMark (localized strings, not a code dependency) | ℹ️ Info | Tracked in deferred-items.md; SC3 only requires SwiftCommonMark removed from `Package.swift` (done). No build/functional impact. Future acknowledgements pass. |
| `DownloadsFeatureTests/ReadingReducerLocalTests.swift:23` | Pre-existing `let`-vs-`var` warning | ℹ️ Info | Unrelated to this phase (a downloads test); tracked in deferred-items.md. |

No debt markers (TBD/FIXME/XXX) in any phase-modified Swift source. No stubs — every parity path is wired to a real engine/parser and covered by passing tests.

### Deferred Items (tracked, not gaps)

| Item | Tracked In | Note |
| --- | --- | --- |
| Acknowledgements credit SwiftCommonMark, not swift-markdown | deferred-items.md | Localized strings only; no build/functional impact; future acknowledgements pass |
| Pre-existing unrelated warning in DownloadsFeatureTests | deferred-items.md | Not caused by this phase |

The prior "ColorfulView deprecation (no in-package replacement)" deferred item was RESOLVED by the 01-08 ColorfulX migration and is no longer outstanding.

### Human Verification Required

None outstanding. Both human UATs are satisfied and recorded:
1. **Colorful animated-gradient visual parity (D-19)** — user-verified PASS live on simulator after the G-01-1 fix (01-UAT.md test 1; 01-COLORFUL-UAT.md all checks pass).
2. **Real-world domain-fronting / SNI (D-15)** — accepted PASS (informational): request path byte-identical after the DEP-06 inline; a live in-region China/SNI test is only owed if a non-deprecated DF replacement is ever adopted (a future phase), not this one.

### Gaps Summary

No gaps. All five ROADMAP success criteria are verified against the actual current sources — not SUMMARY prose:

- DEP-01 was de-vendored to the external `EhPanda-Team/SwiftyOpenCC` fork (product `OpenCC`, exact 2.1.0); the former local SwiftyOpenCC + copencc modules are gone and `FileClient` imports `OpenCC`.
- The color module was renamed to `ImageColors` with a modern CGImage-in/SwiftUI-Color-out API and is wired into `LibraryClient.analyzeImageColors`.
- swift-markdown (0.8.0) is sole-owned by `MarkdownExt`; SwiftCommonMark/CommonMarkExt/OpenCCExt are removed; DetailFeature routes markdown via TagTranslation (no direct parser import).
- The external `DeprecatedAPI` package was inlined into the local warning-suppressed `LegacyCFReadStream` module — SC4's "inlined warning-free, DF behavior unchanged" is now literally met (superseding the earlier document-skip retention).
- Colorful was migrated to ColorfulX 6.1.0; the initially-mechanical swap's gradient regression (G-01-1) was fixed (animated-gated render, light-mode analysis skip, neutral-seed bloom) and user-verified.

Parity is behavior-locked by 46 Swift Testing `@Test` cases across the six goal-critical targets, green on a fresh targeted run, plus the two satisfied human UATs. Phase goal achieved.

---

_Verified: 2026-07-11T03:05:00Z_
_Verifier: Claude (gsd-verifier)_
