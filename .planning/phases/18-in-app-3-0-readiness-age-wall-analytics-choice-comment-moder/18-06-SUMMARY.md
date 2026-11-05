---
phase: 18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder
plan: "06"
subsystem: localization
tags: [localization, xcstrings, copy, age-wall, analytics-choice, moderation]

requires: []
provides:
  - "`18-copy-check.py`: byte-for-byte check of the catalogs against the three approved copy files, with retired-text detection and `--self-test` (11 cases)"
  - "Resources catalog: `age_wall.*` (6), `consent.*` (11, incl. `consent.level.recommended`), `blocked_users*` (4), each with a public `.RLocalizable` forwarder"
  - "Resources Constant catalog: `contact.privacy_policy` = `https://ehpanda.app/privacy` (A-6), forwarded as `.RConstant.contactPrivacyPolicy`"
  - "DetailFeature catalog: 16 `comment.*` keys; generated `commentReport(_:)`, `commentReportConfirmBody(_:_:)` (site, author), `commentBlock(_:)`, `commentBlockConfirmTitle(_:)`, `commentUnblock(_:)`"
affects: [18-05, 18-09, 18-10, 18-11, 18-12]

actuals:
  tokens: 9000
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Catalog values are inserted by script from the copy check's expected map, never retyped"
    - "Copy precedence is encoded once in the check script; later plans (18-12 `--readmes`) extend the same script"

key-files:
  created:
    - .planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-copy-check.py
  modified:
    - AppPackage/Sources/Resources/Resources/Localizable.xcstrings
    - AppPackage/Sources/Resources/Resources/Constant.xcstrings
    - AppPackage/Sources/Resources/ResourceStringSymbols.swift
    - AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings

key-decisions:
  - "The retired level name (`None` and its five translations) is matched only as the whole value of a `consent.*` key; every retired sentence is matched as a substring anywhere. A substring match on \"None\" would flag unrelated keys such as DetailFeature's `metadata.none`"
  - "The retired list is derived, not hand-typed: every copy-file row a later source replaces, plus the `consent.level.none*` rows and Revision 3's Basic line. The self-test asserts it holds all eight retired rows in all six languages (48 texts)"
  - "The retired-text and retired-key scan covers every `.xcstrings` under `AppPackage/Sources` (Localizable and Constant), a superset of the plan's Localizable-only scope"
  - "The check also requires `extractionState: manual` on every new key, `shouldTranslate: false` on `contact.privacy_policy`, and the same placeholders in every locale as in en"
  - "New entries are appended at the end of each catalog in that file's own formatting: Xcode's `\" : \"` style with alphabetical locales in the Resources catalog, `\": \"` style with en first and no trailing newline in the DetailFeature and Resources Constant catalogs. The insert script asserted every existing entry parses unchanged"
  - "Forwarders sit in alphabetical position: `ageWall*` and `blockedUsers*` after `actions`, `consent*` after `clear`, `contactPrivacyPolicy` before `responseGalleryUnavailable`"

patterns-established:
  - "Phase 18 copy lives in the copy files; `18-copy-check.py` is the gate that keeps the catalogs equal to them"

requirements-completed: [AGE-18-01, CONSENT-18-01, UGC-18-01]

coverage:
  - id: D1
    description: "Copy check script with self-test (changed apostrophe, missing zh-Hant, the five retired descriptions/intro, missing Recommended, title line break, consent.level.none key)"
    requirement: CONSENT-18-01
    verification:
      - kind: script
        ref: "python3 .planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-copy-check.py --self-test (11/11 cases passed)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every approved Phase 18 string in its catalog, six locales, translated, byte-identical; no retired text or key in any catalog"
    requirement: AGE-18-01
    verification:
      - kind: script
        ref: "python3 .planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-copy-check.py (38 keys x 6 locales verbatim; 48 retired texts absent)"
        status: pass
      - kind: command
        ref: "the plan's eleven acceptance greps (Revision 2/5/6 lines present once, retired lines 0, no consent.level.none)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Cross-module forwarders and generated comment symbols compile"
    requirement: UGC-18-01
    verification:
      - kind: build
        ref: "xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda -destination iOS Simulator FFE7E686 (BUILD SUCCEEDED, 0 warnings)"
        status: pass
      - kind: lint
        ref: "swiftlint lint --strict --no-cache --config .swiftlint.yml AppPackage/Sources/Resources (0 violations)"
        status: pass
    human_judgment: false

