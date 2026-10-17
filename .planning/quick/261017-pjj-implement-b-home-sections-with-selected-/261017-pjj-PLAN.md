---
quick: 261017-pjj
status: planned
mode: quick
files_modified:
  - AppPackage/Sources/HomeFeature/
  - AppPackage/Sources/AppComponents/GalleryCoverStyle.swift
  - AppPackage/Tests/HomeFeatureTests/GalleryCoverLayoutTests.swift
  - EhPandaUITests/LandscapePaneUITests.swift
---

# Large-window Home implementation

## Locked decisions

D99 authorizes implementing the current B+C combination: B Frontpage/Toplists/Other and the
D98-selected C slideshow. D100 requires every Home gallery title to honor the existing default-on
simplified-title setting, including compact/Duo titles and cover accessibility labels. D96–D97
exclude redundant Popular labels, uploader/date in slideshow and duplicated metadata.

Preserve Home section order, native title/scroll edge, navigation, carousel identity/center anchor,
Duo split presentation, reader behavior and existing data requests. Use the existing measured
GalleryViewport.isLarge policy for richer single-pane Home; no new adaptive slideshow grouping
mode or device-name check. This is an iOS implementation, not a macOS target port.

## Task 1 — Implement the selected section presentation

- Thread large-window section styling through HomeSectionsView without changing routing/reducers.
- Give C slideshow a larger cover, grouped page/category fields, rating/language and up to three
  existing nonduplicate tags. Preserve gradient behavior; permit rich content to grow with text.
- Give B Frontpage two rows of larger covers, two-line titles and pages/language. Size rows from
  content so text is never clipped by the old cover-only height. Toplists retains 2-by-3 groups,
  enlarges covers and includes existing category/pages/language/rating information.
- Increase Other card size and add localized purpose descriptions; do not repeat their purpose
  in a redundant footer. Keep all three destinations and the native section actions.
- Use the existing shared setting/parser for every gallery title and accessibility title in Home.
- Add semantic cover roles instead of affecting the current shared compact/standard/hero sizes.

## Task 2 — Verify and deliver

- Strict lint and warning-free native builds. Run HomeFeature layout/navigation tests plus the
  existing simplified-title model suite. Add meaningful rich-card geometry/metadata coverage.
- Native iPad: verify cold Home and rotation at Large, AX1, AX3 and AX5; verify native title,
  ordinary Frontpage navigation, new metadata and live simplified-title setting changes.
- Preserve compact/Duo routing via existing feature tests; assess compact title behavior.
- Retain native evidence, including failed attempts. Update the original review iPad in place,
  clearing fixture-only launch flags and keeping its account/data. No Device Hub or baseline promotion.
- Record exact implementation/test source boundaries and any remaining limits in SUMMARY.md;
  update session decisions and STATE.md. Commit code atomically, then documentation.

## Execution

Inline in the existing owner-designated app-design worktree. GSD CLI 1.17.0 initialized this quick
task; no subagent dispatch or model override is used. No new branch/worktree is required.
