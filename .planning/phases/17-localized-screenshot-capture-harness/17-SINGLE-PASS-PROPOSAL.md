<!-- Full historical proposal, preserved during the repository split. -->
This proposal records the state before `dd206a7ab` and the resulting implementation. References to
direct commands inheriting retries describe the original problem, not the corrected documented
entry points. The ordinary UITests plan still retains its regression retry policy. Subsequent
appshot-specific consumer wiring is documented in [17-APPSHOT-INTEGRATION.md](17-APPSHOT-INTEGRATION.md).

# Phase 17 single-pass execution proposal

The user authorized this proposal for the current task and clarified that selecting an agent's
recommendation does not prevent future agents from revising the design based on new evidence.
Execution results are also recorded in `$HOME/Library/Caches/Appshot/handoff/STATUS.md`.

The authorized implementation and verification are complete in commit `dd206a7ab`; the original test
plan is unchanged. This proposal covers only the direct UITests commands listed in Task A and does
not bring in changes from capture-cli.

## Original state

`Gate.single_pass_run(plan)` in `Scripts/verify-full-content-capture.py` locates the unique original
xctestrun for the selected test plan under the specified DerivedData directory's `Build/Products`.
It removes every nested `TestRepetitionPolicy`, records the removed entries and saves a separate
`phase17-<plan>.xctestrun`. The original xctestrun and UITests.xctestplan are preserved.

`Gate.run` executes `test-without-building` with that copy and an explicit test selector, with
parallel testing disabled. It checks the expected test count, that every test passed, that there
are no skips, expected failures or Repetition nodes, and that the tests ran on the specified device.
`Scripts/visual/capture-native.py` already uses this path.

Direct `xcodebuild test -testPlan UITests` commands still inherit the test plan's retryOnFailure
policy, allowing up to three attempts. Removing the misused command-line flags corrected the syntax
but did not make these direct commands produce evidence from a single visual test execution.

## Proposed scope

1. Route the affected UITests commands in 17-VALIDATION, 17-RESEARCH and plans 17-05, 17-08, 17-09,
   17-10 and 17-11 through the existing single-pass preparation and verification flow. Preserve each
   original selector, device and actual expected test count. Establish counts from build and test
   enumeration evidence rather than guessing.
2. Reuse the build-for-testing products in the specified DerivedData directory and the existing Gate
   logic for removing retry policies and evaluating results. If the entry point cannot express a
   selector, extend only the necessary argument handling.
3. Build for a generic simulator destination, then execute test-without-building serially, one device
   and one invocation at a time. Wait for tests from other work to finish on their own before starting.
   Retain the complete commands, exit codes, logs and xcresult bundles.
4. Add meaningful checks for the single-pass copy and result validation: the original plan is
   unchanged, the copy has no repetition policy, and repeated, skipped, zero-count or wrong-count
   results are rejected. Each selected test must execute exactly once.
5. Make a separate change on the Phase 17 branch. Inspect additions from other work first and preserve
   unrelated changes. This scope excludes changes to UITests.xctestplan's ordinary regression policy
   and execution of the full visual matrix.

Alternative: retain the direct commands as ordinary regression checks and explicitly state at every
affected location that they cannot serve as single-pass visual acceptance evidence. The existing
native runner would continue to handle strict visual acceptance.

## Execution results

All 196 Python tests passed. One selected test ran on each of iPhone and iPad; the result names and
counts matched the enumerated tests exactly, with no skips or repetitions. The original test plan
was preserved. Complete evidence is in
`$HOME/Library/Caches/Appshot/handoff/phase17-single-pass-verification.json`.
Full scene acceptance for each producer task still requires separate execution.
