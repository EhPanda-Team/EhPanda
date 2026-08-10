---
phase: 15-continued-background-downloads
plan: 75
subsystem: localization
tags: [swift, string-catalog, localization, xcstrings, spelling-convergence, mechanical-pass]

requires:
  - phase: 15-continued-background-downloads
    provides: "The IN-02 spelling split carried since round 17 and widened by 15-69, which this plan closes"
provides:
  - "One localized-key access spelling across every DownloadClient call site: 25 sites, all `.RLocalizable.`"
  - "Ten keys rehomed from the module-local catalog into the shared Resources catalog, six locales byte-identical"
  - "Hand-written RLocalizable symbols for all ten, with semantic labels on the one multi-argument key"
  - "A type-level close on the split: with no module-local catalog, a bare spelling no longer compiles"
affects: [download-error-messages, continued-session-card, resources-module, phase-15-verification]

tech-stack:
  added: []
  patterns:
    - "Catalog convergence as spelling convergence: a key's ACCESS spelling is a function of which catalog owns it, so unifying the spelling means moving the key, not editing the call site"
    - "Retire the affordance, not just the instances: deleting the module-local catalog turns the minority spelling from a convention into a compile error"

key-files:
  created: []
  modified:
    - AppPackage/Sources/Resources/Resources/Localizable.xcstrings
    - AppPackage/Sources/Resources/ResourceStringSymbols.swift
    - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift
    - AppPackage/Package.swift
    - .planning/phases/15-continued-background-downloads/deferred-items.md
  deleted:
    - AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings

key-decisions:
  - "DEC-A: the census was re-derived and is 25 sites (13 prefixed, 12 bare), not the plan's 19 or the review's 18 — three key accesses live outside the `String(localized:` shape both counts matched on (derived by argument, counted from source)"
  - "DEC-B: the module-local catalog is DELETED rather than emptied-and-kept, because the deletion is what makes the split unable to widen: with no catalog there are no module-scoped generated symbols, so a bare spelling is a compile error (enforced by the type system; falsification run recorded)"
  - "DEC-C: continuedSessionSubtitle keeps the call site's existing labels (completed/total/galleries) and carries a doc comment stating that the parameter ORDER is load-bearing and uncheckable, because it binds the catalog's argNum 1/2/3 substitutions (derived by argument; the order property is enforced by 50 pre-existing subtitle assertions)"
  - "DEC-D: no new test was added — the resolution property the plan warns about is already enforced by 50 subtitle and 34 title assertions, and the spelling property is now enforced by the compiler; a restated census would be an unowned claim pointed the other way (derived by argument, on 15-74 DEC-C's precedent)"
  - "DEC-E: the shared catalog was rewritten with Xcode's own serialization (`separators=(',', ' : ')`), verified byte-identical on a no-op round trip first, so the diff is a pure 698-line addition with zero touched lines (enforced by `git diff --numstat`)"

patterns-established:
  - "Prove the serializer before writing through it: round-trip the target file and require byte identity, so a mechanical merge cannot reformat 33 keys it was not asked to touch"
  - "Check the shipped artifact, not the source: compare the compiled .strings/.stringsdict in the built bundle against the PRE-move catalog read from git, which catches a move that edits JSON correctly but lands in the wrong bundle"

requirements-completed: []

