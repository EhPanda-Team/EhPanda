---
phase: 15-continued-background-downloads
plan: 76
subsystem: logging
tags: [swift, filesystem, migration, apfs, case-sensitivity, files-app, tdd]

requires:
  - phase: 15-continued-background-downloads
    provides: "The owner's first Deferred Follow-Up from 15-UAT.md (test 6, deferred 2026-08-08)"
provides:
  - "`Defaults.FilePath.logs == \"Logs\"`, so the Files-app folder's displayed name begins uppercase"
  - "A one-time launch migration that moves a pre-rename install's logs onto the new name"
  - "Regime classification as a pure, total function, so the merge regime is pinned on a host whose volume cannot represent it"
  - "A merge that never overwrites and never deletes, with the collision disposition decided and justified"
affects: [activity-logs, files-app-visibility, app-launch, phase-15-uat]

tech-stack:
  added: []
  patterns:
    - "Classify a filesystem regime from the DISAGREEMENT between two observations (a directory listing and a path probe) rather than from a volume capability flag — the disagreement is the phenomenon that breaks the API, the flag is only correlated with it"
    - "Gate a host-dependent test on the precondition the FIXTURE needs (can two case variants be stored?), not on the property the code branches on (does a case variant resolve?) — the simulator separates the two"
    - "Freeze a legacy constant as a historical fact instead of deriving it from the current one, so a future rename cannot silently redefine what a migration reads FROM"

key-files:
  created:
    - AppPackage/Sources/AppTools/LogsDirectoryMigration.swift
    - AppPackage/Tests/AppToolsTests/LogsDirectoryMigrationTests.swift
  modified:
    - AppPackage/Sources/AppTools/Defaults.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift
  deleted: []

key-decisions:
  - "DEC-A: the both-exist case is gated on a probe that STAGES two case variants, not on a `fileExists` answer — the simulator reports case-SENSITIVE lookups over a case-INSENSITIVE backing store, so the obvious probe enabled a case whose fixture could not be built (found by watching it fail, deviation 1)"
  - "DEC-B: regime classification is a pure, total function of (storedNames, currentSpellingResolves), so all four regimes — including the merge this host cannot stage — are pinned by test on any volume; only the merge's filesystem STAGING stays host-gated (enforced by test)"
  - "DEC-C: the legacy name is a frozen private literal, NOT `Defaults.FilePath.logs.lowercased()` — a derived legacy name would mean a future rename silently redefines the migration's SOURCE and strands the directory this plan just created (derived by argument)"
  - "DEC-D: the device regime keeps a single atomic `moveItem`; staging is used only where atomicity is unavailable anyway, so the >99.99% path has no crash window in which logs could sit under a name nothing reads (derived by argument)"
  - "DEC-E: a merge skips a colliding name and keeps the DESTINATION copy, because run-log names embed day + time-of-day + count, so a shared name is the same run and the destination copy is the one the current process may still be appending to (derived by argument; the disposition is enforced by test from both sides)"
  - "DEC-F: the plan's acceptance criterion `rg '\"logs\"' → no matches` is unsatisfiable alongside its own required artifact and was replaced with a criterion that carries the intent — exactly one lowercase literal, the frozen legacy constant, used only as a move SOURCE (deviation 2)"

patterns-established:
  - "Ask the filesystem the question your fixture asks, not the question your code asks: a probe measuring lookup semantics and a probe measuring storage capability disagree on the iOS simulator, and only the second one gates a fixture correctly"
  - "Give a migration an Outcome instead of a throw, and let a partial failure leave a state the next launch re-classifies into the same regime — retry becomes a property of the design rather than a code path"

requirements-completed: []

