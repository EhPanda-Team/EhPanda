---
phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele
plan: "01"
subsystem: infra
tags: [xcconfig, build-flavor, url-scheme, privacy-manifest, xcprivacy, altstore-pal]

requires: []
provides:
  - "`Config/Marketplace.xcconfig`: the AltStore PAL flavor (`.marketplace` bundle suffix, name EhPanda, scheme `ehpanda-marketplace`, stamp `altstorePAL`), for 20-04's `-xcconfig`"
  - "The channel stamp as the build setting `EHPANDA_DISTRIBUTION_CHANNEL` (default `source` in `Config/Flavor.xcconfig`), read by `App/Info.plist`"
  - "`GalleryURLParser` accepts `ehpanda-marketplace://`"
  - "`App/PrivacyInfo.xcprivacy` in every build, and `actions-tool/tests/test_privacy_manifest.py` (shape + grep-backed required-reason coverage)"
affects: [20-03, 20-04, 20-05, 20-08, 20-14]

actuals:
  tokens: 5100
  tasks: 3
  commits: 6

tech-stack:
  added: []
  patterns:
    - "A flavor is one xcconfig passed with `-xcconfig`; only a signed flavor sets the channel stamp at build time, unsigned builds keep `source` for `package-channel.sh`"
    - "The privacy manifest is comment-free and byte-equal to `plistlib.dumps(sort_keys=True)`; its reasons live in the test's docstring"

key-files:
  created:
    - Config/Marketplace.xcconfig
    - App/PrivacyInfo.xcprivacy
    - actions-tool/tests/test_privacy_manifest.py
  modified:
    - Config/Flavor.xcconfig
    - Config/Signing.xcconfig
    - App/Info.plist
    - AppPackage/Sources/AppTools/GalleryURLParser.swift
    - AppPackage/Tests/AppToolsTests/GalleryURLParserTests.swift
    - AppPackage/Sources/AppModels/Utilities/DistributionChannel.swift

key-decisions:
  - "`EHPANDA_DISTRIBUTION_CHANNEL` defaults to `source` in Flavor.xcconfig; Beta.xcconfig gets no stamp line (its path stays `package-channel.sh`), per Research §1"
  - "The manifest declares exactly UserDefaults CA92.1 and FileTimestamp C617.1, plus ProductInteraction, DeviceID and OtherDiagnosticData (unlinked, untracked, Analytics); the share extension gets none"
  - "Signing.xcconfig's release-workflow header names no flavors, so only its include comment changed (now names the distribution channel)"

patterns-established:
  - "Required-reason grep: `test_privacy_manifest.py` scans AppPackage/Sources, App and ShareExtension (no UITestSupport, no *Tests, no comment lines) for Apple's listed symbols of all five categories and fails on an undeclared one, or on a declared one with no use"

requirements-completed: [DIST-18-01]

coverage:
  - id: D1
    description: "Marketplace flavor: unsigned archive with -xcconfig Config/Marketplace.xcconfig has app.ehpanda.marketplace, app.ehpanda.marketplace.shareExtension, scheme ehpanda-marketplace in both plists, display name EhPanda, stamp altstorePAL"
    requirement: DIST-18-01
    verification:
      - kind: integration
        ref: "Task 1 verify (xcodebuild archive ×2 + plutil -extract), /tmp/ehp20-dd/task3-archives.log"
        status: pass
    human_judgment: false
  - id: D2
    description: "Default build unchanged: app.ehpanda / app.ehpanda.shareExtension, scheme ehpanda, stamp source; package-channel.sh still stamps github"
    requirement: DIST-18-01
    verification:
      - kind: integration
        ref: "Task 1 verify: default archive plist values; package-channel.sh default.app github gh.ipa → github"
        status: pass
    human_judgment: false
  - id: D3
    description: "GalleryURLParser accepts ehpanda-marketplace:// like ehpanda:// and ehpanda-beta://; ehpanda-other:// rejected"
    requirement: DIST-18-01
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppToolsTests/GalleryURLParserTests.swift#parsesGalleryRoute / rejectsInvalidGalleryRoute"
        status: pass
    human_judgment: false
  - id: D4
    description: "App/PrivacyInfo.xcprivacy declares no tracking, CA92.1, C617.1 and the three analytics data types, and ships in both archives' app (not the extension)"
    requirement: DIST-18-01
    verification:
      - kind: unit
        ref: "actions-tool/tests/test_privacy_manifest.py (9 tests)"
        status: pass
      - kind: integration
        ref: "plutil -lint; ls <archive>/EhPanda.app/PrivacyInfo.xcprivacy ×2; find …ShareExtension.appex/PrivacyInfo.xcprivacy | wc -l = 0"
        status: pass
    human_judgment: false
  - id: D5
    description: "App Store Connect accepts the manifest (Xcode privacy report / upload)"
    requirement: DIST-18-01
    verification: []
    human_judgment: true
    rationale: "Needs a signed archive and an App Store Connect upload; that is 20-08's first submission (Research §2)"

