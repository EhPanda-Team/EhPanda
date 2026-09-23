---
quick_id: 260923-nnu
status: incomplete
date: 2026-09-23
description: Build and test; resolve all warnings, errors, and lint violations, including test targets
---

# Build, test, and lint cleanup

## Changes

- Replace the share extension's iOS 27-deprecated `loadItem` call with typed
  `loadObject(ofClass: URL.self)` loading and the matching capability check. Loading errors cancel
  the extension request with the actual error; successful URLs retain the existing app handoff.
- Declare AppIntents framework linkage in all package test targets and both UI-test configurations.
  Xcode's metadata extractor runs on these bundles; targets without a transitive framework link
  previously emitted a missing-framework warning. Metadata extraction remains enabled.
- Guard the release-notes CLI argument, print usage to stderr, and exit unsuccessfully when it is
  absent. Valid-input filtering and output remain unchanged.
- Edit cookies through the storage API's native replacement behavior. Removing every matching
  cookie before storing one replacement discarded other matching domain/path scopes. Each existing
  scope now retains its attributes and receives the new value. A live-storage regression covers
  both matching paths, expiration, security, and unrelated cookies.
- Run synchronous startup cookie maintenance on a utility dispatch queue, bridged with a checked
  continuation. CFNetwork's cookie writes can block on persistence, so this work must not run on
  the main actor or Swift's cooperative executor. The root launch effect awaits the complete pass
  before importing automation credentials and loading settings; the delegate no longer launches
  separate cookie effects. An async regression verifies that all maintenance completes on return.

No lint rules, compiler diagnostics, test assertions, or expected-failure dispositions were weakened.
The pre-existing project-file serialization edits are preserved and excluded from this task's commits.

## Baseline

Xcode 27.0 (`27A266a`), Swift tools 6.4, iOS 27.0 simulator runtime (`24A434`).

- Clean FeatureTests run: 1,055 passed, 11 existing expected failures, zero unexpected failures,
  zero skipped tests, and no reported runtime warnings.
- Compiler: one share-extension deprecation.
- Metadata extractor: 11 package-test bundles; the subsequent UI build exposed the same issue in
  the UI-test bundle.
- Strict uncached lint: one unchecked CLI subscript in 591 tracked Swift files, including all
  package tests, UI tests, package configuration, and build tools.

## Verification

| Check | Result |
| --- | --- |
| Final FeatureTests, including both cookie regressions | 1,057 passed; 11 existing expected failures; zero unexpected failures or runtime warnings |
| Strict uncached SwiftLint, all 591 tracked Swift files | Passed; zero violations |
| Release-notes CLI: normal, empty, missing arguments | 3 cases passed |
| Cookie-logging audit and audit fixtures | Passed |
| Final arm64/x86_64 feature-test build | Passed; zero warnings, errors, or analyzer warnings |
| Final full iPhone UI suite | 51 passed; 2 iPad-only skips; zero failures, retries, or runtime warnings |
| Final full iPad UI suite | 53 passed; zero final failures or runtime warnings; one failed autoplay attempt passed on retry |
| Final arm64/x86_64 UI-test build | Passed; zero warnings, errors, or analyzer warnings |
| Focused launch audit after moving cookie maintenance off main actor | Passed; zero runtime warnings |

Evidence uses `/tmp/ehpanda-260923-nnu-`:

- `feature-baseline.log` and `feature-baseline.xcresult`
- `feature-final.log`, `feature-final.xcresult`, and `feature-final-summary.json`
- `lint-baseline.log` and `lint-final.log`
- `build-feature-clean.log` and `build-feature-clean.xcresult`
- `build-ui-clean.log` and `build-ui-clean.xcresult`
- `ui-verified.log` and `ui-verified.xcresult`
- `feature-async-final.log`, `feature-async-final.xcresult`, and `feature-async-final-summary.json`
- `build-feature-complete.log` and `build-feature-complete.xcresult`
- `build-ui-complete.log` and `build-ui-complete.xcresult`
- `cookie-async-probe.xcresult` and `cookie-async-probe-summary.json`
- `lint-complete.log`
- `ui-complete.log`, `ui-complete.xcresult`, `ui-complete-summary.json`, and `ui-complete-tests.json`
- `autoplay-attachments/` and `autoplay-activities.json`

The intermediate feature build reported an unused `Progress` result from the replacement URL API;
the call now explicitly discards that progress object. The fresh builds of the final source report
zero warnings in both raw logs and `xcresulttool get build-results` output. Each build covers
arm64 and x86_64 simulator architectures. The latest builds also include the cookie maintenance
and regression-test changes.

