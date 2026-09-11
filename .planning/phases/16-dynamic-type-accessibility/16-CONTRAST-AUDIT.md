# Phase 16 — Round-2 Contrast and Colour Audit (plan 16-13)

Audit-first half of round 2 (D-20). Every number below was computed this session — from the live colorset JSON for the category
badges, and from rendered simulator pixels for everything else. Nothing is copied from `16-RESEARCH.md`; where a RESEARCH
number is quoted it is for comparison only. No colour, glyph or code was changed by this plan (D-22): the decisions that the
numbers call for are listed in `## Decisions` and belong to the owner.

**Formula.** sRGB channel c → linear `c ≤ 0.04045 ? c/12.92 : ((c+0.055)/1.055)^2.4`; L = 0.2126 R + 0.7152 G + 0.0722 B;
ratio = (L_hi + 0.05) / (L_lo + 0.05). Thresholds: text 4.5:1, large text (≥ 18 pt regular or ≥ 14 pt bold) 3:1, non-text 3:1
(skill `display-settings.md`). Black and white tie at L = 0.17913 (ratio 4.583).

**Infrastructure and deviations (recorded for the SUMMARY).**

- The simulators in `16-SWEEP.md § Infrastructure` (`IPHONE_UDID` `ADE09605…`, `IPAD_UDID` `8250D97E…`, `SPARE_UDID` `E2BF974E…`)
  and the plan's `88B217DA…` no longer exist in `xcrun simctl list devices`. Every pixel measurement here was taken on the
  available iOS 26.5 **iPhone 17e `67377A20-A90A-4DB2-9A9C-9965532B0AA9`**. `16-SWEEP.md § Infrastructure` is deliberately
  *not* edited by this plan (its `files_modified` is this file only); a later plan re-derives the sweep infrastructure on purpose.
- That simulator started **Shutdown** with **no EhPanda build installed** and **no session** (D-09: no credential was entered,
  requested or copied). Baselines read after boot: `appearance = light`, `increase_contrast = disabled`, `content_size = large`.
  Restored and read back identical at the end of the session; the device was shut down again.
- Build: `xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda -destination 'platform=iOS Simulator,id=67377A20-…'` at
  HEAD `8d462178`; `plutil -extract CFBundleIdentifier raw` on the built `.app` printed `app.ehpanda.personal` (the project's resolved
  bundle id on this machine, see `16-SWEEP.md § Why app.ehpanda.personal`); installed with `xcrun simctl install`, launched with
  `xcrun simctl launch`. One `xcodebuild` at a time.
