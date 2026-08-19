---
phase: quick-260819-ovp
plan: 01
subsystem: testing
tags: [swift-concurrency, xctest, xcuitest, string-catalog, xcstrings, localization, swiftlint]

requires:
  - phase: 15-continued-background-downloads
    provides: "the deferred-items register (DEF-15-04, DEF-15-10) and the `ResourceStringSymbols.swift` shared-key layer these two items act on"
provides:
  - "a warning-free `UITests` build: the pad idiom read now happens in a genuinely main-actor-isolated context"
  - "43 shared string accessors that forward to Xcode's generated catalog symbols, so a bad key is a compile error instead of a raw key rendered on screen"
affects: [localization, ui-tests, resources]

tech-stack:
  added: []
  patterns:
    - "generated-symbol forwarding: a public accessor layer whose bodies resolve compiler-checked internal symbols rather than hand-typed key literals"
    - "main-actor reads in XCTest live in the test method, not in a `setUpWithError` override"

key-files:
  created: []
  modified:
    - EhPandaUITests/DeepLinkPadUITests.swift
    - AppPackage/Sources/Resources/ResourceStringSymbols.swift

key-decisions:
  - "PD-1's premise was false and was corrected during execution: `setUpWithError()` overrides a nonisolated XCTest declaration, so the class-level `@MainActor` never reached it and no shape of the guard inside it can be warning-free. The guard moved into the test method, which overrides nothing and is therefore main-actor-isolated."
  - "`@MainActor override func setUpWithError()` was rejected on evidence, not preference: it is a hard Swift 6 error (isolation differs from the nonisolated overridden declaration), proven by a standalone typecheck before any repo edit."
  - "No isolation escape hatch was used: no `MainActor.assumeIsolated`, no `nonisolated(unsafe)`, no `@preconcurrency`, no `swiftlint:disable` (T-ovp-04 holds)."
  - "PD-2..PD-5 executed exactly as written: the public layer stays, every body forwards, no catalog / consumer / test file was touched."

patterns-established:
  - "Forwarder layer: `public static var cancel: LocalizedStringResource { .cancel }` — the implicit member resolves the generated internal symbol against the contextual type, never the enclosing namespace."
  - "Hand-written semantic labels survive on the public signature while forwarding positionally to the generated symbol (`days(count:)` -> `.days(count)`)."

requirements-completed: [DEF-15-04, DEF-15-10]

coverage:
  - id: D1
    description: "DEF-15-04 — the two `DeepLinkPadUITests.swift` main-actor-isolation warnings are gone, and the pad test still runs on an iPad while skipping elsewhere"
    requirement: DEF-15-04
    verification:
      - kind: other
        ref: "xcodebuild build-for-testing -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests -destination 'generic/platform=iOS Simulator' (0 Swift diagnostics)"
        status: pass
      - kind: automated_ui
        ref: "EhPandaUITests/DeepLinkPadUITests#testPadTabModalReplacedByDeepLink (iPad Pro 11-inch (M5) simulator)"
        status: pass
    human_judgment: false
  - id: D2
    description: "DEF-15-10 — all 43 shared string accessors forward to Xcode's generated catalog symbols; no key literal remains, and a renamed key is a compile error at the forwarder"
    requirement: DEF-15-10
    verification:
      - kind: other
        ref: "xcodebuild build -project EhPanda.xcodeproj -scheme Resources -destination 'generic/platform=iOS Simulator' (all 43 symbols resolve, 0 diagnostics)"
        status: pass
      - kind: other
        ref: "PD-5 negative proof: key `cancel` renamed in Localizable.xcstrings -> Resources build fails at the forwarder; reverted, rebuild green"
        status: pass
      - kind: other
        ref: "xcodebuild build -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator' (0 diagnostics, SwiftLint plugin clean)"
        status: pass
      - kind: unit
        ref: "xcodebuild test -scheme AppPackage-Package (1020 tests, 0 failures)"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-08-19
status: complete
---

# Quick Task 260819-ovp: Close DEF-15-04 and DEF-15-10 Summary