coverage:
  - id: D1
    description: "The logs folder's displayed name begins with an uppercase letter"
    verification:
      - kind: unit
        ref: "LogsDirectoryMigrationTests.theLogsDirectoryNameBeginsWithAnUppercaseLetter — asserts `Defaults.FilePath.logs.first.isUppercase` (the requirement) and `== \"Logs\"` (the spelling chosen for it)"
        status: pass
    human_judgment: false
  - id: D2
    description: "An existing install's logs are moved onto the new name rather than stranded, and the move is observable as a LITERAL stored name"
    verification:
      - kind: unit
        ref: "theLegacyDirectoryIsRenamedToTheUppercaseStoredName — `run` returns `.renamed`, the documents listing is exactly `[\"Logs\"]`, and both run files are byte-identical inside it"
        status: pass
    human_judgment: false
  - id: D3
    description: "All four regimes are classified correctly, including the merge regime this host's volume cannot represent"
    verification:
      - kind: unit
        ref: "Four pure cases over `regime(storedNames:currentSpellingResolves:)`: nothingToMigrate (×2 inputs), rename, renameThroughStaging, merge"
        status: pass
    human_judgment: false
  - id: D4
    description: "The merge moves disjoint files, skips colliding names with the destination bytes surviving, and removes only an emptied source"
    verification:
      - kind: unit
        ref: "mergeDecision pinned from both sides (everyDisjointNameIsMoved, aNameAlreadyInTheDestinationIsSkipped) plus two filesystem cases over `mergeContents(of:into:)` with arbitrary directory names, so this half runs on every host"
        status: pass
    human_judgment: false
  - id: D5
    description: "The migration is idempotent and mints nothing"
    verification:
      - kind: unit
        ref: "aSecondRunFindsNothingToMigrateAndLeavesTheMigratedLogsIntact; aFreshInstallWithOnlyTheNewDirectoryIsNothingToMigrate; emptyDocumentsIsNothingToMigrateAndMintsNoDirectory (asserts the listing stays empty)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Failure is contained: it is reported, never thrown, and never damages the destination"
    verification:
      - kind: unit
        ref: "anUnreadableDocumentsDirectoryReportsFailureRatherThanNothingToMigrate; anUnreadableSourceFailsWithoutTouchingTheDestination (destination listing and bytes asserted unchanged)"
        status: pass
    human_judgment: false
  - id: D7
    description: "Every consumer of the logs path derives from the single constant"
    verification:
      - kind: other
        ref: "Re-derived census: `rg '\"logs\"' App AppPackage/Sources ShareExtension -g '*.swift'` → 1 match, the migration's frozen legacy SOURCE constant. Six consumer sites all read `FileUtil.logsDirectoryURL`, which reads the constant"
        status: pass
    human_judgment: false
  - id: D8
    description: "The both-exist merge is routed to correctly when both spellings are stored"
    verification:
      - kind: unit
        ref: "bothStoredSpellingsRouteToAMerge — SKIPPED on this host (its fixture cannot be staged). Its classification half is carried by twoStoredSpellingsAreAMerge and its application half by the two mergeContents cases; only the composition of the two is unexercised here"
        status: partial
    human_judgment: true
    rationale: "The regime that only a case-sensitive volume can represent is the device regime. Both of its halves are pinned independently on this host, and the case that joins them is written and will run unskipped on any case-sensitive volume — but on THIS machine nothing observed the join. The honest label is 'decomposed and pinned in halves', not 'verified end to end'."
  - id: D9
    description: "The Files-app deep link opens the renamed folder"
    verification:
      - kind: other
        ref: "`ApplicationClient.openFileApp` builds `shareddocuments://` + `FileUtil.logsDirectoryURL.path`, so the path derives from the constant — but no test and no device run observed the link opening `Logs`"
        status: partial
    human_judgment: true
    rationale: "Derived by argument only. The deep link's behavior is a system integration; it rides the next device UAT pass."

duration: 45min
completed: 2026-08-11
status: complete
---

# Phase 15 Plan 76: Capitalize the Logs Directory Summary

**The owner asked for a capital letter; the work was the migration underneath it — and the interesting part is that this machine is a *third* filesystem regime that neither the plan nor the obvious probe accounts for.**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-08-10T14:42Z (local 23:42 JST)
- **Completed:** 2026-08-10T15:27Z (local 2026-08-11 00:27 JST)
- **Tasks:** 2 (RED / GREEN)
- **Files created:** 2 · **modified:** 2 · **+701 / −1**

## Accomplishments

