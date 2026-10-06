---
phase: 17-localized-screenshot-capture-harness
plan: "03"
subsystem: testing
tags: [python, fixtures, provenance, scrubbing, atomic-publication, marketing]
requires:
  - phase: 17-02
    provides: The regression contracts module (repository root and path containment) and the Scripts/visual test layout
provides:
  - acquire-fixtures.py, which acquires an owner-declared real-gallery selection anonymously into a versioned, checksummed and scrubbed local fixture
  - fixtures.py, the selection schema, scrubbing, the derivation shared by acquisition and validation, and single-writer atomic publication
  - selection-review.py, a deterministic review ledger and contact sheet with composition checks for the proposed marketing scenes
affects: [17-04, 17-05, 17-06, 17-07, 17-21, marketing]
actuals:
  tokens: 29472
  tasks: 2
  commits: 5
tech-stack:
  added: []
  patterns: [content-addressed fixture versions, staging and atomic link publication under an exclusive lock, validation that repeats the acquisition derivation, length-preserving in-place scrubbing, resolve-once fixture reads]
key-files:
  created:
    - Scripts/visual/acquire-fixtures.py
    - Scripts/visual/fixtures.py
    - Scripts/visual/test_fixtures.py
    - Scripts/visual/selection-review.py
    - Scripts/visual/test_selection_review.py
  modified:
    - .gitignore
    - Scripts/visual/README.md
key-decisions:
  - The owner supplies every marketing gallery ID for both content sets; the agent selects and browses no real gallery (owner, 2026-10-07).
  - Acquisition is anonymous: no credentials are read, only the app's nw=1 preference cookie goes to e-hentai.org, and a response showing an account session fails the run.
  - A version is content-addressed over the selection bytes and every asset entry except retrieval timestamps, so unchanged content keeps its version and any change of content or configured order makes a new one.
  - Validation repeats the acquisition derivation over the stored files; a manifest is never trusted for which resources a selection needs.
  - Composition checks describe the proposed populated marketing scenes, not general app constraints.
patterns-established:
  - Fixture readers resolve `current` once with fixtures.resolve_fixtures and read only the returned version directory.
  - Access-bearing values are zeroed in place at the same length, so stored pages and their manifest URLs still agree.
requirements-completed: [CAP-17-01, CAP-17-04]
coverage:
  - id: D1
    description: Acquisition mirrors the app's requests, refuses disallowed hosts, redirects and account sessions, scrubs access values, and publishes only a verified version through a single writer.
    requirement: CAP-17-01
    verification:
      - kind: unit
        ref: Scripts/visual/test_fixtures.py, 37 tests with synthetic responses and the repository's saved parser responses; .capture/17-03-verify-02/test_fixtures.log
        status: pass
    human_judgment: false
  - id: D2
    description: Validation rejects tampering, including resealed semantic edits, malformed entries, symbolic links, traversal, extra or missing files and renamed versions.
    requirement: CAP-17-01
    verification:
      - kind: unit
        ref: test_fixtures.TamperingTests; mutants in .capture/marketing-fixtures-mutations-02 (22 of 22) and .capture/17-03-fix-mutations-02 (5 of 5)
        status: pass
    human_judgment: false
  - id: D3
    description: The review traces every gallery occurrence, page and comment to the active selection, checks the proposed composition, keeps configured order and approves nothing.
    requirement: CAP-17-04
    verification:
      - kind: unit
        ref: Scripts/visual/test_selection_review.py, 16 tests; .capture/17-03-verify-02/test_selection_review.log; mutants in .capture/selection-review-mutations-02 (18 of 18)
        status: pass
    human_judgment: false
  - id: D4
    description: A real selection and its assets exist locally, and their content is reviewed visually.
    requirement: CAP-17-01
    verification:
      - kind: manual_procedural
        ref: Owner-input checkpoint; waits for owner gallery IDs for both sets (17-03-PLAN.md, owner decision of 2026-10-07)
        status: unknown
    human_judgment: true
duration: about 1 hour after the owner decision (2026-10-06, 16:32 to 17:36 UTC)
completed: 2026-10-07
status: complete
source_head: bdc0f1f11
---

# Phase 17 Plan 03: Real marketing fixture tooling Summary

**Owner-declared real galleries can be acquired once, anonymously, into a scrubbed, checksummed and
versioned local fixture, and reviewed offline. No real gallery has been acquired yet: the owner
supplies every gallery ID.**

