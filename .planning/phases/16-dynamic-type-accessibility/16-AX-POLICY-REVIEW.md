# AX navigation/search policy and manual selection review

## Owner decision — 2026-09-08

The latest owner instruction supersedes the earlier no-fix decision for native search and the
temporary removal of title fallbacks. Use shared temporary workarounds on evidenced failing sites;
measure inlineLarge screens separately. Remove workarounds after supported OS versions pass without
them. Per the subsequent owner instruction, write the global contributor rule into `AGENTS.md`
only after inlineLarge measurement is complete; the premature addition has been removed.

## Implementation

- `AccessibilityNavigationTitleWorkaround`: automatic normally, inline at AX sizes; used on
  Frontpage, Popular, Watched, History, Toplists, Search results, App Activity Logs, and Archives.
  Archives has documented iPad title/content overlap (finding #36), rather than title disappearance.
- `AccessibilitySearchableWorkaround`: automatic drawer normally, always-visible drawer at AX;
  used on the seven search sites in finding #4 (the preceding list except Archives).
- Both modifiers preserve view identity and document the reproduction and removal criteria.
- The initial request measured manual selections first; the subsequently authorized native migration is recorded below.

## Separate inlineLarge measurement — 2026-09-09

sim-use screenshots and coordinate actions were used on iOS 26.5, portrait, light appearance.
The full accessibility tree still fails, but point queries and screenshot/action verification work.
The owner explicitly authorized continuing with sim-use after that failure.

| Site | iPhone 17e AX3 / AX5 | iPad Pro 11-inch AX5 |
| --- | --- | --- |
| Home | Title visible at both sizes | Selected top tab shows Home |
| Favorites | Title visible at both sizes; logged out | Selected top tab shows Favorites; logged out |
| Search root | Title visible at both sizes; empty state with existing blank-subtitle workaround | Selected top tab shows Search; populated history |
| Downloads | Title visible at both sizes; empty downloads | Selected top tab shows Downloads; empty downloads |
| Setting | inlineLarge tab title visible at both sizes | Separate large-title sheet; title visible after Large → AX5 |

The iPad tab presentation has no separate leading navigation title in the sampled roots.
Downloads has the same presentation at Large, so this is not evidence of AX-triggered disappearance.
The Settings sheet is not an inlineLarge measurement. iPhone Home and Setting include live AX3 →
AX5 changes; this is not exhaustive cold-entry/live-change coverage at every AX size or orientation.
Search's protected empty state does not prove removal of its existing workaround would succeed.

Evidence filenames on the external review page: `inline-{home,favorites,search,downloads,setting}-ax{3,5}.png`,
`ipad-inline-{home,favorites,search,downloads}-ax5.png`, `ipad-inline-downloads-large.png`,
`ipad-inline-setting-large.png`, and `ipad-inline-setting-ax5.png` (the last two are sheets).

Decision: preserve these designed inlineLarge modes. The global rule was written into `AGENTS.md`
only after these measurements, with explicit separate verification rather than an automatic fallback.

## Manual selection verification

| Site | Actual comparison | Result |
| --- | --- | --- |
| Reader Auto-Play | Prior iPad Large / AX5, Off unchanged | Tick disappears at AX5; independent native probe also reproduces |
| Favorites category | iPhone Large / AX5, All unchanged | Tick visible at Large, absent at AX5 |
| Toplists type | iPhone Large → AX5 with menu open, Yesterday unchanged | Tick disappears at AX5 |
| Downloads folder filter | iPad Large / AX5, All unchanged | Tick visible at Large, absent at AX5 |
| Favorites sort order | Isolated iPad build, seeded lastUpdateTime; Large → AX5 → Large | Tick disappears at AX5, returns at Large |
| Runs popup | iPhone AX5; previous iPad AX3 / AX5 | Native Picker tick visible |
| More Logs sheet | iPhone AX5; previous iPad AX5 | Manual Label tick in ordinary list remains visible |
| Reader dual-page / except cover | Actual iPhone landscape reader, both enabled; Large → AX5 → Large | Both ticks disappear at AX5 and return at Large; cover row inspected after scrolling |

Evidence: `favorites-category-{large,ax5}.png`, `toplists-menu-{large,ax5}.png`,
`ipad-folder-menu-{large,ax5}.png`, `favorites-sort-large.png`, `policy-runs-ax5.png`,
`policy-more-logs-ax5.png`; prior Auto-Play evidence remains available.
Selection values stayed unchanged between text-size comparisons. Reader controls were temporarily enabled
to establish selected-state baselines and restored afterward. No menu implementation was changed.

## Policy verification

Both policy builds and changed-file SwiftLint passed. The latest built app was installed on both
review devices without clearing their data. iPhone root measurements preceded that installation;
root title implementations were unchanged by the policy build.

On the policy build, iPhone Toplists Large → AX5 retains its inline title and renders the full-height
Filter drawer with its prompt. Entering `axcheck` filters to an empty list; clearing restores items,
and cancel exits focus. The query was cleared. Native focus layout still enlarges the cancel icon
and initially overlaps the magnifier/prompt; the workaround is scoped to the blank drawer failure,
not a claim of perfect native AX focus layout. App Activity Logs Large → AX5 likewise retains its
title and Search prompt. Returning to Large restores its native large-title layout.

Evidence: `policy-toplists-ax5.png`, `policy-toplists-search-focus-ax5.png`,
`policy-logs-large.png`, `policy-logs-ax5.png`, `policy-logs-restored-large.png`.
This is a targeted verification, not a completed all-screen/all-device phase acceptance matrix.
The other policy call sites retain their previous failure evidence and passed build/lint;
fresh full visual coverage of the navigation/search policy remains open. The manual menu inventory
is now measured as described below.

Both review devices were returned to Large text size. No app data was deleted and no selection
or playback setting remains changed. Phase 16 review remains open.

## Completion of manual menu measurements — 2026-09-09

The owner requested finishing the remaining selection measurements. The three outstanding controls
now have direct rendering evidence. This closes the listed manual-menu investigation; it does not
claim exhaustive OS/device/AX-size acceptance or verification of a future native-control migration.

### Favorites sort order

The logged-out production screen has nil selection because `FavoritesReducer` assigns the order
from a successful server response. An isolated app build (`app.ehpanda.pickermeasurement`) seeded
only `FavoritesReducer.State.sortOrder = .lastUpdateTime`; the actual FavoritesView and SortOrderMenu
rendering implementations were unchanged. This avoids needing an authenticated account and does not
exercise server sorting. The measurement copy omitted its unrelated share extension to use an
independent application ID. The production app installation and data were preserved.

On iPad Pro 11-inch (M5), iOS 26.5, portrait/light: By last gallery update time has a tick at Large,
loses it at AX5, and regains it when returning to Large. No sort action was triggered.
Evidence: `picker-sort-seeded-large.png`, `picker-sort-seeded-ax5.png`,
`picker-sort-restored-large.png`.

The temporary seed was restored byte-for-byte before rebuilding the ordinary app. Both measurement
and restored production builds succeeded. The fixture is not a production code change.

### Reader dual-page and except cover

On the unmodified reader controls in the installed policy build, iPhone 17e, iOS 26.5,
landscape/light: temporarily changed reading direction from Vertical to Right-to-left, enabled
Dual-Page Mode and Except the Cover, and captured both ticks at Large. After switching to AX5,
reopened the menu (the toolbar size change dismissed it). Dual-Page Mode has no tick. Scrolling
within the menu brings the entire Except the Cover row into view; its tick is also absent.
Returning to Large and reopening restores both ticks, demonstrating the selections remained set.

Evidence: `picker-dual-cover-large.png`, `picker-dual-cover-ax5.png`,
`picker-cover-scrolled-ax5.png`, `picker-dual-cover-restored-large.png`.
Raw screenshots retain the simulator's portrait pixel orientation; the review page rotates their
presentation with CSS only, without changing screenshot pixels.

The earlier orientation blocker is resolved: Simulator's Device > Rotate Left/Right sets device
orientation, while all app interactions and screenshots remain through sim-use. Both booleans were
returned to false, reading direction to Vertical, device orientation to portrait, and text size to
Large. Auto-Play was not changed. iPad also returned to Large with Settings foreground.

### Result and control semantics

Every inventoried manual popup selection site now has evidence of an AX5 missing tick: Auto-Play,
Favorites category, Favorites sort, Toplists type, Downloads folder filter, and both reader booleans.
The native Runs Picker and the ordinary More Logs list retain ticks in their sampled AX states.
Single-choice sites suit Picker semantics; dual-page and except-cover are independent booleans and
suit Toggle semantics, retaining the existing except-cover disabled condition. No conversion was
implemented in this measurement task.


## Authorized native selection migration — 2026-09-09

After reviewing the completed measurements, the owner authorized the proposed migration.

- Favorites category, Favorites sorting, Toplists type, Downloads folder filtering, and Reader
  Auto-Play now use inline native Pickers inside their existing Menus.
- Reader dual-page and except-cover now use native Toggles. Except-cover remains disabled when
  dual-page is off. Runs and More Logs remain unchanged.
- Favorites and Toplists change guards moved from view closures into reducer actions. Sorting
  sends a request without optimistically changing the server-confirmed selection.
- DownloadFolderFilter now conforms to Hashable for native Picker tags.

### Verification

sim-use on iOS 26.5, light appearance:

| Site | Device / state | Result |
| --- | --- | --- |
| Favorites category | iPhone 17e, AX5 | All tick visible; selecting category 0 moves the tick; restored All |
| Downloads folder | iPhone 17e, AX5, empty downloads | All tick visible; Manage Folders action retained |
| Toplists type | iPhone 17e, AX5 | Yesterday tick visible |
| Favorites sort | iPad Pro 11-inch, AX5, isolated seeded selection | Last-update tick visible |
| Auto-Play | iPad Pro 11-inch, Large and AX5 | Off tick visible; playback advances pages and stops after Off |
| Dual-page | iPhone 17e, landscape, AX5 | Enabled tick visible |
| Except cover | Same reader, scrolled to entire row | Enabled tick visible; disabling dual-page retains disabled condition |

The independent measurement app used the actual changed components. Its only temporary source
changes were a default Favorites sort selection and a print in AutoPlayHandler.setPolicy.
Selecting 5 seconds, then selecting 5 seconds again, produced two writes about 1.92 seconds apart;
the unchanged handler invalidates and recreates the timer on each write. Native Picker therefore
preserves reselect-to-restart behavior on the measured OS. Off then produced raw value -1.
These fixture edits were restored byte-for-byte and the ordinary application rebuilt successfully;
no fixture code remains in the repository.

`xcodebuild test`, EhPanda scheme, FavoritesFeatureTests on the iPad simulator: all 4 tests passed.
The new SortSelectionTests covers selection during an in-flight load, a failed response retaining
the confirmed order, and nil/same-order selections producing no retry. It does not exercise live
authenticated server sorting. The isolated visual fixture likewise proves rendering only.
All 18 changed/new Swift files passed SwiftLint. Ordinary and isolated builds succeeded.

Evidence on the external review page, section `native-pickers`:
`native-category-ax5.png`, `native-category-changed-ax5.png`, `native-folder-ax5.png`,
`native-toplists-ax5.png`, `native-sort-ax5.png`, `native-autoplay-ax5.png`,
`native-dual-cover-ax5.png`, `native-cover-scrolled-ax5.png`, `native-dual-disabled.png`.

These targeted checks close the measured missing-checkmark migration. Phase 16's remaining broad
accessibility acceptance work stays open.

Cleanup for this migration: both devices returned to Large; both reader booleans returned to false,
iPhone reading direction returned to Vertical, and Auto-Play returned to Off. Reader page positions
returned to 1. iPad returned to Settings. The iPhone simulator remained landscape because its
native Rotate Right menu became disabled during cleanup; this does not affect the completed
landscape control measurements. No app data was removed.
