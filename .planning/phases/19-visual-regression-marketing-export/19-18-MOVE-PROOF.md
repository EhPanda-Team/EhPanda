# 19-18 move proof

The move of every scenario registration into a per-view `SnapshotProvider` file is a pure move: a local candidate
capture of the 21-scenario sample taken after the move is byte-identical (same PNG SHA-256 per key) to the same
capture taken before it, and every sampled key that was identical to the downloaded `baseline2` set before the move
is still identical to it after (D-08, D-10).

## Commits

- Base (the "before" capture ran on these sources, with only the runner changed): `da6495e81`
- Task 1 (runner, `SnapshotProvider`, first provider): `24b860297`
- Task 2 (Browsing and Library states moved): `45b94b6c0`
- Task 3 (Gallery and Settings states moved, this file): the commit that adds this file. The "after" capture ran
  on exactly its sources.

## Sample (class/method for `--classes`)

```
HomeSnapshotTests/testHomePopulated
FrontPageSnapshotTests/testList
WatchedSnapshotTests/testSignedOut
ToplistsSnapshotTests/testList
HistorySnapshotTests/testList
PopularSnapshotTests/testList
SearchSnapshotTests/testRootHistory
QuickSearchSnapshotTests/testList
FavoritesSnapshotTests/testList
DownloadsSnapshotTests/testList
GalleryDetailSnapshotTests/testLoaded
CommentsSnapshotTests/testList
DetailPagesMoreSnapshotTests/testTorrents
DetailPagesSnapshotTests/testArchives
ReaderSnapshotTests/testVertical
ReaderSnapshotTests/testHorizontal
SettingsSnapshotTests/testRoot
SettingsPagesSnapshotTests/testGeneralBasic
SettingsSnapshotTests/testBlockedUsersFilled
AppWideSnapshotTests/testErrorInfo
SettingsSnapshotTests/testLoginEmpty
```

## Commands

Each run took the same two commands, with `--out` `before-phone` and `before-pad` before the move, and
`after-phone` and `after-pad` after it (`$SAMPLE` is the list above, joined with commas; the simulators are the
project simulators `EhPanda iPhone Air (phase19)` and `EhPanda iPad Pro 11-inch (M5) (phase19)`):

```
Scripts/visual/run-snapshot-local.sh --device phone --simulator 'EhPanda iPhone Air (phase19)' \
    --config en-large,ja-accessibility5 --classes "$SAMPLE" --mode candidate --out "$W/after-phone"
Scripts/visual/run-snapshot-local.sh --device pad --simulator 'EhPanda iPad Pro 11-inch (M5) (phase19)' \
    --orientation portrait --config en-large --classes "$SAMPLE" --mode candidate --out "$W/after-pad"
```

`$W` is `$MAIN/.capture/agent-work/phase19-18` (ignored by git; no picture is in the repository).

## Build

Local Xcode: `Xcode 27.2 / Build version 27B52`. Hosted pin (`regression-environment.json`):
`Xcode 27.1`, build `27A9275`. Identity to `baseline2` is therefore required only for the keys that were already
identical to it before the move, never assumed for the rest.

## Counts

- phone: keys 168, after = before 166 of 168, before = baseline2 99 of 168, after = baseline2 among those 99 of 99
- pad: keys 42, after = before 38 of 42, before = baseline2 20 of 42, after = baseline2 among those 20 of 20

## Differences between the before and after captures

Six of the 210 keys differ between the before and after captures (phone 2 of 168, iPad 4 of 42). To tell the
move from run-to-run variation, the four classes holding them were captured again on the same project simulators
(`diag-*`: the sources after the move; `diag2-*`: the sources before the move, restored from the base commit
for this check only, then removed again). The reruns are not part of the sample and are not in the table below.

### phone

| key | before | after | rerun after the move | rerun before the move |
| --- | --- | --- | --- | --- |
| `app-wide-error-info__en__large__portrait__iphone__dark` | A | B | A | B |
| `app-wide-error-info__ja__accessibility5__portrait__iphone__dark` | A | A | B | A |
| `detail-pages-archives__ja__accessibility5__landscape__iphone__light` | A | B | B | B |

Equal letters are byte-identical pictures; the letters are local to each row.

### pad

| key | before | after | rerun after the move | rerun before the move |
| --- | --- | --- | --- | --- |
| `downloads-list__en__large__portrait__ipad__dark` | A | B | B | B |
| `downloads-list__en__large__portrait__ipad__light` | A | B | B | B |
| `favorites-list__en__large__portrait__ipad__dark` | A | B | B | B |
| `favorites-list__en__large__portrait__ipad__light` | A | B | C | B |

Equal letters are byte-identical pictures; the letters are local to each row.

## D-10 comparison of the differing keys

The runner's compare mode (`--mode compare --refs <before sample>`, precision 0.9999, perceptual precision 1, unchanged)
was run on the sources after the move, against the before pictures, for the classes holding the six keys. It captures
each coordinate again, so what is compared with the before picture is a fresh capture after the move, not the stored
after file (no existing path compares two stored pictures).

| device | key | result against the cold before capture |
| --- | --- | --- |
| phone | `app-wide-error-info__en__large__portrait__iphone__dark` | within tolerance (`passed`) |
| phone | `detail-pages-archives__ja__accessibility5__landscape__iphone__light` | within tolerance (`passed`) |
| pad | `downloads-list__en__large__portrait__ipad__light` | beyond tolerance (`changed`, 2 attempts): 15363 of 1009140 pixels (1.52%), one box x 15-306, y 128-184 |
| pad | `downloads-list__en__large__portrait__ipad__dark` | beyond tolerance (`changed`, 2 attempts): 15221 pixels (1.51%), same box |
| pad | `favorites-list__en__large__portrait__ipad__light` | beyond tolerance (`changed`, 2 attempts): 15196 pixels (1.51%), box x 15-306, y 286-342 |
| pad | `favorites-list__en__large__portrait__ipad__dark` | beyond tolerance (`changed`, 2 attempts): 15347 pixels (1.52%), same box |

Phone: `passed=16 changed=0` over the 16 coordinates of the two classes; both differing phone keys are within
tolerance. Pad: `changed=4`.

### The four iPad keys: controlled old-versus-new reference (owner decision)

The pad's before capture was the first capture on a freshly created simulator; every later capture ran on that
simulator in a used state. The question this proof answers is whether the move changes a picture, so the four iPad
keys are compared under one simulator state:

- Reference: the capture made with the old sources (the base commit) on the same simulator, in the same state as the
  after capture (`diag2-pad`).
- Result: that old-code capture is byte-identical to the capture made with the new sources (`compare-pad`, and also the
  stored after capture) for all four keys: old = new, byte for byte. The move changes none of these pictures.
- The cold first capture (the before sample) is beyond tolerance against both: the box and pixel counts are in the
  table above.

## Finding for 19-27: Cold first capture differs

On a freshly created simulator, the first capture of the iPad Library pages differs from every later capture, with the
same sources. The differing box (291 x 56 pixels, 1.5% of the picture) is the selected row of the Library sidebar:
cold, the row is drawn in the accent colour (green fill, white text and symbol); in the later captures it is drawn in
the inactive selection grey (dark text, green symbol). `downloads-list` shows Visual Folder A (y 128-184) and
`favorites-list` shows All (y 286-342).

Crops of the box (3x, 15 pixels of margin left and right and 10 above and below), saved under
`$MAIN/.capture/agent-work/phase19-18/cold-vs-warm/` (not committed):

- `downloads-list-light-cold-before.png` (cold), `downloads-list-light-warm-old-code.png` and
  `downloads-list-light-warm-new-code.png` (later, same simulator), `downloads-list-context.png` (the page top)
- `favorites-list-light-cold-before.png` (cold), `favorites-list-light-warm-old-code.png` and
  `favorites-list-light-warm-new-code.png` (later), `favorites-list-context.png`

Hosted runners always start from fresh simulators, so this may be a cause of the run-to-run variation the hosted runs
show. It is the first open input for 19-27.

## Per key

### phone

