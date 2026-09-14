# Phase 16: Agent-driven walkthrough research (input to revised 16-25 / 16-26)

**Researched:** 2026-09-15
**Question:** For each check the round-2 walkthrough needs, how can an agent do it reliably without a
human, and what is left that truly needs a human ear?
**Owner scope (2026-09-15, verbatim):** "2" (16-25 walks only the main flows, no exhaustive per-cell
table; 16-26 drops the Nutrition Label document and keeps the re-sweep and the closing gates), and
"而且全都先你自己做 / 我只會去處理必須需要我聽的部分 / 包括 voiceover 的焦點測試也是你可以處理的".
**Confidence:** HIGH for the simulator VoiceOver method and the display-setting commands (probed, evidence
below); MEDIUM for simulator-to-device parity of VoiceOver focus behaviour (not calibrated on a device);
LOW for the physical-device and Voice Control speech options (not probed).

Evidence root for everything cited: `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough-research/`
(abbreviated `WR/` below). Nothing from it is committed. The probe scripts are archived in `WR/scripts/`.

**Build probed.** `$HOME/Library/Caches/ehpanda-phase16/round2/audit/DerivedData/Build/Products/Debug-iphonesimulator/EhPanda.app`
(bundle id `app.ehpanda.personal`, read with `plutil`). Its `EhPanda.debug.dylib` is dated 2026-09-13 09:32:16,
11 s before commit `c91c2b31`, and `git diff --stat c91c2b31..HEAD -- AppPackage/Sources App ShareExtension`
prints nothing, so its app sources very likely equal HEAD `ed1e25b4` [VERIFIED: stat + git diff this session].
Whether that dylib already contained `c91c2b31`'s one-line change is not provable from the file
[ASSUMED]. Every behavioural observation below should be re-checked once on a fresh HEAD build in 16-25.

**Probe device.** A throwaway iPhone 17 simulator on iOS 26.5 (`ehpanda-wt-research`, created, used,
shut down and deleted by this research). No listed or booted simulator was touched, and the physical
iPhone was not used. At about 02:02 every booted simulator on the machine, the throwaway one included,
was shut down by a process outside this research. The throwaway was rebooted and the probes resumed.
Long VoiceOver sessions should expect this and be resumable.

---

## Summary

The main finding is that **real VoiceOver runs inside the iOS 26.5 Simulator.** The runtime ships the
VoiceOver daemon (`/System/Library/CoreServices/VoiceOverTouch.app/vot`). Setting one preference and
starting its launchd job turns it on. At debug log level `vot` logs every focus change, every
screen-change focus decision and **the exact string it speaks**. An agent can drive it with VoiceOver
keyboard chords (Ctrl+Option+arrows, rotor chords) sent through `sim-use ios key-combo`. So reading order,
focus after push, pop and sheet dismiss, rotor custom actions, adjustable controls and announcements can
all be observed by an agent. This is the actual screen reader, not a proxy
[VERIFIED: probes, `WR/walk-*.txt`, `WR/focus-*.txt`, `WR/rotor-comment-cell.txt`, `WR/vot-stream*.log`].

Accessibility trees (`sim-use ui`, XCUITest/`agent-device snapshot`) are **not** trustworthy for VoiceOver
order. On Home, `sim-use ui` lists Frontpage, Toplists and the tab bar right after the three hero cards.
The real VoiceOver walk never gets past the hero carousel: it steps through the looping card buffer
forever and is periodically thrown back to the "Home" heading. The tree shows none of that
[VERIFIED: `WR/simuse-ui-home.txt` vs `WR/walk-home-02.txt`, `WR/walk-home-03.txt`].

Six of the eight display settings can be set from the command line on a running simulator, and the
running app picks each one up without a relaunch (same pid). The six are Dark, Increase Contrast,
content size, Bold Text, Button Shapes and Reduce Transparency, with screenshot or video evidence for
each. Reduce Motion is also picked up live, confirmed from video frames of the toast dismissal: a slide
without the setting, an in-place fade with it. Grayscale is written and notified but produces no change
in simulator screenshots, so it has to be checked with a software grayscale conversion. Voice Control
starts on the simulator, but its en-US recognition asset fails with "Asset is incompatible", so spoken
commands cannot be tested there.

**What still needs a human ear is small:** how the synthesized speech *sounds* (pronunciation and
intelligibility of titles, uploader names, numbers and mixed CJK text, ideally with the device's own
voices). Two short device-only checks that are not about listening remain optional: a VoiceOver
double-tap activation spot check and a calibration of simulator focus against the device. The login
question is separate (§ 7).

**Primary recommendation:** rewrite 16-25 around the in-simulator VoiceOver method, run by the agent
on main flows with transcripts as evidence, plus one short owner checkpoint for listening. Rewrite 16-26
as D-25 re-sweep plus closing gates plus sign-off, re-pointed away from simulators that no longer exist.

### Summary table

