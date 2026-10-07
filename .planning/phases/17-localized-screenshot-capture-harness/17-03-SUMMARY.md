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
    description: A real provisional nonexplicit selection and its assets exist locally, sampled at random from Non-H and reviewed visually.
    requirement: CAP-17-01
    verification:
      - kind: manual_procedural
        ref: .capture/marketing-selection-01/ (seed, candidates, rejections); .capture/marketing/versions/marketing-fdcb0fc6d3c54a29; .capture/marketing-review-01/ (valid composition, visual-review.md)
        status: pass
    human_judgment: true
  - id: D5
    description: The explicit set's selection and assets.
    requirement: CAP-17-01
    verification:
      - kind: manual_procedural
        ref: Owner input; the agent does not select explicit galleries (17-03-PLAN.md)
        status: unknown
    human_judgment: true
duration: about 1 hour after the owner decision (2026-10-06, 16:32 to 17:36 UTC)
completed: 2026-10-07
status: complete
source_head: bdc0f1f11
---

# Phase 17 Plan 03: Real marketing fixture tooling Summary

**Real galleries can be acquired once, anonymously, into a scrubbed, checksummed and versioned
local fixture, and reviewed offline. A random, visually reviewed Non-H selection is acquired as the
provisional nonexplicit set; the explicit set waits for the owner's gallery IDs.**

## Performance

- The owner decision was recorded at 2026-10-06T16:32:53Z; the last source commit landed at
  2026-10-06T17:35:51Z.
- Tasks: 2/2. Source commits: 5. Documentation commits: 4 (two owner instructions and two
  completion records).
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

## Provisional nonexplicit selection

Following the owner's later instruction (17-03-PLAN.md), `.capture/marketing-selection-01/sample.py`
drew one gallery at random from each of 60 Non-H listing pages at random cursors (seed
4767476936933364992), read their metadata from the gallery API without recording archiver keys, and
excluded one gallery by tag (ryona). Of the 59 candidate covers (`contact-0.png`, `contact-1.png`),
13 were rejected in visual review, each with its reason in `rejections.json`: two whose title or
circle signals lolicon, and covers or tags showing lingerie, underwear, swimsuit pin-ups, fanservice
or fetish themes. The selection takes the accepted candidates in their random order. The flow
gallery must name a text language for Live Text and have a readable comment: 1979820, a 31-page
English comic with 3 comments, reading and Live Text on page 4.

```sh
PYTHONPATH=Scripts/visual python3 -B .capture/marketing-selection-01/sample.py sample
PYTHONPATH=Scripts/visual python3 -B .capture/marketing-selection-01/sample.py select \
  --rejections .capture/marketing-selection-01/rejections.json
python3 -B Scripts/visual/acquire-fixtures.py \
  --selection .capture/marketing-selection-01/selection.json --output .capture/marketing
python3 -B Scripts/visual/selection-review.py --fixtures .capture/marketing/current \
  --output .capture/marketing-review-01
```

The first real acquisition published `marketing-fdcb0fc6d3c54a29` (2026-10-07T01:19:35Z to
01:20:44Z): 42 assets, 1.7 MB, 17 details and covers, one preview sprite, one preview page and three
reader pages with images, from `e-hentai.org`, `ehgt.org` and H@H hosts, with every keystamp zeroed.
The review reports a valid composition; its only unresolved inputs are the explicit set and the final
owner selection. In `visual-review.md`, all stored covers, the preview sprite and pages 3 to 5 show
no nudity, sexual suggestion, gore or real-person photographs. The three saved comments are benign
but name real site usernames, which the owner should weigh in the final selection.

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
200); that probe requested no gallery.

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
- **Owner instruction, later on 2026-10-07.** The owner asked for random IDs for both sets, the
  nonexplicit set limited to Non-H. The agent sampled and acquired the nonexplicit set as above. It
  does not select the explicit set: random picks from the explicit categories cannot exclude
  sexualized depictions of minors, and the only remaining check would be inspecting sexual images
  for apparent age. The owner's later proposals (limiting to Artist CG, Game CG, Western, Non-H,
  Image Set, Cosplay and Misc, or filtering the lolicon tag) do not change that; 17-03-PLAN.md
  records the reasoning.
- The plan names `scripts/visual`; the repository directory is `Scripts/visual`.
- No acceptance, threshold or production behavior changed. The review fixes only make invalid
  input fail explicitly and keep one review on one version.

## Unresolved Gates

1. **Owner gallery input for the explicit set.** Gallery URLs in the form
   `https://e-hentai.org/g/<gid>/<token>/` with explicit set assignment, Home slots (at least
   three hero galleries with a neighbor on each side of `selectedIndex`, an even frontpage count of
   at least two, at least three per Toplists period), the flow gallery with its reader pages,
   `readerPage` and `liveTextPage`, and at least two downloads in display order. Both sets share one
   selection, so the explicit galleries and scene join the existing selection and acquisition
   publishes a new version with `--refresh`; then run `selection-review.py`.
2. **Visual review of explicit content.** The agent cannot verify that explicit-set content is
   free of prohibited material, so the visual review of that set needs the owner.
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

None for the tooling. The explicit set needs the owner input above.

## Next Plan Readiness

17-04 can define `CaptureFixtureManifest` against this schema: `manifest.json` with
`purpose: marketingReal`, `fixtureVersion`, `aggregateDigest`, the selection identity and digest,
and `assets` entries of `kind`, `gid`, `index`, `url`, `path`, `mime`, `bytes`, `sha256` and
`retrievedAt`, beside `selection.json` (Scripts/visual/README.md). Replay matches the stored
scrubbed URLs exactly. A reader resolves `current` once and stays on that version directory. 17-04 can
launch the actual Home scene on the provisional nonexplicit fixture now; explicit-set coordinates
wait for the owner input. Phase progress is 4/24 plans; CAP-17-01 and CAP-17-04 stay open until both
sets are acquired and every declaring plan finishes.
