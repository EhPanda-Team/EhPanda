---
phase: 17-localized-screenshot-capture-harness
plan: "03"
reviewed: 2026-10-07
execution: inline-orchestrator
scope: fixture-acquisition-validation-and-selection-review
status: passed
source_head: bdc0f1f11
---

# Real marketing fixture tooling review

Inline review of the Python tooling; not an independent or whole-phase review. Scope:
`Scripts/visual/fixtures.py`, `acquire-fixtures.py`, `selection-review.py`, their tests, the
README sections and the ignore rule, as committed in `60e49ea30` and `b9c2e2aa6` and corrected in
`6b8261409`, `404ead2c7` and `bdc0f1f11`. No real gallery was acquired or viewed; the owner
supplies every gallery ID (17-03-PLAN.md).

## Contract

Selections are strict: exact key sets, canonical gallery URLs, explicit set assignment, slots
that name only declared galleries of their own set, every declared gallery placed, no gallery
repeated within one screen (Home's sections count as one screen), and a final selection only
with owner authority. Acquisition mirrors the app's request and parser semantics, takes pages
only from `e-hentai.org` and images only from `ehgt.org` hosts or `*.hath.network`, refuses
redirects, sends no credentials, and fails on an account session. Access-bearing values are
zeroed in place before anything is stored, and the manifest records the scrubbed URLs.

Validation repeats the derivation over the stored files, so the selection, not the manifest,
decides which resources must exist. It rejects missing, extra and relocated files, checksum and
length mismatches, unscrubbed or session-bearing pages, disallowed hosts, symbolic links,
traversal, malformed entries, a changed selection and a wrong aggregate or version name.
Publication verifies the staged directory before an atomic rename and link replacement, under an
exclusive lock that also guards stale-staging cleanup. The review approves nothing and keeps
configured order.

## Findings fixed before the task commits

Found by self-review and by mutation runs on git-initialized copies with unmutated baselines:

- Surviving mutants exposed four weak tests: a symbolic link check masked by path containment, a
  sorted frontpage, publication without verification, and a link-target check masked by the name
  check. Each test now isolates its check (a resealed link to identical bytes, an order assertion,
  an entity-encoded keystamp, a moved version that keeps its name).
- `http.client.IncompleteRead` escaped the network error handling; `HTTPException` is now caught.
- The setup path could leak the lock descriptor, and a symbolic `versions` directory was accepted;
  both are fixed.
- The comment header kept a newline in the posted time, and the contact sheet rendered dark text
  on a dark background; both are fixed.

## Findings fixed after the task commits

A fresh reread of the committed tools found four defects and one test weakness. Each fix has a
test that fails on the old code (`.capture/17-03-input-red-01/`, `.capture/17-03-resolve-red-01/`)
and a mutant that the final tests kill (`.capture/17-03-fix-mutations-02/`, 5 of 5):

| Finding | Fix |
|---|---|
| JSON `true` passed as schema version 1 in a selection and a manifest | `current_schema` checks the type as well as the value (`6b8261409`) |
| A non-string download status raised `TypeError` | The status must be a string before the lookup (`6b8261409`) |
| An unsupported image media type in a manifest raised `KeyError` | Entry validation requires `text/html` for pages and a supported image type for images (`6b8261409`) |
| `review()` and the command resolved `current` up to three times, so a publication in between could mix two versions | `fixtures.resolve_fixtures` resolves once; the ledger and contact sheet read that directory (`404ead2c7`) |
| Strictness subtests shared one output, so one wrongly accepted case failed every later case | Each rejection check acquires into its own output (`bdc0f1f11`) |

## Result

The full Python suite passes 126 tests with warnings as errors
(`.capture/17-03-isolation-green-01/`); the plan's two verify commands pass 37 and 16 tests
(`.capture/17-03-verify-02/`). No open finding remains in this scope. Real content, its visual
review and the final owner selection are owner-input gates recorded in 17-03-SUMMARY.md, not
review findings.
