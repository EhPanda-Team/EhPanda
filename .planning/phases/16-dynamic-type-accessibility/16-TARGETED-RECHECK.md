# Phase 16 targeted visual recheck — 2026-09-08

The owner requested a fresh sim-use inspection because the historical findings were unclear. This report records a targeted check, not completion of plan 16-11 or a replacement for the 504-cell matrix.

## Build and scope

- Source: `7d874f93bd39702b4642bbec8d680945be8d480a` (no source edits).
- Both exact-destination Debug simulator builds succeeded. Bundle identifier verified as `app.ehpanda.personal` before installation over the existing containers.
- iPad: `8250D97E-9AB0-42FD-99DB-07B0094BF8C7`, iPad Pro 11-inch (M5), iOS 26.5, portrait/light. Normal Large, AX3 and AX5 sampled as noted below.
- Supplemental iPhone: `E2BF974E-DE4D-4A67-B84A-90D41325C4A7`, iPhone 17e, iOS 26.5, portrait/light, Large and AX5. Its initial boot/migration delayed preflight; preflight passed after boot completed. This is supplemental evidence, not a substitute for the original iPhone sweep matrix.
- The original iPhone Air UDID is absent from the current simulator inventory. The historical evidence directory, including the four D-15 baselines, is also absent.
- Evidence: `$HOME/.codex/visualizations/2026/09/08/01a08081-1265-72c1-b663-16a2706740c6/phase16-review/`. `index.html` explains selected raw captures in Traditional Chinese. No screenshot is stored in the repository.

## Reproduced observations

| Finding | Current visual result | Evidence filename |
| --- | --- | --- |
| #4 | iPhone Toplists at AX5 shows a blank search capsule: neither magnifier nor Filter is drawn, though the accessibility outline reports the text field. The normal-size capture has both. iPad Frontpage at AX5 does show them; this is not a universal search-field failure. | `iphone-toplists-large.png`, `iphone-toplists-ax5.png`, `ipad-frontpage-filter-ax5.png` |
| #7 | iPhone title reads `Toplists - Yeste…` at AX5 versus the complete `Toplists - Yesterday` at Large. The period menu remains available; this is title truncation, not loss of navigation. | `iphone-toplists-large.png`, `iphone-toplists-ax5.png` |
| #26, Auto-Play site | iPad reader menu shows a tick beside Off at Large; the tick is visually absent at AX5 although the outline still reports `#checkmark`. No interval was selected; playback stayed Off. The Runs site behaves differently (below). | `ipad-autoplay-large.png`, `ipad-autoplay-ax5.png` |
| #31 | iPhone AX5 error toast shows only `This link wasn't…`; its normal-size form retains much more of the sentence but also uses an ellipsis. Tapping the toast opens an error detail with the full unsupported-link explanation and a scrollable suggested solution. This is toast information reduction, not complete loss of the explanation. | `iphone-error-toast-large.png`, `iphone-error-toast-ax5.png`, `iphone-error-detail-ax5.png`, `iphone-error-detail-bottom-ax5.png` |

## Checks that did not reproduce the old failure

