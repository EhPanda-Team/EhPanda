---
phase: 16-dynamic-type-accessibility
plan: 12
subsystem: accessibility
tags: [dynamic-type, swiftlint, custom-rules, minimumScaleFactor, owner-sign-off, round-1-closure, d-14, d-16, d-23]

# Dependency graph
requires:
  - phase: 16-01
    provides: The `custom_rules` battery shape, the doccomment spelling-trap comment, and the negative-control probe pattern for D-16 rules
  - phase: 16-11
    provides: Closed round-1 findings loop (0 open findings, 0 pending/re-verify cells, 5/5 D-13 dispositions, `### Round-1 closure`, owner `ROUND1-CLEAR`) and the five `minimumScaleFactor` removals (`59fb2eb9`)
provides:
  - "`no_minimum_scale_factor` custom rule at error severity in the root `.swiftlint.yml` (fifth D-16 rule; the `minimumScaleFactor` ban is now self-enforcing via the build-tool plugin)"
  - "`16-SWEEP.md § Owner sign-off`: the owner's `approved` (2026-09-11T08:35Z) recorded as text against HEAD `d5afe78f`, closing 10-UAT.md test 7 (D-03 device gate), ROADMAP Phase 16 criterion 5 and requirement A11Y-01"
  - "Round 2 (plans 16-13 onward) unblocked under D-23"
affects: [16-13, 16-14, accessibility-round-2, every future SwiftUI change in the tree]

# Actuals (#2632) — chars/4 over the realized diff; commits measured from the plan ledger.
actuals:
  tokens: 4718
  tasks: 3
  commits: 2
  plan_head_before: 4471184aa1787c74671d11b34a5cde2c5786f81f

tech-stack:
  added: []
  patterns:
    - "Land a build-breaking lint rule only after the tree is provably at zero for it (precondition grep before the rule, strict lint and both builds before the commit)"

key-files:
  created: []
  modified:
    - .swiftlint.yml
    - .planning/phases/16-dynamic-type-accessibility/16-SWEEP.md

key-decisions:
  - "`no_minimum_scale_factor` lands at error severity with the tree at 0 sites, so no build was ever broken by it; the ban is outright, not grandfathered (D-14, D-16)."
  - "Round 1 is closed on the owner's `approved` (2026-09-11T08:35Z) covering HEAD `d5afe78f`; the signature is recorded as text in `16-SWEEP.md § Owner sign-off`, no image enters the repo (D-32)."
  - "A11Y-01 is complete at this sign-off; A11Y-02 (round 2) remains open and starts with wave 12 (16-13, 16-14) under D-23."

patterns-established:
  - "Zero-then-ban: a D-16 rule that the plugin runs at error severity is landed only in the same commit window that proves the count is 0 and the plugin build is green."

requirements-completed: [A11Y-01]

coverage:
  - id: D1
    description: "`no_minimum_scale_factor` live at error severity between `no_geometry_reader` and `no_nslock`; `minimumScaleFactor` count 0 before and after; strict standalone lint 0 violations; scheme build and FeatureTests build-for-testing green"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "grep -rn minimumScaleFactor AppPackage/Sources App ShareExtension | wc -l  # 0 before and after; grep -c 'no_minimum_scale_factor:' .swiftlint.yml  # 1 (line 240, between line 227 and line 255)"
        status: pass
      - kind: other
        ref: "swiftlint 0.65.0 artifact binary: lint --strict --no-cache --config .swiftlint.yml AppPackage/Sources App ShareExtension EhPandaUITests AppPackage/Tests  # Done linting! Found 0 violations, 0 serious in 571 files"
        status: pass
      - kind: other
        ref: "xcodebuild build -scheme EhPanda -destination 'generic/platform=iOS Simulator'  # BUILD SUCCEEDED; xcodebuild build-for-testing -scheme EhPanda -testPlan FeatureTests  # TEST BUILD SUCCEEDED"
        status: pass
    human_judgment: false
  - id: D2
    description: "Probe: the rule fires on `.minimumScaleFactor(0.5)` and `.minimumScaleFactor (0.72)`, and stays silent on the same token inside a `///` doccomment, a `//` comment and a string literal"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "swiftlint lint --no-cache --config .swiftlint.yml <scratch probe, deleted>  # positives at probe lines 10, 11 fire (error); negatives at lines 3, 5, 6 silent"
        status: pass
    human_judgment: false
  - id: D3
    description: "Owner-signed UAT of the completed round-1 verdict table (ROADMAP Phase 16 criterion 5; 10-UAT.md test 7 / D-03 device gate)"
    requirement: A11Y-01
    verification: []
    human_judgment: true
    rationale: "The gate is the owner's own judgment of readability and operability at XXL / AX3 / AX5 across every screen including authenticated ones; recorded verbatim (`approved`, 2026-09-11T08:35Z, HEAD `d5afe78f`) in `16-SWEEP.md § Owner sign-off`."
  - id: D4
    description: "`## Owner sign-off` recorded once in `16-SWEEP.md`, text only, no absolute home path, no image staged"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "f=.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md; grep -c '^## Owner sign-off' \"$f\"; git log -1 --format=%s; git status --porcelain | grep -Ei '\\.(png|jpe?g|heic|gif)$' | wc -l; grep -c <home-directory prefix> \"$f\"  # 1 / docs(16): record round-1 owner sign-off / 0 / 0"
        status: pass
    human_judgment: false