- **The simulator is neither of the two regimes the plan describes, and finding that out is what fixed the test gate.** The plan (and the prompt) frame this as case-sensitive device vs. case-insensitive dev host. Measured directly, the iOS simulator container is *both*: `fileExists(".../Logs")` answers **NO** while `logs` is stored — case-SENSITIVE lookup semantics — but `createDirectory(".../Logs")` alongside `logs` fails with **EIO**, because the macOS APFS volume underneath is case-insensitive and cannot store the second entry. From the Mac side the same path reports the opposite (`fileExists` → True, `mkdir` → `EEXIST`). So a gate written as "is the volume case-sensitive?" via a lookup probe answers **true** here and enables a case whose fixture is impossible to build. That is exactly what happened: the first RED run showed `bothStoredSpellingsRouteToAMerge` *running* and dying on its own fixture setup. The gate now measures the precondition the fixture actually needs — stage `logs` and `Logs`, then require the listing to hold two entries — which answers correctly on all three regimes.
- **Regime classification became a pure function, so the regime this host cannot stage is still pinned.** `regime(storedNames:currentSpellingResolves:)` is total over its inputs and returns one of `nothingToMigrate / rename / renameThroughStaging / merge`. Four unit cases pin all four on any volume. That is what keeps the skipped fixture case from being a coverage hole: the merge regime's *classification* is pinned by `twoStoredSpellingsAreAMerge`, and its *application* by two `mergeContents(of:into:)` cases driven with ordinary directory names (`source`/`destination`) that any volume can hold. Only the composition of the two halves is host-gated (coverage D8).
- **The case-insensitive detection is derived, not assumed.** `fileExists` alone cannot tell "the destination exists" from "you are looking at the source through its other spelling". Read *against* the directory listing it separates them exactly: a name that **resolves without being stored** must be an alias for one that is. That single sentence is the whole basis for choosing the staged rename, it is written at `Regime.renameThroughStaging`, and it is asserted by `aDestinationThatResolvesWithoutBeingStoredIsTheCaseInsensitiveSignature`.
- **The device path stayed atomic.** iOS's data volume is case-sensitive, so on every real install the destination is genuinely free and the migration is one `rename(2)`. Staging is used only where atomicity is unavailable anyway. This matters because the staged form has a window — a crash between its two moves — in which logs would sit under a name nothing reads; that window now exists only on volumes no user has. (The staging name still leads with `Logs`, so even a stranded directory reads correctly in the Files app.)
- **Nothing is overwritten and nothing is deleted.** A merge skips any name the destination already has and keeps the destination copy; the legacy directory is removed only if the merge emptied it, so a skipped file is never deleted along with its folder. The *why* is stronger than the plan's "deterministic": run-log names embed day, time-of-day and run count, so a shared name is the **same run**, and the destination copy is the one the current process may still be appending to — overwriting it is the one disposition that could destroy live data.
- **A migration that cannot run degrades instead of failing loudly.** Nothing in `LogsDirectoryMigration` throws; every failure becomes an `Outcome` the launch effect logs. A partial merge leaves the remaining files in place, and the next launch re-classifies into the same regime and retries — retry is a property of the design, not a code path.
- **980 tests, 22 targets, 0 failures, 1 skipped** (963 baseline + 17 new), clean build **0 warnings / 0 errors** from fresh derived data, SwiftLint `--strict` **0 violations** over all four changed files.

## Task Commits

1. **Task 1 (RED): pin the migration's regimes** — `0f45c40f` (test)
2. **Task 2 (GREEN): constant, migration, launch wiring** — `f8513360` (feat)

## The RED gate was watched failing

`0f45c40f` was committed against skeleton signatures with do-nothing bodies. The run at that commit:

```
➜ Test bothStoredSpellingsRouteToAMerge() skipped: "Two directories differing only in
   case cannot be stored on this host's volume."
✘ Test run with 17 tests in 1 suite failed after 0.017 seconds with 22 issues.
** TEST FAILED **
```

12 of the 16 running cases failed, including the requirement itself (`Expectation failed: (initial → l).isUppercase → false`). The four that passed at RED are the ones whose expected answer *is* "do nothing" (`nothingToMigrate` for empty documents, for a new-only install, for a stored regular file, and for the no-legacy-name classification) — unavoidable for a stub of a four-case enum, and stated here rather than left for a reader to notice.

## Consumer disposition — re-derived, not inherited

The plan supplied this table; it was re-derived from source with a case-insensitive sweep that also covered `Info.plist`, entitlements, `project.pbxproj`, string catalogs and interpolated paths. **It is correct as given** — six consumers, one change site, and no other path literal anywhere.

