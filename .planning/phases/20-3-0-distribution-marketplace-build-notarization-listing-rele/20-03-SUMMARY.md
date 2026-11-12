---
phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele
plan: "03"
subsystem: infra
tags: [altstore-pal, altstore, sidestore, source-json, jq, adp]

requires: [20-01, 20-02]
provides:
  - "`actions-tool/altstore-pal.template.json`: source `app.ehpanda.altstorepal`, app `app.ehpanda.marketplace`, AltStore.json's metadata, `nsfw: true`, `marketplaceID: \"\"`, no screenshots, empty `appPermissions`, no versions"
  - "`altstore-add-version.jq` PAL mode: optional `assetURLs`, `entitlements` and `marketplaceID` (via `$ARGS.named`); `sha256` optional only with `assetURLs`"
  - "`check_source(pal=True)` in `altstore_languages.py`; `check_source` without `pal` unchanged"
  - "Golden outputs of the Classic, SideStore and beta filter calls (`tests/fixtures/add-version-golden/`)"
  - "`tests/fixtures/pal-release-assets.json`: a release asset list with an ADP uploaded as `EhPanda-AltStorePAL-<file>`"
affects: [20-05, 20-08, 20-10]

actuals:
  tokens: 9000
  tasks: 2
  commits: 4

tech-stack:
  added: []
  patterns:
    - "Golden files for a jq filter: frozen inputs plus outputs captured before the change, compared byte for byte"
    - "New filter arguments are read with `$ARGS.named.<x> // null`, so callers that omit them are unaffected"

key-files:
  created:
    - actions-tool/altstore-pal.template.json
    - actions-tool/tests/fixtures/pal-release-assets.json
    - actions-tool/tests/fixtures/add-version-golden/classic.input.json
    - actions-tool/tests/fixtures/add-version-golden/classic.output.json
    - actions-tool/tests/fixtures/add-version-golden/sidestore.input.json
    - actions-tool/tests/fixtures/add-version-golden/sidestore.output.json
    - actions-tool/tests/fixtures/add-version-golden/beta.input.json
    - actions-tool/tests/fixtures/add-version-golden/beta.output.json
  modified:
    - actions-tool/altstore-add-version.jq
    - actions-tool/altstore_languages.py
    - actions-tool/tests/test_altstore_add_version.py
    - actions-tool/tests/test_source_templates.py

key-decisions:
  - "A PAL entry's fields are, in order: version, buildVersion, marketingVersion, date, localizedDescription, localizedDescriptions, downloadURL, assetURLs, size, minOSVersion (Research code example). It has no sha256."
  - "`sha256` is read through `$ARGS.named`. Without `assetURLs` it is required, as before. With them it may be omitted or empty, and any other value is an error."
  - "`entitlements` replaces the list without `application-identifier` and `com.apple.developer.team-identifier`, which AltStore says not to list (Research §4). 20-05 can therefore pass `codesign`'s keys unchanged."
  - "`marketplaceID` must be digits. It is set only when the source has the key with an empty value or has no key, and a different value is an error."
  - "The template has no `versions` key, like the SideStore template. `marketplaceID` follows `bundleIdentifier`. Otherwise the field order is the SideStore template's."
  - "The PAL source's public address is https://ehpanda.app/AltStorePAL.json, which forwards to `AltStorePAL.json` on `main` the way /AltStore.json does (owner msg 2822; Leto adds it, and it goes live with the site at 3.0). It is recorded here, not in the JSON, because the Classic and SideStore sources carry no `sourceURL` either."

patterns-established:
  - "`check_source(..., pal=True)` for the PAL source; `check_pal_version` for its entries"

requirements-completed: []

coverage:
  - id: D1
    description: "The filter writes a PAL entry and leaves Classic, SideStore and beta output byte-identical"
    requirement: DIST-18-02
    verification:
      - kind: unit
        ref: "test_altstore_add_version.py: 18 tests OK (GoldenOutputTests, PALEntryTests, AddVersionTests); RED before the change: failures=13, errors=4, goldens and old tests passing"
        status: pass
    human_judgment: false
  - id: D2
    description: "The PAL template plus a release passes check_source(pal=True); the template alone fails; refused shapes are reported"
    requirement: DIST-18-02
    verification:
      - kind: unit
        ref: "test_source_templates.py: 16 tests OK (PALTemplateTests); RED before the template: import error"
        status: pass
      - kind: integration
        ref: "plan verify: jq -e '.apps[0].bundleIdentifier == \"app.ehpanda.marketplace\" and .nsfw == true and (.apps[0].versions | length) == 0' → true; test -f AltStorePAL.json → false"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-11-09
status: complete
---

# Phase 20 Plan 03: PAL source template, the filter's PAL mode and the PAL check Summary

**The PAL source template exists. The version filter writes an ADP entry (manifest `downloadURL`, `assetURLs`, no
`sha256`), replaces entitlements and sets the `marketplaceID` once. `check_source(pal=True)` checks the result.
Golden tests show that the Classic, SideStore and beta output did not change.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-11-09T01:51:00Z
- **Completed:** 2026-11-09T01:59:00Z
- **Tasks:** 2
- **Files modified:** 12 (8 created, 4 modified)

## Accomplishments

- **Filter (Task 1).** `altstore-add-version.jq` has three optional arguments, read with `$ARGS.named`. Its header
  comment documents them. It was extended, not forked. The goldens were captured from the unmodified filter on
  frozen inputs, and all three calls still produce the same bytes (T-20-09).
