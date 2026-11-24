# Quick task 261123-355: iPad pointer pass (2026-11-24)

The first look at the hover effects under a real pointer (section 11 of `261123-355-SUMMARY.md`). It is partial: the
groups below were walked, the rest are listed as not yet walked. The fixes the owner asked for afterwards ("fix known
issues first") are in the last section.

## Method

- Xcode 27.2 has no Simulator app; its Device Hub forwards the Mac pointer to an iPad simulator as hover with no
  setting to turn on. The device was an iPad Pro 11-inch (M5) simulator on iOS 27.2, portrait, light, large text,
  running the branch rebased onto develop, signed out, against the live site.
- `XCUIElement.hover()` draws no hover effect in the simulator (a reference project measured an empty pixel diff, and
  plan 05 test 1 here saw the same), so the pointer was moved by hand over Device Hub's window.
- Each control was held under the pointer for about 4 s while `simctl io screenshot` captured a frame a second. Every
  frame was compared with a frame taken with the pointer off the device: the changed region's bounds, in points, show
  whether the control drew an effect, its extent, and whether anything else moved. Home's slideshow card animates by
  itself, so changes in its region were read from the pictures, not counted as hover.
- Evidence pictures (non-explicit crops only) are in `.capture/261123-355/pointer-pass/` (gitignored).

## What draws a hover and what does not

The system draws a pointer effect for toolbar items (Detail's More, the gallery list's Layout, Library's Hide Sidebar),
the tab bar's tabs, and every control that carries this task's helpers. It draws none for any of these, each held
under the pointer with no changed pixel:

- Default-styled and `.borderless` Buttons outside a List: Home's slideshow card, Front Page cover tiles, Toplists
  rows, the section header's Show All; Detail's title and uploader, Find Similar, a tag chip, the Previews heading and
  a preview page (SL-07, SL-08).
- Interactive glass outside a toolbar: Detail's Download menu (SL-04).
- `Link`: the analytics screen's Privacy Policy (SL-11).
- A sidebar List's `.sectionActions` rows: Library's Manage Folders and Create Default Folder (SL-08).
- A collapsible `Section(isExpanded:)` header in the sidebar: Library's Downloads and Favorites headers.

So the system-left register (section 8) does not hold on iOS 27.2: SL-04, SL-07, SL-08 and SL-11 are flat, and each
needs its register follow-up. SL-01, SL-02, SL-03, SL-05, SL-06, SL-09 and SL-10 were not walked.

## Helper sites that pass

One effect each, in the control's visible shape, and nothing at rest moved. The system's highlight scales the hovered
content up by about 1 to 3 pt and greys a white fill; that is the system's own drawing, not a layout change.

- First launch: the checkbox card and the three choice cards (rect 15), Continue (capsule).
- Detail: Read (circle).
- Settings root rows (rect 10, about 12 pt inside the sheet's sides).
- A Form row with `cellRowHover` (General > App Activity Logs, Import Custom Translations, Clear Image Cache): about
  5 pt inside the card's sides and 4 pt above its bottom.
- General's language button.
- Library sidebar rows (`cellRowHover(.sidebarSelection)`): the system's selection pill.

## Defects found

1. **Switch rows move under the pointer (rule W).** `AppToggle` puts the hover on the whole Toggle, so the system's
   highlight scales the label with the switch: on General > Open Links on Selected Site the label moves left by about
   1 pt while the track is hovered. On that row the capsule's trailing end is also cut flat where it reaches past the
   row's bounds.
2. **The switch track is 63 pt, not 61.** Measured on General > Enhanced Tags: the track spans from 61 pt before the
   Toggle's trailing edge to about 2 pt past it, so `SwitchTrackHoverShape` (61 pt ending at the edge) is centred 1 pt
   leading of the track and the highlight clears it by 6 pt on the leading side and 4.5 pt on the trailing side.
3. **Gallery list rows draw their content twice.** On the Front Page list, a hovered row shows every line of text
   twice, about 1 pt apart, in a steady frame (not an animation step). Settings rows with the same helper do not. The
   row is a default Button with a context menu and the read-tap interaction; which effect stacks on the helper's is
   not established.

## Not yet walked

Search, Downloads, Filters and Quick Search, the Report Form, the reader (SL-01, the Live Text circle, page zones),
Comments, Archives (SL-03), Laboratory (SL-02), About, Login (SL-06), the state views, the toasts, the EhSetting page
(SL-09, the exclusion circles), the accessibility-size analytics menu (SL-10), a narrow iPad window, landscape, and
dark appearance.

## Fixes (owner: "fix known issues first", 2026-11-24)

The full walk was paused for these. Each flat group takes the follow-up its register entry named (section 8 of the
summary), applied to its whole class: on iPadOS 27.2 the system draws a pointer effect only for toolbar items and tab
bar tabs, so the interactive-glass entries that were not walked (SL-01, SL-02, SL-03, SL-05, SL-06) take theirs too.
`hoverShape` had no caller left and is removed; the `interactiveHover` documentation now says which controls draw
their own effect.

- **Switches (defects 1 and 2).** The owner's choice: mirror the reference project, whose toggle style puts the
  highlight on the whole Toggle. A style that put it on a labels-hidden switch alone kept the label still, but it
  rebuilt the Form's switch row, and labelled switch rows grew from 52 to 58 pt at rest. `SwitchTrackHoverShape` now
  follows the drawn track measured from the pixels: 63 x 28 pt, from 61 pt before the Toggle's trailing edge to 2 pt
  past it. The label still moves by about 1 pt while the track is hovered (accepted).
- **Gallery list rows (defect 3).** The detail cell's text column was drawn through `.drawingGroup()`, and the
  highlight drew that layer twice. The modifier is removed (no recorded reason; the Detail stats strip lost its own in
  Phase 17 and the comment strip in Phase 18).
- **SL-04** Detail header glass: the download progress, download menu and idle download buttons and the favourite pair
  take E1 circle. Only the visible one of the favourite pair lights.
- **SL-07** cards and tiles take E2 lift in their shape (Home slideshow card, covers, destination cards, misc grid
  items, cover wall; Search history cards; Detail preview strip; Previews thumbnails; Hath archive cards; gallery and
  Downloads grid tiles). Detail tag chips take E1 rect 5.
- **SL-08** plain-rectangle buttons: Home ranking rows, Search keyword rows, SubSection title and Show All, Search
  Show All and Remove All, Rate and Find Similar, Tag Detail links, and the Detail title and uploader take E1 in
  `HoverTextButtonShape`, so the highlight stands 6 pt clear of the content instead of ending at the glyphs (the plan
  04 list named `.rect` for some of these). The keyword delete button, the gallery-info ellipsis and the reader's
  page reload take `interactiveIconHover()`. Library's section actions render as sidebar rows, so they take the rows'
  `cellRowHover(rowFill)` (plan 05 named a capsule around the label). The grid's fetch-more footer takes E1 rect 15,
  in line with the tiles; its whole row is now the retry control, as it already was in the List.
- **SL-11** the analytics screen's Privacy Policy `Link` takes E1 in `HoverTextButtonShape`.
- **SL-01, 02, 03, 05, 06** glass outside a toolbar: the reader's move-controls (rect 16) and Close (capsule), the
  Laboratory cells (rect 15), the Archives download banner (capsule, in `DownloadBannerStyle`), Post Comment (its
  15 pt shape) and the Login chevron (circle) take E1. The audit's three allowances for these sites are removed.
- **Audit allowance after the rebase.** `GalleryReadInteraction` now has one `TapGesture` and one
  `SpatialTapGesture` (develop changed the single tap), so its allowance is two entries of one each.

Not changed: the Library sidebar's collapsible section headers (no register entry; the chevron is the system's) and
SL-09 and SL-10, which were not walked.

Commits: `fea7a2caf` (audit allowance), `660d7652a` (gallery row), `14cf75f4d` (switch track), `fe327c0b2` (the
flat controls).

Verification:

- Lint clean, and the builds have no warnings. The FeatureTests plan without `VisualSnapshotTests` passed on the
  final tree (3626 passing test cases); `14cf75f4d` builds and passes AppToolsTests on its own.
- Snapshots at rest, phone, en-xSmall, en-large and en-accessibility5, 22 classes, against a candidate recorded from
  `199e83dd8` on a new iOS 27.2 iPhone Air (the earlier candidate came from iOS 27.0 simulators that no longer
  exist): 1385 passed, 241 changed, 30 not applicable. The 240 gallery-list pictures (20 scenarios at all 12 sizes,
  orientations and appearances) differ only in the antialiasing of the row's SF Symbols (rating stars, page count) and
  the category label's edges, at most 44 of 255 per channel; text and layout are identical. That is the removed
  `.drawingGroup()`, the same sub-pixel effect Phase 17 recorded for the stats strip. The 241st,
  `search-typing-suggestions` at accessibility5 in landscape and light, changed again in a rerun of the Search
  class: a 2 px band at the search field's shadow, which samples the results list underneath, at most 20 of 255.
  The published baselines of these list scenarios move with this change.
- Not run: the iPad snapshot compares, and the pointer pass over the fixed sites (the owner declined full-screen
  control for now).