- Only **public E-Hentai content** was measured: Home, the Frontpage and Toplists lists, a public gallery's Detail (header, tag
  cloud, comments preview), the full Comments view, the Filters sheet, Settings › Laboratory, Settings › General › App Activity
  Logs, the Downloads row, and the unsupported-deep-link toast (`xcrun simctl openurl … ehpanda://unsupported.example/…`, which
  raises SpringBoard's "Open in EhPanda?" prompt on every call). States that need a session or a fixture — the offline
  notice, the Downloads *Update* action, `NewDawnView` — are computed from declared colours and are marked **source-derived**
  in the tables so the owner can see which ratios are rendered pixels and which are not.
- To reach the Downloads row one public gallery was downloaded into a newly created default folder (and a second folder,
  `Second`, was created so that the *Move* swipe action renders). The gallery turned out to be 112 pages and completed before it
  could be paused. Nothing was deleted.
- Screenshots: `xcrun simctl io <UDID> screenshot <file>` (the `--scale` flag named in the plan does not exist in this Xcode's
  `simctl`; captures are full-scale 1170 × 2532). They live only under `$HOME/Library/Caches/ehpanda-phase16/round2/contrast/`
  (57 captures, named `<mode>-<screen>.png` with mode ∈ `light-std`, `dark-std`, `light-ic`, `dark-ic`) plus 48 desaturated
  copies under `…/round2/contrast/gray/` (`sips --matchTo 'Generic Gray Profile.icc'`). No image enters the repository (D-32).
- Sampling: a stdlib-Python PNG reader in the session scratchpad takes the dominant colours of a pixel box over each element;
  the ratio is computed between the dominant foreground and background colours (anti-aliased edge colours are ignored).
- Not measured: **Reduce Transparency** (no `simctl ui` switch exists for it) and **Bold Text**. The Liquid Glass toast was
  measured over a plain page; over cover imagery the glass colour is content-dependent and is not pinned by this audit.

## Category variants (D-26)

Method: a scratchpad script walked the 22 `App/Assets.xcassets/Category/Colors/{E-Hentai,ExHentai}/*.colorset/Contents.json`
files, asserted `color-space == "srgb"` on every entry, normalised the three component encodings (`"0x11"` hex byte,
`"0.910"` float, `"163"` decimal byte — counts this session: 156 hex, 90 float, 6 decimal), and computed per variant L, the ratio against white,
the ratio against black, the better of the two, and the text colour D-26 would choose (black if L > 0.17913, else white).
Appearance keys read from `appearances`: none = light, `luminosity: dark` = dark, `contrast: high` = +HC.

**Totals (live JSON, this session):** variants **84** / white-text failures (< 4.5:1) **45** / best-of failures **0** / worst best-of
**4.62:1 — ExHentai / Game CG / light** (white 4.55, black 4.62) / flips to black **47** / crossover L = **0.17913** (ratio 4.583).
Every total equals the RESEARCH § "Re-measured numbers" table (84 / 45 / 0 / 4.62 ExHentai Game CG light / 47 / 0.1791); no
deviation to explain. The two black-chosen variants that also pass with white are the same two RESEARCH names: E-Hentai/Asian Porn/dark+HC white 4.51; ExHentai/Game CG/light white 4.55.
`Private` has only light and dark entries on both hosts (rows 37–38 and 79–80), which is why 22 colorsets give 84 rather than 88 variants.

**Rendered cross-check.** The E-Hentai *Doujinshi* badge sampled from the Frontpage captures rendered `#FC4F4F` (light),
`#9B0202` (dark), `#FC7272` (light + Increase Contrast) and `#E00202` (dark + Increase Contrast) — byte-for-byte the four JSON
entries in rows 5–8 — with white-text ratios 3.30 / 8.74 / 2.70 / 5.03. The colorset walk and the running app agree.

Appearance ∈ light / dark / light+HC / dark+HC; "Text" is the D-26 adaptive choice; all 84 best-of values are ≥ 4.5.

| # | Host | Category | Appearance | sRGB | L | vs white | vs black | Best-of | Text |
|---|---|---|---|---|---|---|---|---|---|
| 1 | E-Hentai | Artist CG | light | `#C7BF08` | 0.4952 | 1.93 | 10.90 | **10.90** | black |
| 2 | E-Hentai | Artist CG | dark | `#9E9905` | 0.3007 | 2.99 | 7.01 | **7.01** | black |
| 3 | E-Hentai | Artist CG | light+HC | `#DEE600` | 0.7182 | 1.37 | 15.36 | **15.36** | black |
| 4 | E-Hentai | Artist CG | dark+HC | `#B0B800` | 0.4334 | 2.17 | 9.67 | **9.67** | black |
| 5 | E-Hentai | Asian Porn | light | `#B551A5` | 0.1843 | 4.48 | 4.69 | **4.69** | black |
| 6 | E-Hentai | Asian Porn | dark | `#8C3D7F` | 0.1045 | 6.80 | 3.09 | **6.80** | white |
| 7 | E-Hentai | Asian Porn | light+HC | `#C373B6` | 0.2724 | 3.26 | 6.45 | **6.45** | black |
| 8 | E-Hentai | Asian Porn | dark+HC | `#B352A3` | 0.1826 | 4.51 | 4.65 | **4.65** | black |
| 9 | E-Hentai | Cosplay | light | `#8700C1` | 0.0900 | 7.50 | 2.80 | **7.50** | white |
| 10 | E-Hentai | Cosplay | dark | `#6D009B` | 0.0562 | 9.89 | 2.12 | **9.89** | white |
| 11 | E-Hentai | Cosplay | light+HC | `#9654F4` | 0.1936 | 4.31 | 4.87 | **4.87** | black |
| 12 | E-Hentai | Cosplay | dark+HC | `#9E00E2` | 0.1276 | 5.91 | 3.55 | **5.91** | white |
| 13 | E-Hentai | Doujinshi | light | `#FC4F4F` | 0.2685 | 3.30 | 6.37 | **6.37** | black |
| 14 | E-Hentai | Doujinshi | dark | `#9B0202` | 0.0702 | 8.74 | 2.40 | **8.74** | white |
| 15 | E-Hentai | Doujinshi | light+HC | `#FC7272` | 0.3394 | 2.70 | 7.79 | **7.79** | black |
| 16 | E-Hentai | Doujinshi | dark+HC | `#E00202` | 0.1590 | 5.03 | 4.18 | **5.03** | white |
| 17 | E-Hentai | Game CG | light | `#1A9417` | 0.2142 | 3.97 | 5.28 | **5.28** | black |
| 18 | E-Hentai | Game CG | dark | `#147512` | 0.1299 | 5.84 | 3.60 | **5.84** | white |
| 19 | E-Hentai | Game CG | light+HC | `#05BF0A` | 0.3743 | 2.47 | 8.49 | **8.49** | black |
| 20 | E-Hentai | Game CG | dark+HC | `#05990A` | 0.2284 | 3.77 | 5.57 | **5.57** | black |
| 21 | E-Hentai | Image Set | light | `#2656AA` | 0.0997 | 7.01 | 2.99 | **7.01** | white |
| 22 | E-Hentai | Image Set | dark | `#1E4487` | 0.0616 | 9.41 | 2.23 | **9.41** | white |
| 23 | E-Hentai | Image Set | light+HC | `#3971D2` | 0.1733 | 4.70 | 4.47 | **4.70** | white |
| 24 | E-Hentai | Image Set | dark+HC | `#2A60BF` | 0.1262 | 5.96 | 3.52 | **5.96** | white |
| 25 | E-Hentai | Manga | light | `#E88C1A` | 0.3607 | 2.56 | 8.21 | **8.21** | black |
| 26 | E-Hentai | Manga | dark | `#B77011` | 0.2170 | 3.93 | 5.34 | **5.34** | black |
| 27 | E-Hentai | Manga | light+HC | `#FCB517` | 0.5391 | 1.78 | 11.78 | **11.78** | black |
| 28 | E-Hentai | Manga | dark+HC | `#E9911C` | 0.3766 | 2.46 | 8.53 | **8.53** | black |
| 29 | E-Hentai | Misc | light | `#707070` | 0.1626 | 4.94 | 4.25 | **4.94** | white |
| 30 | E-Hentai | Misc | dark | `#545B5E` | 0.1018 | 6.92 | 3.04 | **6.92** | white |
| 31 | E-Hentai | Misc | light+HC | `#9E9E9E` | 0.3424 | 2.68 | 7.85 | **7.85** | black |
| 32 | E-Hentai | Misc | dark+HC | `#737C81` | 0.1965 | 4.26 | 4.93 | **4.93** | black |
| 33 | E-Hentai | Non-H | light | `#0F9EBC` | 0.2819 | 3.16 | 6.64 | **6.64** | black |
| 34 | E-Hentai | Non-H | dark | `#0D7D96` | 0.1695 | 4.78 | 4.39 | **4.78** | white |
| 35 | E-Hentai | Non-H | light+HC | `#1BC8EC` | 0.4760 | 2.00 | 10.52 | **10.52** | black |
| 36 | E-Hentai | Non-H | dark+HC | `#05ABB5` | 0.3244 | 2.80 | 7.49 | **7.49** | black |
| 37 | E-Hentai | Private | light | `#000000` | 0.0000 | 21.00 | 1.00 | **21.00** | white |
| 38 | E-Hentai | Private | dark | `#333333` | 0.0331 | 12.63 | 1.66 | **12.63** | white |
| 39 | E-Hentai | Western | light | `#5BC13A` | 0.4067 | 2.30 | 9.13 | **9.13** | black |
| 40 | E-Hentai | Western | dark | `#4A992E` | 0.2443 | 3.57 | 5.89 | **5.89** | black |
| 41 | E-Hentai | Western | light+HC | `#7ACF5F` | 0.4959 | 1.92 | 10.92 | **10.92** | black |
| 42 | E-Hentai | Western | dark+HC | `#0FBA1C` | 0.3537 | 2.60 | 8.07 | **8.07** | black |
| 43 | ExHentai | Artist CG | light | `#D48F1C` | 0.3361 | 2.72 | 7.72 | **7.72** | black |
| 44 | ExHentai | Artist CG | dark | `#A06D16` | 0.1847 | 4.47 | 4.69 | **4.69** | black |
| 45 | ExHentai | Artist CG | light+HC | `#E88C1A` | 0.3607 | 2.56 | 8.21 | **8.21** | black |
| 46 | ExHentai | Artist CG | dark+HC | `#D9941D` | 0.3602 | 2.56 | 8.20 | **8.20** | black |
| 47 | ExHentai | Asian Porn | light | `#A33382` | 0.1179 | 6.25 | 3.36 | **6.25** | white |
| 48 | ExHentai | Asian Porn | dark | `#822868` | 0.0726 | 8.56 | 2.45 | **8.56** | white |
| 49 | ExHentai | Asian Porn | light+HC | `#B552A6` | 0.1855 | 4.46 | 4.71 | **4.71** | black |
| 50 | ExHentai | Asian Porn | dark+HC | `#B63891` | 0.1482 | 5.30 | 3.96 | **5.30** | white |
| 51 | ExHentai | Cosplay | light | `#6B33A3` | 0.0814 | 7.99 | 2.63 | **7.99** | white |
| 52 | ExHentai | Cosplay | dark | `#542882` | 0.0501 | 10.49 | 2.00 | **10.49** | white |
| 53 | ExHentai | Cosplay | light+HC | `#9A4994` | 0.1377 | 5.59 | 3.75 | **5.59** | white |
| 54 | ExHentai | Cosplay | dark+HC | `#7538B6` | 0.0999 | 7.01 | 3.00 | **7.01** | white |
| 55 | ExHentai | Doujinshi | light | `#9E2621` | 0.0877 | 7.63 | 2.75 | **7.63** | white |
| 56 | ExHentai | Doujinshi | dark | `#7C1E19` | 0.0528 | 10.21 | 2.06 | **10.21** | white |
| 57 | ExHentai | Doujinshi | light+HC | `#D2322C` | 0.1616 | 4.96 | 4.23 | **4.96** | white |
| 58 | ExHentai | Doujinshi | dark+HC | `#B82C25` | 0.1213 | 6.13 | 3.43 | **6.13** | white |
| 59 | ExHentai | Game CG | light | `#617D63` | 0.1810 | 4.55 | 4.62 | **4.62** | black |
| 60 | ExHentai | Game CG | dark | `#547557` | 0.1537 | 5.16 | 4.07 | **5.16** | white |
| 61 | ExHentai | Game CG | light+HC | `#6B946E` | 0.2540 | 3.45 | 6.08 | **6.08** | black |
| 62 | ExHentai | Game CG | dark+HC | `#7D9980` | 0.2868 | 3.12 | 6.74 | **6.74** | black |
| 63 | ExHentai | Image Set | light | `#335BA3` | 0.1083 | 6.63 | 3.17 | **6.63** | white |
| 64 | ExHentai | Image Set | dark | `#284982` | 0.0683 | 8.88 | 2.37 | **8.88** | white |
| 65 | ExHentai | Image Set | light+HC | `#4A76C6` | 0.1849 | 4.47 | 4.70 | **4.70** | black |
| 66 | ExHentai | Image Set | dark+HC | `#3866B6` | 0.1372 | 5.61 | 3.74 | **5.61** | white |
| 67 | ExHentai | Manga | light | `#DB6B23` | 0.2570 | 3.42 | 6.14 | **6.14** | black |
| 68 | ExHentai | Manga | dark | `#994C19` | 0.1201 | 6.17 | 3.40 | **6.17** | white |
| 69 | ExHentai | Manga | light+HC | `#E2884E` | 0.3433 | 2.67 | 7.87 | **7.87** | black |
| 70 | ExHentai | Manga | dark+HC | `#D26822` | 0.2372 | 3.66 | 5.74 | **5.74** | black |
| 71 | ExHentai | Misc | light | `#787878` | 0.1873 | 4.42 | 4.75 | **4.75** | black |
| 72 | ExHentai | Misc | dark | `#596066` | 0.1145 | 6.38 | 3.29 | **6.38** | white |
| 73 | ExHentai | Misc | light+HC | `#9E9E9E` | 0.3424 | 2.68 | 7.85 | **7.85** | black |
| 74 | ExHentai | Misc | dark+HC | `#768188` | 0.2133 | 3.99 | 5.27 | **5.27** | black |
| 75 | ExHentai | Non-H | light | `#5EA8CE` | 0.3484 | 2.64 | 7.97 | **7.97** | black |
| 76 | ExHentai | Non-H | dark | `#26607C` | 0.1023 | 6.89 | 3.05 | **6.89** | white |
| 77 | ExHentai | Non-H | light+HC | `#7EB9D7` | 0.4404 | 2.14 | 9.81 | **9.81** | black |
| 78 | ExHentai | Non-H | dark+HC | `#3689B1` | 0.2185 | 3.91 | 5.37 | **5.37** | black |
| 79 | ExHentai | Private | light | `#000000` | 0.0000 | 21.00 | 1.00 | **21.00** | white |
| 80 | ExHentai | Private | dark | `#333333` | 0.0331 | 12.63 | 1.66 | **12.63** | white |
| 81 | ExHentai | Western | light | `#AA9E60` | 0.3384 | 2.70 | 7.77 | **7.77** | black |
| 82 | ExHentai | Western | dark | `#726B3D` | 0.1443 | 5.40 | 3.89 | **5.40** | white |
| 83 | ExHentai | Western | light+HC | `#BBB17F` | 0.4354 | 2.16 | 9.71 | **9.71** | black |
| 84 | ExHentai | Western | dark+HC | `#9D9354` | 0.2868 | 3.12 | 6.74 | **6.74** | black |

## Increase Contrast variants (D-27)

For each of the 40 `contrast: high` variants, the best-of-black/white ratio is compared with the standard sibling of the same
host / category / luminosity. **40 comparisons: lower best-of 19, higher or equal 21, white-text lower 40** — so **19 / 40** HC variants give *less* badge contrast than their standard sibling
even after D-26's adaptive text (RESEARCH expected 19/40 — reproduced), and every one of the 40 is lower on the *current*
white text (40/40, as RESEARCH found).

| # | Host | Category | Appearance | Standard best-of (text) | HC best-of (text) | Delta | Verdict |
|---|---|---|---|---|---|---|---|
| 1 | E-Hentai | Artist CG | light+HC | 10.90 (black) | 15.36 (black) | +4.46 | **higher** |
| 2 | E-Hentai | Artist CG | dark+HC | 7.01 (black) | 9.67 (black) | +2.65 | **higher** |
| 3 | E-Hentai | Asian Porn | light+HC | 4.69 (black) | 6.45 (black) | +1.76 | **higher** |
| 4 | E-Hentai | Asian Porn | dark+HC | 6.80 (white) | 4.65 (black) | -2.15 | **lower** |
| 5 | E-Hentai | Cosplay | light+HC | 7.50 (white) | 4.87 (black) | -2.63 | **lower** |
| 6 | E-Hentai | Cosplay | dark+HC | 9.89 (white) | 5.91 (white) | -3.98 | **lower** |
| 7 | E-Hentai | Doujinshi | light+HC | 6.37 (black) | 7.79 (black) | +1.42 | **higher** |
| 8 | E-Hentai | Doujinshi | dark+HC | 8.74 (white) | 5.03 (white) | -3.71 | **lower** |
| 9 | E-Hentai | Game CG | light+HC | 5.28 (black) | 8.49 (black) | +3.20 | **higher** |
| 10 | E-Hentai | Game CG | dark+HC | 5.84 (white) | 5.57 (black) | -0.27 | **lower** |
| 11 | E-Hentai | Image Set | light+HC | 7.01 (white) | 4.70 (white) | -2.31 | **lower** |
| 12 | E-Hentai | Image Set | dark+HC | 9.41 (white) | 5.96 (white) | -3.45 | **lower** |
| 13 | E-Hentai | Manga | light+HC | 8.21 (black) | 11.78 (black) | +3.57 | **higher** |
| 14 | E-Hentai | Manga | dark+HC | 5.34 (black) | 8.53 (black) | +3.19 | **higher** |
| 15 | E-Hentai | Misc | light+HC | 4.94 (white) | 7.85 (black) | +2.91 | **higher** |
| 16 | E-Hentai | Misc | dark+HC | 6.92 (white) | 4.93 (black) | -1.99 | **lower** |
| 17 | E-Hentai | Non-H | light+HC | 6.64 (black) | 10.52 (black) | +3.88 | **higher** |
| 18 | E-Hentai | Non-H | dark+HC | 4.78 (white) | 7.49 (black) | +2.71 | **higher** |
| 19 | E-Hentai | Western | light+HC | 9.13 (black) | 10.92 (black) | +1.78 | **higher** |
| 20 | E-Hentai | Western | dark+HC | 5.89 (black) | 8.07 (black) | +2.19 | **higher** |
| 21 | ExHentai | Artist CG | light+HC | 7.72 (black) | 8.21 (black) | +0.49 | **higher** |
| 22 | ExHentai | Artist CG | dark+HC | 4.69 (black) | 8.20 (black) | +3.51 | **higher** |
| 23 | ExHentai | Asian Porn | light+HC | 6.25 (white) | 4.71 (black) | -1.54 | **lower** |
| 24 | ExHentai | Asian Porn | dark+HC | 8.56 (white) | 5.30 (white) | -3.26 | **lower** |
| 25 | ExHentai | Cosplay | light+HC | 7.99 (white) | 5.59 (white) | -2.40 | **lower** |
| 26 | ExHentai | Cosplay | dark+HC | 10.49 (white) | 7.01 (white) | -3.48 | **lower** |
| 27 | ExHentai | Doujinshi | light+HC | 7.63 (white) | 4.96 (white) | -2.67 | **lower** |
| 28 | ExHentai | Doujinshi | dark+HC | 10.21 (white) | 6.13 (white) | -4.08 | **lower** |
| 29 | ExHentai | Game CG | light+HC | 4.62 (black) | 6.08 (black) | +1.46 | **higher** |
| 30 | ExHentai | Game CG | dark+HC | 5.16 (white) | 6.74 (black) | +1.58 | **higher** |
| 31 | ExHentai | Image Set | light+HC | 6.63 (white) | 4.70 (black) | -1.93 | **lower** |
| 32 | ExHentai | Image Set | dark+HC | 8.88 (white) | 5.61 (white) | -3.27 | **lower** |
| 33 | ExHentai | Manga | light+HC | 6.14 (black) | 7.87 (black) | +1.73 | **higher** |
| 34 | ExHentai | Manga | dark+HC | 6.17 (white) | 5.74 (black) | -0.43 | **lower** |
| 35 | ExHentai | Misc | light+HC | 4.75 (black) | 7.85 (black) | +3.10 | **higher** |
| 36 | ExHentai | Misc | dark+HC | 6.38 (white) | 5.27 (black) | -1.12 | **lower** |
| 37 | ExHentai | Non-H | light+HC | 7.97 (black) | 9.81 (black) | +1.84 | **higher** |
| 38 | ExHentai | Non-H | dark+HC | 6.89 (white) | 5.37 (black) | -1.52 | **lower** |
| 39 | ExHentai | Western | light+HC | 7.77 (black) | 9.71 (black) | +1.94 | **higher** |
| 40 | ExHentai | Western | dark+HC | 5.40 (white) | 6.74 (black) | +1.33 | **higher** |

### Re-authoring proposal for the 19 `lower` variants

Rule applied (plan 16-13 § Task 1.2): keep the hue by scaling the three *linear* channels uniformly away from the crossover —
lighter when the variant's L > 0.17913, darker otherwise — until its best-of ratio is at least the standard sibling's, then quantise
to 8-bit and nudge until the target still holds. "Hue kept" is *no* where a channel hit 1.0 and the remainder had to be blended
toward white (one case: E-Hentai Cosplay light+HC). The proposed values are candidates for the owner, not changes.

| # | Host | Category | Appearance | Current HC sRGB (best-of) | Standard best-of | Proposed HC sRGB | Proposed L | Proposed best-of | Text | Direction | Hue kept |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | E-Hentai | Asian Porn | dark+HC | `#B352A3` (4.65) | 6.80 | `#DD67CA` | 0.2934 | **6.87** | black | lighter | yes |
| 2 | E-Hentai | Cosplay | light+HC | `#9654F4` (4.87) | 7.50 | `#C27AFF` | 0.3261 | **7.52** | black | lighter | no — a channel clipped at 1.0, blended toward white |
| 3 | E-Hentai | Cosplay | dark+HC | `#9E00E2` (5.91) | 9.89 | `#6B009C` | 0.0553 | **9.98** | white | darker | yes |
| 4 | E-Hentai | Doujinshi | dark+HC | `#E00202` (5.03) | 8.74 | `#9B0101` | 0.0699 | **8.76** | white | darker | yes |
| 5 | E-Hentai | Game CG | dark+HC | `#05990A` (5.57) | 5.84 | `#069E0C` | 0.2452 | **5.90** | black | lighter | yes |
| 6 | E-Hentai | Image Set | light+HC | `#3971D2` (4.70) | 7.01 | `#2956A3` | 0.0977 | **7.11** | white | darker | yes |
| 7 | E-Hentai | Image Set | dark+HC | `#2A60BF` (5.96) | 9.41 | `#1B4389` | 0.0605 | **9.50** | white | darker | yes |
| 8 | E-Hentai | Misc | dark+HC | `#737C81` (4.93) | 6.92 | `#8B969C` | 0.2970 | **6.94** | black | lighter | yes |
| 9 | ExHentai | Asian Porn | light+HC | `#B552A6` (4.71) | 6.25 | `#D461C2` | 0.2644 | **6.29** | black | lighter | yes |
| 10 | ExHentai | Asian Porn | dark+HC | `#B63891` (5.30) | 8.56 | `#832567` | 0.0713 | **8.66** | white | darker | yes |
| 11 | ExHentai | Cosplay | light+HC | `#9A4994` (5.59) | 7.99 | `#783773` | 0.0796 | **8.10** | white | darker | yes |
| 12 | ExHentai | Cosplay | dark+HC | `#7538B6` (7.01) | 10.49 | `#532684` | 0.0489 | **10.62** | white | darker | yes |
| 13 | ExHentai | Doujinshi | light+HC | `#D2322C` (4.96) | 7.63 | `#9F231E` | 0.0867 | **7.68** | white | darker | yes |
| 14 | ExHentai | Doujinshi | dark+HC | `#B82C25` (6.13) | 10.21 | `#7E1B16` | 0.0528 | **10.22** | white | darker | yes |
| 15 | ExHentai | Image Set | light+HC | `#4A76C6` (4.70) | 6.63 | `#5C90F0` | 0.2851 | **6.70** | black | lighter | yes |
| 16 | ExHentai | Image Set | dark+HC | `#3866B6` (5.61) | 8.88 | `#254884` | 0.0669 | **8.98** | white | darker | yes |
| 17 | ExHentai | Manga | dark+HC | `#D26822` (5.74) | 6.17 | `#DB6D25` | 0.2613 | **6.23** | black | lighter | yes |
| 18 | ExHentai | Misc | dark+HC | `#768188` (5.27) | 6.38 | `#839097` | 0.2701 | **6.40** | black | lighter | yes |
| 19 | ExHentai | Non-H | dark+HC | `#3689B1` (5.37) | 6.89 | `#409ECB` | 0.2986 | **6.97** | black | lighter | yes |

**What adopting this means.** The proposal rewrites the bytes of **19 of the 40 `contrast: high` entries**; the other 21 HC
entries and all **44 standard entries stay byte-identical**. D-26 pins the 84 variants as "byte-identical" and D-27 asks for
the HC variants to be re-authored: **both cannot hold at once.** Under HC=A the invariant test (plan 16-14) pins the 44
standard entries and the 40 HC entries as two separately hashed groups and the HC hash is re-pinned deliberately in plan 16-15;
under HC=B all 84 stay pinned as one group and the 19/40 residual is recorded as a documented should-fix not done. The
choice is the owner's (D-22); it is not resolved here.

## Non-category colours (D-28)

Method: on `67377A20…`, for each of `appearance light` / `appearance dark` × `increase_contrast disabled` / `enabled`
(`xcrun simctl ui`), the screen was left in place and re-captured — the app re-renders both switches live, which the category
badge cross-check above confirms. Foreground and background are the dominant colours of a pixel box over the element in each
capture. Thresholds follow the element's role: non-text glyph 3:1; text 4.5:1; text at ≥ 14 pt bold or ≥ 18 pt regular 3:1
(the tag chips and namespace chip are `.subheadline.bold()` = 15 pt bold; the Laboratory cell is `.title2.bold()` = 22 pt bold;
the offline notice is 15 pt *semibold*, which is below the bold cut and so keeps 4.5:1). `Basis` says whether the pair is rendered
or source-derived and which capture it came from.

| # | Site | Role | Light | Dark | Light + IC | Dark + IC | Threshold | Verdict | Basis |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Rating stars — list cells (`GalleryDetailCell`, `GalleryThumbnailCell`; `.yellow` on card) | non-text glyph | 1.51 (`#FFCC00` on `#FFFFFF`) | 12.05 (`#FFD600` on `#1C1C1E`) | 4.59 (`#A16A00` on `#FFFFFF`) | 11.69 (`#FEDF43` on `#242426`) | 3:1 | **FAIL** (light) | rendered: `light-std-frontpage.png` etc.; no numeric rating beside the stars in list cells |
| 2 | Rating stars — Home card (`GalleryCardCell`; `.yellow` on `Color.gray.opacity(0.2)` card) | non-text glyph | 1.23 (`#FFCC00` on `#E8E8E9`) | 1.97 (`#FFD600` on `#A29A91`) | 3.54 (`#A16A00` on `#E2E2E2`) | 2.21 (`#FEDF43` on `#96988B`) | 3:1 | **FAIL** (light, dark, dark+IC) | rendered: `*-home-root.png`; dark backgrounds are the cover-derived animated gradient (content-dependent) |
| 3 | Rating stars — Detail header (`DescScrollRatingItem`, `.primary`) + numeric rating text | non-text glyph / text | 21.00 (`#000000` on `#FFFFFF`) | 21.00 (`#FFFFFF` on `#000000`) | 21.00 (`#000000` on `#FFFFFF`) | 21.00 (`#FFFFFF` on `#000000`) | 3:1 | pass | rendered: `*-detail-top.png`; the header stars are `.primary`, not `.yellow`; numeric `1.50` is `.primary` |
| 4 | Read button glyph — white `book.fill` on `.glassProminent` accent (`HeaderSection`) | non-text glyph (icon-only label) | 3.30 (`#FFFFFF` on `#669C34`) | 1.81 (`#FFFFFF` on `#94D25C`) | 9.10 (`#FFFFFF` on `#34501A`) | 1.12 (`#FFFFFF` on `#D5FFAE`) | 3:1 | **FAIL** (dark, dark+IC) | rendered: `*-detail-top.png` |
| 5 | Category badge cross-check — E-Hentai Doujinshi, white text (`CategoryLabel`) | text 13pt bold | 3.30 (`#FFFFFF` on `#FC4F4F`) | 8.74 (`#FFFFFF` on `#9B0202`) | 2.70 (`#FFFFFF` on `#FC7272`) | 5.03 (`#FFFFFF` on `#E00202`) | 4.5:1 | **FAIL** (light, light+IC) | rendered: `*-frontpage.png`; equals the colorset rows 5–8 of § Category variants (3.30 / 8.74 / 2.70 / 5.03) |
| 6 | Tag namespace chip — `reversedPrimary` on `Color(.systemGray)` (`TagsSection`) | text 15pt bold (large text) | 3.26 (`#FFFFFF` on `#8E8E93`) | 6.44 (`#000000` on `#8E8E93`) | 5.23 (`#FFFFFF` on `#6C6C70`) | 9.50 (`#000000` on `#AEAEB2`) | 3:1 | pass | rendered: `*-detail-top.png` |
| 7 | Tag chip — `.primary` on `Color(.systemGray5)` (`TagCloudCell`) | text 15pt bold (large text) | 16.73 (`#000000` on `#E5E5EA`) | 13.94 (`#FFFFFF` on `#2C2C2E`) | 14.78 (`#000000` on `#D8D8DC`) | 12.06 (`#FFFFFF` on `#363638`) | 3:1 | pass | rendered: `*-detail-top.png` |
| 8 | Toast title — `.primary` `.footnote.bold()` on Liquid Glass over a plain page (`ToastMessageView`) | text 13pt bold | 20.47 (`#000000` on `#FCFCFC`) | 16.74 (`#F3F3F3` on `#131313`) | 19.95 (`#000000` on `#F9F9F9`) | 16.60 (`#F3F3F3` on `#141414`) | 4.5:1 | pass | rendered: `*-toast.png` over the Activity Logs page; glass over imagery is content-dependent and not pinned |
| 9 | Toast subtitle — `.secondary` `.footnote` on Liquid Glass (`ToastMessageView`) | text 13pt | 4.73 (`#727272` on `#FDFDFD`) | 7.16 (`#A0A0A0` on `#121212`) | 4.70 (`#707070` on `#F9F9F9`) | 7.13 (`#A1A1A1` on `#141414`) | 4.5:1 | pass | rendered: `*-toast.png`; Reduce Transparency has no `simctl` switch and was not measured |
| 10 | Toast error icon — `.red` `exclamationmark.triangle` on glass | non-text glyph | 3.54 (`#FE373B` on `#FDFDFD`) | 5.68 (`#FF4B4E` on `#121212`) | 4.45 (`#E6122A` on `#F9F9F9`) | 6.65 (`#FF6B6F` on `#141414`) | 3:1 | pass | rendered: `*-toast.png` |
| 11 | Activity-log level dot — `.notice` `.gray` `circle.fill` (`AppActivityLogRow`) | non-text glyph | 3.26 (`#8E8E93` on `#FFFFFF`) | 6.44 (`#8E8E93` on `#000000`) | 5.23 (`#6C6C70` on `#FFFFFF`) | 9.50 (`#AEAEB2` on `#000000`) | 3:1 | pass | rendered: `*-activity-logs.png` |
| 12 | Activity-log level dot — `.error` `.orange` `circle.fill` | non-text glyph | 2.31 (`#FF8D28` on `#FFFFFF`) | 9.41 (`#FF9230` on `#000000`) | 4.55 (`#C55300` on `#FFFFFF`) | 10.41 (`#FFA056` on `#000000`) | 3:1 | **FAIL** (light) | rendered: `*-activity-logs.png`; `.debug` indigo, `.info` blue, `.fault` red rows were not present in the log |
| 13 | Laboratory cell OFF — `.secondary` `.title2.bold()` on `Color(.systemGray5)` (`LaboratoryCell`) | text 22pt bold (large text) | 4.50 (`#676769` on `#E5E5EA`) | 6.07 (`#ABABAB` on `#2C2C2E`) | 4.35 (`#616163` on `#D8D8DC`) | 5.50 (`#AFAFAF` on `#363638`) | 3:1 | pass | rendered: `*-laboratory.png` |
| 14 | Laboratory cell ON — `.purple` `.title2.bold()` on `.purple.opacity(0.2)` | text 22pt bold (large text) | 3.39 (`#C51ADB` on `#F2D3F6`) | 4.79 (`#FD45FF` on `#432248`) | 4.33 (`#A518B9` on `#EAD1EE`) | 7.33 (`#FFA3FF` on `#3E2B42`) | 3:1 | pass | rendered: `*-laboratory-on.png` |
| 15 | Comment link run — `.accentColor` `.body` on the comment cell (`LinkColoredText`, `CommentsView`) | text 17pt | 3.26 (`#669D34` on `#FFFFFF`) | 9.54 (`#96D35F` on `#1C1C1E`) | 11.40 (`#2A4015` on `#FFFFFF`) | 14.26 (`#E1FFC6` on `#242426`) | 4.5:1 | **FAIL** (light) | rendered: `*-comments-full.png` |
| 16 | Comment body text — `.primary` `.body` on the comment cell (`CommentsView`) | text 17pt | 21.00 (`#000000` on `#FFFFFF`) | 17.01 (`#FFFFFF` on `#1C1C1E`) | 21.00 (`#000000` on `#FFFFFF`) | 15.49 (`#FFFFFF` on `#242426`) | 4.5:1 | pass | rendered: `*-comments-full.png` |
| 17 | Comment preview text — `.primary` on `Color(.systemGray5)` (`DetailView.CommentCell`) | text | 16.73 (`#000000` on `#E5E5EA`) | 13.94 (`#FFFFFF` on `#2C2C2E`) | 14.78 (`#000000` on `#D8D8DC`) | 12.06 (`#FFFFFF` on `#363638`) | 4.5:1 | pass | rendered: `*-detail-comments.png` |
| 18 | Comment preview date — `.secondary` caption on `Color(.systemGray5)` (`DetailView.CommentCell`) | text ≤ 13pt | 3.13 (`#808086` on `#E5E5EA`) | 5.29 (`#9F9FA5` on `#2C2C2E`) | 4.74 (`#5B5B62` on `#D8D8DC`) | 5.85 (`#B4B4BC` on `#363638`) | 4.5:1 | **FAIL** (light) | rendered: `*-detail-comments.png` |
| 19 | `.secondary` metadata on white/black cards — list-cell date & page count, comment score `+421` | text ≤ 13pt | 4.00 (`#7F7F7F` on `#FFFFFF`) | 5.20 (`#8E8E8F` on `#1C1C1E`) | 4.00 (`#7F7F7F` on `#FFFFFF`) | 4.98 (`#929293` on `#242426`) | 4.5:1 | **FAIL** (light, light+IC) | rendered: `*-frontpage.png`, `*-comments-full.png`; this `.secondary` is a hierarchical ShapeStyle and did not change under Increase Contrast |
| 20 | Filters `CategoryCell` excluded — white text on E-Hentai Misc at opacity 0.3 over the sheet row | text 17pt bold (large text) | 1.48 (`#FFFFFF` on `#D4D4D4`) | 11.42 (`#FFFFFF` on `#383A3C`) | 1.30 (`#FFFFFF` on `#E2E2E2`) | 8.78 (`#FFFFFF` on `#484B4E`) | 3:1 | **FAIL** (light, light+IC) | rendered: `*-filters-excluded.png`; all 80 filter variants in § Differentiate Without Color |
| 21 | Offline notice — `.orange` `.subheadline.weight(.semibold)` text on `.regularMaterial` (`DetailView` ~281) | text 15pt semibold | 2.31 (`#FF8D28` on `#FFFFFF`) | 9.41 (`#FF9230` on `#000000`) | 4.55 (`#C55300` on `#FFFFFF`) | 10.41 (`#FFA056` on `#000000`) | 4.5:1 | **FAIL** (light) | source-derived: `.orange` taken from the rendered log dots, material approximated by the page background; the state needs the network off and was not triggered |
| 22 | Swipe action — Delete, white label on `.tint(.red)` (`DownloadsView` trailing) | text ~12pt + glyph | 3.57 (`#FFFFFF` on `#FF383C`) | 3.43 (`#FFFFFF` on `#FF4245`) | 4.56 (`#FFFFFF` on `#E9152D`) | 2.94 (`#FFFFFF` on `#FF6165`) | 4.5:1 | **FAIL** (light, dark, dark+IC) | rendered: `*-swipe-trailing.png` |
| 23 | Swipe action — Pause, white label on `.tint(.indigo)` (active download; `.accentColor` when inactive) | text ~12pt + glyph | 5.09 (`#FFFFFF` on `#6155F5`) | 3.51 (`#FFFFFF` on `#6D7CFF`) | 6.12 (`#FFFFFF` on `#564ADE`) | 2.13 (`#FFFFFF` on `#A7AAFF`) | 4.5:1 | **FAIL** (dark, dark+IC) | rendered: `*-swipe-trailing.png`; the inactive-state accent variant equals the Read-button accent row |
| 24 | Swipe action — Move, white label on `.tint(.teal)` (`DownloadsView` leading, two folders present) | text ~12pt + glyph | 2.16 (`#FFFFFF` on `#00C3D0`) | 1.86 (`#FFFFFF` on `#00D2E0`) | 4.57 (`#FFFFFF` on `#008198`) | 1.65 (`#FFFFFF` on `#3BDDEC`) | 4.5:1 | **FAIL** (light, dark, dark+IC) | rendered: `*-swipe-leading-move.png` |
| 25 | Swipe action — Pages (inspect), white label on the untinted system swipe background (`DownloadsView` leading) | text ~12pt + glyph | 1.68 (`#FFFFFF` on `#C7C7CC`) | 9.12 (`#FFFFFF` on `#48484A`) | 2.21 (`#FFFFFF` on `#AEAEB2`) | 7.56 (`#FFFFFF` on `#545456`) | 4.5:1 | **FAIL** (light, light+IC) | rendered: `*-swipe-leading.png`; `inspectButton` carries no `.tint`, so SwiftUI draws the system gray |
| 26 | Swipe action — Update, white label on `.tint(.orange)` (only when `canTriggerUpdate`) | text ~12pt + glyph | 2.31 (`#FFFFFF` on `#FF8D28`) | 2.23 (`#FFFFFF` on `#FF9230`) | 4.55 (`#FFFFFF` on `#C55300`) | 2.02 (`#FFFFFF` on `#FFA056`) | 4.5:1 | **FAIL** (light, dark, dark+IC) | source-derived: `.orange` taken from the rendered Activity-Logs error dot in each mode; the update state was not reachable |
| 27 | NewDawn greeting — white bold text over the gradient **top** (`Color(.systemTeal)` light / `Color(.systemGray5)` dark) | text (title-class bold) | 2.16 (`#FFFFFF` on `#00C3D0`) | 13.94 (`#FFFFFF` on `#2C2C2E`) | 4.57 (`#FFFFFF` on `#008198`) | 12.06 (`#FFFFFF` on `#363638`) | 3:1 | **FAIL** (light) | source-derived: `NewDawnView` needs a login-only greeting; teal from the rendered Move tint, gray5 from rendered chips |
| 28 | NewDawn greeting — white bold text over the gradient **bottom** (`Color(.systemIndigo)` light / `Color(.systemGray2)` dark) | text (title-class bold) | 5.09 (`#FFFFFF` on `#6155F5`) | 5.99 (`#FFFFFF` on `#636366`) | 6.12 (`#FFFFFF` on `#564ADE`) | 5.99 (`#FFFFFF` on `#636366`) | 3:1 | pass | source-derived: indigo from the rendered Pause tint; `systemGray2` dark was not rendered this session — Apple's documented `#636366` is used for both dark cells |

### Findings and proposed fixes (each is a visible colour/weight change — the owner may veto by id)

| Id | Failing site (row) | Measured failure | Proposed fix | Layout moves? |
|---|---|---|---|---|
| `stars-list` | Rating stars, list cells (1) | `.yellow` on white **1.51:1** in light; passes dark (12.05), light+IC (4.59 — iOS 26's Increase-Contrast yellow is `#A16A00`), dark+IC (11.69) | This is decision **STARS** (see `## Decisions`). Under B, a light-mode star colour of `#B59000` gives 3.02:1 on white; `#A38100` gives 3.69:1 on white and 3.01:1 on the Home card's `#E8E8E9`; Apple's own IC yellow `#A16A00` gives 4.59 / 3.75. Under A the stars keep `.yellow` and the group gets a VoiceOver label + value. | No |
| `stars-card` | Rating stars, Home card (2) | **1.23:1** light on the gray card; **1.97** / **2.21** on the cover-derived gradient (dark, dark+IC) — the gradient is content-dependent and cannot be made to pass by a colour choice alone | Same STARS decision; the gradient case argues for A's stance (stars decorative, the `Text(rating)` fallback / a VoiceOver value carries the number) or for a solid backing behind the rating row under B | No (B with a backing: no size change) |
| `read-glyph` | Read button glyph (4) | White `book.fill` on the accent: **1.81:1** dark, **1.12:1** dark+IC (light 3.30, light+IC 9.10) | Choose the glyph colour from the resolved accent's luminance with the plan-16-14 helper — the D-26 rule applied to one glyph: black reads 11.63:1 on `#94D25C` and 18.74:1 on `#D5FFAE` while white stays where it passes | No |
| `log-dot` | Activity-log `.error` dot (12) | `.orange` disc on white **2.31:1** (non-text); `.notice` gray passes at 3.26; `.debug` indigo / `.info` blue / `.fault` red rows were not present in the log this session | Combine with the DWC fix below: per-level glyph in palette rendering `.foregroundStyle(.primary, level.color)` so the mark (exclamation / cross) is `.primary` (≥ 15:1) and the colour is redundant; alternatively `.orange` → `#DF7B22` (3.00:1) for the light disc | No (same glyph box) |
| `comment-link` | Comment link runs (15) | `.accentColor` body text on the white cell **3.26:1** in light (dark 9.54, IC ≥ 11) | Light-mode link colour darkened to `#54832A` (4.51:1 on white, 4.66:1 against the black body text) and an underline on link runs (also the DWC carrier, below) | No |
| `comment-date` | Comment preview date (18) | `.secondary` caption on `systemGray5` **3.13:1** in light | `.foregroundStyle(.primary)` for the date, or drop the gray-5 card behind the preview text; owner's call — a system semantic colour on a system gray | No |
| `secondary-meta` | `.secondary` metadata on white cards (19) | **4.00:1** light and light+IC (hierarchical `.secondary` = 50 % primary; Increase Contrast does not raise it) | **No change proposed**: this is Apple's platform convention for secondary text and appears in Apple's own apps at the same ratio; record it as the one known `.secondary` caveat for the Nutrition Label recommendation. Alternative if the owner wants strict AA: `Color(.secondaryLabel)` under IC reads 4.74 on gray-5 (row 18) — on white it would still be ≈ 4.0 | No |
| `offline-notice` | Offline notice text (21, source-derived) | `.orange` 15 pt semibold **2.31:1** in light (dark 9.41, IC 4.55 / 10.41) | Text `.primary`, keep `.orange` on the `wifi.exclamationmark` glyph (glyph then 2.31 as a decorative duplicate of the text; `#B36119` would give 4.53 if the orange text must stay) | No |
| `swipe-delete` | Downloads swipe *Delete* (22) | white label on `.red`: **3.57** light, **3.43** dark, **2.94** dark+IC (light+IC 4.56) | System-drawn white label; the only lever is the tint. `.red` is Apple's own delete convention (Mail, Messages) — proposed: **keep**, record as platform convention; or a custom darker red such as `#C8102E`-class for light | No |
| `swipe-pause` | Downloads swipe *Pause* (23) | `.indigo`: **3.51** dark, **2.13** dark+IC (light 5.09, light+IC 6.12) | Same lever; Apple's Increase-Contrast dark palette is pastel by design, so every white-label swipe action fails dark+IC — proposed: **keep**, record as platform convention | No |
| `swipe-move` | Downloads swipe *Move* (24) | `.teal`: **2.16** light, **1.86** dark, **1.65** dark+IC (light+IC 4.57) | Replace `.teal` with a tint that carries white in standard modes, e.g. `.indigo`-class or `Color(.systemBlue)` measured in 16-23; dark+IC stays a platform limit | No |
| `swipe-pages` | Downloads swipe *Pages* (25) | untinted system gray: **1.68** light, **2.21** light+IC (dark 9.12, dark+IC 7.56) | `inspectButton` gets an explicit `.tint` — the only site whose failure is the app's own omission rather than a system tint; `.indigo` (5.09 light) or `Color(.systemGray)` (3.26, still short) — propose `.indigo`-class, measured in 16-23 | No |
| `swipe-update` | Downloads swipe *Update* (26, source-derived) | `.orange`: **2.31** light, **2.23** dark, **2.02** dark+IC | Same as `swipe-move`: a darker tint; `#B36119`-class in light reads 4.53 | No |
| `newdawn` | NewDawn greeting over the gradient top (27, source-derived) | white bold on `Color(.systemTeal)` **2.16:1** in light (indigo bottom 5.09; dark 13.94 / 5.99) | Darken the light gradient's top stop (e.g. `#008198`, the IC teal, gives 4.57) or add a text shadow / scrim behind the greeting; the sun disc is decorative and needs nothing | No |

Passing rows need no action: Detail-header stars and numeric rating (`.primary`, 21:1), tag chips (≥ 12:1), namespace chip
(≥ 3.26 at 15 pt bold), toast title / subtitle / icon (≥ 4.70 / 3.54 over a plain page), notice dot, Laboratory text (≥ 3.39 at
22 pt bold), comment body text, NewDawn gradient bottom. The category badge cross-check row (5) fails on *white* text exactly as
§ Category variants predicts and is resolved by D-26's adaptive text, not by a D-28 fix.

## Differentiate Without Color (D-20)

Method: the relevant captures were desaturated with `sips -s format png --matchTo '/System/Library/ColorSync/Profiles/Generic
Gray Profile.icc'` into `…/round2/contrast/gray/` and re-sampled at the same pixel boxes; in parallel the WCAG relative
luminance of the rendered colours was compared directly (the two agree on every verdict). "State ratio" is the luminance
ratio between the two states' colours — 1.0 means the states are identical once colour is removed; anything under ≈ 1.5 is not
reliably readable as two states. Rows follow the RESEARCH table; verdicts are this session's.

| State | Site | Non-colour carrier today | Grayscale measurement | Verdict | Proposed carrier (if needed) |
|---|---|---|---|---|---|
| Download status badge | `DownloadBadgeLabel` | symbol per status + progress text | rendered on the Downloads row: `checkmark` + `112/112` text read unchanged in gray | pass (reference) | — |
| Inspector page-group status | `DownloadsView+Subviews:171` | `status.symbol` + title text | source (symbol + text) | pass | — |
| Detail download button status | `HeaderSection` | symbol per status + label | rendered: cloud-download symbol; other states source | pass | — |
| Favourited | `HeaderSection` | `heart` vs `heart.fill` | shape differs; rendered `heart` (outline) on the public gallery | pass | — |
| Rating | `RatingView` + numeric text | fill level is shape (`star` / `star.leadinghalf.filled` / `star.fill`); Detail header shows the number | rendered: `#000000` stars on white keep their fill shapes in gray; list cells have no number beside the stars — the fill shape alone carries the value there | pass (contrast is the separate STARS finding) | — |
| Comment vote | `CommentCells`, `CommentsView` | thumbs up vs down glyph | source (glyph shape); the rendered `+421` score is text | pass | — |
| Cookie validity | `AccountSettingView` | `xmark.circle` vs `checkmark.circle` | source; login-gated | pass | — |
| Exclude toggle | `EhSettingView+Sections3` | `nosign` vs `circle` | source; login-gated | pass visually; VoiceOver / Voice Control semantics are plan 16-16's, not a colour matter | — |
| Toast success / error | `ToastMessageView` | `checkmark.circle` vs `exclamationmark.triangle` | rendered error toast: triangle glyph + "Error" title read in gray | pass | — |
| Offline notice | `DetailView` | `wifi.exclamationmark` glyph + text | source; not triggerable without the network off | pass | — |
| **Activity-log level** | `AppActivityLogRow` + `Level.color` | **colour-only `circle.fill`** (indigo / blue / gray / orange / red) | rendered gray (light): notice dot `#8E8E93` → `#7C7C7C`, error dot `#FF8D28` → `#9C9C9C`; two identical discs of slightly different gray (state ratio 1.6), no shape or text difference | **fail** | Per-level symbol carried by the same `Image`: `circle.fill` for debug / info / notice, `exclamationmark.circle.fill` for error, `xmark.octagon.fill` for fault, plus `.accessibilityLabel(level.title)`; keep the colour as the redundant cue (palette rendering, see `log-dot`). Same glyph box → no layout change. Plan 16-22. |
| **Filter category included / excluded** | `CategoryCell` (opacity 0.3) | luminance only | rendered E-Hentai Misc: included `#707070` vs excluded `#D4D4D4` → gray `#5D5D5D` vs `#CACACA`, state ratio **3.34** (light); dark `#545B5E` vs `#383A3C` → gray `#484848` vs `#2C2C2C`, **1.65**; light+IC **2.07**; dark+IC **2.06**. Across all 80 filter variants (table below): light min **1.59** (E-Hentai Artist CG), dark min **1.25** (ExHentai Cosplay, 20/20 below 3.0, 6 below 1.5), light+HC min **1.23**, dark+HC min **1.51**. The excluded label itself is white on the faded tile: **1.48:1** light / **1.30:1** light+IC — unreadable. | **weak** in light, **fail** in dark for a third of the categories | Decision **CATEGORYCELL**: A keeps opacity 0.3 (+ D-26 adaptive text resolved against the *composited* colour, `Button` semantics, `.isSelected`) and claims DWC on the luminance numbers above; B adds a visible non-colour cue — strike-through text, a `nosign` overlay, or a dashed outline — for the excluded state (Filters sheet joins the D-25 re-sweep). |
| **Laboratory feature on / off** | `LaboratoryCell` | tint vs `.secondary` text; tinted-0.2 vs gray-5 background | rendered gray: OFF background `#E5E5EA` → `#DFDFDF`, ON `#F2D3F6` → `#D5D5D5` (state ratio **1.08**); OFF content `#676769` → `#545454`, ON `#C51ADB` → `#616161` (**1.22**); dark **1.04 / 1.22**, light+IC **1.01 / 1.01**, dark+IC **1.07 / 1.25** — the two states are indistinguishable without colour | **fail** | A `Toggle`-style carrier: a `checkmark.circle.fill` / `circle` trailing glyph (or a real `Toggle` with `.toggleStyle(.button)`), plus `.accessibilityAddTraits(.isToggle)` / `.isSelected`; the cell height is unchanged if the glyph sits inline with the title. Plan 16-22; Laboratory joins the D-25 re-sweep only if the glyph changes the cell's size. |
| Swipe action kinds | `DownloadsView` | each has a `Label` with text | rendered: Pages / Move / Delete / Pause all carry their text under the glyph | pass | — |
| Links in comments | `LinkedText` | **no underline, no weight change** — link runs differ from body text by colour only (`.accentColor` `#669D34` vs `#000000`, 6.37:1 between them in light; 9.54:1 link vs cell in dark) | rendered gray (light): link `#669D34` → `#7C7C7C` vs body `#000000`: the runs remain visibly lighter, and every link in the sample is a literal URL, so the text form itself says "link" | weak pass (WCAG G183 is met on the 3:1 link-vs-text difference; there is no hover/focus cue on iOS) | `.underlineStyle(.single)` on link runs in `LinkColoredText` (pairs with the `comment-link` colour fix); no layout change. |

### Filters `CategoryCell` excluded state — all 80 filter variants

Composite of the category colour at opacity 0.3 over the Filters sheet's row background (rendered: `#FFFFFF` light, `#2C2C2E`
dark, `#FFFFFF` light+HC, `#363638` dark+HC), gamma-space blend — validated against the rendered Misc tiles (`#D4D4D4`, `#383A3C`,
`#E2E2E2`, `#484B4E` computed = sampled). `Private` is not a filter and is omitted. "Luminance ratio" is the included : excluded
state ratio that the grayscale check depends on; the last three columns are the text ratios on the excluded tile.

| # | Host | Category | Appearance | Included bg (L) | Excluded bg (L) | Included:excluded luminance ratio | White on excluded | Black on excluded | Best-of on excluded |
|---|---|---|---|---|---|---|---|---|---|
| 1 | E-Hentai | Artist CG | light | `#C7BF08` (0.495) | `#EEECB5` (0.815) | **1.59** | 1.21 | 17.30 | 17.30 |
| 2 | E-Hentai | Artist CG | dark | `#9E9905` (0.301) | `#4E4D22` (0.070) | **2.91** | 8.72 | 2.41 | 8.72 |
| 3 | E-Hentai | Artist CG | light+HC | `#DEE600` (0.718) | `#F5F7B2` (0.891) | **1.23** | 1.12 | 18.83 | 18.83 |
| 4 | E-Hentai | Artist CG | dark+HC | `#B0B800` (0.433) | `#5B5D27` (0.102) | **3.18** | 6.91 | 3.04 | 6.91 |
| 5 | E-Hentai | Asian Porn | light | `#B551A5` (0.184) | `#E9CBE4` (0.656) | **3.02** | 1.49 | 14.13 | 14.13 |
| 6 | E-Hentai | Asian Porn | dark | `#8C3D7F` (0.104) | `#493146` (0.041) | **1.71** | 11.60 | 1.81 | 11.60 |
| 7 | E-Hentai | Asian Porn | light+HC | `#C373B6` (0.272) | `#EDD5E9` (0.715) | **2.37** | 1.37 | 15.30 | 15.30 |
| 8 | E-Hentai | Asian Porn | dark+HC | `#B352A3` (0.183) | `#5C3E58` (0.064) | **2.04** | 9.19 | 2.29 | 9.19 |
| 9 | E-Hentai | Cosplay | light | `#8700C1` (0.090) | `#DBB2EC` (0.530) | **4.14** | 1.81 | 11.59 | 11.59 |
| 10 | E-Hentai | Cosplay | dark | `#6D009B` (0.056) | `#401F4F` (0.026) | **1.39** | 13.75 | 1.53 | 13.75 |
| 11 | E-Hentai | Cosplay | light+HC | `#9654F4` (0.194) | `#E0CCFC` (0.661) | **2.92** | 1.48 | 14.21 | 14.21 |
| 12 | E-Hentai | Cosplay | dark+HC | `#9E00E2` (0.128) | `#55266B` (0.044) | **1.89** | 11.20 | 1.88 | 11.20 |
| 13 | E-Hentai | Doujinshi | light | `#FC4F4F` (0.269) | `#FECACA` (0.676) | **2.28** | 1.45 | 14.52 | 14.52 |
| 14 | E-Hentai | Doujinshi | dark | `#9B0202` (0.070) | `#4D1F21` (0.027) | **1.57** | 13.69 | 1.53 | 13.69 |
| 15 | E-Hentai | Doujinshi | light+HC | `#FC7272` (0.339) | `#FED5D5` (0.735) | **2.01** | 1.34 | 15.69 | 15.69 |
| 16 | E-Hentai | Doujinshi | dark+HC | `#E00202` (0.159) | `#692628` (0.045) | **2.19** | 11.00 | 1.91 | 11.00 |
| 17 | E-Hentai | Game CG | light | `#1A9417` (0.214) | `#BADFB9` (0.667) | **2.71** | 1.46 | 14.34 | 14.34 |
| 18 | E-Hentai | Game CG | dark | `#147512` (0.130) | `#254226` (0.044) | **1.91** | 11.14 | 1.89 | 11.14 |
| 19 | E-Hentai | Game CG | light+HC | `#05BF0A` (0.374) | `#B4ECB6` (0.731) | **1.84** | 1.34 | 15.61 | 15.61 |
| 20 | E-Hentai | Game CG | dark+HC | `#05990A` (0.228) | `#27542A` (0.069) | **2.33** | 8.79 | 2.39 | 8.79 |
| 21 | E-Hentai | Image Set | light | `#2656AA` (0.100) | `#BECCE6` (0.598) | **4.33** | 1.62 | 12.97 | 12.97 |
| 22 | E-Hentai | Image Set | dark | `#1E4487` (0.062) | `#283349` (0.033) | **1.34** | 12.65 | 1.66 | 12.65 |
| 23 | E-Hentai | Image Set | light+HC | `#3971D2` (0.173) | `#C4D4F2` (0.652) | **3.14** | 1.50 | 14.05 | 14.05 |
| 24 | E-Hentai | Image Set | dark+HC | `#2A60BF` (0.126) | `#324360` (0.055) | **1.67** | 9.96 | 2.11 | 9.96 |
| 25 | E-Hentai | Manga | light | `#E88C1A` (0.361) | `#F8DDBA` (0.752) | **1.95** | 1.31 | 16.04 | 16.04 |
| 26 | E-Hentai | Manga | dark | `#B77011` (0.217) | `#564025` (0.058) | **2.48** | 9.74 | 2.16 | 9.74 |
| 27 | E-Hentai | Manga | light+HC | `#FCB517` (0.539) | `#FEE9B9` (0.829) | **1.49** | 1.20 | 17.57 | 17.57 |
| 28 | E-Hentai | Manga | dark+HC | `#E9911C` (0.377) | `#6C5130` (0.093) | **2.99** | 7.35 | 2.86 | 7.35 |
| 29 | E-Hentai | Misc | light | `#707070` (0.163) | `#D4D4D4` (0.658) | **3.33** | 1.48 | 14.17 | 14.17 |
| 30 | E-Hentai | Misc | dark | `#545B5E` (0.102) | `#383A3C` (0.042) | **1.65** | 11.42 | 1.84 | 11.42 |
| 31 | E-Hentai | Misc | light+HC | `#9E9E9E` (0.342) | `#E2E2E2` (0.761) | **2.07** | 1.30 | 16.21 | 16.21 |
| 32 | E-Hentai | Misc | dark+HC | `#737C81` (0.196) | `#484B4E` (0.070) | **2.06** | 8.78 | 2.39 | 8.78 |
| 33 | E-Hentai | Non-H | light | `#0F9EBC` (0.282) | `#B7E2EB` (0.705) | **2.27** | 1.39 | 15.09 | 15.09 |
| 34 | E-Hentai | Non-H | dark | `#0D7D96` (0.170) | `#23444D` (0.050) | **2.19** | 10.47 | 2.01 | 10.47 |
| 35 | E-Hentai | Non-H | light+HC | `#1BC8EC` (0.476) | `#BBEEF9` (0.786) | **1.59** | 1.26 | 16.71 | 16.71 |
| 36 | E-Hentai | Non-H | dark+HC | `#05ABB5` (0.324) | `#27595E` (0.084) | **2.80** | 7.85 | 2.68 | 7.85 |
| 37 | E-Hentai | Western | light | `#5BC13A` (0.407) | `#CEECC4` (0.771) | **1.80** | 1.28 | 16.42 | 16.42 |
| 38 | E-Hentai | Western | dark | `#4A992E` (0.244) | `#354D2E` (0.063) | **2.61** | 9.32 | 2.25 | 9.32 |
| 39 | E-Hentai | Western | light+HC | `#7ACF5F` (0.496) | `#D7F1CF` (0.819) | **1.59** | 1.21 | 17.37 | 17.37 |
| 40 | E-Hentai | Western | dark+HC | `#0FBA1C` (0.354) | `#2A5E30` (0.087) | **2.94** | 7.66 | 2.74 | 7.66 |
| 41 | ExHentai | Artist CG | light | `#D48F1C` (0.336) | `#F2DDBB` (0.742) | **2.05** | 1.33 | 15.84 | 15.84 |
| 42 | ExHentai | Artist CG | dark | `#A06D16` (0.185) | `#4F4027` (0.055) | **2.24** | 10.02 | 2.10 | 10.02 |
| 43 | ExHentai | Artist CG | light+HC | `#E88C1A` (0.361) | `#F8DDBA` (0.752) | **1.95** | 1.31 | 16.04 | 16.04 |
| 44 | ExHentai | Artist CG | dark+HC | `#D9941D` (0.360) | `#675230` (0.091) | **2.90** | 7.43 | 2.83 | 7.43 |
| 45 | ExHentai | Asian Porn | light | `#A33382` (0.118) | `#E3C2DA` (0.600) | **3.87** | 1.62 | 13.00 | 13.00 |
| 46 | ExHentai | Asian Porn | dark | `#822868` (0.073) | `#462B3F` (0.034) | **1.46** | 12.52 | 1.68 | 12.52 |
| 47 | ExHentai | Asian Porn | light+HC | `#B552A6` (0.185) | `#E9CBE4` (0.656) | **3.00** | 1.49 | 14.13 | 14.13 |
| 48 | ExHentai | Asian Porn | dark+HC | `#B63891` (0.148) | `#5C3753` (0.056) | **1.86** | 9.88 | 2.13 | 9.88 |
| 49 | ExHentai | Cosplay | light | `#6B33A3` (0.081) | `#D3C2E3` (0.580) | **4.79** | 1.67 | 12.60 | 12.60 |
| 50 | ExHentai | Cosplay | dark | `#542882` (0.050) | `#382B47` (0.030) | **1.25** | 13.09 | 1.60 | 13.09 |
| 51 | ExHentai | Cosplay | light+HC | `#9A4994` (0.138) | `#E1C8DF` (0.626) | **3.60** | 1.55 | 13.53 | 13.53 |
| 52 | ExHentai | Cosplay | dark+HC | `#7538B6` (0.100) | `#49375E` (0.050) | **1.51** | 10.55 | 1.99 | 10.55 |
| 53 | ExHentai | Doujinshi | light | `#9E2621` (0.088) | `#E2BEBC` (0.566) | **4.48** | 1.70 | 12.33 | 12.33 |
| 54 | ExHentai | Doujinshi | dark | `#7C1E19` (0.053) | `#442828` (0.029) | **1.30** | 13.29 | 1.58 | 13.29 |
| 55 | ExHentai | Doujinshi | light+HC | `#D2322C` (0.162) | `#F2C2C0` (0.613) | **3.13** | 1.58 | 13.25 | 13.25 |
| 56 | ExHentai | Doujinshi | dark+HC | `#B82C25` (0.121) | `#5D3332` (0.049) | **1.73** | 10.58 | 1.99 | 10.58 |
| 57 | ExHentai | Game CG | light | `#617D63` (0.181) | `#D0D8D0` (0.671) | **3.12** | 1.46 | 14.42 | 14.42 |
| 58 | ExHentai | Game CG | dark | `#547557` (0.154) | `#38423A` (0.050) | **2.03** | 10.46 | 2.01 | 10.46 |
| 59 | ExHentai | Game CG | light+HC | `#6B946E` (0.254) | `#D3DFD3` (0.713) | **2.51** | 1.38 | 15.27 | 15.27 |
| 60 | ExHentai | Game CG | dark+HC | `#7D9980` (0.287) | `#4B544D` (0.084) | **2.52** | 7.85 | 2.67 | 7.85 |
| 61 | ExHentai | Image Set | light | `#335BA3` (0.108) | `#C2CEE3` (0.612) | **4.18** | 1.59 | 13.23 | 13.23 |
| 62 | ExHentai | Image Set | dark | `#284982` (0.068) | `#2B3547` (0.035) | **1.39** | 12.33 | 1.70 | 12.33 |
| 63 | ExHentai | Image Set | light+HC | `#4A76C6` (0.185) | `#C9D6EE` (0.667) | **3.05** | 1.46 | 14.34 | 14.34 |
| 64 | ExHentai | Image Set | dark+HC | `#3866B6` (0.137) | `#37445E` (0.058) | **1.74** | 9.76 | 2.15 | 9.76 |
| 65 | ExHentai | Manga | light | `#DB6B23` (0.257) | `#F4D3BD` (0.695) | **2.43** | 1.41 | 14.90 | 14.90 |
| 66 | ExHentai | Manga | dark | `#994C19` (0.120) | `#4D3628` (0.044) | **1.82** | 11.21 | 1.87 | 11.21 |
| 67 | ExHentai | Manga | light+HC | `#E2884E` (0.343) | `#F6DBCA` (0.745) | **2.02** | 1.32 | 15.90 | 15.90 |
| 68 | ExHentai | Manga | dark+HC | `#D26822` (0.237) | `#654531` (0.072) | **2.35** | 8.58 | 2.45 | 8.58 |
| 69 | ExHentai | Misc | light | `#787878` (0.187) | `#D6D6D6` (0.672) | **3.04** | 1.45 | 14.45 | 14.45 |
| 70 | ExHentai | Misc | dark | `#596066` (0.114) | `#393C3F` (0.045) | **1.74** | 11.10 | 1.89 | 11.10 |
| 71 | ExHentai | Misc | light+HC | `#9E9E9E` (0.342) | `#E2E2E2` (0.761) | **2.07** | 1.30 | 16.21 | 16.21 |
| 72 | ExHentai | Misc | dark+HC | `#768188` (0.213) | `#494C50` (0.072) | **2.16** | 8.63 | 2.43 | 8.63 |
| 73 | ExHentai | Non-H | light | `#5EA8CE` (0.348) | `#CFE5F0` (0.756) | **2.02** | 1.30 | 16.12 | 16.12 |
| 74 | ExHentai | Non-H | dark | `#26607C` (0.102) | `#2A3C45` (0.042) | **1.66** | 11.47 | 1.83 | 11.47 |
| 75 | ExHentai | Non-H | light+HC | `#7EB9D7` (0.440) | `#D8EAF3` (0.799) | **1.73** | 1.24 | 16.98 | 16.98 |
| 76 | ExHentai | Non-H | dark+HC | `#3689B1` (0.218) | `#364F5C` (0.071) | **2.21** | 8.64 | 2.43 | 8.64 |
| 77 | ExHentai | Western | light | `#AA9E60` (0.338) | `#E6E2CF` (0.757) | **2.08** | 1.30 | 16.14 | 16.14 |
| 78 | ExHentai | Western | dark | `#726B3D` (0.144) | `#413F32` (0.049) | **1.96** | 10.60 | 1.98 | 10.60 |
| 79 | ExHentai | Western | light+HC | `#BBB17F` (0.435) | `#EBE8D9` (0.804) | **1.76** | 1.23 | 17.08 | 17.08 |
| 80 | ExHentai | Western | dark+HC | `#9D9354` (0.287) | `#555240` (0.083) | **2.53** | 7.87 | 2.67 | 7.87 |

- light: min state-luminance ratio 1.59 (E-Hentai/Artist CG); max 4.79 (ExHentai/Cosplay); n=20; below 1.5: 0; below 3.0: 10
- dark: min state-luminance ratio 1.25 (ExHentai/Cosplay); max 2.91 (E-Hentai/Artist CG); n=20; below 1.5: 6; below 3.0: 20
- light+HC: min state-luminance ratio 1.23 (E-Hentai/Artist CG); max 3.60 (ExHentai/Cosplay); n=20; below 1.5: 2; below 3.0: 16
- dark+HC: min state-luminance ratio 1.51 (ExHentai/Cosplay); max 3.18 (E-Hentai/Artist CG); n=20; below 1.5: 0; below 3.0: 19

## Decisions

Owner resume line, recorded verbatim:

```
STARS=B CATEGORYCELL=A HC=A D28=ok CONTEXTMENU=not-exposed
```

Delivered 2026-09-11 through the orchestrator's structured checkpoint questions (option labels selected verbatim from the plan's
Task 2 options). `STARS=B`, `CATEGORYCELL=A`, `HC=A` and `D28=ok` are the owner's own selections (owner reply ≈ 10:20 UTC).
`CONTEXTMENU=not-exposed` has a different provenance and is recorded as such in its slot below: the owner asked the orchestrator
to verify research Open Question 2 with agent-device instead of performing the VoiceOver rotor check on `Owner-iPhone-Test`.
`D28=ok` means every proposed D-28 fix is applied; no site was vetoed. Nothing is built by this plan; each slot names the plan
that builds against it.

