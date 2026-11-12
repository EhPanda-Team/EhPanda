# Release notes

Every release has one notes file here, `ReleaseNotes/<version>.md`, named after the version the
release is tagged with, for example `ReleaseNotes/2.8.2.md`. Add it in the release pull request.
The pull request's description is not used for the notes. Merging the release pull request does not
release anything: start Deploy by hand on main afterwards. Its title and notes all come from this file.

`python3 actions-tool/release_notes.py version` prints the version the next release gets.

## Format

The release title on the first line, then one section per language, all six, in this order, with
exactly these headings:

```markdown
# Bugfixes & search improvements

## English

Two fixes for reading and search.
Fixed reading page gestures not responding when scale is greater than 1.
Improved the search page. (credit @someone)

## Deutsch

…

## 日本語

…

## 한국어

…

## 简体中文

…

## 繁體中文

…
```

- The first line is `# <release title>`, the GitHub release's title: one line, at most 100 characters.
- No text between the title and `## English`, no other headings (`#`, `###`, …), and no empty section.
- Write plain text, one item per line, without a number or a bullet (`1.`, `-`, `*`); the check
  refuses both. The first line of each section is the lead sentence. GitHub, Telegram and Discord show
  it as its own paragraph and turn each following line into a bullet (blank lines between the lines
  make no difference). A link on its own paragraph at the end stays below the list. AltStore and
  SideStore show the lines as written.
- English and 繁體中文 together must fit in one Telegram message (4,096 characters), and English
  alone in one Discord message (2,000 characters).

A check on the release pull request fails if the file is missing or breaks any of these rules.
Run it locally with `python3 actions-tool/release_notes.py check`.

## Where each section goes

| Destination | Notes |
|---|---|
| AltStore (`AltStore.json`) | every language, by language code; English is the default for any other language |
| SideStore (`SideStore.json`) | English |
| GitHub release | English, then each other language in a collapsed section titled with its heading; lead sentence, then a bullet per line |
| Telegram | English, a blank line, 繁體中文, then the release link; no language is named; lead sentence, then a `•` per line |
| Discord | English, then the release link; lead sentence, then a bullet per line |

The language codes are `en`, `de`, `ja`, `ko`, `zh-Hans` and `zh-Hant`, the same as the app's.
A device set to 繁體中文 (Taiwan or Hong Kong) gets the `zh-Hant` notes, one set to 简体中文 the
`zh-Hans` notes.