coverage:
  - id: D1
    description: "Every localized-key access in DownloadClient uses the `.RLocalizable.` spelling — 25 sites, zero bare"
    verification:
      - kind: other
        ref: "rg -nP 'localized:\\s*\\.(?!RLocalizable)|\\.missingFiles\\(\\.(?!RLocalizable)' AppPackage/Sources/DownloadClient -> 0; prefixed count -> 25"
        status: pass
    human_judgment: false
  - id: D2
    description: "The split cannot widen again: a bare spelling in DownloadClient is a compile error, not a style choice"
    verification:
      - kind: other
        ref: "Falsification run — one site reverted to the bare spelling: BUILD FAILED, DownloadClient+RetryHelpers.swift:95:57: error: 'downloadStoreInvalidPageSelection' is inaccessible due to 'internal' protection level"
        status: pass
    human_judgment: false
  - id: D3
    description: "Zero translation drift: all ten moved keys carry all six locales with values identical to their module-local originals"
    verification:
      - kind: other
        ref: "python3 deep-equality gate at merge time (10/10 keys equal); plus the SHIPPED bundle's compiled .strings/.stringsdict compared against `git show HEAD:...` of the pre-move catalog, 10 keys x 6 locales, True"
        status: pass
    human_judgment: false
  - id: D4
    description: "The moved keys resolve through the shared bundle at runtime rather than falling through to a key name or a defaultValue"
    verification:
      - kind: unit
        ref: "50 rendered-subtitle equality assertions (e.g. DownloadContinuedSessionBasisTests.swift#L108 '5 / 14 pages · 2 galleries') and 34 'Downloading galleries' assertions across DownloadsFeatureTests, all pass"
        status: pass
    human_judgment: false
  - id: D5
    description: "continued_session.subtitle's three substitutions keep their per-locale plural category sets and their argument positions"
    verification:
      - kind: other
        ref: "Compiled ja.lproj/Localizable.stringsdict: NSStringLocalizedFormatKey = '%1$#@completed@ / %2$#@total@ · %3$#@galleries@' with %1$lld / %2$lldページ / %3$lld件のギャラリー; the 50 subtitle assertions cross singular and plural on both count arguments"
        status: pass
    human_judgment: false
  - id: D6
    description: "The module-local catalog and its resource declaration are retired with no stale reference left behind"
    verification:
      - kind: other
        ref: "ls AppPackage/Sources/DownloadClient/Resources -> No such file or directory; rg 'DownloadClient/Resources' -> no matches; no AppPackage_DownloadClient.bundle in the built app"
        status: pass
    human_judgment: false
  - id: D7
    description: "The eight error-message keys resolve correctly, but no test asserts their rendered text"
    verification:
      - kind: other
        ref: "Shipped-bundle comparison covers all ten keys x six locales; DownloadsFeatureTests asserts the rendered value of only the two continued-session keys"
        status: pass
    human_judgment: true
    rationale: "Their resolution is verified against the built artifact at this HEAD, not pinned by a test. That is unchanged by this plan — those eight keys had no rendered-value coverage before the move either — but the honest label is 'verified at this HEAD', and the owner should decide whether error-message text is worth pinning."

duration: 25min
completed: 2026-08-10
status: complete
---

# Phase 15 Plan 75: One Localized-Key Spelling Summary

**IN-02's minority spelling did not lose an argument — it lost the thing that made it possible: with the module-local catalog gone, every DownloadClient key resolves through `RLocalizable` and a bare access no longer compiles.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-08-10T14:12Z (local 23:12 JST)
- **Completed:** 2026-08-10T14:37Z (local 23:37 JST)
- **Tasks:** 1
- **Files modified:** 8 (+1 planning artifact)
- **Files deleted:** 1

## Accomplishments

