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
- Not run: the iPad snapshot compares.

## Pointer pass over the fixes (2026-11-24, same simulator)

Each site was held under the pointer while the simulator recorded video, and the frames were compared with a frame
taken with the pointer off the device.

- **Switches:** the highlight is centred on the track, 6 pt clear of it on every side (General: Enhanced Tags, Open
  Links on Selected Site, Detect Links in Clipboard). The label scales with the Toggle while hovered, as accepted.
- **Gallery list rows:** one crisp copy of the text; the highlight stands 5 pt inside the row's sides.
- **Home:** both headings and both Show All links light 6 pt clear of their text; the ranking rows light with
  padding; the covers lift.
- **Detail:** the title, uploader, Download menu (glass circle), Read, Find Similar and tag chips light; the favourite
  menu and Rate stay flat while signed out (disabled); the Previews and Comments headings stay flat (no reload action,
  not hit-testable); the preview pages lift.
- **Search:** Remove All and Show All light 6 pt clear; the disabled Remove All stays flat; the recently viewed cards
  lift.
- **Library:** Manage Folders and Create Default Folder light as the same pill as the rows below them.
- **Laboratory** cell and the **reader**'s bottom Close (glass) draw a clean highlight in their shape.

Found and fixed: the lifted tiles were cut flat where they grew past their horizontal rows (Home's front-page covers,
Search's recently viewed cards, Detail's preview pages), losing their top corners and shadow. Those rows, and Home's
misc row, now carry `.scrollClipDisabled()` as the slideshow carousel already did (`2d4d3c64e`); each lift was
rechecked whole. A snapshot compare of the Home, Search, Gallery Detail and Detail Pages classes against the
candidate changed only the 25 list pictures already explained above.

Accepted as it is (owner, 2026-11-24): the reader toolbar's Live Text button. It keeps `.plain` so its symbol can
pulse, the toolbar then draws no pointer effect for it, and the icon helper's circle renders inside the toolbar's
glass as a lens that distorts the glyph. Without the helper the button had no hover at all; handing it to the
toolbar's own style gives the clean pill of Auto-Play beside it but stops the pulse. The pulse was kept, with the
lens.

Still unwalked: the Search keyword rows (no history on this simulator), the Library sidebar's collapsible headers
(left flat), signed-in-only controls, and the rest of the list in "Not yet walked" above.

## Full walk (owner: "Resume full walk", 2026-11-24, same simulator)

Every control reachable while signed out, swept under Device Hub's pointer with the video method above. To reach
lists that were empty, the walk made a saved search, a default downloads folder and one 22-page Non-H download, and
set Filters to Non-H while it picked that gallery.

Pass, one effect in the control's shape and nothing at rest moved:

- **Search:** a recent keyword row (6 pt clear of the row, the system's scale-up on top), its delete button (circle),
  both Remove All and Show All, the search field's clear button (the system's own).
- **Quick Search:** a saved search row (the card-row pill, 5 pt inside the card), the sheet's Cancel, New and Edit
  (toolbar items).
