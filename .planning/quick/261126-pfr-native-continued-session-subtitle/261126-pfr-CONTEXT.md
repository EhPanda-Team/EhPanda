# Quick Task 261126-pfr: Native continued-session subtitle - Context

**Gathered:** 2026-11-26
**Status:** Ready for planning

<domain>
## Task Boundary

The continued-processing card subtitle (`continued_session.subtitle` in
`AppPackage/Sources/Resources/Resources/Localizable.xcstrings`) used a decorative middle dot,
`%#@completed@ / %#@total@ · %#@galleries@`, in all six locales. The owner's rule ("No decorative
middle dots") forbids `·` as a separator between items, and swapping in another glyph is not a fix.
This task replaces the value in every locale with wording a native writer of that locale would use,
and updates every test literal and source comment that pins the old English rendering.

Out of scope: planning documents and other prose, the `actions-tool` golden fixtures, the
unrelated doc comment at `AppPackage/Tests/DownloadsFeatureTests/DownloadRunProgressOverlayTests.swift:14`
(it quotes a different, historical overlay line), and the zero-gallery end state described under
Deferred.
</domain>

<decisions>
## Implementation Decisions (locked)

### Process that produced the copy
Each locale was written by its own writer from the facts alone (no English, no other locale), then
read by a different blind reviewer per locale; reviews were reconciled side by side and the zh pair
was checked mechanically (zh-Hant converted to Simplified equals zh-Hans).

### Final catalog values
Substitution names, `argNum` and `formatSpecifier` stay exactly as they are:
`completed` = argNum 1, `total` = argNum 2, `galleries` = argNum 3, all `lld`. The outer string may
order the placeholders differently per locale (ja and ko put `total` first); `argNum` keeps the
arguments bound, as `accessibility.partial` in the DetailFeature catalog already does for ja.

| Locale | Outer `stringUnit.value` | Substitution values |
| --- | --- | --- |
| de | `%#@completed@ von %#@total@ aus %#@galleries@` | unchanged: completed other `%arg`; total one `%arg Seite`, other `%arg Seiten`; galleries one `%arg Galerie`, other `%arg Galerien` |
| en | `%#@completed@ of %#@total@ in %#@galleries@` | unchanged: completed other `%arg`; total one `%arg page`, other `%arg pages`; galleries one `%arg gallery`, other `%arg galleries` |
| ja | `全%#@total@ページ中%#@completed@ページ完了（ギャラリー%#@galleries@件）` | each variable's only (`other`) value becomes `%arg` (total was `%argページ`, galleries was `%arg件のギャラリー`; completed already `%arg`) |
| ko | `총 %#@total@페이지 중 %#@completed@페이지 완료 (갤러리 %#@galleries@개)` | each `other` value becomes `%arg` (total was `%arg페이지`, galleries was `갤러리 %arg개`) |
| zh-Hans | `已下载 %#@completed@ 页，共 %#@total@ 页（%#@galleries@ 个画廊）` | each `other` value becomes `%arg` (total was `%arg 页`, galleries was `%arg 个画廊`) |
| zh-Hant | `已下載 %#@completed@ 頁，共 %#@total@ 頁（%#@galleries@ 個畫廊）` | each `other` value becomes `%arg` (total was `%arg 頁`, galleries was `%arg 個畫廊`) |

Exact characters matter: ja and zh use full-width `（` `）` and `，` with no space before `（`; ko
uses a half-width space then `(` `)`; zh puts one half-width space between a number and adjacent
Han characters. No locale ends with a period (each value is a fragment). Category sets stay
coherent: en and de both use {other} for completed and {one, other} for total and galleries;
ja, ko, zh-Hans and zh-Hant are `other`-only.

Rendered examples (completed, total, galleries) = (6, 14, 2):
- en: `6 of 14 pages in 2 galleries`
- de: `6 von 14 Seiten aus 2 Galerien`
- ja: `全14ページ中6ページ完了（ギャラリー2件）`
- ko: `총 14페이지 중 6페이지 완료 (갤러리 2개)`
- zh-Hans: `已下载 6 页，共 14 页（2 个画廊）`
- zh-Hant: `已下載 6 頁，共 14 頁（2 個畫廊）`

### Editing the catalog
Edit only the lines that change inside the `continued_session.subtitle` entry (the six outer values
and the eight ja/ko/zh substitution values). Do not re-serialize the file: it mixes `"key" : value`
and `"key": value` styles, and a JSON round-trip would rewrite unrelated entries. The file must
still parse as JSON afterwards.

### Test literals and comments
The tests run in the simulator's default English locale and pin the English rendering. Rewrite
every pinned rendering with this mapping, which covers all 182 occurrences (literals, interpolated
literals such as `"\(numerator) / 6 pages · 1 gallery"`, and the doc comments that quote the card):

- `<a> / <b> <page|pages> · <c> <gallery|galleries>` becomes `<a> of <b> <page|pages> in <c> <gallery|galleries>`

where `<a>` is a number or a Swift interpolation like `\(numerator)`, `<b>` is a number or `N`, and
the noun forms stay as they are. Files: every `*.swift` under `AppPackage/Tests/DownloadsFeatureTests/`,
plus the one source doc comment at
`AppPackage/Sources/DownloadClient/DownloadClient+WorkingManifestReconciliation.swift:26`
(`` `0 / N pages · 0 galleries` `` becomes `` `0 of N pages in 0 galleries` ``). After the rewrite the
only `·` left under `AppPackage/Tests/DownloadsFeatureTests/` is the out-of-scope comment in
`DownloadRunProgressOverlayTests.swift:14`. The new English text is two characters longer per
occurrence, so check the 120-character line limit (SwiftLint `line_length` is an error) and wrap
any line that crosses it without suppressing the rule.

### Verification
- The catalog parses (`python3 -c "import json; json.load(open(...))"`).
- SwiftLint, run directly, reports nothing for `AppPackage/Sources/DownloadClient` and
  `AppPackage/Tests/DownloadsFeatureTests` (the app-scheme build does not lint test targets).
- `DownloadsFeatureTests` passes, run through the app scheme and test plan on the dedicated
  simulator `EhPanda iPhone Air (middle-dot)` (id `811DE720-3B21-4A00-B575-F980A031F185`).
  Only one `xcodebuild test` may run on this Mac at a time: before starting, wait until
  `pgrep -x xctest` finds nothing, and never kill a test run.

### Commits
One atomic code commit on the current branch, subject at most 50 characters, signed, with author
and committer dates in +0800 (the machine zone is +0900). No push, no merge.

### Claude's Discretion
None. Any deviation from the values above needs the orchestrator.
</decisions>

<specifics>
## Deferred (reported, not fixed here)

Every reviewer flagged that the drained end state renders as completed 0, total 1, galleries 0
(`0 of 1 page in 0 galleries`): the progress floor of one page reaches the text while the gallery
count is zero, which contradicts itself in every language. No wording can fix it; it belongs to the
code that supplies the numbers, so it is reported to the owner as a follow-up.
</specifics>
