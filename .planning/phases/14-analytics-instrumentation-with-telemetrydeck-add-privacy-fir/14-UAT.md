---
status: complete
phase: 14-analytics-instrumentation-with-telemetrydeck-add-privacy-fir
source: [14-01-SUMMARY.md, 14-02-SUMMARY.md, 14-03-SUMMARY.md, 14-04-SUMMARY.md, 14-05-SUMMARY.md, 14-06-SUMMARY.md, 14-07-SUMMARY.md, 14-08-SUMMARY.md, 14-09-SUMMARY.md, 14-10-SUMMARY.md, 14-11-SUMMARY.md, 14-12-SUMMARY.md, 14-13-SUMMARY.md, 14-14-SUMMARY.md, 14-15-SUMMARY.md, 14-16-SUMMARY.md, 14-17-SUMMARY.md, 14-18-SUMMARY.md]
started: 2026-07-26T13:56:46Z
updated: 2026-07-26T15:12:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Analytics opt-out toggle in General settings
expected: Settings -> General shows an "Analytics" section with a "Share Analytics Data" toggle, switched ON, plus a footer stating that switching it off does not make the app fully silent (the anonymous per-install identifier and the SDK's technical details still go once per session).
result: pass

### 2. Opt-out choice survives relaunch without resetting other preferences
expected: Turn the toggle off, force-quit, relaunch. It reads off, and every other setting (General, Reading, Appearance) keeps its value. This is the old-blob decode-tolerance guarantee: the new field is optional precisely so a preferences blob written before the toggle shipped still decodes instead of resetting everything to defaults.
result: pass

### 3. Gallery-detail tag tap still performs its search
expected: On a gallery detail screen, tapping a tag pushes the detail-search screen with that tag's keyword, exactly as before. Plan 14-13 rerouted this tap through a new namespace-carrying reducer action and widened the callback at six sites, so a broken wire would show up as a tap that does nothing or searches the wrong term. The informational tag-detail sheet is a separate control and should still open its sheet.
result: pass

### 4. Download actions behave unchanged
expected: From gallery detail and the Downloads tab, exercise start, retry, pause, resume, update, delete and move. Each behaves as before: no stalls, no duplicated rows, no button that stopped responding. Plans 14-13, 14-15 and 14-17 added emission at these sites, grew DownloadOutcome by three cases, and made deleteDownloadDone bind a Result it previously discarded.
result: pass

### 5. Reader session and reading-progress flush
expected: Open a gallery in the reader, page forward and back, scrub the slider, then dismiss. On reopening, position is the last page you actually swiped to. Plan 14-14 added a session-start date read and a visited-page set to the reducer and emits at the dismissal seam; the existing progress flush must still run first, which is what keeps the last page from being lost.
result: pass

### 6. Login, including the Cloudflare challenge path
expected: A correct credential signs in; a wrong one surfaces the refusal toast; if a Cloudflare challenge appears, resolving it completes the login. Plan 14-16 added emissions to the login-failure and challenge-detected paths and states it left untouched the credential-ordering that Phase 12 found load-bearing (credentials must reach the shared cookie jar before didLogin is read, or a successful post-challenge login reports as a failure).
result: issue
reported: "pass. but a login failure presents a toast with message \"Login required to access this download.\" is not appropriate"
severity: major
note: Login flow itself passed; the defect is the failure toast copy.

### 7. README analytics disclosure, all six languages
expected: README.md and the five files in READMEs/ each carry an Analytics section (all at line 30) describing what actually ships: on by default with an opt-out, the collected categories including searches-as-shape, the SDK's own enrichment (device model and architecture, screen metrics, OS version, locale, region, time zone, seven accessibility settings, appearance, retention and session counts), the never-collected list, the hashed per-install identifier, and the vendor privacy-policy link. Read at least the English one against that list and confirm nothing is overstated or missing.
result: issue
reported: "\"A build made without the local analytics configuration file (`Config/Analytics.local.xcconfig`) sends nothing at all, whatever that setting says. Contributor builds from source and any release cut without that file have analytics silently disabled.\" is stale since we've shifted to use ci secrets"
severity: major
note: Present at line 41 of all six READMEs. deploy.yml:50 and deploy-pre-release.yml:51 inject TELEMETRYDECK_APP_ID / TELEMETRYDECK_SALT from CI secrets, so an official release does carry credentials.

### 8. A credential-free build reaches the ingestion host zero times
expected: With no Config/Analytics.local.xcconfig present (which is the current working-tree state), a proxied run driving several instrumented flows shows zero requests to the analytics ingestion host, including no TelemetryDeck.Session.started. That absent signal is the load-bearing part: it comes from the SDK itself, so its absence shows the gate resolves before initialization rather than merely muting call sites. Recorded evidence, 14-18 Check A: six emissions across five signal cases, a 25s wait covering the 10s transmit interval, 79 domains captured, zero vendor matches, with a positive control taken first.
coverage_id: 14-04:D6
result: pass

### 9. Credentialed delivery, payload contents, and the opt-out kill
expected: With the real credential in place, the same flows produce POST /v2/ requests that all return 200, and every decrypted request body is free of keyword text, gallery title, uploader name, gallery id, token and any URL, with no Cookie header on any request. With the toggle switched off, telemetry stops advancing while ordinary e-hentai traffic from the same session continues. Recorded evidence, 14-18 Checks B and D: eight POSTs all 200, forbidden-value sweep zero matches each with a positive control at 8/8, and roughly 340 further e-hentai flows past the last telemetry flow once opted out.
result: pass

### 10. CountBucket and DurationBucket map every Int / TimeInterval to exactly one bucket, with no gaps or overlaps at any boundary (D-08)
expected: CountBucket and DurationBucket map every Int / TimeInterval to exactly one bucket, with no gaps or overlaps at any boundary (D-08)
result: pass
source: automated
coverage_id: 14-01:D1

### 11. The TelemetryDeck SPM package resolves to a 2.x stable tag with no pre-release pin (D-12 supply-chain hygiene)
expected: The TelemetryDeck SPM package resolves to a 2.x stable tag with no pre-release pin (D-12 supply-chain hygiene)
result: pass
source: automated
coverage_id: 14-01:D2

### 12. All three new test targets are declared, lint-covered, and actually execute in the default test plan
expected: All three new test targets are declared, lint-covered, and actually execute in the default test plan
result: pass
source: automated
coverage_id: 14-01:D3

### 13. Every feature and test target later waves instrument already resolves AnalyticsClient, so no later plan modifies Package.swift or FeatureTests.xctestplan
expected: Every feature and test target later waves instrument already resolves AnalyticsClient, so no later plan modifies Package.swift or FeatureTests.xctestplan
result: pass
source: automated
coverage_id: 14-01:D4

### 14. ANALYTICS-01 exists in REQUIREMENTS.md, unchecked, with acceptance criteria, a Phase 14 mapping row and consistent coverage counts
expected: ANALYTICS-01 exists in REQUIREMENTS.md, unchecked, with acceptance criteria, a Phase 14 mapping row and consistent coverage counts
result: pass
source: automated
coverage_id: 14-01:D5

### 15. All five research Open Questions carry a recorded owner disposition before any taxonomy code is written
expected: All five research Open Questions carry a recorded owner disposition before any taxonomy code is written
result: pass
source: automated
coverage_id: 14-02:D1

### 16. The salt is decided exactly once, with its irreversibility stated (T-14-07)
expected: The salt is decided exactly once, with its irreversibility stated (T-14-07)
result: pass
source: automated
coverage_id: 14-02:D2

### 17. The D-09 wall placement is a recorded decision rather than an implementer's judgement call, with the departure from D-09's wording stated in plain terms (T-14-01)
expected: The D-09 wall placement is a recorded decision rather than an implementer's judgement call, with the departure from D-09's wording stated in plain terms (T-14-01)
result: pass
source: automated
coverage_id: 14-02:D3

### 18. No decision narrows what D-01 … D-14 permit the app to collect
expected: No decision narrows what D-01 … D-14 permit the app to collect
result: pass
source: automated
coverage_id: 14-02:D4

### 19. The generated doc leaks no absolute home path and names no other local project
expected: The generated doc leaks no absolute home path and names no other local project
result: pass
source: automated
coverage_id: 14-02:D5

### 20. The closed screen, tab, surface and outcome vocabulary exists with pinned spellings, and every Int-raw domain enum has a stable non-numeric analytics spelling (D-09)
expected: The closed screen, tab, surface and outcome vocabulary exists with pinned spellings, and every Int-raw domain enum has a stable non-numeric analytics spelling (D-09)
result: pass
source: automated
coverage_id: 14-03:D1

### 21. The gallery category vocabulary covers all eleven Category cases, imageSet and private included (D-15)
expected: The gallery category vocabulary covers all eleven Category cases, imageSet and private included (D-15)
result: pass
source: automated
coverage_id: 14-03:D2

### 22. TagNamespaceCounts reduces a gallery's tags to exact per-namespace counts (D-16), with unused namespaces absent rather than zero and unrecognized raw namespaces collapsed onto one anonymous key
expected: TagNamespaceCounts reduces a gallery's tags to exact per-namespace counts (D-16), with unused namespaces absent rather than zero and unrecognized raw namespaces collapsed onto one anonymous key
result: pass
source: automated
coverage_id: 14-03:D3

### 23. SearchShape reduces a keyword to a word-count bucket, a tag-syntax flag and the exact grapheme-count length, and stores nothing else (D-07/D-19)
expected: SearchShape reduces a keyword to a word-count bucket, a tag-syntax flag and the exact grapheme-count length, and stores nothing else (D-07/D-19)
result: pass
source: automated
coverage_id: 14-03:D4

### 24. No content text survives either reduction — proven by reflecting over the constructed value and asserting a distinctive sentinel appears nowhere in its stored graph (D-06, threat T-14-01)
expected: No content text survives either reduction — proven by reflecting over the constructed value and asserting a distinctive sentinel appears nowhere in its stored graph (D-06, threat T-14-01)
result: pass
source: automated
coverage_id: 14-03:D5

### 25. AppErrorKind mirrors all fifteen AppError cases with no associated values and no catch-all arm, so a sixteenth case is a compile error (D-06, threat T-14-08)
expected: AppErrorKind mirrors all fifteen AppError cases with no associated values and no catch-all arm, so a sixteenth case is a compile error (D-06, threat T-14-08)
result: pass
source: automated
coverage_id: 14-03:D6

### 26. AnalyticsErrorCategory mirrors the vendor's three category spellings locally, with every kind's category pinned and no SDK import in the taxonomy layer
expected: AnalyticsErrorCategory mirrors the vendor's three category spellings locally, with every kind's category pinned and no SDK import in the taxonomy layer
result: pass
source: automated
coverage_id: 14-03:D7

### 27. The module declares no stored String property outside String-raw enum storage, and SwiftLint reports zero violations with no suppression directive added
expected: The module declares no stored String property outside String-raw enum storage, and SwiftLint reports zero violations with no suppression directive added
result: pass
source: automated
coverage_id: 14-03:D8

### 28. A clean clone with no local override builds successfully, emits no configuration-file warning, and carries empty analytics credentials
expected: A clean clone with no local override builds successfully, emits no configuration-file warning, and carries empty analytics credentials
result: pass
source: automated
coverage_id: 14-04:D1

### 29. The build-variable substitution reaches the built app bundle — the local override's value is readable out of EhPanda.app/Info.plist, and its absence leaves the key empty
expected: The build-variable substitution reaches the built app bundle — the local override's value is readable out of EhPanda.app/Info.plist, and its absence leaves the key empty
result: pass
source: automated
coverage_id: 14-04:D2

### 30. Both AppInfo accessors resolve to nil under the test host, which is the D-13 gate protecting every other suite in the repository
expected: Both AppInfo accessors resolve to nil under the test host, which is the D-13 gate protecting every other suite in the repository
result: pass
source: automated
coverage_id: 14-04:D3

### 31. Nothing credential-bearing is tracked by git — the local override is gitignored and no real app ID or salt exists in any commit
expected: Nothing credential-bearing is tracked by git — the local override is gitignored and no real app ID or salt exists in any commit
result: pass
source: automated
coverage_id: 14-04:D4

### 32. No privacy manifest is added to the app or share-extension target (D-04)
expected: No privacy manifest is added to the app or share-extension target (D-04)
result: pass
source: automated
coverage_id: 14-04:D5

### 33. AnalyticsSignal is a closed thirteen-case enum covering every D-05 flow-family item not already emitted by the SDK, with no case carrying a String, URL, Data or AppModels content type (D-09)
expected: AnalyticsSignal is a closed thirteen-case enum covering every D-05 flow-family item not already emitted by the SDK, with no case carrying a String, URL, Data or AppModels content type (D-09)
result: pass
source: automated
coverage_id: 14-05:D1

### 34. Every signal renders to its exact stable name and full parameter dictionary through one exhaustive no-default switch, the single site where an analytics name or key is minted
expected: Every signal renders to its exact stable name and full parameter dictionary through one exhaustive no-default switch, the single site where an analytics name or key is minted
result: pass
source: automated
coverage_id: 14-05:D2

### 35. No rendered parameter key collides case-insensitively with the SDK's 25-key reserved set, and no rendered signal name begins with the reserved TelemetryDeck. prefix (D-06 tampering, threat T-14-04)
expected: No rendered parameter key collides case-insensitively with the SDK's 25-key reserved set, and no rendered signal name begins with the reserved TelemetryDeck. prefix (D-06 tampering, threat T-14-04)
result: pass
source: automated
coverage_id: 14-05:D3

### 36. An exhaustive sentinel sweep over every case proves no rendered name, key or value carries gallery, keyword, tag or error-payload text (D-06, threat T-14-01)
expected: An exhaustive sentinel sweep over every case proves no rendered name, key or value carries gallery, keyword, tag or error-payload text (D-06, threat T-14-01)
result: pass
source: automated
coverage_id: 14-05:D4

### 37. SwiftLint reports zero violations across the module and its test target with no suppression directive added
expected: SwiftLint reports zero violations across the module and its test target with no suppression directive added
result: pass
source: automated
coverage_id: 14-05:D5

### 38. A nil build-time app ID resolves AnalyticsClient.live to the total no-op with the SDK never referenced (D-13), which also stops any signal from reaching an uninitialized SDK
expected: A nil build-time app ID resolves AnalyticsClient.live to the total no-op with the SDK never referenced (D-13), which also stops any signal from reaching an uninitialized SDK
result: pass
source: automated
coverage_id: 14-06:D1

### 39. The D-11 global default parameters are re-read on every signal — a mid-session setting change is reflected on the next signal, not snapshotted at init
expected: The D-11 global default parameters are re-read on every signal — a mid-session setting change is reflected on the next signal, not snapshotted at init
result: pass
source: automated
coverage_id: 14-06:D2

### 40. testValue is the loud unimplemented client and previewValue is the silent no-op (the D-12-locked triple), and the .noop-derived spy records signals in order
expected: testValue is the loud unimplemented client and previewValue is the silent no-op (the D-12-locked triple), and the .noop-derived spy records signals in order
result: pass
source: automated
coverage_id: 14-06:D3

### 41. Exactly one file in the repository imports the TelemetryDeck SDK (D-12), the SDK is configured with the app ID and the D-17 salt, and no deprecated SDK spelling appears anywhere
expected: Exactly one file in the repository imports the TelemetryDeck SDK (D-12), the SDK is configured with the app ID and the D-17 salt, and no deprecated SDK spelling appears anywhere
result: pass
source: automated
coverage_id: 14-06:D4

### 42. SwiftLint reports zero violations across the module and its new test files with no suppression directive added; the full default test plan is green
expected: SwiftLint reports zero violations across the module and its new test files with no suppression directive added; the full default test plan is green
result: pass
source: automated
coverage_id: 14-06:D5

### 43. Every TestStore in DownloadsFeatureTests resolves analyticsClient to the no-op client (55 real initializers, covering all 75 grep-counted store constructions)
expected: Every TestStore in DownloadsFeatureTests resolves analyticsClient to the no-op client (55 real initializers, covering all 75 grep-counted store constructions)
result: pass
source: automated
coverage_id: 14-07:D1

### 44. Every TestStore in SettingFeatureTests resolves analyticsClient to the no-op client (28 store constructions across 11 files)
expected: Every TestStore in SettingFeatureTests resolves analyticsClient to the no-op client (28 store constructions across 11 files)
result: pass
source: automated
coverage_id: 14-08:D1

### 45. Every TestStore in the four targets resolves analyticsClient to the no-op client (24 store constructions across 9 files)
expected: Every TestStore in the four targets resolves analyticsClient to the no-op client (24 store constructions across 9 files)
result: pass
source: automated
coverage_id: 14-09:D1

### 46. SDK initializes exactly once per process from the launch-finish reducer action, never a view callback (D-14)
expected: SDK initializes exactly once per process from the launch-finish reducer action, never a view callback (D-14)
result: pass
source: automated
coverage_id: 14-10:D1

### 47. Switching to a different tab records exactly one tabOpened; re-tapping the current tab records nothing
expected: Switching to a different tab records exactly one tabOpened; re-tapping the current tab records nothing
result: pass
source: automated
coverage_id: 14-10:D2

### 48. The modal gallery-detail path emits one galleryDetailOpened matching a fixture, carrying no gid/token/title/URL
expected: The modal gallery-detail path emits one galleryDetailOpened matching a fixture, carrying no gid/token/title/URL
result: pass
source: automated
coverage_id: 14-10:D3

### 49. A diagnostics-carrying error toast emits one errorSurfaced of the expected kind; a caption-only toast and the error-detail drill-down emit nothing
expected: A diagnostics-carrying error toast emits one errorSurfaced of the expected kind; a caption-only toast and the error-detail drill-down emit nothing
result: pass
source: automated
coverage_id: 14-10:D4

### 50. All five Home sections emit homeSectionViewed through one exhaustive mapping across the two entry actions
expected: All five Home sections emit homeSectionViewed through one exhaustive mapping across the two entry actions
result: pass
source: automated
coverage_id: 14-11:D1

### 51. The Home gallery-detail push emits one galleryDetailOpened matching a fixture, carrying no gid/token/title/URL/tag text
expected: The Home gallery-detail push emits one galleryDetailOpened matching a fixture, carrying no gid/token/title/URL/tag text
result: pass
source: automated
coverage_id: 14-11:D2

### 52. Each Home sub-screen filter panel emits filterPanelOpened naming its own surface; the Watched quick-search panel emits quickSearchPanelOpened
expected: Each Home sub-screen filter panel emits filterPanelOpened naming its own surface; the Watched quick-search panel emits quickSearchPanelOpened
result: pass
source: automated
coverage_id: 14-11:D3

### 53. A performed search emits exactly one searchPerformed signal carrying a reduced SearchShape and a CountBucket result count, never the keyword text
expected: A performed search emits exactly one searchPerformed signal carrying a reduced SearchShape and a CountBucket result count, never the keyword text
result: pass
source: automated
coverage_id: 14-12:D1

### 54. The recorded performed-search signal carries no part of the keyword (sentinel reflection); the history-keyword action records zero signals
expected: The recorded performed-search signal carries no part of the keyword (sentinel reflection); the history-keyword action records zero signals
result: pass
source: automated
coverage_id: 14-12:D2

### 55. Filter and quick-search panels on the Search, Search-root and Favorites screens each emit naming their own surface
expected: Filter and quick-search panels on the Search, Search-root and Favorites screens each emit naming their own surface
result: pass
source: automated
coverage_id: 14-12:D3

### 56. The Favorites gallery-detail push emits galleryDetailOpened with a Category and exact per-namespace tag counts, no title/tag text
expected: The Favorites gallery-detail push emits galleryDetailOpened with a Category and exact per-namespace tag counts, no title/tag text
result: pass
source: automated
coverage_id: 14-12:D4

### 57. Selecting a quick-search word records one payload-free quickSearchWordUsed signal from a reducer action, carrying no part of the word
expected: Selecting a quick-search word records one payload-free quickSearchWordUsed signal from a reducer action, carrying no part of the word
result: pass
source: automated
coverage_id: 14-12:D5

## Summary

total: 57
passed: 55
issues: 2
pending: 0
skipped: 0
blocked: 0

## Gaps

- gap_id: G-14-6
  truth: "A login failure surfaces a toast whose message describes the login failure"
  status: resolved
  resolved_by: "commit 3fcce0f0 (fix: stop login refusal reading as auth error)"
  resolved_at: 2026-07-26
  resolution: "Two parts. (1) `app_error.authentication_required_description` is now context-neutral in all six locales (\"Login required to access this content.\"), since the case it serves is general. (2) `LoginRequest.response()` no longer lets the site-wide `.authenticationRequired` verdict escape as a login outcome: it reports a plain refusal (`.unknown`, which `LoginReducer.loginFailureKind` maps to `.rejected`), matching what the error-box branch already throws for the same condition. Every other site error keeps its own case. Guarded by `aRefusalPageIsNotReportedAsAGeneralAuthenticationError`, verified as a real guard by reverting the mapping and confirming the test fails with exactly `.authenticationRequired`."
  reason: "User reported: pass. but a login failure presents a toast with message \"Login required to access this download.\" is not appropriate"
  severity: major
  test: 6
  note: "The login flow itself passed; the defect is the failure toast's copy — it names downloads on a login screen."
  root_cause: "Context-specific copy bound to a context-free error case. `AppError.authenticationRequired` is raised from several unrelated places — the response parser (kokomade wall, `access to exhentai.org is restricted`, `bounce_login.php`) and the download client — but its user-facing text is written for one of them. A login refusal maps to `.other` in `LoginReducer.loginFailureKind` and surfaces the same string, so the toast names a download the user never started. Pre-existing; Phase 14 did not introduce it, the UAT sweep surfaced it."
  artifacts:
    - path: "AppPackage/Sources/AppModels/Resources/Localizable.xcstrings"
      issue: "`app_error.authentication_required_description` is download-specific (\"Login required to access this download.\") in all six locales, but the error case it serves is general."
    - path: "AppPackage/Sources/AppModels/Support/AppError.swift:93"
      issue: "`.authenticationRequired` returns that one string as its alert text for every caller."
    - path: "AppPackage/Sources/ParserFeature/Parser+ResponseError.swift:14,71,92"
      issue: "Raises `.authenticationRequired` from non-download response parsing, which is how a login attempt reaches the download-worded toast."
    - path: "AppPackage/Tests/AppModelsTests/AppErrorStructuredTests.swift:61"
      issue: "Pins the exact string; must be updated with the copy."
  missing:
    - "Reword `app_error.authentication_required_description` to be context-neutral in all six locales (en, de, ja, ko, zh-Hans, zh-Hant)."
    - "Decide whether the download path keeps download-specific wording of its own — `DownloadFailure` (AppModels/Download/DownloadFailure.swift:26) builds its message from `error.alertText`, so it inherits whatever this becomes."
    - "Update the pinned expectation in AppErrorStructuredTests.swift."
  debug_session: ""

- gap_id: G-14-7
  truth: "The README analytics disclosure describes what actually ships, in all six languages"
  status: resolved
  resolved_by: "commit 2c7e0d0f (docs: correct analytics release disclosure)"
  resolved_at: 2026-07-26
  resolution: "The sentence now states that official releases are built with credentials supplied by the release workflow from repository secrets and therefore do send, while a build without those credentials sends nothing (contributor clones and forks). Rewritten in all six READMEs. `Config/Analytics.xcconfig`'s header comment carried the same stale claim (\"a contributor clone, a fork and CI all build with empty analytics credentials\") and now documents both credential paths, including that command-line build settings outrank the xcconfig and that each workflow reads the archived Info.plist back to fail an uncredentialed release. Verified: zero em dashes per the repo's public-docs rule, no residual `Analytics.local.xcconfig` reference in any README, and the CI D-03 disclosure gate passes against all six files."
  reason: "User reported: \"A build made without the local analytics configuration file (`Config/Analytics.local.xcconfig`) sends nothing at all, whatever that setting says. Contributor builds from source and any release cut without that file have analytics silently disabled.\" is stale since we've shifted to use ci secrets"
  severity: major
  test: 7
  note: "Line 41 of README.md and all five READMEs/*.md. Official releases now receive credentials from CI secrets (deploy.yml:50, deploy-pre-release.yml:51), so the second sentence is false for them; the contributor-build half is still true."
  root_cause: "The disclosure was written in plan 14-17 when the local xcconfig was the only way to supply credentials, and it was not revisited when credential delivery moved to CI secrets. `deploy.yml` and `deploy-pre-release.yml` export TELEMETRYDECK_APP_ID / TELEMETRYDECK_SALT into the build and then assert the values landed in the built Info.plist, so an official release is credentialed without any `Config/Analytics.local.xcconfig` existing. The sentence therefore understates collection for exactly the builds most readers run. 14-18 Check C audited this section against observed traffic but not against the release pipeline, so the staleness survived that review."
  artifacts:
    - path: "README.md:41"
      issue: "Claims any release cut without the local xcconfig has analytics silently disabled."
    - path: "READMEs/README.chs.md:41, READMEs/README.cht.md:41, READMEs/README.de.md:41, READMEs/README.jpn.md:41, READMEs/README.ko.md:41"
      issue: "Same claim, translated; all five must move together with the English."
    - path: ".github/workflows/deploy.yml:50-51"
      issue: "Injects the credentials from CI secrets, which is the fact the disclosure contradicts."
    - path: ".github/workflows/deploy-pre-release.yml:51-52"
      issue: "Same for pre-release builds."
  missing:
    - "Rewrite the sentence in all six READMEs to say official releases are credentialed via CI secrets and do send analytics, while a build from source without credentials sends nothing."
    - "Keep the runtime opt-out described as the control that applies to a credentialed release."
  debug_session: ""
