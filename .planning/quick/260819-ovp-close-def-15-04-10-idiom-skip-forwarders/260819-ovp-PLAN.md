---
phase: quick-260819-ovp
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  # Task 1 — DEF-15-04: the pad UI test reads the idiom on the main actor
  - EhPandaUITests/DeepLinkPadUITests.swift
  # Task 2 — DEF-15-10: the shared string accessors forward to Xcode's generated symbols
  - AppPackage/Sources/Resources/ResourceStringSymbols.swift
autonomous: true
gap_closure: true
gap_ids: [DEF-15-04, DEF-15-10]
requirements: [DEF-15-04, DEF-15-10]

must_haves:
  truths:
    - "DEF-15-04: `EhPandaUITests/DeepLinkPadUITests.swift` no longer reads `UIDevice.current.userInterfaceIdiom` inside `XCTSkipUnless`'s nonisolated autoclosure; the read happens directly in the `@MainActor` `setUpWithError`, and a non-pad idiom skips by `throw XCTSkip(...)` with the same message. `xcodebuild build-for-testing … -scheme EhPanda -testPlan UITests` reports zero Swift warnings (the only pre-existing line, `appintentsmetadataprocessor`'s 'Metadata extraction skipped', is not a Swift diagnostic and is excluded by the gate)."
    - "DEF-15-10: `ResourceStringSymbols.swift` contains NO hand-typed key literal, NO `table:` argument, NO `defaultValue:` literal and NO bundle description of its own: every one of the 43 public accessors keeps its exact public signature (name, parameter labels `count:`/`page:`/`completed:total:galleries:`, types, `public static var`/`func`) and its body forwards to the internal symbol Xcode generates from the Resources module's catalogs — `.cancel`, `.days(count)`, `.downloadStorePageMissing(page)`, `.continuedSessionSubtitle(completed: completed, total: total, galleries: galleries)`, `Constant.responseGalleryUnavailable`. A renamed, mistyped or deleted key is therefore a compile error at the forwarder (`type 'LocalizedStringResource' has no member '…'`), observed once by a temporary, uncommitted key rename."
    - "DEF-15-10: no consumer, test, or `.xcstrings` catalog changes; the two `continued_session` rendered-value pins in `ContinuedProcessingSessionFoldTests` stay as they are; the full `AppPackage-Package` suite stays at 1020 tests / 0 failures; the `AppFeature` build is warning-free (SwiftLint plugin runs in it)."
    - "Both changes are committed separately (two commits, messages ≤ 50 characters); no `swiftlint:disable`, no lint-rule edits, no absolute home path or local-project name in any artifact; `deferred-items.md`, `STATE.md`, `ROADMAP.md` untouched by the executor (the orchestrator writes the resolution rows with the commit SHAs in the docs commit)."
  artifacts:
    - path: "EhPandaUITests/DeepLinkPadUITests.swift"
      provides: "the main-actor idiom guard with a two-line comment stating why it is not `XCTSkipUnless`"
      contains: "throw XCTSkip("
    - path: "AppPackage/Sources/Resources/ResourceStringSymbols.swift"
      provides: "43 forwarders, a file-level doc explaining the layer's reason to exist (access level + hand-written numeric labels), a rewritten `continuedSessionSubtitle` doc"
      contains: "public static var cancel: LocalizedStringResource { .cancel }"
  key_links:
    - from: "AppPackage/Sources/Resources/ResourceStringSymbols.swift"
      to: "AppPackage/Sources/Resources/Resources/Localizable.xcstrings"
      via: "Xcode's `GeneratedStringSymbols_Localizable.swift` for the `Resources` target (internal `static` members on `LocalizedStringResource`, one per key, names derived 1:1 from the keys; `%#@name@` substitution keys get semantic labels, top-level `%lld` plural keys get `_ arg1:`)"
      pattern: "\\.continuedSessionSubtitle\\(completed: completed, total: total, galleries: galleries\\)"
    - from: "AppPackage/Sources/Resources/ResourceStringSymbols.swift"
      to: "AppPackage/Sources/Resources/Resources/Constant.xcstrings"
      via: "Xcode's `GeneratedStringSymbols_Constant.swift` (internal `enum Constant` nested on `LocalizedStringResource`)"
      pattern: "Constant.responseGalleryUnavailable"
---

