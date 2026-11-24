---
phase: 19-visual-regression-marketing-export
plan: "21"
subsystem: ui
tags: [clipped-content, search-terms-field, activity-logs-title, report-form, hosted-tests]

requires:
  - phase: 19-30
    provides: "the stillness steps (`still:`) that run at screen size before the window grows, used by the word-editor capture and re-measure"
provides:
  - "C1: the saved-search editor's Search Terms field is a vertical-axis `TextField` (`.lineLimit(3...)`) that grows with its text; `SavedSearchEditorLayoutTests`"
  - "C2: the App Activity Logs reveal cover is keyed to loading, so the empty loaded page keeps its large title; `ActivityLogsTitleTests`"
  - "C11: the Report form's centred states are a private `CentredState` with the visible height as a floor, so the Sent message scrolls instead of truncating; `ReportFormCentredStateTests`"
  - "Re-measures of the two Quick Search states handed to this plan (findings for 19-26)"
affects: [19-26, 19-12]

actuals:
  tokens: 13500
  tasks: 3
  commits: 3

plan_head_before: 2220c865931652e552b1666406b27294a3a1e7b2
plan_head_after: 0dd2e8935dfd34dc34bcd85eaf4c5a8ebe92f8ea

key-files:
  created:
    - AppPackage/Tests/HostedViewTests/SavedSearchEditorLayoutTests.swift
    - AppPackage/Tests/HostedViewTests/ActivityLogsTitleTests.swift
    - AppPackage/Tests/HostedViewTests/ReportFormCentredStateTests.swift
  modified:
    - AppPackage/Sources/QuickSearchFeature/QuickSearchView.swift
    - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift
    - AppPackage/Sources/DetailFeature/Moderation/ReportFormView.swift

key-decisions:
  - "Return in the Search Terms field inserts a line break; it does not submit (measured), so nothing was kept or changed for it."
  - "The reveal cover hides content only while a run's logs load; an empty, loaded page shows its title and its empty message."
  - "A centred state's visible height is a floor for its content, read from the scroll geometry's container size, which already excludes the content insets."
  - "The centring check is differential (two window heights) because the Sent block's accessibility frame is biased against its layout frame by a constant."

requirements-completed: [VIS-18-01]
status: complete
---

# Phase 19 Plan 21: Clipped content (C1, C2, C11) Summary

**The Search Terms field grows with its text, the empty Activity Logs page keeps its large title, and the Report form's centred states scroll instead of truncating the Sent message at AX5 landscape; each fix is one signed commit with a hosted test that failed before the fix and passes after it.**

All local runs of this plan (the RED and GREEN test runs, the picture checks and the re-measures) ran on the iOS 27.2 simulator runtime (owner decision 2026-11-24, after the iOS 27.0 runtime was removed from the host). Every measured need below is therefore a 27.2 value. Strict SwiftLint ran from the standalone binary 0.65.1, unpacked from the SPM artifact zip (the artifact the build plugin uses).

## Accomplishments

- **Task 1, C1** (`240e2ffdb`): in `EditSavedSearchView` the Search Terms `TextEditor` became `TextField(text: $savedSearch.content, axis: .vertical) { Text(.searchTerms) }` with `.lineLimit(3...)`, keeping `.autocorrectionDisabled(true)`, `.textInputAutocapitalization(.never)` and `.focused(focusedField, equals: .content)`, with a comment on why. `SavedSearchEditorLayoutTests` (390 x 844, `.large` and `.accessibility5`, a query of several lines) asserts the field's text view is never shorter than the height its text needs (`sizeThatFits`).
- **Task 2, C2** (`a225c5945`): `AppActivityLogsView` now reveals with `.revealed(store.loadingState != .loading || !store.displayedLogs.isEmpty)`, with a comment on `revealed(_:)`'s contract. `ActivityLogsTitleTests` renders the page (390 x 844, `.large`, no logs) and counts the colours inside the title element's frame, and checks the loading view exists while loading.
- **Task 3, C11** (`0dd2e8935`): `centred { ... }` builds a private `CentredState` that owns `@State visibleHeight`, keeps the grouped-background `ZStack`, the `ScrollView` with `.scrollBounceBehavior(.basedOnSize)` and `.scrollEdgeEffectStyle(.soft, for: [.top, .bottom])`, gives its content `.frame(maxWidth: .infinity, minHeight: visibleHeight)` and reads the height with `.onScrollGeometryChange`. `ReportFormCentredStateTests` covers the AX5 landscape scroll case and the differential centring case.

## RED and GREEN evidence

| Task | RED (before the fix) | GREEN (after) |
| --- | --- | --- |
| C1 | `Failed 19 1`; both cases of `searchTermsFieldIsNeverShorterThanItsText(size:)` failed on the assertion: at `.large` "text view is 22.0 pt tall but its text needs 148.0 pt", at `.accessibility5` "35.67 pt tall but its text needs 1009.3 pt" | `** TEST SUCCEEDED **`, `Passed 19 0` (the new test and all of `SearchFeatureTests`) |
| C2 | `Failed 8 1`; `anEmptyLoadedPageDrawsItsTitle` failed: "The title's frame (16.0, 125.7, 277.7, 40.7) holds 1 colour(s); the title is not drawn"; the loading case passed | `** TEST SUCCEEDED **`, `Passed 8 0` |
| C11 | `Failed 33 1`; `theSentMessageScrollsWhenItDoesNotFit` failed: "The content is 200.67 pt tall in 200.67 pt of room" (pinned to the container height); the centring case passed on the old code, which centred too | `** TEST SUCCEEDED **`, `Passed 33 0` (the new tests and `ReportFormReducerTests`) |