# Metrics
duration: 21min (plan window 2026-09-11T08:16Z to 08:37Z: Task 1 about 10 min, owner checkpoint about 9 min, Task 3 about 2 min; SUMMARY and metadata follow)
completed: 2026-09-11
status: complete
---

# Phase 16 Plan 12: `no_minimum_scale_factor` rule and round-1 owner sign-off Summary

**The fifth D-16 SwiftLint rule bans `minimumScaleFactor` at error severity with the tree at 0 sites, and the owner's `approved` (2026-09-11T08:35Z, HEAD `d5afe78f`) is recorded as text in `16-SWEEP.md § Owner sign-off`, closing round 1, Phase 10's deferred D-03 device gate and A11Y-01, and unblocking round 2.**

## Performance

- **Duration:** 21 min (plan window; excludes this SUMMARY and the metadata commit)
- **Started:** 2026-09-11T08:16:09Z (ledger commit `4471184a`, the 16-11 close-out)
- **Completed:** 2026-09-11T08:37:27Z (sign-off commit `c5138ea7`)
- **Tasks:** 3 (Task 1 auto, Task 2 blocking human-verify checkpoint resolved by the owner, Task 3 auto in a continuation executor)
- **Files modified:** 2

## Accomplishments

- `no_minimum_scale_factor` is live at `severity: error` in the root `.swiftlint.yml`, positioned alphabetically between `no_geometry_reader` (line 227) and `no_nslock` (line 255) at line 240, with regex `\.minimumScaleFactor\s*\(`, `excluded_match_kinds` `comment` / `doccomment` (spelling-trap comment carried) / `string`, and a message naming Phase 16 D-14 and the reflow fix (wrap, `ViewThatFits`, or stack at accessibility sizes). All four D-16 rules from plan 16-01 plus this one now run at error severity; the tree is at 0 for each.
- The precondition held: `grep -rn "minimumScaleFactor" AppPackage/Sources App ShareExtension | wc -l` printed `0` before and after the rule landed, so no build was ever broken by it (T-16-07 mitigated).
- The rule is proven, not assumed: positive probes fire, comment / doccomment / string negatives stay silent (T-16-04 mitigated); strict standalone lint reports 0 violations in 571 files with no config warning; the scheme build and the FeatureTests build-for-testing are both green.
- The owner signed the completed round-1 verdict table: `approved` at 2026-09-11T08:35Z covering HEAD `d5afe78f`, recorded verbatim with the covered hash in `16-SWEEP.md § Owner sign-off` (T-16-06 mitigated). This closes Phase 10's `10-UAT.md` test 7 (item 5, `skipped` there; the D-03 device gate), ROADMAP Phase 16 criterion 5 (owner-signed UAT) and criterion 6 (`minimumScaleFactor` 5 to 0 with the error-level rules), and requirement A11Y-01. A11Y-02 (round 2) remains open.
- Round 2 (plans 16-13 onward) may begin under D-23; the layout it lands on is the one signed here.

## Task Commits

Each task was committed atomically:

1. **Task 1: Land `no_minimum_scale_factor` at zero, probe it, build green, commit** - `d5afe78f` (feat) - `.swiftlint.yml` only, +15 lines, message `feat(16-12): ban minimumScaleFactor via lint`
2. **Task 2: Owner-signed UAT of the completed round-1 verdict table** - no commit (checkpoint resolved by the owner: `approved`, 2026-09-11T08:35Z)
3. **Task 3: Record the signature and mark round 1 closed** - `c5138ea7` (docs) - `16-SWEEP.md` only, +35 lines, message `docs(16): record round-1 owner sign-off`

**Plan metadata:** recorded in the final `docs(16-12)` commit (see the completion report)

Commit count measured from the plan ledger (`.git/gsd-plan-head-before-16-12` = `4471184a`): `git rev-list --count 4471184a..HEAD` = 2 at SUMMARY time.

## Probe Table (negative control, SwiftLint 0.65.0 artifact binary, live config, scratch file deleted)

Binary: the SwiftLint 0.65.0 artifact under `$HOME/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint`.

### Positives — both fired `no_minimum_scale_factor` at error severity

| # | Probe line | Construct | Fired |
|---|---|---|---|
| 1 | 10 | `.minimumScaleFactor(0.5)` | error |
| 2 | 11 | `.minimumScaleFactor (0.72)` (space before the paren, exercising `\s*`) | error |

### Negatives — all silent

| # | Probe line | Construct | Why it must stay legal | Fired |
|---|---|---|---|---|
| 1 | 3 | the token inside a `///` doccomment | `doccomment` excluded (spelling-trap comment carried) | — |
| 2 | 5 | the token inside a `//` comment | `comment` excluded | — |
| 3 | 6 | the token inside a string literal | `string` excluded | — |

The only other diagnostic in the probe run was a `no_space_in_method_call` warning on probe line 11, an artifact of the deliberately spaced positive; it is not from the new rule.

## Lint and Build Results

| Check | Command | Result |
|---|---|---|
| Precondition (before and after) | `grep -rn "minimumScaleFactor" AppPackage/Sources App ShareExtension \| wc -l` | `0` |
| Rule present and positioned | `grep -n "no_geometry_reader:\|no_minimum_scale_factor:\|no_nslock:" .swiftlint.yml` | 227, 240, 255 (ascending, in order) |
| Strict standalone lint | `swiftlint lint --strict --no-cache --config .swiftlint.yml AppPackage/Sources App ShareExtension EhPandaUITests AppPackage/Tests` | `Done linting! Found 0 violations, 0 serious in 571 files.`, exit 0, no config warnings on stderr |
| Scheme build | `xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda -destination 'generic/platform=iOS Simulator'` | `** BUILD SUCCEEDED **` (80.7 s), 0 `error:` / `Violation:` lines |
| Test build | `xcodebuild build-for-testing -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,id=67377A20-A90A-4DB2-9A9C-9965532B0AA9'` | `** TEST BUILD SUCCEEDED **` (53.4 s), 0 `error:` / `Violation:` lines; build only, nothing installed |

Idempotency (must-have truth 7): the strict standalone lint after the rule landed reports 0 for every custom rule, the same counts as before it landed.

## Owner Sign-off (Task 2 resolution, recorded in Task 3)

- **Resume text, verbatim:** `approved`
- **Route and time:** the execute-phase orchestrator's structured question for the `checkpoint:human-verify` (`gate="blocking"`), option labelled `approved`, 2026-09-11T08:35Z; no additional signature line was typed, so none is recorded.
- **Covered commit:** HEAD `d5afe78f` (`git rev-parse --short HEAD` verified at 08:35Z; working tree clean apart from the untracked `.gsd/` runtime directory, which is never staged).
- **Recorded at:** `16-SWEEP.md § Owner sign-off` (commit `c5138ea7`), text only (D-32). The section states the closures listed under Accomplishments, the lint state at the signed commit, the `.large` half of D-15 as verified per fix batch in plan 16-11, and that round 2 may begin under D-23.
- **Task 3 verify output:** `grep -c "^## Owner sign-off"` = `1`; `git log -1 --format=%s` = `docs(16): record round-1 owner sign-off`; staged image files = `0`; absolute home-directory paths in `16-SWEEP.md` (grep for the home prefix) = `0`.

