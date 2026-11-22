# Quick 261122-fv8: port #462 item (10), My Tags page and watched-tag highlight

Contributions row item (10) in `.planning/STATE.md`. Branch `port/462` (tip `d3dd40af1` when this task started);
commits go on top, nothing on the branch is rewritten. Nothing is pushed. `.capture/merge-prep/pr-462-comment.md`
belongs to the orchestrating session: never touch it.

Four features:

1. **My Tags page**: a native page mirroring the site's My Tags (`/mytags`): the tag sets, the tags in a set; add a
   tag; edit a tag's watched/hidden state, colour and weight; remove a tag.
2. **Highlight**: tags in My Tags stand out wherever tags are shown, in the colour the site gives them.
3. **"Add This Tag to…"** in a tag's context menu.
4. **"Remove from My Tags"** in a tag's context menu.

dyphire's reference is commit `7ddbf3b23` on local branch `pr-462` (`Request+MyTags.swift`, `Parser+MyTags.swift`,
`WatchedTag.swift`, `WatchedTagsSetting.swift`): background only. Its global actor cache, its view-side recolouring
and its fixed tagset 1 are not taken. The site contract below, read live on 2026-11-22, replaces it.

## Two stages (orchestrator; superseded 2026-11-22, see "Design (approved 2026-11-22)")

A separate design session is designing the My Tags page and the highlight; the owner reviews it there. Stage 1 (this
plan) builds everything that does not depend on the design: models, persistence, requests and parser with
fixtures and tests, the reducers, the context menus and the add/edit/remove round trips, with **plain native
placeholder UI** for the page and the highlight and no visual design choices of its own. Stage 1 ends at a
checkpoint. Stage 2 (a later plan) applies the approved design: placement, highlight treatment, states, copy.

## Owner decisions (2026-11-22, locked)

- **D-01 Highlight scope waits for the design.** Whether only Watched tags or every tag in My Tags is highlighted
  (the site colours every tag of an enabled tag set, watched, flagged only or hidden) is decided with the visual
  design. The model therefore keeps each tag's watched/hidden state and its resolved colour, so either scope is a
  filter, not a model change. The stage 1 placeholder follows the site's rule.
- **D-02 Add menu.** A tag's context menu has a submenu "Add This Tag to…" whose items are My Tags, Watched Tags and
  Hidden Tags (flagged only, watched, hidden); each opens a further submenu listing the account's tag sets, and the
  chosen set receives the tag. The working English labels are "Add This Tag to…" and "Remove from My Tags"; the two
  must read at about the same length (owner, 2026-11-22). Each locale writes its own native labels with the same
  balance.
- **D-03 Remove is one item.** "Remove from My Tags" has no submenu.
- **D-04 Live test approved.** The owner allowed adding a test tag to the account and removing it again to learn the
  site's replies (done 2026-11-22, findings below; the account is back to its previous tags).

## Orchestrator decisions (to report to the owner afterwards)

- A tag in no tag set shows "Add This Tag to…"; a tag in any tag set shows "Remove from My Tags", which removes it
  from every set that holds it. Both appear only when signed in and only once My Tags has been loaded.
- My Tags is cached as one optional field on the persisted `User` (`@Shared(.user)`), so it needs no schema migration
  and is cleared with the user on logout. It is fetched with the favorite categories (at launch when signed in and
  after login), when the My Tags page opens, and replaced by the page the site returns after each add or remove; an
  edit updates the cached tag in place after the API accepts it.
- The API key comes from the fetched `/mytags` page and stays in feature state; it is never persisted. (Detail
  already holds the gallery page's own key.)
- All site calls go through one injected client (`MyTagsClient`, in the style of `GalleryClient`), so reducers state
  each outcome in tests.
- Requests use the selected host (`setting.galleryHost`); both hosts share one My Tags.
- The Account screen's My Tags row opens the native page instead of the web view. Native requests go through the
  domain-fronting protocol, so the row no longer hides when "bypass SNI filtering" is on.
- Lists keep the colours the site already writes into list pages (compact, extended and thumbnail modes); stage 1
  adds the cached colours to Detail's tag section, which the site does not colour.
- Tag set management (create, rename, delete, enable, set colour) is out of scope; the page shows the sets and their
  enabled flag and colour read-only.
- Fixtures are synthetic: they keep the site's markup but carry no account data (no real `apiuid`, `apikey` or the
  owner's tags).

## Site contract (read live 2026-11-22, both hosts, signed in)

E-Hentai `https://e-hentai.org/mytags` and ExHentai `https://exhentai.org/mytags` serve the same markup and the same
tags (one account-wide My Tags). Differences: the page's `api_url` (`https://api.e-hentai.org/api.php` and
`https://s.exhentai.org/api.php`; the app's `Defaults.URL.api(host:)` = `<host>/api.php` was confirmed to work for
`setusertag` on ExHentai), the stylesheet, and the server-rendered preview gradient (E-Hentai darkens the border by
32 per channel, ExHentai draws it flat). The gallery page (`/g/…`) carries **no** My Tags colour (every `#taglist`
div is `style="opacity:1.0"`), so Detail needs the cached My Tags; list pages do carry it
(`style="color:#f1f1f1;border-color:#…;background:radial-gradient(#…,#…) !important"`), also for tags that are only
flagged, not watched. The gallery page's own tag menu has no My Tags actions. The gallery page's
`toggle_tagmenu(<tagid>, '<ns>:<tag>', …)` uses the same tag id as `/mytags`.

