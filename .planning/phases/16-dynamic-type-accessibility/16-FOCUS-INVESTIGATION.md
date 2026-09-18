# Phase 16 Focus Investigation

## Scope and status

This document records the current evidence for VO-3, W-13, W-8, W-35, and the related withdrawn or pending probes. It is an investigation record, not an acceptance record. Phase 16 is not complete, and there is no blanket approval.

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

This establishes a reproducible VoiceOver activation-order-dependent system AX failure chain in the tested simulator fixture: VO after modal presentation reproduces the chain, while VO before modal presentation does not, with the same binary and measured scroll offset. Both the new `AXBackBoardServer` event at `03:10:04.200` and the earlier production service event at `02:04:52.160` are connections; no disconnect evidence supports calling either a reconnect. The private caller inside the system remains unidentified, and the result is not extrapolated to physical devices or other OS versions. The tab-modal variant is built but has not been runtime tested. No TCA, network, loading, or app-issued focus command participates in this bounded fixture.

### W8 code-side boundary audit

The Detail implementation has no app-owned scroll-to-visible feedback state. The presentation hierarchy is TabView, then an app-level sheet, then NavigationStack, then Detail's plain ScrollView. `DetailView.content` uses that plain `ScrollView` at `AppPackage/Sources/DetailFeature/DetailView.swift:57`, with no `scrollPosition`, `scrolledID`, offset preference, geometry callback, or scroll observer. The header is inserted as ordinary content at lines 64--96. `HeaderSection` has no scroll or navigation-bar state; its title/uploader/action layout is static apart from Dynamic Type branching at lines 417--430. The uploader is a regular `Button` at lines 391--396, while the read action's only focus binding is the explicit `.accessibilityFocused` at lines 229--240.

The Detail view's state-driven changes are unrelated to scroll position: three value animations and two launch-automation `onChange` handlers are at lines 35--46, and the navigation toolbar is installed once at line 49. The toolbar menu's only predicates are loaded/loading state and login/download data (`DetailView+Navigation.swift:11--36`). There is no `minimalTitleHeight`, `scrolledID`, title offset, toolbar opacity, or navigation-bar mutation in the Detail feature or shared modifiers. Therefore the app source does not support a feedback loop in which scrolling from title to uploader changes navigation-bar/status-bar presentation or the AX tree. The observed app notification ordering `1044` (scroll), `1001` (navigation-bar contents), `1069` (end deceleration), then SpringBoard `1000` remains a system/runtime chain whose initiating caller is not identified by this code audit. This audit does not establish modal or push presentation as a necessary condition; a push comparison remains outstanding.

The warm run (PID 64610) began at `01:44:16.169` uploader and reached the manual dismiss at approximately `01:45:30` without a reset. It must not be conflated with the cold run.

The bounded standalone modal probe provides a layout differential. In the long-title modal (PID 3126), the first More was at `02:51:57.865`, title focus at `02:52:15.568`, and uploader focus at `02:52:48.945` with uploader y `243.333`; there was no offset change or More reset after more than 100 seconds. In the single-title modal (PID 5374), uploader focus was at `02:59:00.866` with uploader y `193.333`, and the measured offset changed from `-70` to `-48.6667`; as of the recorded check there was still no ScreenChanged/More reset. The only source difference between these two valid modal runs was the title literal; the single-title artifact manifest records source/binary prefixes `6115e829...`/`aac62b...`. The logs are `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/rootcause-20260918/w8-scroll-probe/runtime-root-modal-valid.log`, `runtime-root-system-valid.log`, `runtime-root-single-modal.log`, and `runtime-root-single-system.log`. This shows that scroll/geometry change alone is insufficient to reproduce the production reset chain; a push-presentation comparison has not yet been run.

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
- W31: blank button capsule only.
- W34: mebibytes decision accepted.

## Review boundary

This record intentionally preserves unresolved hypotheses and pending human judgements for the remaining items. It does not claim a confirmed VO-3/W-13 root cause or declare Phase 16 complete.
