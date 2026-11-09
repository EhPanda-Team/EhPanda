# 20-09 Device record

## Task 1: iPad Release build and the Gallery Detail stall (DEV-18-01, Research §8)

**Outcome: as designed.** Ten cold launches, ten details shown, no stall. The slowest took 5.88 s from the tap,
which includes the driver's own time. The 30-second ceiling was never close.

### Consent and setup

- Consent: owner msg 2885, answering card 2884: "I will connect the iPad but you run the verification". The owner
  only connected the iPad. The agent did the build, the install and all ten launches. Owner msg 2887 then named the
  device and allowed control of it through the Device MCP app. The owner tapped nothing.
- Device: the owner's iPad mini (6th generation, iPad14,1), iPadOS 27.2 (24B119), Developer Mode on, connected over
  the local network. Portrait, 744 x 1133 points. Phase 16's stall was seen on iPadOS 27 beta simulators of an
  iPad Pro 11-inch, so this is a different size class.
- Build: branch `feature/gsd-phase-20` at `ac03a2ca68251420f8bdfddf5700250896ae5ed3`. **Release** configuration,
  version 3.0.0 (159), built with
  `xcodebuild -project EhPanda.xcodeproj -scheme EhPanda -configuration Release -destination "platform=iOS,id=<iPad>"
  -derivedDataPath $TMPDIR/ehp20-09 -allowProvisioningUpdates build`. The build succeeded with no errors in
  97.8 s. It was the only xcodebuild running on this Mac at the time.
- Signing: the owner's local `Config/LocalSigning.xcconfig`, automatic signing, development profile. The worktree
  had no copy of this ignored file, so the main checkout's copy was placed in the worktree for the build and removed
  right after. No tracked file changed. The worktree has no `Analytics.local.xcconfig`, so this build carries no
  analytics app ID and sends nothing.
- Install: `xcrun devicectl device install app` over the 3.0.0 (158) copy already on the iPad.
- Setup the agent did on the device:
  1. The first launch stopped at iOS's "Untrusted Developer" alert. The agent trusted the owner's own development
     certificate in Settings › General › VPN & Device Management. No passcode was asked.
  2. The next launch met the first-launch screens, as a user would. The agent ticked the age declaration, chose
     **Minimal** analytics, and tapped Continue on each screen. Home then loaded from E-Hentai over the network.
  3. One rehearsal launch checked the driver. It is not counted below (5.03 s to Home, 3.71 s to detail, no stall).

### How the launches were driven

The launches used Device MCP over one persistent session, not an XCUITest run, so no UI-test runner was built or
signed. The driver script and its client stay on the Mac and are not committed. For each launch:

1. Terminate the app, wait 2 s, and confirm it is no longer in front (cold launch: the process is gone).
2. `launch_app`, then wait for Home's "Front Page" section. This gives the **Home** column.
3. Wait 2 s, then read the accessibility tree and find the first Home gallery: the carousel card in front
   (`home_slideshow_title_<gid>`).
4. **Baseline**: tap the status bar (a no-op, since Home is already at its top), then confirm an element that is
   already on screen. This measures Device MCP's own cost for a tap plus a fresh tree read.
5. Tap the card's centre. Wait for the detail sheet's Read control (`book.fill`), giving the **Sheet** column. Then
   wait for "Find Similar", which only shows once the gallery's detail has loaded, giving the **Detail** column.
   Both waits share the 30 s ceiling.
6. On a stall, the plan was an `xctrace` Time Profiler sample attached to the app for 10 s (this devicectl has no
   `process sample` subcommand), plus a screenshot and the spin reports. No launch stalled, so none was taken.

Times are wall-clock seconds around the Device MCP calls. **Net** is Detail minus Baseline, an estimate of the
app's own time with the driver's cost taken out. The whole run was screen-recorded.

### Launches

| Launch | Detail (from tap) | Home (from launch) | Sheet (from tap) | Baseline | Net | Outcome |
|---|---|---|---|---|---|---|
| 1 | 5.35 s | 5.77 s | 5.33 s | 1.39 s | 3.96 s | detail shown, no stall |
| 2 | 5.45 s | 6.45 s | 5.42 s | 2.47 s | 2.98 s | detail shown, no stall |
| 3 | 4.25 s | 5.77 s | 4.24 s | 1.11 s | 3.14 s | detail shown, no stall |
| 4 | 4.72 s | 6.12 s | 4.70 s | 1.11 s | 3.61 s | detail shown, no stall |
| 5 | 3.66 s | 5.31 s | 3.64 s | 0.99 s | 2.67 s | detail shown, no stall |
| 6 | 4.76 s | 5.53 s | 4.74 s | 1.15 s | 3.61 s | detail shown, no stall |
| 7 | 3.69 s | 5.48 s | 3.67 s | 1.08 s | 2.61 s | detail shown, no stall |
| 8 | 5.88 s | 5.34 s | 5.87 s | 1.05 s | 4.83 s | detail shown, no stall |
| 9 | 4.17 s | 5.85 s | 4.15 s | 1.20 s | 2.97 s | detail shown, no stall |
| 10 | 4.23 s | 5.12 s | 4.22 s | 1.04 s | 3.19 s | detail shown, no stall |

