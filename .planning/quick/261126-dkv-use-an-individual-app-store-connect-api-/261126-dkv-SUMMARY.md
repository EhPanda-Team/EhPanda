---
phase: 261126-dkv-use-an-individual-app-store-connect-api-
plan: 01
subsystem: ci-distribution
tags: [app-store-connect, build-upload-api, individual-api-key, altstore-pal, github-actions]
requires:
  - phase: 261126-0b9
    provides: the release path (wait-build, ensure-version, whats-new, attach-build, submit), the allow-list and the call record
provides:
  - "asc.py signs individual-key tokens (sub user, no iss) and needs only the key ID and the key file"
  - "asc.py upload: the Build Upload API upload of the .ipa with MD5 checksums, a checked plan and resent parts"
  - "marketplace-upload.yml: export without keys, signing teardown, then upload"
affects: [marketplace-upload.yml, deploy.yml caller, 20-06-ACCOUNT.md]
tech-stack:
  added: []
  patterns:
    - "Part URLs are logged and recorded without their query (the signature)"
    - "The upload plan is validated whole before any byte is sent"
key-files:
  created: []
  modified:
    - actions-tool/asc.py
    - actions-tool/tests/test_asc.py
    - actions-tool/ExportOptions-marketplace.plist
    - actions-tool/marketplace-signing.sh
    - .github/workflows/marketplace-upload.yml
    - actions-tool/tests/test_workflows.py
    - .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-06-ACCOUNT.md
key-decisions:
  - "Individual key only; no issuer anywhere outside .planning/ (owner decision 1)"
  - "The .ipa goes up through the Build Upload API, not altool or xcodebuild's upload (owner decision 2)"
  - "Everything from 261126-0b9 stays (owner decision 3)"
requirements-completed: [DIST-18-03]
status: complete
completed: 2026-11-26
commits: 3
plan_head_before: 30fd054f078fb9c5a8f37c1a8572c678df38c718
plan_head_after: 89b65b267690e8d5bcb9dd51b4dd435c105eae00
actuals:
  tokens: 22000
  tasks: 3
  commits: 3
---

# Phase 261126-dkv Plan 01: Individual API key and Build Upload API upload Summary

The PAL CI signs App Store Connect tokens with the owner's individual key (`sub: user`, no issuer) and uploads the exported `.ipa` through the Build Upload API in the new `asc.py upload` command, with a fully checked upload plan and resent parts.

## Tasks

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Individual-key token, `asc.py upload`, export-only options, workflow and shape tests (tracer) | a760a6522 | asc.py, test_asc.py, ExportOptions-marketplace.plist, marketplace-signing.sh, marketplace-upload.yml, test_workflows.py |
| 2 | Check the upload plan before any byte and resend parts after transient failures | dc6cec729 | asc.py, test_asc.py |
| 3 | Record the individual key and the environment's secrets | 89b65b267 | 20-06-ACCOUNT.md |

All three commits are signed (`G`) with `+08:00` author and committer dates.

## What changed

- `asc.make_token(key_id, key_path)` signs `{sub: user, iat, exp = iat + 1200, aud: appstoreconnect-v1}`; `TokenSource` and `main` need only `APP_STORE_CONNECT_KEY_ID` and `ASC_KEY_PATH`.
- `asc.py upload` creates the build upload and its `.ipa` file (ASSET, `com.apple.ipa`), PUTs each part to its own https URL with only the headers the operation lists plus Host and Content-Length (never the API token), PATCHes the file as uploaded with its file and composite MD5 checksums, and polls the build upload to COMPLETE (prints its ID) or FAILED (exit 1 listing every error and warning).
- `ALLOWED` has 15 entries (four added for the Build Upload API); `COMMANDS` has 7.
- Parts are logged as `UPLOAD PUT <url> <status> part=<n>` and recorded as `{method, url, status, part}` without the URL's query.
- Task 2: `upload_parts` refuses, before any byte, a malformed plan (non-object, method other than PUT, unusable range, bad URL, bad headers, a Content-Length other than the part's, ranges that do not start at 0, leave a gap, overlap or miss the file's size); `Client.send_part` resends a part after 429, 5xx or a lost connection, at most three times (sleeping 5 s then 10 s), and treats any other refusal as final.
- Workflow: `Export .ipa file` (no env, no key flags), `Tear down signing`, `Upload to App Store Connect` (only `APP_STORE_CONNECT_KEY_ID` as a secret); the issuer secret is gone from every step; the export options' destination is `export`.
- 20-06-ACCOUNT.md carries two dated 2026-11-26 amendments; no existing line changed.

