# Phase 16 Focus Investigation

## Scope and status

This document records the current evidence for VO-3, W-13, W-8, W-35, and the related withdrawn or pending probes. It is an investigation record, not an acceptance record. Phase 16 is not complete, and there is no blanket approval.

The 2026-09-19 root-cause round is recorded in [Root-cause round (2026-09-19)](#root-cause-round-2026-09-19) at the end. It identifies the VO-3 and W-13 Comments cause as a SwiftUI limitation, records the workaround that was evaluated and the owner ruling against adopting it, states the platform rule behind W-35, and supersedes the W-8 activation-order conclusion below. The earlier sections are kept as the historical record they were written as.

Times below are recorded in the source logs' local JST context unless explicitly marked UTC. The cache paths are written with `$HOME` to avoid embedding a machine-specific home path.

## W33 audio judgement

The ordinary P-M user-listening judgement passed on the new corrected clip. The user confirmed that this recording speaks `P M` correctly:

- `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w33/rootcause-20260918/audio/root-final-0139-date-pm-corrected.wav`
- Source interval: 17.000--21.500 seconds
- Duration: 4.5 seconds
- SHA-256: `d212aecb148a09fd8ed04b064f9acc2aea9ec57e601a5582f6d8d6c63fc3ec55`
- The full recording is 37.162667 seconds, original speed, with no mixing.
- The tested candidate is owner-verified for the audio result. The tested source SHA-256 is `d0b99bda712425785fc8b474f55ab9a5ccddd8c3b6c9e61ef0f7b544e959d77a`.
- Locale preflight and generic build evidence are retained at `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w33/rootcause-20260918/preflight.log` and `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w33/rootcause-20260918/generic-build.log`.

The older miscut is invalid evidence. The prior capital-pronunciation clip is retained only as historical context and is not part of the accepted result. This closes W-33's audio listening criterion only; it does not sign off Phase 16 or accept any other finding.

## W38 reader video

The earlier full and short recordings were missing the required reopening action; that was corrected by user review and they are not valid for the required flow.

The v3 recording is a control group: ordinary swipe navigation with VoiceOver off. It correctly provides a visual `51 / 52` comparison, but it is not native VoiceOver Next evidence.

The v4 recording is the actual native VoiceOver flow: Ctrl-Option-Right advanced content 47, 48, 49, 50, and 51, followed by reopening the panel. The panel then displayed `47 / 52` over a blurred background while page 51 had been reached earlier. The evidence must not claim a clear same-frame page-51 plus panel-page match.

The v4 full and short media details, including the short interval 100.000--176.800 seconds, durations, and hashes, are preserved in the cache provenance at `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/rootcause-20260918/reader-demo/w38-reader-demo-v4-provenance.md`. The user has confirmed the required flow; this is now recorded as a reproduced finding, not a pending judgement. The four-case root-cause record is [16-W38-ROOT-CAUSE.md](16-W38-ROOT-CAUSE.md), with local helper/log/image provenance at `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/w33/rootcause-20260918/reader-matrix/`.

## W8 runtime observations

For root app PID 78554 in one run:

- `01:54:17.475` uploader
- `01:54:18.253` ScreenChanged
- `01:54:19.044` More
- Notifications intercepted inside EhPanda PID 78554 were `1044`, `1001`, and `1069`; `1000` was absent from that app's intercepted stream. This does not mean notification `1000` was absent globally.

For the second run, app PID 82491:

- `02:04:51.401` uploader
- SpringBoard PID 51375 emitted notification `1000`; `52.164` is the attempt and `52.165` is completion of the same emission.
- VOT observed completion at `52.165`
- `02:04:52.954` Will set for More, followed by the actual More selection at `02:04:52.956`

The cold-run precursor is visible in the paired logs: at `02:04:51.364` SpringBoard received an external-keyboard Ctrl event, and the VOT log resolved the right-arrow chord at `02:04:51.371--51.372` to its built-in Move to Next Item command. VOT then emitted DidFocusOnElement and proposed/set an `uploader` element in app PID 82491 at `02:04:51.396--51.401`. SpringBoard's foreground-process/scene and status-bar AX queries begin at `02:04:52.161--52.163`, immediately before the single `1000` attempt/completion at `52.164/52.165`; VOT received Screen Changed at `52.165` and rebuilt its element cache before the More Will set at `52.954` and actual selection at `52.956`.

This establishes a temporal ordering from the native VoiceOver keyboard action through VOT focus processing to the SpringBoard emission. The available logs do not identify the initiating caller upstream of SpringBoard; that absence does not exclude an app, tool, or system origin.

The producer boundary is established at SpringBoard, while the initiating trigger/caller remains undetermined. Raw evidence paths are `/private/tmp/ehpanda-phase16-w8-cold-20260918/springboard.log`, `/private/tmp/ehpanda-phase16-w8-cold-20260918/vot.log`, `/private/tmp/phase16-w8-cold-springboard-0154.log`, and `/private/tmp/ehpanda-phase16-w8-cold-20260918-vot.log`. The persisted focus probe VOT log is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/rootcause-20260918/focus-probe/vot-root.log`.

The same installed single-title binary (SHA-256 `aac62b4762eb1e29f126e2bd7566a12472500bdc98a288d714e6d0134b854b58`) now has a bounded activation-order A/B/A result. The earlier VO-before-modal run (PID 5374) was negative: no post-uploader SpringBoard `1000`, Screen Changed, or More reset. The VO-after-modal run (PID 9062, VOT PID 9412) was positive: uploader at `03:10:03.435`, offset `-70` to `-48.6667`, AXBackBoardServer service connection at `03:10:04.200`, SpringBoard `1000` at `03:10:04.206`, VOT Screen Changed at `03:10:04.207`, and actual More at `03:10:05.005`. The repeated VO-before-modal run (PID 10208, VOT PID 10003) was negative: More `03:12:23.797`, title `03:12:58.163`, uploader `03:13:24.825`, offset `-70` to `-48.6667`, and no uploader-following SpringBoard `1000`/Screen Changed/More reset through logger close after `03:15`. The logs are `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/rootcause-20260918/w8-scroll-probe/runtime-vo-after-modal.log`, `runtime-vo-after-modal-system.log`, `runtime-vo-before-modal-repeat.log`, and `runtime-vo-before-modal-repeat-system.log`.

This establishes a reproducible VoiceOver activation-order-dependent system AX failure chain in the tested simulator fixture: VO after modal presentation reproduces the chain, while VO before modal presentation does not, with the same binary and measured scroll offset. Both the new `AXBackBoardServer` event at `03:10:04.200` and the earlier production service event at `02:04:52.160` are connections; no disconnect evidence supports calling either a reconnect. The private caller inside the system remains unidentified, and the result is not extrapolated to physical devices or other OS versions. No TCA, network, loading, or app-issued focus command participates in this bounded fixture.

The same installed binary (`aac62b4762eb1e29f126e2bd7566a12472500bdc98a288d714e6d0134b854b58`) was then compared under modal and push presentation on the same WALK iOS 26.5 (23F77) fixture. Both presentation modes were positive. In the modal run (app PID 38104, VOT PID 38305), the initial title was logged at `10:51:31.589`; native Next reached the uploader at `10:51:51.205`, with the app offset changing from `-70` to `-48.6667`. AXBackBoardServer registered at `10:51:51.973/.974`, SpringBoard posted notification `1000` at `10:51:51.980`, VOT received Screen Changed at `10:51:51.981`, VOT logged Will set element for More at `10:51:52.784` and logged Setting element at `10:51:52.789`. In the push run (app PID 38629, VOT PID 38780), the initial title was logged at `10:53:13.535`; native Next reached the uploader at `10:53:32.903`, with the app offset changing from `-116` to `-94.6667`. AXBackBoardServer registered at `10:53:33.675`, SpringBoard posted notification `1000` at `10:53:33.681`, VOT received Screen Changed at `10:53:33.682`, VOT logged Will set element for Back at `10:53:34.474` and logged Setting element at `10:53:34.479`.

After each native Next, the operator read the system log directly and did not call the simulator UI reader, so a subsequent AX-tree query is not required to produce the observed chain. The logs do not exclude the external-keyboard input itself as a trigger. This same-binary modal/push A/B narrows the hypothesis: modal presentation is not necessary, and the result does not require app-owned data. It does not identify the upstream system caller, establish a production fix, or constitute owner acceptance. Raw provenance is retained at `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/rootcause-20260918/w8-scroll-probe/`: `root-modal-comparison-app.log` (SHA-256 `3855ece263d74d4eb2812e537bc1f6eae85e51fba17790d7e181973d8005ec48`), `root-modal-comparison-system.log` (`82f03eef651ebabf51ef29f8c0706a6a6594888ed4f85d7213710dbae734c5b0`), `root-push-comparison-app.log` (`a93606266888e65e02861013437f50a24a6f4fb55265cb2d83f11edea0cb42ab`), and `root-push-comparison-system.log` (`b3324a402dbec92d95b41b94f57a5ef64c0b7874130fb70c4115b7a3c0121b42`).

The VO-before-push control was subsequently negative over the bounded `10:55:20.224`--`10:55:37` observation window, with the limitation that VoiceOver was warm: app PID 39258 used the same binary and push arguments, while VOT PID 38780 was the already-running process from the positive push run and had an existing AXBackBoardServer connection. The title was logged at `10:55:03.819`, native Next reached the uploader at `10:55:20.224`, and the offset changed from `-116` to `-94.6667`; through `10:55:37` there was no new uploader-following SpringBoard `1000`, Screen Changed, or Back reset. Normal launch/push Screen Changed events at `10:54:47` and `10:55:03` are excluded from this result. This warm negative is a control against a newly established VOT process; the same-binary modal/push A/B above, rather than this warm control, is the evidence that modal is unnecessary. It is not equivalent to a cold VO-before-push run. Raw provenance is `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/rootcause-20260918/w8-scroll-probe/root-vo-before-push-app.log` (SHA-256 `eee1ed445da9f2decdedebe4be884b9cc5e8dc26725d1ad06b0b1ac165d1d`) and `root-vo-before-push-system.log` (`d31e692b58d9fc8044c19804d4a773ebc0f0f6d9c82056ab6d7add464b61fab5`); no private caller or physical-device conclusion is drawn. Probe termination, VoiceOver readback `0`, logger/console shutdown, and restoration of the original app panel were completed during cleanup.

### W8 code-side boundary audit

The Detail implementation has no app-owned scroll-to-visible feedback state. The presentation hierarchy is TabView, then an app-level sheet, then NavigationStack, then Detail's plain ScrollView. `DetailView.content` uses that plain `ScrollView` at `AppPackage/Sources/DetailFeature/DetailView.swift:57`, with no `scrollPosition`, `scrolledID`, offset preference, geometry callback, or scroll observer. The header is inserted as ordinary content at lines 64--96. `HeaderSection` has no scroll or navigation-bar state; its title/uploader/action layout is static apart from Dynamic Type branching at lines 417--430. The uploader is a regular `Button` at lines 391--396, while the read action's only focus binding is the explicit `.accessibilityFocused` at lines 229--240.

The Detail view's state-driven changes are unrelated to scroll position: three value animations and two launch-automation `onChange` handlers are at lines 35--46, and the navigation toolbar is installed once at line 49. The toolbar menu's only predicates are loaded/loading state and login/download data (`DetailView+Navigation.swift:11--36`). There is no `minimalTitleHeight`, `scrolledID`, title offset, toolbar opacity, or navigation-bar mutation in the Detail feature or shared modifiers. Therefore the app source does not support a feedback loop in which scrolling from title to uploader changes navigation-bar/status-bar presentation or the AX tree. The observed app notification ordering `1044` (scroll), `1001` (navigation-bar contents), `1069` (end deceleration), then SpringBoard `1000` remains a system/runtime chain whose initiating caller is not identified by this code audit. This audit does not establish modal or push presentation as a necessary condition; the same-binary modal/push comparison above is positive in both modes, while the VO-before-push control is a warm negative control.

The warm run (PID 64610) began at `01:44:16.169` uploader and reached the manual dismiss at approximately `01:45:30` without a reset. It must not be conflated with the cold run.

The bounded standalone modal probe provides a layout differential. In the long-title modal (PID 3126), the first More was at `02:51:57.865`, title focus at `02:52:15.568`, and uploader focus at `02:52:48.945` with uploader y `243.333`; there was no offset change or More reset after more than 100 seconds. In the single-title modal (PID 5374), uploader focus was at `02:59:00.866` with uploader y `193.333`, and the measured offset changed from `-70` to `-48.6667`; as of the recorded check there was still no ScreenChanged/More reset. The only source difference between these two valid modal runs was the title literal; the single-title artifact manifest records source/binary prefixes `6115e829...`/`aac62b...`. The logs are `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/rootcause-20260918/w8-scroll-probe/runtime-root-modal-valid.log`, `runtime-root-system-valid.log`, `runtime-root-single-modal.log`, and `runtime-root-single-system.log`. The later same-binary modal/push A/B shows that the presentation mode is not the distinguishing condition; scroll/geometry change alone remains insufficient to identify the production reset chain.

## VO-3 and W-13 investigation state

The failure is localized to native icon-only toolbar focus binding in the controlled probe; the full framework mechanism is not identified. The findings are recorded in `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/rootcause-20260918/focus-probe/v2-runtime-findings.md` and `v3-runtime-findings.md`. V0/V1 text-toolbar probes issued a programmatic focus request and observed the actual VoiceOver target asynchronously after the setter (about one second), with sheet restoration. V1S was subject to a simultaneous runner limitation and is not independent primary evidence. This section covers the remaining toolbar targets; the older Read and Downloads targets were separately repaired and are not reopened here.

The V2 icon-only outer Button/Menu binding reproduced the failure even after the native controls were present on a stable screen and an additional setter was applied: toolbar setters caused layout changes, but no focus `onChange`; the body control succeeded. V3 moved the binding to the label and still failed under the same stable-screen/manual-setter condition. Native next navigation reached the button, but the SwiftUI binding did not receive `onChange`. Therefore “request too early” alone is insufficient. Clean production observations at `02:37:10.699` (More) and `02:39:00.933` (Post Comment) identified `_UIButtonBarButton` native elements; the LLDB observations are recorded in the root tool transcript, not presented as a standalone raw file. This establishes a reproducible native toolbar focus-binding bridge breakpoint, while the Apple-private resolution mechanism remains unknown and production remains unmodified.

The native keyboard activation `Ctrl-Option-Space` was resolved but was a no-op in production and in the simple Button probe; taps were used to open and dismiss. The stable-screen probes show the native toolbar target already exists when the setter is applied and still fails to produce binding `onChange`, which rules out a dismissal callback being simply too early. The remaining Apple-private binding-resolution path is unknown.

## W-35 and standing decisions

The bounded results are in `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/rootcause-20260918/focus-default-probe/w35-final-bounded-analysis.md` and its raw logs. The noDefault cases are controls whose expected result is the Toolbar, so their Toolbar selection is not a failure. In the default cases, the expected initial Body was not reached; the shared controlled binary SHA-256 is `48397ef7d0309203d0890eebc4c6d459cd15a63cbacf271e4ce3c4dee946997f`, with initial Setting-toolbar observations PID 98436 at `02:43:07.875`, PID 98648 at `02:43:41.588`, PID 98786 at `02:44:34.426`, and PID 99044 at `02:45:26.615`. The later sheet-default result changed the binding to Body, but actual VoiceOver focus remained Toolbar; it is not evidence of a successful Body focus transition.

The two plain VStack controls also selected the sentinel: plain-default did not reach Body after more than 30 seconds. The plain comparison binary includes the intermediate SHA-256 `ae973b4ff6f29dbda8d7a7994bb0e83b5605ea4bdbadfb4f44ad40850054df10`. The direct bare-VStack control used a separate binary SHA-256 `ed16317d2114018a1b5a66f2f2c5afb3af5737cc2e56e634bdc270b390243802`, deployment target 26.0; it selected the sentinel at `02:54:55.194`, with no Body after more than 45 seconds, and VO off/on at `02:55:53.910` still selected the sentinel. Thus the bare direct positive control also failed. The evidence cannot specifically attribute W-35 to NavigationStack, sheet presentation, asynchronous timing, or an Apple bug; W-35 remains unresolved, with the binary boundary preserved.

The VO-only direct variant further bounds W-35. On GATE, PID 12581 with VOT PID 12526, binary SHA-256 `a4d7735ce03a9e4ee6323387958711496858e2c01da53bc5f6ec8c699c45a5b1` and source prefix `de492...`, the only change was `@AccessibilityFocusState(for: .voiceOver)`. The initial sentinel was selected at `03:18:57.239`; after approximately 46 seconds Body was still not selected. At `03:19:43.138`, native VoiceOver Next reached Body, and the app binding briefly reported `bodyButton` before returning to nil in the same second. This proves Body can be reached and the binding can receive a transient event, but it does not prove sustained synchronous success or repair initial default focus. The tested API is documented by Apple's [`AccessibilityFocusState`](https://developer.apple.com/documentation/swiftui/accessibilityfocusstate) reference, including iOS 26 availability and container usage. Logs: `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/rootcause-20260918/focus-default-probe/root-controlled-voiceover-only.log` and `vot-root-voiceover-only.log`. W-35 still has no complete framework root cause or acceptance decision.

The following standing decisions remain unchanged:

- #39: owner decision is Apple-bug handling; do not fix locally.
- VO-3 and the W-13 Comments slice: owner decision (2026-09-20) is Apple-bug handling; do not fix locally; no Feedback report.
- W31: blank button capsule only.
- W34: mebibytes decision accepted.

## Root-cause round (2026-09-19)

All runs below used the WALK simulator (iPhone 17, iOS 26.5, 23F77) with real VoiceOver, the `vot` debug log as the focus oracle (`Will set element`, `First element in app focus`, `Received note`), hermetic stub-network launches, and pass-through taps. Evidence is under `$HOME/Library/Caches/ehpanda-phase16/round3/focus-rootcause-20260919/`; the wide VoiceOver log is `e2-vo-after-wide.log`.

### VO-3 and W-13 Comments: cause, evaluated workaround, owner ruling

**Platform default.** Apple Contacts was used as the native calibration: Add, the New Contact sheet, then closing it lands VoiceOver on the first element of the screen underneath, not on Add (`e3-contacts-01..03*.png`). Returning focus to the control that opened a sheet is therefore app-level behavior on iOS 26.5, not something the system does and the app breaks.

**Cause.** The app's approved designs (set an `AccessibilityFocusState` from the sheet's `onDismiss`) were correct and failed for one reason: SwiftUI bridges a toolbar `Button` or `Menu` whose label is a `Label` to a native `UIBarButtonItem` (accessibility element class `_UIButtonBarButton`), and a bridged item drops an `accessibilityFocused` binding in both directions. The control can neither be focused programmatically nor report focus. This is the mechanism behind the earlier "native icon-only toolbar focus binding breakpoint".

The standalone probe (`toolbar-probe/`, sources `FocusProbeApp-T1..T4.swift.txt` plus the current T5 file, logs `runtime-t1..t5.log`) isolates the discriminator:

| Toolbar control form | Element | Binding |
|---|---|---|
| `Label` label, `.labelStyle(.iconOnly)` (the production form) | `_UIButtonBarButton` | dropped |
| `Label` label plus `.accessibilityLabel` on the control | `_UIButtonBarButton` | dropped |
| `Label` label under a custom `LabelStyle` that renders the icon only (T5) | bridged | dropped |
| Custom `ButtonStyle` | SwiftUI-hosted | works, but the accessibility frame shrinks to the glyph (26.7 x 27.3); rejected |
| `Image` label | `SwiftUI.AccessibilityNode` | works, native-size frame |

So the label's type decides: any `Label` is bridged, an `Image` stays hosted. In the full menu, item, sheet, dismiss flow the hosted menu button is VoiceOver's first and only focus decision after dismissal.

A hosted item loses what the `Label` supplied for free. The accessibility label is restored with `.accessibilityLabel`. The Large Content Viewer title is restored with `.accessibilityShowsLargeContentViewer { Label(…) }`, which has to sit on the control itself: attached inside the label it shows the glyph without its title (`toolbar-probe/t5-lcv-compare.png`; correct form in `t3-lcv-compare.png`).

**Evaluated workaround (not adopted).** A build that swapped the `Label` for an `Image` on the More menu and on Post Comment, re-added the accessibility label and the Large Content Viewer title by hand, and set the binding from each sheet's `onDismiss` was measured on 2026-09-19. It behaved as intended: after the dismiss tap, VoiceOver's single focus decision was `More` from the Search root (Filters `15:02:20.519`, Quick Search `15:04:44.905`) and from the results (Filters `15:03:13.670`, Quick Search `15:03:44.219`, Date Seek `15:03:59.103`), `Post Comment` on Comments (`15:06:22.155`), and the edited comment's row for the edit origin (`15:07:41.657`, exercised with a scratch copy of the fixtures carrying one editable comment; the repository fixtures are unchanged). The six audits touching those controls, the full `FeatureTests` plan (1064 tests in 185 suites) and a warning-free build passed on that build. Transcripts and screenshots are in `fix-verify/`, logs in `fix-uitests.log`, `fix-featuretests.log` and `fix-build.log`.

It is a workaround, not a fix, and was judged as one. The defect stays in SwiftUI; the swap only steps around the bridge. It rests on an undocumented rule (which label types are bridged) that a later SDK can change silently, and no test can guard it because XCUITest cannot drive VoiceOver. It downgrades a `Label` to an `Image` and restores by hand what the `Label` supplied for free. It also moves a glyph: measured against the capsule's vertical center at 84 pt (`toolbar-probe/t4-*.png`), `square.and.pencil` sits at 83.67 bridged and 85.00 hosted (1.33 pt lower), `ellipsis.circle` at 84.17 and 83.83, and a lone item's accessibility frame becomes 30 to 31 x 36 instead of 36 x 36.

**Owner ruling (2026-09-20).** Apple-bug handling: do not fix locally, and no Feedback report. The source edits were reverted; production keeps the `Label` form, and no app-side change is carried for VO-3 or the W-13 Comments slice. After such a sheet is dismissed, VoiceOver lands on the first element of the screen underneath, which is the platform default measured in Contacts above.

**Scope of the limitation.** The same cause applies to every sheet opened from a toolbar control, not only the two recorded flows: the More menu on `SearchRootView`, `SearchView`, `WatchedView`, `FavoritesView`, `DetailSearchView`, `DetailView` and the reader, and the direct toolbar buttons on `FrontpageView`, `PopularView`, `EhSettingView`, `LoginView` and `CommentsView`. All of them stay at the platform default under the ruling. One part of the approved W-13 Comments slice does not depend on the workaround: the edit origin returns focus to a content row, where the binding works, as it does for the Read and Downloads slices. It was reverted together with the rest and is not implemented.

All measurements were taken on the simulator with pass-through taps, because VoiceOver's activate gesture does not fire there; behavior after a real double-tap activation on a physical device is unverified.

### W-35: the platform rule

On Screen Changed, VoiceOver asks the app for its first element, and UIKit answers with the first element in traversal order; the navigation bar precedes the content. The only elements UIKit exempts are loading spinners, status-bar items and table section elements (never first), so while Detail loads, with its content accessibility-hidden, `More` is the only candidate, and once it has loaded `More` still precedes the title. Detail has no navigation title, and in the app-level sheet route no leading item, so `More` is first; in the pushed route Back is first, which checklist item 1.7 accepts. An inline navigation title does not outrank a leading item either: the titled probe's first element was its leading button (`14:54:18.870`).

Two details of the recorded behavior are now explained. The second `More` decision after load came from the `.disabled` flip rebuilding the bridged bar button (focus went to null) plus the app's load-time Screen Changed; on the unadopted workaround build, whose menu was SwiftUI-hosted, the two decisions remained (`15:07:03.580`, `15:07:04.491`). When VoiceOver is switched on over an already-loaded Detail, the first element is the title: that path does not go through a Screen Changed first-element query.

There is no synchronous public hook to change the first element: `accessibilityDefaultFocus` stays non-functional on 26.5 (previous probes), and the private hooks are not available to an app. Programmatic title focus works but lands 0.8 to 0.9 s late, after `More` has been selected, through VoiceOver's delayed update pass (the withdrawn probe above). W-35 therefore needs an owner decision among: accept the platform convention (first navigation-bar element, as on the pushed route); adopt the app's existing "focus newly loaded content" pattern for the Detail title and accept that `More` is selected first; or give the sheet route a navigation title or leading item so the bar's first element is something other than `More`, which is a visible design change.

### W-8: corrected characterization

The producer boundary stands: SpringBoard posts the Screen Changed (`1000`), and VoiceOver then selects the app's first element. The chain is: a VoiceOver-keyboard-driven scroll makes the app post Layout Changed; VoiceOver's delayed layout-change handler (about 0.77 s) queries SpringBoard (lock screen, notification center, foreground processes and scenes); SpringBoard answers with `1000`.

The activation-order conclusion above is superseded. The reset fires once per app activation, at a nondeterministic time. In app PID 81511 SpringBoard's deferred `1000` landed inside the presentation flurry (`14:30:33.334`), harmlessly, and the later uploader walk did not reset. In PID 81181, with VoiceOver already on before the app launched, it landed mid-walk (`14:29:43.613`); likewise in the fresh-VoiceOver run (`14:26:36.802`). After it has fired, further VoiceOver scrolls on the same screen do not reset. The earlier A/B/A samples were single samples of this timing, which also explains "2 of 4 launches".

Refuted this round: a one-time lazy `AXBackBoardServer` connection by VoiceOver (a reset occurs without a new registration); an app-independent system behavior (stock Settings shows no reset, `e1-settings-system.log`, although the no-app-logic SwiftUI fixture above does); a navigation-bar scroll-edge transition (touch scrolls post the identical `1044`, `1001`, `1069` sequence and never draw a SpringBoard `1000`). The app's notifications around the reset are ordinary, and the only focus-retention hook UIKit consults is private, so no app-side lever exists. W-8 is a system behavior on the tested simulator runtime; SpringBoard's internal trigger remains unidentified, and nothing is extrapolated to physical devices. For walkthrough evidence, the mitigation is procedural: wait for SpringBoard's deferred `1000` after a launch before starting a walk.

## Review boundary

This record preserves unresolved hypotheses and pending human judgements for the remaining items. As of 2026-09-20 it claims a confirmed cause for VO-3 and the W-13 Comments slice, measured on the simulator only, and records the owner ruling that it is handled as an Apple bug with no local fix. It does not claim a decision on W-35, an identified SpringBoard trigger for W-8, or that Phase 16 is complete.

## Owner disposition (2026-09-22T02:56:39Z)

The owner approved the focus issues with the reply “approve focus issues.” W-8 and W-35 are accepted with the behavior and limitations recorded above; W-35 retains the platform-default initial focus. VO-3 and W-13 Comments keep their existing Apple-bug disposition with no workaround adopted. This approval does not establish a new root cause or new runtime measurement. W-38 remains open under the separate VoiceOver-only index-update request in `16-SWEEP.md`; Phase 16 and A11Y-02 are not complete.