- Runs selector (#26): iPad portrait AX3 and AX5 visibly retain the selected Run 5 tick. Current source uses a native Picker here; Auto-Play still uses an image accessory. Do not close the combined finding while its Auto-Play site remains reproducible.
- Detail statistics (D13-1): iPad AX5 captions and values remain readable. Horizontal scrolling reaches the full rating stars, page count and file size. Clipping at the scroll viewport edge is not counted as information loss when the complete column is reachable.
- Detail tags (D13-2): sampled iPad AX5 chips remain within the sheet width; scrolling reaches the lower tags. This gallery does not establish exhaustive coverage of arbitrarily long tags.
- Reader counter (D13-3): iPad AX5 clearly displays `1 / 15` in the upper bar. No disappearance reproduced at this sampled configuration.
- Carousel (D13-5): the iPad AX5 long title still ellipsizes inside its bounded card. Treat this as evidence for review of the latest cover design; do not silently claim that the full title always fits.

## Unverified and unavailable

- #11/#23/#37 delete confirmations: both devices have empty Downloads; no downloads were started or seeded to create a destructive-action fixture. Existing #37 acceptance remains preserved.
- #28 account E-Hentai Settings and D13-4 populated Favorites: iPad Favorites currently shows the login-required state, and the Settings root does not expose the account-specific settings route. Historical `IPAD_LOGIN=present` is not valid current evidence. No credential was entered and no logout was performed.
- #35 pre-change default-size parity: the historical baseline directory is absent. A current comment card cannot prove parity with that missing reference.
- iPhone Frontpage filter: three reveal attempts did not expose the field, so further attempts stopped. The affirmative #4 reproduction above comes from Toplists, where the capsule was visible.
- Landscape and the full XXL/AX3/AX5 matrix were not rerun. The early `ipad-frontpage-filter-ax3.png` capture may predate completion of the live relayout; do not use it as AX3 verdict evidence. Current verdicts rely on settled AX5 captures.

## Restoration and next step

Both devices read back `large`, `light`, and `increase_contrast disabled`, matching their live starting settings; orientation stayed portrait. iPad returned to Settings / Multitasking & Gestures. iPhone returned to its original shutdown state. App installation and ordinary navigation/cache/history effects occurred; no gallery was deleted, no download was started, no account action was taken, and no playback option was changed.

The four reproduced observations now have current visual evidence. No owner disposition or `ROUND1-CLEAR` is inferred. Plans 16-10/11 remain halted at review; the next discussion should use this report rather than presenting the historical open labels as current defects.

## Owner review — 2026-09-08

The owner acknowledged seeing the first two reproduced observations, requested the missing Auto-Play screenshots, and accepted the fourth item (#31): 「第四個我覺得展示不下就展示不下直接接受」. Finding #31 is accepted; no fix is requested. Both Auto-Play screenshots were added to the external comparison page. The first two observations and Auto-Play are not marked accepted by this reply.

## Follow-up diagnosis — 2026-09-08

The owner requested investigation of blank search content and missing selection marks. See `.planning/debug/phase16-search-menu.md` for the experiment record.

- Title: `NavigationTitleDisplayModeModifier` explicitly selects inline mode at every accessibility size. A fresh AX5 Toplists entry confirmed this before scrolling. The owner's conditional acceptance of truncation after scroll collapse does not establish acceptance of this initial inline configuration.
- Search: a standalone native SwiftUI `NavigationStack` + `List` + `.searchable` reproduced the blank capsule after revealing search at Large and switching to AX5. No application toolbar, TCA, gallery data, or appearance customization was required. The failed field measured 96 points high. Changing only the drawer display mode to `.always`, with the original title and title-mode behavior retained, produced visible Filter text and magnifier at AX5, with a 124-point field. This isolates the native automatic drawer layout/update path; private framework internals were not inspected. Focusing the failed probe and typing displayed text. The candidate has not been tested in production App integration.
- Auto-Play: an isolated manual `Text` + checkmark `Image` menu reproduced the invisible mark at AX5, while a native inline `Picker` visibly marked the same Off selection. This validates the candidate already used by the working Runs menu; Auto-Play production code is unchanged.
- Evidence: the existing external review page now includes `probe-search-ax5.png`, `probe-search-always-transition-ax5.png`, `probe-manual-menu-ax5.png`, and `probe-picker-menu-ax5.png`, with both reproduction and candidate probe sources alongside them. These are explicitly labeled standalone experiments, not screenshots of a fixed App.
- Scope/restoration: diagnosis only; no production Swift code changed. The separate native test app remains installed on the supplemental simulator. Its text size was restored to Large and the simulator returned to Shutdown; the iPad was not touched during this follow-up. Existing #31 and #37 acceptance remains unchanged.

## Owner dispositions and implementation history — 2026-09-08

- Finding #4: accepted as an Apple/native framework defect; explicitly no app fix. Do not change search placement to `.always` for this finding. The probe remains diagnostic evidence only.
- Finding #7: title truncation/initial inline presentation accepted as-is; no title change requested. Technical clarification: the current accessibility-size inline fallback is explicitly applied by the app's `NavigationTitleDisplayModeModifier` to avoid the observed platform large-title rendering issue; it is not an unconfigured Apple default.
- Auto-Play remains under discussion. Its implementation is a native `Menu` containing `Button` rows and a conditional checkmark `Image`, not a `Picker`. Commit `77097ff7` (`feat: AutoPlay`, 2021-09-25) introduced this structure alongside an existing dual-page menu using the same pattern. The code predates Phase 16; the parent of `5614f486` already contains it. Inference: the feature reused the neighboring action-menu pattern and retained it through later layout work. The commit does not state a reason for avoiding Picker, so no API limitation or intentional rejection of Picker is established.

## Owner-requested native title review — 2026-09-08

The owner subsequently requested removing all accessibility-size forced-inline behavior and deleting the explicit display mode on App Activity Logs. This supersedes keeping the earlier fallback. The common modifier is deleted; all automatic call sites omit a display mode; Setting retains its designed native `.inlineLarge` tab / `.large` sheet choice without an AX override. Auto-Play is unchanged pending discussion.

Build succeeded and changed Swift files passed SwiftLint. On iPhone 17e / iOS 26.5 portrait AX5, a fresh App Activity Logs entry draws a large title truncated to `App Activit…`; pulling out search retains that title. A fresh Toplists entry already at AX5 rendered an inline truncated title in the sampled navigation state. After switching to Large and pulling to reveal the full large title, switching back to AX5 makes the title disappear and compresses the search field to 23 points. Evidence: `logs-automatic-ax5.png`, `logs-automatic-search-ax5.png`, `toplists-automatic-ax5.png`, `toplists-automatic-large.png`, `toplists-automatic-transition-ax5.png` on the external review page. No all-device/all-screen conclusion is inferred. Search remains an accepted Apple defect, no workaround applied. Simulator text size restored to Large and returned to Shutdown.

Auto-Play migration discussion: retain its timer Menu label, Off and 1–5 second options, and binding to the existing timer handler; native inline Picker would own selection rendering. Existing Button re-selection always calls the handler and restarts its timer; equivalent behavior on selecting the same Picker value is not yet verified. The same manual Text/Image menu pattern appears in ToplistsTypeMenu, FavoritesIndexMenu, SortOrderMenu, Downloads folder filters, and reader dual-page/except-cover controls. These are separate implementations, not shared instances of Auto-Play. Dual-page/except-cover are independent booleans (native Toggle semantics), not one single-choice Picker. A separate Runs sheet uses a Label checkmark in RunButton; it is not the already-migrated Runs popup menu and has not been implicated by the menu probe.

## Latest AX policy instruction — 2026-09-08

The owner now requests shared temporary title/search workarounds on previously affected screens, independent inlineLarge measurement, and verification of the remaining hand-built selection menus. This supersedes the earlier search no-fix instruction and the title-fallback removal. See `16-AX-POLICY-REVIEW.md` for scope, implementation, and the 2026-09-09 sim-use measurement results and remaining coverage.

## Manual selection inventory completed — 2026-09-09

The remaining Favorites sort order and reader dual-page/except-cover controls now have direct
Large → AX5 → Large comparisons. All lose their manual popup ticks at AX5 and regain them at
Large. Favorites sort used an isolated build with a seeded selected value and the unchanged
production menu; reader controls were tested in the actual landscape reader. Temporary state
and reading settings were restored. See `16-AX-POLICY-REVIEW.md` for evidence, setup, and scope.
No Picker/Toggle conversion was made.

### Native control migration authorized and verified — 2026-09-09

The subsequent owner approval authorized converting the five failing single-choice menus to native
Picker and both reader booleans to native Toggle. All seven controls retain their selection marks
in the measured AX5 states. Auto-Play reselect restarts the existing timer; Favorites sorting keeps
the server-confirmed value on failure. Four Favorites tests and lint on 18 Swift files passed.
See `16-AX-POLICY-REVIEW.md` for fixture scope, screenshots, behavior checks, and remaining limits.
Earlier statements that no conversion was implemented describe the prior measurement-only step.

### Direct menu Picker simplification — 2026-09-09

Owner approval authorized direct `.menu` Picker for Favorites category/sort, Toplists type,
and Auto-Play, using native `currentValueLabel` for the existing icon entry. Removed
FavoritesIndexMenu, ToplistsTypeMenu, and SortOrderMenu instead of adding a generic wrapper.
Moved their two localized titles into the owning feature catalogs, preserving every translation.
Downloads retains Menu + Picker for its additional action; reader booleans retain Menu + Toggle.
Existing bindings, `.sending` actions, and reducer/timer behavior are unchanged.

Verification: final production build succeeded (24.908 seconds); four changed view/component
Swift files passed SwiftLint; catalog entries exactly match their original translations;
`git diff --check` passed. Direct lint of Package.swift reports its existing file-length
violation (HEAD 1128 lines, now 1129, limit 1000); no suppression or lint-rule change was added.

Sim-use preflight and app checks passed on a new dedicated iPhone 17e / iOS 26.5 simulator.
The earlier iPhone failed installation/system startup and the earlier iPad's device data was
missing; neither was erased. Direct Picker icon entries and AX5 native ticks were observed for
all four controls. Production Favorites category switched All to Favorites 0; Toplists switched
Yesterday to Past Month and updated its title. Sort selected-state rendering used an isolated
app with lastUpdateTime seeded in State because this clean device is logged out; it does not
claim a live authenticated sorting request passed. Production optional state remains unchanged.

The isolated app also temporarily logged AutoPlayHandler.setPolicy: selecting 5 seconds and
reselecting 5 seconds both reached the existing handler (timestamps 1788915409.817172 and
1788915426.252449); Off reached it with rawValue -1. The unchanged handler invalidates and
recreates the timer on each positive policy write. Both temporary source edits were restored
byte-for-byte before the final production build. No fixture code is committed.

External review gallery `#direct-pickers` contains direct-picker-favorites.png,
direct-category-ax5.png, direct-toplists-ax5.png, direct-autoplay-ax5.png, and
direct-sort-ax5.png. This is targeted iPhone verification; iPad, VoiceOver speech, and broader
Phase 16 acceptance are not newly claimed complete.

### Native toolbars awaiting owner visual review — 2026-09-09

The owner authorized deleting CustomToolbarItem everywhere and trying a native reader upper
toolbar. All 17 call sites now use native ToolbarItem/ToolbarItemGroup; no replacement wrapper
was added. Toplists retains its alert-dependent disabled states on both controls. Favorites
uses separate items. Its category Picker still measures approximately 53 points at Large;
removing the manual HStack did not eliminate the native Picker's own width.

ReadingView now owns a NavigationStack with toolbar visibility driven by showsPanel and a hidden
navigation-bar background so page content remains full-screen. ReadingToolbar supplies native
close, title, Live Text, conditional dual-page Menu, Auto-Play Picker, and More items. Auto-Play
uses its ideal size to prevent it stretching the trailing group across unused toolbar space.
Removed the old upper FlowLayout, explicit glass backgrounds, and manual window/top insets.
The lower panel implementation, including preview rendering, was compared byte-for-byte and
is unchanged. Its remaining wrapper still provides the same bottom alignment and visibility.

**Pending owner confirmation:** do not limit lower-panel/preview Dynamic Type yet. The owner
requested that follow-up only after accepting the native upper toolbar. No dynamicTypeSize
modifier, font cap, lint suppression, or global policy change was introduced in this step.

Validation: production build succeeded (24.312 seconds), 19 changed/new Swift files passed
SwiftLint, no remaining CustomToolbarItem references in Swift, and diff whitespace checks passed.
Sim-use preflight passed on the dedicated iPhone 17e and newly created iPad mini A17 Pro, iOS 26.5.
Final-layout screenshots cover Large/AX5 portrait on both and iPhone landscape AX5 with all four
trailing controls. Page 1 / 54 remained visible; iPhone portrait places it beside Close and iPad
centers it. iPhone image frames stayed (0,0,390,551) and (0,551,390,552) through upper-panel
hide/show in the initial native layout. Reading Setting opened from More and its landscape
Close returned to the reader; dual-page and Auto-Play menus opened at AX5. iPad upper Close
dismissed the reader. Reading direction was temporarily changed to RTL for the dual-page entry.
Reading direction was restored to Vertical and both devices to Large after measurement.
No broad all-screen, VoiceOver, extreme page-counter length, or iPad windowing pass is claimed.

External review gallery `#native-toolbars` contains the final native toolbar screenshots.
This is a reviewable implementation, not owner acceptance or Phase 16 completion.

### Reader title glass and Favorites width investigation — 2026-09-09

Owner requested a glass container for the reader title and investigation of Favorites toolbar
width. Added horizontal/vertical padding and non-interactive regular glass to the Text inside
the existing native `.title` item. The title remains readable at Large and AX5 on iPhone 17e /
iOS 26.5. LowerPanel, previews, title placement, and dynamic-type policy are unchanged.

Sim-use measured the following temporary variants on the actual Favorites screen at Large:

| Variant | Category / sort width | Observation |
| --- | --- | --- |
| Original currentValueLabel Picker | ~53 / 50 pt | Icons visible |
| fixedSize + plain category / borderless sort | ~53 / 50 pt | No width reduction |
| Category menuIndicator visible | ~69 pt | Hidden indicator already saves ~16 pt |
| Sort ordinary icon-only Label, no currentValueLabel | ~24 pt | Nil sort produced a blank entry; unsuitable |
| Category ordinary Label + labelsHidden | ~43 pt | Selected All text replaces icon; unsuitable |
| Sort currentValueLabel + labelsHidden | ~50 pt | No reduction |
| Category native Menu with inline Picker and the same dial icon | ~43 pt | Icon retained, ~10 pt narrower |

These measurements isolate a native presentation difference between direct Picker and Menu
entries, not the removed CustomToolbarItem HStack. They do not establish a specific internal
padding constant or an Apple defect. A native Menu + Picker is a viable narrower icon-entry
option without restoring wrappers. All temporary Favorites source changes were restored
byte-for-byte before the final production build; this request commits no Favorites behavior
or structure change. The sorting-label probe was logged out/nil, not authenticated selection.

Evidence is in external gallery `#title-glass-width`, including title-glass Large/AX5 and
original-versus-native-Menu Favorites screenshots. Owner acceptance and the subsequent
lower-panel/preview Dynamic Type range change remain pending.

Final production build succeeded (20.809 seconds); changed Swift file passed SwiftLint and
`git diff --check` passed. Restored production Favorites entry verified after reinstallation.


### Menu + Picker and lower control approval — 2026-09-09

Owner approved native Menu + inline Picker, full-height reader title glass, and the lower
panel Dynamic Type range including preview and its separate Close button. This supersedes
the preceding pending lower-panel approval.

- Favorites category/sort, Toplists type and reader AutoPlay now use Menu with an inline
  native Picker. Existing bindings, TCA actions, optional sort tags and disabled conditions
  are preserved. Native labels retain accessible names without custom wrapper components.
- Reader title retains `.title` placement and its own glass, now with a 44pt minimum height
  matching adjacent native glass. A temporary `.sharedBackgroundVisibility(.visible)` probe
  did not provide a background for `.title`; that probe was removed.
- A temporary toolbar-local environment probe on iPhone 17e / iOS 26.5 measured system
  XS → `.large`, Large → `.large`, AX5 → `.xxLarge`. Removed the probe after measurement.
  ControlPanel alone now clamps to `.large ... .xxLarge`, covering its lower Close button,
  slider labels and preview. Menu contents retain full accessibility sizing.
- SwiftLint permits only that exact range in ControlPanel. The general ban still applies
  elsewhere, and a companion rule rejects other ranges in ControlPanel. Fixture checks
  confirmed approved range passes, wrong range fails, and the same range elsewhere fails.

Sim-use on iPhone 17e / iOS 26.5 confirmed category/sort entry widths of 43/40pt at Large
(previously 53/50pt), Favorites All and AutoPlay Off native checkmarks, title glass height at
Large/AX5, preview expansion/collapse at AX5, and the lower Close dismissing the reader.
Lower Close is 44pt at Large and approximately 50pt at both XXLarge and AX5. Favorites was
logged out, so authenticated sorting/network behavior was not verified. This pass did not
complete a fresh iPad or landscape verification. System type size restored to Large.

Production build succeeded (21.746 seconds), all four changed Swift files passed SwiftLint,
and `git diff --check` passed. External gallery `#menu-picker-lower-panel` contains this
pass's screenshots. This records the requested implementation, not Phase 16 completion.


### iPad reader sizes and leading title — 2026-09-09

At owner request, installed the latest reader build on iPad mini (A17 Pro), iOS 26.5,
and captured portrait Large, XXXL, AX3, AX5 plus expanded AX5 preview. Controls retain
complete sampled page numbers; lower Close measures 44pt at Large and about 51pt at
the other sampled sizes. Evidence: external gallery `#ipad-reading-type-sizes`.

The owner then requested a leading iPad title. ReadingToolbar now uses `.topBarLeading`
in regular horizontal size class and retains `.title` in compact width. The text keeps
its intrinsic width to avoid the native leading item's narrow proposal wrapping digits.
Its own 44pt-minimum glass stays separate from the Close item's system background.
Sim-use verified the final iPad portrait Large and AX5 layouts: the sampled page indicator
starts at x=82pt beside Close and remains complete. Evidence: `#ipad-title-leading`.
Build and changed-file SwiftLint passed. Restored system Large; no iOS 27 migration occurred.
This does not close the remaining full-phase Dynamic Type review.