## Files Created/Modified

- `.swiftlint.yml` - `no_minimum_scale_factor` custom rule (error severity), between `no_geometry_reader` and `no_nslock`
- `.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md` - `## Owner sign-off` section appended after `### Round-1 closure`

## Decisions Made

- The rule lands only at count 0 and only after the strict lint and both builds pass, because the build-tool plugin runs it at error severity in every module (D-14, D-16; threat T-16-07).
- The signature is recorded verbatim as the single token the owner gave (`approved`) with its route, time and covered hash, rather than paraphrased; no signature line is invented for the owner (threat T-16-06).
- The `.large` half of D-15 is stated as covered by the signature on the basis of plan 16-11's per-batch parity records; no new parity check was run in this plan.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Plan's swiftlint glob matched nothing; full artifact path used**
- **Found during:** Task 1 (standalone strict lint)
- **Issue:** The plan's `<verify>` glob `ls $HOME/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/*/macos/swiftlint` resolved to nothing; the binary sits one directory deeper (`.../swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint`).
- **Fix:** Ran the same command against the full artifact path; `swiftlint version` = 0.65.0, the binary plan 16-01 probed against.
- **Files modified:** none
- **Verification:** `Done linting! Found 0 violations, 0 serious in 571 files.`
- **Committed in:** n/a (no file change)

**2. [Rule 3 - Blocking] Plan's spare simulator absent; build-for-testing used an available iOS 26.5 device, build only**
- **Found during:** Task 1 (FeatureTests build-for-testing)
- **Issue:** The plan's destination `88B217DA-A166-4BAD-820D-DE13B1C4EB54` is not in the current simulator inventory.
- **Fix:** Used the available iOS 26.5 iPhone 17e `67377A20-A90A-4DB2-9A9C-9965532B0AA9` as the build-for-testing destination; build only, nothing installed or launched, so no logged-in simulator was touched.
- **Files modified:** none
- **Verification:** `** TEST BUILD SUCCEEDED **` (53.4 s)
- **Committed in:** n/a (no file change)

---

**Total deviations:** 2 auto-fixed (2 blocking, both pre-authorized by the orchestrator and both about the verification environment, not the deliverable)
**Impact on plan:** None on the artifacts. Both substitutions exercised the identical check the plan asked for.

## Issues Encountered

- The sweep simulators recorded in `16-SWEEP.md § Infrastructure` (`IPHONE_UDID` `ADE09605…`, `IPAD_UDID` `8250D97E…`, `SPARE_UDID` `E2BF974E…`) are absent from the current simulator inventory. Recorded as a fact for round 2's infrastructure step; the owner's sign-off did not depend on them (the plan's spot-check step was at the owner's discretion, and the signed evidence is the persisted table plus the recorded rechecks).
- `.planning/REQUIREMENTS.md` already showed A11Y-01 checked (traceability `Complete`) since 2026-08-23, ahead of this sign-off. Left as is; this plan is the one that actually completes A11Y-01, and the traceability row is refreshed by the metadata step only if the tooling touches it.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None. Both changes are complete: a live lint rule and a recorded signature.

## Threat Flags

None. No new network endpoint, auth path, file access pattern or schema change; the plan's threat register (T-16-07, T-16-04, T-16-06 mitigated; T-16-SC accepted, no package installs) covers everything touched.

## Next Phase Readiness

- Round 1 is signed and closed; round 2 is unblocked under D-23. Ready for wave 12: 16-13 (contrast audit) and 16-14 (contrast helper), both `depends_on` this plan.
- Round 2's first infrastructure step must re-derive simulator UDIDs; the ones recorded in `16-SWEEP.md § Infrastructure` no longer exist.
- Phase 16 is not complete (12/26 plans); A11Y-02 remains open. Do not push without the owner.

---
*Phase: 16-dynamic-type-accessibility*
*Completed: 2026-09-11*

## Self-Check: PASSED

- Files: `.swiftlint.yml`, `16-SWEEP.md`, `16-12-SUMMARY.md` present
- Commits: `d5afe78f`, `c5138ea7` present in history
- Absolute home-directory paths (grep for the home prefix) in this file and `16-SWEEP.md`: 0
