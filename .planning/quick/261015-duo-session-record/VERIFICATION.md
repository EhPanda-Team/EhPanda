---
type: retrospective-verification
recorded: 2026-10-15
status: historical-and-integrated-evidence
implementation_head: 37461f3980a0a057078b5539c54efea285ebf43e
---

# Verification record and limits

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

D91 withdraws the iPad Home two-column implementation and its divider/ranking refinements.
The older results below remain historical; current rollback checks are recorded in
[the iPad Home rollback](IPAD-HOME-ROLLBACK.md).

The table below retains results from the implementation session. Fresh post-cherry-pick builds,
unit tests and four iPad/Duo UI checks are recorded separately in [Migration](MIGRATION.md#fresh-integrated-validation-2026-10-15).
Reports below name commands, logs, failure investigations and captures. Original source hashes are
provenance; migration remaps implementation references but does not turn old runs into new evidence.

| Scope | Recorded result | Durable report |
|---|---|---|
| Reader native bars, scroll indicator, measured routing | Final full reader suites: 8/8 on Duo and 8/8 ordinary iPhone, first attempts; warning-free build. Open and cover-landscape host routing checked. | [Initial reader verification](evidence/reader-initial.md) |
| Split Home and nested sheets | Full FeatureTests run 1,200 passes, 13 pre-existing known issues; final affected targets 117 App + 38 Home. Six final Duo Home UI cases passed. | [Home verification](evidence/home.md) |
| Right scroll/title isolation and crease | Exact title x/y/width/height and left-content checks at standard/AX1/AX3/AX5; native ordinary roots cold/live size checks; selected crease captures. | [Title and crease](evidence/hinge.md) |
| Reader orientation and held scrub | Final 186 unit tests (88 models, 43 Home, 55 reader); ordinary-phone manual control, iPad and Duo auto-entry/rotation/reentry, opt-out; preview stays through eight-second hold. | [Orientation and scrub](evidence/reader-followup.md) |
| Cover/open Duo and NewDawn | Cover actual-page-pixel checks; open Duo orientation and opt-out first-attempt passes; iPad 50% selected capture equals reviewed screenshot SHA-256. | [Final orientation/NewDawn](evidence/orientation-final.md) |
| Live-loading handoff correction | Normal relaunch without fixture flags; real reader smoke passed in 29.138 seconds and real inner-display pages seen. No production network code change. | [Correction at end of report](evidence/orientation-final.md) |
| Native side tabs restored | Portrait pushed list → landscape native Back → split Home → portrait; seven remaining Home regressions and cover toolbar compression: nine relevant tests passed. | [Side tabs](evidence/side-tabs.md) |
| Whole-Home side refresh | Exactly one Reload; native side placement, successful tap, pane geometry and six rankings; title/rotation regressions. | [Refresh](evidence/refresh.md) |
| Half reader panel | Four focused Duo tests, ordinary iPhone and iPad centered-panel probes; held touch screenshots, RTL and Close count. | [Lower panel](evidence/lower-panel.md) |
| Fully open Duo/iPad panes | 99 related unit tests; nine UI checks for Home, opposite sheets, reader, RTL, held scrub and ordinary-phone exclusion. | [Landscape extension](evidence/landscape-panes.md) |
| Opposite control button / animation | Four focused UI tests, same-height button, iPad Close above slider. 60 fps recording and intermediate frame show real motion with Reduce Motion off. | [Opposite controls](evidence/opposite-controls.md) |
| Final iPad divider/Toplists | Native nested opposite-sheet test passed on iPad (28.665 s) and Duo (23.278 s); final 2 pt build passed (27.388 s). Later width/thickness visual refinements were not a new complete UI matrix. | Local `.build/home-divider/` logs, final source in HomeView/HomeView+Sections. |
| Favorites/Search/Downloads proposal | Native prototype warning-free build and SwiftLint; nine screenshots: three recommended pages on iPad/Duo, three iPad alternatives. | [Proposal](proposal/PROPOSAL.md) |

## Failed attempts and supersession

- A navigation minimization modifier kept Home visible but shrank it; independent navigation hosts
  replaced it. The failed baseline/experiment is not counted as meeting D18.
- Forcing horizontal Home bars moved native tabs to the bottom. That implementation was corrected
  by splitting only the root and keeping pushed hosts against the display edge.
- A nested SwiftUI sheet experiment placed the actual nested Detail on the wrong half; a native
  presentation owner fixed the measured composition. No claim of a general OS root cause is made.
- XCTest orientation alone did not rotate Duo. A stale inner/cover simulator routing state required
  restarting the dedicated simulator. simulator pose driver pose changes and cover/inner mapping establish the
  later successful results; no application workaround was added.
- An early dual-page retry inherited changed toggles and is **not** evidence. The first attempt's
  visible pages establish spread preservation; the indicator normalized to its first page.
- An exploratory native search script failed to establish its interaction, so it does not establish
  search-state continuity. This gap remains open.
- Initially invisible swap animation was explained by the simulator's Reduce Motion setting. Product
  code correctly honors it; disabling the setting for visual review demonstrated the transition.
- Leaving fixture network flags active caused the owner's real-image loading failure. This was an
  agent cleanup error. Normal live launch and the smoke check corrected the handoff.

## Durable visual review

Crease choices are A light (image removed from repository history), A dark (image removed from repository history),
B light (image removed from repository history), B dark (image removed from repository history),
C light (image removed from repository history), C dark (image removed from repository history). Owner selected B.
NewDawn comparison: 60% (image removed from repository history) and 50% (image removed from repository history); owner selected 50%.
These screenshots use neutral test fixtures. Live gallery screenshots are not published in this record.

## What this evidence does not establish

- Physical devices, a complete manual VoiceOver audit, live RTL-language UI, and interactive iPad
  window resizing were not covered by the recorded final UI checks.
- Inner-display XCTest captures may show the cover/black; host `simctl` captures supply visual
  evidence. Some inner tests use accessibility page state; cover/iPad additionally check page pixels.
- Proposal screenshots do not verify production state flow, precise hinge alignment, opposite sheets,
  keyboard/focus continuity or standard/AX1/AX3/AX5 behavior for the proposed screens.
- Known issues reported by earlier FeatureTests were pre-existing diagnostics, not new passes hidden
  by retries. Where an older log was overwritten, the historical report explicitly says so.
- Fresh integration coverage and the corrected inventory failures are recorded separately in MIGRATION.md;
  they do not establish every broader historical/manual scenario on the new branch.

## Repeatable validation rules

Use dedicated app simulators and run this session’s test commands sequentially. D55 explicitly
permits other sessions to test concurrently on their own dedicated simulators; never operate those
devices or processes. Build with generic iOS Simulator destination; use explicit simulator IDs for execution.
Pass `-parallel-testing-enabled NO` and `-collect-test-diagnostics never`; final validation uses a
single attempt. Do not weaken page, geometry or uniqueness assertions to fit a test driver.
Restore normal launches and verify no `EHPANDA_` test flags before returning devices to the owner.


## Owner inspection launch — 2026-10-23

The owner requests the current app on Duo and a non-Duo iPhone. Both dedicated review simulators
remain booted with the app running for manual inspection:

| Device | Runtime | Simulator UUID | Launch PID |
|---|---|---|---:|
| EhPanda Review iPhone Duo | iOS 27.1 | `004AEA0A-A396-4F39-93B8-118DD2F05975` | 40755 |
| EhPanda Review iPhone 17 | iOS 27.0 | `CC444738-6672-47F8-BCCC-AC3BFBC344C5` | 41480 |

Both use the same normal universal app already installed on the review iPad after D129
(`0720e193e56c3e72c79649e38829445b7478b995`, including the 64-point Search section gap).
The former build cache is no longer present, so the installed verified artifact is reused and its
executable hashes are retained in `.build/manual-review-phones/provenance.json`. This launch does
not claim a new build or test run. Installation, launch and subsequent process checks succeed;
all inherited `SIMCTL_CHILD_` variables are removed from the launch environment. The phones have
their own app data; no review-iPad data or settings are copied.

The installed iOS 27.1 runtime supports only Duo. Creating an iPhone 17 on it returned an
incompatible-device error, so the ordinary iPhone uses the compatible iOS 27.0 runtime. Commands,
device IDs and delivery evidence are retained in `.build/manual-review-phones/`. This is a manual
review handoff, not completion of any outstanding acceptance gate.


### Device Hub visibility follow-up — 2026-10-23

The owner can see only the review iPad in Device Hub. A fresh `simctl` inventory confirms all
three EhPanda review devices are booted, but CoreDevice's inventory contains only the iPad.
Device Hub displays that same stale inventory. Its simulator filter is correct. New Window and
Quit and Keep Simulators Running actions, followed by reopening the app, leave the two phones
absent. Thus the earlier successful install/launch and process checks did not establish that
the devices were accessible for inspection through Device Hub.

Filtered evidence before recovery is retained in
`.build/manual-review-phones/device-hub-simctl.json` and
`.build/manual-review-phones/device-hub-coredevice.json`.

The owner explicitly approved restarting the shared CoreDeviceService on 2026-10-23. Sending
SIGTERM to that service alone replaced PID 8402 with PID 18153; CoreSimulatorService retained
PID 33626. CoreDevice discovery then included all three EhPanda review devices, and Device Hub
showed the same restored inventory. Selecting the iPad, iPhone 17 and iPhone Duo successfully
connected their app displays. The two phones exposed the live Home and Frontpage accessibility
content; Duo also exposed all four app tabs. Device Hub is left on Duo for owner inspection.

All three simulators remain booted. No simulator was deleted or reset, CoreSimulatorService
was not restarted, and no product code changed. Recovery evidence is retained in
`.build/manual-review-phones/coredevice-restart.json`,
`.build/manual-review-phones/coredevice-refresh-command.json` and
`.build/manual-review-phones/device-hub-coredevice-after-restart.json`. This resolves the
observed discovery and display-connection issue; it does not establish why the shared service
originally stopped synchronizing its inventory.


## Phone Home and adaptive Library — 2026-10-23

D130–D132 are implemented and delivered to the retained review iPhone, Duo and iPad. The
[follow-up verification record](PHONE-HOME-LIBRARY.md) contains exact source commits, seven
Library feature tests, four passing UI cases, cold and live text-size coverage, the six Duo
pose results, normal launch evidence and a neutral phone screenshot. It distinguishes the
final sidebar-state correction's native checks from the earlier UI runs, and records fixture
side effects on review-device preferences/authentication. Phase 17 gates are unchanged.