### Page

- Inline script in `#outer`: `var api_url = "…"; var apiuid = <int>; var apikey = "<hex>"; var tagset_color = "";
  var tagset_name = "Tagset #1"; var baseurl = "<host>/mytags"; var default_color = "000000";`
- `form#tagset_form` > `#tagset_outer`: `<select onchange="change_tagset(this.value)">` with
  `<option value="1" selected="selected">Tagset #1 (36)</option>` (name, then the tag count in parentheses; the
  selected option is the shown set); `input#tagset_enable` (`checked="checked"` when enabled); `input#tagcolor`
  `name="tagset_color"` (`value=""` or `#RRGGBB`). Other sets: `GET /mytags?tagset=<n>` (`change_tagset` omits the
  query for 1).
- `form#usertag_form` > `#usertags_outer`: `div#usertag_0` is the add row (inputs `tagname_new`, `tagwatch_new`,
  `taghide_new`, `tagcolor_new`, `tagweight_new` default `10`). Every other `div#usertag_<tagid>` is one tag:
  `div#tagpreview_<id>` with `title="<namespace>:<tag>"` (the full name; its text may abbreviate the namespace, e.g.
  `f:…`), `input#tagwatch_<id>` and `input#taghide_<id>` (`checked="checked"` when set; the `onchange` text contains
  `checked=false`, so test the attribute, not a substring), `input#tagcolor_<id>` `value=""` or `#RRGGBB`,
  `input#tagweight_<id>` `value="<int>"`, and `input[name="modify_usertags[]"][value="<id>"]`.
- `#usertags_mass`: `select#usertag_target name="usertag_target"` (`0` = Delete Selected; other values move to that
  set).
- Errors on a form POST: status 200, no redirect, `<div id="msg"><p>No matching tag found</p></div>` (unknown tag) or
  `<p>No tag was specified</p>` (empty) at the top of `#outer`.

### Colour rule (`update_tagpreview` in `ehg_mytags.c.js`)

Colour = the tag's colour, else the set's colour, else `3377FF` when not hidden and weight >= 0, else `FF6666`.
Text = `090909` when `0.299 R + 0.587 G + 0.114 B > 151`, else `f1f1f1`. Watched and Hidden are mutually exclusive in
the page's UI (checking one clears the other). Only tags of an enabled set are flagged.

### Writes

- **Add**: form POST to `/mytags` (`?tagset=<n>` for sets other than 1) with `usertag_action=add`,
  `tagname_new=<ns:tag>`, `tagwatch_new=on` (watched) or `taghide_new=on` (hidden) or neither (flagged), `tagcolor_new`
  (`""` or `#RRGGBB`), `tagweight_new=10`, `usertag_target=0`. Success: redirect to the page, which now lists the tag.
  A tag already present is accepted silently (redirect, unchanged). An unknown tag returns the `#msg` error.
- **Edit**: JSON POST to the API: `{"method":"setusertag","apiuid":<int>,"apikey":"<hex>","tagid":<int>,
  "tagwatch":0|1,"taghide":0|1,"tagcolor":""|"#RRGGBB","tagweight":"<int>"}`. Success `{"tagid":<id>}`. Errors
  `{"error":"The provided color code is invalid","tagid":…}`, `{"error":"Weight must be between 99 and -99",…}`. An
  unknown tag id answers `{"tagid":<id>}` with no change, so success is not proof the tag exists.
- **Remove**: form POST to `/mytags` (`?tagset=<n>`) with `usertag_action=mass`, `modify_usertags[]=<id>` (repeatable),
  `usertag_target=0`. Success: redirect to the page without the tag.

## Rules

- Follow `AGENTS.md` / `CLAUDE.md`: `Feature`-suffixed new reducers, SwiftLint without suppressions, labeled numeric
  format arguments, scroll-edge policy (the new page carries `.scrollEdgeEffectStyle(.soft, for: .top)`), dialog
  placement, parallel tests; new modules get their own `.swiftlint.yml`.
- New strings written natively in all six locales (en, de, ja, ko, zh-Hans, zh-Hant = Taiwan usage). English terms
  follow the site (Watched, Hidden, Weight, Tagset/tag set as the site writes them).
- One atomic commit per task, `TZ=Asia/Shanghai`, signed, author and committer dates at +08:00, message <= 50
  characters, body `Co-authored-by: dyphire <qimoge@gmail.com>`.
- One `xcodebuild test` at a time on the machine (check `pgrep -x xcodebuild` / `pgrep -x xctest` first).
- 0 warnings, lint clean, the FeatureTests plan with `-skip-testing:VisualSnapshotTests` passes.

