# Comment parser

Owner request (2026-11-02): comments showed `&gt;` and `<strong>` literally. The two reported comments are comment
8120807 in gallery 4290276 and comment 0 in gallery 3845660, both saved in the fixture repository.

## Root cause

`parseCommentContent` used the comment's serialized `innerHTML` as its text. It replaced `<br>` and `</span>` by hand
and found links by searching for their serialized form. Every other tag therefore stayed in the text, and so did
libxml's re-escaping of `<`, `>` and `&`. `&#039;` and `&quot;` looked correct only because the serializer writes those
back as plain characters, which is why just some entities were wrong.

No replacing could have fixed this, since serialized markup cannot be told apart from text the author typed. The owner
accepted a refactor if the design was the cause, so the function was replaced (`1ef14ca1e`).

## Change

The parser now walks the comment's DOM and takes text from its text nodes. It no longer alters the document.

| Comment body | Before | After |
| --- | --- | --- |
| `&gt; quote` | `&gt; quote` | `> quote` |
| `<strong>word</strong>`, `<em>word</em>` | Tags shown | `word` |
| `&lt;strong&gt;`, which the author typed | `&lt;strong&gt;` | `<strong>` |
| `<span>word</span>` directly in the body | Text lost | `word` |
| `<a name="x">word</a>`, with no `href` | Text lost | `word` |
| Edit form for a comment holding `&gt;` | Pre-filled `&gt;` | Pre-filled `>` |

The direct `span` removal dated from a 2021 infinite-loop patch. The version before it kept that text, so keeping it
restores what the site shows. No saved comment has such a `span`.

Unchanged: how text splits around links and images, image pairing, links without text, and leaving out a nested `div`.
Comments are not persisted, so nothing cached needs repair.

This first change read bold and italic as plain text, because `LinkedText` needed one fixed font for its link tapping.
Text styles below replaced that.

## Verification

- All 311 distinct comment bodies from the 173 saved pages in the fixture repository went through both parsers in a
  temporary test, which was not committed. 300 came out identical. The other 11 differ only by decoded entities and
  removed `strong` and `em` tags. No markup or entity remains in any plain text run.
- `GalleryCommentParserTests` adds 15 test functions. Against the old parser 9 fail, and the 6 covering unchanged
  behavior pass.
- Both reported comments were read on an iPhone Air on iOS 27.2 in a Debug build, in the running app's text and on
  screen, using fixtures `marketing-726d47a8cc4353c3` and
  `.capture/website-language-20261102/marketing-8f95f940d5b1858c`.
- `FeatureTests` without `VisualSnapshotTests`: 1,419 tests, 1,408 passed, 10 expected failures, 1 failed. No test
  in `ParserFeatureTests` failed. Strict SwiftLint reports no violations, and the app build has no warnings.

These runs used a working tree that also held the uncommitted title-preference and website-review work.

The one failure is `CaptureSceneTests/sceneSettingsAreTheDefaultsWithTheBypassOn`. That uncommitted work makes
`CaptureScenePreparation.swift` set `displayJapaneseTitle` from the locale, so the scene's settings no longer equal the
defaults this test expects. It is unrelated to the parser and was left alone.

Not verified: the live site was not checked, so all evidence comes from saved pages.

The 24 website Comments captures from `LANGUAGES-20261102.md` predate this fix and still show literal `<strong>`.

## Text styles

The owner then asked for styles to render, not only bold and italic (`5d4c24553`).

The site's wiki lists bold, underline, strike-through and italic as the comment BBCode. Saved and live pages show how
each is written, and the parser reads these:

| BBCode | HTML | Where it was seen |
| --- | --- | --- |
| Bold | `<strong>` | Saved pages |
| Italic | `<em>` | Saved pages |
| Underline | `<span style="text-decoration:underline;">` | Live pages, around links |
| Strike-through | `<del>` | Live pages |

The parser also accepts `b`, `i`, `u`, `s`, `strike`, `ins` and a `line-through` span, none of which were seen. The old
direct `span` removal would have deleted every underlined link in those live comments.

`CommentContent.text` is now an `AttributedString`, the one source of the text and its styles. SwiftUI's `Text` draws
styles and links together, on both the Comments list and the Detail card. The UIKit tap overlay in `LinkedText` is gone:
it measured with a single fixed font, so it could not stay aligned with styled text.

### Verification

- The live markup comes from 1,260 distinct comments on 52 public pages, fetched anonymously at one page every 4
  seconds. Only tags and styles were counted, and nothing from those pages was kept in the repository.
- 1,587 distinct comments from saved and live pages went through this parser and the previous one in a temporary test.
  They produced 6 bold, 4 italic, 5 underline and 2 strike-through runs. Text, links and images matched except for one
  trailing zero-width space, which was then fixed and now has a test. The comparison was not rerun after that fix.
- `GalleryCommentParserTests` covers every tag above, nesting, trimming and the live underlined-link shape.
  `LinkedTextTests` covers link ranges after Chinese, emoji, Unicode bold and combining characters.
- Each style was rendered in Latin, Chinese and Japanese on the list, and in Latin on the Detail card.
- In the running app, on fixture data: tapping a link opened `book.dmm.com` in Safari, tapping plain words did nothing,
  and the row still lists "Open link to book.dmm.com" and "Open link to bookwalker.jp" as accessibility actions.
- `FeatureTests` without `VisualSnapshotTests`: 1,428 tests, 1,418 passed, 9 expected failures, 1 failed. The failure is
  the same `sceneSettingsAreTheDefaultsWithTheBypassOn` as above. Strict SwiftLint and the build are clean.

Not verified: underline and strike-through were checked in the parser tests and those renders, not in the running app,
because no fixture comment has them. VoiceOver itself was not run. Swipe actions on a row with a link were not tried,
because anonymous fixture comments have none.

### Known limits

- Chinese and Japanese italics stay upright, including inside bold italics. Bold, underline and strike-through do apply
  to them. iOS draws no slanted CJK from `.emphasized`, while a browser synthesizes one.
- Editing a comment pre-fills plain text, so saving an edit in the app drops the comment's styles.
  The owner deferred this (Deferred Items in `.planning/STATE.md`).
- The website Comments captures predate this change as well.