Each verify ran as written (the plan's xcodebuild command, through a wrapper that also logs it) on the project iPhone. The evidence is in `$W` (the worktree's ignored `.capture/agent-work/phase19-21`): `c1-red`, `c1`, `c2-red`, `c2-diag-keep`, `c2`, `c11-red-final`, `c11` (`.xcresult` and logs).

C2 diagnosis (plan step 2): with the view's `revealed` argument temporarily set to `true` in the working tree, `ActivityLogsTitleTests` passed (`Passed 2 0`, `c2-diag-keep.xcresult`), so the reveal cover is the cause; the line was then restored and fixed as planned.

Acceptance: `grep -v '^ *//' QuickSearchView.swift | grep -c 'TextEditor('` prints 0; `grep -c 'revealed(!store.displayedLogs.isEmpty)'` prints 0; `grep -c 'containerRelativeFrame(.vertical) { length, _ in length }'` prints 0; the Snapshots `heights:` diff counts 0; strict lint of `QuickSearchFeature`, `SettingFeature`, `DetailFeature` and `HostedViewTests`, each from its own directory, prints nothing.

## Picture checks (iOS 27.2)

- **Word editor** (`QuickSearchSnapshotTests/testWordEditor`, `en-large`, `$W/c1-capture`): the run reports `error=4`, all four the expected `page-height` errors (portrait needs 944 pt, committed 912; landscape needs 709 pt, committed 420). The stillness step (`still: LibraryScenarios.holdCaret`) reached the field. The portrait and landscape pictures show the Search Terms field at its three-line minimum with its text; nothing is cut.
- **Activity Logs empty** (`SettingsPagesSnapshotTests/testActivityLogsEmpty`, `en-large`, `$W/c2-capture`): `recorded=4 error=0`. The portrait light and dark pictures show the "App Activity Logs" large title, the search field and "No Logs Found".
- **Report Sent** (`ReportFormSnapshotTests/testSent`, `en-accessibility5`, `$W/c11-capture`): the run reports `error=4`, all `page-height` (portrait needs 4548 pt, committed 912; landscape needs 2448 pt, committed 420), as the plan allows. The landscape picture shows "Report Sent" and the message wrapped over two lines (not cut to one) with the content scrolled to its top; the Done bar overlays the lower part at the 420 pt picture height. The portrait picture shows the whole message centred. The full-page height is 19-26's.

## Re-measures of the Quick Search states (19-26 findings, iOS 27.2)

One measuring run per device after the C1 fix, nothing else in the tree changed (`--measure-heights`, `en-large`; `$W/c1-measure-phone`, `$W/c1-measure-pad`). No line is `error` or `cannot-cover:keyboard`, so no stop condition applied; no `heights:` value was changed.

| key | status | need (pt) | steps | reason | converges now? |
| --- | --- | --- | --- | --- | --- |
| `quick-search-delete-confirmation__en__large__portrait__iphone__light` | cannot-cover | 1008 | 2 | `cannot-cover:popover` | no longer did-not-converge; a popover whose source lies outside the scene (screen 912) |
| `quick-search-delete-confirmation__en__large__portrait__iphone__dark` | cannot-cover | 1008 | 2 | `cannot-cover:popover` | same |
| `quick-search-delete-confirmation__en__large__landscape__iphone__light` | cannot-cover | 741 | 1 | `cannot-cover:popover` | same (screen 420) |
| `quick-search-delete-confirmation__en__large__landscape__iphone__dark` | cannot-cover | 741 | 1 | `cannot-cover:popover` | same |
| `quick-search-word-editor__en__large__portrait__iphone__light` | did-not-converge | 1328 | 12 | none | no |
| `quick-search-word-editor__en__large__portrait__iphone__dark` | did-not-converge | 1328 | 12 | none | no |
| `quick-search-word-editor__en__large__landscape__iphone__light` | did-not-converge | 1093 | 12 | none | no |
| `quick-search-word-editor__en__large__landscape__iphone__dark` | did-not-converge | 1093 | 12 | none | no |
| `quick-search-delete-confirmation__en__large__portrait__ipad__light` | did-not-converge | 1626 | 12 | none | no (screen 1210) |
| `quick-search-delete-confirmation__en__large__portrait__ipad__dark` | did-not-converge | 1626 | 12 | none | no (screen 1210) |

Findings for 19-26:

- **The word editor's growth does not come from the Search Terms field.** Its needs (1328 pt portrait, 1093 pt landscape, 12 steps) are identical to 19-30's pre-fix values, so C1 did not change them. Its step sequence is `make(.wordEditor)` then `still: LibraryScenarios.holdCaret` (an 800 ms wait, then `freezeIndicators`), with no `interact` step; the measurer then grew the window 12 times without the need holding still. It stays a finding for 19-26; no diagnosis was attempted (that would have needed harness instrumentation).
- **The delete confirmation moved on the iPhone** from `did-not-converge` (needs 1328 / 1093 pt) to `cannot-cover:popover` (needs 1008 / 741 pt), so its measurement now ends in a named class rather than growing without bound. On the iPad portrait it still does not converge, need 1626 pt, the same as 19-30.

## Findings the plan asked for

- **Return key in the Search Terms field:** it inserts a line break and does not submit. A temporary probe focused the field and inserted `"\n"`: the text became `"abc\n"` and the submit action fired 0 times. This matches the old `TextEditor`, so the plan's "keep a submit" branch did not apply and nothing was changed for it.
- **Activity Logs loading state:** while a previous run loads with no logs on screen, the title is hidden. The probe (first case rendered with `.loading`, same colour count) found 1 colour inside the title frame, because the cover is up during loading (`revealed` is `false` then). This is not part of the fix and is left for the orchestrator.

## Deviations from Plan

1. **The AX-error first attempt of the iPad re-measure, with one approved retry** (orchestrator decision). The first iPad `--measure-heights` run stopped before measuring: `VisualCaptureOrientationUITests.testRotateToPortrait` failed with `Failed to get list of active applications: Accessibility error Unknown kAXError value -25218`, 0.9 s after the orientation was set, the first UI test on a freshly created simulator. The runner printed `Could not turn the iPad`. The orchestrator approved exactly one retry of the device turn; it got through and produced the two iPad lines above. The failed log is kept in `$W/c1-measure-pad-ax-error/`.
2. **The `visibleHeight` formula, corrected** (orchestrator-approved deviation from the plan's text). The plan reads the height as `$0.containerSize.height - $0.contentInsets.top - $0.contentInsets.bottom`. With that formula the 420 x 912 fit case gave a content of 559.33 pt in 735.67 pt of room, short by 176.33 pt, which equals the adjusted insets (top 68 + bottom 108.33): 735.67 + 68 + 108.33 = 912. `ScrollGeometry.containerSize` already excludes those insets, so the plan's formula subtracted them twice. The code uses `$0.containerSize.height` alone, and the `visibleHeight` doc comment says the geometry's container size already excludes the content insets.
3. **The centring check is differential** (orchestrator-approved change to the plan's wording "centred vertically within one point"). With the fixed formula the content height matched (735.67 pt), but the `report_sent` accessibility frame's middle sat 2.75 pt (2.83 pt on the old code) below the content's middle (370.67 pt against 735.67 / 2 = 367.83 pt). A probe showed why: the checkmark symbol's layout box is taller than its accessibility frame, so the Sent block's frame is 138.0 pt tall against a 144.0 pt layout height (`UIHostingController.sizeThatFits` of a replica), the missing part at the top, which biases the frame's middle by a constant of about 3 pt. The content really is centred: a 144 pt box centred in 735.67 pt has its middle at 367.83 pt, the content middle. The test now hosts the form at 420 x 912 and 420 x 1012 (`.large`) and requires `|(mid2 - mid1) - (V2 - V1) / 2| <= 1`, with `|contentHeight - visibleHeight| <= 1` at both heights. The tolerance stays 1 pt; the bias cancels, and a top- or bottom-pinned layout fails it. The test's doc comment says this.
4. **The simulators and runtime changed mid-plan** (owner and orchestrator decisions, not plan deviations): the original phase simulators and then the iOS 27.0 runtime were removed from the host; the two phase simulators were recreated on iOS 27.2. The first RED attempt of Task 1 failed on the missing runtime (`The iOS 27.0 simulator runtime is not available`), is kept as `c1-runtime-missing.*`, and is not recorded as a RED.
5. **Process notes:** temporary probes (the Return key, the loading-state title colours, the centre offset) lived only in the test files and were removed before each commit; the RED for Task 3 ran on the old source restored with `git checkout -- <file>` from a copy kept in the scratchpad (no stash). Two RED/GREEN runs started with a compile error in the new test (a missing `import AppModels`, a probe typed `.greatestFiniteMagnitude`); they are kept as `*-compile-error.log` and are not counted.

## Auth gates

None.

## Known Stubs

None.

## Threat Flags

None. The threat register's T-19-48 mitigation held: each fix is scoped to one view, with a failing-then-passing hosted test, the module's existing tests (`SearchFeatureTests`, `AppActivityLogsReducerTests`, `ReportFormReducerTests`, all passing) and a matrix capture; the Return-key and loading-cover observations are reported, not changed.

## Self-Check: PASSED

Commits `240e2ffdb`, `a225c5945` and `0dd2e8935` are in the branch history (signed, +08:00 dates); the six source and test files named in `key-files` exist. `commits: 3` counts this plan's own task commits after `2220c8659`; the two orchestrator docs commits `b8bc1e845` and `7d8c64da9` that sit in the same range are not part of this plan.