The table's first time column is the plan's measure: from the tap to the detail being shown.

- Detail from the tap: 3.66 to 5.88 s (median 4.5 s). Net of the driver: 2.61 to 4.83 s. Cold launch to Home:
  5.12 to 6.45 s. These figures include network time to E-Hentai.
- The card in front changed between launches as the popular list changed. Five different galleries were opened.
- In every launch, the Read control and "Find Similar" turned up in the same tree read. So the sheet and the loaded
  detail appeared together, within the tool's resolution.
- After the run, Device MCP's `list_crashes` (kind `all`) listed no EhPanda crash, spin or hang report on the iPad.
- The app answered the next command after every detail. The screenshots show a complete detail sheet each time:
  header, stats, tags, and the Previews section starting.

### Stall samples

None: no launch came near the 30 s ceiling, so no sample was taken.

### Evidence (local to this Mac, not committed)

This evidence is kept out of the repository because it shows adult content and the device's name.

- Screen recording of all ten launches: `$HOME/Movies/Device MCP/ehp20-09/ehp20-09-ipad-ten-launches.mov`
  (339.6 s). Rehearsal: `ehp20-09-ipad-rehearsal.mov` in the same folder.
- Detail screenshot for each launch: `$HOME/Movies/Device MCP/ehp20-09/launch-<n>-detail.png`.
- Driver log, driver, Device MCP client and build log: `drive.log`, `drive.py`, `mcp.py` and `build.log` in the
  same folder.

### Reading

Phase 16 recorded a cold Gallery Detail stall on iPadOS 27 beta simulators: about 100% CPU in SwiftUI layout. It
did **not** reproduce on real hardware with a Release build of this branch, in ten tries out of ten. This is one
device size (iPad mini, portrait) and one OS (iPadOS 27.2). Larger iPads and landscape were not covered here.
Nothing reproduced, so this check raises no gap for a closure plan.

## Task 2: iPhone continued background downloads (Phase 15 SC2)

**Outcome: as designed.** The SC2 procedure was repeated on the 3.0 build, with three continued-processing
sessions across two queues, each with a repair. On every frame read, the system card showed real progress
that never went backward, and it kept "· 2 galleries" up to the moment of the cancel. Both repairs climbed
from their announce. In both card cancels, every gallery in the queue was paused. To compare a repair, the
same repair was then paused by hand in the app, and it ended in the same state. One observation from that
comparison is filed for the owner as **G-20-09-1** below. It is not an SC2 failure, because both routes behave
the same way.

All times below are UTC on 2026-11-09.

### Consent and setup

- Consent: owner msg 2893, answering card 2892. The agent ran the whole procedure through the Device MCP app.
  The owner tapped nothing, and no passcode or Face ID prompt came up.
- Device: the owner's test iPhone 11 (iPhone12,1), iOS 27.2 (24B120), on Wi-Fi with airplane mode on, and
  charging. While the app was in the background, the app's log reported the thermal state as `serious`. Nothing
  slowed because of it: pages kept arriving at 1 to 2 s each.