- **STARS = B** — darken the rating-star colour in **light mode only** to ≥ 3:1; dark mode keeps `.yellow`.
  - Plan **16-19** labels the star group for VoiceOver (a single element with a label and a value, e.g. "Rating, 4.5 out of 5"),
    on every `RatingView` site including the list cells, where the audit found no numeric rating beside the stars.
  - Plan **16-23** changes the light-mode star colour only. The audit's measured candidates are `#B59000` (3.02:1 on white — fails
    the Home card's `#E8E8E9`), `#A38100` (3.69:1 on white, 3.01:1 on the Home card) and Apple's own Increase-Contrast yellow
    `#A16A00` (4.59:1 on white, 3.75:1 on the Home card). **The audit recommends `#A38100`**: it is the smallest visible departure
    from `.yellow` that clears 3:1 on both measured light backgrounds (list cell white, Home card gray). Its Home-card margin is
    0.01, so 16-23 must re-measure it from rendered pixels; if the rendered Home-card ratio falls below 3.00, 16-23 escalates to
    `#A16A00`, which has real headroom and additionally makes the light and light+IC star colours identical. No code changes here.
  - Recorded caveat: the Home card's **dark** backgrounds are the cover-derived animated gradient (1.97:1 and 2.21:1 measured on
    one cover). B as chosen leaves dark on `.yellow`, so that case is content-dependent and stays a documented caveat for the
    Nutrition Label recommendation (plan 16-26); the 16-19 VoiceOver value carries the rating regardless of the glyph colour.
