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
