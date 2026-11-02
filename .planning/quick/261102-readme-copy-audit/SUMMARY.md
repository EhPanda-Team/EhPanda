# README cleanup and copy audit

Owner request (2026-11-02): run the app's localization audit on the READMEs, delete the Translation and Screenshots
sections, fold System Requirements into a small note under Installation, and propose new titles for Content & Copyright
and Questions & Feedback. The owner then accepted every proposal and the recommended titles, and asked for Community to
sit directly under Installation.

## Changes

- `d154de30f` removes Screenshots from all six READMEs. It held the only link to ehpanda.app, so the READMEs no longer
  link to the website.
- `d154de30f` moves the System Requirements sentence under Installation, wrapped in `<sub>`.
- `cf9388d36` applies the 96 copy edits: 11 P0, 25 P1, 44 P2 and 16 P3. The proposals and their reasons are in
  `.capture/agent-work/copy-audit/readme/proposals.py`, which is git-ignored.
- `cf9388d36` renames two sections. Content & Copyright becomes Disclaimer, because the section never mentions copyright.
  Questions & Feedback becomes Community, because the section holds only three community links.
- `cf9388d36` gives the footnote line CRLF in the five READMEs that use CRLF. It was their only LF line.
- `cf9388d36` moves Community directly under Installation.
- The Translations Wanted section needed no change: `519a450f2` already removed it on this branch, and main still shows it
  because it has not merged.

GitHub's Markdown API confirms `<sub>` survives, while `style`, `<font>` and `<small>` are stripped, so a README can have
small text but not gray text.

## Verification

- Every proposal matched exactly one place in its README, checked by script before applying.
- App names (settings path, toggle, dual-page mode) were read from the current string catalogs. Three READMEs named them
  wrongly: zh-Hant 一般設定, zh-Hans 一般 and 共享分析数据, and Korean 양면 보기 모드.
- iOS accessibility setting names were read from the iOS 27.2 simulator runtime's own strings tables.
- In the applied READMEs, a Traditional-to-Simplified conversion leaves only regional words, script and Apple's own names
  as differences between the Chinese files, and every difference was read.
- GitHub's Markdown API renders all six files with the same structure: 4 headings, 1 `<sub>`, 14 links, 4 images and 2
  bold passages. None contains an em or en dash.

Not verified: no native speaker reviewed German, Japanese or Korean. The READMEs were not viewed on GitHub itself, because
this branch is not pushed.

## Left alone

The German README uses LF and the other five use CRLF. Unifying them would touch every line in the diff. Edit these files
in bytes, because Python's text mode rewrites CRLF as LF.
