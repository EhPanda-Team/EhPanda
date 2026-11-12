# Adaptive Home tags and cover sizing

Owner-directed continuation of the Home pose review: compact slideshow tags are visible only when
the complete title, metadata and tags fit the existing card height. Oversized Frontpage covers shrink
to the corresponding slideshow cover; smaller covers stay unchanged. Preserve native navigation,
Dynamic Type and the accepted card height. Validate tag presence/absence and cover geometry using
the local fixture build, with strict lint and focused layout checks. No commit, generation or pin change.

## Owner continuation: maximum aspect ratio

Use the supplied regular-card reference (approximately 751 × 274 points) as the maximum width/height
ratio. Preserve card heights; narrow overly wide cards, retaining centered snapping and neighboring
card peeks. Replace the old orientation/900-point width threshold with the height-derived ceiling.
Validate compact, regular and split cards across normal and accessibility sizes. Leave the owner's
standard iPhone review simulator available. No commit or baseline change.

## Owner continuation: native top-bar refresh experiment

Try integrating Home refresh beside the iPad top tab bar using native toolbar configuration.
Verify actual iPad landscape rendering before retaining a change. Preserve phone and Duo navigation,
pushed destinations, loading state and action ownership. Do not substitute a custom bar or remove
the button in favor of pull-to-refresh.

## Owner continuation: iPad slideshow title alignment

Apply the compact title's maximum-height, top-leading alignment to the regular iPad slideshow
title. Remove its two-line reservation and intrinsic-height override; preserve the title font,
card sizing and metadata layout. Keep metadata at its intrinsic height so the title uses the
remaining space. Validate the simulator build and lint; no new baseline or capture matrix.

## Owner continuation: Toplists star and commit

Reduce only the Toplists rating star by one semantic font step, from inherited subheadline to
footnote. Preserve rating digits, Dynamic Type and slideshow rating appearance. Validate build
and strict lint, then commit this change together with the outstanding iPad title work and records.
Preserve the separately committed slideshow color adjustments.

## Owner continuation: tighter Toplists metadata

Match the Toplists star to the pages caption style, and group category/pages/rating with a
4-point gap so flexible spacers do not expand those internal gaps. Capture the updated iPad Home.
