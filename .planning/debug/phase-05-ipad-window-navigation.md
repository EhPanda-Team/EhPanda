---
status: diagnosed
trigger: "G-05-4: iPad window chrome/background problems, unsupported multiple-window capability, and iPhone detail navigation changing from push to modal presentation."
created: 2026-07-13T17:00:00+09:00
updated: 2026-07-13T17:27:00+09:00
---

## Current Focus

hypothesis: Confirmed: G-05-4 combines four independent causes—an overlay that ignores window-control exclusion geometry, an inherited window backdrop that matches Home's card fill, a stale multi-scene declaration backed by one shared app store, and an observed iPhone presentation that contradicts Phase 5's explicit non-pad push contract.
test: Source inspection, git-history differential, and the existing phone/pad DownloadsReducer routing test all agree with this diagnosis.
expecting: Not applicable; root causes are confirmed.
next_action: Return the diagnose-only root-cause report; do not apply fixes.

## Symptoms

expected: iPad windows keep custom toolbars clear of window controls and use visually distinct backgrounds; the app does not advertise unsupported multi-window behavior; opening detail pages on iPhone preserves navigation-push behavior unless an intentional change is documented.
actual: Custom upper toolbar overlaps iPad window controls; sheet-style window backgrounds hide Home card backgrounds; the app advertises multi-window support despite shared state; iPhone detail pages now open as modal sheets instead of navigation pushes.
errors: None reported.
reproduction: Test 4 in Phase 5 UAT.
started: Discovered during Phase 5 UAT.

## Eliminated

- hypothesis: Phase 5 intentionally changed iPhone gallery navigation to modal presentation.
  evidence: Plan 05-01, commit 5901ee63, GalleryNavigation comments, and the Phase 5 summary all explicitly require iPad modal/non-iPad push parity.
  timestamp: 2026-07-13T17:17:00+09:00
- hypothesis: The Phase 5 DeviceType refactor inverted or otherwise changed the gallery routing conditional.
  evidence: The 5901ee63 diff is a direct isPad() to deviceType() == .pad substitution, and the targeted DownloadsReducerActionTests pass for both the phone push and pad delegate paths.
  timestamp: 2026-07-13T17:24:00+09:00

## Evidence

- timestamp: 2026-07-13T17:05:00+09:00
  checked: Phase 5 UAT gap G-05-4.
  found: One UAT test groups four concrete behaviors: toolbar/window-control overlap, indistinct sheet-style backgrounds, unsupported multi-window advertisement, and iPhone detail modal presentation.
  implication: Each behavior needs an independent implementation/history trace; a single root cause should not be assumed.
- timestamp: 2026-07-13T17:05:30+09:00
  checked: Phase 5 state decisions.
  found: Recorded Phase 5 decisions cover adaptive dimensions, device identity, geometry, reader gestures, and key-window lookup, but contain no decision intentionally changing iPhone detail navigation from push to modal.
  implication: The modal behavior lacks documented Phase 5 intent and is a regression candidate pending git-history confirmation.
- timestamp: 2026-07-13T17:06:00+09:00
  checked: Debug knowledge base and root SwiftLint configuration.
  found: No debug knowledge base exists; lint rules are unrelated to the reported runtime layout/presentation symptoms.
  implication: Investigation proceeds from source and commit history without a known-pattern shortcut.
- timestamp: 2026-07-13T17:12:00+09:00
  checked: App scene manifest, app shell, root view, and AppDelegate store ownership.
  found: App/Info.plist advertises UIApplicationSupportsMultipleScenes=true, while every WindowGroup renders RootView(appDelegate:) and RootView obtains the single StoreOf<AppReducer> owned by the one UIApplicationDelegate instance.
  implication: Multiple scenes are advertised without per-scene state; every window necessarily shares navigation, tab, lock, and feature state.
- timestamp: 2026-07-13T17:14:00+09:00
  checked: Reader ControlPanel upper toolbar layout and git history.
  found: UpperPanel is a full-width HStack padded only 20 points horizontally. Its only top compensation is 8 points for non-pad landscape, and its comment explicitly assumes iPad is already safely inset. It never consumes safe-area/window-control geometry. The compensation predates the Phase 5 container-size refactor; Phase 5 preserved that assumption.
  implication: In an iPad freeform window with macOS-style leading window controls, the custom overlay has no exclusion region and can overlap the controls.
- timestamp: 2026-07-13T17:15:00+09:00
  checked: Root/Home background composition.
  found: EhPandaApp, RootView, TabBarView, and HomeView set no explicit window/root content background. Home's Other cards use Color(.systemGray6), so they rely on the inherited backdrop being visually different.
  implication: When the platform's window surface uses a sheet/grouped gray appearance, the cards and inherited root background converge and card boundaries disappear.
- timestamp: 2026-07-13T17:17:00+09:00
  checked: GalleryNavigation source, Phase 5 Plan 05-01, summary, commit 5901ee63, and earlier commits 5b204baa/b39bf62b.
  found: The routing contract before and during Phase 5 is explicitly "iPad presents; iPhone pushes." Phase 5 only replaced isPad() with DeviceType.current == .pad, and its plan, commit message, comments, and summary all require unchanged behavior. The app-level DetailView sheet is reached only through the present delegate.
  implication: Modal iPhone gallery taps were not an intentional Phase 5 behavior change. They are a regression report (or a path-specific observation outside ordinary gallery taps), not a documented product decision.
- timestamp: 2026-07-13T17:24:00+09:00
  checked: Targeted DownloadsFeatureTests/DownloadsReducerActionTests on an iPhone Air iOS 26.5 simulator.
  found: xcodebuild exited 0. The suite's non-pad fixture receives pushGalleryDetail and appends a navigation path, while its pad fixture receives the modal-present delegate.
  implication: The checked-in standard gallery-tap routing still honors the intended iPhone push contract; the reported iPhone sheet is not an intended Phase 5 change and is not reproduced by the covered reducer path.
- timestamp: 2026-07-13T17:25:00+09:00
  checked: Git provenance for UIApplicationSupportsMultipleScenes and Phase 5 window-related changes.
  found: The multi-scene true flag dates to the initial repository commit, not Phase 5. Phase 5 did not add per-scene stores or window-specific root styling. The reader toolbar's iPad-safe-area assumption also predates its Phase 5 container-size conversion.
  implication: UAT exposed longstanding window-capability and window-chrome gaps; Phase 5 did not resolve them and explicitly preserved the navigation split.

## Resolution

root_cause: "Four independent causes: (1) ReadingFeature/Support/ControlPanel.swift positions its full-width custom UpperPanel with fixed horizontal padding and a top-padding branch that excludes iPad, so it never reserves the macOS-style iPad window-control region. (2) The app/root/Home hierarchy supplies no explicit distinct window content background while Home's Other cards use systemGray6, allowing the platform sheet/grouped window backdrop to match and visually erase those cards. (3) App/Info.plist advertises UIApplicationSupportsMultipleScenes=true, but every WindowGroup scene receives RootView(appDelegate:) and therefore the single AppDelegate.store, so separate windows share all app state. (4) Phase 5 did not intentionally make iPhone details modal: Plan 05-01 and commit 5901ee63 explicitly preserve iPad modal/non-pad push routing, and the phone/pad reducer test passes. Thus the reported iPhone sheet is a regression/path-specific mismatch with the contract, not a documented Phase 5 design change; standard gallery taps in the checked-in reducer still push on phone."
fix: Not applied; diagnose-only mode.
verification: Root-cause evidence verified by complete source reads, line-level git history/diffs, and a passing targeted phone/pad routing test.
files_changed: []