duration: 3 min
completed: 2026-11-05
status: complete
---

# Phase 18 Plan 06: Approved strings and the copy check Summary

**All 38 approved Phase 18 keys are in the catalogs in en, de, ko, ja, zh-Hans and zh-Hant, byte-identical to the
copy files: the age wall, the analytics choice with the Revision 2 Minimal line, the Revision 5 intro, the Revision 6
Basic and Full lines and the Recommended label, Blocked Users, the comment report, warning and blocking strings, and
the privacy URL. `18-copy-check.py` proves it and fails on any drift or retired text.**

## Performance

- **Duration:** 3 min (wall clock for the commits; reading the plan and copy files came first)
- **Started:** 2026-11-05T07:50:35Z
- **Completed:** 2026-11-05T07:53:33Z
- **Tasks:** 2
- **Files modified:** 5 (1 created, 4 modified)

## Accomplishments

- **`18-copy-check.py`** (Python 3, standard library only):
  - Parses every `| key | en | de | ko | ja | zh-Hans | zh-Hant |` table of the three copy files and strips a key
    cell's parenthesised suffix. Glossary tables ("One term per concept") are skipped.
  - Reads the Minimal file's first table, Revision 2, Revision 3 (retired text only), Revision 5 and both Revision 6
    tables, and stops with an error if any of those sections loses its table.
  - Precedence: Revision 6 (Basic and Full descriptions, Recommended), Revision 5 (`consent.body`) and Revision 2
    (Minimal description) > the Minimal file's first table > the first-launch file.
  - Only placeholders are rewritten: `{site}` → `%1$@` and `%@` → `%2$@` in `comment.report.confirm_body`;
    `{site}` → `%@` in `comment.report`.
  - Findings: missing catalog, key or locale; state not `translated`; any byte difference; a line break (`\n`, `\r`,
    U+2028, U+2029); a placeholder set different from en; `extractionState` not `manual`; a translatable privacy
    URL; a `consent.level.none*` key or any retired text in any `.xcstrings` under `AppPackage/Sources`.
  - `--self-test` builds temporary catalogs from the expected map and runs 11 cases (correct passes; curly
    apostrophe, missing zh-Hant, msg-1805 Minimal description, first-launch Basic description, msg-1805
    `consent.body`, Revision 3 Basic description, first-launch Full description, missing
    `consent.level.recommended`, `consent.title` with `\n`, `consent.level.none` key each fail). It also asserts the
    retired list holds all eight retired rows in all six languages.
  - `--root DIR` checks another checkout.
- **Resources catalog:** `age_wall.title`, `.body`, `.declaration`, `.continue`, `.continue_hint`, `.footnote`;
  `consent.title`, `.body` (Revision 5), `.footer`, `.privacy_link`, `.level.minimal`, `.level.minimal.description`
  (Revision 2), `.level.basic`, `.level.basic.description` (Revision 6), `.level.recommended` (Revision 6),
  `.level.full`, `.level.full.description` (Revision 6); `blocked_users`, `.footer`, `.empty`, `.unblock`.
- **Resources Constant catalog:** `contact.privacy_policy` = `https://ehpanda.app/privacy`, `shouldTranslate: false`,
  the same value in all six locales (AGENTS.md rule for non-translated keys).
- **`ResourceStringSymbols.swift`:** 21 `RLocalizable` forwarders and `RConstant.contactPrivacyPolicy`. None of the
  Resources keys takes an argument, so all are plain `static var`s.
- **DetailFeature catalog:** `comment.report`, `.report.confirm_title`, `.report.confirm_body`, `.report.open`,
  `.filter.title`, `.filter.body`, `.filter.edit`, `.filter.post_anyway`, `.block`, `.block.confirm_title`,
  `.block.confirm_body`, `.block.confirm`, `.blocked_row`, `.blocked_row.show`, `.blocked_row.hide`, `.unblock`.
  String arguments stay positional per AGENTS.md; the generated symbols are `commentReport(_:)`,
  `commentReportConfirmBody(_:_:)` (site first, author second), `commentBlock(_:)`,
  `commentBlockConfirmTitle(_:)` and `commentUnblock(_:)`.