- **CATEGORYCELL = A** — keep opacity 0.3 for the excluded state; no visible non-colour cue is added.
  - Plan **16-15** keeps `color.opacity(isFiltered ? 0.3 : 1)`, gives the cell D-26's adaptive text resolved against the
    **composited** colour (the category colour at 0.3 over the sheet row, gamma-space blend — the table above validates the
    composite against the rendered Misc tiles), so the excluded label goes from white 1.48:1 (light) / 1.30:1 (light+IC) to the
    best-of black ≥ 12.33:1 on every light-family excluded tile, and adds `Button` semantics plus `.isSelected` for the included
    state (VoiceOver / Voice Control read the state as a trait, not as colour).
  - The Differentiate Without Color claim for this state rests on the measured grayscale numbers alone: on E-Hentai Misc the
    included:excluded luminance ratio is **3.34** in light and **1.65** in dark; across all 80 filter variants the dark minimum is
    **1.25** (ExHentai Cosplay; 20/20 below 3.0, 6 below 1.5) and the light minimum 1.59. The Nutrition Label recommendation
    (plan 16-26) must carry that caveat verbatim: in dark mode the excluded state is a luminance-only distinction that is weak
    for about a third of the categories.
- **HC = A** — adopt the re-authored values for the 19 `lower` Increase Contrast variants; the 44 standard variants stay frozen.
  - Plan **16-15** edits exactly the 19 `contrast: high` entries listed in § Re-authoring proposal to the proposed sRGB values
    (one of them, E-Hentai Cosplay light+HC, does not keep its hue exactly because a channel clipped at 1.0); the other 21 HC
    entries and all 44 standard entries are not touched.
  - `CategoryColorsetInvariantTests` (plan 16-14) re-pins **only** the HC-40 hash: the current
    `e81b0604c84754a0260818465051f11fae99fe756b934db2f16929ea83600937` is re-derived from the edited colorsets. The standard-44
    pin `f940492af7648bf41e12a5cca24532c8f7451d79875a75b3534a7b9c0f235363` never changes. D-26's "84 byte-identical" therefore
    narrows to "44 standard byte-identical + 40 HC re-pinned", and D-27 is fulfilled: Increase Contrast never yields less badge
    contrast than standard. The change is visible only to users with Increase Contrast on.
