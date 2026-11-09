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

## Task 2: iPhone continued background downloads

Not run yet (Task 1 only in this pass).
