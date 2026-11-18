# Phase 19-12: Candidate Screenshot Runs & Snapshot Repository

**Status:** Candidate re-recording in progress (run `44279625701`); open pre-check items in `19-13-PRECHECK.md` must be resolved before baseline publication.

## Owner Decisions Recorded

- **Candidate runs on hosted runners (owner decision):** Full 72-shard candidate runs were authorized and dispatched on `snapshot-gate.yml` (`mode=candidate`) with nothing published to the snapshot repository until `19-13` approval:
  - Run `44025665174` on `16a08f42a` (`baseline1` candidate: 19,512 recorded, 360 not applicable, 0 picture errors).
  - Run `44137794244` on `ce3732a89` (`baseline2` candidate after `A1–A9` scenario fixes: 19,512 recorded, 360 not applicable, 0 picture errors; native policy job failed on iPhone and was fixed before run `44279625701`).
  - Run `44279625701` on `84c9c00bd` (`baseline3` candidate after `A12`, run-to-run settle/bar/keyboard/alert stability fixes, and `NativeVisualPolicyUITests` + `snapshot_infra.py` fixes; dispatched 2026-11-18 with explicit owner go-ahead).
- **Public snapshot repository creation (owner decision):** Created `https://github.com/EhPanda-Team/ehpanda-snapshot` as a public repository with only `README.md` (`Scripts/visual/snapshot-repo-README.md`) in its initial signed commit `14a6b03eb1ff80779093746a4e560da37fcf682e` (`Describe the snapshot repository`). No candidate pictures have been pushed.

## Candidate Set Counts & Size (`44137794244` / `ce3732a89`)

- **Recorded pictures:** `19,512` (`138` scenarios × `144` coordinates = `19,872` matrix coordinates, minus `360` deterministic `notApplicable` coordinates).
- **Total size:** `4,937,105,350` bytes (`4.94 GB` decimal / `4.60 GiB`), under the 5 GB storage threshold (`19-12-PLAN.md` R-2).
- **Slice count:** `12` `(family, locale)` slices (`1,626` pictures each), every slice well under the `1.8 GB` push limit (largest slice `ipad/de` at `0.58 GB`).

| Slice | Pictures | Bytes | Size (GB) | Limit Check (`< 1.8 GB`) |
| --- | ---: | ---: | ---: | --- |
| `ipad/de` | 1,626 | 578,550,581 | 0.58 | pass |
| `ipad/en` | 1,626 | 563,139,941 | 0.56 | pass |
| `ipad/ja` | 1,626 | 570,185,058 | 0.57 | pass |
| `ipad/ko` | 1,626 | 541,670,849 | 0.54 | pass |
| `ipad/zh-Hans` | 1,626 | 546,136,493 | 0.55 | pass |
| `ipad/zh-Hant` | 1,626 | 551,902,853 | 0.55 | pass |
| `iphone/de` | 1,626 | 278,019,440 | 0.28 | pass |
| `iphone/en` | 1,626 | 263,653,488 | 0.26 | pass |
| `iphone/ja` | 1,626 | 271,204,471 | 0.27 | pass |
| `iphone/ko` | 1,626 | 252,755,651 | 0.25 | pass |
| `iphone/zh-Hans` | 1,626 | 258,698,342 | 0.26 | pass |
| `iphone/zh-Hant` | 1,626 | 261,188,183 | 0.26 | pass |

## Remaining Work Before Closing `19-12` / `19-13`

1. Complete run `44279625701` (`84c9c00bd`), assemble `baseline3`, update the size table above if byte totals shift, and verify green `native-policy` jobs plus zero unintended run-to-run variation against `baseline2`.
2. Resolve every `owner to decide` item (`B1–B2`, `C1–C16`, and `A11`) tracked in `19-13-PRECHECK.md` — fixing and re-recording affected shards wherever the owner chooses a code change (D-17).