## Performance

- The owner decision was recorded at 2026-10-06T16:32:53Z; the last source commit landed at
  2026-10-06T17:35:51Z.
- Tasks: 2/2. Source commits: 5. Documentation commits: 2 (the owner decision and this record).
- Realized diff: about 29,500 tokens (chars/4), against an estimate of 48,000.

## Accomplishments

- `acquire-fixtures.py --selection PATH --output DIR [--refresh]` validates a strict selection
  schema, then saves each gallery's detail page (`?hc=1`) and cover. For each flow gallery it also
  saves the detail page's preview images, the `?p=<n>` preview page that holds each declared reader
  page (the app's `PreviewConfig` page number), each reader page and its image. It follows the
  app's parsers: cover from `#gd1`, previews and page numbers from `#gdt`, the reader image from
  `#i3`, and the batch size from the preview mode and the "Showing 1 - N" count.
- Pages come only from `e-hentai.org` and images only from `ehgt.org` hosts or `*.hath.network`,
  over HTTPS and without redirects, paced at least one second apart. The multi-page viewer and the
  bandwidth-limit image are rejected explicitly.
- Before a page is stored, the API key, show key, image keystamp, preview path key, original-image
  keys and static-link token are zeroed in place. The manifest records the same scrubbed URLs, so
  replay by exact URL, MIME, file and SHA-256 matches what the app parses from the stored pages.
- Publication writes a fresh staging directory under an exclusive `flock`, verifies it completely,
  renames it into `versions/<fixtureVersion>` and repoints `current` atomically. A second writer
  fails at once, and an interrupted run publishes nothing. Inside the repository the output must be
  git-ignored; `.capture/marketing/` is.
- `fixtures.validate_fixtures` repeats the resource derivation over the stored files and checks
  every URL, host, path, checksum, length, scrubbed form, entry type, the selection digest, the
  aggregate digest and the version name. `fixtures.resolve_fixtures` gives readers one stable
  version directory.
- `selection-review.py --fixtures DIR --output DIR` writes a self-ignoring `review.json` and
  `review.html` that list every gallery occurrence by content set and screen, Home slots and
  rankings, the flow pages with their reader and Live Text roles, saved comments and downloads
  with display priority. It reports composition problems and the unresolved final inputs, and it
  approves nothing.

## Task Commits

1. `f07d64eff`, docs: the owner's gallery-ID decision, recorded in 17-03-PLAN.md.
2. `60e49ea30`, Task 1: fixture acquisition, validation, tests, ignore rule and README.
3. `b9c2e2aa6`, Task 2: selection review, tests and README.
4. `6b8261409`, review fix: malformed fixture inputs fail explicitly.
5. `404ead2c7`, review fix: a review reads exactly one resolved fixture version.
6. `bdc0f1f11`, review fix: rejected-selection checks use isolated outputs.

## Verification

```sh
python3 -B -W error -m unittest discover -s Scripts/visual -p test_fixtures.py
python3 -B -W error -m unittest discover -s Scripts/visual -p test_selection_review.py
python3 -B -W error -m unittest discover -s Scripts/visual
python3 -B .capture/17-03-fix-mutations-02/mutate.py . .capture/17-03-fix-mutations-02
```

| Check | Evidence | Result |
|---|---|---|
| Task 1 RED | `.capture/marketing-fixtures-red-01/` | Suite fails to import `fixtures` before it exists |
| Task 1 GREEN | `.capture/marketing-fixtures-green-01/` | 110 tests pass |
| Task 1 mutants | `.capture/marketing-fixtures-mutations-02/` | 22 of 22 killed; unmutated baseline passes |
| Task 2 RED | `.capture/selection-review-red-01/` | 14 tests error before `selection-review.py` exists |
| Task 2 GREEN | `.capture/selection-review-green-01/` | 125 tests pass |
| Task 2 mutants | `.capture/selection-review-mutations-02/` | 18 of 18 killed; unmutated baseline passes |
| Review fix RED | `.capture/17-03-input-red-01/`, `.capture/17-03-resolve-red-01/` | Each new case fails on the unfixed code |
| Review fix mutants | `.capture/17-03-fix-mutations-02/` | 5 of 5 killed; both baselines pass |
| Final suite | `.capture/17-03-isolation-green-01/` | 126 tests pass with warnings as errors |
| Plan verify commands | `.capture/17-03-verify-02/` | 37 and 16 tests pass, exit 0 |

Every mutation run used a git-initialized copy holding exactly the scripts and the saved parser
responses, with an unmutated baseline. The tests use synthetic responses and the repository's saved
parser responses only. One HEAD request to the `e-hentai.org` root confirmed that the site accepts
the tool's User-Agent and cookie (`.capture/marketing-fixtures-host-probe-01/probe.json`, status
200); no gallery was requested.

