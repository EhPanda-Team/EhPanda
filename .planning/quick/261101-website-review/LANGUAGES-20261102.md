# Reading and translation language review

Owner requested matching Reading's source language to Live Text's untranslated source, translating
Live Text into the selected interface language, and capturing Comments at its initial position.

| Interface | Reading and Live Text source | Translation target |
| --- | --- | --- |
| English | Japanese book 4217037 | English |
| German | English book 4223235 | German |
| Japanese | English book 4223235 | Japanese |
| Korean | Japanese book 4217037 | Korean |
| Traditional Chinese | Japanese book 4217037 | Traditional Chinese |
| Simplified Chinese | Japanese book 4217037 | Simplified Chinese |

The rule applies to both screenshot groups. Reading remains page 6 and Live Text page 12.
The six translation records contain real responses from installed Apple Translation models, recorded
on the host through `TranslationSession(installedSource:target:)`. The native capture app replays
them through its actual lettering removal, layout and translation renderer. These captures verify
the translated presentation; they do not constitute an end-to-end test of requesting translation
inside the app. The owner acknowledged this distinction and requested continuing.

The current fixture repository's 64 unique gallery detail pages were inspected. Gallery 3845660,
MIKOREI LOG vol. 2, has an image in its first uploader comment (comment 0). Both groups therefore
use that gallery for Comments. Its anonymous detail response was refreshed to resolve expired
preview URLs; the posted image and preview were acquired without credentials. Previous fixture
versions remain unchanged. New content-addressed, screen-specific fixtures are in the local ignored
`.capture/website-language-20261102/` directory, with complete checksum validation. Other screens
retain their own approved fixtures and existing images.

The capture manifest now supports `commentImage` assets. The fixture collector can opt into images
inside the selected gallery's comment bodies, excluding contact icons and deduplicating repeated
URLs. Validation verifies these references; older fixtures remain compatible. The collector tests
passed (54 tests), strict SwiftLint passed, and the native UI capture build succeeded.

Review: `http://127.0.0.1:8774/languages-20261102/`. The previous review and images remain available
for per-image comparison. All 72 affected coordinates were recaptured; the other 120 images are
retained. All 192 coordinates passed checksum, dimensions, readiness, locale/theme, gallery/page,
source-language and target-language checks. All 192 browser routes loaded their original-size PNG
and previous-image comparison without JavaScript errors. Both task-created simulators were removed.

The two native batches each produced 24 verified coordinate attachments, with no test failures:
`/tmp/website-titles-all-1793623348.xcresult` (light) and
`/tmp/website-titles-all-1793623726.xcresult` (dark). The 24 Comments captures verify comment 0 at
the initial position, zero unknown requests/pending images, and consecutive identical PNGs.
The review's `audit.json`, `provenance.json`, `translation-evidence/` and per-image `evidence/`
record the results. Owner visual approval and publication remain separate.

Observed existing issue: the selected comment exposes literal `<strong>` markup. Its image loads
correctly. The review preserves the actual UI and annotates the issue; no screenshot retouching or
unrelated production parser changes were made.