**The pad UI test's idiom read moved to a context that is actually main-actor-isolated (clearing both concurrency warnings), and all 43 shared string accessors now forward to Xcode's generated catalog symbols so a bad key fails the build instead of rendering its own name.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-08-19T08:58:00Z
- **Completed:** 2026-08-19T09:23:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- **DEF-15-04** closed: the `UITests` build-for-testing is free of Swift diagnostics (4 warning lines before, 0 after), and the pad test still passes on an iPad simulator.
- **DEF-15-10** closed: `ResourceStringSymbols.swift` hand-types nothing anymore — no key literal, no `table:`, no `defaultValue:`, no bundle description, no `#bundle`. All 43 public signatures are byte-identical to before; only the bodies changed.
- The property DEF-15-10 asked for was **demonstrated, not asserted**: a temporary catalog key rename made the build fail at the exact forwarder.
- The plan's DEF-15-04 approach turned out to rest on a false premise about XCTest's isolation. That was diagnosed with a standalone typecheck and corrected rather than worked around; no suppression of any kind was introduced.

## Task Commits

1. **Task 1: DEF-15-04 — read the pad idiom on the main actor** — `97347f5d` (test)
2. **Task 2: DEF-15-10 — forward the 43 shared string accessors to Xcode's generated symbols** — `15cf9273` (refactor)

No docs artifacts were committed by the executor: `git diff HEAD~2 HEAD` touches exactly the two source files, and `.planning/`, `deferred-items.md`, `STATE.md` and `ROADMAP.md` are untouched.

## Files Created/Modified

- `EhPandaUITests/DeepLinkPadUITests.swift` — `setUpWithError` is back to `continueAfterFailure = false` alone; the `guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip(...) }` now opens the test method, above a four-line comment recording why it cannot live in the set-up and why `XCTSkipUnless` is unusable. Skip message kept verbatim; `import UIKit` still needed.
- `AppPackage/Sources/Resources/ResourceStringSymbols.swift` — rewritten as 43 forwarders (141 lines, longest line 117). File-level WHY doc added; `continuedSessionSubtitle`'s doc rewritten; `resourceStringSymbolsBundleDescription` and its `#bundle` macro deleted. Alphabetical order, `import Foundation`, the `@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)` attribute, `public nonisolated extension LocalizedStringResource` and both enum names preserved.

## Gate Results

### Task 1 (DEF-15-04)

| Gate | Result |
|---|---|
| `xcodebuild build-for-testing … -scheme EhPanda -testPlan UITests` (pre-fix baseline, reproducing the item) | `** TEST BUILD SUCCEEDED **`, **4** `warning:` lines (2 unique warnings × arm64 + x86_64 compile passes) |
| Same gate, after the corrected fix | `** TEST BUILD SUCCEEDED ** [46.523 sec]`, **0** `warning:`/`error:` lines excluding `appintentsmetadataprocessor` |
| Excluded pre-existing tool noise | `appintentsmetadataprocessor[…] warning: Metadata extraction skipped. No AppIntents.framework dependency found.` — not a Swift diagnostic, present before and after |
| iPad single-test run (`-only-testing:EhPandaUITests/DeepLinkPadUITests`, iPad Pro 11-inch (M5) simulator) | `Test Case '-[EhPandaUITests.DeepLinkPadUITests testPadTabModalReplacedByDeepLink]' passed (16.894 seconds)`, `Executed 1 test, with 0 failures (0 unexpected)`, `** TEST SUCCEEDED ** [684.424 sec]` |

The optional iPhone skip-side run was **not** performed — see "Deferred / not done" below.

### Task 2 (DEF-15-10)

| Gate | Result |
|---|---|
| (a) `xcodebuild build … -scheme Resources` | `** BUILD SUCCEEDED ** [1.951 sec]`, 0 diagnostics. Verified non-vacuous: the log shows `SwiftCompile … Compiling ResourceStringSymbols.swift` for both arm64 and x86_64, plus the SwiftLint plugin invocation over the file. |
| (b) PD-5 negative proof | `** BUILD FAILED **` with the single error quoted below |
| (b) revert + rebuild | `git checkout -- …/Localizable.xcstrings` → `** BUILD SUCCEEDED ** [1.782 sec]`, 0 diagnostics; `git status --porcelain` shows the catalog unmodified |
| (c) `xcodebuild build … -scheme AppFeature` (whole graph, SwiftLint plugin runs) | `** BUILD SUCCEEDED ** [94.878 sec]`, 0 `warning:`/`error:` lines |
| (d) `xcodebuild test -scheme AppPackage-Package` (one run, iPhone Air simulator) | `** TEST SUCCEEDED ** [87.985 sec]`, **1020 tests / 0 failures**, 0 `✘` markers — exactly the baseline count, as expected since no test was added or removed. (Sum of the per-target `Test run with N tests` lines: 488+102+78+66+60+44+33+26+24+18+14+12+11+9+8+6+4+4+4+3+3+3 = 1020. The 13 `known issues` across four targets are pre-existing `withKnownIssue` expectations.) |
| (e) `git status --porcelain` before staging | only `AppPackage/Sources/Resources/ResourceStringSymbols.swift` modified |
| Verify-block greps | `table: "` 0, `defaultValue:` 0, `resourceStringSymbolsBundleDescription` 0, `#bundle` 0, `public static` **43**; the four required forwarder patterns all present; `git diff --quiet -- AppPackage/Sources/Resources/Resources AppPackage/Tests` holds |