## Design (approved 2026-11-22)

The owner approved the design session's My Tags design on 2026-11-22, so the work is one stage: "Two stages" above,
the placeholder UI and the stage checkpoint no longer apply. The decisions below supersede the ones they name;
everything else above stands (the site contract, the client, the requests, synthetic fixtures, the cache on `User`,
credentials in feature state only, the rules).

- **D-05 Context menu (supersedes D-02, D-03 and the orchestrator's "removes it from every set").** After the shipped
  items, a divider and one item, signed in only. "Add to My Tags" (`tag`), for a tag not in the selected tag set,
  presents the Add Tag sheet with the tag filled in and read-only, state Watched, adding to the set last chosen on My
  Tags (the site's first set before that); then the toast "Added to My Tags". "Remove from My Tags" (`tag.slash`,
  destructive), for a tag in that set, removes it at once; then the toast "Removed from My Tags". The accessibility
  actions offer the same. The set last chosen is persisted with the cache. Errors go to the app alert, titled
  `my_tags.save_failed` / `my_tags.remove_failed`.
- **D-06 Highlight (resolves D-01; supersedes the stage 1 colour rule and "Lists keep the colours").** Every tag in
  an enabled tag set, across all sets. The tag chip keeps its colours and gains a Bold symbol inside the label's text:
  `eye` watched, `eye.slash` hidden, `tag` otherwise, in the tag's colour, else the set's colour, else the label's
  colour (no 3377FF/FF6666 fallback). VoiceOver reads the state after the label (`my_tags.state.*`); the symbol is
  hidden from it. It applies on Detail and in every list and grid cell. Lists no longer fill a tag with the site's
  colour; the colour a list page gives a tag stands in, drawn as `tag`, only until the cache has loaded.
- **D-07 Cache (extends the orchestrator's cache decision).** Every set's name, enabled flag and colour, and every
  tag, read from every set's page. Read on launch when signed in, after login, after any My Tags change, and when the
  gallery host changes.
- **D-08 Page (supersedes "Tag set management ... read-only").** A Form. Section 1: Tag Set (a menu picker; switching
  sets shows the loading view until the tags arrive), Enabled (a toggle), Default Color (a hex field, 7.5 em wide,
  trailing, plus a ColorPicker without opacity), footer `my_tags.tag_set_footer`. Enabled and the colour are editable
  and sent at once; a failure reverts and shows the alert. The update is a form POST to `/mytags[?tagset=n]` with
  `tagset_action=update`, `tagset_name=` (empty), `tagset_enable=on` (omitted when off) and `tagset_color` (empty or
  `#RRGGBB`). Creating, renaming and deleting sets stay out of scope. Section 2 "Tags": a row per tag with a chevron;
  a tap opens Edit Tag; a full trailing swipe removes (trash). Pull to refresh; reload after sign-in. Toolbar: plus
  (Add Tag), disabled while loading, signed out or failed. Empty: the set section stays, plus "No Tags Yet" with an
  Add Tag button. Signed out: NotLoginView. Failed: ErrorView with a second button "Open in Browser" above Retry,
  opening `/mytags` in the app's web view sheet; closing it reloads. On iPad the page pushes inside the Settings
  sheet.
- **D-09 Account row (supersedes the orchestrator's "no longer hides when bypass SNI filtering is on").** The row
  pushes the native page and stays hidden while Bypass SNI Filtering is on.
- **D-10 Editor (Add Tag / Edit Tag sheet).** Close (xmark) leading; confirm (checkmark) trailing, a spinner while it
  runs; on failure the sheet stays open with the alert. Add's confirm is disabled until a tag is entered; Edit's until
  something changed. Section 1: a segmented Normal / Watched / Hidden picker (labels hidden, accessibility label
  State; new tags default to Watched), then the Tag row (Add: a text field, prompt `namespace:tag`, no autocorrection
  or capitalization, submit confirms, tag suggestions while the search-suggestions setting is on; Edit: read-only),
  footer `state_footer`. Colour: the hex field and the ColorPicker in sync; six hex digits with or without `#`,
  upper-cased on submit, reverted if invalid; the prompt is the colour in use; "Use Default Color" only while the tag
  has its own colour; footer `color_footer.own` / `.tag_set` / `.none`. Weight: the value and a Stepper over
  -99...99; the footer names the host. Edit only: a destructive "Remove from My Tags" row, which removes the tag,
  closes the sheet and shows the toast.
- **D-11 Copy.** The design's strings sheet (21-my-tags.md) verbatim in all six locales; keys that are not
  translated carry every locale; `open_in_browser` is shared; `my_tags`, `tags`, Retry and Log In are reused; every
  `%@` argument is a string.
- **D-12 Scroll edge and snapshots.** Every new root carries `.scrollEdgeEffectStyle(.soft, for: .top)` and
  SCROLL-EDGE-INVENTORY.md is updated; dialogs and alerts follow the AGENTS.md placement rule. The VisualSnapshot
  scenarios whose rendering changes are listed, not re-recorded.
