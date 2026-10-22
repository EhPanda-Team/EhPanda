# Slideshow tag containers — D113, 2026-10-22

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Status: D114 selects A (Liquid Glass); implemented on 2026-10-22. B remains comparison material.
Base source: `d2ecf5096718cf954eed94c3eff375ee52ee71cd`.

The owner requests Liquid Glass and Material alternatives for slideshow tags. This remains a
container-only exploration: preserve D111's card-wide gradient brightness, the existing tag data,
font, foreground policy, padding, spacing, corner radius and slideshow layout.

## Variants

| Option | Native implementation | Visible comparison |
|---|---|---|
| A — Liquid Glass | `.glassEffect(.regular, in: .rect(cornerRadius: 6))` per tag, grouped in `GlassEffectContainer(spacing: 0)` to keep distinct tag shapes. | Highlighted edges and greater background color transmission. |
| B — Material | `.background(.regularMaterial, in: .rect(cornerRadius: 6))` per tag in both appearances. | Flatter surface; dark samples have a stronger separation between tag text and background. |

Both replace the previous custom background/outline. Neither adds a tint, new interactivity,
font change or card-wide dimming. The pre-selection review build's light-solid/dark-material
hybrid is the comparison baseline; B applies Material in light appearance as well and removes the custom line.
The comments above describe the supplied screenshots, not a full contrast/accessibility audit.

Exact changes: [A patch](variants/a-glass.patch), [B patch](variants/b-material.patch).
The SDK declarations confirm both APIs on the deployment target. Apple reference:
[Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views).

## Visual review

Open the retained [comparison notes](index.html) for the historical light, warm-dark and cool-dark variants. The page now retains the comparison labels and text only; native image files have been removed.
It does not provide a current visual comparison of either material.

| Scene | A: native full screen | B: native full screen | Comparison page |
|---|---|---|---|
| Light | Glass (image removed from repository history) | Material (image removed from repository history) | Both (image removed from repository history) |
| Warm dark | Glass (image removed from repository history) | Material (image removed from repository history) | Both (image removed from repository history) |
| Cool dark | Glass (image removed from repository history) | Material (image removed from repository history) | Both (image removed from repository history) |

The fixtures contain only neutral geometric artwork and synthetic titles. The carousel can select
a different numbered fixture on launch; all fixtures share the compared tags, counts and cover
palette. The remaining artifacts contain written findings and source; the historical image files have been removed.

## Prototype verification and restoration — D113

Both variants pass strict lint and native builds with zero errors, compiler warnings or analyzer
warnings. Six 1668×2420 iPad Pro 11-inch (M5), iOS 27.0 portrait captures cover light and warm/cool
dark at Large text size. Native full-screen rendering is used because material compositing must
be evaluated in its real window. The preview selectors and all three comparison states were
visually checked in the browser. No new behavioral test, landscape, large-text, VoiceOver or
Reduce Transparency sweep is claimed for these temporary styling proposals.

Only the disposable simulator's Reduce Motion preference was set for stable gradient comparisons
(readback `1`). The normal review iPad's app/data/settings were not changed. The temporary device
was shut down and deleted. Production source was restored byte-for-byte (SHA-256 checked), and a
third clean build restored the baseline build output. D113 ended with no production source diff;
D114 subsequently applies the selected A patch as recorded below.

Raw build reports, lint logs, capture manifest and original source backup remain in the ignored
`.build/library/tag-container-review/` directory. Patches and screenshots above are the durable
review artifacts. Phase 17 gates and screenshot baselines are unchanged.

## Selected implementation — D114

The owner selected Liquid Glass. `75a50edd83449783730eab8931b515dd00f51c52` applies the exact A patch to
`AppPackage/Sources/HomeFeature/HomeGalleryInformation.swift`. Light and dark slideshow tags use
regular Liquid Glass with the existing 6-point corners and a zero-spacing GlassEffectContainer.
Keep the same tag text, semantic foregrounds, padding, flow spacing and noninteractive behavior.
D111's card-wide gradient brightness and title/metadata policy stay intact.

The final source file's SHA-256 matches the A source used for all three native comparison captures.
A fresh native build and strict lint pass with zero compiler/analyzer warnings or errors. This pass
reuses that exact-source light/warm-dark/cool-dark visual evidence; no additional behavioral suite
or screenshot sweep was run for the selected styling-only change. Verification and parity records
are in `.build/library/slideshow-glass-selected/`.

The normal review iPad was updated in place and launched without fixture environment keys; its
account/data and system settings were preserved. This resolves D113's selection without changing
Phase 17 gates or promoting screenshot baselines.