The 11 expected-failure test results have two different causes. Nine deliberately exercise issue
reporting: unimplemented test clients and invalid category, scheduling, basis-movement, and
progress-series operations must report issues. Their expected-issue assertions fail if the expected
report disappears. Two SettingFeature tests instead report skipped assertions when cancelling
in-flight effects. One ends a subscription tested separately; the other starts a live profile-creation
request and cancels it without testing its completion. The latter is test-isolation debt, not an
intentional diagnostic assertion. `EhProfileRequest` already accepts a URLSession, but its reducer
call site does not expose that choice as a test dependency. See `CODE-HEALTH-REVIEW.md` for the
follow-up source audit.

The iOS 27 XCTest runner still prints Apple-owned console notices about duplicate accessibility
classes in WebKit/WebCore and a future launch-screen requirement. These are not project build
diagnostics or reported runtime warnings; the toolchain's binaries and logging remain untouched.

The first full UI run finalized successfully: 104 device-test passes, two iPhone-only skips of
iPad-specific tests, no failures, and no retry/repetition nodes. It also recorded 104 instances of
one runtime priority-inversion warning. Both optional simulator diagnostic collectors timed out
after 600 seconds; `xcodebuild` still completed successfully.

The result-bundle backtrace had zeroed addresses, but the exported simulator unified log retained
image UUIDs and offsets. Matching the app image UUID and symbolicating it identified this chain:
`AppDelegateReducer` launch effect → `CookieClient.ignoreOffensive` → `setOrEditCookie` →
`editCookie` → `removeCookie` → `HTTPCookieStorage.deleteCookie` → CFNetwork semaphore wait.
Removing that unnecessary deletion exposed the same CFNetwork wait through `setCookie`, so replacing
cookies alone was insufficient. Moving the synchronous maintenance to a utility dispatch queue
eliminated the warning in the focused iPad launch audit: one pass, no runtime warnings, and zero
build diagnostics. Warning detection remains enabled. The native replacement change also fixes
the regression observed on the original implementation: only one of two cookie paths survived.
Final feature and full UI verification report zero runtime warnings. Both `xcodebuild` test commands
exit successfully. The full UI result retains one intermittent failed attempt described below;
this task is therefore not recorded as an entirely clean test gate.

## Remaining test instability

On iPad, `ReaderPageSyncUITests.testAutoPlayTurnsThePageAndKeepsTheIndicatorOnIt` failed its first
attempt at `ReaderPageProbe.swift:240`: the Auto-Play menu did not disappear after the single
selection tap on **Off**. The plan's existing retry passed; there is one failed first-run node and
one successful retry node. No retry settings, timeouts, taps, or assertions were weakened.

The retained video and accessibility hierarchy show **1 second** still selected while pages keep
advancing. The synthesized event records a 50 ms tap at `(712.5, 59)` inside the Off row's frame
`(600.5, 40, 224, 38)`. This is an unapplied selection, not merely a stale dismissal check, so
forcing menu dismissal would not address the observed failure. The same failure class is recorded
in the earlier reader verification history. Its precise cause remains unproven.

A temporary isolated SwiftUI menu with animated paging completed 20 selections using a native
state binding and another 20 using a custom selection binding, without reproducing the failure.
This does not exonerate either the reader or the framework; it leaves the cause undetermined.
The diagnostic sources were removed from the app and test targets, and the original app shell
was restored byte for byte. Copies remain under `/tmp/ehpanda-260923-nnu-menu-probe-source/`.
No speculative production reader or test-driver change is included.

Probe evidence: `menu-isolation.xcresult`, `menu-binding-probe.xcresult`, and the final production
launch audit `restored-app.xcresult`, under the temporary prefix above. All requested build/lint
diagnostics and observed runtime warnings are resolved; the intermittent first-attempt UI failure
remains open, which is why this summary retains `status: incomplete`.

## Workflow

Code commits:

- `edca42cb` (`fix(quick-260923-nnu): clear build and lint diagnostics`)
- `7ac307e1` (`fix(quick-260923-nnu): move startup cookie maintenance off main actor`)

Executed GSD quick inline, using the workflow's sequential fallback. No subagents were dispatched.
The quick task leaves the phase roadmap unchanged.

## API reference

The installed iOS 27 SDK and Apple's
[typed NSItemProvider loading documentation](https://developer.apple.com/documentation/foundation/nsitemprovider/loadobject(ofclass:completionhandler:)-6pysm)
confirm the replacement API and its completion-handler contract.

The installed Foundation header and Apple's
[cookie storage documentation](https://developer.apple.com/documentation/foundation/httpcookiestorage/setcookie(_:))
specify that storing a cookie replaces the existing cookie with the same name, domain, and path.