<objective>
Close the owner's second Phase 15 deferred-items grouping (`deferred-items.md` index: DEF-15-04 and DEF-15-10, "quick task with …"). The grouping is the owner's; scope, order and approach inside it are decided HERE (planner decisions PD-1..PD-6) and are to be executed as written.

1. **DEF-15-04** — two Swift concurrency warnings at `EhPandaUITests/DeepLinkPadUITests.swift:9` (`main actor-isolated class property 'current' can not be referenced from a nonisolated autoclosure` at col 22; `main actor-isolated property 'userInterfaceIdiom' …` at col 30), reproduced today with `xcodebuild build-for-testing -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests -destination 'generic/platform=iOS Simulator'`. Read the idiom on the main actor instead of inside `XCTSkipUnless`'s autoclosure.
2. **DEF-15-10** — `ResourceStringSymbols.swift` hand-types the key literal in all 43 accessors, so a renamed, mistyped or deleted key still compiles and renders the raw key name. Xcode already generates internal symbols for the `Resources` target's two catalogs (verified in DerivedData today: `Resources.build/DerivedSources/GeneratedStringSymbols_Localizable.swift`, 42 symbols, and `GeneratedStringSymbols_Constant.swift`, 1 symbol, names matching the hand-written layer 1:1). Keep every public signature; replace each body with a forwarder so the key literals vanish and a bad key becomes a compile error.

Output: source on `feature/gsd-phase-15`, TWO commits (one per item, Task 1 then Task 2). Do NOT edit `deferred-items.md`, `STATE.md` or `ROADMAP.md` — the orchestrator records the resolutions with the commit SHAs in the docs commit.
</objective>

## Planner decisions (owned here — reasoning stated; execute as written, do not re-litigate)

**PD-1 (DEF-15-04) Take the read out of the autoclosure with a `guard`/`throw XCTSkip`, not a hoisted local.** `XCTSkipUnless(_:_:file:line:)` takes its condition as a nonisolated `@autoclosure`; `UIDevice` is main-actor-isolated in the iOS 26 SDK, so the two property reads inside that closure are exactly what the compiler flags (two warnings, one per access). The class is `@MainActor` and `setUpWithError` runs on it, so evaluating the comparison directly in the method body is correct and needs no hop. Of the two warning-free shapes — `let isPad = …; try XCTSkipUnless(isPad, …)` and `guard … == .pad else { throw XCTSkip(…) }` — use the `guard`: it removes the autoclosure boundary rather than feeding it a pre-computed value through a throwaway local, and `XCTSkip` is the same public error `XCTSkipUnless` throws, so the skip reads and reports identically. Keep the message verbatim ("The tab-modal gallery detail is an iPad-exclusive entry."). Add a two-line comment above the guard saying WHY it is not `XCTSkipUnless` (the autoclosure is nonisolated; `UIDevice.current` is main-actor-isolated; the read stays in this `@MainActor` set-up) so nobody "simplifies" it back. Nothing else in the file changes; `import UIKit` stays (still the only `UIDevice` user in the target).

**PD-2 (DEF-15-10) Forward; do not delete the layer, do not re-export, do not touch a catalog.** The generated symbols are `internal` (`static var cancel: LocalizedStringResource` with no access modifier, in a `nonisolated extension LocalizedStringResource` inside the `Resources` module), and Swift has no way to re-export them at `public`; every consumer in 17 modules (112 call sites of `.RLocalizable.…`/`.RConstant.…`, plus 9 test files) depends on the public `LocalizedStringResource.RLocalizable` / `.RConstant` names. So the public layer stays exactly as a surface and each body becomes a forwarder into the same module's generated symbol. Nothing about what a consumer sees changes; only the proof moves from "a string that happens to match" to "a symbol the compiler resolves". No `.xcstrings` edit, no consumer edit, no test edit.