| Check | Agent method | Verified? (evidence) | Reliability / limits | Residual human need |
|---|---|---|---|---|
| 1.1 reachability / 1.5 decorative hidden | VoiceOver keyboard "next item" walk, parse `Will set element:` | Yes: Home, Setting, Search, Detail, Comments, Reader panel (`WR/walk-home-0{1,2,3}.txt`, `WR/walk-detail-01.txt`, `WR/walk-reader-panel.txt`) | Real VoiceOver traversal. Found two candidate defects the trees hide (§ Candidate findings). ~2.5 s per element. | None |
| 1.2 / 1.3 / 1.4 labels, traits, state | Same walk, parse `Post-processed string:` (label, value, traits, hint as spoken text) | Yes (e.g. `'Add to favorites'` `'dimmed'` `'Button'` `'Pop up button'`) | Exact spoken text. Earlier speech can spill into the next step's window, so key on the focus line. | Pronunciation only (§ 6) |
| 1.6 reading order | Same walk (the order of `Will set element:` lines) | Yes | Authoritative for the simulator. Device parity [ASSUMED], same `vot` binary. | Optional device calibration |
| 1.7 focus after push | Pass-through tap, then read `First element in app focus` / `Will set element` | Yes: Setting→General (`WR/focus-push-general.txt`, `WR/focus-push-pop-trials.txt`), Detail→Comments (`WR/focus-push-comments.txt`), reader panel (`WR/focus-reader-panel.txt`) | Deterministic across 3 trials once VoiceOver's pre-push focus is fixed. The result depends on where VoiceOver focus was before the tap, so set it with the keyboard first. | Optional device calibration |
| 1.8 focus after dismiss / pop | Same | Yes: Filters sheet dismiss → "Search" title (`WR/focus-sheet-dismiss-filters.txt`); General pop → "Account" row (`WR/focus-push-pop-trials.txt`) | Same as 1.7 | Owner decides what "sensible" means (policy, not listening) |
| 1.9 adjustable | VoiceOver focus on slider, then Ctrl+Option+Up/Down | Yes: reader page slider `'16 of 156'`, `'31 of 156'`, `'15 of 156'` (`WR/adjust-reader-slider.txt`) | Exact announced values | None |
| 1.10 announcements | Trigger the event, grep `VoiceOver Received note: Announcement` plus the spoken string; interruption from `Completed utterance` timing | Yes: toast `'Error,… This link wasn't recognized as an Eh Panda gallery link.'` (`WR/announce-toast.txt`) | Text is exact. Whether it was cut off is inferred from utterance timing (heuristic). | Optional: confirm truncation by ear |
| 1.11 complete a flow | Walk plus pass-through taps | Partly: VoiceOver's own activation (Ctrl+Option+Space) resolves "Activate" but does not fire in the simulator (§ 1) | Activation path differs from a user's double-tap | Optional device spot check of double-tap activation |
| OQ2 rotor actions (tag chip, comment cell, download row) | Ctrl+Option+Cmd+Right to cycle rotors, then Ctrl+Option+Cmd+Down through Actions; cross-check `sim-use ui --point x,y --json` → `raw.custom_actions` | Yes on comment cell: rotor lists `'Open link to twitter.com'`, `'Open link to mks.booth.pm'`, `'Open link to'`+`'www dot pixiv dot net'`; `custom_actions` gives the same three (`WR/rotor-comment-cell.txt`, `WR/simuse-point-comment.json`). Tag chip logged out: no Actions rotor and `custom_actions: []`, as the source predicts (menu is empty when logged out with no translation). Download row: not reached (no download in fixtures). | `custom_actions` is a faithful cheap proxy for the Actions rotor | None, if a logged-in session and a download row are available (§ 7) |
| 2.1–2.7 Voice Control | Proxy: accessibility label (or input labels) of every actionable element from `sim-use ui --json`, compared with visible English text. Real Voice Control recognition is blocked on the simulator. | Blocker verified: `Error Domain=kRXAssetDownloadErrorDomain Code=101 "Asset is incompatible"` for en-US (`WR/vc-asset-error.txt`). "Show names" overlay not observed (`WR/21-vc-names.png`). | Label proxy follows the skill's resolution order (visible text → input labels → label). D-30 already makes it structural. | Speaking commands, if the owner wants more than the proxy (not listening) |
| Dark / Increase Contrast / content size | `xcrun simctl ui <UDID> appearance\|increase_contrast\|content_size …` | Yes, live, same pid (`WR/display/home-dark.png`, `home-ic-on.png`, `home-ax5.png`) | Exact | None |
| Bold Text / Button Shapes / Reduce Transparency | `defaults write com.apple.Accessibility <key>` + `notifyutil -p <name>` (`WR/scripts/ax-setting.sh`) | Yes, live, same pid (`WR/display/bold-text-on.png`, `button-shapes-crop.png`, `pair-rt.png`) | Pitfall: a view in another tab kept Bold Text rendering until the next environment change (`WR/display/pair-drift.png`) | None |
| Reduce Motion | Same script. Evidence by recording video and tracking a gated element across frames. | Yes, live: toast dismiss slides with it off, fades in place with it on (`WR/display/motion/dismiss-analysis.txt`). System push still slides either way (`push-rm-off-sheet.png`, `push-rm-on-sheet.png`). | Needs a gated site that can be triggered in the foreground | None |
| Grayscale | Software conversion of screenshots (luminance) | The setting itself: written, notified, **no change in captures** (`WR/display/home-grayscale-on.png`, diff 0.0000) | The simulator capture does not show the display filter. Software grayscale matches the check's intent (information without colour). | None |
| Login-gated flows | Depends on § 7 option | D-09 simulators confirmed absent | — | One of the § 7 options |

---

## Project constraints (from CLAUDE.md / AGENTS.md) that bind this research's recommendations

- **D-09 / credential rule:** the agent never handles, requests or types a credential. The
  `EHPANDA_AUTOMATION_IPB_*` launch seam was rejected on credential-exposure grounds; do not re-propose it.
- **D-32 evidence:** no screenshot or video enters git. This extends in spirit to VoiceOver transcripts,
  which contain real gallery titles and uploader names. Keep them in the evidence root and put written
  descriptions in the repo.
- **Generated docs:** no absolute home paths (`$HOME/…` only); never name another local project.
- **Accessibility navigation and search policy (AGENTS.md):** the temporary
  `accessibilityNavigationTitleWorkaround()` / `accessibilitySearchableWorkaround(text:prompt:)` stay scoped to
  recorded evidence. A walkthrough that finds a new title or search failure records evidence before any
  scope extension.
- **Confirmation dialog placement / sim alert hazard:** near destructive alerts, drive by frame
  coordinates only, never label aliases such as `--label "dismiss popup"`.
- **One `xcodebuild` at a time**, under the shared lock. No overlapping test runs.
- **Lint rules are never suppressed.** Walkthrough fixes use catalog keys (`accessibility_hardcoded_string`).

---

## 1. VoiceOver reading order

### Method (verified): real VoiceOver in the Simulator

```bash
U=<simulator UDID>; EV="$HOME/Library/Caches/ehpanda-phase16/round2/<run>"
# 1) capture VoiceOver's own log (debug level carries focus and spoken text)
xcrun simctl spawn "$U" log stream --style compact --level debug \
  --predicate 'process == "vot" AND subsystem == "com.apple.Accessibility"' > "$EV/vot.log" &
# 2) turn VoiceOver on (it does NOT auto-start after a simulator reboot; repeat step 2 after a boot)
xcrun simctl spawn "$U" defaults write com.apple.Accessibility VoiceOverTouchEnabled -bool true
xcrun simctl spawn "$U" launchctl start com.apple.VoiceOverTouch
# 3) step through elements: Ctrl(224)+Option(226)+Right(79) = "Move to Next Item"; Left(80) = previous
sim-use ios key-combo --modifiers 224,226 --key 79 --device "$U"
# 4) read what happened
grep -E "Will set element:|First element in app focus|Post-processed string:" "$EV/vot.log"
# 5) off
xcrun simctl spawn "$U" defaults write com.apple.Accessibility VoiceOverTouchEnabled -bool false
xcrun simctl spawn "$U" launchctl stop com.apple.VoiceOverTouch
```

