# Phase 17: WR-01 rebuild-during-turn check

**Date:** 2026-11-05 · **Source:** `b5eca09d1` · **Run by:** agent (owner rule msg 1652) · **Harness:**
throwaway XCUITest class `ZZUAT17WR01UITests` (`testWR01RebuildMidTurn`, `testWR01NegativeControl`), not
committed. The throwaway harness is preserved outside the repo for Phase 18 Step 4b, which adds the real
committed tests.

UAT tests 1 to 3 (17-UAT.md) never reached the condition WR-01 guards: a pager rebuilt while a turn is
still animating. This check aims at that condition directly.

## Method

- **Trigger:** Auto-Play at 1 s drives page turns. In the logs most turns run idle → animating → idle in
  0.30–0.34 s (207 of 268 in D1); the rest take up to 0.61 s. With the More menu already open, a quick
  tap on Reload All Images rebuilds the pager through `.id(forceRefreshID)`. On iPhone the rebuild
  comes 0.64–0.73 s after the tap (per-run medians 0.66–0.71 s). On iPad it comes 0.85–0.92 s after.
  The taps were aimed with a measured lead, so each rebuild falls at a planned offset from a turn. The
  iPad lead was not retuned.
- **Pass criterion, per try:** after the rebuild, the page indicator and the probe settle on the same
  page and hold it for 1.5 s. Then a next-edge tap and a previous-edge tap each move ±1, and the
  indicator and probe agree after each one. 20 tries per run.
- **Rebuild timing:** taken from the video. The rebuild is the frame where the new pager first draws,
  matched to the More menu's dismissal. "In the window" means the rebuild came 0–0.35 s after a turn
  started. For D1 and FI1 the app log (`WR01DIAG` NSLog) is the ground truth.

## Results

| Run | Device | Build | Tries | In the 0.35 s window | Result |
|---|---|---|---|---|---|
| W1 | iPhone Air | fixed (`b5eca09d1`) | 20 | 18 | 20/20 PASS |
| W2 | iPhone Air | fixed | 20 | 11 | 20/20 PASS |
| W3 | iPad Pro 11 | fixed | 20 | 9 | 20/20 PASS |
| **Fixed total** | | | **60** | **38** | **60/60 PASS** |
| N1 | iPhone Air | plain revert of the WR-01 calls | 20 | 12 | 20/20 PASS |
| D1 | iPhone Air | N1 revert + NSLog instrumentation | 20 | 9 rebuilt while `animating` (log) | 20/20 PASS |
| FI1 | iPhone Air | D1 + fault injection: the new pager's initial `idle → idle` report dropped | 20 | 10 rebuilt while `animating` (log) | 10/20: all 10 mid-animation tries FAIL, all 10 idle tries PASS |

FI1 failing tries: 1, 2, 4, 5, 7, 8, 10, 13, 16, 19. The xcresult failure text lists exactly these.

## Instrumentation finding

- **D1:** every one of the 20 rebuilds logs `phase idle -> idle` at the rebuild instant (0 ms after
  `rebuild`), including the 9 made while `animating`. Every later Auto-Play turn is `admitted true`. The
  run's only 3 `admitted false` lines (`holds true`) come from the harness repositioning the reader
  midway, between rebuilds 13 and 14, not from a rebuild. So on this runtime, SwiftUI's first phase
  report on the new ScrollView clears the gate by itself. The premise behind WR-01 doesn't occur, and the
  fix acts as a safety net.
- **FI1 (positive control):** dropping that initial idle report recreates exactly what WR-01 assumes.
  After each mid-animation rebuild, every later Auto-Play turn was `admitted false` (6–7 per try) until a
  drag recovered the pager. The indicator ran 6–7 pages ahead of the shown page (for example 13/7 and
  20/13), and the drag brought both into agreement. Every idle rebuild passed. So the test reaches the
  condition and detects the failure.

## Caveats

- No iPad negative control (N1, D1 and FI1 are iPhone only). The iPad lead was not retuned, and 9 of
  W3's 20 rebuilds fell in the window.
- Video timing is accurate to ±0.03–0.1 s, so the logs are the ground truth for D1 and FI1.
- None of this is a committed automated test. G1 in 17-VALIDATION.md stays escalated to manual-only.

## Evidence (local, `/tmp/ehp-uat17/`)

- Videos: `W1-iphone.mp4`, `W2-iphone.mp4`, `W3-ipad.mp4`, `N1-iphone.mp4`, `D1-iphone.mp4`,
  `FI1-iphone.mp4`
- Runs: `runs/{W1-iphone,W2-iphone,W3-ipad,N1-iphone,D1-iphone,FI1-iphone}.{log,status,xcresult}` and
  `-summary.json`
- App logs: `runs/D1-applog.txt`, `runs/FI1-applog.txt`
- Rebuild timing: `vf/W1-rebuilds2.json`, `vf/W2-rebuilds2.json`, `vf/N1-rebuilds2.json`,
  `vf/W3-rebuilds3.json`
- Control source change: `nc-final.diff` (FI1 revert, instrumentation and fault injection)
- Frames: `mont/WR01-N1-try02.png`, `mont/WR01-W2-try02-13.png`
