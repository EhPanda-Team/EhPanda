# Phase 19-13: Candidate Pre-Check & Open Findings

**Status:** Open. `A1`–`A9` and `A12`–`A14` are fixed on `fix/snapshot-scenarios` (`84c9c00bd`); the run-to-run variation fixes are in the same commits but not yet shown stable on a hosted run. The owner decided every former `owner to decide` item on 2026-11-22 (verdicts below): `A11`, `B1`, `B2`, `C8`, `C10`, `C12`, `C13` and `C14` are accepted; `C1`–`C3`, `C5`–`C7`, `C9`, `C11`, `C15` and `C16` are to be fixed and re-recorded (`C15` was accepted instead on 2026-11-25, see its row); `C4` changes the capture for every page (a fixed height per device, orientation and text size that covers the whole page, declared per view in a `*ViewSnapshot.swift` file through a test-only `SnapshotProvider` protocol). The candidate set must be re-recorded and pre-checked again before approval (19-CONTEXT D-17).

## Coverage & Machine Checks

- **Pictures checked:** `19,512` of `19,512` expected captured coordinates (`360` `notApplicable`).
- **Contact sheets viewed:** `1,220` contact sheets (`ceil(19512 ÷ 16) = 1220`), plus full-size inspection of every machine-flagged picture. Second-pass visual verification recovered the 146 sheets dropped from initial reviewer context so 100% of sheets were inspected.

| Machine Check | Run `44025665174` (`16a08f42a`) | Run `44137794244` (`ce3732a89`) | Notes |
| --- | ---: | ---: | --- |
| `unreadable` | 0 | 0 | 4 transient Vision read errors on first pass cleared on re-read |
| `uniform` | 200 | 200 | Loading screens and blank error surfaces (`C2`, site-settings error) |
| `placeholder` | 677 | 677 | Synthetic preview/failed-page placeholders by scenario design |
| `size-outlier` | 2 | 7 | Shorter localized text fitting without scroll (`analytics-choice-minimal` `ko`/`zh-Hant`), plus `A12` before `8f2c96fe3` |
| `same-as` | 0 | 0 | Distinct states differ |
| `same-in-both-themes` | 216 | 144 | Comic page filling viewport in reader scenarios (`reader-vertical` iPad landscape added after `A5`) |
| `truncated` | 173 | 173 | Long synthetic titles with ellipsis, system popovers at AX5, plus app truncation items in Section C |
| `untranslated` | 9 | 9 | Intentional English report prefill (`ReportPrefill.swift`) and proper nouns |
| `real-content` | 0 | 0 | Zero real user/gallery content; all markers match `PublicVisualFixtures` |
| **Total flagged coordinates** | **1,271** | **1,204** | Every flagged coordinate maps to an entry in Sections A–D below |

---

## A. Capture & Scenario Findings (`VisualSnapshotTests` / `VisualSnapshotSupport`)

