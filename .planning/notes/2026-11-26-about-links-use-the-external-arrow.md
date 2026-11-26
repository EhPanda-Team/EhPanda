---
date: "2026-11-26T09:00:00Z"
promoted: true
promoted_to: ".planning/quick/261126-iq9-fix-the-findings-and-release-a-new-beta-/"
---

# About page links use the external-link arrow: done in quick 261126-iq9

Source: owner, 2026-11-26. Owner direction: record this. Implemented 2026-11-26 in quick 261126-iq9.

## Request

The link rows on the About page end with a chevron. Change that symbol to the arrow pointing to the top right
that the General settings page already uses for its external link.

## Current state

- About: `LinkRow` in `AppPackage/Sources/SettingFeature/Components/AboutView.swift` draws each `Link` with
  `title.withArrow()`, which is `chevron.right` (`.secondary`, `.imageScale(.small)`, opacity 0.5) from
  `AppPackage/Sources/AppComponents/ViewModifiers.swift`. Five rows use `LinkRow`, all of them open a URL.
- General: `privacyPolicyRow` in `AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift` draws
  `Image(systemSymbol: .arrowUpRight)` with `.imageScale(.small)`, `.foregroundStyle(.secondary)` and
  `.accessibilityHidden(true)`, at full opacity.

## Target

The About link rows draw the same arrow as the General privacy policy row (symbol, scale, style, hidden from
accessibility), so both pages mark an external link the same way. The chevron stays for rows that push a page.

## Open for planning

- Whether the arrow becomes one shared helper used by both pages instead of two copies.
- Whether the opacity follows General (full) or the chevron's 0.5.