| key | before | after | baseline2 |
| --- | --- | --- | --- |
| `app-wide-error-info__en__large__landscape__iphone__dark` | `feb0cfefa03988b8310bfc829508bd2602d3ae1416dbad027cd14eccd80e23b2` | `feb0cfefa03988b8310bfc829508bd2602d3ae1416dbad027cd14eccd80e23b2` | `feb0cfefa03988b8310bfc829508bd2602d3ae1416dbad027cd14eccd80e23b2` |
| `app-wide-error-info__en__large__landscape__iphone__light` | `945e6dfc834ec019bc6c6b08c3816ac454a6ef38f44013b67010738e60114bea` | `945e6dfc834ec019bc6c6b08c3816ac454a6ef38f44013b67010738e60114bea` | `945e6dfc834ec019bc6c6b08c3816ac454a6ef38f44013b67010738e60114bea` |
| `app-wide-error-info__en__large__portrait__iphone__dark` | `85bc4bdcf81eaba71203de4cae4df3fb7071e95e6a597e947d07149ccac81554` | `89859e2e766319e4b728d20f82f0fa76d35c0c259093ee592a9b58ce8adf06d2` | `8b28c2ef9e470d801a3b00fcf469c5f571bf53c262df3beec3cb51854d050781` |
| `app-wide-error-info__en__large__portrait__iphone__light` | `b9e7e6298002dfcdd3f74a7e88aeb58e61df1c720e7ab054c746c850d3059d64` | `b9e7e6298002dfcdd3f74a7e88aeb58e61df1c720e7ab054c746c850d3059d64` | `d1587408c64dc7d8b0d2a16bbf4841165359299a738d2c45bafb169586e54f62` |
| `app-wide-error-info__ja__accessibility5__landscape__iphone__dark` | `2558c2fbbf0cfc57d1c0fd1de028ea80b3604232f499321902d5a72bdc2c4682` | `2558c2fbbf0cfc57d1c0fd1de028ea80b3604232f499321902d5a72bdc2c4682` | `2558c2fbbf0cfc57d1c0fd1de028ea80b3604232f499321902d5a72bdc2c4682` |
| `app-wide-error-info__ja__accessibility5__landscape__iphone__light` | `fdf367d30e1caa78998363035993aa9f89e4931e0f422566a66834a20b896a49` | `fdf367d30e1caa78998363035993aa9f89e4931e0f422566a66834a20b896a49` | `fdf367d30e1caa78998363035993aa9f89e4931e0f422566a66834a20b896a49` |
| `app-wide-error-info__ja__accessibility5__portrait__iphone__dark` | `f00c2a84f44a1d8a15617cc84cfcc5cbcb0b2a7dbc4c88aae303c90f2339309d` | `f00c2a84f44a1d8a15617cc84cfcc5cbcb0b2a7dbc4c88aae303c90f2339309d` | `f00c2a84f44a1d8a15617cc84cfcc5cbcb0b2a7dbc4c88aae303c90f2339309d` |
| `app-wide-error-info__ja__accessibility5__portrait__iphone__light` | `b0261f6dab3dd981fa35498ad3874fc5e59767f2545fab233eeb2937dea8ecec` | `b0261f6dab3dd981fa35498ad3874fc5e59767f2545fab233eeb2937dea8ecec` | `b0261f6dab3dd981fa35498ad3874fc5e59767f2545fab233eeb2937dea8ecec` |
| `blocked-users-filled__en__large__landscape__iphone__dark` | `479782e01f1091396404d7c3c5ee5ecf0c019cde08aa0a5d377da86704dc7c31` | `479782e01f1091396404d7c3c5ee5ecf0c019cde08aa0a5d377da86704dc7c31` | `479782e01f1091396404d7c3c5ee5ecf0c019cde08aa0a5d377da86704dc7c31` |
| `blocked-users-filled__en__large__landscape__iphone__light` | `1712f90ca2df1ad6e3badd3b6caf18c25cac9b111273f0d4d9e6e03553369532` | `1712f90ca2df1ad6e3badd3b6caf18c25cac9b111273f0d4d9e6e03553369532` | `1712f90ca2df1ad6e3badd3b6caf18c25cac9b111273f0d4d9e6e03553369532` |
| `blocked-users-filled__en__large__portrait__iphone__dark` | `2e5997e45d05bfa6b67c60d42a2605728b0a01d13d25e9a22006132e6996f77c` | `2e5997e45d05bfa6b67c60d42a2605728b0a01d13d25e9a22006132e6996f77c` | `2e5997e45d05bfa6b67c60d42a2605728b0a01d13d25e9a22006132e6996f77c` |
| `blocked-users-filled__en__large__portrait__iphone__light` | `0872700279e5920ae41a686ad7fd80c118f334f52e47ec7db89865c103dc37f9` | `0872700279e5920ae41a686ad7fd80c118f334f52e47ec7db89865c103dc37f9` | `0872700279e5920ae41a686ad7fd80c118f334f52e47ec7db89865c103dc37f9` |
| `blocked-users-filled__ja__accessibility5__landscape__iphone__dark` | `7d0f68f012f5e85b28e8076c7e558e46338b640e01e81a326f4a958d97e2488f` | `7d0f68f012f5e85b28e8076c7e558e46338b640e01e81a326f4a958d97e2488f` | `7d0f68f012f5e85b28e8076c7e558e46338b640e01e81a326f4a958d97e2488f` |
| `blocked-users-filled__ja__accessibility5__landscape__iphone__light` | `b0eac819623a856ccfe4f86af1c2bbc573afdc19f010745311db271f73e3a7f3` | `b0eac819623a856ccfe4f86af1c2bbc573afdc19f010745311db271f73e3a7f3` | `b0eac819623a856ccfe4f86af1c2bbc573afdc19f010745311db271f73e3a7f3` |
| `blocked-users-filled__ja__accessibility5__portrait__iphone__dark` | `7adbeb0e5a39210568b56d923dddbd84145abdb329fd90ccc73edee81044eab3` | `7adbeb0e5a39210568b56d923dddbd84145abdb329fd90ccc73edee81044eab3` | `7adbeb0e5a39210568b56d923dddbd84145abdb329fd90ccc73edee81044eab3` |
| `blocked-users-filled__ja__accessibility5__portrait__iphone__light` | `270be16dfa576232fc5d71e8a3911dcec2f3253dbf2997ded06d6d8610431a5d` | `270be16dfa576232fc5d71e8a3911dcec2f3253dbf2997ded06d6d8610431a5d` | `270be16dfa576232fc5d71e8a3911dcec2f3253dbf2997ded06d6d8610431a5d` |
| `comments-list__en__large__landscape__iphone__dark` | `f5f074b4b59d5dc67bc6c3c2acc398398313d7d430f88b39b2d5c2357c1129ff` | `f5f074b4b59d5dc67bc6c3c2acc398398313d7d430f88b39b2d5c2357c1129ff` | `f5f074b4b59d5dc67bc6c3c2acc398398313d7d430f88b39b2d5c2357c1129ff` |
| `comments-list__en__large__landscape__iphone__light` | `895bdec5cbba7e4a5dd1563476584c89b718c10c0536afef228e6544b8d65916` | `895bdec5cbba7e4a5dd1563476584c89b718c10c0536afef228e6544b8d65916` | `895bdec5cbba7e4a5dd1563476584c89b718c10c0536afef228e6544b8d65916` |
| `comments-list__en__large__portrait__iphone__dark` | `6f6c74f65841562fc5a4fcd00239e7a89a6e6400b423d7c047539f4d8c90e262` | `6f6c74f65841562fc5a4fcd00239e7a89a6e6400b423d7c047539f4d8c90e262` | `6f6c74f65841562fc5a4fcd00239e7a89a6e6400b423d7c047539f4d8c90e262` |
| `comments-list__en__large__portrait__iphone__light` | `597dd4ed4c27f2d31b0a22bb41415b593acf48796992ebf0dfae5c1ffd8a00dd` | `597dd4ed4c27f2d31b0a22bb41415b593acf48796992ebf0dfae5c1ffd8a00dd` | `597dd4ed4c27f2d31b0a22bb41415b593acf48796992ebf0dfae5c1ffd8a00dd` |
| `comments-list__ja__accessibility5__landscape__iphone__dark` | `c3fc0ed70f584e1e7aa9d20a35341db75c5b637a0f9b8a803a32b5fe84257960` | `c3fc0ed70f584e1e7aa9d20a35341db75c5b637a0f9b8a803a32b5fe84257960` | `c3fc0ed70f584e1e7aa9d20a35341db75c5b637a0f9b8a803a32b5fe84257960` |
| `comments-list__ja__accessibility5__landscape__iphone__light` | `4ac766a2b152f280907688dc39dd8fb8fefd367477b3abefd091affeb8619b16` | `4ac766a2b152f280907688dc39dd8fb8fefd367477b3abefd091affeb8619b16` | `4ac766a2b152f280907688dc39dd8fb8fefd367477b3abefd091affeb8619b16` |
| `comments-list__ja__accessibility5__portrait__iphone__dark` | `61f630bfa489f6dab934f0d9ad57d9d5386b9d2c4fbd6e711ca3a817521a5784` | `61f630bfa489f6dab934f0d9ad57d9d5386b9d2c4fbd6e711ca3a817521a5784` | `61f630bfa489f6dab934f0d9ad57d9d5386b9d2c4fbd6e711ca3a817521a5784` |
| `comments-list__ja__accessibility5__portrait__iphone__light` | `0c4e0d165b51d89023678163cf7b282f2097131936664501eebc80f9257d197e` | `0c4e0d165b51d89023678163cf7b282f2097131936664501eebc80f9257d197e` | `0c4e0d165b51d89023678163cf7b282f2097131936664501eebc80f9257d197e` |
| `detail-pages-archives__en__large__landscape__iphone__dark` | `84a81c02025fb1f6158f5b0a0cbf951683c0783cac46184a307b26d26d174125` | `84a81c02025fb1f6158f5b0a0cbf951683c0783cac46184a307b26d26d174125` | `6319f033ea6e44320c3416c989be2bcfaea96b96ce4b8654dd0c1391a4bf4695` |
| `detail-pages-archives__en__large__landscape__iphone__light` | `af1408214694519e91bbdd724769177109791fde3fbc8b3dd95bbc2efbd45e43` | `af1408214694519e91bbdd724769177109791fde3fbc8b3dd95bbc2efbd45e43` | `6df95190241b5d5d54752b8f92aded5cc127caa99894edca92c34e48322e718c` |
| `detail-pages-archives__en__large__portrait__iphone__dark` | `c2aa4917c62f96a109dd2e8c0462fe16ea9f9b483fb001fe69e223ecd8f02d48` | `c2aa4917c62f96a109dd2e8c0462fe16ea9f9b483fb001fe69e223ecd8f02d48` | `8621c26f4d58d3ca90c30d71c398bd996f29a1635f1fdc22c93678b19db12f8b` |
| `detail-pages-archives__en__large__portrait__iphone__light` | `6fdef11bf535dc9811a2d1ee23519d3df7282e330fda02893f3754fc7ba0a044` | `6fdef11bf535dc9811a2d1ee23519d3df7282e330fda02893f3754fc7ba0a044` | `9cd21c36b20c0a758ef85a6273190809296f63e971e1a1126612673ed349e495` |
| `detail-pages-archives__ja__accessibility5__landscape__iphone__dark` | `45ed115547b5e0573b435fbe67d3a74a705dfbb9a1f57887195acc2d223b268d` | `45ed115547b5e0573b435fbe67d3a74a705dfbb9a1f57887195acc2d223b268d` | `45ed115547b5e0573b435fbe67d3a74a705dfbb9a1f57887195acc2d223b268d` |
| `detail-pages-archives__ja__accessibility5__landscape__iphone__light` | `2963dfeae5cc5b50c4989a3bf93b41e2d279039586557fc3aa0861b47975646d` | `3068d9f8b9760fbe98fd3035a29ff5629b446d5aafc73472fbf79b9652ba6a5d` | `3068d9f8b9760fbe98fd3035a29ff5629b446d5aafc73472fbf79b9652ba6a5d` |
| `detail-pages-archives__ja__accessibility5__portrait__iphone__dark` | `cad779180d12c1d4dc826510e8aad9405f93c2096de069e9c0249020d9644f1b` | `cad779180d12c1d4dc826510e8aad9405f93c2096de069e9c0249020d9644f1b` | `90372eb46c138fbbeb39211ba9c69da92aed7bf0af3a8ff44e3866ad60aec254` |
| `detail-pages-archives__ja__accessibility5__portrait__iphone__light` | `6e165f02f5ec0617a958fe82d92dd3fdd03ff96dcf05c05e59d031938589cbb0` | `6e165f02f5ec0617a958fe82d92dd3fdd03ff96dcf05c05e59d031938589cbb0` | `6e165f02f5ec0617a958fe82d92dd3fdd03ff96dcf05c05e59d031938589cbb0` |
| `detail-pages-torrents__en__large__landscape__iphone__dark` | `0c25feeab1809f964671095f9561538104147ac74ce4f5dd6f862d9c38ed9044` | `0c25feeab1809f964671095f9561538104147ac74ce4f5dd6f862d9c38ed9044` | `0c25feeab1809f964671095f9561538104147ac74ce4f5dd6f862d9c38ed9044` |
| `detail-pages-torrents__en__large__landscape__iphone__light` | `a8cb54e2f0f4bec2e965f41ca030ebf708692925162f4b2d9c1a33d341b3aca5` | `a8cb54e2f0f4bec2e965f41ca030ebf708692925162f4b2d9c1a33d341b3aca5` | `a8cb54e2f0f4bec2e965f41ca030ebf708692925162f4b2d9c1a33d341b3aca5` |
| `detail-pages-torrents__en__large__portrait__iphone__dark` | `4543af8c44699e1f7afe5de76d9d56595d3746e54a5a7942f0aa67b35c9bff59` | `4543af8c44699e1f7afe5de76d9d56595d3746e54a5a7942f0aa67b35c9bff59` | `5cbd9575f20916e395ccfc1e7cf8a9892e7ccea31f2d286f19c98bd006798483` |
| `detail-pages-torrents__en__large__portrait__iphone__light` | `7c726196a64e1197238b27c98fb961cc9566af5433b28eb7134bc6cc8ae693d7` | `7c726196a64e1197238b27c98fb961cc9566af5433b28eb7134bc6cc8ae693d7` | `7c726196a64e1197238b27c98fb961cc9566af5433b28eb7134bc6cc8ae693d7` |
| `detail-pages-torrents__ja__accessibility5__landscape__iphone__dark` | `b2f16880b9652256529a9897c5104811efb8e534498bef1bd04efdcb946bf8a6` | `b2f16880b9652256529a9897c5104811efb8e534498bef1bd04efdcb946bf8a6` | `b2f16880b9652256529a9897c5104811efb8e534498bef1bd04efdcb946bf8a6` |
| `detail-pages-torrents__ja__accessibility5__landscape__iphone__light` | `9267df63acb39cf5d64c28772eff6a4112d49679f1f3c9b8bb498abaf03da4fd` | `9267df63acb39cf5d64c28772eff6a4112d49679f1f3c9b8bb498abaf03da4fd` | `9267df63acb39cf5d64c28772eff6a4112d49679f1f3c9b8bb498abaf03da4fd` |
| `detail-pages-torrents__ja__accessibility5__portrait__iphone__dark` | `761d77cded8d5e05add9aa737ad3a8e169453edb19b97b655339fec0aaf2d553` | `761d77cded8d5e05add9aa737ad3a8e169453edb19b97b655339fec0aaf2d553` | `761d77cded8d5e05add9aa737ad3a8e169453edb19b97b655339fec0aaf2d553` |
| `detail-pages-torrents__ja__accessibility5__portrait__iphone__light` | `e327272208a67461618b986cb2409150c3d34764ba5ca1ace4d9f286ee0b65e6` | `e327272208a67461618b986cb2409150c3d34764ba5ca1ace4d9f286ee0b65e6` | `e327272208a67461618b986cb2409150c3d34764ba5ca1ace4d9f286ee0b65e6` |
| `downloads-list__en__large__landscape__iphone__dark` | `67f586886c2a822a54d0bff372e861c81c6c5981f16e7e692a07b5b1550340c4` | `67f586886c2a822a54d0bff372e861c81c6c5981f16e7e692a07b5b1550340c4` | `67f586886c2a822a54d0bff372e861c81c6c5981f16e7e692a07b5b1550340c4` |
| `downloads-list__en__large__landscape__iphone__light` | `5e5f4400cb9a4397aaf6e815fa7a8264bc33ebf5aea68298873b555392661e5f` | `5e5f4400cb9a4397aaf6e815fa7a8264bc33ebf5aea68298873b555392661e5f` | `42c2472f1e552468bd3cd23c988d22751d54296543baff4f4801bfe783895030` |
| `downloads-list__en__large__portrait__iphone__dark` | `0dcbd359a1a2551c0fd3b912f20bbfc909bf4bb8350f8320544f4f202a353bdc` | `0dcbd359a1a2551c0fd3b912f20bbfc909bf4bb8350f8320544f4f202a353bdc` | `0dcbd359a1a2551c0fd3b912f20bbfc909bf4bb8350f8320544f4f202a353bdc` |
| `downloads-list__en__large__portrait__iphone__light` | `a4c70ad92542d851d8780703d758a5796e4e3311ef2996437d3adcb4a94bdc1b` | `a4c70ad92542d851d8780703d758a5796e4e3311ef2996437d3adcb4a94bdc1b` | `582efb53181fdc44716390bc872a770734a1f36f4e47b57b1e16145cb20f6b43` |
| `downloads-list__ja__accessibility5__landscape__iphone__dark` | `e4ac7a347c8b74c5d2bdb39537fa947401cf3efc18fa4dc2caf88c356ccac6f8` | `e4ac7a347c8b74c5d2bdb39537fa947401cf3efc18fa4dc2caf88c356ccac6f8` | `36a8552ef1426c975da5c15597d96ff9f8eedcf1e528b50838bc5694d10c4dc9` |
| `downloads-list__ja__accessibility5__landscape__iphone__light` | `f6d41f8b9d922b313c83c4a5ab64e3278f38c903b7ac4d4ed1a6ae7499d00e05` | `f6d41f8b9d922b313c83c4a5ab64e3278f38c903b7ac4d4ed1a6ae7499d00e05` | `13765ba7a5d33cf98dfef4deca6902b9fe6bed316709cbdb45a68d29a0d6a8d6` |
| `downloads-list__ja__accessibility5__portrait__iphone__dark` | `04ceb43049026cf6409148f2c389df5f96ade60e51ed7e1b7985d059b1c93ebc` | `04ceb43049026cf6409148f2c389df5f96ade60e51ed7e1b7985d059b1c93ebc` | `0a9ced7f74ba07a787ee9f00fec675a37f639bbde76a2f89041710ff9a297c86` |
| `downloads-list__ja__accessibility5__portrait__iphone__light` | `3eb00d69cb3c3e5ad46ac6b84a01bcd6ba4bc52208f3d02c2e3d5813e6abea21` | `3eb00d69cb3c3e5ad46ac6b84a01bcd6ba4bc52208f3d02c2e3d5813e6abea21` | `9f93303f4b6f904808ea10e3fb01338de28c053e5c423ff370978864af7c6e6c` |
| `favorites-list__en__large__landscape__iphone__dark` | `36722b5b98cda10c5f22071ec0987e0e5b8e2106c0d092ff50c000bdc88d6969` | `36722b5b98cda10c5f22071ec0987e0e5b8e2106c0d092ff50c000bdc88d6969` | `36722b5b98cda10c5f22071ec0987e0e5b8e2106c0d092ff50c000bdc88d6969` |
| `favorites-list__en__large__landscape__iphone__light` | `a1f39ef2ecb0e4ab975f6efc178e1c373b1e3395e15ca4b2dfdace4caea9669d` | `a1f39ef2ecb0e4ab975f6efc178e1c373b1e3395e15ca4b2dfdace4caea9669d` | `a1f39ef2ecb0e4ab975f6efc178e1c373b1e3395e15ca4b2dfdace4caea9669d` |
| `favorites-list__en__large__portrait__iphone__dark` | `f3e8f9b89e8acd94e20f4c2570e7f4d742fbc5e1b725129510e7fe2dc6cac296` | `f3e8f9b89e8acd94e20f4c2570e7f4d742fbc5e1b725129510e7fe2dc6cac296` | `f3e8f9b89e8acd94e20f4c2570e7f4d742fbc5e1b725129510e7fe2dc6cac296` |
| `favorites-list__en__large__portrait__iphone__light` | `98b603f3f730147f9cfe9e2b8d7209d48fc0d80dfca504f64d7756508fdafc41` | `98b603f3f730147f9cfe9e2b8d7209d48fc0d80dfca504f64d7756508fdafc41` | `98b603f3f730147f9cfe9e2b8d7209d48fc0d80dfca504f64d7756508fdafc41` |
| `favorites-list__ja__accessibility5__landscape__iphone__dark` | `d9b88b5e6bbc827e1ef36f363d462adbf00fe07c0322de2ff78fed9b1f72cee4` | `d9b88b5e6bbc827e1ef36f363d462adbf00fe07c0322de2ff78fed9b1f72cee4` | `6c3415ef13506e5f0f8c8964517a591734252b78ecf5c4035af9a19bf3ba9ec4` |
| `favorites-list__ja__accessibility5__landscape__iphone__light` | `00faa140dc1edfbca0a6c3575e1680795c5cc263a83b30b28dda94aba41e7402` | `00faa140dc1edfbca0a6c3575e1680795c5cc263a83b30b28dda94aba41e7402` | `ad8a481df1df51836c857babeed01fea0dabc65b946dfa9e31cf8efb3eced0df` |
| `favorites-list__ja__accessibility5__portrait__iphone__dark` | `2e9a0b5050c64891f713c4ca000660d3a5725691fe4e132cc09d42395505e55f` | `2e9a0b5050c64891f713c4ca000660d3a5725691fe4e132cc09d42395505e55f` | `b153094e68c60d25b972d449f7e6fe50bc73ca9df6d9bf60cc039db90ac4a8a5` |
| `favorites-list__ja__accessibility5__portrait__iphone__light` | `1a83ce3ce2bb056ed84f36b6b969fcfca94c33b76712c4fb963edd5dba08407e` | `1a83ce3ce2bb056ed84f36b6b969fcfca94c33b76712c4fb963edd5dba08407e` | `6f2797c120271ed3d9a2fed815e66036900f4d0122d441cfeb7b5734af8cca24` |
| `front-page-list__en__large__landscape__iphone__dark` | `4fd8784d7214321b146315d9a5cad202d19d92fc22db47ff92793e3b7adbac68` | `4fd8784d7214321b146315d9a5cad202d19d92fc22db47ff92793e3b7adbac68` | `4fd8784d7214321b146315d9a5cad202d19d92fc22db47ff92793e3b7adbac68` |
| `front-page-list__en__large__landscape__iphone__light` | `7a419154fb88683aaa8303359d863ed1a59179e5b34a6e20d6e76175cf1565f1` | `7a419154fb88683aaa8303359d863ed1a59179e5b34a6e20d6e76175cf1565f1` | `8de95b0301c217722c75a68d77744173f05331e0dd3f8cf1d5410015fb37811e` |
| `front-page-list__en__large__portrait__iphone__dark` | `20fa0e7b466f677a67695e9b4d4ffed1df49191f65cae7fee9b48b8971f57c4d` | `20fa0e7b466f677a67695e9b4d4ffed1df49191f65cae7fee9b48b8971f57c4d` | `20fa0e7b466f677a67695e9b4d4ffed1df49191f65cae7fee9b48b8971f57c4d` |
| `front-page-list__en__large__portrait__iphone__light` | `e1ae737a62a428a26d4ae1b38d47ccddfb1339f13da62847a2689a50a78dfb9a` | `e1ae737a62a428a26d4ae1b38d47ccddfb1339f13da62847a2689a50a78dfb9a` | `2c5481ee5d70d6ae46d3ad57888a0800cf38c1bc5cf41ac0c10eebde350d2ed4` |
| `front-page-list__ja__accessibility5__landscape__iphone__dark` | `a7133cf5ef22c3e8d8366ba4758233015bf8f3ea2fb6744370ba9dd77821a3dc` | `a7133cf5ef22c3e8d8366ba4758233015bf8f3ea2fb6744370ba9dd77821a3dc` | `3494d386ae3b1e9383ba9d2b805bc3eacdc144e60881bf7d13f0fde34dcc2292` |
| `front-page-list__ja__accessibility5__landscape__iphone__light` | `a50d7654c75ea0964283246f0eb01e8a4c6c6462eb840cdb925d1ec563453490` | `a50d7654c75ea0964283246f0eb01e8a4c6c6462eb840cdb925d1ec563453490` | `79a1260b857aecab59add1412a2e99a1be4ec1d4beace3926d64c58a913cf570` |
| `front-page-list__ja__accessibility5__portrait__iphone__dark` | `68e09109baeb28a4b0a2ed1216f380f128b87a85358fac7b41e53011c4cc06c4` | `68e09109baeb28a4b0a2ed1216f380f128b87a85358fac7b41e53011c4cc06c4` | `444b1d1c06d5982d0b8fd8a48a8652aa0f78ffd5f5893071ae811c4e41187a37` |
| `front-page-list__ja__accessibility5__portrait__iphone__light` | `2e05989daaf27d7f22957bb8632499a778524b3afb2c8fe0b3bdf152aab4ddf1` | `2e05989daaf27d7f22957bb8632499a778524b3afb2c8fe0b3bdf152aab4ddf1` | `e23fc4ce834d8a512e610eb3c600c4dd0222662bb42f8b31adb8cc2c6796917b` |
| `gallery-detail-loaded__en__large__landscape__iphone__dark` | `1fac2b4865e9182d8ca14cd059ae3b7da9e83ee8b536559cd918cac4c07fa63a` | `1fac2b4865e9182d8ca14cd059ae3b7da9e83ee8b536559cd918cac4c07fa63a` | `90b89b7650e3bebbd2df806ebd8d28e8a4915e00a9b362b2cdfb198ea2080eb7` |
| `gallery-detail-loaded__en__large__landscape__iphone__light` | `8cd89786814f0db152bbe24b23038f5d3b16a6e13af5d5cd5f746cda2fadd2a0` | `8cd89786814f0db152bbe24b23038f5d3b16a6e13af5d5cd5f746cda2fadd2a0` | `0bca650c62625fc448a07cc908923b77a7d5365a338a9ae738e427c33da23f62` |
| `gallery-detail-loaded__en__large__portrait__iphone__dark` | `9fcf97c0d5192dacd4171014eb7031f060f83d133a0e56d815233a8468b283af` | `9fcf97c0d5192dacd4171014eb7031f060f83d133a0e56d815233a8468b283af` | `99ea64e86b33635736bfa2fbc927423ccec49d0a385d8aec742d185b691f21ed` |
| `gallery-detail-loaded__en__large__portrait__iphone__light` | `317c5ac0eecbc00bd01328e28d641299616ba989ef48947f9f19fbff5d8b9b12` | `317c5ac0eecbc00bd01328e28d641299616ba989ef48947f9f19fbff5d8b9b12` | `5ffdab2db195c3eddc5884d0227d8ad27de966d53835210e1fcf2c211f9ed7e8` |
| `gallery-detail-loaded__ja__accessibility5__landscape__iphone__dark` | `9cb13482bd7ecbc29fd6a2087e805c12e86f3079e8f518e025108dc54401716a` | `9cb13482bd7ecbc29fd6a2087e805c12e86f3079e8f518e025108dc54401716a` | `9cb13482bd7ecbc29fd6a2087e805c12e86f3079e8f518e025108dc54401716a` |
| `gallery-detail-loaded__ja__accessibility5__landscape__iphone__light` | `d0858d7200dfc9379f8f6363c24d0ae962aa69d3b948c7994916a76fdb0e7849` | `d0858d7200dfc9379f8f6363c24d0ae962aa69d3b948c7994916a76fdb0e7849` | `d0858d7200dfc9379f8f6363c24d0ae962aa69d3b948c7994916a76fdb0e7849` |
| `gallery-detail-loaded__ja__accessibility5__portrait__iphone__dark` | `3c649a749100857e69d492a5f51575e928736dcdf24b2c4acabbdbeddeab4ebb` | `3c649a749100857e69d492a5f51575e928736dcdf24b2c4acabbdbeddeab4ebb` | `2c203ae7b219e00ff4802d3a6540c605cc9d85775b1c007396c054e6b2b7cfd4` |
| `gallery-detail-loaded__ja__accessibility5__portrait__iphone__light` | `18ba91bcae64d1a1c20221de05536964ba7ec362cf94cb4f0d5538d2eb564c96` | `18ba91bcae64d1a1c20221de05536964ba7ec362cf94cb4f0d5538d2eb564c96` | `4e794565a537525ddaff9a4b5b828b603bf23dbefcdd972db68969b0ea1fe15f` |
| `history-list__en__large__landscape__iphone__dark` | `43ccdc25db2d97c543a4e0b78b685fad01a70ca4bef6c8830a59a14bca7ff85a` | `43ccdc25db2d97c543a4e0b78b685fad01a70ca4bef6c8830a59a14bca7ff85a` | `43ccdc25db2d97c543a4e0b78b685fad01a70ca4bef6c8830a59a14bca7ff85a` |
| `history-list__en__large__landscape__iphone__light` | `b0ec16362d3c24bc83688a7321f5dd510d0bc488c16cced2695a4714bfcc7d8e` | `b0ec16362d3c24bc83688a7321f5dd510d0bc488c16cced2695a4714bfcc7d8e` | `3880d0c67dcaaf3dbd655664e7a090aa59eccd707c81288a3bbeec9b74f9a270` |
| `history-list__en__large__portrait__iphone__dark` | `552b7449f78210b13ba6e8d97932c207ffba7268ab9c50d5458cf4e490b27bdd` | `552b7449f78210b13ba6e8d97932c207ffba7268ab9c50d5458cf4e490b27bdd` | `552b7449f78210b13ba6e8d97932c207ffba7268ab9c50d5458cf4e490b27bdd` |
| `history-list__en__large__portrait__iphone__light` | `32146466e6254c7771c3c74085e3b7d6bf675ab6faf6cb09c24105a473a8d73f` | `32146466e6254c7771c3c74085e3b7d6bf675ab6faf6cb09c24105a473a8d73f` | `a04b0f417d2fc4b5de8201d893f3e38830d4cf00a25d0f5ebcf0f949f9f28a76` |
| `history-list__ja__accessibility5__landscape__iphone__dark` | `4eb8b242b6cd96f2f8e2ab136029dc39f9357df775bda7682ea36b363b8949b5` | `4eb8b242b6cd96f2f8e2ab136029dc39f9357df775bda7682ea36b363b8949b5` | `0cc0ad8b7408e076eadcc3f5a0e6327b17b5dd7b2b3eac152c3c399a35ae2279` |
| `history-list__ja__accessibility5__landscape__iphone__light` | `d3406228c1785941e5d515687fcc1b2202d5fc3a0765bbcaefd0033d652dbf5c` | `d3406228c1785941e5d515687fcc1b2202d5fc3a0765bbcaefd0033d652dbf5c` | `410e01a30c3d5fe7260e8c4688e8d2e552d184b434010e412439381a0eb19cbd` |
| `history-list__ja__accessibility5__portrait__iphone__dark` | `6ad2452af4102ae0be4d3bdd70ef82b532f185870fe853a8b948d08e17476d8a` | `6ad2452af4102ae0be4d3bdd70ef82b532f185870fe853a8b948d08e17476d8a` | `7ccbf2840e5a0ccc0a96821893ab1039e2f8d76f2f6af0fcaa1478d1b4b094d0` |
| `history-list__ja__accessibility5__portrait__iphone__light` | `411ade9e91f24e0af16001d6a54b8e582bb0914ced9eecbfdf67aefffaf3e729` | `411ade9e91f24e0af16001d6a54b8e582bb0914ced9eecbfdf67aefffaf3e729` | `55de67203c67dc1a36b38850b7e7e235381f49c91d70cf637e923d8ba69ee0fd` |
| `home-populated__en__large__landscape__iphone__dark` | `2a305ed1cf888b4e384fa44ffacc9b6b12c7250a0e701271cfbae8d5f1dbc0e2` | `2a305ed1cf888b4e384fa44ffacc9b6b12c7250a0e701271cfbae8d5f1dbc0e2` | `2a305ed1cf888b4e384fa44ffacc9b6b12c7250a0e701271cfbae8d5f1dbc0e2` |
| `home-populated__en__large__landscape__iphone__light` | `af964992e90dab4ad15064d0d1c8b08a5f735e3cc3c3f2abe61a13ff2a7d7be7` | `af964992e90dab4ad15064d0d1c8b08a5f735e3cc3c3f2abe61a13ff2a7d7be7` | `af964992e90dab4ad15064d0d1c8b08a5f735e3cc3c3f2abe61a13ff2a7d7be7` |
| `home-populated__en__large__portrait__iphone__dark` | `25c5849b40878e6cb1083d866fe70816c08a9dffedad168e77ed7de7c5228b2e` | `25c5849b40878e6cb1083d866fe70816c08a9dffedad168e77ed7de7c5228b2e` | `25c5849b40878e6cb1083d866fe70816c08a9dffedad168e77ed7de7c5228b2e` |
| `home-populated__en__large__portrait__iphone__light` | `f724a52f5fca0f237e6a6ae71be163cf1ec42b0f860159711b108168dbf88c20` | `f724a52f5fca0f237e6a6ae71be163cf1ec42b0f860159711b108168dbf88c20` | `f724a52f5fca0f237e6a6ae71be163cf1ec42b0f860159711b108168dbf88c20` |
| `home-populated__ja__accessibility5__landscape__iphone__dark` | `45b1d8a29e8bfa8fd13e32727755d97335e5994157e25e66ef7791eab209ce83` | `45b1d8a29e8bfa8fd13e32727755d97335e5994157e25e66ef7791eab209ce83` | `45b1d8a29e8bfa8fd13e32727755d97335e5994157e25e66ef7791eab209ce83` |
| `home-populated__ja__accessibility5__landscape__iphone__light` | `5981f2c81e101dd6b416e88ee03978b1cf837e575f9d2d0026a45de5b0cdca99` | `5981f2c81e101dd6b416e88ee03978b1cf837e575f9d2d0026a45de5b0cdca99` | `5981f2c81e101dd6b416e88ee03978b1cf837e575f9d2d0026a45de5b0cdca99` |
| `home-populated__ja__accessibility5__portrait__iphone__dark` | `3bf23916b5a58c3181a57ac1d712f2feb95ec28c800fb82628f916dda48f691d` | `3bf23916b5a58c3181a57ac1d712f2feb95ec28c800fb82628f916dda48f691d` | `3bf23916b5a58c3181a57ac1d712f2feb95ec28c800fb82628f916dda48f691d` |
| `home-populated__ja__accessibility5__portrait__iphone__light` | `16a72cb6297ea8abe8b291d8ed7fb18fc0133851ff91c1af34e9fbfa337e79c4` | `16a72cb6297ea8abe8b291d8ed7fb18fc0133851ff91c1af34e9fbfa337e79c4` | `16a72cb6297ea8abe8b291d8ed7fb18fc0133851ff91c1af34e9fbfa337e79c4` |
| `popular-list__en__large__landscape__iphone__dark` | `7b78b0d20a8666e10c4770abca9b5289289173fa4bc0e1b6170aaa0b807cc6e3` | `7b78b0d20a8666e10c4770abca9b5289289173fa4bc0e1b6170aaa0b807cc6e3` | `7b78b0d20a8666e10c4770abca9b5289289173fa4bc0e1b6170aaa0b807cc6e3` |
| `popular-list__en__large__landscape__iphone__light` | `ed6a62b7616e73baacc55f78c741892b476f7c86f2017ed26c9155825442b778` | `ed6a62b7616e73baacc55f78c741892b476f7c86f2017ed26c9155825442b778` | `af90b57a3ab4d571bb92404a8865f85c4e15360987cfe00c425c292df60960da` |
| `popular-list__en__large__portrait__iphone__dark` | `609c2f2755f7eec6f730fe3f7094f84391afcdd40d9443b86ae2901a043484d4` | `609c2f2755f7eec6f730fe3f7094f84391afcdd40d9443b86ae2901a043484d4` | `609c2f2755f7eec6f730fe3f7094f84391afcdd40d9443b86ae2901a043484d4` |
| `popular-list__en__large__portrait__iphone__light` | `024e3b906db13c4b077a8fba7c888a735889009a9d1c1409c58cfc6154d1359d` | `024e3b906db13c4b077a8fba7c888a735889009a9d1c1409c58cfc6154d1359d` | `d9832bd23fbb34b5c4bf5c2eccf55987865602be111e1059ef9768f7078b94f6` |
| `popular-list__ja__accessibility5__landscape__iphone__dark` | `e3d9490e15db65652a259200a4fd2f93843d1964508bf9f51b4c2f6bf49363b1` | `e3d9490e15db65652a259200a4fd2f93843d1964508bf9f51b4c2f6bf49363b1` | `66d7ebcf7f00475f88e23a00072560d18558e58ca54b65b0a7c6dc86088b1b53` |
| `popular-list__ja__accessibility5__landscape__iphone__light` | `1f9b62c91c120df25bc5f074e7731dac30d844bc0a79f6777ec7d864afb7348c` | `1f9b62c91c120df25bc5f074e7731dac30d844bc0a79f6777ec7d864afb7348c` | `4266d594516f2272c3f31ee18d4b8a7b19cd72c8138c3f150def86cd5e2f6431` |
| `popular-list__ja__accessibility5__portrait__iphone__dark` | `8097173ba9717b6e46d34d7b82d66e0364c5e67e898462d218a9d8d2f5843230` | `8097173ba9717b6e46d34d7b82d66e0364c5e67e898462d218a9d8d2f5843230` | `cebd758846534814dc7631e41cea59fc0cdc851667d1404624c7b6c2a0830597` |
| `popular-list__ja__accessibility5__portrait__iphone__light` | `0b020b39e3fa472a44ee40ad18b83628668874355b5011be24195f2f6b183972` | `0b020b39e3fa472a44ee40ad18b83628668874355b5011be24195f2f6b183972` | `9c24694f3cb041987914f33e2a9038aa23518d7dfdfdd953ab64d9910ea8d043` |
| `quick-search-list__en__large__landscape__iphone__dark` | `10796b567ad83668bddc35a9021ff65647828906d2b894ec0d38e8b88cbf90a4` | `10796b567ad83668bddc35a9021ff65647828906d2b894ec0d38e8b88cbf90a4` | `10796b567ad83668bddc35a9021ff65647828906d2b894ec0d38e8b88cbf90a4` |
| `quick-search-list__en__large__landscape__iphone__light` | `38a0afd2b2425ba442333a515502deaff1e62a0b90ec44d40882b85e0936f034` | `38a0afd2b2425ba442333a515502deaff1e62a0b90ec44d40882b85e0936f034` | `38a0afd2b2425ba442333a515502deaff1e62a0b90ec44d40882b85e0936f034` |
| `quick-search-list__en__large__portrait__iphone__dark` | `895608005667c3abd4b320779836512ed99c537e81ee72176c005e6ea1fbd0f8` | `895608005667c3abd4b320779836512ed99c537e81ee72176c005e6ea1fbd0f8` | `92d6d49ea2bd68b6ada15e897524311e0b2debb1947ca67545d4f5fe7747cfc5` |
| `quick-search-list__en__large__portrait__iphone__light` | `b8f62c4fcaf33a8eb9da0c978e7925d240f22ac33f1255bc29aa7f75234f0dbb` | `b8f62c4fcaf33a8eb9da0c978e7925d240f22ac33f1255bc29aa7f75234f0dbb` | `54e0fe7e0d3f4edd3d037431991236d99726fcd145832c83ba09a705dea9ba3f` |
| `quick-search-list__ja__accessibility5__landscape__iphone__dark` | `25ae9675243d4bc162008e818e5b5b3ae986aa06d80698b358631aeb8c5c8890` | `25ae9675243d4bc162008e818e5b5b3ae986aa06d80698b358631aeb8c5c8890` | `25ae9675243d4bc162008e818e5b5b3ae986aa06d80698b358631aeb8c5c8890` |
| `quick-search-list__ja__accessibility5__landscape__iphone__light` | `7d35190ee5fc2520eac05631560199edfa97e010caad6f1fed725b8aa4e1b8ca` | `7d35190ee5fc2520eac05631560199edfa97e010caad6f1fed725b8aa4e1b8ca` | `ca0eadf66868962d43d55134bff80680cce6f9baec36e7218555891ed33382c8` |
| `quick-search-list__ja__accessibility5__portrait__iphone__dark` | `19d0f1b2b7621b681661ecf04c23b31c3f6ed404bed2bc3c62b806c139755247` | `19d0f1b2b7621b681661ecf04c23b31c3f6ed404bed2bc3c62b806c139755247` | `2ff72887c6b4ce4c6662030bded0e86b8212b878fa515df0045d3e60746d34f1` |
| `quick-search-list__ja__accessibility5__portrait__iphone__light` | `fdccde35298d077d3d3861e1da42d4f86b788ee47dbae9ce95f22bfb3a78fc19` | `fdccde35298d077d3d3861e1da42d4f86b788ee47dbae9ce95f22bfb3a78fc19` | `bc9c246aa90d22817525c8bab5a04f82168bd3b33631fcee044d875d61d08931` |
| `reader-horizontal__en__large__landscape__iphone__dark` | `3903a95caae50041bb4f935375ae75af8167ca87a7cc840df782223bfa5dbfe5` | `3903a95caae50041bb4f935375ae75af8167ca87a7cc840df782223bfa5dbfe5` | `3903a95caae50041bb4f935375ae75af8167ca87a7cc840df782223bfa5dbfe5` |
| `reader-horizontal__en__large__landscape__iphone__light` | `3effbfd552b7cd80f975322007a2cf511a6f41810f8a318beadc6273599326e8` | `3effbfd552b7cd80f975322007a2cf511a6f41810f8a318beadc6273599326e8` | `3effbfd552b7cd80f975322007a2cf511a6f41810f8a318beadc6273599326e8` |
| `reader-horizontal__en__large__portrait__iphone__dark` | `9e41610fba85ecacf43d4252465819a50c2726533849e7c5517ae4ab17ef03a0` | `9e41610fba85ecacf43d4252465819a50c2726533849e7c5517ae4ab17ef03a0` | `9e41610fba85ecacf43d4252465819a50c2726533849e7c5517ae4ab17ef03a0` |
| `reader-horizontal__en__large__portrait__iphone__light` | `89971db686071e006be7ca9c2bbee83b96168ef07aaec67ba07bdf139421a62d` | `89971db686071e006be7ca9c2bbee83b96168ef07aaec67ba07bdf139421a62d` | `89971db686071e006be7ca9c2bbee83b96168ef07aaec67ba07bdf139421a62d` |
| `reader-horizontal__ja__accessibility5__landscape__iphone__dark` | `3903a95caae50041bb4f935375ae75af8167ca87a7cc840df782223bfa5dbfe5` | `3903a95caae50041bb4f935375ae75af8167ca87a7cc840df782223bfa5dbfe5` | `3903a95caae50041bb4f935375ae75af8167ca87a7cc840df782223bfa5dbfe5` |
| `reader-horizontal__ja__accessibility5__landscape__iphone__light` | `3effbfd552b7cd80f975322007a2cf511a6f41810f8a318beadc6273599326e8` | `3effbfd552b7cd80f975322007a2cf511a6f41810f8a318beadc6273599326e8` | `3effbfd552b7cd80f975322007a2cf511a6f41810f8a318beadc6273599326e8` |
| `reader-horizontal__ja__accessibility5__portrait__iphone__dark` | `9e41610fba85ecacf43d4252465819a50c2726533849e7c5517ae4ab17ef03a0` | `9e41610fba85ecacf43d4252465819a50c2726533849e7c5517ae4ab17ef03a0` | `9e41610fba85ecacf43d4252465819a50c2726533849e7c5517ae4ab17ef03a0` |
| `reader-horizontal__ja__accessibility5__portrait__iphone__light` | `89971db686071e006be7ca9c2bbee83b96168ef07aaec67ba07bdf139421a62d` | `89971db686071e006be7ca9c2bbee83b96168ef07aaec67ba07bdf139421a62d` | `89971db686071e006be7ca9c2bbee83b96168ef07aaec67ba07bdf139421a62d` |
| `reader-vertical__en__large__landscape__iphone__dark` | `566000d96780e386032602844b60a3e02418aa578d0d5a99c381df440f4b9b34` | `566000d96780e386032602844b60a3e02418aa578d0d5a99c381df440f4b9b34` | `566000d96780e386032602844b60a3e02418aa578d0d5a99c381df440f4b9b34` |
| `reader-vertical__en__large__landscape__iphone__light` | `566000d96780e386032602844b60a3e02418aa578d0d5a99c381df440f4b9b34` | `566000d96780e386032602844b60a3e02418aa578d0d5a99c381df440f4b9b34` | `566000d96780e386032602844b60a3e02418aa578d0d5a99c381df440f4b9b34` |
| `reader-vertical__en__large__portrait__iphone__dark` | `ada53d1affc553cfe326760d23c1efe01764b3bd51fcba36fd20409a574ef21f` | `ada53d1affc553cfe326760d23c1efe01764b3bd51fcba36fd20409a574ef21f` | `ada53d1affc553cfe326760d23c1efe01764b3bd51fcba36fd20409a574ef21f` |
| `reader-vertical__en__large__portrait__iphone__light` | `ada53d1affc553cfe326760d23c1efe01764b3bd51fcba36fd20409a574ef21f` | `ada53d1affc553cfe326760d23c1efe01764b3bd51fcba36fd20409a574ef21f` | `ada53d1affc553cfe326760d23c1efe01764b3bd51fcba36fd20409a574ef21f` |
| `reader-vertical__ja__accessibility5__landscape__iphone__dark` | `566000d96780e386032602844b60a3e02418aa578d0d5a99c381df440f4b9b34` | `566000d96780e386032602844b60a3e02418aa578d0d5a99c381df440f4b9b34` | `566000d96780e386032602844b60a3e02418aa578d0d5a99c381df440f4b9b34` |
| `reader-vertical__ja__accessibility5__landscape__iphone__light` | `566000d96780e386032602844b60a3e02418aa578d0d5a99c381df440f4b9b34` | `566000d96780e386032602844b60a3e02418aa578d0d5a99c381df440f4b9b34` | `566000d96780e386032602844b60a3e02418aa578d0d5a99c381df440f4b9b34` |
| `reader-vertical__ja__accessibility5__portrait__iphone__dark` | `ada53d1affc553cfe326760d23c1efe01764b3bd51fcba36fd20409a574ef21f` | `ada53d1affc553cfe326760d23c1efe01764b3bd51fcba36fd20409a574ef21f` | `ada53d1affc553cfe326760d23c1efe01764b3bd51fcba36fd20409a574ef21f` |
| `reader-vertical__ja__accessibility5__portrait__iphone__light` | `ada53d1affc553cfe326760d23c1efe01764b3bd51fcba36fd20409a574ef21f` | `ada53d1affc553cfe326760d23c1efe01764b3bd51fcba36fd20409a574ef21f` | `ada53d1affc553cfe326760d23c1efe01764b3bd51fcba36fd20409a574ef21f` |
| `search-root-history__en__large__landscape__iphone__dark` | `4932fe72a49e0963a5f0d60d3ef27b151e3beccf893da75c77ac9b8c0723759c` | `4932fe72a49e0963a5f0d60d3ef27b151e3beccf893da75c77ac9b8c0723759c` | `4932fe72a49e0963a5f0d60d3ef27b151e3beccf893da75c77ac9b8c0723759c` |
| `search-root-history__en__large__landscape__iphone__light` | `7ce4828c4db76c349fa360fe24151eef940fdb2da4a6bf850912b6429cce7c66` | `7ce4828c4db76c349fa360fe24151eef940fdb2da4a6bf850912b6429cce7c66` | `7ce4828c4db76c349fa360fe24151eef940fdb2da4a6bf850912b6429cce7c66` |
| `search-root-history__en__large__portrait__iphone__dark` | `f97c5e0c045cc5ea3ab9bf25e0eb9f910f9a57e002e6dba266432ae583664fe9` | `f97c5e0c045cc5ea3ab9bf25e0eb9f910f9a57e002e6dba266432ae583664fe9` | `f97c5e0c045cc5ea3ab9bf25e0eb9f910f9a57e002e6dba266432ae583664fe9` |
| `search-root-history__en__large__portrait__iphone__light` | `61d71b81ea40bde74c08ff1d4031ba7faac4bf736207b955b828be380c1f7de6` | `61d71b81ea40bde74c08ff1d4031ba7faac4bf736207b955b828be380c1f7de6` | `61d71b81ea40bde74c08ff1d4031ba7faac4bf736207b955b828be380c1f7de6` |
| `search-root-history__ja__accessibility5__landscape__iphone__dark` | `d151ba5c9e683031f97822f1e437345abf8830aeaec55276c8afae4632001a8f` | `d151ba5c9e683031f97822f1e437345abf8830aeaec55276c8afae4632001a8f` | `3807dfebd8fd221f5012029ac92129da9115738fe745e4ac11ac007495ae2c42` |
| `search-root-history__ja__accessibility5__landscape__iphone__light` | `c6d33cd6ae0e183f4a62c70adec09f4831c7f258666e25baa282d77e4594ff37` | `c6d33cd6ae0e183f4a62c70adec09f4831c7f258666e25baa282d77e4594ff37` | `a96d8d3335717e1f07bfdd5fd2f322bfbddded2e535dfb3e301306536067f653` |
| `search-root-history__ja__accessibility5__portrait__iphone__dark` | `cb8764e58f5884218fd76e6893cee9922dd3a452d26c00af761cc649f41f4def` | `cb8764e58f5884218fd76e6893cee9922dd3a452d26c00af761cc649f41f4def` | `5ca374131f96fe74bf7292be59d0e05c7aa4dc2faadf9d51a94a3d0b2dfcd145` |
| `search-root-history__ja__accessibility5__portrait__iphone__light` | `d847f3415a1e757eb6f38aeaabaf449419021d0cc1b9781063edec6b17c12a55` | `d847f3415a1e757eb6f38aeaabaf449419021d0cc1b9781063edec6b17c12a55` | `2d15bc4786ecf601a6e2e1699ada40fdc8924a62d10e150aebf8fc87ce95a7ca` |
| `settings-login-empty__en__large__landscape__iphone__dark` | `3641c5b79adba061619694a2ed41f180f2a96081fe10159b9cb62cc99db51e34` | `3641c5b79adba061619694a2ed41f180f2a96081fe10159b9cb62cc99db51e34` | `3641c5b79adba061619694a2ed41f180f2a96081fe10159b9cb62cc99db51e34` |
| `settings-login-empty__en__large__landscape__iphone__light` | `67b822820b592904f2f5970506d1a372ec2788a4b676e5f92fb9aeb7250f0372` | `67b822820b592904f2f5970506d1a372ec2788a4b676e5f92fb9aeb7250f0372` | `d6a800115de24a2eb6575c9c17affd434f3519646e8cb7a9963cab3b48fba6e4` |
| `settings-login-empty__en__large__portrait__iphone__dark` | `67ee7ceb645b28885eecfb142df6c7186c3113cf1d9f23cfabf0e6597eabcfa3` | `67ee7ceb645b28885eecfb142df6c7186c3113cf1d9f23cfabf0e6597eabcfa3` | `4e7af2063ac1d2add23334fb9c8cf4d232513e5a94edf02edda171cae9a35cbd` |
| `settings-login-empty__en__large__portrait__iphone__light` | `997738743a4fa8e644980f3ce1be5052774265377255465cfa9c548af0fceec8` | `997738743a4fa8e644980f3ce1be5052774265377255465cfa9c548af0fceec8` | `997738743a4fa8e644980f3ce1be5052774265377255465cfa9c548af0fceec8` |
| `settings-login-empty__ja__accessibility5__landscape__iphone__dark` | `bf4b18fd34864ec3a7d3515f28016ab69e148ecb866c4a20d6c496a5b496efb1` | `bf4b18fd34864ec3a7d3515f28016ab69e148ecb866c4a20d6c496a5b496efb1` | `bf4b18fd34864ec3a7d3515f28016ab69e148ecb866c4a20d6c496a5b496efb1` |
| `settings-login-empty__ja__accessibility5__landscape__iphone__light` | `8fbdc30690b050b75a4bd9ba0f6affe6d9c7a539bbb1e0fa16f8e04a71f24e1c` | `8fbdc30690b050b75a4bd9ba0f6affe6d9c7a539bbb1e0fa16f8e04a71f24e1c` | `b43a680f4de6c85603c48236dbb9f7d3860e5adadb248716a2c798c0b8a335c4` |
| `settings-login-empty__ja__accessibility5__portrait__iphone__dark` | `d0a11097204620a6d03c193fa70c9d01678cbbd0a08c0edf1f66ead9218d18f5` | `d0a11097204620a6d03c193fa70c9d01678cbbd0a08c0edf1f66ead9218d18f5` | `faa8d05ddab282a3f9080cfb1a38cf8426dbacf313bcefcef1588a90eaa85be3` |
| `settings-login-empty__ja__accessibility5__portrait__iphone__light` | `c1a76155c134394fb99888ac57bbdd4df4b20d20350603325de106bd8b4a75b8` | `c1a76155c134394fb99888ac57bbdd4df4b20d20350603325de106bd8b4a75b8` | `5ab4d5a33360f3ed977183d711633e053ee4c561edff1b9962ad37cff7895330` |
| `settings-pages-general-basic__en__large__landscape__iphone__dark` | `bbac176769e1f46c0ea005a2a9e678a693420d9b16b40ee79503fecc42270942` | `bbac176769e1f46c0ea005a2a9e678a693420d9b16b40ee79503fecc42270942` | `bbac176769e1f46c0ea005a2a9e678a693420d9b16b40ee79503fecc42270942` |
| `settings-pages-general-basic__en__large__landscape__iphone__light` | `0416ba32da558ff33da91a127596b570daa96837f92a142177e99686881b710e` | `0416ba32da558ff33da91a127596b570daa96837f92a142177e99686881b710e` | `0416ba32da558ff33da91a127596b570daa96837f92a142177e99686881b710e` |
| `settings-pages-general-basic__en__large__portrait__iphone__dark` | `93aa5a296242f081db179d5c16c531c8d86a0886f1af3a63febe6c939a2f4401` | `93aa5a296242f081db179d5c16c531c8d86a0886f1af3a63febe6c939a2f4401` | `93aa5a296242f081db179d5c16c531c8d86a0886f1af3a63febe6c939a2f4401` |
| `settings-pages-general-basic__en__large__portrait__iphone__light` | `ac8153fbecbdb0c07af948e0b6a891e0775d4d135b927f847168cb6be9b1a78c` | `ac8153fbecbdb0c07af948e0b6a891e0775d4d135b927f847168cb6be9b1a78c` | `3660cca342e07caad2baab19cd9a407700c1062786edaa20bf716b976e5191d2` |
| `settings-pages-general-basic__ja__accessibility5__landscape__iphone__dark` | `33f0b2566e2be4e1deb3be417bc8f9ba3fc2cf70c3fb1b4a2dc89ee372788e6f` | `33f0b2566e2be4e1deb3be417bc8f9ba3fc2cf70c3fb1b4a2dc89ee372788e6f` | `33f0b2566e2be4e1deb3be417bc8f9ba3fc2cf70c3fb1b4a2dc89ee372788e6f` |
| `settings-pages-general-basic__ja__accessibility5__landscape__iphone__light` | `e410c2fd3f2e99e248594cf6669ada32b67381bce44ffeed4cdf9a03b72430e0` | `e410c2fd3f2e99e248594cf6669ada32b67381bce44ffeed4cdf9a03b72430e0` | `c733b99645cada6d2c5dd141a52b01a9979bbef0da478d2595f6bcfb049b89e3` |
| `settings-pages-general-basic__ja__accessibility5__portrait__iphone__dark` | `04f2b5cfd3c3f3d1be30da58af4314be8dada6746179a9d6d3966475ebb6fa93` | `04f2b5cfd3c3f3d1be30da58af4314be8dada6746179a9d6d3966475ebb6fa93` | `04f2b5cfd3c3f3d1be30da58af4314be8dada6746179a9d6d3966475ebb6fa93` |
| `settings-pages-general-basic__ja__accessibility5__portrait__iphone__light` | `862ca7f265b6e2f48f63e9908d8bb8db217213a16d4befea28cfe2e63180cc12` | `862ca7f265b6e2f48f63e9908d8bb8db217213a16d4befea28cfe2e63180cc12` | `862ca7f265b6e2f48f63e9908d8bb8db217213a16d4befea28cfe2e63180cc12` |
| `settings-root__en__large__landscape__iphone__dark` | `081fdfbb724e3b897e52695f086434c7443492599922a7ff4182274c008c0f78` | `081fdfbb724e3b897e52695f086434c7443492599922a7ff4182274c008c0f78` | `081fdfbb724e3b897e52695f086434c7443492599922a7ff4182274c008c0f78` |
| `settings-root__en__large__landscape__iphone__light` | `adba9194434e5c7e8e6322e6e7166be9e6fc1402caf0344362842b29af57e8c5` | `adba9194434e5c7e8e6322e6e7166be9e6fc1402caf0344362842b29af57e8c5` | `adba9194434e5c7e8e6322e6e7166be9e6fc1402caf0344362842b29af57e8c5` |
| `settings-root__en__large__portrait__iphone__dark` | `92c3d6124d2f06d810a5c3c343ef0fef2259f3bee4ae1c9c610ea315f34a6764` | `92c3d6124d2f06d810a5c3c343ef0fef2259f3bee4ae1c9c610ea315f34a6764` | `92c3d6124d2f06d810a5c3c343ef0fef2259f3bee4ae1c9c610ea315f34a6764` |
| `settings-root__en__large__portrait__iphone__light` | `098431aaa13f5e502c2fc6badd931a10fb4859142c7f141e86adf68d57754991` | `098431aaa13f5e502c2fc6badd931a10fb4859142c7f141e86adf68d57754991` | `098431aaa13f5e502c2fc6badd931a10fb4859142c7f141e86adf68d57754991` |
| `settings-root__ja__accessibility5__landscape__iphone__dark` | `89bb09784755b43ea742fb34a4b87efafb4f800d70598c292181232332081161` | `89bb09784755b43ea742fb34a4b87efafb4f800d70598c292181232332081161` | `89bb09784755b43ea742fb34a4b87efafb4f800d70598c292181232332081161` |
| `settings-root__ja__accessibility5__landscape__iphone__light` | `118dd5499295f7ee6621f9d25bc9b8bd7e3517e4cd0d09816131756b0d45d36f` | `118dd5499295f7ee6621f9d25bc9b8bd7e3517e4cd0d09816131756b0d45d36f` | `118dd5499295f7ee6621f9d25bc9b8bd7e3517e4cd0d09816131756b0d45d36f` |
| `settings-root__ja__accessibility5__portrait__iphone__dark` | `1a66eeae3c26278990c7990bd83babda1db821d3ec5921f1c8ccb3ce815ba0ea` | `1a66eeae3c26278990c7990bd83babda1db821d3ec5921f1c8ccb3ce815ba0ea` | `1a66eeae3c26278990c7990bd83babda1db821d3ec5921f1c8ccb3ce815ba0ea` |
| `settings-root__ja__accessibility5__portrait__iphone__light` | `52ced13b54b4007776ce58893ac16de3b8fae2b5693a88d6d0dc28cd7628495e` | `52ced13b54b4007776ce58893ac16de3b8fae2b5693a88d6d0dc28cd7628495e` | `52ced13b54b4007776ce58893ac16de3b8fae2b5693a88d6d0dc28cd7628495e` |
| `toplists-list__en__large__landscape__iphone__dark` | `9dbbda6f86606075c5a97d3950243b44d706433007fb4f76588caa02f040123f` | `9dbbda6f86606075c5a97d3950243b44d706433007fb4f76588caa02f040123f` | `9dbbda6f86606075c5a97d3950243b44d706433007fb4f76588caa02f040123f` |
| `toplists-list__en__large__landscape__iphone__light` | `538a59b73857fffcd9e7ae953b0f58e00322ec6eafa4eab300d723ad97339f17` | `538a59b73857fffcd9e7ae953b0f58e00322ec6eafa4eab300d723ad97339f17` | `f373e9a9f5d8c17d21dba3d1a903a106d5180a36148288102d263387665dc7e0` |
| `toplists-list__en__large__portrait__iphone__dark` | `f50d793f649bf5d97b1dab9be9bb0879c51c5086e60829df82bc35d31d8e4975` | `f50d793f649bf5d97b1dab9be9bb0879c51c5086e60829df82bc35d31d8e4975` | `f50d793f649bf5d97b1dab9be9bb0879c51c5086e60829df82bc35d31d8e4975` |
| `toplists-list__en__large__portrait__iphone__light` | `fcd9f0f67aaf3a382ab7b3294b916582a5702a4869af328d5adce24c49f7672b` | `fcd9f0f67aaf3a382ab7b3294b916582a5702a4869af328d5adce24c49f7672b` | `c9b758ab04141b3336c69cebbda1fbcaf71197e56140a6728537ee309f291beb` |
| `toplists-list__ja__accessibility5__landscape__iphone__dark` | `1b8f2c3eb7db3eb14854f2b89e65b0c351493277f51eed86af8bae100709d438` | `1b8f2c3eb7db3eb14854f2b89e65b0c351493277f51eed86af8bae100709d438` | `75f890a7302c62b81922a2f0675d77bf81ee9bab78ac4f6f80ab14876ccd5001` |
| `toplists-list__ja__accessibility5__landscape__iphone__light` | `3417ad1c98e5792ba23c8398482867a5f08e584b5bcf8d6593bd8450870108b5` | `3417ad1c98e5792ba23c8398482867a5f08e584b5bcf8d6593bd8450870108b5` | `30e798388d7d5b8c2d52bab44d48868e951423b75e0c6ae24ec5b37c417c9647` |
| `toplists-list__ja__accessibility5__portrait__iphone__dark` | `001a816f727e18fa92a37059e6f5623dbf4519f0ef83e556239c506840fd4a54` | `001a816f727e18fa92a37059e6f5623dbf4519f0ef83e556239c506840fd4a54` | `cfd8972acfab6148e4d2b9d0f9407fce08362fd840b69bfe27b7ec4bebc381af` |
| `toplists-list__ja__accessibility5__portrait__iphone__light` | `2cd67239db54bf664f831d26aea493fb8ce32411448c3b18e9a0214ac4eb4862` | `2cd67239db54bf664f831d26aea493fb8ce32411448c3b18e9a0214ac4eb4862` | `d580a53f05e5ef590d1070e7a09636bb5009856bf9e8f54ffe7fe8d438fec4ae` |
| `watched-signed-out__en__large__landscape__iphone__dark` | `c025eb408af3f7c065826e1c9c1d1989393a029f4daf4eece18ac9029ea5dd61` | `c025eb408af3f7c065826e1c9c1d1989393a029f4daf4eece18ac9029ea5dd61` | `c025eb408af3f7c065826e1c9c1d1989393a029f4daf4eece18ac9029ea5dd61` |
| `watched-signed-out__en__large__landscape__iphone__light` | `7a75332f8a3ccd54bde117e824bd4dd54f922044409372264533948088de1df8` | `7a75332f8a3ccd54bde117e824bd4dd54f922044409372264533948088de1df8` | `7a75332f8a3ccd54bde117e824bd4dd54f922044409372264533948088de1df8` |
| `watched-signed-out__en__large__portrait__iphone__dark` | `0542c158c57b4dc1c42899210db40663100efb38288bda20cb314034f6db235a` | `0542c158c57b4dc1c42899210db40663100efb38288bda20cb314034f6db235a` | `0542c158c57b4dc1c42899210db40663100efb38288bda20cb314034f6db235a` |
| `watched-signed-out__en__large__portrait__iphone__light` | `aeef05676e659915f9c1e1b4b1113a625e2c3bc7ab860b3f3b85dc227aff5c3f` | `aeef05676e659915f9c1e1b4b1113a625e2c3bc7ab860b3f3b85dc227aff5c3f` | `aeef05676e659915f9c1e1b4b1113a625e2c3bc7ab860b3f3b85dc227aff5c3f` |
| `watched-signed-out__ja__accessibility5__landscape__iphone__dark` | `d643b7d26380d464e4e78b336a5c2510da36e740981030a612169c2a021de346` | `d643b7d26380d464e4e78b336a5c2510da36e740981030a612169c2a021de346` | `217b5156078610dbf4243371fa66f7582c00745e16b01470df77052d4f10f2ee` |
| `watched-signed-out__ja__accessibility5__landscape__iphone__light` | `fc319ad9e2a890bf3924164c39c09c13fbdfd3902ac90ae1778092ebd2c5c5c1` | `fc319ad9e2a890bf3924164c39c09c13fbdfd3902ac90ae1778092ebd2c5c5c1` | `eb97e7f877f134c4064e5a57528d6cff6e60446694c0341ebdf0a37944cabb48` |
| `watched-signed-out__ja__accessibility5__portrait__iphone__dark` | `3a01255c7490af08aa2636a6a8aa53b1d58735d52b0ee48d363136371e62daab` | `3a01255c7490af08aa2636a6a8aa53b1d58735d52b0ee48d363136371e62daab` | `86a73138a5726fe1c848a1f3e44a680ed696d7afe86dab61045a4b4c64997682` |
| `watched-signed-out__ja__accessibility5__portrait__iphone__light` | `5b172e6391cdde716a6d478f5d6ad3b76aac539f2dbd50e130acf12217d3e570` | `5b172e6391cdde716a6d478f5d6ad3b76aac539f2dbd50e130acf12217d3e570` | `08bca0ac1226415b78b1b3f912f3f312dca6c67c1d951b8567b7e0df242a7572` |