- **Entry rules.** An entry pointing anywhere but the manifest is refused by the filter and by the check (T-20-07).
  The signed build's entitlements replace the stale Classic list (T-20-08).
- **Template and check (Task 2).** `altstore-pal.template.json` has D-16's metadata, taken from `AltStore.json` and
  identical except for the fields the plan exempts. `check_source(pal=True)` requires:
  - a numeric `marketplaceID`;
  - `nsfw: true`;
  - for each version, `downloadURL == assetURLs.manifest`, https asset URLs, `size` above 0, and no `sha256`.

  Without `pal`, `check_source` still refuses a `marketplaceID` (SideStore) and still requires `sha256`.
- `AltStorePAL.json` is not created. Only the first PAL publish (20-05's job) creates it.

## Task Commits

1. **Task 1: PAL mode in the version filter.** `bc2a185b5` (test, RED), `aa774c5f9` (feat, GREEN)
2. **Task 2: PAL template and PAL checks.** `c1a70c702` (test, RED), `6f36f9900` (feat, GREEN)

## Verification evidence

| Check | Result |
|-------|--------|
| Task 1 RED (filter unchanged) | 18 tests, failures=13, errors=4; the goldens and the 3 existing tests pass |
| Task 1 verify | `test_altstore_add_version.py`: Ran 18 tests, OK |
| Task 2 RED (no template) | module import error |
| Task 2 verify | full actions-tool suite OK (8 files: 18 + 5 + 2 + 9 + 20 + 16 + 8 + 11 tests); `jq -e …` → `true` |
| Acceptance | `test -f AltStorePAL.json` is false |

## Files Created/Modified

- `actions-tool/altstore-pal.template.json`: the PAL source template
- `actions-tool/altstore-add-version.jq`: `assetURLs`, `entitlements`, `marketplaceID`; `sha256` optional only with `assetURLs`
- `actions-tool/altstore_languages.py`: `PAL_VERSION_FIELDS`, `check_pal_version`, `check_source(pal=…)`
- `actions-tool/tests/test_altstore_add_version.py`: `GoldenOutputTests`, `PALEntryTests`
- `actions-tool/tests/test_source_templates.py`: `PALTemplateTests`; the PAL template joins the per-device language test
- `actions-tool/tests/fixtures/pal-release-assets.json`: the three Classic IPAs plus `EhPanda-AltStorePAL-manifest.json`, `-signature` and `-<uuid>.ipa` on release `3.0.0`
- `actions-tool/tests/fixtures/add-version-golden/`: three frozen inputs and their outputs

## Decisions Made

See `key-decisions`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The test helpers reused 3.0.0's asset URLs for the next release**
- **Found during:** Tasks 1 and 2, at GREEN
- **Issue:** a second release with the same `downloadURL` was replaced by the filter's existing rule (a re-uploaded
  asset replaces its entry). That rule is correct; the test was wrong, because a real release has its own tag in its
  asset URLs.
- **Fix:** the helpers put the version in the URLs' tag segment.
- **Committed in:** `aa774c5f9`, `6f36f9900`

**2. [Rule 2 - Missing functionality] `sha256` made optional with `assetURLs`; the identity entitlements dropped**
- **Issue:** the filter read `$sha256` directly, so a PAL call with no hash to pass would not compile. Also, AltStore
  wants every entitlement listed except two (Research §4), and the plan did not say who removes them.
- **Fix:** `sha256` is read through `$ARGS.named`. Without `assetURLs` it is still required and its output is
  unchanged, which the goldens confirm. The filter drops `application-identifier` and
  `com.apple.developer.team-identifier` from a given `entitlements` list.
- **Committed in:** `aa774c5f9`

**3. Golden fixture files not listed in `files_modified`**
- The plan asks for golden files but does not list them. They are in `tests/fixtures/add-version-golden/`.

---

**Total deviations:** 2 auto-fixed (Rule 1, Rule 2), plus one unlisted fixture folder. **Impact:** 20-05 can pass
`codesign`'s entitlements and no `sha256`. Every existing call is byte-identical.

## Issues Encountered

None. No build or simulator was needed.

## Open items

- **D-25 copy.** The template carries the Classic subtitle and description, as the plan's D-16 truth asks. That
  includes the source subtitle "Over a million adult comics and doujinshi". D-25 gives the PAL listing its own
  subtitle and description (copywriter msg 2785, pending the owner's approval at 20-10). 20-10 must replace both, in
  the template and in `test_the_pal_template_has_the_classic_metadata`, before 20-08 publishes anything.
- **20-10's screenshot paths are stale.** 20-10 Task 3 still plans to push to `pal/iphone/` and `pal/ipad/` in
  `ehpanda-assets`. The screenshots live under `app-marketplace/` (`c38806448`), so those paths should move there.
  20-10 was left unchanged here. This plan's template has no screenshots, and its checks use the generic
  `ASSETS_URL` root, so nothing in 20-03 points at `pal/`.
- **Source address.** https://ehpanda.app/AltStorePAL.json (owner msg 2822) is not live until the site launches with
  3.0 (D-26). Its redirect is checked at 20-07 Task 2.
- DIST-18-02 stays Pending: the listing half is 20-10.

## User Setup Required

None.

## Next Phase Readiness

20-04 (wave 3) can start. 20-05 calls the filter with `--argjson assetURLs`, `--argjson entitlements` and
`--arg marketplaceID "$PAL_MARKETPLACE_ID"`, passes no `sha256`, and checks the result with
`check_source(pal=True)`.
