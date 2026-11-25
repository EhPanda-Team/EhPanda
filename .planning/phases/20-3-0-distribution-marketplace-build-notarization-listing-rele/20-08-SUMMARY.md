---
phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele
plan: "08"
subsystem: infra
tags: [altstore-pal, notarization, app-store-connect, ci-upload, adp]

requires:
  - phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele
    provides: "the marketplace flavor (20-01), the PAL source and publish tooling (20-03 to 20-05), the app-marketplace environment (20-06), the Classic release (D-26)"
provides:
  - "20-08-SUBMISSION.md: Apple's Notarization acceptance of 3.0.0 (163), the real ADP layout, the hand-made AltStorePAL.json on main, and the first CI upload of a marketplace build"
affects: [DIST-18-03, AltStore PAL releases]

actuals:
  tasks: 4
  commits: 6
plan_head_before: 754424cee
plan_head_after: the commit holding this SUMMARY

tech-stack:
  added: []
  patterns: ["a plan closed on a recorded CI run instead of a submit run (owner amendment)"]

key-files:
  created:
    - .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-08-SUBMISSION.md
  modified: []

key-decisions:
  - "The 3.0.0 submission went outside the workflow and the first AltStorePAL.json was made by hand (owner decisions, 2026-11-21)"
  - "D-25 dropped: the PAL listing keeps the Classic copy and screenshots (owner decision, 2026-11-25)"
  - "DIST-18-03 closes on the first successful CI upload with the app-marketplace secrets; D-21 is no longer asked (owner decision, 2026-11-25)"

requirements-completed: [DIST-18-03]

duration: across sessions (2026-11-21 to 2026-11-25)
completed: 2026-11-25
status: complete
---

# Phase 20 Plan 08: First PAL submission and CI upload Summary

**Apple accepted 3.0.0 (163) for Notarization, 3.0.0 is live on AltStore PAL through a hand-made source, and the first CI upload of a marketplace build with the `app-marketplace` secrets succeeded (run 45583656180, 3.1.0 (164)), which closes DIST-18-03.**

## Accomplishments

- **Submission and verdict (2026-11-21):** the collaborator submitted the signed 3.0.0 (163) marketplace archive in App Store Connect by hand (owner decision), and Apple accepted it for Notarization. No workflow run was involved.
- **ADP:** `453ead28-2d2b-49d1-a398-5a06ca29186b` was fetched with `pal_publish.py fetch --adp-id`. Its layout (`manifest.json`, `signature`, `variant/<publicId>.ipa`) matches the 20-05 fixture. The variants are encrypted, so `publish` now takes entitlements and privacy keys from the project's files.
- **Publication:** the hand-made `AltStorePAL.json` is on `main` through EhPanda-Team/EhPanda#476 and served at `https://ehpanda.app/AltStorePAL.json`. The owner installed 3.0.0 (163) from it in AltStore PAL.
- **First CI upload (2026-11-25):** [run 45583656180](https://github.com/EhPanda-Team/EhPanda/actions/runs/45583656180) of `marketplace-upload.yml` was started by a push to `develop` at `33efae302` and approved in `app-marketplace` on the owner's word. It archived, verified and uploaded 3.1.0 (164), and every step was green. It made no GitHub release, sent no announcement and changed no source file.

## Commits

- `754424cee`, `90c5e3554`, `fd0e5929b`, `e82010b40`, `2f3fbdd9c` (docs): the record and its owner amendments
- The commit holding this SUMMARY: the CI upload record and the closing

The workflow change that made the run possible (`3b64b957d`, `799ed0360`, `33efae302`) was made for the owner's test request. It is outside this plan's commits.

## Deviations

- **The submit-run truths are replaced** (owner amendment, 2026-11-25). `deploy-pal.yml` is gone (261121-jps), so there is no submit run, call record for version creation or D-21 answer. The closing truth is the first successful CI upload.
- **The PAL copy truth no longer applies** (D-25 dropped, 2026-11-25).
- **A live publish happened in this plan** (owner decision, 2026-11-21), which overrides the no-live-publish truth.

## Open (outside the closing)

- Install with `"appPermissions": { "entitlements": [] }` is not yet tried on a device.
- **Missing Sentry symbols:** the export warned "Upload Symbols Failed" for `Sentry.framework` because the archive has no dSYM for the Sentry SDK. Classic releases since 2026-11-23 will show the same warning. The app's own dSYMs reached Sentry.
- Build number 164 is used, so the 3.1.0 release needs 165 or later.
