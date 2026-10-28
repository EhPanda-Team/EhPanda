# Native before / after screenshot review

The owner subsequently selected B1–B6 and requested the persistent Library title menu, replacing
the compact source picker shown in this earlier proposal. See [the implementation record](UI-IMPLEMENTATION.md)
for final-source captures; these 18 pairs remain the original review evidence.
The final gallery is `implemented.html` in the same folder: 18 baseline/implemented pairs and
18 supplementary captures. Its exact list and checksums are in
[UI-IMPLEMENTATION-MANIFEST.json](UI-IMPLEMENTATION-MANIFEST.json).

The owner's clarification replaces the earlier text-only UI deliverable with **18 native screenshot
pairs (36 originals)**. The after images come from a disposable native prototype of B1–B6; production
page UI was unchanged when those review images were captured. Images remain outside repository history.

## Review gallery

The local comparison gallery is `http://127.0.0.1:8756/` while its review server is running. It includes
a selector, side-by-side originals, full-resolution links and the complete screenshot list.
The persistent gallery and images are in:

```text
$HOME/.codex/visualizations/2026/10/28/01a18093-35bb-7490-9bee-b93c0bc77dd8/bottom-bars/
```

Open `index.html` in a browser without a server, or read its sibling `SCREENSHOTS.md` for image links.
Each row below exists for both **iPhone 17** and **iPad Pro 11-inch (M5)**. The exact paths are
`before/<device>-<suffix>.png` and `after/<device>-<suffix>.png`, where device is `iphone` or `ipad`.

| Page / text size | Filename suffix | Candidate | Visible review focus |
|---|---|---|---|
| Library, standard | `library` | B1 / B5 | Compact native source bar and soft bottom treatment; expanded iPad sidebar retains automatic bottom with top tabs. |
| Home, standard | `home` | B2 | Bottom-tab edge treatment; top-tab iPad context. The slideshow can select a different gallery between frames. |
| Search, standard | `search` | B3 | Native search and root layout; empty sections have little content near the bottom, so the visible difference is small. |
| Settings, standard | `settings` | B4 | Bottom-tab edge treatment around the scrolling form. |
| Library, AX1 | `library-ax1` | B1 / B5 | Cold entry: native title/search, picker and lower content clearance. |
| Library, AX3 | `library-ax3` | B1 / B5 | Cold entry at the larger accessibility size. |
| Library, AX5 | `library-ax5` | B1 / B5 | Cold entry at the largest size; content continues beyond the viewport. |
| Archives, standard | `archives` | B6, optional | Funds/action use a native bottom bar; visible footer placement is preserved in these portrait captures. |
| Archives, AX5 | `archives-ax5` | B6, retained behavior | Live size change and scroll to the footer; funds/action remain in the single scrolling column. |

## Provenance

- Source base `f195b7eaaf`; [UI-PROPOSAL.patch](UI-PROPOSAL.patch) contains all five proposed view changes. Both preserved patches use zero-context unified diff;
  replay from the recorded source base with `git apply --unidiff-zero <patch>`.
- Baseline and proposal both include one [capture-only fixture route](UI-CAPTURE-FIXTURE.patch) for `/archiver.php`. It returns
  `GalleryArchive.html`; this network stub change is absent from production and the UI proposal patch.
- Offline HTML and abstract cover fixtures drive real parsers, stores and native views. Home uses
  the existing Library fixture galleries. Archives supplies six sizes and artificial funds; 780x is
  selected to show the enabled action. The download action was never invoked.
- Both apps built successfully with Xcode 27.1 (27A9275), Debug, against the same resolved packages.
  Both builds have zero compiler/lint warnings; the five proposed views pass strict SwiftLint.
- Runtime: iOS/iPadOS 27.0; portrait; English/en_US; light appearance; status-bar override 9:41.
  iPhone viewport 402×874 points / 1206×2622 pixels; iPad 834×1210 points / 1668×2420 pixels.
- Standard content size is Large. AX1/AX3/AX5 map to Accessibility Medium / Extra Large /
  Extra Extra Extra Large. Each Library capture is a cold entry. Archives AX5 changes size live,
  then scrolls to the existing footer. Content size is restored to Large afterward.
- Search baselines were refreshed after fixture gallery entry so both sides have matching history
  state. Home's automatic slideshow remains live, including behind Archives; selected gallery text
  is not a UI change. Captures are not claimed to be pixel-identical outside the proposed effect.
- [SCREENSHOT-MANIFEST.json](SCREENSHOT-MANIFEST.json) records every image's dimensions and SHA-256,
  matching native UI-outline hashes, before/after executable hashes, fixture hashes and patch hash.
  The PNG files were not cropped, composited, retouched or generated.

Scratch source: `/tmp/ehpanda-261028-ui-proposal`; baseline app:
`/tmp/ehpanda-261028-ui-before.app`; proposal build:
`/tmp/ehpanda-261028-ui-proposal-build`. The review simulators retain the proposal app for inspection.

## Scope and next decision

Review **B1–B5 together**, with **B6 as an optional addition**. These images fulfill the requested
visual proposal; they do not assert the full acceptance matrix passed. Landscape, window resizing,
Duo postures, dark appearance, keyboard/focus behavior, pushed destinations, final-row reachability,
VoiceOver and the remaining cold/live Dynamic Type combinations still need implementation validation
after selection. The existing title/search policy and Phase 17 gates remain unchanged.
