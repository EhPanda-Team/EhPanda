# Release notes

Every release has one notes file here, `ReleaseNotes/<version>.md`, named after the version the
release is tagged with, for example `ReleaseNotes/2.8.2.md`. Add it in the release pull request.
The pull request's description is not used for the notes.

`python3 actions-tool/release_notes.py version` prints the version the next release gets.

## Format

One section per language, all six, in this order, with exactly these headings:

```markdown
## English

1. Fixed reading page gestures not responding when scale is greater than 1.
2. Improved the search page. (credit @someone)

## Deutsch

1. …

## 日本語

1. …

## 한국어

1. …

## 简体中文

1. …

## 繁體中文

1. …
```

- No text before `## English`, no other headings (`#`, `###`, …), and no empty section.
- Write plain text: AltStore and SideStore show the notes as they are. Number the items and keep
  each item on one line.
- English and 繁體中文 together must fit in one Telegram message (4,096 characters), and English
  alone in one Discord message (2,000 characters).

A check on the release pull request fails if the file is missing or breaks any of these rules.
Run it locally with `python3 actions-tool/release_notes.py check`.

## Where each section goes

| Destination | Notes |
|---|---|
| AltStore (`AltStore.json`) | every language, by language code; English is the default for any other language |
| SideStore (`SideStore.json`) | English |
| GitHub release | English, then each other language in a collapsed section titled with its heading |
| Telegram | English, a blank line, 繁體中文, then the release link; no language is named |
| Discord | English, then the release link |

The language codes are `en`, `de`, `ja`, `ko`, `zh-Hans` and `zh-Hant`, the same as the app's.
A device set to 繁體中文 (Taiwan or Hong Kong) gets the `zh-Hant` notes, one set to 简体中文 the
`zh-Hans` notes.