| ID | Scenarios / Coordinates | Finding & Root Cause | Resolution / Commit | Verdict |
| --- | --- | --- | --- | --- |
| A1 | `settings-pages-general-basic`, `-full`, `-minimal` (multiple locales/sizes, phone & pad) | `scrollToBottom` jumped without animation into the large-title collapse range on pages only slightly taller than the window, leaving the title half-collapsed over the first row | `SettingsScenarios.scrollToBottom` snaps the title via `RevealStep.restWhereTitleSnaps` (`0f4cedf98`) | defect fixed |
| A2 | `settings-pages-general-cache-confirmation`, `-translations-confirmation` (iPhone landscape; iPad AX5 landscape) | Target row sat below the fold outside AX5, leaving its confirmation popover off-screen or mis-anchored | `RevealStep` now acts at every text size (`1d735dbb6`) | defect fixed |
| A3 | `gallery-detail-rating` (iPhone landscape) | User rating stars under `Rate Gallery` sat below the viewport | `RevealStep.reveal` includes `LibraryScenarios.userRatingHeight` below `Rate Gallery` (`1d735dbb6`) | defect fixed |
| A4 | `reader-live-text` (landscape) | Vertical reader fit page width so the recorded Live Text highlight sat below the landscape viewport | `GalleryScenarios.reader(.liveText)` fixes direction to `.leftToRight` (`d33462954`) | defect fixed |
| A5 | `reader-vertical` (iPad landscape) | Default `readingOrientation` switched landscape iPad to RTL two-page spread | Direction-named reader scenarios disable orientation matching (`d33462954`) | defect fixed |
| A6 | `app-wide-error-info` (iPad) | Device row read `"iPhone"` on iPad because preview `deviceClient` hardcoded phone | `SnapshotMatrixCase` uses `.live` `deviceClient` (`279540b63`) | defect fixed |
| A7 | `settings-pages-general-cache-confirmation`, `-translations-confirmation` | `Share Analytics Data` row showed no chosen value because fixture left `analyticsLevel = nil` | General confirmation fixtures set `analyticsLevel = .basic` (`8493cf859`) | defect fixed |
| A8 | `home-populated` (iPad) | Popular carousel had one blank neighbor and repeated `VH1` on the other side | `TracerScenarios.home()` supplies distinct neighbor galleries and `assets/home/` cover keys (`d4178574b`) | defect fixed |
| A9 | `downloads-inspector`, `downloads-inspector-error` (iPhone portrait) | Initial-state sheet mount left the underlying Downloads list undimmed and peeking below the sheet | Inspector opens via `tapHeldRow` after the hosted list settles (`ce3732a89`) | defect fixed |
| A10 | `detail-pages-new-dawn` (light vs dark) | Background sun rays appear in dark theme and not in light theme; verified static (non-animating) | Intentional dark-only static rendering; no capture change required | not a defect |
| A11 | `watched-signed-out` (`accessibility5` landscape) | Signed-out `ContentUnavailableView` exceeds `accessibility5` landscape height and becomes a scroll view, hiding the automatic navigation-bar-drawer search field (same family as `C13`) | Native UIKit/SwiftUI behavior when `ContentUnavailableView` scrolls; paired with `C13` for owner decision | not a defect (owner decision, 2026-11-22: native behaviour) |
| A12 | `settings-pages-general-cache-confirmation` (`ko` portrait) | `RevealStep` left Korean General mid-title-collapse when revealing the row | `RevealStep.reveal` applies `restWhereTitleSnaps` (`8f2c96fe3`) | defect fixed |
| A13 | Untouched scenarios across runs (`search-results-list`, `report-form-*`, `search-root-*`, `favorites-*`, `gallery-detail-loaded`, `history-clear-confirmation`, `reader-controls`, `reader-slider-scrub`) | 2-read premature settles on starved runners, unverified post-settle render, late `_UITextFieldClearButton`, simultaneous `.sheet`+`.alert` mount on `report-form-error-alert`, interactive glass shadow steps, and disabled+dimmed `GalleryLayoutPicker` bar item race | Six-read floor + kept settled image (`d24ea6438`); platter, clear-button, glass-shadow, report-alert, and disabled bar-item waits (`fc7ca9db5`) | defect fixed |
| A14 | `search-typing-suggestions` (`zh-Hans`, `zh-Hant` `accessibility5` iPhone landscape light) | `LibraryScenarios.type` did not wait for keyboard frame or bind `contentScrollView(for: .top)` to the suggestions list, toggling the navigation bar hairline across runs | Awaits `keyboardIsUp` and names the suggestions scroll view (`fc7ca9db5`) | defect fixed |

---

## B. Capture-Policy Choices Requiring Owner Decision

Each `B` item requires an owner decision on how the snapshot harness should represent the state before closing `19-13`:

| ID | Scenarios / Coordinates | Issue | Options | Verdict |
| --- | --- | --- | --- | --- |
| B1 | `app-wide-app-alert`, `comments-post-empty`, `comments-post-filled`, `comments-posting-warning` (primarily landscape) | Layout reserves bottom space for the software keyboard, which lives in a separate UIKit window omitted by single-window capture | **(a)** Capture without focus; **(b)** composite the keyboard window into the capture; **(c)** keep as-is (focused layout verified, system keyboard omitted) | not a defect (owner decision, 2026-11-22: keep as is; the system keyboard is a separate window) |
| B2 | `settings-login-filled`, `settings-login-error` | Password `SecureField` renders blank in `drawHierarchy` because iOS redacts secure text fields from window snapshots | **(a)** Accept system secure-field redaction as-is; **(b)** adjust scenario/fixture presentation if bullets must be shown | not a defect (owner decision, 2026-11-22: accept the system redaction of secure text) |

---

## C. App UI & Layout Findings Requiring Owner Decision

Per `19-CONTEXT.md` D-17, real UI defects are fixed in app code and their affected shards re-recorded before baseline approval rather than waved through. Each item below awaits owner disposition (fix now before baseline approval, or accept as designed/system behavior):