## Review

The inline review (17-03-REVIEW.md) reread the committed tools after Task 2 and found four
defects and one test-isolation weakness. Each is fixed with a test that fails on the old code:

- JSON `true` passed as schema version 1 in a selection and in a manifest, because `True == 1` in
  Python.
- A non-string download status raised `TypeError` instead of the tool's explicit failure.
- A manifest entry with an unsupported image media type raised `KeyError` in `asset_path`, so a
  review printed a traceback instead of an integrity error.
- `review()` validated `current` and then resolved it again, and the command resolved it a third
  time for the contact sheet's image root. A publication in between could mix version A's
  manifest with version B's selection and images.
- The schema strictness subtests shared one output directory, so a wrongly accepted case failed
  every later case as well, which obscured which case was wrong.

## Decisions and Deviations

- **Owner decision, 2026-10-07.** The executing agent declined to choose explicit-set galleries,
  because it cannot rule out sexualized depictions of minors on the source site without viewing
  explicit images. The owner then chose to supply the gallery IDs for both sets. The agent selected
  no real gallery and browsed no candidates. Recorded in 17-03-PLAN.md.
- As a consequence, Task 1's outcome "a versioned real provisional selection and assets exist
  locally" and Task 2's visual review of real content are an owner-input checkpoint (below), not
  results of this plan. The tooling accepts `selectionAuthority: owner` with `selectionStatus`
  `provisional` or `final`.
- The plan names `scripts/visual`; the repository directory is `Scripts/visual`.
- No acceptance, threshold or production behavior changed. The review fixes only make invalid
  input fail explicitly and keep one review on one version.

## Unresolved Gates

1. **Owner gallery input for both sets.** For each content set: gallery URLs in the form
   `https://e-hentai.org/g/<gid>/<token>/` with explicit set assignment, Home slots (at least
   three hero galleries with a neighbor on each side of `selectedIndex`, an even frontpage count of
   at least two, at least three per Toplists period), the flow gallery with its reader pages,
   `readerPage` and `liveTextPage`, and at least two downloads in display order. Then acquire into
   `.capture/marketing` with `selectionAuthority: owner` and run `selection-review.py`.
2. **Visual review of real content.** To be raised with the owner when the IDs arrive: the agent
   cannot verify that explicit-set content is free of prohibited material, so the visual review of
   that set needs the owner.
3. **Final selection.** `selectionStatus: final` with owner authority remains the Phase 17 closure
   checkpoint in 17-21.

## Issues Encountered

- After the last suite run, the pinned iPhone Air was found Booted, although the recorded owner
  state is Shutdown. A `sim-use` daemon for that UDID started at 2026-10-06T17:25:17Z and the
  device booted at 17:30:26Z. This session never ran `sim-use`, no repository script calls it,
  and the same Python suite had left the iPhone Shutdown at 17:16Z. Another session was
  active on this machine at the time. This plan used no simulator, so the device was left as found;
  restore the owner state before the next simulator gate. The iPad stayed Booted.
- An early, unrecorded mutation attempt used copies that were not git repositories, where the
  ignore check cannot pass. Every recorded run uses git-initialized copies with an unmutated
  baseline.

## User Setup Required

None for the tooling. Real acquisition needs the owner input above.

## Next Plan Readiness

17-04 can define `CaptureFixtureManifest` against this schema: `manifest.json` with
`purpose: marketingReal`, `fixtureVersion`, `aggregateDigest`, the selection identity and digest,
and `assets` entries of `kind`, `gid`, `index`, `url`, `path`, `mime`, `bytes`, `sha256` and
`retrievedAt`, beside `selection.json` (Scripts/visual/README.md). Replay matches the stored
scrubbed URLs exactly. A reader resolves `current` once and stays on that version directory. Every
17-04 step that launches the app on real marketing content, including the Home launch on plan 03
assets, waits for the owner input. Phase progress is 4/24 plans; CAP-17-01 and CAP-17-04 stay open
until real content is acquired and every declaring plan finishes.