### pad

| key | before | after | baseline2 |
| --- | --- | --- | --- |
| `app-wide-error-info__en__large__portrait__ipad__dark` | `aad2ce24fa0749c5282c2c0445db88779eef184f1f1aa56ba5f6a519bdc72362` | `aad2ce24fa0749c5282c2c0445db88779eef184f1f1aa56ba5f6a519bdc72362` | `aad2ce24fa0749c5282c2c0445db88779eef184f1f1aa56ba5f6a519bdc72362` |
| `app-wide-error-info__en__large__portrait__ipad__light` | `a2afa2ce43e09d428bebf7d7a5368026c9495bd7a619587beb8f5b04884143f9` | `a2afa2ce43e09d428bebf7d7a5368026c9495bd7a619587beb8f5b04884143f9` | `4bbd093b43361a0975b7ad21c983540b73b1587d9f1582739a79d3de6144dac3` |
| `blocked-users-filled__en__large__portrait__ipad__dark` | `3e20eaa14442fa6318f4726ec3b2515280cae69362146c07e209d21948a4bcad` | `3e20eaa14442fa6318f4726ec3b2515280cae69362146c07e209d21948a4bcad` | `3e20eaa14442fa6318f4726ec3b2515280cae69362146c07e209d21948a4bcad` |
| `blocked-users-filled__en__large__portrait__ipad__light` | `93f2e91ff40c2a6e5e95e2ff00b4de761dae3224723ee890df255f3a93b80ca5` | `93f2e91ff40c2a6e5e95e2ff00b4de761dae3224723ee890df255f3a93b80ca5` | `93f2e91ff40c2a6e5e95e2ff00b4de761dae3224723ee890df255f3a93b80ca5` |
| `comments-list__en__large__portrait__ipad__dark` | `e625094b9ed7e0677656aabb56e2bcd739777a6975bb97e214e4723cb42b9564` | `e625094b9ed7e0677656aabb56e2bcd739777a6975bb97e214e4723cb42b9564` | `e625094b9ed7e0677656aabb56e2bcd739777a6975bb97e214e4723cb42b9564` |
| `comments-list__en__large__portrait__ipad__light` | `cbd15de7f1e93a0ab43a7e7ee47ad3f21c5f7c66e7ef14c6c1dda04d22e82f08` | `cbd15de7f1e93a0ab43a7e7ee47ad3f21c5f7c66e7ef14c6c1dda04d22e82f08` | `cbd15de7f1e93a0ab43a7e7ee47ad3f21c5f7c66e7ef14c6c1dda04d22e82f08` |
| `detail-pages-archives__en__large__portrait__ipad__dark` | `a1fb5e77b7c325edaafd3339582a01845a81a7b7171ce73d5a7001a85b8c4a0b` | `a1fb5e77b7c325edaafd3339582a01845a81a7b7171ce73d5a7001a85b8c4a0b` | `705be3dc15eb731d0c8af80f6250990ec6059f5988ebefaf18c52b70788d5f49` |
| `detail-pages-archives__en__large__portrait__ipad__light` | `8f74536791fc088bf66506378543dea6e0a6a7d99602473bf018948874b589ed` | `8f74536791fc088bf66506378543dea6e0a6a7d99602473bf018948874b589ed` | `e8ae9454aa37c48ee89e60108f2ac446e5b3933343683600e08c8f0c9d96b980` |
| `detail-pages-torrents__en__large__portrait__ipad__dark` | `ee8a734ffc080ab75fa6d302ab24052c205c41a91da59c34ce6405d8c1c755b6` | `ee8a734ffc080ab75fa6d302ab24052c205c41a91da59c34ce6405d8c1c755b6` | `6aa16ec5dd28395cc48567b18cebd154a6e8513c9be4473159942f75078cccc0` |
| `detail-pages-torrents__en__large__portrait__ipad__light` | `e5746815573506f9fe9d60c620b593e9be623ad7e43cc1641f286c78db5c901c` | `e5746815573506f9fe9d60c620b593e9be623ad7e43cc1641f286c78db5c901c` | `3c3affc2d3bbf7b74b45b57a0a0c5fb31d9e6d248b99a996e9fd0051e99a5aaa` |
| `downloads-list__en__large__portrait__ipad__dark` | `1b551c1ff0337d21ee07ab3ba3c29f9624858bc53941420269f1bc85f2de8d2f` | `22f53fa2204f5be1cf9400ef22aa0379d2545b96db55304efceee27f120d8109` | `38e941a12969937d0752a8807a1e805462bbfd70d69a33ba0bdf14a2eea19878` |
| `downloads-list__en__large__portrait__ipad__light` | `0b373eebabd21db4fb42cd8746509b2eae72ad9ba815bb92c7bc865e45ebb2ee` | `0e411e78d5d87404e900dd10c8fde7dd7872040e5d5b9c76b1b9b6fe24eaee5f` | `014003aea6acf42c3d57e47c4a2b8fb87204fe23c34a5e804059aa9c11766aa6` |
| `favorites-list__en__large__portrait__ipad__dark` | `85ffb8c55e21a901717b1037565f8cfc70c41128af87ceee05ef821d761e7c0c` | `864c7c5ba74ac78f21809b1d9ec6d9c26c93b5ca402125450c6a6c8f7dafedd5` | `aaebe6cc72c1aebd9a0fd17aa5bf0c916dba276ae3760b4d3c63cfb9f06b14e1` |
| `favorites-list__en__large__portrait__ipad__light` | `1f2bcf18427e9381f5ce9b4a5ce614a8f32b8f44a66939d0c4a55b97b7360ecf` | `a8e1dfeba8e4858cc8b01f5b6c97948654618b7b1286cc88e9659325bb84cda6` | `01b8d5fbb10194d44b0236e4316b1a9ea3e15e0f1500d0685da30ea24d34ffc9` |
| `front-page-list__en__large__portrait__ipad__dark` | `02ffbf0ea80df775d4c42b79e9f75071c46c7f4ce47ca155160859b7a9b28d73` | `02ffbf0ea80df775d4c42b79e9f75071c46c7f4ce47ca155160859b7a9b28d73` | `853980d6f72edf99a19a3e3f9b83a8430ac5b0711f1cbd983d4a15985e4eaaeb` |
| `front-page-list__en__large__portrait__ipad__light` | `cff034d394ff36183f161c3a9ba4b6335098b69614149e923e8440938a906a43` | `cff034d394ff36183f161c3a9ba4b6335098b69614149e923e8440938a906a43` | `5b47fcd17d7537f65d952769a78b44884e950eab2a1029f5bc8ee83bb6655808` |
| `gallery-detail-loaded__en__large__portrait__ipad__dark` | `8b5997a27edeafe1f62a7f8b31cc45e6ac2f8d272f3b24d16444317be57569a2` | `8b5997a27edeafe1f62a7f8b31cc45e6ac2f8d272f3b24d16444317be57569a2` | `f6fc41ffe11539c6025de6a24733fac04b9a4b7e0985a5ebb6c0866f9b40aeb8` |
| `gallery-detail-loaded__en__large__portrait__ipad__light` | `0dfcc0dac6fada771059f32003451536674b46ede71c37827597ffeb9c060657` | `0dfcc0dac6fada771059f32003451536674b46ede71c37827597ffeb9c060657` | `0f8498d32e15278245130c207a7d0dd3159352d3484329ddf71282582c2d744c` |
| `history-list__en__large__portrait__ipad__dark` | `312e7e2b35e344cb043ad3af2e1412aa0dfa5bc319e20db9b219816a804794cd` | `312e7e2b35e344cb043ad3af2e1412aa0dfa5bc319e20db9b219816a804794cd` | `98933bc570264f780b5d32795889accf74d50f10a7a4bf29b8e66d81d61d97b3` |
| `history-list__en__large__portrait__ipad__light` | `500d4e1281abc01fd71a18aa28cf30c74cdb59ea95fdb795532070a3d0ec8ae1` | `500d4e1281abc01fd71a18aa28cf30c74cdb59ea95fdb795532070a3d0ec8ae1` | `c731d924adae20da3bf67c200c0c094295e7734e6e3f0313224f7b316ee4cffa` |
| `home-populated__en__large__portrait__ipad__dark` | `f0f9e451e536a14abf3406a7cd518d329618998211956cda9b167b0e32e0088f` | `f0f9e451e536a14abf3406a7cd518d329618998211956cda9b167b0e32e0088f` | `f0f9e451e536a14abf3406a7cd518d329618998211956cda9b167b0e32e0088f` |
| `home-populated__en__large__portrait__ipad__light` | `51c3a42b02b4be435625d812f555ee2c9cab63feeba8cd8d5d52c910f8c968b0` | `51c3a42b02b4be435625d812f555ee2c9cab63feeba8cd8d5d52c910f8c968b0` | `51c3a42b02b4be435625d812f555ee2c9cab63feeba8cd8d5d52c910f8c968b0` |
| `popular-list__en__large__portrait__ipad__dark` | `3a053f995fb7d11bd221c78b57baf2af6758c5d88f401a8eca9e058c7ebbfc49` | `3a053f995fb7d11bd221c78b57baf2af6758c5d88f401a8eca9e058c7ebbfc49` | `f2a43c9df67fc23c7f8858254e3d8dadb6113bc79838c478f3a7805a37c2131d` |
| `popular-list__en__large__portrait__ipad__light` | `17058c9f6546f3045a9d3b3e5b70c433feb8a158cdc3f48c70398ef88e1b0c26` | `17058c9f6546f3045a9d3b3e5b70c433feb8a158cdc3f48c70398ef88e1b0c26` | `ae63b457c4dec59b766f8e364183cc28c84021494b589c35cd0be38cb7ecbf19` |
| `quick-search-list__en__large__portrait__ipad__dark` | `943cb9d4eb384269e48c3b3b060a28bd1ddf558a08fdf1ff9ae4ff7af431f8be` | `943cb9d4eb384269e48c3b3b060a28bd1ddf558a08fdf1ff9ae4ff7af431f8be` | `943cb9d4eb384269e48c3b3b060a28bd1ddf558a08fdf1ff9ae4ff7af431f8be` |
| `quick-search-list__en__large__portrait__ipad__light` | `be0840d23a9d5ef2433d616b8cbca04c9c7efe3cc754870f5ea6df33ecfb1127` | `be0840d23a9d5ef2433d616b8cbca04c9c7efe3cc754870f5ea6df33ecfb1127` | `be0840d23a9d5ef2433d616b8cbca04c9c7efe3cc754870f5ea6df33ecfb1127` |
| `reader-horizontal__en__large__portrait__ipad__dark` | `590431103966d0e6bf49a695a041b395407ec47b86737825d86fc6f46e63413e` | `590431103966d0e6bf49a695a041b395407ec47b86737825d86fc6f46e63413e` | `590431103966d0e6bf49a695a041b395407ec47b86737825d86fc6f46e63413e` |
| `reader-horizontal__en__large__portrait__ipad__light` | `90e43d64645b8e130ab8459a41398b0b87068561ab0d2796983197b7c7b49548` | `90e43d64645b8e130ab8459a41398b0b87068561ab0d2796983197b7c7b49548` | `90e43d64645b8e130ab8459a41398b0b87068561ab0d2796983197b7c7b49548` |
| `reader-vertical__en__large__portrait__ipad__dark` | `558e0b40a65a1710fb1db42b87e5d2492f3fe0eeb99c4ab750ae053e177e790d` | `558e0b40a65a1710fb1db42b87e5d2492f3fe0eeb99c4ab750ae053e177e790d` | `558e0b40a65a1710fb1db42b87e5d2492f3fe0eeb99c4ab750ae053e177e790d` |
| `reader-vertical__en__large__portrait__ipad__light` | `558e0b40a65a1710fb1db42b87e5d2492f3fe0eeb99c4ab750ae053e177e790d` | `558e0b40a65a1710fb1db42b87e5d2492f3fe0eeb99c4ab750ae053e177e790d` | `558e0b40a65a1710fb1db42b87e5d2492f3fe0eeb99c4ab750ae053e177e790d` |
| `search-root-history__en__large__portrait__ipad__dark` | `04ff0ad735ee98dc92e1964ab777bfbc748b95bb41c468a00c9062141c964c2e` | `04ff0ad735ee98dc92e1964ab777bfbc748b95bb41c468a00c9062141c964c2e` | `04ff0ad735ee98dc92e1964ab777bfbc748b95bb41c468a00c9062141c964c2e` |
| `search-root-history__en__large__portrait__ipad__light` | `cbdfec17b6a4bef32b993c0680678bc5054c901ca4bd8cb45edfd46fa7c2e56e` | `cbdfec17b6a4bef32b993c0680678bc5054c901ca4bd8cb45edfd46fa7c2e56e` | `cbdfec17b6a4bef32b993c0680678bc5054c901ca4bd8cb45edfd46fa7c2e56e` |
| `settings-login-empty__en__large__portrait__ipad__dark` | `8414abba08561229a37f8400d683225820fd73de42d8716537f677c9eddc71f4` | `8414abba08561229a37f8400d683225820fd73de42d8716537f677c9eddc71f4` | `8c01592eb2c228931c6f75b70c40ceb6a8bda41c8121143b9a205e931091db31` |
| `settings-login-empty__en__large__portrait__ipad__light` | `81703cc4978fb13239b8310d6a2fe8f26a1f3530de48f074b5bcbe268743c64e` | `81703cc4978fb13239b8310d6a2fe8f26a1f3530de48f074b5bcbe268743c64e` | `244715ff19787ce305abf1fb36d1f29d42f6a70e7472b6ff6247c4435ab91f30` |
| `settings-pages-general-basic__en__large__portrait__ipad__dark` | `d5229f55fab812f6c877019649eb401bd5ddc3ec087636b22c2ac7bf4816c436` | `d5229f55fab812f6c877019649eb401bd5ddc3ec087636b22c2ac7bf4816c436` | `d5229f55fab812f6c877019649eb401bd5ddc3ec087636b22c2ac7bf4816c436` |
| `settings-pages-general-basic__en__large__portrait__ipad__light` | `488ff4aaf0b767d157683e3f13f9cb9ab85f4390f1d79957c00597eb0a712e50` | `488ff4aaf0b767d157683e3f13f9cb9ab85f4390f1d79957c00597eb0a712e50` | `488ff4aaf0b767d157683e3f13f9cb9ab85f4390f1d79957c00597eb0a712e50` |
| `settings-root__en__large__portrait__ipad__dark` | `9d2141e05201dd0627263b7d2a50659b821a7d1c10df5b3ded28cc2f5e7d863b` | `9d2141e05201dd0627263b7d2a50659b821a7d1c10df5b3ded28cc2f5e7d863b` | `9d2141e05201dd0627263b7d2a50659b821a7d1c10df5b3ded28cc2f5e7d863b` |
| `settings-root__en__large__portrait__ipad__light` | `e96e108dc161d76f06d11700cf9f1c5ca3a6852e20f69b2961a3fdea77ed5759` | `e96e108dc161d76f06d11700cf9f1c5ca3a6852e20f69b2961a3fdea77ed5759` | `e96e108dc161d76f06d11700cf9f1c5ca3a6852e20f69b2961a3fdea77ed5759` |
| `toplists-list__en__large__portrait__ipad__dark` | `a6d5a30ca7de1e00b5de4eb337197ce08d313fdf85778c34e3ab80721874b4a7` | `a6d5a30ca7de1e00b5de4eb337197ce08d313fdf85778c34e3ab80721874b4a7` | `67709e42a4d90e2a1caebc935ab57674d1aa715eb0bf4ee41ba4fc12e53e6f07` |
| `toplists-list__en__large__portrait__ipad__light` | `bd9da5ba76ea88a7dbf724cac87ed90b68d9dd9ed7a1b6c3e14f0e9f16362366` | `bd9da5ba76ea88a7dbf724cac87ed90b68d9dd9ed7a1b6c3e14f0e9f16362366` | `8d1a19e1573ad6a643aa307079ec6d31800cf0908ed97f0122f6f776571cbb7f` |
| `watched-signed-out__en__large__portrait__ipad__dark` | `67de7eec1a9ccdeb0c9fb1eb9a485add288235c79a51de92e3cc8572ba13fa63` | `67de7eec1a9ccdeb0c9fb1eb9a485add288235c79a51de92e3cc8572ba13fa63` | `39b87e1d1e14a735ed9236ba9fa1dfbff2dd9843a38ae8d05268ac86e5b55273` |
| `watched-signed-out__en__large__portrait__ipad__light` | `0b2e09eda9f0ada0fd57769918f1235db1564a7953ab1e9c2c1d9773a996d158` | `0b2e09eda9f0ada0fd57769918f1235db1564a7953ab1e9c2c1d9773a996d158` | `0b2e09eda9f0ada0fd57769918f1235db1564a7953ab1e9c2c1d9773a996d158` |
