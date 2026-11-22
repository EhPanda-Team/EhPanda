---
phase: quick-261123-3wz
plan: 01
subsystem: infra
tags: [crash-reporting, sentry, privacy, ci, dsym]
status: complete

requires: []
provides:
  - CrashReporting module (only importer of the Sentry SDK): explicit crashes-only options, beforeSend scrubber, start rule
  - SENTRY_DSN build setting -> Info.plist SentryDSN -> AppInfo.sentryDSN plumbing, started first in application(_:didFinishLaunchingWithOptions:)
  - Privacy manifest entry for crash data
  - actions-tool/upload-dsyms.sh and the three release archives (Deploy, Deploy's AltStorePAL job, Deploy Beta) wired to it
affects: [release workflows, privacy manifest, Package.resolved]

commits: 3
plan_head_before: d43321737449805bce877a37b30d111677a16d03
plan_head_after: 46e929504959f154ca82f531e05a117d302ebc54

actuals:
  tokens: 22591
  tasks: 3
  commits: 3

tech-stack:
  added: [sentry-cocoa 9.35.0 (exact pin), sentry-cli 3.8.2 (CI only, checksum pinned)]
  patterns:
    - "Boundary-capture redaction rules as private functions with a function-local regex literal and a named `boundary` capture"
    - "Start rule as a testable overload that returns whether it started"

key-files:
  created:
    - AppPackage/Sources/CrashReporting/CrashReportScrubber.swift
    - AppPackage/Sources/CrashReporting/CrashReporter.swift
    - AppPackage/Sources/CrashReporting/.swiftlint.yml
    - AppPackage/Tests/CrashReportingTests/CrashReportScrubberTests.swift
    - AppPackage/Tests/CrashReportingTests/CrashReporterOptionsTests.swift
    - AppPackage/Tests/CrashReportingTests/CrashReporterStartTests.swift
    - AppPackage/Tests/CrashReportingTests/.swiftlint.yml
    - actions-tool/upload-dsyms.sh
    - actions-tool/tests/test_upload_dsyms.py
  modified:
    - AppPackage/Package.swift
    - AppPackage/Package.resolved
    - EhPanda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
    - .swiftlint.yml
    - AppPackage/Tests/FeatureTests.xctestplan
    - AppPackage/Sources/AppModels/Utilities/AppInfo.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift
    - App/Info.plist
    - App/PrivacyInfo.xcprivacy
    - actions-tool/tests/test_privacy_manifest.py
    - actions-tool/tests/test_workflows.py
    - .github/workflows/deploy.yml
    - .github/workflows/deploy-beta.yml

key-decisions:
  - "Regex rules with a leading boundary capture are private functions with a function-local `let` regex and a NAMED capture (`boundary`), read as `match.output.boundary`; never positional `.1` (orchestrator decision, see Deviations)"
  - "Sentry environment = DistributionChannel.current.rawValue"
  - "Start rule = never in Debug, never in an XCTest-hosted process, never without a DSN"
  - "No xcconfig default for the DSN (xcconfig would cut it at `//`)"

requirements-completed: [quick-261123-3wz]
---

# Phase quick-261123-3wz Plan 01: Sentry crash reporting with privacy-preserving settings Summary

Release builds now report crashes only (nothing about the person) to the owner's Sentry project through a `beforeSend` scrubber that never drops an event, with the DSN carried solely by release archives from the `SENTRY_DSN` secret and dSYMs uploaded by CI with a checksum-pinned `sentry-cli`.

## Commits

| Task | Commit | Message |
| ---- | ------ | ------- |
| 1 | 9067a3092 | Add a scrubber for crash reports |
| 2 | 4c661deef | Start crash reporting at launch |
| 3 | 46e929504 | Upload dSYMs and require a DSN in releases |

All three are signed, with author and committer dates in +0800.

**Landing on develop (2026-11-23).** The task was built on `main` and replayed onto `develop`, which no longer shares history with `main`. On `develop` the AltStore PAL archive is the `AltStorePAL` job of `deploy.yml` and `deploy-pal.yml` is gone, so Task 3's PAL steps (the `SENTRY_DSN` build setting, "Verify crash reporting DSN", "Upload dSYMs" and "Keep the dSYMs" on `$PAL_ARCHIVE_PATH`, artifact `EhPanda-AltStorePAL-dSYMs`) moved into that job, and `CrashReportingWorkflowTests` checks it there. The lockfiles' only conflict was the `originHash` line; SwiftPM recomputed it as `develop`'s value. The commit IDs above are the replayed ones.

## What was built

- **Task 1**: `CrashReporting` module with `CrashReportScrubber` (field clearing, five kept contexts, `device_app_hash` removal, ordered free-text redaction: URLs, scheme-less E-Hentai/ExHentai hosts, the three credential cookies, e-mail, IPv4, IPv6, home folder, 300-character cut; path redaction for frame packages and debug-image paths). Exact pin `sentry-cocoa` 9.35.0 in both lockfiles (only that pin and the originHash changed). Two lint rules (`crash_reporting_sdk_import_boundary`, `crash_reporting_start_only`) probed on positive and negative inputs. 21 distinct scrubber tests (47 runs with parameterization), FeatureTests plan entry added.
- **Task 2**: `CrashReporter` (testable start overload returning whether it started; every option set explicitly, including the nine 9.35.0 additions; `beforeSend` formed inside the nonisolated options builder), `AppInfo.sentryDSN`, `SentryDSN` Info.plist key, `CrashReporter.start()` as the first statement of the launch callback, crash-data entry in the privacy manifest with `test_privacy_manifest.py` in agreement.
- **Task 3**: `actions-tool/upload-dsyms.sh` (pinned sentry-cli 3.8.2, SHA-256 verified before it is made executable, token never on a command line or in output, CI form always exits 0 with one `::warning::` line, `--reupload` form exits non-zero), 22 offline tests, and in `deploy.yml` (both jobs) and `deploy-beta.yml`: `SENTRY_DSN` build setting, "Verify crash reporting DSN", "Upload dSYMs", "Keep the dSYMs" artifact; `CrashReportingWorkflowTests` and updated `PAL_STEPS`.

## sentry-cli pin

Version 3.8.2 (newest stable on 2026-11-23, published 2026-10-22). The SHA-256 values were read from that release's assets (`gh api repos/getsentry/sentry-cli/releases/tags/3.8.2`, the `digest` field the release page shows) and confirmed against the downloaded bytes with `shasum -a 256`:

- `sentry-cli-Darwin-arm64`: `c80d92b6d34eb64fe7402f56cc7968fbb15aab1c763254ad428b55cc98ec7dcf`
- `sentry-cli-Darwin-x86_64`: `084591ee1f0a43ba8696ccde30d4a79cd9a70d0fa294c5a10143a340f8f332ff`

The live check ran the real script with `--reupload` against `https://sentry.invalid`: it printed `sentry-cli 3.8.2 (sentry-cli-Darwin-arm64) matches its pinned SHA-256.`, the upload then failed on name resolution as intended, and the probe token never appeared in the output.

## Release simulator launches (iPhone Air, iOS 27.2)

- **With a DSN** (`SENTRY_DSN=https://0123456789abcdef0123456789abcdef@o0.ingest.example.invalid/0`): Info.plist `SentryDSN` equals it byte for byte (the `//` survived the command line); the share extension binary has no "sentry" text; the app binary contains `SentrySDK`; none of the FORBIDDEN_CONTENT tokens appear except the accepted inert shell name `UITestAutomation`. Launched, alive after 15 s, and the data container gained `Library/Caches/io.sentry/` (containing one hash-named folder, `392aaab02a009c3b060e710a7e9b5c79b706368f`) and `Library/Caches/SentryCrash/`.
- **Without a DSN**: Info.plist `SentryDSN` is empty. Launched, alive after 15 s, and no Sentry folder exists in the data container (only the Kingfisher cache).

The fake DSN's host does not resolve, so nothing left the machine.

## Gates

- **Warning baseline** (Debug build at HEAD before the first edit): 2 unique `warning:`/`error:` lines, both the pre-existing `public import of 'Foundation' was not used` message in `TitleWidowGuard.swift`. No gate added a line.
- **Tests**: the full FeatureTests plan (VisualSnapshotTests skipped) succeeded at every task (2996, 3023, 3023 passed test-case runs). The known flake `LoginReturnObservationTests.cookieLoginTriggersReloadWithoutAViewCallback` never failed, so no rerun was needed.
- **Lint**: the full-tree lint printed exactly the 7 baseline violations after every task; touched trees lint clean.
- **Tooling**: actions-tool suite 259 -> 288 tests, OK; actionlint on the three deploy workflows exits 0; shellcheck on the script exits 0.

## Deviations from Plan

### Orchestrator-decided deviation (labeled_tuple_elements)

**1. [Lint conflict, orchestrator decision] Boundary-capture regex rules**
- **Found during:** Task 1
- **Issue:** The plan's prescribed form `static var ipv4Address: Regex<(Substring, Substring)>` is rejected by the repo's `labeled_tuple_elements` rule (error severity); no suppression was allowed.
- **Resolution (orchestrator decision, Option A with a change):** each boundary-capture rule (site host, e-mail, IPv4, IPv6) is a private static function with a function-local `let` regex literal whose type is inferred, and the leading boundary is a NAMED capture `(?<boundary>...)` read as `match.output.boundary` in the replacement closure (never a positional `.1`). Patterns, order, the `[redacted]` token, the 300-character limit and behavior are unchanged. URL, cookie and home folder (no tuple) stay computed `Regex<Substring>` properties. Suppressing or excluding the rule was refused.
- **Small consequence:** the multi-line IPv6 and host literals use extended syntax, where `#` starts a comment, so the host pattern spells the `#` in its character class as `\#`. Verified by the host tests.
- **Commit:** 9067a3092

### Accepted process notes

**2. Scrubber written before its tests** (the plan asked for tests first and a failing run). Accepted by the orchestrator. The tests were then run against the implementation and pass; the regex pipeline was additionally checked in a standalone harness before it entered the module.

**3. `swift package resolve` hang.** `xcrun swift package --package-path AppPackage resolve` wrote the correct `Package.resolved` (new pin 9.35.0, nothing else moved) and then hung for over 13 minutes on the binary artifact download with no open sockets. It was stopped with SIGTERM, the file was copied into the workspace, and `xcodebuild -resolvePackageDependencies ... -onlyUsePackageVersionsFromResolvedFile` completed normally. The two files are byte-identical and `AppPackage/.build` was removed.

**4. Concurrent sessions.** Another session's `xcodebuild` runs overlapped with the first test attempts on this machine; no run failed for an infrastructure reason after the lint fix.

### Auto-fixed Issues

None beyond the above: the plan's remaining behavior (options, start rule, tests, workflows) was implemented as written. The only touched-but-unplanned detail was adding `@discardableResult` to `CrashReportScrubber.scrub` (the in-place, same-instance contract makes the result optional for callers; the tests that call it for its effect would otherwise warn).

## Known Stubs

None.

## Threat Flags

None. The new surface (crash upload to Sentry, the CI upload to the Sentry API, the sentry-cli download) is the plan's own threat model (T-3wz-01 to T-3wz-SC); the DSN is embedded in release builds only.

## Notes for the owner

- Before the first release after this lands, create the repository secrets `SENTRY_DSN` and `SENTRY_AUTH_TOKEN` and the repository variables `SENTRY_ORGANIZATION`, `SENTRY_PROJECT` and `SENTRY_URL` (see the plan's `user_setup`); until `SENTRY_DSN` exists the release workflows fail their DSN check by design.
- Recommended in Sentry (Project Settings, Security & Privacy): keep server-side data scrubbing on and turn on Prevent Storing of IP Addresses.
- README files, the ehpanda.app privacy policy, SettingFeature and any settings UI are untouched (D-03). The simulator `EhPanda iPhone Air (261123-3wz)` was created for this task and deleted at the end (0 remain).

## Self-Check: PASSED

- Commits 9067a3092, 4c661deef and 46e929504 are ancestors of HEAD, signed, +0800.
- `AppPackage/Sources/CrashReporting/CrashReporter.swift`, `CrashReportScrubber.swift`, `actions-tool/upload-dsyms.sh` and `actions-tool/tests/test_upload_dsyms.py` exist.
- `git diff d43321737 -- README.md READMEs AppPackage/Sources/SettingFeature` is empty.
