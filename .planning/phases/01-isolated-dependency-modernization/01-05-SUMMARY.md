---
phase: 01-isolated-dependency-modernization
plan: 05
subsystem: markdown
tags: [swift-markdown, markdown, tag-translation, dep-03, dependency-reduction, supply-chain, xcodebuild]

# Dependency graph
requires:
  - Wave 0 markdown parity fixtures (MarkdownExtTests, TagTranslationFeatureTests) locked on CommonMarkExt (01-02)
  - Corrected AppPackage-Package test command + confirmed simulator (01-01)
provides:
  - MarkdownExt local helper module owning all swift-markdown usage
  - swift-markdown (product Markdown) as the DEP-03 parser, replacing SwiftCommonMark
  - TagTranslationFeature consuming MarkdownExt with an unchanged computed-property surface
  - DetailFeature with no direct parser-package dependency (D-08)
affects: [01-06, 01-07, isolated-dependency-modernization]

# Tech tracking
tech-stack:
  added:
    - "apple/swift-markdown 0.8.0 (product Markdown; SHA 3c6f9523da3a1ec2fd829673e472d95b8097a3b8)"
    - "swiftlang/swift-cmark 0.8.0 (transitive backing of swift-markdown)"
  removed:
    - "gonzalezreal/SwiftCommonMark 1.0.0 (product CommonMark)"
  patterns:
    - "Parser dependency hidden behind a single *Ext helper module; feature modules never import the parser or touch node types (D-08/D-09)"
    - "Preserve paragraph-scoped, top-level-inline traversal by walking Document.children explicitly instead of a full-descent MarkupWalker (D-07)"
    - "Migrate a dependency boundary in three atomic commits: add-new -> retarget-consumers -> remove-old, each independently buildable"

key-files:
  created:
    - AppPackage/Sources/MarkdownExt/MarkdownUtil.swift
    - AppPackage/Sources/MarkdownExt/.swiftlint.yml
  modified:
    - AppPackage/Package.swift
    - AppPackage/Package.resolved
    - EhPanda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
    - AppPackage/Sources/TagTranslationFeature/TagTranslation+Markdown.swift
    - AppPackage/Sources/DetailFeature/DetailView.swift
    - AppPackage/Tests/MarkdownExtTests/MarkdownUtilParityTests.swift
  deleted:
    - AppPackage/Sources/CommonMarkExt/MarkdownUtil.swift
    - AppPackage/Sources/CommonMarkExt/.swiftlint.yml

key-decisions:
  - "Recorded the swift-markdown remote as https://github.com/apple/swift-markdown per the explicit supply-chain instruction; apple/ redirects to the canonical swiftlang/swift-markdown and both resolve to the identical tag-0.8.0 SHA 3c6f9523, so the RESEARCH.md swiftlang reference and the prompt's apple reference are the same official package."
  - "Replicated the two intentional MarkdownUtil limitations (paragraph-only blocks, top-level-.text-only inlines) rather than adopting swift-markdown's natural full-tree descent, keeping the Wave 0 fixtures green unchanged (D-07)."
  - "Dropped the old CasePaths retroactive Block/Inline conformances entirely; swift-markdown's class-based Markup nodes support plain as? downcasting, so no adapter was needed (per the plan's guidance)."
  - "Removed the unused direct CommonMark import from DetailView and the unused .commonMark product from detailFeature and appFeature targets; AppFeature reaches MarkdownExt transitively through TagTranslationFeature (D-08)."

requirements-completed: [DEP-03]

# Metrics
duration: 7min
completed: 2026-07-10
status: complete
---

# Phase 01 Plan 05: swift-markdown Migration Behind MarkdownExt Summary

**Migrated the markdown parsing seam from SwiftCommonMark to Apple `swift-markdown` (product `Markdown`) behind a new local `MarkdownExt` helper module, keeping `TagTranslation` and `DetailFeature` behavior fixture-identical and removing SwiftCommonMark/CommonMarkExt from the dependency graph (DEP-03).**

