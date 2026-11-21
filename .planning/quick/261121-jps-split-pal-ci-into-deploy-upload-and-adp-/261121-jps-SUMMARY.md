---
phase: 261121-jps-split-pal-ci-into-deploy-upload-and-adp-
plan: 01
subsystem: ci
tags: [github-actions, altstore-pal, app-store-connect, release]
requires:
  - phase: 20
    provides: D-07, D-19, D-21, D-26 and the PAL tools (asc.py, pal_publish.py, marketplace-signing.sh)
provides:
  - deploy.yml AltStorePAL job (needs Deploy, environment pal-notarization): own marketplace archive, verify, upload, stop
  - publish-pal.yml (Publish AltStore PAL): dispatch-only publish by bare-UUID ADP ID, deploy-key push to main
  - pal_publish.py publish driven by the ADP manifest, with the D-26 Classic-release guard and --notes-dir
  - asc.py reduced to check-build with a GET /v1/builds allow-list
affects: [phase-20 DIST-18-03, release process]
tech-stack:
  added: []
  patterns: [upload-only CI job with a hand-over summary, manifest-driven publish]
key-files:
  created: [.github/workflows/publish-pal.yml]
  modified:
    - .github/workflows/deploy.yml
    - actions-tool/pal_publish.py
    - actions-tool/asc.py
    - actions-tool/tests/test_pal_publish.py
    - actions-tool/tests/test_asc.py
    - actions-tool/tests/test_workflows.py
    - Scripts/visual/test_snapshot_gate.py
    - Config/Marketplace.xcconfig
    - actions-tool/ExportOptions-marketplace.plist
    - actions-tool/marketplace-signing.sh
    - Scripts/visual/README.md
    - .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-CONTEXT.md
    - .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-08-SUBMISSION.md
    - .planning/REQUIREMENTS.md
  deleted: [.github/workflows/deploy-pal.yml]
decisions:
  - "Owner decision 2026-11-21: Deploy gains an AltStorePAL upload job; the collaborator creates, attaches and submits by hand; publish-pal.yml publishes by ADP ID (DIST-18-03 stays Pending)."
metrics:
  duration: about 25 min
  completed: 2026-11-21
status: complete
commits: 3
plan_head_before: 2d5b8efa1799862ea9eab9802f9d7584947448f0
plan_head_after: 7020d896bcaeb87c2b3b27f6ced06919a08cf53b
actuals:
  tokens: 150000
  tasks: 3
  commits: 3
---

# Phase 261121-jps Plan 01: Split the PAL CI Summary

Deploy now ends with an `AltStorePAL` upload job (own marketplace archive, App Store Connect upload, hand-over summary), and a new dispatch-only `Publish AltStore PAL` workflow publishes an accepted ADP from its bare-UUID ID alone.

## What was built

- **Task 1** (`26aebba8d`, `ci: upload PAL in Deploy, publish by ADP ID`): `deploy.yml` keeps `Deploy` (one comment changed) and adds `AltStorePAL` (`needs: Deploy`, environment `pal-notarization`, concurrency `pal-upload`). It reads the version from the project, checks the build number against `AltStorePAL.json` on main and App Store Connect, archives on its own with the generated signing xcconfig, verifies, exports and uploads, uploads the call record and tears down signing. It has no wait, ensure-version, attach or submit step. `publish-pal.yml` has inputs `adp_id` (UUID checked before any request) and `dry_run` (default true), no environment and no App Store Connect secret, and checks out with `DEPLOY_KEY`. `pal_publish.py` lost `process` and `--version`, gained `--notes-dir` and `check_classic_release` (D-26), and `request_json` is GET-only. `deploy-pal.yml` is deleted. Tests: `PalUploadJobTests`, `PublishWorkflowTests`, six new `PublishTests` cases, the gate-wiring test adjusted.
- **Task 2** (`c2a7809ca`, `pal: trim asc.py and drop deploy-pal mentions`): `asc.py` keeps only `check-build`; `ALLOWED` is `GET /v1/builds`; the request body support and submission helpers are gone; the call record is unchanged. `test_asc.py` covers the build check, the refusals and the removed commands. The five remaining mentions of the old workflow were reworded.
- **Task 3** (`7020d896b`, `docs(quick-261121-jps): record the PAL CI split`): dated 2026-11-21 amendments in `20-CONTEXT.md` (plan order, Notarization CI, D-21), `20-08-SUBMISSION.md` (Open) and `REQUIREMENTS.md` (DIST-18-03 note and footer). DIST-18-03 stays unticked and Pending.

## Verification

- Every script test directory passes, run as `lint.yml` runs them (loop over `Scripts` and `actions-tool`).
- `actionlint` on `deploy.yml`, `deploy-beta.yml` and `publish-pal.yml` exits 0.
- `git grep -n 'deploy-pal' -- ':!.planning'` exits 1 (no match).
- Three signed commits (`G`), author and committer dates `+08:00`.
- Nothing was pushed, dispatched or sent to App Store Connect, AltStore or the GitHub API.

## Deviations from Plan

None - the plan was executed as written. Notes on judgment inside the plan's wording:

- In `publish-pal.yml`, "Fetch the ADP" carries its comment as a shell comment inside `run` (the plan said comment then command); the "Checkout" comment is a YAML comment above `with`, as specified.
- The plan counted 15 `self.deploy` call sites in `DeployWorkflowTests`; the file had 17 (12 `step_named`, 5 `step_index`, one of them in `run_text`). All were inside `DeployWorkflowTests` and all were switched to `self.release`.
- A few long comment lines in the new `deploy.yml` job were wrapped at 120 columns; the text is unchanged.

## Known Stubs

None.

## Threat Flags

None. The new surface (the publish workflow's deploy-key push) is the one the plan's threat model lists as T-261121-jps-03.

## Self-Check: PASSED

- Files: `.github/workflows/publish-pal.yml` present; `.github/workflows/deploy-pal.yml` absent.
- Commits: `26aebba8d`, `c2a7809ca`, `7020d896b` are ancestors of HEAD.