- **Filters:** the scope picker (the system's segment hover), the category tiles (rect), Reset Filters and the Minimum
  Rating picker (the card-row pill), every switch (centred on its track, 6 pt clear). The page range fields stay flat,
  as text fields do.
- **Library:** a downloads folder row and the favourites rows (the sidebar pill), the signed-out Log In button
  (bordered); Hide Sidebar, Layout and Filters (toolbar items). The collapsible section headers stay flat, as recorded.
- **Downloads:** a list row (the card-row pill: 5 pt inside the card's sides, 2 pt inside its top, inside its rounded
  corners) and a grid tile (lift, whole, in its 15 pt shape).
- **Detail:** the downloaded state's trash button (glass circle), Show All, the tag chips, the gallery info ellipsis
  (circle, at the end of the stats strip), the preview pages (lift; the one cut by the sheet's edge is cut by the
  sheet). The disabled favourite and Rate stay flat.
- **Torrents:** the file name (6 pt clear of the text). The row's other text is display only and stays flat.
- **Settings:** Account's rows and Copy Cookies, Appearance's Theme picker and App Icon, the switches on Appearance,
  Downloads and Reading, Reading's four pickers, About's link rows: the card-row pill or the switch track.
- **Reader:** the bottom Close (glass capsule) and, in landscape, the move-controls button (its 16 pt glass rect); the
  page zones stay flat.
- **Dark appearance** (Detail): the title, Download menu, Read, Find Similar and a tag chip light as in light;
  the disabled favourite stays flat.

Found:

1. **Comment moderation menu (`...`) draws nothing.** Its icon hover was on the Menu's label, which is where the
   audit allowance put it after an extra-small iPhone landscape snapshot moved; under the pointer the system draws no
   effect for a hover inside a Menu's label.
2. **The Log In button lights while disabled.** `.disabled(_:)` was written above the helper, which then reads the
   enabled environment from outside it (`fe327c0b2` added the helper in that order).
3. **Sliders draw nothing.** Hovered: Appearance's Privacy Mask and the reader's page slider. The others are the same
   system control (Downloads' simultaneous downloads, Reading's two zoom sliders, EhSetting's two). SL-11 lists
   sliders: flat, so E1 in the control's shape.

Not walked: Archives and every signed-in control (favourites, rating, posting and voting on comments, My Tags,
EhSetting, so SL-09's circles), the reader's page reload (only on a failed page), the accessibility-size analytics
menu (SL-10), a narrow iPad window (Device Hub cannot resize the simulator's window). Seen in passing, outside this
task: the saved search name field autocorrected "Touhou" to "Tohoku", and a second search submitted from a results
page's field left the earlier results on screen.

### Fixes after the full walk

- **Comment moderation menu.** The icon helper is on the Menu, after its plain style and before the negative padding,
  so the 44 pt circle follows the label's frame; the audit's allowance for that site is gone. Under the pointer the
  circle lights on every comment. It reaches 12 pt above and below the metadata line, as the button's hit area always
  has, so its bottom edge meets the top of the comment's first line.
- **Log In.** `.disabled(_:)` is written below the helper, so the disabled button stays flat. The enabled state needs
  a password typed in, which the walk does not do. The audit now fails any helper written below `.disabled(_:)` on
  the same chain (`noHoverHelperIsWrittenBelowItsControlsDisabled`, with scanner fixtures); the Log In button was the
  only one in the tree.
- **Sliders.** `SliderHoverShape`: the slider's frame grown by 6 pt, a capsule. On the Slider for the plain ones
  (Downloads, Reading, EhSetting, the reader's page slider); on the stack of the slider and its end marks on Appearance,
  where on the Slider alone the capsule ran into the two eyes. Checked under the pointer: Privacy Mask (the eyes and
  the slider inside, 8 pt clear of each eye), Downloads (10 pt under the label, 7 pt above the separator) and the
  reader's page slider (inside the glass bar, 2 to 3 pt from its top and bottom edges).

Verification: lint clean and the build has no warnings. A snapshot compare of the Comments, Tracer Comments,
Settings, Settings Pages, Settings Pages More and Reader classes against the same candidate, phone, en-xSmall,
en-large and en-accessibility5: 522 passed, 0 changed, 6 not applicable. The six comments pictures that moved when
plan 01 put this hover on the Menu did not move this time.

Commits: `216de8713` (comment menu), `7debceb51` (Log In and the audit), `dd99e281f` (sliders).

## Owner shape review (2026-11-24, same simulator)

The owner looked at four hovers and rejected their shapes:

1. **Remove All** ("i want capsule shape here"). Scope chosen: every single-line text button. `HoverTextCapsule`, a
   capsule 10 pt past the text at the sides and 6 pt above and below, now carries General's two, the analytics
   choice, the section titles and Show All, Search's Show All and Remove All, Rate and Find Similar, the torrent name,
   the tag detail link, the gallery info link and the uploader. `HoverTextButtonShape` stays on multi-line content:
   the search keyword rows and the Detail title.
2. **The Recently Viewed card** ("can't approve this shape"). It lifted in the cover's 5 pt shape. Spacing chosen: the
   cards keep their 8 pt spacing and the background reaches 3 pt past the card.
3. **The Downloads row** ("double corner radius"). The highlight's 10 pt corners sat about 5 pt inside the card's
   26 pt corners.
4. **The Home cover wall** ("they need background on hover"). The tiles lifted with no background.

Changes:

- **Gallery tiles.** `GalleryTileHoverShape(outset:)`: the system highlight, which draws a background, in the tile's
  rect grown by the outset, with corners of the cover's radius plus the outset, so the background's corner and the
  cover's stay concentric. 6 pt on the cover wall and the ranking rows, 3 pt on the Recently Viewed cards. The cover's
  5 pt radius is `GalleryCover.cornerRadius`, which the cover's clip shape and the tile shape share. Covers and
  previews that are only an image keep the lift, as do tiles with a background of their own.
- **Card rows.** 20 pt corners on all four sides, and the gap at the top and bottom raised from 3 to 6 pt, so after
  the system's scale-up the highlight stands about 5 pt inside the card on every side and its corners are concentric
  with the card's. On a one-line row it reads as a capsule, like a sidebar selection; the owner chose that over
  smaller corners next to the separators. `ConcentricRectangle`, which takes its radii from the cell's card, was tried
  first and dropped: on a section's second row (App Activity Logs, Import Custom Translations) the highlight it drew
  sat about 6 pt up and to the left, over the separator and the card's leading edge, whatever the pointer's position.
  A plain rounded rect on the same row sits in place.

Checked under the pointer: the cover wall tile (background, concentric corner), Search's Remove All and Show All, the
Recently Viewed card (3 pt background), App Activity Logs and Clear Image Cache in General (in place, about 5 pt
inside the card), the Downloads row, a Home ranking row, Find Similar, the uploader and the previews' Show All. Not
checked: the torrent name (needs a signed-in gallery with torrents).

Verification: lint clean and the build has no warnings. AppToolsTests and HomeFeatureTests pass, with new tests for
the text capsule, the tile shape and the 20 pt rows. A snapshot compare of the Home, Search, Gallery Detail, Detail
Pages, Detail Pages More, the three Settings, Downloads and First Launch classes against the same candidate, phone,
en-xSmall, en-large and en-accessibility5: 767 passed, 97 changed, 12 not applicable. Every one of the 97 (gallery
list rows in Downloads, search results and the detail search list, and one search suggestions picture) was already
changed in the 12:00 compare: the candidate predates `660d7652a`, which drew the list rows without a layer and so
moved the edges of their stars, page icon and category label. Rerun with the card rows' old 12 pt growth, the
Downloads pictures change the same way.

Commits: `ce2b4fac1` (text capsules), `6695a976b` (gallery tiles), `b1ba7d2dc` (card rows).
