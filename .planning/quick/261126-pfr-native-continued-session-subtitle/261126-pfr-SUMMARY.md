---
phase: quick-261126-pfr
plan: 01
subsystem: downloads, localization
tags: [localization, xcstrings, continued-processing, tests]
requires: []
provides:
  - "Native, middle-dot-free `continued_session.subtitle` wording in all six locales"
affects:
  - AppPackage/Sources/Resources/Resources/Localizable.xcstrings
  - AppPackage/Tests/DownloadsFeatureTests
key-files:
  modified:
    - AppPackage/Sources/Resources/Resources/Localizable.xcstrings
    - AppPackage/Sources/DownloadClient/DownloadClient+WorkingManifestReconciliation.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Tests/DownloadsFeatureTests (13 files)
decisions:
  - "Substitution names, argNum and lld specifiers unchanged; ja and ko put total before completed in the outer value"
metrics:
  tasks: 3
  files: 16
  insertions: 200
  deletions: 200
status: complete
commits: 1
plan_head_before: b7294d401afe8f9091f06388603274e56cb557f3
plan_head_after: 38fc3f9b9ac7004a51773333e549b1eb6f4dde0b
actuals:
  tokens: 45000
  tasks: 3
  commits: 1
completed: 2026-11-26
---

# Phase quick-261126-pfr Plan 01: Native continued-session subtitle Summary

Replaced the decorative middle dot in the continued-processing card subtitle with native per-locale wording (en `6 of 14 pages in 2 galleries`, de `6 von 14 Seiten aus 2 Galerien`, ja, ko, zh-Hans, zh-Hant as locked in CONTEXT) and moved every pinned English rendering in DownloadsFeatureTests and two DownloadClient doc comments to the new form.

## Commit

- `38fc3f9b9`: `Reword the continued-processing card subtitle`, on `develop`; signed (`G`); not pushed
- 18 files, 216 insertions, 216 deletions
- Made first as `5d26d62e9` (16 files, 200/200; author and committer dates `2026-11-26T17:43:54+08:00`) on branch
  `claude/middle-dot-subtitle-493a8f`, which was cut from `main`, then cherry-picked onto `develop` on 2026-11-26
  and the branch deleted. The two extra files are tests develop
  gained after the branch point (`DownloadContinuedSessionDeletionTests`, `DownloadQueueInterruptTests`),
  which now expect the new subtitle too; develop's removal of the two delete-path ledger tests was kept.

## What changed

- Catalog: exactly 14 value lines of `continued_session.subtitle` (six outer values, eight ja/ko/zh substitution values), edited line-anchored with per-line assertions; catalog numstat 14/14, no JSON re-serialization.
- Tests and source comments: 182 pattern replacements (181 in 13 test files, 1 in `DownloadClient+WorkingManifestReconciliation.swift`), plus four partial quotes (`contains("of 12 pages")`, `contains("of 16 pages")`, the `2 of 2 pages` doc comment, the `"0 of 4 pages"` doc comment).
- Untouched on purpose: `DownloadRunProgressOverlayTests.swift:14` (out of scope) and the four `"0 / 4 pages"` spy inputs in `DownloadContinuedSessionIdentityTests.swift`.

## Verification

- Catalog check: `catalog OK` (outer values, bare `%arg` values, argNum/lld, plural category sets, rendered (6, 14, 2) examples and en/de singulars).
- Task 2 gates: every grep gate at its expected value; test-plus-source numstat `15 186 186`.
- SwiftLint: binary `$HOME/Library/Developer/Xcode/DerivedData/EhPanda-bjhqwuemjjedwrfnzlznzjvcttjq/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint`, version 0.65.1; `lint --strict --quiet` on `AppPackage/Sources/DownloadClient` and `AppPackage/Tests/DownloadsFeatureTests`: no output, exit 0.
- DownloadsFeatureTests (app scheme, FeatureTests plan, `EhPanda iPhone Air (middle-dot)`): 585 test cases passed, 0 failed, `** TEST SUCCEEDED **` [380.215 sec]. Xcode 27.2 prints per-case lines and no Swift Testing summary line; the orchestrator accepted this in place of the planned `Test run with N tests` line. No warning named Localizable.xcstrings, a DownloadsFeatureTests file, or either touched DownloadClient file.

## Deviations from Plan

None. The plan was executed as written. The only difference was the missing `Test run with N tests` line, which was paused on and then accepted by the orchestrator (see above).

## Deferred

The drained end state renders as `0 of 1 page in 0 galleries`: the one-page progress floor reaches the text while the gallery count is zero, which contradicts itself in every language. No wording can fix it; it belongs to the code that supplies the numbers. Reported to the owner as a follow-up, not fixed here.

## Known Stubs

None.

## Threat Flags

None. All three substitutions remain `lld` integers, so no gallery title or GID can reach the card.

## Self-Check: PASSED

- Commit `38fc3f9b9` is an ancestor of `develop`; 18 files, 216/216. DownloadsFeatureTests on `develop` after the
  cherry-pick: 663 passed, 0 failed (iOS 27.2 simulator).
- This SUMMARY exists; no docs artifacts were committed.