- **The census is 25 sites, not 19 and not 18 — and the three sites everyone missed are the interesting ones.** The plan said 19 (10 prefixed, 9 bare); the review said 18 (10, 8). Both counted `String(localized: .…)` on a single line. Source has three more key accesses outside that shape: `DownloadClient+ContinuedSession.swift:364`, where `String(` and `localized:` sit on different lines, and `DownloadStore+Operations.swift:718` and `:722`, which pass a `LocalizedStringResource` straight into `.missingFiles(…)` with no `String(localized:)` wrapper at all. The plan's own acceptance regex (`String\(localized: \.(?!RLocalizable)`) is blind to all three, so a pass that satisfied it would have left the split open in the very file the review named. Final: **13 already prefixed, 12 rewritten, 0 bare.** *Derived by argument, counted from source.*
- **Convergence meant moving keys, not editing call sites.** All nine bare-spelled keys plus `continued_session.subtitle` lived in `AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings`, and `.RLocalizable.` is the shared `Resources` module's namespace. All ten moved. A find-and-replace on the call sites alone would have compiled and then rendered the key name at runtime — the failure the plan flags as the worst available, because nothing would catch it.
- **The merge was gated, not trusted.** The shared catalog is Xcode-serialized (`"key" : value`), so a naive `json.dumps` would have reformatted all 33 existing keys. The writer was proved first: a no-op round trip with `separators=(',', ' : ')` reproduced the file byte-for-byte. Only then were the ten keys merged, sorted into place, and every pre-existing key re-compared for equality. `git diff --numstat` reports **698 insertions, 0 deletions** — arithmetically the whole module-local file (704) minus its six envelope lines.
- **Drift was checked against the shipped artifact, not just the JSON.** The built `AppPackage_Resources.bundle` was decoded (`Localizable.strings` as a binary plist, `Localizable.stringsdict` for the substitution key) and compared against the pre-move catalog read out of git. All 10 keys × 6 locales match. This is the check that would catch a key that merged correctly into the source but landed in the wrong bundle.
- **The subtitle's argument order survived, and the compiled dictionary proves it.** `ja.lproj/Localizable.stringsdict` carries `NSStringLocalizedFormatKey = "%1$#@completed@ / %2$#@total@ · %3$#@galleries@"` with `%1$lld`, `%2$lldページ`, `%3$lld件のギャラリー`. The hand-written symbol binds those three positions and nothing else checks it, so the symbol carries a doc comment saying exactly that.
- **The split was closed at the compiler, and the compiler was watched refusing.** One site was reverted to the bare spelling and the build re-run: `error: 'downloadStoreInvalidPageSelection' is inaccessible due to 'internal' protection level`. The diagnostic is sharper than "no such member" — the auto-generated symbol now lives in the `Resources` module at internal access, so the bare spelling is not merely unresolvable from DownloadClient, it is visibly forbidden.
- **963 tests, 0 failures, 22 targets — the baseline exactly**, and 50 of them assert a rendered subtitle while 34 assert the rendered title.

## Task Commits

1. **Task 1: one localized-key spelling across all DownloadClient call sites** — `f3fd0b00` (refactor)

## Files Created/Modified

- `AppPackage/Sources/Resources/Resources/Localizable.xcstrings` — **+698, −0.** Ten keys merged into sorted position: `continued_session.subtitle`, `continued_session.title`, and the eight `download_store.*` error strings. Each key's sub-object is carried over untouched; the only reordering is the `localizations` dict, sorted alphabetically to match the convention every one of the 33 pre-existing keys already follows. 33 → 43 keys, all six locales, all `state: "translated"`, no `shouldTranslate: false` entry anywhere.
- `AppPackage/Sources/Resources/ResourceStringSymbols.swift` — **+102.** Ten hand-written `RLocalizable` symbols in alphabetical position (verified: 43 symbols ↔ 43 catalog keys, bijective, sorted). Eight are plain `static var`. `downloadStoreAssetUnreadable(_ fileName: String)` keeps its `%@` argument positional per the AGENTS.md rule. `continuedSessionSubtitle(completed:total:galleries:)` is the labeled multi-substitution symbol the plan required, and the only symbol in the file with a doc comment — because it is the only one whose parameter order silently changes the rendered string in all six locales with no diagnostic.
- `AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings` — **deleted**, and its directory with it. This is what closes IN-02 structurally rather than by convention.
- `AppPackage/Package.swift` — the DownloadClient target's `resources: [.process(.resources)],` removed; the helper's parameter defaults to `nil`, so no other edit was needed. The built app no longer ships an `AppPackage_DownloadClient.bundle`.
- `AppPackage/Sources/DownloadStore+Operations.swift` — 5 sites: `downloadStoreAssetUnreadable`, `downloadStoreFolderAlreadyExists` ×2, and the two `.missingFiles(…)` producers neither the plan nor the review counted. This is the file the review singled out for using both forms eight lines apart; it now uses one form in ten places.
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` — the multi-line subtitle site and the title site; `import Resources` added.
- `AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift` — 3 sites. Already imported `Resources`, since four of its seven accesses were prefixed.
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift`, `DownloadClient+RetryHelpers.swift` — one site each; these are the two keys 15-69 added in the minority spelling. `import Resources` added to both.
- `.planning/phases/15-continued-background-downloads/deferred-items.md` — one new out-of-scope finding (see below).