### PD-5 negative proof, as observed

With `"cancel"` renamed to `"cancel_renamed"` at line 4 of `AppPackage/Sources/Resources/Resources/Localizable.xcstrings`, the `Resources` build failed with exactly one Swift error (path shown repository-relative):

```
AppPackage/Sources/Resources/ResourceStringSymbols.swift:24:62: error: type 'LocalizedStringResource' has no member 'cancel'
```

Line 24 column 62 is the `.cancel` forwarder inside `RLocalizable.cancel` — the message PD-3 predicted, at the site PD-5 named, and not a recursion diagnostic. The rename was reverted with `git checkout --` and never staged or committed; the catalog is byte-identical to `HEAD~2`.

## Decisions Made

- **PD-1's premise was wrong, and the correction is the substantive finding of this task.** PD-1 reasoned that `setUpWithError` "runs on" the `@MainActor` class so evaluating the comparison in the method body needs no hop. It does not: `XCTest.setUpWithError()` is declared nonisolated (it comes from the ObjC XCTest headers with no `SWIFT_UI_ACTOR` annotation), and a `@MainActor` class attribute does not reach a member that overrides a nonisolated declaration. Applying PD-1 verbatim left the warnings in place with the message *changed* from "nonisolated autoclosure" to "nonisolated **context**", which is what exposed the real cause: the enclosing method had been nonisolated all along, and the original autoclosure wording merely named the innermost nonisolated scope.
- **The escape hatches were rejected on their merits.** `@MainActor override func setUpWithError()` is not a legal shape (hard error, proven below). `MainActor.assumeIsolated` would have been a runtime assertion standing in for a static fact the compiler can establish elsewhere, and the plan's own threat register (T-ovp-04) forbids it. Moving the read into the test method needs neither: that method overrides nothing, so the class's `@MainActor` applies to it, and the read is main-actor-isolated by construction.
- **PD-2..PD-5 were executed exactly as written**, including the decision to keep the public layer rather than delete or re-export it, the exact forwarder shapes per signature family, the 120-column formatting rule, and the doc-comment surgery (file-level WHY added; the `continuedSessionSubtitle` ORDER paragraph and inline-literal paragraph dropped as PD-4 required, privacy and labels-from-substitutions reasoning kept).
- **The generated symbols matched `<reference>` exactly** — 42 `Localizable` members (33 argument-less vars, 8 positional `%lld` funcs, 1 labelled `continuedSessionSubtitle`) and 1 `Constant` member. No difference to report.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] PD-1's fix shape could not clear the DEF-15-04 warnings; the read moved to the test method instead**

- **Found during:** Task 1 (DEF-15-04)
- **Issue:** PD-1's instruction — replace `XCTSkipUnless` with a `guard`/`throw XCTSkip` *inside `setUpWithError`* — was applied verbatim and the gate still reported the warnings, 4 lines, now reading:
  ```
  EhPandaUITests/DeepLinkPadUITests.swift:10:32: warning: main actor-isolated property 'userInterfaceIdiom' can not be referenced from a nonisolated context
  EhPandaUITests/DeepLinkPadUITests.swift:10:24: warning: main actor-isolated class property 'current' can not be referenced from a nonisolated context
  ```
  The `guard` condition is not a closure, so the "nonisolated context" being named is `setUpWithError` itself. `XCTest.setUpWithError()` is nonisolated, and an override cannot be more isolated than what it overrides, so the class-level `@MainActor` never applied to that method. PD-1's stated basis ("the class is `@MainActor` and `setUpWithError` runs on it, so evaluating the comparison directly in the method body is correct") is therefore false, and **no** shape of the guard inside `setUpWithError` can be warning-free without an isolation escape hatch.