## Task Commits

1. **Task 1: The copy check script:** `01eb8449f` (test). Self-test 11/11 before Task 2; the real run then exited 1
   with 38 "missing" lines (21 Resources, 16 DetailFeature, 1 Constant).
2. **Task 2: Catalog entries and forwarders:** `599f6eceb` (feat).

## Files Created/Modified

- `.planning/phases/18-.../18-copy-check.py`: the check and its self-test.
- `AppPackage/Sources/Resources/Resources/Localizable.xcstrings`: 21 keys.
- `AppPackage/Sources/Resources/Resources/Constant.xcstrings`: `contact.privacy_policy`.
- `AppPackage/Sources/Resources/ResourceStringSymbols.swift`: 22 forwarders.
- `AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings`: 16 keys.

## Decisions Made

See `key-decisions` above. In short: the retired level name is matched only as a `consent.*` value; the retired
list is derived from the copy files and checked for completeness; the scan covers every catalog; each catalog keeps
its own formatting; forwarders are in alphabetical position.

## Deviations from Plan

None in scope or behaviour. Two notes:
1. **Wider retired scan.** The plan scopes the retired-text scan to `AppPackage/Sources/**/Localizable.xcstrings`;
   the script scans every `.xcstrings` there (Constant catalogs too). Stricter, no false positive today.
2. **Extra checks.** `extractionState: manual`, `shouldTranslate: false` on the URL and per-locale placeholder
   equality are checked too; the plan states them as properties of the entries, not as script findings.

**Total deviations:** 0 auto-fixes; 2 notes. **Impact:** none.

## Issues Encountered

- `swiftlint` is not on PATH; lint ran with the package's plugin binary
  (`AppPackage/.build/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint`) and
  the root `.swiftlint.yml`.

## Left for later

- `shareAnalyticsData` and `shareAnalyticsDataFooter` remain in SettingFeature's catalog, unread since 18-02. This
  plan's scope does not touch them (prohibition: "`shareAnalyticsDataFooter` is not removed here"). 18-10 reuses
  `shareAnalyticsData` as the picker's row label (D-07) and removes `shareAnalyticsDataFooter`.
- D-06g (owner msg 1898) is layout only: `consent.body` and `consent.footer` stay separate keys, as added here; 18-09
  joins them in one `Text` (one space in en, de, ko; none in ja, zh-Hans, zh-Hant).
- OI-2: the privacy URL path (`/privacy`, A-6) is still to be confirmed by the website owner before Phase 20.

## Verification

- `18-copy-check.py --self-test`: 11/11 cases passed, exit 0.
- `18-copy-check.py`: "38 keys x 6 locales verbatim; 48 retired texts absent", exit 0.
- `xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda -destination "platform=iOS Simulator,id=FFE7E686-..."`:
  BUILD SUCCEEDED, 0 warnings. The log shows `GenerateStringSymbols` and `CompileXCStrings` for Resources and
  DetailFeature and a recompile of `ResourceStringSymbols.swift`.
- `swiftlint lint --strict --no-cache --config .swiftlint.yml AppPackage/Sources/Resources`: 0 violations.
- Acceptance greps on the Resources catalog: Revision 2 Minimal, Revision 6 Basic and Full, Revision 5 intro and the
  `"consent.level.recommended"` key each 1; Revision 3 Basic, first-launch Basic and Full, msg-1805 intro and
  "EhPanda can send anonymous analytics" each 0; no catalog contains `consent.level.none`.

## User Setup Required

None.

## Next

Ready for the remaining plans: 18-05 and 18-11 use the generated `comment.*` symbols; 18-09 the `age_wall.*` and
`consent.*` forwarders and `.RConstant.contactPrivacyPolicy`; 18-10 the `consent.level.*`, `blocked_users*` and
privacy forwarders; 18-12 re-runs the check and adds `--readmes`.

## Self-Check: PASSED

- `18-copy-check.py` exists; commits `01eb8449f` and `599f6eceb` are on `feature/gsd-phase-18`.
- All Task 1 and Task 2 acceptance criteria and the plan `<verification>` were re-run and pass.