## Performance

- **Duration:** ~7 min
- **Tasks:** 3 (one atomic commit each)
- **Files:** 10 (2 created, 6 modified, 2 deleted)

## Accomplishments

- Added Apple `swift-markdown` 0.8.0 (product `Markdown`, SHA `3c6f9523`) and its transitive `swiftlang/swift-cmark` 0.8.0; verified both `Package.resolved` files pin it and no longer resolve SwiftCommonMark.
- Created `MarkdownExt` — a local helper module that is the sole owner of the swift-markdown dependency, with a parent-linked `.swiftlint.yml` (D-08/D-09).
- Reimplemented `MarkdownUtil.parseTexts`/`parseLinks`/`parseImages` on `Markdown.Document`, preserving the exact paragraph-scoped, top-level-inline traversal and the full-string image-URL validation (T-01-05-01) — all 11 `MarkdownExtTests` and 6 `TagTranslationFeatureTests` pass unchanged against the new parser.
- Retargeted `TagTranslationFeature` from `CommonMarkExt` to `MarkdownExt` without changing its public computed-property surface; removed the unused direct `CommonMark` import from `DetailView` and the unused `.commonMark` product from the `detailFeature` and `appFeature` targets.
- Removed SwiftCommonMark, the `.commonMark` product helper, the `.commonMarkExt` module/target, and deleted the `CommonMarkExt` source (including its `CasePaths` retroactive conformance, which swift-markdown does not need).
- Full package build succeeded and the complete package test suite is green.

## Task Commits

1. **Task 1: Add MarkdownExt backed by swift-markdown** — `84fc1496` (feat)
2. **Task 2: Route markdown through MarkdownExt (retarget TagTranslation/Detail)** — `154dcc82` (refactor)
3. **Task 3: Remove SwiftCommonMark and CommonMarkExt** — `1c5af71a` (chore)

Plan metadata: final `docs(01-05)` commit.

## Verification

- `MarkdownExtTests` (11): pass against `MarkdownExt` (Task 1 and after each later task).
- `MarkdownExtTests` + `TagTranslationFeatureTests` + `DetailFeatureTests`: pass (Tasks 2 and 3).
- Full package `build`: `** BUILD SUCCEEDED **` (Task 3).
- Full package `test`: `** TEST SUCCEEDED **` (after-wave sampling; the Network Error / Igneous / Login log lines are the expected deterministic offline-download test output, per 01-02).
- Command correction applied throughout: ran the `AppPackage-Package` scheme without `-testPlan FeatureTests`, selecting targets with `-only-testing:` (see Deviations).

## Decisions Made

- **swift-markdown remote reconciliation:** The prompt's supply-chain note names `https://github.com/apple/swift-markdown`; `RESEARCH.md` verified `https://github.com/swiftlang/swift-markdown`. `git ls-remote` confirms both point to the same repository — tag `0.8.0` resolves to the identical commit `3c6f9523da3a1ec2fd829673e472d95b8097a3b8` on both, and `apple/` redirects to `swiftlang/` (the Swift project moved its repos to the `swiftlang` org). I recorded the URL the prompt explicitly instructed (`apple/swift-markdown`); it is the same official Apple/swiftlang package, not a fork or mirror.
- **Parity over the parser's natural behavior (D-07):** swift-markdown's `MarkupWalker` descends the whole tree, which would collect text nested in strong/emphasis and merge runs differently. To keep the locked fixtures exact, `MarkdownExt.MarkdownUtil` walks `Document.children`, keeps only top-level `Paragraph` blocks, and collects only their direct inline children — mirroring the prior `[case: \.paragraph]` / `[case: \.text]` semantics. Headings and nested inline text remain intentionally excluded.
- **No CasePaths adapter:** The old `CommonMarkExt` needed a large retroactive `CasePathable`/`CasePathIterable` conformance for SwiftCommonMark's enum nodes. swift-markdown's nodes are concrete `Markup` types, so plain `as?` downcasting suffices; the adapter code was not carried over.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Dropped the invalid `-testPlan FeatureTests` flag from the plan's verify commands**
- **Found during:** Tasks 1-3 (running the embedded verify commands).
- **Issue:** The plan's `<verify>` blocks embed `-scheme AppPackage-Package -testPlan FeatureTests`, which fails — the `FeatureTests` test plan is bound to the app's shared `EhPanda` scheme, not the SwiftPM `AppPackage-Package` scheme (the correction 01-01/01-02 already recorded in `01-VALIDATION.md` and pre-flagged in the executor prompt).
- **Fix:** Ran `AppPackage-Package` without `-testPlan` (it already includes every package test target) and used `-only-testing:` filters. No source impact.
- **Verification:** targeted runs EXIT 0; full build and full suite green.
- **Committed in:** covered by `84fc1496` / `154dcc82` / `1c5af71a` (command-only change).

