# Consolidated tag database

Owner decisions (2026-11-02): merge every language into one repository, including zh-Hans; move OpenCC
into its pipeline; publish automatically with guards; Traditional Chinese ships one Taiwan dataset only;
v3.0 is unreleased, so no compatibility or migration work is needed. Old repositories are deleted by the
owner: Korean any time after cutover, English and Japanese after v3.0 ships (v2.8.1 still reads them).

## Repository: EhPanda-Team/ehpanda-tag-database

1. Datasets `en`, `ja`, `ko`, `zh-Hans`, `zh-Hant`, built from the upstream `db.raw.json`. Canonical form:
   compact JSON, `rows` dropped, empty `intro`/`links` omitted.
2. Conversion uses pinned OpenCC `s2twp`, covers name, intro and links, and leaves Markdown link targets
   and bare URLs untouched. Overrides live in data, not code. A dataset fails if converted text parses to
   different link targets.
3. Daily schedule. Unchanged data publishes nothing. A failed dataset reuses the previous asset and its
   provenance, the others still publish, and the run ends failed so the owner is notified.
4. Upstream or license problems stop the run; the last release stays live. Tags or named tags shrinking by
   more than 10% count as a failure, with a manual `accept_shrink` run for legitimate drops.
5. Releases are draft, upload, verify, publish, verify; the last seven are kept and failed drafts cleared.
   A small state file is committed per release as the audit trail and reconciled on every run.
6. Parity check against the live English, Japanese and Korean assets before the first release.

## App

7. `TranslatableLanguage` gains Korean and reads one repository. Updates compare the release asset digest
   for the language instead of `published_at`, so unrelated language changes download nothing.
8. Remove OpenCC: conversion extension, package dependency, test target, test plan entry, both resolved
   files and the About acknowledgement.
9. Update tests and capture support. Verify with focused tests, strict lint, build and a live simulator
   download per language.

## Order

Finish and commit `261101-tag-database-support` first, then the repository, then the app. Independent
review before closing. Record results and limitations in SUMMARY.md and STATE.md.