**PD-3 (DEF-15-10) The exact forwarder shapes — one per generated signature family.** Verified today against the generated file and with a standalone Swift 6 `-strict-concurrency=complete` compile of the same shape:
- 34 argument-less `Localizable` keys: `public static var cancel: LocalizedStringResource { .cancel }` — the implicit member resolves against the contextual type `LocalizedStringResource`, i.e. the generated internal symbol, never the enclosing `RLocalizable.cancel` (a missing generated symbol is `error: type 'LocalizedStringResource' has no member 'cancel'`, confirmed, not recursion).
- 8 top-level `%lld` plural keys, generated POSITIONAL (`static func days(_ arg1: Int)`): keep the hand-written label and forward positionally — `public static func days(count: Int) -> LocalizedStringResource { .days(count) }`; same for `hours`, `minutes`, `seconds`, `pages`, `stars` (`count:`) and `downloadStorePageImageCorrupted`, `downloadStorePageMissing` (`page:`). The labels are the AGENTS.md "labelled localized-format arguments" rule for shared keys and must not fall back to the generated positional signatures.
- `continued_session.subtitle`, generated WITH semantic labels because its value is three named `%#@…@` substitutions: `public static func continuedSessionSubtitle(completed: Int, total: Int, galleries: Int) -> LocalizedStringResource { .continuedSessionSubtitle(completed: completed, total: total, galleries: galleries) }` (body on its own line — the one-liner exceeds 120 columns).
- `RConstant.responseGalleryUnavailable` → `Constant.responseGalleryUnavailable` (the generated `Constant` enum is nested on `LocalizedStringResource`, so the bare nested-type name resolves from inside the extension; confirmed in the standalone compile).
- Formatting: one line where the whole accessor fits in 120 columns, otherwise the body on its own line between the braces (the only such cases are the longest `downloadStore…` names and the argument-taking funcs). Keep the current alphabetical order inside each enum, `import Foundation`, the `@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)` attribute, `public nonisolated extension LocalizedStringResource`, and the two enum names.
- Delete `private nonisolated let resourceStringSymbolsBundleDescription = …` (unused once no body builds a `LocalizedStringResource` itself); the `#bundle` macro leaves with it. The generated file carries its own bundle description (`Bundle.module` under `SWIFT_PACKAGE`).