| ID | Scenarios / Coordinates | App UI / Layout Finding | Verdict |
| --- | --- | --- | --- |
| C1 | `quick-search-word-editor` (every locale, size, and device family) | `Search Terms` text field clips its text vertically in half | owner decision: fix and re-record (open) |
| C2 | `settings-pages-activity-logs-empty` (portrait; landscape shows inline title) | Empty Activity Logs page shows no navigation title in portrait | owner decision: fix and re-record (open) |
| C3 | `settings-login-error` (iPhone landscape; portrait at `large`) | Error toast overlaps the circular sign-in button and truncates its message to one line | owner decision: fix and re-record (open); the toast keeps clear of a tab bar on screens that have none |
| C4 | `agewall-*`, `analytics-choice-*` (iPhone landscape, iPad AX5); `report-form-*`; `detail-pages-archives` / `-insufficient-funds` | Floating bottom action bar / footer overlaps underlying scroll content (or shows text through translucent disabled button) | owner decision: capture every page at a fixed height that covers the whole page (open; applies to all pages) |
| C5 | `detail-pages-new-dawn` (`accessibility5`) | New Dawn greeting card clips its reward line, and a background ray crosses over text | owner decision: fix and re-record (open); the reward line is never cut, and the rays go in light and dark (the sun or moon stays) |
| C6 | `reader-settings-sheet`, `settings-pages-reading` (`de` and `ko` at `accessibility5`) | First row lacks top padding when its value wraps, clipping the label under the navigation title | owner decision: investigate and fix (open) |
| C7 | `detail-pages-folder-delete-confirmation`; `quick-search-delete-confirmation` | Delete Folder confirmation dialog is not anchored to the triggering folder row (`AGENTS.md` dialog placement rule); Quick Search delete confirmation changes anchor across orientations | owner decision: fix and re-record (open); anchor on the triggering row |
| C8 | `history-empty` (`accessibility5` landscape) | Empty-state symbol disappears in landscape at `accessibility5` | not a defect (owner decision, 2026-11-22: native behaviour; re-checked once pages are captured at full height) |
| C9 | `home-populated` | Front Page shelf stacks cards in a single narrow column, and stat labels hyphenate mid-word (e.g. `"Catego-ry"`) | owner decision: investigate and fix (open) |
| C10 | `shell-library-sidebar` (`accessibility5`) | Library sidebar column stays narrow at `accessibility5`, breaking words mid-word | not a defect (owner decision, 2026-11-22: native sidebar width) |
| C11 | `report-form-sent` (`accessibility5` landscape) | Sent confirmation message truncates to a single line | owner decision: fix and re-record (open) |
| C12 | `gallery-detail-*` (iPad portrait) | Horizontal stats strip clips at the trailing edge on iPad portrait (acceptable if horizontal scrolling is the intended affordance) | not a defect (owner decision, 2026-11-22: the strip scrolls) |
| C13 | `front-page-*`, `popular-*`, `toplists-*`, `watched-*` (`list` and `grid`, paired with `A11`) | Loaded gallery lists start with the automatic navigation-bar-drawer search/filter field collapsed, whereas loading/empty/error states show it expanded | not a defect (owner decision, 2026-11-22: native behaviour) |
| C14 | `settings-account-signed-out` | Empty cookie rows display `"None"` with the green `"Valid"` checkmark because `CookieValue.isInvalid` returns `false` for empty strings (also noted in Phase 16 `deferred-items.md`) | not a defect (owner decision, 2026-11-22: accepted as is) |
| C15 | `detail-pages-archives-insufficient-funds` | Insufficient funds are not visually indicated and the H@H download button remains enabled (`19-07-SUMMARY.md`) | owner decision 2026-11-25: accepted (first fix and re-record, 2026-11-22). The site pays a GP shortfall from Credits at an exchange rate the app does not know, so a GP-only gate would block downloads the site fulfils; the site decides and the app shows its response (`19-25-C15-PROPOSAL.md`) |
| C16 | `detail-pages-torrents` (`de`) | Torrent file sizes render with an English decimal point instead of localized decimal formatting in German | owner decision: fix and re-record (open) |

---

## D. System & Deliberate Behaviors (`not a defect`)

| ID | Scenarios / Coordinates | Observation & Rationale | Verdict |
| --- | --- | --- | --- |
| D1 | `search-clear-confirmation`, `settings-account-logout-confirmation`, `settings-pages-general-*-confirmation`, `settings-pages-site-settings-confirmation`, `gallery-detail-retry-confirmation` (`accessibility5`) | Native iOS confirmation popovers (`100–290 pt` wide) wrap per word and clip multi-line button labels at `accessibility5` | not a defect |
| D2 | `app-wide-app-alert`, `report-form-error-alert` (`accessibility5`) | Native `UIAlertController` scrolls internally when `accessibility5` text exceeds viewport height | not a defect |
| D3 | `toplists-period-menu`, `settings-pages-activity-logs-run-picker` | Native `UIMenu` checkmarks sit tight against labels at larger sizes | not a defect |
| D4 | `settings-pages-site-settings`, `settings-root`, `search-root-*` (`accessibility5`) | Inline picker layout and native iOS 27 `inlineLarge` root title sizing at `accessibility5` (`AGENTS.md` title policy) | not a defect |
| D5 | `report-form-filled`, `report-form-sending`, `report-form-sent`, `report-form-error-alert` (non-English locales) | Report `Details` prefill remains English by design (`ReportPrefill.swift`) because reports go to site moderators | not a defect |
| D6 | `reader-*` | Reader canvas background follows theme (`systemGray4` in light, `systemGray6` in dark) and comic page fills viewport in both themes | not a defect |
| D7 | `gallery-detail-*`, `front-page-*`, `popular-*`, `watched-*`, `favorites-*`, `downloads-*`, `history-*` | Long synthetic fixture titles truncate with `…` inside bounded card/row line limits | not a defect |
