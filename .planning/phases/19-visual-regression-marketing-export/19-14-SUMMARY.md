---
phase: 19-visual-regression-marketing-export
plan: "14"
subsystem: testing
tags: [live-check, parser, classification, xctest, python]

requires:
  - phase: 19-03
    provides: "LiveCheckTests (guard-free, opt-in), LiveCheckGate, PageObserver and the GET-only session"
provides:
  - "`LiveCheckPage`, `LiveCheckReader` (the GET-only allowlist), `LiveCheckExpectation` (fixed IDs and sentences)"
  - "`LiveCheckResults`: `results.json` schema 1 with enum-only page fields"
  - "`LiveCheckRunner.run(mode:)` and the pure `LiveCheckClassifier`"
  - "`DailyLiveCheckTests.testLivePages`, `LiveCheckOfflineTests` (11 tests) and the fixture pages"
  - "`Scripts/live-check/test_request_allowlist.py`; environment variable `EHPANDA_LIVE_CHECK_MODE`"
affects: [19-15, 19-16]

actuals:
  tokens: 120000
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "A page's observation is the final response of the last task its session created, read from the task when it finishes"
    - "Offline tests serve saved pages through a URL protocol inside the page's own session"

key-files:
  created:
    - AppPackage/Tests/LiveCheckTests/LiveCheckPage.swift
    - AppPackage/Tests/LiveCheckTests/LiveCheckExpectation.swift
    - AppPackage/Tests/LiveCheckTests/LiveCheckResults.swift
    - AppPackage/Tests/LiveCheckTests/LiveCheckRunner.swift
    - AppPackage/Tests/LiveCheckTests/DailyLiveCheckTests.swift
    - AppPackage/Tests/LiveCheckTests/LiveCheckOfflineTests.swift
    - AppPackage/Tests/LiveCheckTests/Fixtures/toplists.html
    - AppPackage/Tests/LiveCheckTests/Fixtures/toplists-changed.html
    - AppPackage/Tests/LiveCheckTests/Fixtures/challenge.html
    - AppPackage/Tests/LiveCheckTests/Fixtures/ip-banned.html
    - Scripts/live-check/test_request_allowlist.py
  modified:
    - AppPackage/Package.swift
    - AppPackage/Tests/LiveCheckTests/PageObservation.swift
    - AppPackage/Tests/LiveCheckTests/ProbeReportTests.swift

key-decisions:
  - "The four list pages (front page, search, Popular, Toplists) are read with the app's list URLs and `Parser.parseGalleries` over a plain GET, not through `FrontPageGalleriesRequest`, `SearchGalleriesRequest`, `PopularGalleriesRequest` or `ToplistsGalleriesRequest`: those also POST the gallery API's title query (D-21). The Python allowlist test finds these posting types from the sources and proves none is allowed."
  - "The allowlist: `GalleryDetailRequest`, `ThumbnailURLsRequest` then `GalleryNormalImageURLsRequest` (reader), `DataRequest` (image, decoded in memory and discarded), `TagTranslatorRequest`, `ReportFormRequest` (the gallery's `?report=other` page, read and never sent)."
  - "The gallery is the first Toplists (yesterday) row. A dependent page without its input follows the earlier page: `unreachable` after a block, `parser` with `dependency.earlierPage` after a break, never `ok`."
  - "`unreachable`: a 403 with `cf-mitigated`, `ipBanned`, `networkingFailed` or `cloudflareChallengeFailed` after the read's own attempts, a 5xx, any other non-2xx or no response, with no expectation. `parser`: a 2xx page the parser rejects or that misses an expectation."
  - "The search keyword is the fixed neutral word in `LiveCheckPage.searchKeyword`, never logged."

patterns-established:
  - "Classification is a pure function of (observation, outcome), so the offline tests drive it with saved pages"

requirements-completed: []

coverage:
  - id: D1
    description: "GET-only by construction and by test; fixed vocabulary; enum-only results"
    requirement: VIS-19-01
    verification:
      - kind: unit
        ref: "python3 -m unittest discover -s Scripts/live-check -p 'test_*.py' (11 tests, OK)"
        status: pass
      - kind: unit
        ref: "LiveCheckOfflineTests vocabulary and schema tests (4) on $PHONE"
        status: pass
    human_judgment: false
  - id: D2
    description: "A break and a block told apart offline"
    requirement: VIS-19-01
    verification:
      - kind: unit
        ref: "LiveCheckOfflineTests classification tests (7) on $PHONE: 11 / 11 passed; the whole LiveCheck plan without the opt-in: 17 executed, 6 skipped, 0 failures"
        status: pass
    human_judgment: false
  - id: D3
    description: "One local live run end to end"
    requirement: VIS-19-01
    verification:
      - kind: integration
        ref: "DailyLiveCheckTests, mode local, 2026-11-08 03:04 UTC: nine guest pages 200 ok, three skipped; results.json has only the four fields; no site URL in the console log"
        status: pass
    human_judgment: false

duration: two sessions
completed: 2026-11-08
status: complete
---

# Phase 19 Plan 14: Daily live-parsing check pages, classification and results Summary

**The daily check reads the nine guest pages the app reads, as a guest and with GET only, through the app's own
request types and parsers, and classifies each page `ok`, `unreachable` or `parser` without writing anything read from
a page. Offline tests tell a break from a block on saved pages. One local run found all nine guest pages `ok`.**