| Site | Disposition |
|---|---|
| `AppPackage/Sources/AppTools/Defaults.swift:45` | **The one change site.** `"logs"` → `"Logs"` |
| `AppTools/FileUtil.swift:5` `logsDirectoryURL` | Inherits — the only path builder, reads the constant |
| `LogsClient.swift:90` `listRunFiles` | Inherits via `FileUtil` |
| `LogsClient.swift:97` `nextRunCount` | Inherits via `FileUtil` |
| `LogsClient.swift:106` `currentRunFileURL` | Inherits via `FileUtil`; its `appendToRunFile` `createDirectory` is what creates `Logs` lazily, which is why the migration never mints a directory |
| `LogsClient.swift:148` (`noop`) | Inherits via `FileUtil` |
| `ApplicationClient.swift:49` `openFileApp` | Inherits — builds `shareddocuments://` + `FileUtil.logsDirectoryURL.path` (coverage D9: derived, not observed) |
| `App/Info.plist:170` `UIFileSharingEnabled` | Untouched — it publishes `Documents`, not a folder name; it is *why* the name is user-visible |

Non-Swift sweep: `rg -ni 'logs'` over `App/Info.plist`, entitlements and `ShareExtension` → **no matches**. The only `logs`-ish hits elsewhere in the repo are `app_activity_logs*` localization keys and `ConfirmationDialogState`/`LOCALIZATION_PREFERS_STRING_CATALOGS` substring noise, none of which is a path.

## Every claim, labelled by what backs it

| Claim | Backed by |
|---|---|
| The displayed name begins with an uppercase letter | **Enforced by test** — `theLogsDirectoryNameBeginsWithAnUppercaseLetter` asserts the requirement (`first.isUppercase`) separately from the spelling (`== "Logs"`) |
| An existing install's logs land in a directory literally named `Logs`, contents intact | **Enforced by test** — documents listing `== ["Logs"]` read from `contentsOfDirectory`, plus byte equality on both run files |
| All four regimes are classified correctly | **Enforced by test** — four pure cases; host-independent |
| A colliding name is skipped and the destination bytes survive | **Enforced by test** from both sides (decision + filesystem application) |
| The migration is idempotent | **Enforced by test** — a second `run` on a migrated fixture returns `nothingToMigrate` with contents unchanged |
| The migration creates no directory | **Enforced by test** — empty documents comes out with an empty listing |
| A user's regular file named `logs` is left alone | **Enforced by test** — `aRegularFileNamedLikeTheLegacyDirectoryIsLeftAlone` |
| Failure is reported and never thrown, with no destination damage | **Enforced by test** — two cases; and by the type system, since `run`/`mergeContents` are non-throwing |
| Every consumer derives from the one constant | **Derived by argument, counted from source** — the census above; one lowercase literal survives and it is a move SOURCE only |
| The simulator reports case-sensitive lookups over a case-insensitive store | **Measured, twice** — from the Mac (`fileExists` True, `mkdir` EEXIST) and inside the simulator (`fileExists` False, `createDirectory` EIO, quoted in deviation 1) |
| The device regime is one atomic rename | **Derived by argument** — iOS data volume is case-sensitive ⇒ `currentSpellingResolves` is false ⇒ the `.rename` branch; the classification is enforced by test, the *volume's* case-sensitivity is not something this repo can assert |
| The both-exist merge works end to end | **Decomposed and pinned in halves; NOT observed joined** (coverage D8) — its fixture cannot be staged here |
| `openFileApp` opens the renamed folder | **Derived by argument only** (coverage D9) — rides the next device UAT pass |
| No lint suppression, warning-free | **Enforced by gate** — fresh-derived-data build 0 warnings; SwiftLint `--strict` 0 violations over 4 files |

## Race tolerance — the plan's claim, corrected

The plan states the migration is race-tolerant because "a racing write creates `Logs` and the both-exist merge regime then absorbs the legacy `logs` contents". That is true, but not always *within the same launch*, and the summary should say which:

| Regime | A log write races the migration | Absorbed |
|---|---|---|
| `.rename` (device) | The write creates `Logs` after classification; `moveItem` then fails on a non-free destination | **Next launch** — it re-classifies as `.merge` and folds the two together. Nothing is lost; the outcome for this launch is `failed`, logged at error level |
| `.renameThroughStaging` (case-insensitive) | The write lands inside the one shared directory and travels with the rename | **In place**, no action needed |
| `.renameThroughStaging`, write arriving *between* the two moves | The write creates a fresh `Logs`; the second move fails | **In launch** — the staged contents are merged into whatever now stands at the destination, and if even that fails they are moved back under the legacy name so nothing is stranded |

No strict ordering against launch logging is claimed, because the migration rides an async `.run` effect and none is available. This derivation is written at the type, not only here.

## Decisions Made