The wrapper `WR/scripts/vo-walk.sh <udid> <log> <steps> [key] [wait]` prints one line per focus change
(`FOCUS <label> {{x, y}, {w, h}}`) and one per utterance (`SPOKE '<text>'`). `WR/scripts/vo-events.sh`
prints focus, screen-change and announcement events after a given log line.

Evidence that this is VoiceOver and not an inspector:
- `vot` is present in the runtime and runs as `com.apple.VoiceOverTouch` (launchctl shows a pid) [VERIFIED].
- On first enable, SpringBoard shows the system "VoiceOver Gestures" sheet with the VoiceOver cursor drawn
  on it (`WR/01-vot-started.png`). Later screenshots show the black VoiceOver cursor on the focused
  element (`WR/07-after-tap-frontpage.png`, `WR/08-after-touch-setting.png`, `WR/17-reader-panel.png`).
- Keyboard chords are resolved by VoiceOver's command resolver, for example
  `Resolved command: 'VOSCommand<…>: Built-in: Move to Next Item'`, and speech goes through the
  synthesizer: `Spoke: [en:com.apple.voice.compact.en-US.Samantha]`, with the text in `Post-processed string:`.

Chords confirmed from the runtime's `VoiceOverServices.framework/DefaultCommandProfile.plist` [VERIFIED: read
this session]: `NextRotor/KeyChord = ⌘_→`, `PreviousRotor/KeyChord = ⌘_←`, `NextRotorItem/KeyChord = ⌘_↓ | ↓`,
`PreviousRotorItem/KeyChord = ⌘_↑ | ↑`, `ReadAll/KeyChord = a`, `Escape/KeyChord` = the grave accent key, `MagicTap/KeyChord = -`.
All are pressed with the VoiceOver modifier (Ctrl+Option). HID codes: Right 79, Left 80, Down 81, Up 82,
`a` 4, grave 53, Cmd 227.

### What the method can and cannot do (probed)

| Input | Result |
|---|---|
| VoiceOver keyboard navigation (next/previous, rotor, rotor item, adjust) | Works (`WR/walk-*.txt`, `WR/rotor-comment-cell.txt`, `WR/adjust-reader-slider.txt`) |
| VoiceOver keyboard **Activate** (Ctrl+Option+Space) | Resolves `Built-in: Activate`, logs `VOTEventCommandSimpleTap`, but **nothing activates**: the General row and the SpringBoard "OK" both stayed put (`WR/focus-vo-push-general.txt`, `WR/04-after-ok.png`) |
| `sim-use tap` / `sim-use touch` (HID) | **Pass-through**: the app receives a normal tap even with VoiceOver on. VoiceOver still observes the resulting screen change and moves its focus (`WR/focus-push-general.txt`). |
| `sim-use swipe` flick | Not recognized as a VoiceOver gesture (no VoiceOver event logged) |
| `sim-use ui` while VoiceOver runs | Works, but its ~300 hit-test probes flood VoiceOver with `Update element Visuals`. Avoid it mid-walk. |

So: **navigate with pass-through taps, observe with VoiceOver, and walk order with the keyboard.**

### Tree order vs VoiceOver order (why the trees are not trustworthy)

| Source | Order model | Trust for VoiceOver order |
|---|---|---|
| `sim-use ui` outline | Quadtree hit-test probing, grouped by screen region (`[Top]`, `[Content]`, `[Bottom]`, `[Group "Tab Bar"]`) [VERIFIED: `sim-use help describe-ui`] | Low. Spatial and region-grouped; blind to traps, focus resets and `accessibilitySortPriority`. |
| XCUITest / `agent-device snapshot` | Accessibility element tree | Not probed this session (an `agent-device` runner `xcodebuild` from other work was active, and starting a second runner would break the one-`xcodebuild` rule). Being a tree snapshot it cannot show traversal dynamics such as the carousel loop below [ASSUMED]. |
| Accessibility Inspector (Xcode 26.6) | GUI navigation. No scripting dictionary (`sdef` error -192) [VERIFIED]. Automating it would mean driving its GUI through computer-use. | Superseded. The real screen reader is available, so the inspector's claimed VoiceOver-equivalent order [CITED: deque.com/blog/intro-accessibility-inspector-tool-ios-native-apps] is not needed. |

Worked contrast, Home (hermetic fixture):
- `sim-use ui` (`WR/simuse-ui-home.txt`): Home heading, Reload, three hero cards, Frontpage, Show All, eight
  grid cells, Toplists, Show All, Yesterday / Past Month, tab bar.
- VoiceOver (`WR/walk-home-02.txt`, `WR/walk-home-03.txt`): Reload → hero card → next hero card → … the
  six fixture galleries repeat indefinitely at frames `x≈381` (off-screen right, scrolled in by VoiceOver).
  About once per loop, with no key press, focus jumps back to `Home {{16, 63.67}, …}`, then Reload, then
  the carousel again. Frontpage was never reached in 28 steps.

### Screen shapes and trust

| Shape | Trust in the in-simulator VoiceOver walk | Notes |
|---|---|---|
| Plain vertical `List` / `Form` (Setting, General) | High | Order matched visual order |
| Header plus stats strip plus tag cloud (Detail) | High for order. Revealing for grouping. | The stats strip reads headers and values interleaved: `FAVORITED`, `LANGUAGE`, `591, Times`, `JA, Japanese`, `110 Ratings, 4.50, Rating`, `PAGE COUNT`, `FILE SIZE`, `156, Pages`, `314.3, MiB` (`WR/walk-detail-01.txt`) |
| Horizontal scroll rows (preview strip) | High | VoiceOver scrolls items in (`Page 4`…`Page 6` at the same frame) |
| Infinite / rebasing carousel | The walk is the only method that shows the real behaviour | See candidate finding VO-1 |
| Overlays / fade-hidden views (`visible(false)`) | The walk exposes what the tree audit hides or over-reports | See candidate finding VO-2 |
| Toolbars, menus, sheets | High for focus landing (`First element in app focus`) | Menu: focus → `Filters` item. Sheet: → `Cancel`. |
| Screens during loading | Timing-sensitive | Detail finishing its load reset focus to `More` mid-walk (`WR/walk-detail-01.txt` step 02, `SCREEN More`). Wait for load before walking. |