duration: 17min
completed: 2026-11-09
status: complete
---

# Phase 20 Plan 01: Marketplace flavor, channel stamp setting and privacy manifest Summary

**`Config/Marketplace.xcconfig` builds the AltStore PAL app as `app.ehpanda.marketplace` with scheme
`ehpanda-marketplace` and the build-time stamp `altstorePAL`; every build now ships `PrivacyInfo.xcprivacy`
(UserDefaults CA92.1, FileTimestamp C617.1, three unlinked analytics data types), and the default build is unchanged.**

## Performance

- **Duration:** 17 min
- **Started:** 2026-11-09T01:04:09Z
- **Completed:** 2026-11-09T01:21:38Z
- **Tasks:** 3
- **Files modified:** 9 (3 created, 6 modified)

## Accomplishments

- Marketplace flavor in `Beta.xcconfig`'s style; the stamp is the build setting `EHPANDA_DISTRIBUTION_CHANNEL`
  (`source` by default), so unsigned builds and `package-channel.sh` behave as before (D-12 amended, D-22).
- The share extension's marketplace hand-off scheme is accepted by `GalleryURLParser` (T-20-01).
- The app's privacy manifest, with a test that checks its exact shape and greps the shipped sources for every
  required-reason category (D-18, T-20-02).

## Task Commits

1. **Task 1: Marketplace flavor and the stamp setting** - `403360f9e` (feat)
2. **Task 2: Accept the marketplace hand-off scheme** - `5996bb6c4` (test, RED), `ce2ec6953` (feat, GREEN)
3. **Task 3: Privacy manifest** - `df895e555` (test, RED), `bb0fe4d46` (feat, GREEN)
4. **Deviation 1 (doc comment)** - `426b93ec9` (docs)

**Plan metadata:** this SUMMARY commit (docs).

## Verification evidence

All runs used `-derivedDataPath /tmp/ehp20-dd/dd`, archives in `$TMPDIR/ehp20-01`, unsigned
(`CODE_SIGNING_ALLOWED=NO`).

