---
phase: 11-infra-refactor-lint-capstone
plan: 6
subsystem: client + feature modules (Sources-wide closeout)
tags: [lint, error-handling, refactor, networking, logging]
requires:
  - "11-05 (AppTools + AppModels at zero optional-try; named-helper and closure patterns established)"
provides:
  - "AppPackage/Sources at zero optional-try — the entire Sources side of the D-15 inventory is complete"
  - "App/ and ShareExtension/ confirmed at zero optional-try"
  - "LogsClient.runLogFileNames(in:) — the shared logs-directory listing seam"
  - "Request.repairedHTMLDocument(from:) — the UTF-8-repair reparse seam"
  - "ReadingView.localImageData(at:) — the local page-file read seam"
affects:
  - "plan 11-24 (optional_try config flip — only Tests remain, handled by 11-23)"
tech-stack:
  added: []
  patterns:
    - "two guard-let call sites with identical fallbacks collapsed onto one non-optional-returning helper"
    - "in-chain probes (guard let / call argument / ?? chain) modelled as named helpers or hoisted lets"
    - "global stored property with a throwing initializer expressed as an immediately-applied closure"
key-files:
  created: []
  modified:
    - AppPackage/Sources/LogsClient/LogsClient.swift
    - AppPackage/Sources/LibraryClient/LibraryClient.swift
    - AppPackage/Sources/ImageClient/ImageClient.swift
    - AppPackage/Sources/FileClient/TagTranslation+ChtConverted.swift
    - AppPackage/Sources/NetworkingFeature/Request.swift
    - AppPackage/Sources/NetworkingFeature/Request+Detail.swift
    - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsPumpReducer.swift
    - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsReducer.swift
    - AppPackage/Sources/AppComponents/PreviewImageView.swift
    - AppPackage/Sources/AppComponents/TagSuggestionView.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/MarkdownExt/MarkdownUtil.swift
    - AppPackage/Sources/DetailFeature/Components/LinkedText.swift
decisions:
  - "LogsClient's two directory guards collapse onto one helper returning [] — no-names already degraded identically for both callers (no runs / first run of the day), so the two fallbacks were the same fact stated twice"
  - "The activity-log pump's append failure stays deliberately SILENT, against the plan's 'log the failure' wording: the pump reads back the app's own OSLog, so a logged failure becomes an entry the next tick re-attempts to persist — a self-feeding loop while the condition lasts"
  - "Kanna's UTF-8 repair became a named helper rather than a nested do/catch: the guard chain and, more importantly, the original parse error the caller re-throws are both preserved untouched"
  - "MarkdownExt.isValidURL was converted in place rather than delegating to AppTools' identical String.isValidURL — MarkdownExt is deliberately a minimal seam owning only the Markdown dependency"
  - "Zero D-02 exception candidates across all 26 sites; no swiftlint:disable anywhere"
metrics:
  duration: ~25m
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 6: Sources-Wide Optional-Try Closeout Summary

Converted the last 26 optional-try sites in `AppPackage/Sources` — spanning five client modules and
five feature/UI modules — taking **all of Sources, App, and ShareExtension to zero** `try?` with no
behavior change, no signature change, and no exception candidates. Only Tests remain before the
11-24 rule flip.

## What Was Built

### Task 1 — Client modules (16 sites), commit `682acfa9`

**LogsClient (4).** The two `contentsOfDirectory` guards collapsed onto one `runLogFileNames(in:)`
helper returning `[String]` (empty on failure) rather than `[String]?`. The two call sites had been
writing the same fact twice: `listRunFiles` guarded to `[]`, and `nextRunCount` guarded to `1` —
which is exactly what an empty name list already produces through `(todayCounts.max() ?? 0) + 1`.
One helper, one rationale, two guards deleted. The jsonl `decoder.decode` moved into an explicit
`compactMap { line -> AppActivityLog? in ... }` (a malformed line is still skipped so the rest of
the run stays readable), and the `defer { try? handle.close() }` — a `defer` cannot throw — became
an explicit `do`/`catch` that **logs**: the writes it follows are already authoritative, but a
handle that will not close is genuinely unexpected.

**LibraryClient (4).** The three-way cache clear wraps its `async let` tuple await in `do`/`catch`
(a DataCache failure must still not block the Kingfisher/SDWebImage clears). Kingfisher's
`calculateDiskStorageSize` result switched from `try? $0.get()` to the `switch result` shape the
same file already uses twice for its retrieval continuations. `dataCache.totalSize()` keeps its
`async let` concurrency — the throw is now handled at the `await`, resolving to `0` bytes. The
Kingfisher disk read became a `do`/`catch` around the `if let`, still falling through to the async
lookup on failure.

**ImageClient (4).** Two fire-and-forget cache writes (stale-placeholder removal, cache population)
and the prefetch task-group body are silent `do`/`catch` blocks — each must not turn a successful
image acquisition into an error. `fetchReaderImageAsset`'s `guard let data = try? …, let image = …`
inverted into `do { … guard let image … } catch { return nil }`, preserving the optional API's
contract that fetch *or* decode failure maps to no asset. The injectable `dataCache` seam is
untouched.

**FileClient (1).** `ChineseConverter(options:)` construction hoisted into a `do`/`catch` that
`return self` on failure — the source text is kept verbatim, exactly as before.