- **DEC-A — gate on what the fixture needs, not on what the code branches on.** Recorded above. The two probes are equivalent on a real device and on a real Mac volume, and they disagree exactly on the machine the tests run on. *Found by watching the wrong gate fail.*
- **DEC-B — classification as a pure total function.** This is what converts "the merge regime is untestable here" into "only the composition is untestable here". *Enforced by test.*
- **DEC-C — the legacy name is frozen, not derived.** `Defaults.FilePath.logs.lowercased()` would read as elegant and is a trap: rename the constant again and the migration silently starts reading from a directory that does not exist, while the directory *this* plan created becomes the stranded one. The literal carries a doc comment saying so. *Derived by argument.*
- **DEC-D — atomicity where it is available.** A single `rename(2)` has no window; the staged form has one. Since the only regime that occurs in the field is the one where the atomic move is legal, the branch buys real crash-safety for the only users who exist. *Derived by argument.*
- **DEC-E — the destination copy wins a collision.** Justified by the naming scheme rather than by determinism: day + time-of-day + count means a shared name is the same run, and the destination copy is the live one. *Derived by argument; the disposition is enforced by test.*
- **DEC-F — the plan's `"logs"` census criterion was replaced.** See deviation 2.
- **A self-merge guard was added.** `regime` returns `nothingToMigrate` outright if `Defaults.FilePath.logs` is ever equal to the legacy name, so a future revert of the constant can never route one directory into itself as both source and destination.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] The test gate for the both-exist regime measured the wrong property**

- **Found during:** Task 1, on the first RED run
- **Issue:** The gate was written as "is the host volume case-sensitive?", probed the way the migration itself probes (`fileExists` for a case variant). Inside the simulator that answers **true**, so `bothStoredSpellingsRouteToAMerge` ran instead of skipping and failed while building its own fixture: `Error Domain=NSCocoaErrorDomain Code=512 "The file "Logs" couldn't be saved in the folder "Documents"" ... NSUnderlyingError Code=5 "Input/output error"`. The simulator presents case-sensitive *lookups* over a case-insensitive *backing store*, which no part of the plan anticipates.
- **Fix:** The probe now stages the fixture's precondition — create `logs` and `Logs`, require the listing to hold two entries — and answers `false` on any host that cannot store both. A probe that cannot run at all also answers `false`, which can only ever skip a case, never turn a case-sensitive host into a silent pass. Additionally, the regime classification was extracted as a pure function so the skip costs no coverage of the *decision*, and `mergeContents` was given arbitrary source/destination URLs so it costs no coverage of the *application* either.
- **Files modified:** `LogsDirectoryMigrationTests.swift`, `LogsDirectoryMigration.swift`
- **Verification:** `➜ Test bothStoredSpellingsRouteToAMerge() skipped: "Two directories differing only in case cannot be stored on this host's volume."`, with the other 16 cases running.
- **Committed in:** `0f45c40f`

**2. [Rule 1 — Bug] The plan's acceptance criterion contradicts the artifact the plan requires**

- **Found during:** Task 2
- **Issue:** The plan requires a migration that moves the legacy `logs` directory, and separately requires `rg -n '"logs"' App AppPackage ShareExtension -g '*.swift'` → **no matches**. A migration must name the directory it reads *from*, so the two cannot both hold. Satisfying the regex literally would mean deriving the legacy name from the current constant, which DEC-C rejects on correctness grounds.
- **Fix:** The criterion was replaced with one that carries its intent — *no code path can recreate the lowercase folder*: exactly one lowercase literal exists in `Sources`, it is `LogsDirectoryMigration.legacyDirectoryName`, it is `private`, and it is used only in name comparisons and as a move **source**. Verified: `rg '"logs"' App AppPackage/Sources ShareExtension -g '*.swift'` → 1 match, that constant. Test fixtures use the literal deliberately, since a fixture must reproduce what shipped rather than track a constant.
- **Files modified:** none (criterion correction)
- **Committed in:** `f8513360`

**3. [Rule 2 — Missing critical functionality] A regular file named `logs` would have broken logging outright**

- **Found during:** Task 2
- **Issue:** `Documents` is user-writable through File Sharing, so a user can drop a *file* called `logs` next to their folders. The plan's design moves whatever carries that name onto `Logs`, which would leave a regular file exactly where `appendToRunFile`'s `createDirectory` needs a directory — logging would fail from then on, for a file the app never owned.
- **Fix:** `run` verifies the legacy entry is a directory before acting and otherwise reports `nothingToMigrate`, leaving the user's file untouched.
- **Verification:** `aRegularFileNamedLikeTheLegacyDirectoryIsLeftAlone` — outcome, listing and bytes all asserted.
- **Committed in:** `f8513360`