## Performance

- **Tasks:** 3
- **Files:** 11 created, 3 modified

## Accomplishments

- **Vocabulary, schema and allowlist** (Task 1). `LiveCheckPage` (twelve pages, nine guest and three signed-in, which
  are `skipped` while there is no sign-in secret, D-24), `LiveCheckReader` (the allowlist), `LiveCheckExpectation`
  (twelve IDs, each with one literal English sentence, for example `toplists.rows`: "expected a gallery table with at
  least one row, found none") and `LiveCheckResults` (`{schema: 1, date, mode, pages: [{page, status, classification,
  expectation}]}`, every page field but the status an enum). `test_request_allowlist.py` fails on any request type
  outside the allowlist, a POST literal, or an allowlisted type that posts.
- **Runner and classification** (Task 2). `LiveCheckRunner.run(mode:)` reads front page, search, Popular, Toplists,
  gallery, reader, reader image, tag suggestions and Report form, in that order, 5 s apart, each on a fresh
  cookieless GET-only session: about ten GETs per run when nothing is retried. `LiveCheckClassifier` is pure. The offline tests serve the
  fixture pages through `SavedPageProtocol` inside each session.
- **The live test and one local run** (Task 3). `DailyLiveCheckTests.testLivePages` writes `results.json` and passes
  whenever it was written; 19-15's reporter judges it.

**Local run** (`$PHONE`, mode `local`, 2026-11-08 03:04 UTC, 47 s):

| Page | Status | Classification |
|------|--------|----------------|
| frontPage | 200 | ok |
| search | 200 | ok |
| popular | 200 | ok |
| toplists | 200 | ok |
| gallery | 200 | ok |
| reader | 200 | ok |
| readerImage | 200 | ok |
| tagSuggestions | 200 | ok |
| reportForm | 200 | ok |
| watched, favorites, exhentai | — | skipped |

No `parser` result, so no parser break to report.

- **Verification:**
  - `python3 -m unittest discover -s Scripts/live-check -p 'test_*.py'`: 11 tests, OK.
  - `LiveCheckOfflineTests` on `$PHONE`: 11 executed, 0 failures, without the opt-in. The whole `LiveCheck` plan
    without the opt-in: 17 executed, 6 skipped (the four `ProbeReportTests`, the probe and the daily check),
    0 failures.
  - SwiftLint (strict, no cache) on `AppPackage/Tests/LiveCheckTests`: 0 violations.
  - `grep -rn 'httpMethod = "POST"\|SendReportRequest\|GalleryMPVImageURLRequest' AppPackage/Tests/LiveCheckTests`
    prints nothing.
  - The live run's console log has no site URL; its only URLs are the package resolution lines.

## Task Commits

1. **Task 1: Pages, expectations, results schema and the allowlist** - `ae782749c` (test)
2. **Task 2: Runner and classification** - `6d07e02d2` (test)
3. **Task 3: The live test and one local run** - `b8c7c3c6c` (test)

## Decisions Made

See `key-decisions`.

## Deviations from Plan

1. **The list pages do not use their request types** (`FrontPageGalleriesRequest`, `SearchGalleriesRequest` and the
   Popular and Toplists types, which the plan names for the front page). Each also POSTs the gallery API's title
   query, which the plan's GET-only rule (D-21) forbids. They use the app's list URLs and list parser over a plain
   GET, retried up to four times as the request types do. The same choice as 19-03's probe.
2. **`PageObservation.swift` changed (a 19-03 file).** The observer took the status only from the task metrics, which
   have no transaction for a response served by a URL protocol, so every offline page read had no status. It now
   records each task's final response from the task when the task finishes, keyed by task, and the runner waits up
   to two seconds until every task the session created has finished. `GetOnlyURLProtocol` also counts its
   refusals, so a test can require that a run refused none. The probe (`RunnerProbeTests`) still reads the
   observation without the wait; that is how its hosted and local runs were made.
3. **`ProbeReportTests` (a 19-03 file):** the refusal test sends a PUT instead of a POST, so the plan's grep for a
   POST literal prints nothing. It still proves that anything but GET is refused.
4. **"Building each request offline gives GET" is proved by a run, not request by request.** The allowlist names are
   checked in Swift and the posting types are found in Python; `testRunSendsOnlyGetAndReportsEveryPageOnce` runs the
   whole check offline, records every request's method (only GET) and requires that the GET-only session refused
   nothing.
5. **Fixture pages** are one good and one changed Toplists page, one challenge and one ban page. The classification
   code is the same for every page, so the other pages have no fixtures of their own. The good page is the
   repository's `ToplistsCompactList.html` trimmed to two rows, with synthetic titles, IDs, tags, uploader and image
   addresses. A hand-written first version did not parse.

## Issues Encountered

- `ProbeReportTests` (19-03) skip without the opt-in, although they make no request; they run in the hosted probe and
  in any opted-in run.
- One run is one sample: the site may change, or block a runner, on any day. Watching that is the job of the daily
  schedule (19-15, 19-16).

## User Setup Required

None.

## Next Phase Readiness

- 19-15 can run `DailyLiveCheckTests` with `EHPANDA_LIVE_CHECK_MODE=hosted` on the hosted runner (19-03 verdict
  reachable) and judge `results.json`.
- VIS-19-01 stays Pending (19-15 and 19-16 share it).