- **D28 = ok** — every proposed non-category fix is applied; no site vetoed.
  - Plan **16-23** applies, and re-measures from rendered pixels, the fixes proposed in § Findings for: `read-glyph` (glyph colour
    from the resolved accent's luminance via the 16-14 helper), `comment-link` (light link colour `#54832A`), `comment-date`
    (`.foregroundStyle(.primary)` for the date — the first-listed option; it is colour-only, whereas dropping the gray-5 card
    would move layout), `offline-notice` (text `.primary`, `.orange` stays on the glyph), `swipe-move` (a tint that carries white,
    measured), `swipe-pages` (an explicit `.tint` on `inspectButton`, measured), `swipe-update` (a darker tint, `#B36119`-class in
    light, measured), `newdawn` (darken the light gradient's top stop, e.g. `#008198`; a scrim only if the stop cannot pass).
    `swipe-delete` and `swipe-pause` are applied as proposed: **kept**, recorded as platform conventions (`.red` is Apple's
    delete tint; Apple's Increase-Contrast dark palette is pastel by design, so every white-label swipe action fails dark+IC).
    `stars-list` / `stars-card` are the STARS decision above. `secondary-meta` proposed no change and stays unchanged; it is the
    one known `.secondary` caveat (4.00:1 in light, unchanged under Increase Contrast) for the Nutrition Label recommendation.
  - Plan **16-22** adds the Differentiate Without Color carriers: per-level activity-log glyphs (`circle.fill` for debug / info /
    notice, `exclamationmark.circle.fill` for error, `xmark.octagon.fill` for fault, palette-rendered so the mark is `.primary`
    and the colour is redundant — this is also the `log-dot` contrast fix), a Laboratory on/off state glyph (or a real `Toggle`)
    with `.isToggle` / `.isSelected`, and `.underlineStyle(.single)` on comment link runs in `LinkColoredText`.
- **CONTEXTMENU = not-exposed** (research Open Question 2) — SwiftUI `.contextMenu` items are **not** surfaced as VoiceOver
  custom actions on iOS 26.5, while `.swipeActions` are.
  - Plans **16-16** and **16-19** therefore add explicit `accessibilityAction`s for every context-menu item (tag cells in the tag
    cloud, Downloads rows, reader pages and the other `.contextMenu` sites those plans own); this is not a duplication.
  - **Provenance.** This is a simulator accessibility-tree read, not a VoiceOver rotor pass on the physical device. The
    orchestrator ran `agent-device snapshot --actions` (private-AX backend) on the iPhone 17e simulator `67377A20…` (iOS 26.5) on
    2026-09-11 at ≈ 10:35 UTC. The Downloads row — `DownloadsView.swift` `.contextMenu { downloadContextMenu() }` = Detail,
    Pages, Move, [Update], [Pause], Delete; `.swipeActions` = Pages, Move | Delete for a completed download — exposed the custom
    actions `["Pages", "Move", "Delete"]`, exactly the swipe-action set; the context menu's distinguishing `Detail` item was
    absent. The reader page (`.contextMenu` only, no swipe actions) could not be read by the private-AX backend and is not
    corroborating evidence. No screenshot enters the repository. Plan 16-25's manual VoiceOver walkthrough on the physical device
    confirms the behaviour with the rotor.

### D-25 re-sweep candidates

Every screen where round 2 adds a visible element or a size-changing contrast change is re-walked at XXL / AX3 / AX5 in plan
16-26. Per D-24, a change of text or glyph *colour* only moves no layout and is excluded. Applying that rule to the decisions above:

| Screen | Change | Re-sweep? | Reason |
|---|---|---|---|
| Frontpage / Toplists / Favorites / Search list cells | STARS=B star colour (16-23) | **excluded** | Colour only; the `RatingView` glyphs keep their size and count |
| Home hero cards | STARS=B star colour (16-23) | **excluded** | Colour only; no backing shape was chosen under B |
| Detail header (`DescScrollRatingItem`) | none | **excluded** | The header stars are `.primary`, not `.yellow`; 16-23 does not touch them |
| Filters sheet (`CategoryCell`) | CATEGORYCELL=A adaptive text + semantics (16-15) | **excluded** | Text colour and accessibility traits only — no visible cue added, no layout moves |
| Any screen showing a category badge with Increase Contrast on | HC=A re-authored HC bytes (16-15) | **excluded** | Background colour only; badge geometry unchanged |
| Settings › General › App Activity Logs | per-level glyphs replace the colour-only disc (16-22) | **included** | A newly added glyph is one of D-24's two layout risks; the glyph box is meant to be unchanged and the re-sweep proves it |
| Settings › Laboratory | on/off state glyph or `Toggle` (16-22) | **included** | New glyph or control in the cell; joins regardless of whether the cell height changes |
| Comments (`LinkColoredText`) | underline on link runs (16-22) | **excluded** | Text decoration inside the line box; 16-22 re-measures and promotes it to the list only if any line height moves at AX5 |
| Detail header Read button, Detail offline notice, Detail comment preview, Downloads swipe actions | D-28 fixes (16-23) | **excluded** | Every § Findings row is marked `Layout moves? No`: colour, tint or weight-neutral changes only |
| NewDawn greeting | D-28 `newdawn` fix (16-23) | **excluded** | Darkening a gradient stop is colour only; if 16-23 falls back to a scrim (a new shape), 16-23 adds NewDawn to this list |

D-28 sites whose fix changes size: **none** — the audit proposed colour-only fixes for every failing site, so no exceptions exist.
The included set is therefore Activity Logs and Laboratory, both from plan 16-22; plan 16-26 re-walks exactly those unless a
later plan records an exception here.

Plan 16-15 (CATEGORYCELL=A, HC=A) records **no exception**: it changed badge text colour, Increase Contrast background bytes and
accessibility traits only, so per D-24 the Filters sheet and the badge screens stay **excluded** (see `### 16-15 result`).

### 16-15 result

Plan 16-15 built the category half of the decisions above; this is the rendered evidence, taken on the iOS 26.5 iPhone 17e
`67377A20-A90A-4DB2-9A9C-9965532B0AA9` with the `app.ehpanda.personal` build of the tree at `b8296146` installed over the
existing bundle (`plutil -extract CFBundleIdentifier raw` printed `app.ehpanda.personal` before `xcrun simctl install`; nothing
uninstalled or erased; no session, no credential). The simulator's baselines (`appearance light`, `increase_contrast disabled`,
`content_size large`) were read after boot, restored and read back identical, and the device was shut down.

**What changed.** `CategoryLabel` (list cells, Detail header) and the Filters `CategoryCell` draw black or white text chosen by
`Color.contrastingForeground(in:)` from the resolved background (D-26); `CategoryCell` is a `Button` (`.plain`) whose visible
name is its label, with `.isSelected` while the category is included (CATEGORYCELL=A: opacity 0.3 kept, no visible cue, no
catalog key — the trait alone carries the state). The 19 `lower` `contrast: high` entries of § Re-authoring proposal were
rewritten to the proposed values (HC=A); the standard-44 pin `f940492a…5363` is byte-identical, and the HC-40 pin was
re-derived to `84accf722ad6601f41e6cf8d069344f5c066f58df42bfdbf21b780dbcc539407` (from `e81b0604…0937`). After the rewrite:
84 / 84 variants ≥ 4.5:1 best-of, 47 flips to black (every re-authored variant keeps the text side its proposal row named),
worst best-of still ExHentai / Game CG / light 4.62, and **0 / 40** HC variants below their standard sibling (was 19 / 40); the
worst HC best-of is now E-Hentai / Game CG / dark+HC 5.91. Padding, font, corner radius and `lineLimit` are untouched.

**Badge flips, rendered set.** Only E-Hentai public content is reachable on this simulator, so the rendered set is the ten
Filters tiles plus the three categories the Frontpage list happened to show (Misc, Doujinshi, Image Set) and the Doujinshi Detail
header, each in light / dark / light+IC / dark+IC. Dominant colours sampled from the captures:

| Set | light | dark | light+IC | dark+IC | Black of rendered |
|---|---|---|---|---|---|
| Filters tiles, included (10 per mode) | 7 black (Doujinshi, Manga, Artist CG, Game CG, Western, Non-H, Asian Porn) | 3 black (Manga, Artist CG, Western) | 9 black (all but Image Set) | 7 black (all but Doujinshi, Cosplay, Image Set) | **26 / 40** |
| Frontpage list badges (Misc, Doujinshi, Image Set) | Doujinshi black | none | Misc, Doujinshi black | Misc black | **4 / 12** |
| Detail header badge (Doujinshi) | black on `#FC4F4F` 6.37 | white on `#9B0202` 8.74 | black on `#FC7272` 7.79 | white on `#9B0101` 8.76 | 2 / 4 |

Every rendered background equals its colorset entry, including the re-authored bytes (Image Set light+IC `#2956A3`, dark+IC
`#1B4389`; Misc dark+IC `#8B969C`; Doujinshi dark+IC `#9B0101`; Asian Porn dark+IC `#DD67CA`; Cosplay light+IC `#C27AFF`, dark+IC
`#6B009C`; Game CG dark+IC `#069E0C`), and every rendered text/background pair is ≥ **4.69:1** (worst: E-Hentai Asian Porn, light,
black on `#B551A5`), against 2.70 – 3.30 for the white text these badges had before. The full 47 / 84 count is the invariant
test's, not a rendered count; the rendered subset agrees with the table row by row.

**Excluded cell composite.** The Filters `Form` section card is `secondarySystemGroupedBackground`: the section card sampled
`#FFFFFF` / `#2C2C2E` / `#FFFFFF` / `#363638` (light / dark / light+IC / dark+IC) — that colour's values at the elevated (sheet)
interface level — while the sheet behind it sampled `#F2F2F7` / `#1C1C1E` / `#EBEBF0` / `#242426` (`systemGroupedBackground`).
The cell chooses its text against `category.resolve(in:).composited(over: secondarySystemGroupedBackground, opacity: 0.3)`, the
16-14 helper's linear blend. Misc, excluded through the new `Button` (tapped once to exclude, once to restore; the filter was
left as found, all ten included):

| Mode | Raw Misc (L) | Linear composite L → text | Rendered tile | Rendered ratio of chosen text | White would be |
|---|---|---|---|---|---|
| light | `#707070` (0.162) | 0.749 → black | `#D4D4D4` (L 0.658) | **14.17** | 1.48 |
| dark | `#545B5E` (0.102) | 0.048 → white | `#383A3C` (L 0.042) | **11.42** | 11.42 |
| light+IC | `#9E9E9E` (0.342) | 0.803 → black | `#E2E2E2` (L 0.761) | **16.21** | 1.30 |
| dark+IC | `#8B969C` (0.297) | 0.115 → white | `#505356` (L 0.086) | **7.74** | 7.74 |

The dark+IC row is the case the composite exists for: the re-authored raw Misc HC colour would pick *black* (L 0.297), and black
on the rendered `#505356` wash reads 2.71:1; the composite picks white at 7.74. The renderer blends in gamma space (rendered
`#D4D4D4` = 0.3 × `#707070` + 0.7 × `#FFFFFF` byte-wise) while the helper blends in linear light; both were computed for all 80
filter variants against both the elevated card and the base-level grouped background, and every one of the 320 pairs picks the
same text: light-family washes have L ≥ 0.53, dark-family washes L ≤ 0.16, so no case sits near the 0.1791 crossover.

**Assistive-technology read.** The Filters accessibility tree now lists ten `Button` elements labelled with the category names
(before: unlabelled text with no role). Raw traits read from the simulator: included `['Button', 'Selected']`, and Misc after
exclusion `['Button']` — the state travels as the trait, not as colour or a label.

**D-25.** Nothing is added to the re-sweep list: CATEGORYCELL=A added no visible cue, the text-colour flips and the HC background
bytes move no layout (D-24), and the Filters cells' `Button` conversion keeps the same frame (the `LazyVGrid` cells still measure
100 × 30 pt at `.large`). The `Filters sheet (CategoryCell)` and `Increase Contrast` rows above stay **excluded**.

**Evidence (owner review; never committed, D-32).** Full-scale captures under `$HOME/Library/Caches/ehpanda-phase16/round2/badge-review/`,
named `<mode>-<screen>.png` with mode ∈ `light-std`, `dark-std`, `light-ic`, `dark-ic` and screen ∈ `frontpage` (top of the
Frontpage list, all Misc), `frontpage-scrolled` (Misc, Doujinshi, Image Set badges), `detail-header` (Doujinshi header badge),
`filters` (all ten tiles included), `filters-excluded` (Misc excluded) — 20 files.