**4. [Rule 1 — Bug] A SwiftLint warning in the new test helper**

- **Found during:** Task 2 verification
- **Issue:** `String(decoding:as:)` tripped `optional_data_string_conversion` (warning, and the build must be warning-free). It is also the wrong call here: it maps invalid bytes to U+FFFD, so a corrupted read would have surfaced as an unexplained string inequality.
- **Fix:** `try #require(String(bytes:encoding:))` — fixed at the root, no suppression. A non-UTF-8 read now fails the case at the point of decoding.
- **Verification:** Full re-run after the fix: **0 repo warnings**, `TEST SUCCEEDED`.
- **Committed in:** `f8513360`

### Environment note (not a deviation)

The plan's `-destination 'platform=iOS Simulator,name=iPhone Air'` is ambiguous on this machine; every invocation used `id=ADE09605-A44E-4F00-BE12-235970217355` instead. Only the destination differed.

---

**Total deviations:** 4 auto-fixed (3 × Rule 1, 1 × Rule 2). No out-of-scope findings.
**Impact on plan:** No scope creep. Deviations 1 and 2 correct plan artifacts (a test gate and an acceptance criterion) that could not have held as written; 3 and 4 are correctness fixes inside the plan's own scope.

## Issues Encountered

Every `xcodebuild` invocation was serialized — one at a time, five in total (RED probe run, RED gate, full suite, full suite after the lint fix, clean build).

One thing the tests cannot distinguish, stated rather than glossed: on this host the rename case classifies as `.rename` and returns `.renamed`, but `.renamed` is returned both by the direct atomic `moveItem` and by its staging fallback. The branch is exercised; which of its two arms carried it here is unobserved. On a case-sensitive volume the direct move is the only one that can run.

## Verification

| Gate | Result |
|---|---|
| RED, at `0f45c40f` | **TEST FAILED** — 17 tests, 12 failing, 22 issues, 1 correctly skipped |
| `xcodebuild test … -testPlan FeatureTests` (full, simulator by id) | **TEST SUCCEEDED**, **980 tests, 22 targets, 0 failures, 1 skipped** (963 baseline + 17) |
| `xcodebuild … 'generic/platform=iOS Simulator'`, fresh derived data | **BUILD SUCCEEDED**, 0 warnings, 0 errors |
| SwiftLint `--strict` over all 4 changed files | **0 violations, 0 serious** |
| `rg '"logs"' App AppPackage/Sources ShareExtension -g '*.swift'` | 1 — the frozen legacy SOURCE constant (DEC-F) |
| `rg -c '"Logs"' AppPackage/Sources/AppTools/Defaults.swift` | 1 |
| Launch wiring + logger placement in `AppDelegateReducer.swift` | Both present (lines 12, 44) |
| `AppPackage/Package.swift` | **Untouched** — AppTools and AppToolsTests gained no dependency |
| Non-Swift sweep (`Info.plist`, entitlements, `ShareExtension`) | no path literals |

## Next Phase Readiness

The first of the two owner Deferred Follow-Ups (15-UAT.md test 6) is closed in code. Two items ride the next device UAT pass, neither blocking:

- **Coverage D8** — the both-exist merge is pinned in halves here; its end-to-end case runs unskipped on any case-sensitive volume, which includes a real device.
- **Coverage D9** — `openFileApp`'s `shareddocuments://` deep link is derived to open `Logs`, but no run has observed it.

The second follow-up (DownloadsView swipe-action offset during the deletion alert) remains open.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-11*

## Self-Check: PASSED

- `AppPackage/Sources/AppTools/LogsDirectoryMigration.swift` — FOUND (286 lines; `LogsDirectoryMigration`, `Regime`, `MergeDecision`, `Outcome`)
- `AppPackage/Tests/AppToolsTests/LogsDirectoryMigrationTests.swift` — FOUND (17 `@Test` cases)
- `AppPackage/Sources/AppTools/Defaults.swift` — FOUND, `logs = "Logs"`
- `AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift` — FOUND, migration wired at line 44, `private let logger` at line 12
- Commit `0f45c40f` — FOUND (RED: tests + skeleton)
- Commit `f8513360` — FOUND (GREEN: constant, migration, wiring)
- No stubs: the RED skeleton's do-nothing bodies were fully replaced in `f8513360`; `rg 'TODO|FIXME|unimplemented'` over both new files → no matches