## Verification

- `actions-tool/tests`: 368 tests OK (HEAD baseline 350); `test_asc.py` 55 tests OK under both `python3` and `/usr/bin/python3` (Python 3.9, LibreSSL); `test_workflows.py` 102 OK; `Scripts/visual` `test_snapshot_gate.py` OK.
- `actionlint` exits 0 on `marketplace-upload.yml` and `deploy.yml`.
- Zero case-insensitive "issuer" lines across the six code files; zero uncommented `-authentication` lines in the workflow; export destination reads `export`; no line over 120 columns in `asc.py`, `test_asc.py` or the workflow's comments; `asc.COMMANDS` has the 7 expected names and `asc.ALLOWED` 15 entries; `asc.PART_ATTEMPTS == 3`.
- Task 3 verify (amendments present, the 2026-11-25 table row and the "Open:" paragraph intact, `20-08-SUBMISSION.md` and `REQUIREMENTS.md` unchanged) passed.
- The Lint loop (every `test_*.py` directory under `Scripts` and `actions-tool`) passed with no failures, and `git diff 0d80493c8 --stat` over `deploy.yml`, `publish-pal.yml`, `pal_publish.py`, `Scripts/visual/README.md` and `REQUIREMENTS.md` prints nothing.

TDD: Task 2's tests were written first and failed (RED) against Task 1's `upload_parts` and `send_part`, then passed after the changes (GREEN).

## Deviations from Plan

None - plan executed exactly as written.

Notes, not deviations:
- The Task 1 verify command's `grep -c '"$ASC_TOOL_PATH" upload --app'` check returned 0 when run through this machine's interactive `grep` wrapper (a `ugrep` function that treats `$A...` differently in a basic regex). The same pattern with `/usr/bin/grep` returns 1, and `grep -F` returns 1, so the workflow holds the line the check looks for. All other checks in that command passed.
- The orchestrator's composite-checksum pre-check was run before dispatch and confirmed the inferred checksum form; Task 1 uses it as written.

## Open risks (unchanged from the plan, for the first live run)

- Whether Apple requires the asset description and SPI files that Xcode's upload also sent; if so the upload's poll ends FAILED with Apple's errors in the log.
- Whether a failed or unfinished build upload uses up its build number, what COMPLETE means relative to processing, and whether the `.ipa`'s symbols are processed as Xcode's upload did.
- The owner must add `APP_STORE_CONNECT_KEY_ID` and `APP_STORE_CONNECT_PRIVATE_KEY` to the `app-marketplace` environment before the next run.

## Known Stubs

None.

## Threat Flags

None. The new network surface (storage PUTs) is the one the plan's threat model covers (T-261126-dkv-01 to -05, -07).

## Self-Check: PASSED

- Files exist: `actions-tool/asc.py`, `actions-tool/tests/test_asc.py`, `actions-tool/ExportOptions-marketplace.plist`, `actions-tool/marketplace-signing.sh`, `.github/workflows/marketplace-upload.yml`, `actions-tool/tests/test_workflows.py`, `20-06-ACCOUNT.md`.
- Commits a760a6522, dc6cec729 and 89b65b267 are ancestors of HEAD.
