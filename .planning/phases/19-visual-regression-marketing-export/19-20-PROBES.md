# 19-20 probes

The measuring mode (`Scripts/visual/run-snapshot-local.sh --measure-heights`) takes no picture: each coordinate gets
one line in `heights.jsonl` with the window height its page needs, found by growing the window until the need holds
still. Runs below are local runs on the project simulators; `$W` is `$MAIN/.capture/agent-work/phase19-20` (ignored by
git, no picture and no height file is in the repository). Nothing is committed to the provider files.

## Task 1: tracer, `settings-root`

`SettingsSnapshotTests/testRoot` on the iPhone, `en-large` and `en-accessibility5`, both orientations, light and dark
(`$W/tracer`): `measured=8 cannot-cover=0 did-not-converge=0 error=0 notApplicable=0`; no `results.jsonl` and no
picture was written. Each measured need equals the height 19-19 committed for the same coordinate
(`19-19-TALL-WINDOW.md`), and dark gives the same value as light.

| coordinate (iPhone, `en`) | measured need (light = dark) | steps | 19-19 committed | equal |
| --- | --- | --- | --- | --- |
| `large`, portrait | 912 pt | 0 | 912 pt | yes |
| `large`, landscape | 633 pt | 1 | 633 pt | yes |
| `accessibility5`, portrait | 912 pt | 0 | 912 pt | yes |
| `accessibility5`, landscape | 850 pt | 1 | 850 pt | yes |

A page that fits the screen (portrait) is measured at the device height in no steps; landscape overflows the 420 pt
screen and is covered after one growth step. The measuring mode and the check of 19-19 therefore agree for the tracer
state.
