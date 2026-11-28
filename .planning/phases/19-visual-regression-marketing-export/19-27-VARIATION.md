# 19-27 Run-to-run variation

The record of 19-27: the tracer's parity with the earlier hand count, the native policy record, the cost at full height, the owner's go-ahead and run A. Evidence is in `$W` (`.capture/agent-work/phase19-27` of the worktree, ignored by git); the earlier sets are `$AW/baseline1/set` (run 44025665174) and `$AW/baseline2/set` (run 44137794244, `ce3732a89`).

## Tracer parity

Commands (Task 1 step 3), the six scenarios `search-results-list`, `report-form-error-alert`, `report-form-ready`, `search-root-empty`, `favorites-signed-out` and `search-typing-suggestions`:

1. `snapshot_variation.py pairs --a "$AW/baseline1/set" --b "$AW/baseline2/set" --scenarios <the six> --out "$W/tracer/pairs.jsonl"`: 43 pairs differ, no key on one side only.
2. `snapshot_variation.py compare --pairs "$W/tracer/pairs.jsonl" --out "$W/tracer" --simulator 'EhPanda iPhone Air (phase19)'`: `compare.xcresult` `Passed`, 2 tests, 0 failed; 43 outcome lines, one per pair, in order; 22 difference pictures.
3. `snapshot_variation.py report ... --artifacts-a "$AW/baseline1/artifacts" --artifacts-b "$AW/baseline2/artifacts" --scenarios <the six> --out "$W/tracer/report.json"`.

Totals over the six scenarios: 821 identical digests; of the 43 pairs, 2 identical pixels, 19 within tolerance, 22 beyond tolerance, 0 size differs, 0 unreadable. Flaky keys (the chosen attempt took more than one try): `search-typing-suggestions__en__large__landscape__iphone__light` in A, `search-typing-suggestions__en__xSmall__landscape__iphone__light` in B; neither is a differing pair.

| Scenario | Hand count | Beyond tolerance (D-10) | Changed pictures | Changed, more than 9 bytes |
| --- | ---: | ---: | ---: | ---: |
| `search-results-list` | 15 | 6 | 15 | 15 |
| `report-form-error-alert` | 10 | 5 | 12 | 10 |
| `report-form-ready` | 5 | 5 | 5 | 5 |
| `search-root-empty` | 4 | 3 | 4 | 4 |
| `favorites-signed-out` | 3 | 1 | 5 | 3 |
| `search-typing-suggestions` | 2 | 2 | 2 | 2 |

The `beyond` counts are `6 5 5 3 1 2`, not the hand count's `15 10 5 4 3 2`. The hand count is reproduced exactly by a different reading: the pairs whose pictures differ in more than 9 channel bytes (the outcome lines' `differingBytes`). So the hand count of 2026-11-18 sized its groups by visible change, not by the matrix's verdict, and its "beyond" label for those groups does not hold under D-10:

- `search-results-list`: all 15 pairs differ only at the search field's clear button (a 17 to 46 pixel box, channel steps 10 to 80), as the hand count describes. The comparison's byte budget is `(1 - 0.9999)` of the picture's bytes, 153 bytes on the iPhone (420 x 912) and 403 on the iPad (834 x 1210) at the device height. The 9 iPad pairs with 310 to 397 differing bytes pass it; the iPhone pairs (450 to 569 bytes) and the iPad pairs at 405 and 963 bytes fail it.
- `report-form-error-alert` and `favorites-signed-out`: the hand count left out the identical-pixels pair and the pair of 5 or 9 differing bytes, and counted the rest, of which the comparison passes 5 and 2 with one-step differences.
- `search-root-empty`: one iPad pair of 257 one-step bytes is within the budget.

The comparison is the matrix's own: `VariationComparisonTests` calls `HostedWindowCapture.compare`, unchanged since `279d155f0` (2026-11-08), before the hand count was taken, and its file holds no precision of its own. The tool is therefore taken as correct and the hand count as a description of the changed pictures, and Task 2 goes ahead on that basis (orchestrator decision within the approved plan, 2026-11-28; no owner decision is reopened). The variation to be fixed at its cause is both columns: the 22 beyond-tolerance pairs fail a compare today, and the 19 within tolerance are the same causes (the clear button, the glass at the alert and the toolbar) caught under the budget.

Deviations in Task 1:

1. The first tracer comparison read every pair as `unreadable`: `pairs` wrote the paths as given (relative), and the test process runs from another working directory. `pairs` now writes absolute paths, and a picture file that cannot be read at all fails the comparison instead of being classed `unreadable` (which now means only a file that is not a picture); both have tests (`test_paths_are_absolute_when_the_sides_are_named_relatively`, `testOutcomes`'s absent file).
2. `report` takes `--scenarios` too, so its identical-digest count covers the same keys as the pairs.
3. `missing.json` is written beside the pairs file.
4. The outcome lines' `largestStep` and `differingBytes` describe a difference; every verdict comes from `HostedWindowCapture`.
5. `search-typing-suggestions` left the inventory in 19-26 (`2a220c751`), but both earlier sets hold it, so the tracer compares it as the plan names it.
6. The Task 1 verify's six counts are `6 5 5 3 1 2`, its `fails_when` value being `15 10 5 4 3 2`; the reason is above.

## Native policy

Run 44279625701 (`84c9c00bd`, 2026-11-18): both `native policy` jobs ended `failure` (`gh run view 44279625701 --json jobs`, read only). The four failed tests, from `$AW/run-44279625701/iphone-tests.json`, `ipad-tests.json` and the artifacts' `xcodebuild-1.log`, each with the change of `5f5bef068` (2026-11-18, "visual: harden policy menu dismiss and scroll", an ancestor of this commit) that answers it:

| Device | Test | Failure | Answered by `5f5bef068` |
| --- | --- | --- | --- |
| iPhone | `testReaderToolbarKeepsPriorityAtEveryWidth` | `NativeVisualPolicyUITests.swift:467`: `XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - The window did not turn.` (43 s in, at the first turn after the reader opened cold) | `EhPandaUITests/NativeVisualPolicyUITests.swift` `turn(_:to:)`: the window is polled with `Polling.wait` and counts as turned only when its frame is not empty (`!frame.isEmpty && ...`), where an `XCTNSPredicateExpectation` had read the frame through a 10 s waiter; with `resetOrientation()`, which sets portrait only when the device is turned |
| iPad | `testColdEntryAtAX3` | `Test crashed with signal term.`: the runner hung at `Setting up automation session` for Xcode's runner bootstrap allowance and was restarted (`Restarting after unexpected exit, crash, or test timeout`), with no test step run | `Scripts/visual/snapshot_infra.py` `SIGNATURES` `service-hub`: a restart after `Setting up automation session` with no test step classes as the simulator's, and `.github/workflows/snapshot-gate.yml` job `native-policy` runs attempt 2 with `-skip-testing:` for every test attempt 1 passed; `reported_every_test` counts an execution-time overrun as a real failure, so a hang is never classed infra (tests in `test_snapshot_infra.py`, the run's own log lines as the fixture) |
| iPad | `testDialogAndMenuStayAnchoredThroughTurns` | `NativeVisualPolicyUITests.swift:540`: `XCTAssertTrue failed - More did not open.` (Quick Search did not appear within 5 s of the tap on the results page's More) | `testDialogAndMenuStayAnchoredThroughTurns`: waits for the results page's heading before tapping More; `checkAnchorThroughTurns(of:from:isDialog:named:outside:in:)` and `dismissPopover(in:outside:until:)` close the menu with a tap on that inert heading, since iPadOS passes a tap outside a context menu to the gallery row under it; the item waits are 15 s |
| iPad | `testSettingMarksAndTitleSurviveSizesAndTurns` | `exceeded execution time allowance of 20 minutes` (at 1,200 s, in the Settings route at `Larger Text`) | `revealElement(_:in:)`: the scroll host is chosen once, before scrolling, and a row not yet built costs one `exists` look per swipe instead of a hittability wait of its own (`downwardScrolls` 4, `maximumScrolls` 10, was 12); `testSettingMarksAndTitleSurviveSizesAndTurns` waits 15 s for Appearance after each turn |

The 2026-11-18 local runs of those tests after `5f5bef068` passed, 2 on the iPhone and 4 on the iPad, as `19-27-PLAN.md` (Task 2 step 1) records them from `local-verify/iphone-1.log` and `ipad-1.log`. Those logs existed only in the main checkout's `.capture` and were lost in the 2026-11-24 wipe, so the plan is the only record of them.

Local run at `42d55786b` (Task 2 step 2), on each phase simulator in turn, iOS 27.2, after `xcrun simctl ui <udid> content_size large`, with 19-11's command (`xcodebuild test ... -testPlan UITests -only-testing:EhPandaUITests/NativeVisualPolicyUITests -collect-test-diagnostics never`), each waiting for every other `xcodebuild` on the host:

| Device | Bundle | Result | Tests | Failed | Skipped | Wall time |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| iPhone Air | `$W/policy-phone.xcresult` | Passed | 10 | 0 | 0 | 1,049 s |
| iPad Pro 11-inch (M5) | `$W/policy-pad.xcresult` | Passed | 10 | 0 | 0 | 1,329 s |

Every test passed at its first and only run, with no warning in either log, so nothing in `NativeVisualPolicyUITests.swift` needed a change. The UITests plan ran the class on one clone of each simulator, its tests one after another, as the hosted job's `-parallel-testing-enabled NO` runs them on one simulator; no difference in behaviour showed.

## Cost at full height

The projection (Task 2 step 3): `$W/projected-cost.json` is the committed `snapshot-cost.json` (run 43681082788, `measured`) with every `secondsPerPicture` times its device's ratio from `19-26-HEIGHTS.md` "The timing ratio" (iPhone 2.89, iPad 1.13, ratio of medians), `source: model`; `snapshot_shards.py --costs "$W/projected-cost.json" --output "$W/projected-shards.json"` plans it. Both plans keep the same 72 shards with the same runs: every shard is one process (one configuration in one orientation), so no table can cut them finer.

| | Committed plan | Projected plan |
| --- | ---: | ---: |
| iPhone seconds per picture | 2.85 | 8.237 |
| iPad seconds per picture | 3.2 | 3.616 |
| iPhone shards (s01 to s36), estimated minutes | 23.7 to 23.8 | 47.3 to 47.5 |
| iPad shards (s37 to s72), estimated minutes | 25.3 to 25.4 | 27.1 to 27.2 |
| Timeout minutes (committed) | iPhone 48, iPad 51 | |
| Bound, `min(timeoutMinutes - 5, 30)` | 30 | 30 |

The rule (Task 2 step 4) fails: all 36 iPhone shards are over both bounds (47.5 against 30, and against the shard's own budget of 43); the 36 iPad shards fit. A re-cut cannot help, since each shard is a single unit, so the iPhone needs a finer unit, which the plan leaves to the owner as a design change. Work stopped here for the owner's decision, before any push or hosted run.

What the measured ratio rests on (`$W/cost/time-vs-height.py` and `tall-model.py`: 19-26's verification sample against 19-18's after-sample, key by key; `project-cost.py` and `model-cost.py` write the two tables and apply the rule):

- On the iPhone a page that keeps the screen height costs what it did (ratio 0.99, 50 keys), and every taller page costs about 2 s more whatever its height: ratio 2.75 at up to twice the screen (46 keys), 2.48 at two to four times (40), 3.92 above four times (32). The extra cost is mostly fixed per tall picture, not proportional to its height.
- The iPad's 1.13 comes from a sample of which 40 of 42 keys keep the screen height (iPad portrait at three configurations); its two tall keys gave 2.93 and 3.06. So 1.13 understates the iPad's matrix.
- Weighted by the committed heights instead (`snapshot_heights.py export`: 398 of 804 iPhone coordinates and 224 of 804 iPad coordinates are taller than the screen, counted per coordinate, not per picture), the ratios are iPhone 1.94 and iPad 1.62 (`$W/modelled-cost.json`, `$W/modelled-shards.json`): iPhone shards 35.4 to 35.6 minutes and iPad shards 33.9 to 34.1, every shard over the 30-minute target and under its own budget (43 and 46).

Either way the committed plan does not stand at full height, and all of these figures are local (one Mac, iOS 27.2); the hosted runner's cost is unmeasured.

### Owner decision (2026-11-28)

Asked in Taiwanese Mandarin, with the four ways on: finding the cause of the fixed cost first, a finer unit, a longer target, or a hosted measurement first. The owner chose 「先查固定成本（建議）」: find, locally, why a page taller than the screen costs about 2 s more a picture, fix it at its cause, then project the cost again, as its own step, with no push and no hosted run in the meantime. The committed plan and cost table stay unchanged until then.
