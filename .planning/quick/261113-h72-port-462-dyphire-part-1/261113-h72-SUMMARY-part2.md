---
quick_id: 261113-h72
slug: port-462-dyphire-part-1
part: 2
status: complete
date: 2026-11-13
branch: port/462
---

# Port #462 (dyphire), part 2: summary

Same branch and rules as part 1. Not pushed, not merged, no rebase (develop has moved on by the CI commit
`629752f25`). Each port commit carries `Co-authored-by: dyphire <qimoge@gmail.com>`; the cache sizes of `b3a78e957`
are unchanged.

## Commits

| Commit | What |
|---|---|
| `46ff0b7e3` | search: tag suggestions in the saved search editor (#462 row 7) |
| `976030419` | lists, detail: favorite slot, the user's own rating and expunged galleries (rows 14, 15, 16) |
| `59981e742` | lists: leave rows that are not favorites structurally unchanged |
| `b85d15675` | detail: the Read button shows the page the reader resumes at (row 17) |

## Decisions and deviations from #462

- **Saved search editor.** `TagSuggestionView` has a source: `.searchField` (unchanged: text is tidied as it changes)
  or `.textEditor` (suggestions are read from the text as typed and never written back, so a marked CJK composition is
  not rewritten; the tidying runs on the typed text when a suggestion is chosen). Not checked on a device.
- **History snapshot (#462's stale one).** The favorite and rated state is not copied into `GalleryHistoryEntry`:
  no schema change and nothing to go stale. History rows therefore show no heart; they do show an expunged date, from
  the `gdata` API's `expunged` flag.
- **`favoriteTagIndex` on Detail.** Read from the favorite icon's sprite offset (-2 + 19 per slot), else the default
  name `Favorites N`, else the user's folder names. The offset rule is not confirmed against a live favorited page (no
  fixture has one); the name routes cover its absence.
- **Palette and index.** `Defaults.FavoriteColor.color(at:)` replaces `colors[index]`; EhSetting's favorite rows use it.
- **`Gallery` JSON.** Custom decoding: the four new keys default when absent (test with old JSON); wrong types still fail.
- **User rating colour.** Detail reads it from the page's star class (`irr`, `irg`, `irb`), not from #462's value
  thresholds (the repo's own detail test pairs a 2.5 rating with `irr`, so the thresholds looked unsafe). Lists use
  green for any rated row.
- **Read button (superseded).** The capsule labelled "P12" of `b85d15675` was replaced on the designer's decision
  by a progress ring inside the unchanged round button: 4pt in from the edge, 3pt round-capped stroke from 12 o'clock
  clockwise, white at 35% for the track and solid for the progress, resume page over page count (clamped; none for no
  saved page or an unknown count), 0.3s ease-out when the reader closes, none under Reduce Motion. VoiceOver keeps "Read"
  and takes `accessibility.read_progress` ("Page 12 of 156", copy final per the copywriter) as its value; `read_progress`
  is deleted.

## Tests

RED runs before the code: `/tmp/ehp462/p2red-final.xcresult` (24 failing, including the haptics crash of the stub run)
and `p2red8.xcresult` (6 failing runs for the Read button). Gate: `FeatureTests` without `VisualSnapshotTests`, last run
on the final tree: 1888 passed, 0 failed, 9 expected failures.

## Snapshot tests expected to change (baselines not re-recorded)

`settings-pages-site-settings` and `settings-pages-site-settings-confirmation` (the favorite dots take the slot colours).
No other scenario carries a favorite, rated or expunged gallery, a saved reading page or enabled tag suggestions, and the
rows that are not favorites keep their view tree, so they should not move.