**PD-4 (DEF-15-10) Doc comments: one file-level WHY, one rewritten symbol doc, no per-accessor chatter.** Replace the bare file with a file-level doc (a `//`/`///` block above the extension) stating the design so it does not read as needless indirection: Xcode generates `internal` symbols for this module's two catalogs (`STRING_CATALOG_GENERATE_SYMBOLS`), one per key, names derived from the keys; this file is the module's public surface over them and exists for two reasons only — access level (the generated members cannot be re-exported) and hand-written semantic labels for the top-level `%lld` plural keys whose generated signatures are positional; every body forwards, so a renamed, mistyped or deleted key is a compile error here rather than a raw key rendered on screen, which is why no runtime "does it resolve" test exists for these keys. Rewrite the `continuedSessionSubtitle` doc to what is still true: the card's subtitle is three counts with no wording of its own (privacy reasoning stays — the key accepts nothing but integers, so no content-identifying text has a path onto the card); the labels come from the catalog's three named substitutions, which is why the generated symbol — and so this forwarder — is labelled rather than positional. DROP the two paragraphs that the forwarder makes false or moot: the "parameter ORDER is load-bearing … `arguments` below is what supplies those positions" paragraph (the forwarder passes labelled arguments; position binding now lives in the generator, derived from the catalog's `argNum`s) and the "Written inline rather than bound to a local … stray `%lld%lld%lld` entry" paragraph (no literal remains in this file to be extracted). Do not add a doc to each of the other 42 accessors.

**PD-5 (DEF-15-10) Proof, positive and negative.** Positive: a warning-free `AppFeature` build (which compiles `Resources` against the generated symbols — every one of the 43 keys must still exist for it to succeed) and one full `AppPackage-Package` run (1020 tests; consumers render several of these keys through `String(localized:)`). Negative, once, locally, NOT committed: rename the key `"cancel"` to `"cancel_renamed"` in `AppPackage/Sources/Resources/Resources/Localizable.xcstrings`, build the `Resources` scheme (`xcodebuild build -project EhPanda.xcodeproj -scheme Resources -destination 'generic/platform=iOS Simulator'`), confirm it fails with `error: type 'LocalizedStringResource' has no member 'cancel'` at the forwarder line, then `git checkout -- AppPackage/Sources/Resources/Resources/Localizable.xcstrings` and rebuild green. Record the observed error line in the SUMMARY. This is the property the item asked for, demonstrated rather than asserted.

**PD-6 Order, commits, gates.** Task 1 (DEF-15-04) first — one file, isolated target; then Task 2 (DEF-15-10). One commit per task, messages ≤ 50 characters (`commit-execution-protocol`): suggested `test(15): read the idiom on the main actor` and `refactor(15): forward shared string symbols`. Each commit is preceded by its task's warning-free build gate; Task 2 additionally by ONE full `AppPackage-Package` run. Never two overlapping `xcodebuild test` runs; never `pkill -9` a running one. If the pinned simulator ids below are absent, substitute a concrete simulator from `xcodebuild -showdestinations` / `xcrun simctl list devices available` and change nothing else. Worktree isolation is deliberately OFF for this task (set by the orchestrator): the Xcode DerivedData build cache is path-bound and a fresh worktree would force a cold build of the whole graph for every gate; every prior quick task in this repository executed sequentially on the main checkout.

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@./CLAUDE.md
@.swiftlint.yml
@.planning/phases/15-continued-background-downloads/deferred-items.md
@EhPandaUITests/DeepLinkPadUITests.swift
@AppPackage/Sources/Resources/ResourceStringSymbols.swift
@AppPackage/Sources/Resources/Resources/Localizable.xcstrings
@AppPackage/Sources/Resources/Resources/Constant.xcstrings
@AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSessionSubtitle.swift
@AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionFoldTests.swift
</context>

<reference>
Xcode's generated symbols for the `Resources` target live at (build-output, NOT a repo path — read, never edit):
`$HOME/Library/Developer/Xcode/DerivedData/EhPanda-*/Build/Intermediates.noindex/AppPackage.build/Debug-iphonesimulator/Resources.build/DerivedSources/GeneratedStringSymbols_Localizable.swift` and `…/GeneratedStringSymbols_Constant.swift`. Read both before writing Task 2 and mirror their exact member names and parameter shapes. Summary of what they contain today (verified 2026-08-19):
- `nonisolated extension LocalizedStringResource` with 42 internal `static` members for `Localizable.xcstrings`: argument-less `var`s for 34 keys; `func days(_ arg1: Int)`, `hours(_:)`, `minutes(_:)`, `seconds(_:)`, `pages(_:)`, `stars(_:)`, `downloadStorePageImageCorrupted(_:)`, `downloadStorePageMissing(_:)` (positional); `func continuedSessionSubtitle(completed: Int, total: Int, galleries: Int)` (labelled).
- `enum Constant` nested on `LocalizedStringResource` with `static var responseGalleryUnavailable` for `Constant.xcstrings`.
</reference>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: DEF-15-04 — read the pad idiom on the main actor, not in XCTSkipUnless's autoclosure</name>
  <files>EhPandaUITests/DeepLinkPadUITests.swift</files>
  <action>
    Implement PD-1 exactly. In `setUpWithError`, replace

    ```swift
    try XCTSkipUnless(
        UIDevice.current.userInterfaceIdiom == .pad,
        "The tab-modal gallery detail is an iPad-exclusive entry."
    )
    ```

    with a `guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("The tab-modal gallery detail is an iPad-exclusive entry.") }`, preceded by a two-line `//` comment: `XCTSkipUnless` evaluates its condition in a nonisolated autoclosure and `UIDevice.current` is main-actor-isolated, so the read stays here, in this `@MainActor` set-up, and only the skip is handed to XCTest. Keep `continueAfterFailure = false` above it; change nothing else in the file. Read `.swiftlint.yml` first (120 columns; the UI-test target is linted by the app scheme's plugin too).

    Gate: `xcodebuild build-for-testing -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests -destination 'generic/platform=iOS Simulator'` → `** TEST BUILD SUCCEEDED **` and ZERO lines matching `warning:|error:` after excluding `appintentsmetadataprocessor` (its "Metadata extraction skipped" line is tool noise, pre-existing, not a Swift diagnostic). Then run the single test once on the iPad simulator to prove the guard still admits the pad and the test passes: `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests -only-testing:EhPandaUITests/DeepLinkPadUITests -destination 'platform=iOS Simulator,id=8250D97E-9AB0-42FD-99DB-07B0094BF8C7'` → expect `Executed 1 test, with 0 failures`. (Optional, cheap: the same on the booted iPhone `id=88B217DA-A166-4BAD-820D-DE13B1C4EB54` → `1 test skipped`.) If the iPad run fails for a reason unrelated to the guard (simulator boot/launch), record the exact failure in the SUMMARY instead of looping on it — the warning-free build is the item's gate.

    Commit: `test(15): read the idiom on the main actor`
  </action>
  <verify>
    <automated>cd "$(git rev-parse --show-toplevel)" && grep -q 'throw XCTSkip(' EhPandaUITests/DeepLinkPadUITests.swift && test "$(grep -c 'XCTSkipUnless' EhPandaUITests/DeepLinkPadUITests.swift)" = "0" && xcodebuild build-for-testing -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests -destination 'generic/platform=iOS Simulator' 2>&1 | tee /tmp/ui.log | grep -E "TEST BUILD SUCCEEDED|BUILD FAILED" && test "$(grep -E 'warning:|error:' /tmp/ui.log | grep -v appintentsmetadataprocessor | wc -l | tr -d ' ')" = "0"</automated>
  </verify>
  <done>`DeepLinkPadUITests.swift` has no `XCTSkipUnless`; the idiom is read in the `@MainActor` set-up and a non-pad skips via `throw XCTSkip` with the original message; the UITests build-for-testing is warning-free; the iPad run of `DeepLinkPadUITests` passed (or its unrelated failure is recorded); one commit `test(15): read the idiom on the main actor`.</done>
</task>

<task type="auto" tdd="false">
  <name>Task 2: DEF-15-10 — forward the 43 shared string accessors to Xcode's generated symbols</name>
  <files>AppPackage/Sources/Resources/ResourceStringSymbols.swift</files>
  <action>
    Implement PD-2, PD-3, PD-4, PD-5 exactly.

    1. Read the two generated files named in `<reference>` (build output under DerivedData; read-only). Confirm the 43 member names and shapes match the hand-written layer; if any differ from the `<reference>` summary, follow the GENERATED file and note the difference in the SUMMARY.

    2. Rewrite `AppPackage/Sources/Resources/ResourceStringSymbols.swift`:
       - delete `private nonisolated let resourceStringSymbolsBundleDescription = LocalizedStringResource.BundleDescription.atURL(#bundle.bundleURL)`;
       - keep `import Foundation`, the `@available(...)` attribute, `public nonisolated extension LocalizedStringResource`, `enum RLocalizable`, `enum RConstant`, and every accessor's exact public signature and alphabetical order;
       - replace every body per PD-3: `{ .cancel }` for the 34 argument-less keys; `{ .days(count) }` / `{ .downloadStorePageMissing(page) }` for the 8 positional plural keys (labels `count:`/`page:` stay on the public signature); `{ .continuedSessionSubtitle(completed: completed, total: total, galleries: galleries) }` (own line); `{ Constant.responseGalleryUnavailable }` in `RConstant`;
       - formatting per PD-3: one line where the accessor fits in 120 columns, otherwise the body on its own line;
       - add the file-level WHY doc per PD-4 and rewrite the `continuedSessionSubtitle` doc per PD-4 (privacy + labels-from-substitutions reasoning kept; the ORDER paragraph and the inline-literal paragraph removed); no doc on the other 42 accessors.
       Read `.swiftlint.yml` first (120 columns; `sorted_imports`; no `swiftlint:disable`).

    3. Gates, in this order:
       a. `xcodebuild build -project EhPanda.xcodeproj -scheme Resources -destination 'generic/platform=iOS Simulator'` → `BUILD SUCCEEDED`, zero `warning:|error:` (fast inner loop; proves all 43 symbols resolve).
       b. Negative proof (PD-5): rename key `"cancel"` → `"cancel_renamed"` in `AppPackage/Sources/Resources/Resources/Localizable.xcstrings` (the top-level key string only), rebuild the `Resources` scheme, confirm `error: type 'LocalizedStringResource' has no member 'cancel'` pointing at the `RLocalizable.cancel` forwarder; then `git checkout -- AppPackage/Sources/Resources/Resources/Localizable.xcstrings`; rebuild green. Do NOT commit the rename. Record the observed error line (path:line:col + message) in the SUMMARY.
       c. `xcodebuild build -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator'` → warning-free.
       d. ONE full run: `cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` → `** TEST SUCCEEDED **`, 1020 tests, 0 failures (no count change — no test is added or removed).
       e. `git status --porcelain` shows only `AppPackage/Sources/Resources/ResourceStringSymbols.swift` modified.

    Commit: `refactor(15): forward shared string symbols`
  </action>
  <verify>
    <automated>cd "$(git rev-parse --show-toplevel)" && F=AppPackage/Sources/Resources/ResourceStringSymbols.swift && test "$(grep -c 'table: "' $F)" = "0" && test "$(grep -c 'defaultValue:' $F)" = "0" && test "$(grep -c 'resourceStringSymbolsBundleDescription' $F)" = "0" && test "$(grep -c '#bundle' $F)" = "0" && grep -q 'public static var cancel: LocalizedStringResource { .cancel }' $F && grep -q 'public static func days(count: Int) -> LocalizedStringResource { .days(count) }' $F && grep -q '.continuedSessionSubtitle(completed: completed, total: total, galleries: galleries)' $F && grep -q 'Constant.responseGalleryUnavailable' $F && test "$(grep -c 'public static' $F)" = "43" && git diff --quiet -- AppPackage/Sources/Resources/Resources AppPackage/Tests && xcodebuild build -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator' 2>&1 | tee /tmp/b.log | grep -E "BUILD SUCCEEDED|BUILD FAILED" && test "$(grep -E 'warning:|error:' /tmp/b.log | grep -viE 'note:' | wc -l | tr -d ' ')" = "0" && cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' 2>&1 | tee /tmp/t.log | grep -E "Test run with [0-9]+ tests|\*\* TEST (SUCCEEDED|FAILED)"</automated>
  </verify>
  <done>All 43 accessors forward to the generated symbols with their public signatures unchanged; no key literal, `table:`, `defaultValue:`, bundle description or `#bundle` remains in the file; the file-level WHY doc and the rewritten `continuedSessionSubtitle` doc are in place; the negative proof was observed and reverted; `Resources` and `AppFeature` builds warning-free; full suite `** TEST SUCCEEDED **` at 1020 tests; catalogs, consumers and tests untouched; one commit `refactor(15): forward shared string symbols`.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| catalog key → rendered UI text | A key that no longer exists must fail the build, not render its raw name on screen |
| build system → source | The forwarders depend on Xcode's generated symbols; the project is Xcode-only already (every module-local catalog relies on the same generation) |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-ovp-01 | Tampering (silent drift) | hand-typed key literals in `ResourceStringSymbols.swift` | medium | mitigate | Task 2: every body forwards to a compiler-resolved symbol; negative proof observed once (PD-5) |
| T-ovp-02 | Denial of Service (build) | a toolchain that does not generate string symbols | low | accept | the repository is Xcode-only already (`swift build` fails on host-platform deployment; module-local catalogs already depend on generated symbols); documented in the file-level doc |
| T-ovp-03 | Information Disclosure | `continued_session.subtitle` content on system UI | none | accept | unchanged: the key still accepts only integers; the privacy paragraph is kept in the rewritten doc |
| T-ovp-04 | Tampering | concurrency warning hiding a real cross-actor read | low | mitigate | Task 1: the read happens on the main actor by construction; no `nonisolated(unsafe)`, no `assumeIsolated` |
| T-ovp-SC | Tampering | npm/pip/cargo installs | low | accept | not applicable: Swift sources only, no package added |
</threat_model>

<verification>
- Both automated verify blocks pass in task order; Task 2 ends in ONE full `AppPackage-Package` run (never two concurrent `xcodebuild test`).
- The builds are warning-free (SwiftLint plugin): no `swiftlint:disable`, no lint-rule edits, no `.xcstrings` change committed.
- `git diff --quiet -- AppPackage/Sources/Resources/Resources AppPackage/Tests` holds (catalogs and tests untouched); no consumer file changes.
- No file under `AppPackage/`, `EhPandaUITests/` or `.planning/quick/260819-ovp-*/` contains an absolute home path or a local reference-project name.
- `git log --oneline -3` shows exactly the two commits named above (newest last): `test(15): read the idiom on the main actor`, `refactor(15): forward shared string symbols`; `deferred-items.md`, `STATE.md`, `ROADMAP.md` untouched.
</verification>

<success_criteria>
- DEF-15-04: the two `DeepLinkPadUITests.swift:9` warnings are gone from the UITests build; the pad test still runs on an iPad and still skips elsewhere.
- DEF-15-10: 43 forwarders, zero key literals, signatures unchanged; a bad key is a compile error (observed); the two `continued_session` value pins untouched; 1020 tests green; warning-free builds.
- Two commits; no docs artifacts committed by the executor.
</success_criteria>

<output>
Create `.planning/quick/260819-ovp-close-def-15-04-10-idiom-skip-forwarders/260819-ovp-SUMMARY.md` when done, `status: complete` in its frontmatter, listing per item: the commit SHA, the gate results (UITests build warning count, iPad single-test run outcome, `Resources`/`AppFeature` build results, the full-suite count), the PD-5 negative-proof error line as observed, and anything you had to deviate on. No absolute home paths (write `$HOME/…` for DerivedData paths); no local reference-project names.
</output>