- **Fix:** Diagnosed before editing further, with a standalone Swift 6 typecheck against the simulator SDK comparing the two candidate shapes:
  - annotating the override — `error: main actor-isolated instance method 'setUpWithError()' has different actor isolation from nonisolated overridden declaration`, with `note: overridden declaration is here → open func setUpWithError() throws`. Not a legal option.
  - the guard at the top of the test method — typechecks clean.

  So `setUpWithError` was restored to `continueAfterFailure = false` alone and the `guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("The tab-modal gallery detail is an iPad-exclusive entry.") }` now opens `testPadTabModalReplacedByDeepLink`, before the app is launched. Everything else PD-1 asked for is intact: the read is on the main actor (the test method overrides nothing, so `@MainActor` reaches it), the skip is the same public `XCTSkip` error, the message is verbatim, and the comment above it records the WHY — now naming both reasons, the nonisolated override and `XCTSkipUnless`'s nonisolated autoclosure — so nobody moves it back.
- **Files modified:** `EhPandaUITests/DeepLinkPadUITests.swift`
- **Verification:** `build-for-testing` for the `UITests` test plan reports 0 Swift diagnostics (from 4); the iPad run of `DeepLinkPadUITests` passes.
- **Committed in:** `97347f5d` (Task 1 commit)

**Behavioural note on the relocation:** with one test method in the class the skip semantics are unchanged (a non-pad idiom skips the same test with the same message; XCTest reports a skip either way). The difference to know is that a future second test method in this class would need the same guard, since it no longer runs in shared set-up. The comment at the guard says why the set-up is unavailable, which is the information a future author needs to make that call.

---

**Total deviations:** 1 auto-fixed (1 blocking).
**Impact on plan:** DEF-15-04's stated outcome is met by a different, provably legal shape; DEF-15-10 landed exactly as planned. No scope creep, no new dependency, no suppression, no catalog / consumer / test change.

## Issues Encountered

- **A 1.95-second "BUILD SUCCEEDED" for gate (a) looked like a cache no-op.** It was checked rather than trusted: the log contains `SwiftCompile normal arm64 Compiling ResourceStringSymbols.swift` and the x86_64 equivalent, a `SwiftDriver Resources` invocation with `-swift-version 6`, and the SwiftLint plugin run over the file. The gate is real; the `Resources` target is simply one small file.
- **The full-suite log carries no single total line.** Swift Testing prints one `Test run with N tests` per test target, so the 1020 total is the sum of those 22 lines (listed in the gate table above) with 0 `✘` markers and `** TEST SUCCEEDED **`.

## Deferred / not done

- **The optional iPhone skip-side run was not performed.** The plan marks it "(Optional, cheap)". It is a `xcodebuild test` invocation, and this machine tolerates only one at a time (an overlapping run, or killing one mid-launch, wedges `testmanagerd`); by the time the mandatory iPad run finished, Task 2's own mandatory full-suite run was the next thing due. Nothing depends on it: the skip path is the `guard`'s `else` branch, the same public `XCTSkip` the previous code threw, and the item's gate is the warning-free build, which passed. If the skip side is ever worth pinning, it costs one run on simulator `88B217DA-A166-4BAD-820D-DE13B1C4EB54` and should read `1 test skipped`.

## User Setup Required

None.

## Next Phase Readiness

- `deferred-items.md` rows DEF-15-04 and DEF-15-10 are ready to be marked resolved with SHAs `97347f5d` and `15cf9273`. Per the plan the orchestrator writes those rows, along with `STATE.md` and `ROADMAP.md`, in the docs commit; the executor touched none of them.
- Only **DEF-15-07** (deferred indefinitely by the owner) then remains open in the Phase 15 register.
- One thing a future reader should know: the forwarder layer's correctness now depends on Xcode's string-symbol generation, which the file-level doc states explicitly along with why that is not a new dependency (the project builds only through Xcode; every module-local catalog already resolves the same way). This is threat-register entry T-ovp-02, dispositioned `accept`.

---
*Quick task: 260819-ovp*
*Completed: 2026-08-19*

## Self-Check: PASSED

- Both commits resolve in `git log`: `97347f5d`, `15cf9273`.
- Both modified files exist on disk and are committed; working tree is clean apart from this untracked plan directory.
- No absolute home path in this summary (the DerivedData reference is written `$HOME/…` in the plan; this summary quotes only repository-relative paths). No local reference-project name anywhere.
- `deferred-items.md`, `STATE.md` and `ROADMAP.md` were not edited and no docs artifact was committed.