---

## 2. VoiceOver focus after push and after sheet dismiss

**Answer:** observable on the simulator with the method above. No DEBUG hook and no in-app code are
needed. The in-app `UIAccessibility.elementFocusedNotification` observer idea was **not prototyped**,
because VoiceOver's own log already reports every focus decision: `First element in app focus: <label>
{{frame}}` at a screen change, and `Will set element: <label> {{frame}}` for every focus move, including
moves no key press caused.

Recipe: put VoiceOver focus on the trigger (keyboard walk), pass-through tap the trigger, wait 3–4 s,
then read `vo-events.sh` from the pre-tap log line.

| Transition | VoiceOver focus before | Landed on | Evidence |
|---|---|---|---|
| Home tab → Setting tab | carousel card | `Setting` heading | `WR/08-after-touch-setting.png` + log |
| Setting → push General | `Setting` heading | `Setting` back button ("Setting", "Back button") | `WR/focus-push-general.txt` |
| Setting → push General (×3) | `General` row | `Language` (first form row) | `WR/focus-push-pop-trials.txt` |
| General → pop (×3) | after the push above | `Account` row (**not** the `General` trigger) | `WR/focus-push-pop-trials.txt` |
| Search → More menu | `More` | `Filters` menu item | log in `WR/vot-stream3.log` |
| Menu → Filters sheet | — | `Cancel` | `WR/focus-sheet-open-filters.txt` |
| Filters sheet → Cancel | `Cancel` | `Search` title (not `More`) | `WR/focus-sheet-dismiss-filters.txt` |
| Detail → push Comments | — | first comment cell | `WR/focus-push-comments.txt` |
| Detail → Read | — | page element `1`, then hint "Swipe up or down to select a custom action, then double tap to activate." | `WR/focus-reader-panel.txt` |
| Reader → show panel | — | `Close` (the `@AccessibilityFocusState` target) | `WR/focus-reader-panel.txt` |

Limits:
- The activation path differs from a user's. A user double-taps, VoiceOver activates the focused element,
  and focus stays on it until the transition. The agent taps directly while VoiceOver focus sits on the
  same element. Restoration logic depends on VoiceOver's last focused element, which is the same in both
  cases, so parity is expected [ASSUMED] but not calibrated on a device.
- Results depend on pre-transition focus (the two push rows above). Always set focus with the keyboard
  before the tap and record it.
- "Sensible" is a policy question, not a listening one. The skill's criteria: 1.7 focus moves to the first
  element (title or back button); 1.8 focus returns to the trigger. The pop → `Account` and sheet →
  `Search` results should be ruled on by the owner, not heard.

**Device path (not needed; cost recorded for completeness):** VoiceOver on the physical iPhone, input
through `agent-device`. Every XCUITest runner launch needs the owner to type the passcode (project
memory). XCUITest cannot send VoiceOver keyboard chords on iOS [ASSUMED]. Device logs are not
live-streamable without `sudo /usr/bin/log collect --device-udid …` (project memory). The owner would end
up driving anyway. Not recommended.

---

## 3. Custom actions and context menus in the rotor (OQ2)

**Method (verified):** with VoiceOver on the element, Ctrl+Option+Cmd+Right repeatedly until
`Post-processed string: 'Actions'`, then Ctrl+Option+Cmd+Down for each action name.

Comment cell (Comments view, hermetic): rotor order `Characters`, `Words`, `Lines`, `Speaking Rate`,
`Containers`, `Headings`, `Actions`. The action items are `Open link to twitter.com`,
`Open link to mks.booth.pm`, `Open link to` / `www dot pixiv dot net`, `Activate`, `Default`
(`WR/rotor-comment-cell.txt`).

**Cheap proxy (verified equivalent on that cell):** `sim-use ui --device <UDID> --point <x,y> --json` →
`data.raw.custom_actions` = `['Open link to twitter.com', 'Open link to mks.booth.pm', 'Open link to www.pixiv.net']`
(`WR/simuse-point-comment.json`).

Tag chip (Detail, hermetic, logged out): the rotor has no `Actions` entry and `custom_actions: []`
(`WR/simuse-point-tagchip.json`). This is expected from source, not a finding.
`DetailView+Subviews.swift:448-456` mirrors the menu into the rotor
(`.contextMenu { tagContextMenu(content: content, translation: translation) }` and
`.accessibilityActions { tagContextMenu(content: content, translation: translation) }`), and the builder at
`:464-479` only emits items `if let translation = translation, let description = translation.descriptionPlainText, !description.isEmpty`
or `if didLogin` [VERIFIED: DetailView+Subviews.swift:448-479, read this session]. Hermetic Detail has
neither. **OQ2 on the tag chip and the download row therefore needs a logged-in session (vote items) and
a download row.** § 7 and Open Questions cover both.

Whether iOS 26 surfaces `.contextMenu` items as rotor actions by itself was not isolated: every probed
context-menu site either mirrors its items or was empty. The rotor method can answer it on any
`.contextMenu` site without a mirror, for example the reader page context menu
(`ReadingViewComponents.swift:149`, grep only).

---

## 4. Voice Control names

- **Simulator availability:** `CommandAndControl` starts (`defaults write com.apple.Accessibility
  CommandAndControlEnabled -bool true` + `launchctl start com.apple.commandandcontrol`; a status-bar mic
  glyph appears in `WR/20-vc-start.png`), but recognition cannot work. The failing output, pasted verbatim
  (`WR/vc-asset-error.txt`):
  ```
  [com.apple.speech.SpeechRecognitionCommandAndControl:AssetDownload] Error in asset download: Error Domain=kRXAssetDownloadErrorDomain Code=101 "Asset is incompatible" UserInfo={NSLocalizedFailureReason=Asset is incompatible}
  … Error for  language en-US. Error Dictionary: { "en-US" = 1; }
  ```
  So "Tap <name>", "Show numbers" and "Show names" cannot be exercised by voice on this simulator
  [VERIFIED: falsification output above].
- **"Show names" capture:** writing `CACAlwaysShowOverlay` (a key found in the domain
  `com.apple.speech.SpeechRecognitionCommandAndControl` in the Voice Control log) to `Names` and restarting
  the service produced no overlay (`WR/21-vc-names.png`). The correct value or notification is unknown, so
  this is **no observation**, not a declared impossibility.
- **Label proxy (recommended, D-30-consistent):** Voice Control resolves an element's name from visible
  text, then `accessibilityInputLabels`, then `accessibilityLabel` [CITED: skill `references/voice-control.md`
  § How Voice Control Works]. For each actionable element in `sim-use ui --json` (roles `Button`,
  `PopUpButton`, `RadioButton`, `Link`, adjustable, text fields), the agent checks that:
  (2.1/2.3) the element exists with an actionable role; (2.4) its label equals its visible English text,
  judged from the screenshot; (2.7) icon-only controls carry an English label, e.g. `More`, `Reload`,
  `Close`, `Post Comment`, `Gallery Infos`, `Read`, `Add to favorites` (seen in `WR/simuse-ui-home.txt`,
  the Detail outline and `WR/walk-detail-01.txt`). Custom tappables without an actionable role (e.g. comment
  link runs, which are `Text` + `onTapGesture` exposed as custom actions) are invisible to "Show numbers"
  [ASSUMED]. The proxy flags them for a decision.
- **Run the proxy with the simulator in English.** The throwaway ran `en` (Voice Control's log shows
  `AppleLocale en_001`). Record the simulator language in the walkthrough header, as D-30 wants.
- **Real Voice Control, if wanted:** it needs someone speaking to a device. That is speaking, not
  listening, and outside the owner's "listening only" scope unless he opts in. Playing macOS `say` into the
  device microphone is conceivable but untested [ASSUMED].

---

## 5. Display settings from the command line

Every command below was run against the running hermetic app (pid 40609 before and after), with
screenshot or video diffs from `WR/scripts/imgdiff.py` (share of changed pixels, status bar excluded).

| Setting | Set | Restore | Live pickup evidence |
|---|---|---|---|
| Dark | `xcrun simctl ui <UDID> appearance dark` | `… appearance <recorded>` | 96.5 % pixels changed (`WR/display/home-dark.png`) |
| Increase Contrast | `xcrun simctl ui <UDID> increase_contrast enabled` | `… disabled` | 22.3 % changed, app content region (`WR/display/home-ic-on.png`) |
| Content size | `xcrun simctl ui <UDID> content_size accessibility-extra-extra-extra-large` | `… content_size <recorded>` | 36 % changed (`WR/display/home-ax5.png`). Round 1 already relied on this (§ Pre-flight A1). |
| Bold Text | `xcrun simctl spawn <UDID> defaults write com.apple.Accessibility EnhancedTextLegibilityEnabled -bool true` then `xcrun simctl spawn <UDID> notifyutil -p com.apple.accessibility.enhance.text.legibility.status` | same with `false` + notify | 2.2 % changed on Setting, 0 % after off (`WR/display/bold-text-on.png`, `bold-text-off.png`) |
| Button Shapes | key `ButtonShapesEnabled`, notify `com.apple.accessibility.button.shapes` | `false` + notify | Tab bar gains an outline (`WR/display/button-shapes-crop.png`), 0 % after off |
| Reduce Transparency | key `EnhancedBackgroundContrastEnabled`, notify `com.apple.accessibility.enhance.background.contrast.status` | `false` + notify | Navigation-bar blur turns opaque and the Popular/Watched cards change fill (`WR/display/pair-rt.png`) |
| Reduce Motion | key `ReduceMotionEnabled`, notify `com.apple.accessibility.reduce.motion.status` | `false` + notify | Toast dismissal slides without it (`(709,739)→(730,760)→(743,772)→(784,804)`) and fades in place with it (`(709,739)→(710,739)→(710,729)→gone`), matching `View+Toast.swift`'s gate (`WR/display/motion/dismiss-analysis.txt`) |
| Grayscale | key `GrayscaleDisplay`, notify `com.apple.accessibility.grayscale` | `false` + notify | **No change in captures** (diff 0.0000, `WR/display/home-grayscale-on.png`). Use software conversion (`PIL Image.convert("L")`) of normal screenshots instead. |

`WR/scripts/ax-setting.sh <udid> <reduce-motion|reduce-transparency|bold-text|button-shapes|grayscale> <on|off>`
wraps the five `defaults` rows and prints the read-back. Key and notification names were taken from the
runtime's `libAccessibility.dylib` strings and confirmed by the live effect above
[VERIFIED: strings + live effect]. `simctl ui` supports only `appearance`, `increase_contrast` and
`content_size` [VERIFIED: `xcrun simctl help ui`]. `agent-device settings` covers appearance and animations
but none of the accessibility display settings [VERIFIED: `agent-device help settings`].

Pitfalls observed:
- **Stale off-screen tab.** Bold Text was toggled on and off while Setting was frontmost. When Home was
  shown afterwards it still rendered "Popular"/"Watched" bold until the next accessibility notification
  re-rendered it (`WR/display/pair-drift.png`). Set a display setting while the screen under test is
  frontmost, or re-verify by screenshot after navigating.
- **System push transitions still slide under Reduce Motion** on iOS 26.5 (`push-rm-off-sheet.png` vs
  `push-rm-on-sheet.png` are the same slide). Checklist 7.1's "no sliding" cannot be judged on system
  navigation. Judge the app's own D-29 gated sites.
- The hero carousel and image loading keep changing Home pixels. Diff against a fresh baseline taken just
  before the toggle, and read the diff's bounding box, not only its size.
- Restore to the **recorded** baseline per simulator (§ Simulator baseline rule), not to a fixed value. The
  throwaway's end state was read back: all five keys `0`, `appearance=light`, `content_size=large`,
  `increase_contrast=disabled`.

---

## 6. What genuinely needs a human listening

With the spoken text, the voice identifier, hints, announcements and utterance completion all in the
VoiceOver log, the list shrinks to:

| # | Item | Why no agent method covers it |
|---|---|---|
| L-1 | **How the speech sounds**: pronunciation and intelligibility of gallery titles, uploader names, mixed CJK/Latin text, abbreviations (`JA`, `MiB`), and the numbers VoiceOver spells out (`4 dot 50`, `2024 slash 10 slash 27`, `15 <break> 20`). | The agent sees the post-processed text VoiceOver sends to the synthesizer, not the audio. The simulator speaks with `com.apple.voice.compact.en-US.Samantha`; the device may use other (enhanced or per-language) voices, so even a recording from the simulator would not match what users hear. |

Items that sound like listening but are covered:
- *Wording, verbosity, duplicated hints, "button button"*: the exact strings are logged. The agent judges them.
- *Which language or voice speaks a label*: `Spoke: [<lang>:<voice id>]` is logged per utterance.
- *Announcement timing and interruption*: the log has the announcement text, its enqueue time and the
  `Completed utterance` time, so a truncation shows as an utterance "completed" far sooner than its length
  allows (toast case: enqueued 02:11:50.885, replaced at 02:11:51.698). Heuristic, MEDIUM. The owner may
  confirm by ear if a case matters.

Device-only remainders that are **not** listening (optional, owner's call):
- D-1: VoiceOver **double-tap activation** of custom-tappable and `accessibilityActivate` paths, and running
  a rotor custom action. The simulator's VoiceOver Activate does not fire (§ 1).
- D-2: a one-time **calibration** of simulator focus against the device on two transitions from § 2
  (pop → `Account`, sheet dismiss → `Search`) and a check of the carousel loop (VO-1).
- D-3: **speaking Voice Control commands** (§ 4), only if the label proxy is not enough.

---

## 7. Login-gated flows

**D-09 simulators are gone.** `xcrun simctl list devices | grep -c -E "88B217DA|E2BF974E|ADE09605|8250D97E"`
prints `0`, so the `IPHONE_UDID`, `IPAD_UDID` and both recorded spares are absent [VERIFIED]. The gates in
16-24 already moved to iPhone 17 `73E148DA…` and iPad (A16) `B6679864…`
(`16-24-SUMMARY.md:132-133, 173`), but `16-26-PLAN.md` Task 2 still names `88B217DA…`, and
`.planning/config.json` `workflow.test_command` still names `ADE09605…`.

Also observed, **not touched**: a booted simulator named `EhPanda Login iPhone Air (26.5)`
(`C9C8B01B-1FBC-466E-A4F8-C46B13E1D07D`), with an `agent-device` runner session attached. It may be a
login simulator being prepared elsewhere. The orchestrator should ask before counting on it.

**Flows that need a session** (`16-SWEEP.md § Inventory` "Login-gated" column, plus hermetic observation):

| Flow / surface | Why it needs a session |
|---|---|
| Favorites root (#8) | Inventory `yes`. Logged out shows the login placeholder. |
| Home › Watched (#5) | Inventory `yes` |
| Detail › Archives (#19), Torrents (#20) | Inventory `yes` |
| Setting › EhSetting (#38) | Inventory `yes` |
| Downloads › FolderManager (#13) | Inventory `yes` |
| Detail › Detail Search (#17) | Inventory `yes` (live). Hermetic tag-tap routing not probed. |
| Rating | Hermetic Detail shows `Give a Rating` **disabled** (`WR/walk-detail-01.txt`: `'Give a Rating'` `'dimmed'`) |
| Favoriting from Detail | `Add to favorites` **disabled** (`'dimmed'`) |
| Posting a comment | `Post Comment` **disabled** (Comments outline, `WR/focus-push-comments.txt` context) |
| Tag vote actions (OQ2 tag chip) | Menu items only `if didLogin` (`DetailView+Subviews.swift:477-479`) |
| Download row actions (OQ2) | Needs an existing download, not a session. The non-credential `EHPANDA_AUTOMATION_AUTO_DOWNLOAD_GID` / `EHPANDA_AUTOMATION_DOWNLOAD_FOLDER` keys exist (`AppLaunchAutomation.swift:52-59`); whether a stubbed-network download completes is unknown. |

Hermetic, no session needed (probed): Home, Frontpage grid, Search + Filters sheet, Setting + General,
gallery Detail (`EHPANDA_AUTOMATION_GALLERY_URL`), Comments, Reader + control panel + slider, error toast.

**Options (not chosen here; the orchestrator asks the owner):**

| Option | What happens | Owner cost | Agent coverage | Risks |
|---|---|---|---|---|
| A. Owner logs in once, by hand, on a new dedicated simulator (D-09 pattern) | Owner signs in through the app's WKWebView on a simulator the agent then treats as infrastructure (install-over only). The agent runs the in-simulator VoiceOver method there. Toggling VoiceOver writes only `com.apple.Accessibility` prefs, never the app container. | One manual login (minutes). Repeat only if that simulator is erased. | Full: every gated flow gets the same VoiceOver, focus, rotor and display checks as hermetic flows. | Real gallery content in transcripts and screenshots (D-32: evidence root only). External simulator shutdowns (seen this session) do not lose the login, but erasure would. |
| B. Physical iPhone driven by `agent-device` | The agent installs over and drives taps. VoiceOver is toggled by the owner or via Settings. | Passcode on **every** XCUITest runner launch (project memory). The owner's device is in use. | Weak for VoiceOver: no keyboard-chord channel [ASSUMED], no live `vot` log without `sudo log collect` (project memory). Focus and order evidence would fall back to the owner. | Highest owner time. Contradicts "agent does it first". |
| C. Source verification plus hermetic fixtures | Gated screens are verified by reading source (labels, actions, gates); hermetic flows by the simulator method. | None | Partial. Fixtures are only `FrontPageList.html`, `GalleryDetail.html`, `GalleryDetailAlt.html`, `GallerySinglePage.html` [VERIFIED: `ls EhPandaUITests/Fixtures`], so Favorites, Watched, Archives, Torrents, EhSetting, rating, posting and tag votes can only be read, never walked. No credential-free way to render them logged in exists today; the only launch-time login switch is the D-09-rejected seam, which this research does not propose. | Gated rows can say only "source-verified", which is honest under the best-effort scope but untested. |

---

## Candidate findings surfaced by the probes (for 16-25's fix loop; re-verify on a HEAD build)

These came up while validating methods, on the build described at the top. They are **observations, not
closed verdicts**. 16-25 should re-run them first.

- **VO-1 — Home hero carousel traps VoiceOver linear navigation (1.1).** "Next item" from the first card
  steps through the sliding-window card buffer without end (frames at `x≈381`, off-screen, scrolled in) and
  never reaches Frontpage, Toplists or the tab bar by linear navigation. About once per loop, focus is reset
  to the `Home` heading with no key press (`Will set element: Home` 1.2 s after focusing a card)
  (`WR/walk-home-02.txt`, `WR/walk-home-03.txt`). Source context: `CardSlideSection` renders
  `ForEach(bufferedCards)` over `(windowBase..<windowBase + count * windowBlocks)` and rebases
  `windowBase += (block - middleBlock) * count` when a scroll settles outside the middle block
  [VERIFIED: HomeView+Sections.swift:82-88, 170-177, read this session]. The mechanism linking the rebase
  to the focus reset is [ASSUMED]. The 16-24 owner-approved exclusions concern audit reports on the
  carousel, not VoiceOver traversal.
- **VO-2 — Reader slider-preview strip is reachable by VoiceOver while hidden (1.5).** With the control
  panel shown and no preview visible (`WR/17-reader-panel.png`), "next item" after `Close` focuses three
  unlabeled 20×20 elements at `y≈774` and the captions `0`, `1`, `2` at `y≈788`, all silent, before reaching
  the `Page` slider (`WR/walk-reader-panel.txt`). The strip is wrapped in `.visible(showsSliderPreview)`,
  which is `opacity(isVisible ? 1 : 0)` + `.accessibilityHidden(!isVisible)`, and each slot in
  `.visible(checkIndex(page))` [VERIFIED: ViewModifiers.swift:61-64, ControlPanel.swift:203-227, read this
  session]. Why VoiceOver still reaches them is [ASSUMED] (one hypothesis: the inner
  `.accessibilityHidden(false)` on in-range slots re-exposes children of the hidden container, but slot `0`
  was reached too). **This bears on `E-1.hidden-content`**, which the owner approved on the premise that "the
  hide works — the audit engine walks past it" (`16-CONTRAST-AUDIT.md` E-1 row). Under D-22 it goes back to
  the owner with this evidence rather than being silently accepted.
- **VO-3 — Focus return (1.8), for the owner's ruling:** pop from General lands on `Account`, not the
  `General` trigger. Dismissing the Filters sheet (opened from the More menu) lands on the `Search` title,
  not `More` (§ 2 table).
- **VO-4 — Spoken verbosity (1.2), for judgment from text:** comment cells read the full URL character
  class by class (`https colon slash slash www dot pixiv dot net slash users slash 750220 …`) and dates as
  `2024 slash 10 slash 27, 15 <break> 20`. The Detail rating reads `110 Ratings` / ` 4 dot 50`, and the
  stats strip interleaves headers and values (§ 1).

---

## Recommended shape for the revised 16-25 and 16-26

### 16-25 — agent-run VoiceOver / Voice Control / display walkthrough on main flows

**Environment.** A HEAD build installed on a simulator. Hermetic flows use a fresh simulator (throwaway or
iPhone 17 `73E148DA…`); gated flows use whatever § 7 option the owner picks. Header: build hash, UDID, iOS
version, simulator language (English, D-30), baseline `appearance` / `increase_contrast` / `content_size`
and the five `com.apple.Accessibility` keys read back.

**Main flows (owner option 2)** — one row set per flow, not per cell:

| Flow | Route | Session |
|---|---|---|
| F1 Browse | Home (carousel, Frontpage, Toplists) → Frontpage list | no |
| F2 Search | Search → type keyword → results → More › Filters sheet → dismiss | no |
| F3 Gallery detail | Frontpage cell → Detail → tag chip → Comments | no (tag votes: yes) |
| F4 Read | Detail › Read → tap page → panel → slider → Close | no |
| F5 Favorites | Favorites tab → list → Detail › Add to favorites | yes |
| F6 Download | Detail › Download → Downloads row → row actions / context menu | download row needed |
| F7 Change a setting | Setting → General → toggle → back | no |
| F8 Comment / rate | Comments › Post Comment; Detail › Give a Rating | yes |

**Per-flow checks (agent):**
1. VoiceOver walk transcript for every screen in the flow (1.1–1.6): order, labels, traits, hidden or
   decorative elements, traps. `vo-walk.sh`; the evidence is the transcript path.
2. Focus after every push, sheet, menu and dismiss in the flow (1.7 / 1.8), with the pre-transition focus
   recorded. `vo-events.sh`.
3. Rotor actions on the flow's action-bearing elements (tag chip F3, comment cell F3, download row F6) plus
   the `custom_actions` cross-check. This settles OQ2 / `CONTEXTMENU=` from the simulator.
4. Adjustable controls (F4 slider, 1.9) and announcements (toast, loading, 1.10) with the interruption
   heuristic.
5. Voice Control label proxy on every actionable element in the flow (2.1 / 2.3 / 2.4 / 2.7), English.
6. Display pass on the flow's key screens: Dark + Increase Contrast, Bold Text, Button Shapes, Reduce
   Transparency, Reduce Motion (video on a D-29 gated site in the flow), grayscale by software conversion,
   and an AX5 spot check. Settings are toggled while the screen is frontmost, then restored.

**Recording.** In `16-SWEEP.md § Round-2 walkthrough (16-25)`: a table `flow | check (qa id) | method |
result (pass / finding:#N / accepted: reason) | evidence ($HOME path, not committed)`, with a written
description per finding. Transcripts and screenshots stay in the evidence root (D-32; transcripts carry
real titles). Candidate findings VO-1…VO-4 are re-run first and enter the fix loop or go to the owner (VO-2
under D-22).

**Owner checkpoint (one, short):** (a) L-1 listening: the agent names the utterances to listen to (for
example a Detail header, a comment cell, a CJK-titled card, a rating) and the owner reports anything
unintelligible; (b) rulings on VO-3 focus policy and VO-2 / E-1; (c) optionally D-1 / D-2 / D-3. Fix loop as
today: catalog keys, round-2 idioms, no suppression, module tests + lint build per fix.

### 16-26 — D-25 re-sweep + closing gates + sign-off (no Nutrition Label)

- **Re-sweep:** the touched-screen union from `16-CONTRAST-AUDIT.md § D-25 re-sweep candidates`,
  `16-SWEEP.md § D-25 re-sweep` (today: `14 Gallery Detail`, iPhone portrait XXL / AX3 / AX5), plus any glyph
  or size change a 16-25 fix makes. It must be **re-pointed**: the § Infrastructure UDIDs and the
  install-over protocol reference deleted simulators. Detail renders hermetically through
  `EHPANDA_AUTOMATION_GALLERY_URL`, so a fresh simulator can host that row unless the owner wants live
  content (§ 7 option A).
- **Gates:** `FeatureTests` then `UITests` sequentially on iPhone 17 `73E148DA…` (not `88B217DA…`);
  standalone SwiftLint 0; the five custom rules present; phase-range added-image check `0`. Fix
  `workflow.test_command` in `.planning/config.json` (still `ADE09605…`) or state that the gate uses an
  explicit destination.
- **Sign-off:** the owner reviews the re-sweep closure and the 16-25 closure (including any accepted
  findings and the L-1 result). Drop `16-NUTRITION-LABEL.md`, the §4 template, the eight-by-nine matrix
  and the claim language. A11Y-01 / A11Y-02 traceability moves into the 16-26 summary.

---

## Assumptions log

| # | Claim | Section | Risk if wrong |
|---|---|---|---|
| A1 | The probed build's app sources equal HEAD's (built 11 s before `c91c2b31`) | Header | Observations VO-1…VO-4 could be stale. Mitigated by re-running on a HEAD build. |
| A2 | Simulator VoiceOver focus decisions match the device's (same `vot`, different activation path) | § 1, § 2 | Focus verdicts could differ on device. Optional D-2 calibration. |
| A3 | XCUITest / `agent-device snapshot` order cannot reveal traversal dynamics such as VO-1 | § 1 | Low: VoiceOver itself is the oracle either way |
| A4 | XCUITest on a physical iPhone cannot send VoiceOver keyboard chords | § 2, § 7 B | Option B might be less costly than stated |
| A5 | Custom tappables exposed only as custom actions do not get a "Show numbers" badge | § 4 | Voice Control proxy could over- or under-flag |
| A6 | macOS `say` into the device microphone could drive Voice Control | § 4 | Untested. Only matters if D-3 is chosen. |
| A7 | The carousel rebase causes VO-1's focus reset; the inner `accessibilityHidden(false)` causes VO-2 | Candidate findings | Root-cause guesses only; the fix loop must confirm |
| A8 | A stubbed-network download from `EHPANDA_AUTOMATION_AUTO_DOWNLOAD_GID` can produce a download row | § 7 | OQ2 download row may need a live session |

## Open questions

1. **Which § 7 option for gated flows?** Owner decision. The booted `EhPanda Login iPhone Air (26.5)`
   simulator may already be an option A candidate.
   **RESOLVED (2026-09-15):** option A. The owner logged in by hand on `EhPanda Login iPhone Air (26.5)`
   `C9C8B01B-1FBC-466E-A4F8-C46B13E1D07D` (login confirmed by a populated Favorites list); it is the D-09
   simulator for gated flows, iPhone only ("只做 iPhone 就好").
2. **Download row for OQ2 / F6 without a live session?** Try the automation download keys on a hermetic
   simulator first. If no row appears, F6 moves to the gated set.
   **RESOLVED (2026-09-15):** the revised 16-25 tries the hermetic automation download first, then the
   logged-in simulator (one real download at most), and records the outcome if neither yields a row.
3. **VO-2 versus the approved `E-1.hidden-content` exclusion.** D-22: present to the owner with
   `WR/walk-reader-panel.txt` and `WR/17-reader-panel.png`.
   **RESOLVED (2026-09-15, orchestrator under the owner's delegation "全都先你自己做"):** VO-2 is a defect
   fixed in 16-25 across every hide-idiom site; `E-1.hidden-content` is removed only if its audit reports
   disappear on both gate devices. Only a fix that needs a visible change returns to the owner (D-22).
4. **Focus-return policy (VO-3).** The owner rules whether pop → first row and dismiss-from-menu → title
   are acceptable.
   **RESOLVED (2026-09-15, orchestrator under the same delegation, which named VoiceOver focus testing):**
   the skill's qa-checklist is the standard: 1.7 push → first element of the new screen; 1.8 sheet/alert
   dismiss → the triggering element (the Filters → Search-title case is a fail). Pop-back focus is not a
   checklist item and is recorded as an observation.

## Sources

### Primary (verified this session)
- iOS 26.5 simulator runtime: `VoiceOverTouch.app/vot`, `com.apple.VoiceOverTouch.plist`,
  `VoiceOverServices.framework/DefaultCommandProfile.plist`, `libAccessibility.dylib` strings,
  `SpeechRecognitionCommandAndControl.framework` strings.
- Live probes and logs: `WR/` (paths above); `xcrun simctl help ui`; `sim-use help describe-ui|touch|ios batch|ios key-combo`; `agent-device help settings`.
- Repository files read: `16-25-PLAN.md`, `16-26-PLAN.md`, `16-CONTEXT.md` (D-08…D-11, D-21…D-25, D-26…D-34), `16-SWEEP.md` (§ Infrastructure, § Protocol, § Inventory, § D-25 re-sweep), `DetailView+Subviews.swift:425-504`, `CommentsView.swift:170-219`, `ViewModifiers.swift:54-65`, `ControlPanel.swift:168-229`, `HomeView+Sections.swift:60-184`, `AppLaunchAutomation.swift:48-77`.
- Skill: `$HOME/.claude/skills/swift-accessibility-skill` (SKILL.md, `resources/qa-checklist.md`, `references/testing-auditing.md`, `references/voice-control.md`).

### Secondary
- [Deque: Intro to iOS Accessibility Inspector](https://www.deque.com/blog/intro-accessibility-inspector-tool-ios-native-apps/): the inspector's claimed VoiceOver-like navigation (not relied on).
- [Apple Developer Forums: VoiceOver on the simulator](https://developer.apple.com/forums/thread/83458): the long-standing "not available in Simulator" guidance, which this session's probes supersede for iOS 26.5 via the command line.

## Metadata

**Confidence breakdown:**
- VoiceOver-in-simulator method: HIGH. Probed across six screens with the log as oracle.
- Display settings: HIGH for seven settings (live effect shown). Grayscale capture limit: HIGH (0 diff).
- Voice Control on simulator: HIGH that recognition is blocked (pasted error). Overlay: no observation.
- Device parity, physical-device option, speech-driven Voice Control: LOW (not probed).

**Valid until:** the next Xcode or simulator runtime change (the method depends on private runtime
components: `vot` log categories, preference keys, notification names). Re-validate the recipe at the start
of 16-25.