## Every claim, labelled by what backs it

| Claim | Backed by |
|---|---|
| Zero bare key accesses remain in DownloadClient; 25 sites all prefixed | **Enforced by test** (the suite compiles) **plus** a census `rg` reported above |
| A bare spelling in DownloadClient no longer compiles | **Enforced by the type system, and demonstrated** — falsification run: BUILD FAILED, `'downloadStoreInvalidPageSelection' is inaccessible due to 'internal' protection level` |
| The census is 25, not 19 or 18 | **Derived by argument, counted from source** — the three extra sites are enumerated above with line numbers |
| The ten moved keys are byte-identical across six locales | **Enforced by a gate at merge time** (deep equality, 10/10) **and independently** by comparing the compiled bundle to `git show HEAD:` of the pre-move catalog |
| No pre-existing shared-catalog key was touched | **Enforced by a gate** (all 33 compared equal) **plus** `git diff --numstat` → 698 insertions, 0 deletions |
| `continued_session.subtitle` resolves with its three arguments in the right positions | **Enforced by test** — 50 rendered-subtitle equality assertions, crossing singular and plural on both count arguments |
| `continued_session.title` resolves through the shared bundle | **Enforced by test** — 34 `"Downloading galleries"` assertions |
| The eight error-message keys resolve through the shared bundle | **Verified against the shipped artifact at this HEAD** — no test asserts their rendered text (coverage D7) |
| Substitution plural-category sets are unchanged per locale | **Derived by argument** — the sub-objects were copied by reference through the deep-equality gate, so no category set could change — **and demonstrated** in the compiled `stringsdict` |
| No stale reference to the retired catalog survives | **Enforced by test** (clean build, 0 warnings) **plus** `rg 'DownloadClient/Resources'` → no matches |
| The plan's own acceptance regex is blind to three of the sites | **Derived by argument** — `String\(localized: \.` cannot match a `.missingFiles(` producer or a line-broken call |

## Falsification run (the guard was seen to refuse)

`DownloadClient+RetryHelpers.swift:95` was reverted to `String(localized: .downloadStoreInvalidPageSelection)` and the app scheme rebuilt:

```
** BUILD FAILED **
DownloadClient+RetryHelpers.swift:95:57: error: 'downloadStoreInvalidPageSelection'
  is inaccessible due to 'internal' protection level
```

Restoring the prefix returned the build to `** BUILD SUCCEEDED **`, 0 warnings. This is the evidence behind D2: the property "the split cannot widen again" is carried by the compiler, not by a comment. Note the shape of the diagnostic — the symbol still exists, auto-generated at internal access inside the `Resources` module, which is why re-introducing the minority spelling is refused rather than silently resolved somewhere else.

(The `git checkout --` used to restore that file also reverted its `import Resources`; that was caught immediately by re-reading the file, re-added, and the final `git diff` for it inspected line by line — it is exactly the import plus the prefix.)

## Decisions Made

