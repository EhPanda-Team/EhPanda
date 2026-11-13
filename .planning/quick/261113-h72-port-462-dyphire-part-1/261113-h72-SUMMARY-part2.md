---
quick_id: 261113-h72
slug: port-462-dyphire-part-1
part: 2
status: complete
date: 2026-11-13
branch: port/462
---

# Port #462 (dyphire), part 2: summary

Same branch and rules as part 1. Not pushed, not merged. The branch was rebased onto develop `4d98daab0` (which
includes the CI commit `629752f25`); the patches did not change, only their hashes (part 1 lists its old ones:
`5391e7596` is now `712941ade`, `e7abca7c7` `4b5a04b6c`, `b3a78e957` `de74c968a`, `303b1e9bc` `b57a1ac0b`, `ec703ff24`
`3e0db3fc7`). Each port commit carries `Co-authored-by: dyphire <qimoge@gmail.com>`. The cache sizes of `de74c968a`
were replaced by the owner's in `30fab27a3`.

## Commits

| Commit | What |
|---|---|
| `9b5234543` | search: tag suggestions in the saved search editor (#462 row 7) |
| `b1ceb1a29` | lists, detail: favorite slot, the user's own rating and expunged galleries (rows 14, 15, 16) |
| `65937a9d0` | lists: leave rows that are not favorites structurally unchanged |
| `b9175ef6c` | detail: the Read button shows the page the reader resumes at (row 17) |
| `30fab27a3` | cache: the owner's disk limits, 1 GiB reader cache, 512 MiB Kingfisher, 128 MiB SDWebImage |
| `2b0476faa` | detail: the Read button shows reading progress as a ring, not a capsule |
| `0f96f02fc` | test: the Reduce Motion inventory counts the Read button's ring |
| `30bcf9243` | detail: the Read button's ring grows once the reader has closed (the designer) |

## Decisions and deviations from #462

- **Saved search editor.** `TagSuggestionView` has a source: `.searchField` (unchanged: text is tidied as it changes)
  or `.textEditor` (suggestions are read from the text as typed and never written back, so a marked CJK composition is
  not rewritten; the tidying runs on the typed text when a suggestion is chosen). Checked on the iOS simulator, not on
  a physical device, with the Japanese Kana and Chinese Pinyin software keyboards (so the text goes through marked text),
  in the editor and in the main search bar, which shares `TagTranslationHandler`'s `~`/`-` prefix matching and
  `autoComplete`. While text is marked, no character is lost or doubled, the candidate bar works, and the suggestions
  neither commit nor replace the marked text (ねこ suggests ねこ and ねこみみ; Pinyin `mao` stays `mao` until a
  candidate is chosen). After a candidate is committed the suggestions follow it (猫 suggests 猫娘 and 猫男孩, 中文
  suggests `language:chinese`). Tapping a suggestion inserts the tidied tag in place of the keyword
  (`f:"cat girl$"`, `m:"cat boy$" l:chinese$`, `-f:"cat girl$"` with the prefix kept), also when tapped while the
  keyword is still marked, and typing goes on after it. No defect found, no change.
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
- **Read button (superseded).** The capsule labelled "P12" of `b9175ef6c` was replaced on the designer's decision
  by a progress ring inside the unchanged round button: 4pt in from the edge, 3pt round-capped stroke from 12 o'clock
  clockwise, white at 35% for the track and solid for the progress, resume page over page count (clamped; none for no
  saved page or an unknown count), 0.3s ease-out when the reader closes, none under Reduce Motion. VoiceOver keeps "Read"
  and takes `accessibility.read_progress` ("Page 12 of 156", copy final per the copywriter) as its value; `read_progress`
  is deleted.
- **Read button ring timing (the designer, `30bcf9243`).** The arc no longer animates while the reader's cover is
  still sliding away. `DetailView` marks the reader as on screen from its presentation until the cover's `onDismiss`;
  the header holds the ring at the length it was drawn at for that time and then lets it go with a 0.3s ease-out, so
  the growth starts from the length last drawn and is seen whole. A gallery that was never read shows no ring and the
  first close grows it from 0. Under Reduce Motion the arc takes the new length at once (a gated `withAnimation`;
  `ReduceMotionGatingSourceTests` now counts three). Checked on a screen recording of the stub-network run of gallery
  3103480 (156 pages): on the first read (to page 57) and on the resumed one (to page 128) the arc holds still while
  the cover closes and starts growing about 0.08s after the cover is gone, and reaches its length in about 0.3s.

## Tests

RED runs before the code: `/tmp/ehp462/p2red-final.xcresult` (24 failing, including the haptics crash of the stub run)
and `p2red8.xcresult` (6 failing runs for the Read button). Gate: `FeatureTests` without `VisualSnapshotTests`, last run
on the final tree (`30bcf9243`): 1904 passed, 0 failed, 9 expected failures.

## Snapshot tests expected to change (baselines not re-recorded)

`settings-pages-site-settings` and `settings-pages-site-settings-confirmation` (the favorite dots take the slot colours).
No other scenario carries a favorite, rated or expunged gallery, a saved reading page or enabled tag suggestions, and the
rows that are not favorites keep their view tree, so they should not move.