**2. [Rule 3 - Process] Task 3 amended to a single atomic commit**
- **Found during:** Task 3 commit.
- **Issue:** The first `git add` for Task 3 listed the already-`git rm`'d `CommonMarkExt` paths; git aborted the whole `add` on the missing pathspec, so the initial commit captured only the file deletions and left the `Package.swift`/`Package.resolved` edits unstaged — a non-building intermediate (manifest still referencing the deleted module in committed form).
- **Fix:** Staged the manifest changes and `git commit --amend` so Task 3 is one atomic, buildable commit (`1c5af71a`) containing all five files. Verified the full package build and suite against this exact tree.
- **Files modified:** none beyond the planned Task 3 set.

### Out-of-Scope (Deferred, not fixed)

**Acknowledgements still credit SwiftCommonMark, not swift-markdown.**
- `AboutView.swift` and `Constant.xcstrings` still list SwiftCommonMark. Task 3 explicitly scopes attribution/resource changes out unless the build requires them, and removing the package does not break `AboutView` (it references localized strings, not the package symbol). Logged to `deferred-items.md` for a later acknowledgements pass that must honor the `.xcstrings` all-locale rule. No functional impact.

**Total deviations:** 2 auto-fixed (both blocking/process; command correction + commit-atomicity), plus 1 deferred out-of-scope attribution item.
**Impact on plan:** No scope creep. Markdown parsing behavior is preserved exactly; the parser dependency is now hidden behind `MarkdownExt` and SwiftCommonMark is gone.

## Known Stubs

None. No placeholder/empty-data paths were introduced; `MarkdownExt.MarkdownUtil` is fully wired to the real swift-markdown parser and all consuming `TagTranslation` properties resolve against live parsing.

## Issues Encountered

- The first build resolved swift-markdown + swift-cmark from the network (~26 s clean); incremental builds are ~19 s and pure test execution is sub-second. One `xcodebuild` invocation ran at a time and each was allowed to finish — no `testmanagerd` wedge.

## User Setup Required

None — no external service configuration required. Package resolution used the public Apple/swiftlang Git remote.

## Next Phase Readiness

- DEP-03 is complete: SwiftCommonMark/CommonMarkExt are removed and swift-markdown is exposed only through `MarkdownExt`.
- 01-06 / 01-07 can proceed; the shared parser helper change was validated by a full-suite green run.
- A future acknowledgements pass should update credits for the removed packages (see `deferred-items.md`).

## Self-Check: PASSED

- Created files present: `AppPackage/Sources/MarkdownExt/MarkdownUtil.swift`, `AppPackage/Sources/MarkdownExt/.swiftlint.yml`.
- Deleted files absent: `AppPackage/Sources/CommonMarkExt/` removed.
- Commits present: `84fc1496`, `154dcc82`, `1c5af71a`.
- `Package.resolved` (both) pin swift-markdown 0.8.0 and contain no SwiftCommonMark.

---
*Phase: 01-isolated-dependency-modernization*
*Completed: 2026-07-10*
