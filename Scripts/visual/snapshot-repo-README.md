# ehpanda-snapshot

The approved screenshot baseline of [EhPanda](https://github.com/EhPanda-Team/EhPanda)'s screenshot check.

EhPanda's tests draw every screen of the app in each language, text size, device, orientation and appearance, and
compare each picture with the approved one kept here. The pictures show synthetic content only: made-up titles,
names and generated artwork, never a real gallery or account.

## What a push contains

Every push is approved by the project owner. A new baseline is recorded by one full run of the check on GitHub's
Macs, checked picture by picture, and approved as a whole before it is pushed. Nothing records automatically: a
change to the app's look makes the check fail until a new baseline replaces the affected pictures.

A baseline arrives as one commit per device and language, then an approval commit that adds `baseline.json` and the
tag `baseline-<n>`. `baseline.json` records the tag, the picture count, the approval and the SHA-256 of the
fingerprint file that was approved.

## Layout

```
<family>/<locale>/<size>/<scenario>/<orientation>-<theme>.png
```

- `family`: `iphone` or `ipad`
- `locale`: `en`, `de`, `ja`, `ko`, `zh-Hans` or `zh-Hant`
- `size`: the text size, `xSmall`, `large` or `accessibility5`
- `orientation`: `portrait` or `landscape`
- `theme`: `light` or `dark`

Coordinates that cannot be drawn (for example a screen that exists only on one device) are left out, each with its
reason, in the app repository's scenario inventory.

## How the check uses it

The app repository pins the approved set in `AppPackage/Tests/VisualSnapshotTests/Baseline/fingerprints.json`: this
repository's commit, the tag and the SHA-256 of every picture. Each part of the check fetches only the slices it
needs at that commit and refuses a picture whose hash differs, a missing picture and a file that is not listed, so a
picture edited here never reaches a comparison.

To fetch one slice yourself:

```sh
git clone --no-checkout --depth 1 --filter=blob:none --sparse https://github.com/EhPanda-Team/ehpanda-snapshot.git
cd ehpanda-snapshot
git sparse-checkout set --cone iphone/en/large
git checkout main
```