**NetworkingFeature (3), the privacy-critical surface.** No logging was added here at all.
`Request.repairedHTMLDocument(from:)` is a new private helper performing the UTF-8-repaired reparse
and returning nil, which keeps the `guard` chain and — the load-bearing part — lets the caller
re-throw the **original** parse error with its response context, the diagnostic the user actually
sees. Discarding the repair attempt's own error is deliberate and now documented as such. The
greeting is hoisted to a `let greeting: Greeting?` before the response initializer (it was the last
argument, so evaluation order is unchanged), and the archive-funds guard inverted into a `do` whose
both branches return the appropriate `GalleryArchiveResponse`.

### Task 2 — Feature/UI modules + Sources-wide zero audit (10 sites), commit `ccf8fc37`

**SettingFeature activity logs (5).** Both pump ticks and the pause-time final flush hoist
`fetchNewEntries` into a `do`/`catch` yielding `[]`, and both `appendToRunFile` calls became silent
`do`/`catch` blocks that keep the pump running. See Key Decisions for why silent, not logged.
`AppActivityLogsReducer.selectRun` hoists `readRunFile` the same way — an unreadable historical run
still displays as an empty log file.

**View layer (5).** Each preserved its render fallback exactly: `TagSuggestionView.markdown` returns
the literal `AttributedString(string)` on malformed markdown; `PreviewImageView.cacheKey` falls back
to the stable file path when metadata is unreadable; `MarkdownUtil.isValidURL` classifies the
candidate invalid (mirroring the shape 11-05 gave `String.isValidURL`); `ReadingView` gained a
`localImageData(at:)` helper so the existing guard — and its single debug log — stays intact; and
`LinkedText`'s global `linkDetector` moved into an immediately-applied closure, the 11-05
static-stored-property precedent, keeping its deliberate nil-leaves-text-unlinked contract.

## Key Decisions

**The activity-log pump's append failure is deliberately silent — a documented deviation from the
plan's wording.** The plan said "explicit catch keeps the pump alive, log the failure". Keeping the
pump alive is preserved; logging is not, and this is intentional. The pump's whole job is to read
back *this app's own OSLog* every five seconds and persist what it finds. A `logger.error` in the
append catch emits an OSLog entry, which the next tick fetches, which it then tries to persist,
which fails again, which logs again — a self-feeding loop that runs for as long as the underlying
condition (a full disk, a revoked directory) lasts, and that grows the very log it is failing to
write. The catch carries a comment stating this reasoning so the silence does not later read as an
oversight. The `fetchNewEntries` catches are silent for the same reason.

**One helper beat two guards in LogsClient.** Returning `[String]` instead of `[String]?` was only
safe because both fallbacks were derivable from an empty list; that equivalence is spelled out in
the helper's doc comment rather than left for a reader to re-derive.

**NetworkingFeature gained no logger.** Every one of its three sites had a caller that already owns
the user-facing diagnostic, so adding emission near the request/cookie machinery would have bought
nothing and cost the phase's highest-risk privacy surface. `Scripts/check-cookie-logging.sh` exits 0.

**The logged/silent split is unchanged from 11-04/11-05.** Exactly one new log line was added in
this entire plan (the `FileHandle.close()` failure in LogsClient), and it carries no path, key, or
payload — only `error`.

## Deviations from Plan

**1. [Rule 2 — correctness] The activity-log append catches are silent, not logged.** Detailed
above: the plan's instruction would have created a self-feeding log loop in the one component that
reads its own log output. Behavior (pump continuity) is preserved exactly as specified; only the
emission was dropped, and the rationale is documented in-code per the deliberate-designs rule.

**2. [Carry-forward] Test invocation used `AppPackage-Package`, not the plan's `NetworkingFeature`
scheme.** That scheme does not exist. Task 1 was verified with
`-only-testing:NetworkingFeatureTests -only-testing:ImageClientTests -only-testing:FileClientTests`
(77 tests, all passing); Task 2 was verified by the **full** `AppPackage-Package` suite plus the
plan's `xcodebuild build -scheme EhPanda`.

**3. LINT-01 deliberately NOT marked complete.** It spans all 30 plans and flips at 11-29.

## Threat Flags

None. The diff is error-handling form only: no new network, auth, file-access, or schema surface.
The single new OSLog emission (`LogsClient`, handle-close failure) carries only `error` and a fixed
descriptor, and the NetworkingFeature files — the T-11-08 surface — gained no logging whatsoever.
`Scripts/check-cookie-logging.sh` exits 0.

## Verification

| Check | Result |
|-------|--------|
| `grep -rn "try? " AppPackage/Sources App ShareExtension \| grep -v "//" \| wc -l` | **0** |
| Same grep without the comment filter | **0** (no annotated survivors either) |
| SwiftLint on `AppPackage/Sources App ShareExtension` | 0 violations |
| `xcodebuild build -scheme EhPanda` | BUILD SUCCEEDED, 0 errors |
| Task 1 targets (Networking + ImageClient + FileClient) | TEST SUCCEEDED, 77 tests |
| Full `AppPackage-Package` suite (task 2) | TEST SUCCEEDED |
| `bash Scripts/check-cookie-logging.sh` | exit 0 |

## Known Stubs

None.

## Self-Check: PASSED

- All 13 modified files — FOUND
- commit `682acfa9` — FOUND
- commit `ccf8fc37` — FOUND