| Check | Result |
|-------|--------|
| Task 1 verify, default archive | `CFBundleIdentifier app.ehpanda`, `EhPandaDistributionChannel source`, `CFBundleDisplayName EhPanda`, scheme `ehpanda`, extension `app.ehpanda.shareExtension`, `EhPandaURLScheme ehpanda` |
| Task 1 verify, marketplace archive | `app.ehpanda.marketplace`, `altstorePAL`, `EhPanda`, `ehpanda-marketplace`, extension `app.ehpanda.marketplace.shareExtension`, `ehpanda-marketplace` |
| `package-channel.sh <default app> github gh.ipa` | `Packaged gh.ipa with EhPandaDistributionChannel = github.`; IPA plist reads `github` |
| Run twice: after Task 1 and after Task 3 | identical values both times; exit 0 |
| `grep -c EHPANDA_DISTRIBUTION_CHANNEL` Flavor / Marketplace / Info.plist | 1 / 1 / 1 |
| `grep -ci "APPICON\|SWIFT_ACTIVE_COMPILATION_CONDITIONS" Config/Marketplace.xcconfig` | 0 |
| `git diff --stat -- Config/Beta.xcconfig actions-tool/package-channel.sh .github/workflows` (base `ae4788733`) | empty |
| AppToolsTests RED (test commit only) | 15 tests, 14 passed, 1 failed (`parsesGalleryRoute`, the marketplace case) |
| AppToolsTests GREEN | `TEST SUCCEEDED`, 15/15 passed |
| AppToolsTests + AnalyticsClientTests at HEAD | `TEST SUCCEEDED`, 113 tests: 111 passed, 2 expected failures, 0 failed, 0 skipped (`theTestRunReportsSource` passes: the host's resolved stamp is `source`) |
| `swiftlint lint --strict` AppTools + AppToolsTests; DistributionChannel.swift | 0 violations in 21 files; 0 in 1 file |
| `test_privacy_manifest.py` RED (no manifest) | 9 tests, failures=1, errors=6 |
| `plutil -lint App/PrivacyInfo.xcprivacy` | OK |
| `python3 -m unittest discover -s tests` (actions-tool) | 54 tests, OK |
| Manifest in both apps | present in `default` and `marketplace` `EhPanda.app`, byte-identical to the source file |
| Manifest in the extension | `find … ShareExtension.appex/PrivacyInfo.xcprivacy \| wc -l` = 0 |
| `grep -c "CA92.1\|C617.1" App/PrivacyInfo.xcprivacy` | 2 |
| `EHPANDA_` in shipped bytes | `strings` of each app binary 0, each app plist 0, each extension plist 0; `grep -rl` over each whole `.app` 0 files |
| Scan negative control (temp tree, not in repo) | `systemUptime` → SystemBootTime and `volumeAvailableCapacityForImportantUsageKey` → DiskSpace detected; the same in `UITestSupport` and in a `///` comment ignored |

## Files Created/Modified

- `Config/Marketplace.xcconfig` - the marketplace flavor (caller: 20-04's `deploy-pal.yml`)
- `Config/Flavor.xcconfig` - `EHPANDA_DISTRIBUTION_CHANNEL = source`; header names the marketplace flavor
- `Config/Signing.xcconfig` - include comment names the distribution channel
- `App/Info.plist` - `EhPandaDistributionChannel` = `$(EHPANDA_DISTRIBUTION_CHANNEL)`
- `App/PrivacyInfo.xcprivacy` - the privacy manifest (App/ is a synchronized group; its only membership exception is `Info.plist`)
- `AppPackage/Sources/AppTools/GalleryURLParser.swift` - third scheme, doc names all three flavors
- `AppPackage/Tests/AppToolsTests/GalleryURLParserTests.swift` - marketplace and unknown-scheme cases
- `actions-tool/tests/test_privacy_manifest.py` - manifest and required-reason checks, reasons and evidence in the docstring
- `AppPackage/Sources/AppModels/Utilities/DistributionChannel.swift` - doc comment only (deviation 1)

## Decisions Made

See `key-decisions`. No question needed the owner.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Stale documentation] DistributionChannel's doc comment contradicted the new stamp source**
- **Found during:** after Task 1
- **Issue:** it said the committed `App/Info.plist` holds `source` and that the PAL job stamps `altstorePAL` with `package-channel.sh`, which D-12 amended rules out.
- **Fix:** the comment now says Info.plist reads a build setting that is `source` by default and the marketplace flavor sets it. The literal `EHPANDA_` is kept out of `AppPackage/Sources`.
- **Files modified:** `AppPackage/Sources/AppModels/Utilities/DistributionChannel.swift`
- **Verification:** swiftlint 0; AnalyticsClientTests green (113 / 111 + 2 expected failures)
- **Committed in:** `426b93ec9`

### Verification adaptations (no code impact)

- Builds and tests ran with `-derivedDataPath /tmp/ehp20-dd/dd` (the brief forbids the default DerivedData).
- Task 2 ran on a simulator created for this plan, `EhPanda iPhone Air 20-01` (iOS 27.2), passed as `id=` instead of
  the plan's name lookup (which would pick the shared `EhPanda iPhone Air`); it was deleted afterwards.
- `swiftlint` is not on PATH; the SwiftLint binary from the package's artifact bundle in that DerivedData was used.
- Xcode 27.2 prints no `Test run with` line for Swift Testing, so counts come from
  `xcrun xcresulttool get test-results summary` on `-resultBundlePath` bundles.
- The `EHPANDA_` check was widened from the binary and plist to every file of both bundles.

---

**Total deviations:** 1 auto-fixed (Rule 1). **Impact:** documentation only; no scope creep.

## Issues Encountered

None.

## Open items

- The Xcode privacy report needs a signed archive; App Store Connect's acceptance is checked by 20-08's upload (D5).
- `Signing.xcconfig`'s "Release CI" paragraph says release identifiers stay at the upstream defaults, which has been
  untrue for the beta since Phase 20 D-11 and is for the marketplace flavor too. Pre-existing and outside this
  plan's "only if it names flavors" rule; left alone.
- `DistributionChannelTests.theTestRunReportsSource`'s comment says the host plist "says `source`"; it now resolves
  to `source` from the default setting. Still true in effect; unchanged.
- DIST-18-01 stays Pending in REQUIREMENTS.md: 20-14 shares it.

## User Setup Required

None.

## Next Phase Readiness

Ready for 20-02 (wave 1). 20-03 and 20-04 can use `Config/Marketplace.xcconfig` and the stamp setting as is.

## Self-Check: PASSED

- key-files.created exist: `Config/Marketplace.xcconfig`, `App/PrivacyInfo.xcprivacy`, `actions-tool/tests/test_privacy_manifest.py`
- commits for 20-01 on this branch: `403360f9e`, `5996bb6c4`, `ce2ec6953`, `df895e555`, `bb0fe4d46`, `426b93ec9`, all `G`, all +08:00
- every task's acceptance criteria and the plan's `<verification>` re-run green (table above)

---
*Phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele*
*Completed: 2026-11-09*