- Build: the same Release build as Task 1, 3.0.0 (159). The branch head was `4906e86c2`, which differs from Task
  1's `ac03a2ca6` only by this file. It was built with the same `xcodebuild ... -configuration Release ...
  -allowProvisioningUpdates build` line, with the iPhone as the destination. The build succeeded. The signing
  handling and the missing analytics app ID were the same as in Task 1, and no tracked file changed.
- Install: `xcrun devicectl device install app` over the copy already on the iPhone. The app's data from the
  Phase 15 rounds in August was kept, so their galleries were available.
- Setup the agent did on the device: it trusted the development certificate in Settings, and at the first launch
  it ticked the age declaration and chose **Minimal** analytics.
- How the agent observed:
  - The system card: Device MCP's accessibility tree of the Lock Screen, read every 11 to 12 s, plus screenshots.
  - The app: its own activity log, copied off the device with `xcrun devicectl device copy from`.
  - The queue: the Downloads rows and each gallery's Download Status sheet.
  - The whole session was screen-recorded (31.7 min).
- Repair fixture: built as in Phase 15 round 6. The agent opened the gallery's folder in Files.app, deleted every
  image file from outside EhPanda, and left only `manifest.json`. The record still claimed every page while no
  page was on disk. In the app, Verify Images then marked the gallery Needs Attention, and Retry Pages
  started the repair.

### Round A: repair and second gallery, card watched (06:16 to 06:20)

| Step | Observation |
|---|---|
| Repair fixture | Onna no Battle (27 pages): all image files deleted in Files.app. Verify Images, then Retry Pages. |
| Start in foreground | Session granted at 06:16:06. Heartbeats `6 / 27`, `13 / 27`, `19 / 27`, `1 galleries`: **the repair climbed from its announce**, not from the record's stale 27. |
| Second gallery | Berserk guidebook (194 pages, about 56 already on disk) resumed at 06:16:45. The basis became `83 / 221`, `2 galleries`. The repair completed at 06:16:49 with all 27 pages and the cover written again. |
| Background | 06:16:55. |
| System card | 15 Lock Screen reads from 06:17:18 to 06:20:14, all "Downloading Galleries · N / 221 pages · 2 galleries": 98, 102, 109, 116, 119, 119, 119, 122, 127, 130, 134, 135, 144, 147, 153. One more read at 06:19:39 got no accessibility tree (OCR only) and is not counted. The count **never went backward**. The three reads at 119 are a page transfer that got no bytes for 13 s. The app logged it as starved and nudged its progress (nudge 2 to 4 of 30, far below one page). The card held its value and did not fall. |
| Cancel | **Not reached in this round.** At 06:20:33 the agent's driver used Device MCP's `launch_app` to bring the app forward. That relaunched the app, ending the process, and with it the session, at `153 / 221`. iOS then left a "Downloading Galleries · Task failed" card under Background Activities. This was a driver error, not the procedure. Every later foreground used `xcrun devicectl device process launch`, which brings the running process forward (same process id afterwards). |

### Round B: two galleries, cancel from the card (06:22 to 06:24)

| Step | Observation |
|---|---|
| Start in foreground | After the relaunch, Berserk carried on in the foreground from page 131 with no session, reaching 149 / 194 by 06:21:46. Ix (144 pages, paused in the app at 11 since August) was resumed in the app at 06:22:00. The session was granted at once with a basis of `338` = 194 + 144, `2 galleries`. |
| Background | 06:22:10. Heartbeats `177`, `184`, `192`, `198`, `204` `/ 338 pages, 2 galleries`. |
| System card | Photographed at 06:22:54: "Downloading Galleries · 205 / 338 pages · 2 galleries", stop button live. Round A's "Task failed" card was still listed above it. |
| Cancel from the card | The agent pressed the card's stop button at 06:22:54. Berserk had completed one second before (194 pages, 06:22:53). The log shows: `Continued-processing session expired, pausing schedulable downloads.` and then `Download paused` for Ix. That expired line follows a real cancel press here. The card disappeared. |
| Foreground and compare | 06:24:33. Berserk: Downloaded 194 / 194. Ix: **Paused 11 / 144**, resumable. That is the state Ix had from pausing it by hand in the app, so nothing was lost and nothing was left running. |

### Round C: repair plus a paused gallery, cancel from the card mid-repair (06:27 to 06:33)

| Step | Observation |
|---|---|
| Repair fixture | Gallery M (gid 4127369, 112 pages): all 113 image files deleted in Files.app, `manifest.json` kept. Verify Images, then Retry Pages. |
| Start in foreground | Session granted at 06:27:55. Heartbeats `8 / 112`, `15 / 112`, `1 galleries`: **the repair climbed from its announce**. Ix was resumed at 06:28:24, and the basis became `36 / 256` (112 + 144), `2 galleries`. |
| Background | 06:28:35. The card on the Lock Screen at 06:28:39 read "42 / 256 pages · 2 galleries". |
| System card | 8 reads from 06:28:43 to 06:30:04, all "N / 256 pages · 2 galleries": 42, 47, 56, 66, 73, 81, 90, 97. The count only went up. The log continued to `114 / 256` at 06:30:28. Ix stayed at 11 the whole time because the queue downloads one gallery at a time. |
| Cancel from the card | The agent pressed the stop button. The log at 06:30:36 shows: `session expired, pausing schedulable downloads`, `Download paused` for M (page 110 had just started), and `Download paused` for Ix. The card disappeared from the Lock Screen (screenshot at 06:30:45). |
| Foreground and compare | 06:32:47, the same process brought forward. Ix: **Paused 11 / 144**. M: the row and its Download Status sheet read **"Downloaded 112 of 112"**, with Downloaded (112), Pending (0), Pause disabled, and no Resume. On disk there were 110 pages and the cover. Verify Images (06:33:53, `Working manifest reconciled, blanked page count: 2`) changed it to Paused 110 / 112, Pending 111 to 112, with Resume. Resume finished M at 06:35:33 (112 pages). |

### In-app pause baseline for the repair (06:36 to 06:39)

Before this check, the record had only been seen being paused from the card in the middle of a repair. To
compare, the same fixture was rebuilt on M and paused by hand:

1. All 113 image files were deleted in Files.app, with `manifest.json` (112 of 112 hashes) kept. The row then
   read "Downloaded 112 of 112". After Verify Images it read "Needs Attention 112 of 112".
2. Retry Pages at 06:37:39 started the repair. Heartbeat `8 / 112`. The sheet read "Downloading 10 of 112",
   Pending 11 to 112, so the repair climbed from its announce again.
3. The sheet's **Pause** button at 06:37:55. Logged: `session drained, terminal progress pushed`, then
   `Download paused`. The row and sheet then read **"Downloaded 112 of 112"**, with Pending (0) and Pause
   disabled. This is exactly the state the card cancel left in Round C.
4. Verify Images (06:38:09, `blanked page count: 99`) changed it to Paused 13 / 112. Resume brought M back to
   Downloaded 112 / 112, with 112 pages, the cover and the manifest on disk.

So the card cancel and an in-app pause end in the same state for a repair as well as for an ordinary download.
This matches the design: the expiry path pauses each gallery through the same primitive as the app's Pause
button (`DownloadClient+ContinuedSession.swift`, `pauseAllSchedulable`).

### SC2 clauses

| Clause (15-UAT test 2) | Verdict |
|---|---|
| One neutral card, "Downloading Galleries" | Pass. Each live session showed one card with the app icon, the title, and a stop button. |
| The counts advance with real work and never go backward within a reporting regime | Pass. 23 card reads in Rounds A and C, all non-decreasing. The plateau in Round A was a starved transfer, held by the bounded nudge. The basis changed only when a gallery joined (27 to 221, 112 to 256), and the count went up across each change. |
| The subtitle keeps the gallery count on every frame, including the last | Pass for every frame read. Each of them, including the last frame before both cancels, showed "· 2 galleries". This round had no drain-to-completion frame while the app was in the background. Rounds B and C ended by cancel, and the restore runs finished in the foreground. |
| A repair climbs from its announce | Pass, three times: 6 / 27, then 8 / 112, then 8 / 112 again in the baseline. None started at the record's stale claim. |
| Card-cancel state matches the in-app per-gallery pause baseline | Pass. Ix was Paused 11 / 144 after both cancels, the same as its hand-paused state. For M, the repair paused from the card and the repair paused by hand both read "Downloaded 112 of 112" until verified. |

### G-20-09-1 (for the owner to decide; not an SC2 failure)

**Observed:** when a repair is paused, whether from the card or by hand, the gallery reads "Downloaded N of N"
while pages are still missing on disk. Pause is then disabled and there is no Resume. Only Verify Images brings
back the true count and the Resume button. A reader opening it would meet the missing pages.

**Cause:** Phase 15's design. The record claimed N of N when every file was deleted, and validation refuses
to blank a whole gallery (closed as no defect in G-15-2G). While the repair is running, the row reads the run's
progress (G-15-2F). Once the run stops, the row goes back to the record, and the record still claims every page.

**Scope:** this needs a whole gallery deleted from outside the app and then a pause before the repair ends.
Phase 15 never paused a repair, so this is new information, not a regression.

**Options:** for example, write the run's progress to the record when a repair is paused, or blank the record
when a whole-gallery repair starts. Either one is a code change, outside this plan.

### Evidence (local to this Mac, not committed)

This evidence is kept out of the repository because it shows adult content and the device's name. It is all in
`$HOME/Movies/Device MCP/ehp20-09/`:

- Screen recording: `ehp20-09-iphone-sc2.mov` (1903 s).
- Card screenshots: `card-live-before-cancel.png`, `card-after-cancel.png`, `r2-card-1.png` and
  `r2-card-after-cancel.png`.
- Row and sheet screenshots: `card-state-1525.png`, `r2-mina-status.png` and
  `baseline-repair-paused-sheet.png`.
- Card read log and its reader: `card.log` and `monitor.py`.
- The app's activity logs: `app-log-run2.jsonl` and `app-log-run3.jsonl`.
- iPhone build log: `build-iphone.log`.

After the run, Device MCP's `list_crashes` (kind `all`) listed no EhPanda crash, spin or hang report on the
iPhone.