- **DEC-A — the census was re-derived and disagreed with both prior counts.** Recorded above. Neither the plan's 19 nor the review's 18 is source. Both matched `String(localized: .…)` on one line; `.missingFiles(.…)` takes a `LocalizedStringResource` directly and never wraps it, and one subtitle call is line-broken. Had the pass been driven by the plan's acceptance regex, `DownloadStore+Operations.swift` would still carry both spellings — in the same file the review cited as the evidence for IN-02. *Derived by argument, counted from source.*
- **DEC-B — delete the module-local catalog rather than empty it.** An emptied catalog left in place, with its `resources:` declaration, keeps the affordance: the next key added to it generates a module-scoped symbol and the next call site takes the bare spelling, exactly as 15-69 did. Deleting it removes the generator. The must_have truth ("cannot widen again") is only true under the deletion, and the falsification run is what makes that a demonstration rather than a claim. *Enforced by the type system.*
- **DEC-C — the subtitle keeps its existing labels and gains a doc.** `completed`/`total`/`galleries` are already semantic and already what the call site writes, so the AGENTS.md shared-key rule is satisfied without renaming anything. What was missing is the reason they must stay in that order: they bind `argNum` 1/2/3 of three *named* substitutions, and a substitution resolves positionally. Swapping two parameters compiles, passes type-checking, and renders pages where galleries belong. The doc says so at the symbol. *The order itself is enforced by test (50 assertions); the doc exists because the compiler cannot be.*
- **DEC-D — no new test.** The two properties this plan owns are already pinned: the spelling by the compiler (D2), the resolution by 84 pre-existing assertions (D4). The one uncovered slice is the eight error strings' rendered text, and that slice was uncovered before the move too — adding assertions on error copy would be new scope, and adding a source census restating what the compiler enforces would be an unowned claim pointed the other way, which is the arm 15-74's DEC-C rejected for the same reason. *Derived by argument.*
- **DEC-E — the serializer was proved before it was used.** The shared catalog is written by Xcode with a space before every colon. Writing it back with Python's defaults would have rewritten all 1550 lines and buried ten added keys inside a whole-file reformat that no reviewer could read. Round-tripping the untouched file to byte identity first turned the merge into a diff a human can check. *Enforced by `git diff --numstat`: 698 / 0.*

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] The plan's site count and its acceptance regex both missed three call sites**

- **Found during:** Task 1, before any edit
- **Issue:** The plan specified 19 sites (10 prefixed, 9 bare) across five bare-spelling files, and its first acceptance criterion was `rg -nP 'String\(localized: \.(?!RLocalizable)'`. Source has 25 key accesses. Three are invisible to that pattern: `DownloadClient+ContinuedSession.swift:364` (the `String(` and its `localized:` argument are on different lines) and `DownloadStore+Operations.swift:718`/`:722` (`.missingFiles(.downloadStoreDownloadFolderMissing)` and `.missingFiles(.downloadStoreManifestMissing)`, which pass a `LocalizedStringResource` with no `String(localized:)` wrapper). Satisfying the stated criterion would have declared IN-02 closed while `DownloadStore+Operations.swift` still carried both spellings.
- **Fix:** The census was re-derived from source before the pass and widened to `localized:\s*\.` plus `\.missingFiles\(\.`, giving 13 prefixed / 12 bare. All 12 were rewritten. The plan's criterion still passes; the wider one is what the summary reports.
- **Files modified:** `DownloadClient+ContinuedSession.swift`, `DownloadStore+Operations.swift` (the three extra sites)
- **Verification:** Wider census → 25 prefixed, 0 bare. The deletion of the module-local catalog makes it independently impossible for a missed site to survive: it would not compile.
- **Committed in:** `f3fd0b00`

**2. [Rule 3 — Blocking] Three files consumed keys from their own module and had no `import Resources`**

- **Found during:** Task 1
- **Issue:** `DownloadClient+ContinuedSession.swift`, `DownloadClient+ExecutionFetch.swift` and `DownloadClient+RetryHelpers.swift` reached their keys through the module-local catalog's generated symbols, so none imported `Resources`. After the move their call sites would not resolve.
- **Fix:** `import Resources` added to all three, in the files' existing alphabetical import order. The other two rewritten files already imported it, because they already carried prefixed accesses.
- **Files modified:** the three named above
- **Verification:** Clean build, 0 warnings; the falsification run confirms the import alone is not what carries the spelling.
- **Committed in:** `f3fd0b00`

