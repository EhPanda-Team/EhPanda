# Global gallery-title preference — 2026-11-02

Owner requested applying Show Japanese Titles to all gallery titles, then recapturing all website
screenshots. Existing screenshots and approved selection fixtures remain preserved.

## Implementation

`Gallery` retains normal and optional Japanese titles. Its preference resolver uses nonblank Japanese
text when enabled and otherwise the original title. Older serialized galleries decode without the
new optional field. Shared row/grid cells and Home slideshow, Frontpage and Toplists observe the
existing shared setting; visible text and VoiceOver use the same selected title. Detail header and
navigation titles use the same resolver. Download projections now preserve both source variants
instead of choosing Japanese unconditionally. Explicit normal/Japanese fields in Gallery Information
remain separately labeled; download folder identities are unchanged.

HTML listings carry only the site's selected title. Every gallery-list request therefore enriches
its parsed rows with both title variants using the existing bounded gdata metadata request. This
preserves HTML ordering, rating, cover, page count and vote-strength tags. Unresolved metadata leaves
the original HTML row intact, while transport failures follow the existing visible retry path.
The metadata decoder handles `title_jpn` and HTML entities. The upstream field and batch contract
are documented in [EHWiki API](https://ehwiki.org/wiki/API).

Capture scene preparation retains the Japanese title already present in the saved real detail
response. Fixture content, selected centers and Frontpage arrangements are unchanged.

## Verification

- FeatureTests and UITests build-for-testing succeeded; strict SwiftLint and diff whitespace checks pass.
- 22 focused tests passed: preference/fallback/legacy decoding, metadata decoding and all list
  request baselines. List tests deliberately return different API page counts to confirm title
  enrichment preserves the HTML list's other fields.
- On the iPhone Air simulator, toggling Show Japanese Titles off and on changed the existing Home
  center from `[ごろ寝工房 (レルビィ)]` to `[Gorone Koubou (Reluvy)]` and back without relaunching.
  Evidence: `.capture/website-titles-20261102/title-preference-{off,on}.json`.
- Native Home images passed title and arrangement checks. The current center retains its tags.
- A scrolled native Toplists check verified four visible Japanese titles against the real fixture.

## Recapture

Completed capture matrix: iPhone Air portrait, 1260 × 2736; two content groups × six locales × two appearances
× eight screens (192). The owner refined capture preferences: Korean/Japanese/Traditional Chinese/Simplified Chinese
use Japanese titles (with original-title fallback); English/German use original titles. This policy
is confined to isolated capture settings; the app default and manual preference are unchanged. Native batches pin one appearance before cloning and keep normal test
parallelism. The independent review page is http://127.0.0.1:8774/titles-20261102/.

The review's provenance records app executable hash, base commit and working-diff hash. No commit,
publication or baseline approval is implied. Owner visual review remains required.

All four native capture batches (18 coordinates each) passed. Temporary process-inventory
unavailability interrupted direct captures; those failures remained explicitly marked until
successful recapture after the native batches released resources. No process-disappearance banner
was observed. No test parallelism or retry-policy override was introduced.

The 64 earlier all-Japanese English/German images are archived under the review page's
`previous-all-japanese/` directory. Those coordinates were recaptured with the original-title
preference; the 128 matching Asian-language images are retained. The manifest records the build hash
per coordinate and links changed coordinates to their immediately preceding images.


Final capture audit: 192/192 ready, no errors. The two final locale-policy native batches each
passed 12 coordinates. Home center/Frontpage and Detail titles were checked against the appropriate
real fixture title for every interface locale; prior image hashes and all image dimensions/readiness
checks passed. All task-created source simulators were removed after captures completed. Owner
visual approval is pending; the local review server remains running.

Browser verification also passed all 192 coordinate routes: native dimensions, available previous-image
links and zero JavaScript errors. The review retains independent notes and image-hash-based stale
approval handling.