### Out of Scope — Logged, Not Fixed

**3. `AppPackage/Package.swift` breaches the `file_length` ERROR limit and nothing catches it**

SwiftLint run directly over the changed files reports one violation, and it is not in a file this plan authored: `Package.swift` is 1128 lines against a 1000-line ERROR limit. It is pre-existing (1129 before this plan removed a line) and structurally invisible to the build gate — the SwiftLint plugin runs per target over that target's *sources*, and the manifest belongs to no target, so a warning-free app-scheme build says nothing about it. Fixing it means splitting the target list across manifest helper files, which is a package-layout change, not a branch fix. Recorded in `deferred-items.md` per the scope boundary.

---

**Total deviations:** 2 auto-fixed (1 × Rule 1, 1 × Rule 3), 1 out-of-scope finding logged.
**Impact on plan:** No scope creep. Deviation 1 makes the pass do what the plan's *contract* says ("all call sites, not just the two keys the last round added") rather than what its regex could see.

## Issues Encountered

None beyond the deviations. Every `xcodebuild` invocation was serialized — one at a time, four in total (build, falsification build, clean rebuild, full test run).

## Verification

| Gate | Result |
|---|---|
| `xcodebuild … -destination 'generic/platform=iOS Simulator' build` (fresh derived data) | **BUILD SUCCEEDED**, 0 warnings, 0 errors |
| `xcodebuild test … -testPlan FeatureTests` (full, simulator by id) | **TEST SUCCEEDED**, 963 tests, 22 targets, 0 failures (baseline exactly) |
| SwiftLint `--strict` over all 7 changed Swift files | 0 violations in authored files; 1 pre-existing `file_length` on `Package.swift` (logged, out of scope) |
| Bare-spelling census in DownloadClient | **0**; prefixed **25** |
| Moved keys vs pre-move catalog, source JSON | 10/10 deep-equal |
| Moved keys vs pre-move catalog, **compiled bundle** | 10 keys × 6 locales, all match |
| Pre-existing shared-catalog keys | 33/33 unchanged; `git diff --numstat` → 698 / 0 |
| Symbols ↔ catalog keys | 43 ↔ 43, bijective, alphabetically ordered |
| `ls AppPackage/Sources/DownloadClient/Resources` | No such file or directory |
| `rg 'DownloadClient/Resources'` (whole repo) | no matches |
| Falsification: bare spelling reintroduced | **BUILD FAILED** with the access-level error quoted above |

## Next Phase Readiness

IN-02 is closed, and with it gap 5's fourth and last item — gap 5 can be re-verified. The close is structural rather than stylistic: the minority spelling is now a compile error in this module, so a future round cannot re-widen it by adding a key the easy way.

Two items carried forward, neither blocking:

- **Coverage D7** — the eight moved error-message keys have their resolution verified against the built bundle but pinned by no test. Unchanged from before the move; flagged so the owner can decide whether error copy is worth asserting.
- **`Package.swift` file length** (deviation 3) — a real ERROR-severity lint violation that the build gate structurally cannot see. Logged in `deferred-items.md`.

Still near the `file_length` limit and needing a split before they are next edited: `DownloadContinuedSessionTests.swift` (993), `DownloadFeatureTestHelpers.swift` (992), `DownloadSourceInventoryTests.swift` (992), `DownloadClient+ContinuedSession.swift` (970 after this plan's one added import).

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-10*

## Self-Check: PASSED

- `AppPackage/Sources/Resources/ResourceStringSymbols.swift` — FOUND (43 symbols, alphabetical, bijective with the catalog)
- `AppPackage/Sources/Resources/Resources/Localizable.xcstrings` — FOUND (43 keys, contains `download_store.*` and `continued_session.*`)
- `AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings` — CONFIRMED ABSENT, as intended
- Commit `f3fd0b00` — FOUND; its one file deletion is the intended catalog retirement
- Bare key-access census in `AppPackage/Sources/DownloadClient` — 0
