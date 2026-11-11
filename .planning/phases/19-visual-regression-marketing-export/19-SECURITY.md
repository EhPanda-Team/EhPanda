---
phase: "19"
slug: visual-regression-marketing-export
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
open_total: 0
below_threshold_open: 0
accepted: 2
# accepted_deferred: accepted by the owner (msg 3573) on a condition; they are not closed. Condition: carried with the
# deferred 19-12/19-13 screenshot publishing; must be closed before any baseline publication.
accepted_deferred: 4
asvs_level: 1
block_on: high
created: "2026-11-11"
audited_head: bac1ca916
closed_at: "2026-11-11"
---

# Phase 19 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
> Audited at `feature/gsd-phase-19` HEAD `bac1ca916`, including the review fixes `bded61963..bac1ca916` and `b10fb61aa`.
> Config: `security_enforcement` true, ASVS level 1 (a mitigation counts when it is present in the cited file), block on high.
> Read-only audit: no code was changed. Local checks run: `Scripts/live-check` 27 tests OK, `Scripts/visual` 384 tests OK
> (includes `test_snapshot_gate.py`, `test_snapshot_fetch.py`, `test_run_shard.py`, `test_snapshot_aggregate.py`),
> grep of every workflow for `pull_request_target`, `secrets.`, and `${{ }}` inside `run:`. No xcodebuild, no hosted run.

**Verdict: SECURED, with four accepted-deferred threats.** 36 of 40 threats closed (2 of them accepted). The other four
(T-19-24, T-19-25, T-19-26, T-19-27) belong to the deferred plans 19-12 and 19-13 (owner msg 3428) and are
accepted-deferred by the owner (msg 3573): carried with the deferred 19-12/19-13 screenshot publishing; must be closed
before any baseline publication. They are not closed and not mitigated yet; three are high and one is medium. None is
reachable today: no publisher script, no snapshot repository push and no `fingerprints.json` exist, so nothing can be
published. The gate fails closed while there is no baseline. Everything that runs on hosted runners and everything that
handles tokens or secrets is closed. `threats_open` is 0 only because of the recorded acceptance; it is not a statement
that the four mitigations exist.

*Close-out (2026-11-11): the owner's acceptance (msg 3573) was recorded and the frontmatter counts and sign-off were
updated. No code was changed and no check was re-run; the audit evidence above is the audit of `bac1ca916`.*

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| PR code → hosted runner (`snapshot-gate.yml`) | public PRs run untrusted code on `xcode-27` | no secrets; `contents: read` token only |
| deploy / deploy-beta → gate | release builds need a green `aggregate` | verdict (job result), release secrets stay in `Deploy` only |
| live site → public logs, artifacts, issues | page content must never reach the public repository | enums, HTTP status, fixed sentences (`results.json`) |
| issues token → run step | `issues: write` is used by the reporter only | `GH_TOKEN` (job token) |
| snapshot repository → verdict | fetched pictures must be the approved ones | pictures, SHA-256 fingerprints |
| fixtures → public baseline | every picture is published | synthetic pictures |
| test bundle → Release product | capture and snapshot code must not ship | binary, resources |
| results files → gate verdict | missing or malformed file must never read as a pass | `results.jsonl`, `shard.json` |
| proof commits → phase branch | fault switches and the token change must not land | commits |
| owner's sign-in → GitHub | pushes, repo creation, install | owner consent (message ids) |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation / evidence | Status |
|-----------|----------|-----------|----------|-------------|-----------------------|--------|
| T-19-01 | Tampering | compare run overwriting references | high | mitigate | `HostedWindowCapture.swift:436` ("`reference` is never touched"); `HostedWindowCaptureTests.swift:148` `testComparePassLeavesTheReferenceDirectoryUnchanged` | closed |
| T-19-02 | Elevation of privilege | `VisualSnapshotSupport` / SnapshotTesting in Release | medium | mitigate | `AppPackage/Package.swift:1146-1151` (only dependency is SnapshotTesting); linked only by the `VisualSnapshotTests` target (`EhPanda.xcodeproj/project.pbxproj:152,265-266`); `Scripts/visual/verify-release.py` `FORBIDDEN_CONTENT`/`FORBIDDEN_LINKAGE`; 19-17-SUMMARY gate: Release build, PASS, 0 findings (recorded result, not re-run here) | closed |
| T-19-SC | Tampering | package installs | low | accept | no new dependency; `Package.swift:36` `swift-snapshot-testing` `exact: "1.19.6"` | closed (accepted, see log) |
| T-19-03 | Repudiation | not-applicable rules | medium | mitigate | `snapshot_matrix.py:106-107` rejects a rule without a reason; totals list them; README lists current totals | closed |
| T-19-04 | Tampering | shard plan drift | low | mitigate | `snapshot-gate.yml:72-73` runs `snapshot_shards.py --check`; test run printed "is stale" path for the negative case | closed |
| T-19-05 | Information disclosure | probe output and logs | high | mitigate | `runner-probe.yml:50-61` full log kept on the runner, only counts and `: error:` lines without URLs printed; `:69-76` uploads `probe.json` only (no `.xcresult`); `ProbeReportTests.swift:34` title-like body test; `PageObservation.swift:4-8` records status and `cf-mitigated` only | closed |
| T-19-06 | Elevation of privilege | network guard removed elsewhere | high | mitigate | `Scripts/live-check/test_network_guard.py` (both directions; 6 tests OK); `Package.swift:225-226` | closed |
| T-19-07 | Denial of service (site) | probe traffic | low | mitigate | `RunnerProbeTests.swift:21,23` two 5 s sleeps between three GETs; one run on a `ci/runner-probe` push | closed |
| T-19-08 | Repudiation | probe push without consent | medium | mitigate | 19-03-SUMMARY: owner msg 2397 authorised the push and deletion | closed |
| T-19-09 | Denial of service (cost) | billed runner | medium | mitigate | 19-04-SUMMARY R-1: `billable: {}` in every run, runner group GitHub Actions, label `xcode-27` | closed |
| T-19-10 | Repudiation | measure push without consent | medium | mitigate | 19-04-SUMMARY: owner msg 2743 | closed |
| T-19-11 | Information disclosure | real content in a picture (19-05) | high | mitigate | factories use `PublicVisualFixtures` / `FixtureArtwork` only (`Sources/VisualSnapshotSupport/PublicVisualFixtures.swift`, `Tests/VisualSnapshotTests/FixtureArtwork.swift`); `.invalid` and synthetic URLs in `ScenarioCatalog+*.swift`. The second layer (agent pre-check, 19-13) is tracked under T-19-26 | closed |
| T-19-12 | Tampering | capture-only app code | medium | mitigate | no `#if` capture branch or test-only launch key added to `AppPackage/Sources/*Feature` by this phase (diff of added lines checked; the existing `#if DEBUG` hits in `AppFeature/UITestSupport` pre-date it and are excluded from Release by `verify-release.py`) | closed |
| T-19-13 | Information disclosure | real content / search words in a picture (19-06) | high | mitigate | same synthetic-fixture control as T-19-11; second layer under T-19-26 | closed |
| T-19-14 | Information disclosure | member names, comment text (19-07) | high | mitigate | synthetic comment fixtures (`GalleryFixtures.swift`, `ScenarioCatalog+Gallery.swift`); second layer under T-19-26 | closed |
| T-19-15 | Tampering (site) | report sent from a scenario | medium | mitigate | `ScenarioCatalog+Gallery.swift:199` stubs `reportFormClient.send`; test targets link the network guard (`Package.swift:225`); no live URL | closed |
| T-19-16 | Information disclosure | account details in Account/Login pictures | high | mitigate | `SettingsFixtures.swift`, `ScenarioCatalog+Settings.swift`; UI test uses `fixture-member` / `fixture-session` values only (`EhPandaUITests/NativeVisualPolicyUITests.swift:331-332`); second layer under T-19-26 | closed |
| T-19-17 | Tampering | gate verdict | high | mitigate | `snapshot_aggregate.py:108-112,152-155` missing shard or coordinate → `runner-lost` / `missing-result`; `:67-69` malformed line; `:133-137` duplicate; `snapshot-gate.yml:488-491,541-544` fail when checks/build failed, aggregate status empty or non-zero, or native policy not `success`; `test_snapshot_aggregate.py` | closed |
| T-19-18 | Information disclosure | report loading remote assets | low | mitigate | `test_snapshot_report.py:70-82` (no `src`/`href`/`https?://`); `snapshot_report.py` escapes every artifact-derived string (`html.escape`, lines 116-187) | closed |
| T-19-19 | Elevation of privilege | PR workflows | high | mitigate | `snapshot-gate.yml:28` `pull_request`, no `pull_request_target` anywhere in `.github/workflows`; `:44` `permissions: {}` then `contents: read` per job; no `secrets.` in the gate; `deploy.yml:32-33` / `deploy-beta.yml:35-36` call it with `contents: read`, no `secrets: inherit`; `test_snapshot_gate.py:226` `test_every_job_has_minimal_explicit_permissions` | closed |
| T-19-20 | Tampering | baseline swapped in the snapshot repository | high | mitigate | `snapshot_fetch.py:107-118` pinned 40-char commit, count check; `:76-98` every file hashed, missing / extra / differing → `Mismatch`; `:66-73` HEAD must equal the pinned commit; `run-shard.sh:139-143` exit 3/4 → `baseline-mismatch`, never a pass; `test_snapshot_fetch.py` | closed |
| T-19-21 | Denial of service | gate holding all 5 macOS slots | medium | accept | `Scripts/visual/README.md:107-112` records it (Pitfall 9); `snapshot-gate.yml:47-52` cancels superseded PR runs | closed (accepted, see log) |
| T-19-22 | Tampering | fault injection reaching main | medium | mitigate | no commit on HEAD sets `EHPANDA_SNAPSHOT_FAULT` in `.github` (`git log -G` on HEAD empty; only on `ci/snapshot-gate`, commits `3140c6665`..`a100173b5`); the switch is env-only in `run-shard.sh:38-41,88` and no workflow sets it | closed |
| T-19-23 | Tampering | simulator text size left at AX5 | low | mitigate | `NativeVisualPolicyUITests.swift:44,77,199,225` `LiveTextSize.reset()`; `snapshot-gate.yml:435` `content_size large` at the start of each attempt | closed |
| T-19-24 | Repudiation | public repository created without consent | high | mitigate (deferred) | **Not implemented**: plan 19-12 deferred (owner msg 3428); no publisher script or `test_snapshot_publish.py` exists; the blocking owner checkpoint has not run | **accepted-deferred** (owner msg 3573: carried with the deferred 19-12/19-13 screenshot publishing; must be closed before any baseline publication) |
| T-19-25 | Information disclosure | personal data in the public repository | medium | mitigate (deferred) | **Not implemented**: the snapshot repository README and the 19-13 pre-check before any push do not exist yet (19-12/19-13 deferred). Phase 19's own `Scripts/visual/README.md` and tests carry no name, home path or address (grep) | **accepted-deferred** (owner msg 3573: carried with the deferred 19-12/19-13 screenshot publishing; must be closed before any baseline publication; below the high threshold) |
| T-19-26 | Information disclosure | real content in a public picture | high | mitigate (deferred) | **Not implemented**: `test_snapshot_precheck.py`, the machine real-content check and the agent view of every picture (19-13 Task 1) are deferred (owner msg 3428). Primary control (synthetic fixtures only) is verified under T-19-11/13/14/16 | **accepted-deferred** (owner msg 3573: carried with the deferred 19-12/19-13 screenshot publishing; must be closed before any baseline publication) |
| T-19-27 | Repudiation | inferred approval | high | mitigate (deferred) | **Not implemented**: the 19-13 decision checkpoint recording the exact owner message has not run; no approval has been given or inferred, no `fingerprints.json` exists | **accepted-deferred** (owner msg 3573: carried with the deferred 19-12/19-13 screenshot publishing; must be closed before any baseline publication) |
| T-19-28 | Tampering | baseline altered after approval | high | mitigate | control present and fail-closed: `snapshot_fetch.py` verifies every shard's slices against the pinned fingerprints; with no `fingerprints.json` every compare fails (`snapshot-gate.yml:98-102`, `run-shard.sh:142`). The file itself is committed at approval (19-13) | closed |
| T-19-29 | Information disclosure | results and messages (live check) | high | mitigate | `DailyLiveCheckTests.swift:4-6,14` no page-derived assertion text; `LiveCheckResults.swift` enum-only schema (key set tested in `LiveCheckOfflineTests.swift:60-66`); `live-check.yml:48-55` uploads `results.json` only; `run-live-check.sh:143-144` keeps only the final `** TEST/BUILD ... **` line and deletes the log | closed |
| T-19-30 | Tampering (site) | state-changing request | high | mitigate | `PageObservation.swift:96-120` `GetOnlyURLProtocol` refuses non-GET; `LiveCheckOfflineTests.swift:119-125` asserts only `GET` and zero refusals; `test_request_allowlist.py` (Python reference, 5 tests OK) | closed |
| T-19-31 | Denial of service (site) | request volume | low | mitigate | `LiveCheckRunner.swift` 5 s `pause` between pages, one run a day (`live-check.yml:12` cron, `concurrency: live-check`); app's own retry policy (see IN-07 note below) | closed |
| T-19-32 | Information disclosure | issue text | high | mitigate | `report_issues.py:139-187` strict schema validation before any `gh` call (exact key sets, enums, size cap `:65`, duplicate keys, non-finite numbers); `:73-113` constant templates; `:181-186` values rebuilt from the vocabulary; `test_report_issues.py:217` content-like strings rejected before any gh call, with `fake-gh` | closed |
| T-19-33 | Spoofing | false "parser broken" during a block | medium | mitigate | `report_issues.py:258` only `classification == 'parser'` opens a parser issue; `:273-285` `unreachable` opens "cannot reach" only after `CANNOT_REACH_RUNS = 3`; `:176-177` an `unreachable` result cannot carry an expectation | closed |
| T-19-34 | Elevation of privilege | workflow token | low | mitigate | `live-check.yml:16-21` exactly `contents: read`, `issues: write`, `actions: read`; review fix `297164e62`: `:33` `persist-credentials: false`, `:46` `GH_TOKEN` only on the run step, `run-live-check.sh:134` `env -u GH_TOKEN -u GITHUB_TOKEN xcodebuild`, `:70-73` local mode unsets tokens | closed |
| T-19-35 | Information disclosure | first public log | high | mitigate | `19-16-DEPLOY.md:62-77` content check recorded, "log checked: no content"; owner msg 2456 | closed |
| T-19-36 | Repudiation | install without consent | medium | mitigate | `19-16-DEPLOY.md:11` owner msg 2456; branch deleted `:88` | closed |
| T-19-37 | Elevation of privilege | SnapshotTesting / fixtures in Release | high | mitigate | `verify-release.py` (forbidden content, payload, linkage, probe launch environment); 19-17-SUMMARY gate: Release build + `verify-release.py` PASS, 0 findings. Recorded result; re-run before any release build | closed |
| T-19-38 | Tampering | regression commit landing | medium | mitigate | 19-17 Task 3 deferred, so no regression commit exists; none on HEAD. The `ci/snapshot-gate` proof branch is the only place with proof commits | closed |
| T-19-39 | Information disclosure | README with personal details | low | mitigate | grep of `Scripts/**`, `.github/**`, `AppPackage/Tests/{VisualSnapshotTests,LiveCheckTests}` for home paths, `/Users/<name>`, LAN addresses, tokens: no hit except a CI runner path inside a test fixture (`test_snapshot_infra.py:30`, not personal) | closed |

*Status: open · closed · accepted-deferred (accepted by the owner on a condition; not closed)*
*Counts: 40 threats; closed 36 (including 2 accepted); accepted-deferred 4 (T-19-24, T-19-25, T-19-26, T-19-27); open 0.*

### Accepted-deferred threats (what is missing and how to close it)

Condition for all four (owner msg 3573): carried with the deferred 19-12/19-13 screenshot publishing; must be closed
before any baseline publication.

| Threat | Severity | File / evidence | Close by |
|--------|----------|-----------------|----------|
| T-19-24 | high | 19-VALIDATION.md rows 19-12-01..03; no `Scripts/visual/snapshot_publish.py` | Execute 19-12 (publisher never pushes by itself; owner checkpoint with message id before repository creation) |
| T-19-26 | high | 19-VALIDATION.md row 19-13-01; no `test_snapshot_precheck.py` | Execute 19-13 Task 1 (machine check plus agent view of every picture) before any push |
| T-19-27 | high | 19-VALIDATION.md rows 19-13-02..03 | Execute 19-13 Task 2; record the owner's exact approval message id; a partial answer is not approval |
| T-19-25 | medium | 19-VALIDATION.md rows 19-12-01..03, 19-13-01 | Execute 19-12/19-13; grep the new repository README for names and paths before pushing |

These four share one cause, the owner's deferral (msgs 3425 and 3428). They stay on the books until the deferred plans
run and each row above is closed with its evidence; the conditional acceptance does not retire them.

---

## Unregistered Flags (attack surface with no threat in any plan; none blocking)

SUMMARY.md files carry no `## Threat Flags` section. These came from reading the workflows and scripts.

| Flag | Severity | File:line | Note and suggested mitigation |
|------|----------|-----------|-------------------------------|
| UF-1 | medium | `.github/workflows/dependencies.yml:6-10,16,19-26,36` | Phase 19 added `actions: write` next to `contents: write` and `pull-requests: write`. The job checks out with the default persisted credential, then runs `swift package update` and `xcodebuild -resolvePackageDependencies` (evaluates third-party package manifests) before `peter-evans/create-pull-request@v8` (tag-pinned). Add `persist-credentials: false` to the checkout (the action takes its own token input), scope the permissions to the job, and consider SHA-pinning the action **Resolved** (`dc3d17a2b`): the checkout sets `persist-credentials: false`; `create-pull-request` takes `token: ${{ github.token }}` explicitly and is pinned by full commit SHA (tag in a comment); permissions stay at workflow level. |
| UF-2 | low | `.github/workflows/deploy.yml:37-50`, `deploy-beta.yml:40-49` | The `Deploy` jobs have no explicit `permissions`, so they take the repository default token scope; they need `contents: write`. State it (`permissions: contents: write`) so a permissive default cannot widen it. The gate jobs are explicit **Resolved** (`1c2acb75b`): both `Deploy` jobs declare `permissions: contents: write` (no step needs more). |
| UF-3 | low | `origin/ci/snapshot-gate` (head `a100173b5`) | The remote proof branch still exists (19-10-PROOF.md says deleted) and carries the fault-switch proof workflow. Gate has no secrets, so impact is a stray hosted run. Delete it once the deferred proof is done or abandoned **Open**: delete `origin/ci/snapshot-gate` after run 42951290351 ends. |
| UF-4 | low | `19-10-PROOF.md:317-318,345-346`; `Scripts/visual/run-library-validation.py:19` | Simulator device IDs (not hardware UDIDs) in tracked files; the second one pre-dates phase 19. Scrub if the repository is public **Resolved** (`aecd50b98`): device IDs replaced by neutral labels in `19-10-PROOF.md`; `run-library-validation.py` left as it pre-dates phase 19. |
| UF-5 | low | `Scripts/visual/validate-preview.py:87-97` (review IN-08) | The preview validator accepts a response that omits `locale`/`variant`/`review`. A review aid only, never a gate; require the fields **Resolved** (`c5453db72`): a response without `locale`, `variant` or `review` is rejected; existing tests green. |
| UF-6 | low | `AppPackage/Tests/LiveCheckTests/LiveCheckRunner.swift:199-209` (review IN-07) | Up to four immediate retries per list page; the daily check should not burst on a blocked IP. Add a pause between attempts |
| UF-7 | info | `snapshot-gate.yml:66,121,183,265,…` | Checkouts keep the persisted read-only token while PR code runs; no secrets, `contents: read`, so impact is nil. `persist-credentials: false` would remove it |
| UF-8 | info | `snapshot-gate.yml:201,207,…` | `${{ matrix.shard.id }}` is interpolated into `run:`; values come from the committed `snapshot-shards.json` (a PR's own code runs anyway; no secrets). Pass via `env` if desired |
| UF-9 | info | `nick-fields/retry@v4`, `actions/*@v7`, `softprops/action-gh-release@v3` | Actions are tag-pinned, not SHA-pinned; Dependabot is configured (`.github/dependabot.yml`) |

Checked and clean: no `pull_request_target`; `secrets.` appear only in `deploy.yml` / `deploy-beta.yml` (TelemetryDeck,
release token, notification hooks) and never in the gate, live-check, probe or measure workflows; untrusted values
(`inputs.*`, PR title) reach shell only through `env:` (`snapshot-gate.yml:85-88`, `deploy.yml:146`,
`deploy-beta.yml:157-180`); artifacts are `results.json`, `probe.json`, shard results (JSON, synthetic pictures, runner
logs) and the native-policy diagnostics on failure, none holds a secret or personal data; the gate's candidate
pictures and logs are synthetic; deploy gating is `needs: snapshot-gate` with the default `success()` and a fixed
`mode: compare`.

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-19-01 | T-19-SC | No new dependency; SnapshotTesting stays at exact 1.19.6 (`Package.swift:36`) | plan 19-01 (planning decision; no owner message id recorded) | 2026-11-11 (audit) |
| AR-19-02 | T-19-21 | The gate may hold all 5 macOS slots for about 9 hours; documented in `Scripts/visual/README.md:107-112`; superseded PR runs are cancelled | plan 19-10 (planning decision; no owner message id recorded) | 2026-11-11 (audit) |

### Accepted-deferred (conditional; not closed)

| Risk ID | Threat Ref | Rationale and condition | Accepted By | Date |
|---------|------------|-------------------------|-------------|------|
| AR-19-03 | T-19-24 | Public repository creation needs the publisher script and the owner's go-ahead, both in deferred 19-12. Carried with the deferred 19-12/19-13 screenshot publishing; must be closed before any baseline publication (owner msg 3573). Nothing can be published meanwhile | owner, msg 3573 | 2026-11-11 |
| AR-19-04 | T-19-25 | The snapshot repository README and the pre-check before any push do not exist yet. Same condition (owner msg 3573) | owner, msg 3573 | 2026-11-11 |
| AR-19-05 | T-19-26 | The machine real-content check and the agent view of every picture are 19-13 Task 1. Same condition (owner msg 3573). Primary control (synthetic fixtures only) is verified under T-19-11/13/14/16 | owner, msg 3573 | 2026-11-11 |
| AR-19-06 | T-19-27 | The decision checkpoint recording the owner's exact approval message is 19-13 Task 2. Same condition (owner msg 3573). No approval has been given or inferred | owner, msg 3573 | 2026-11-11 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-11-11 | 40 | 36 | 4 (3 blocking, 1 non-blocking) | gsd-security-auditor (claude-sonnet-5-5, high effort) |
| 2026-11-11 | 40 | 36 | 0 open; 4 accepted-deferred (owner msg 3573); UF-3 open (low) | phase close-out records (gsd-executor): acceptance recorded, no re-audit |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed (T-19-24, T-19-26 and T-19-27 are accepted-deferred by the owner, msg 3573, not closed)
- [x] `status: verified` set in frontmatter
- [ ] Accepted-deferred threats T-19-24, T-19-25, T-19-26, T-19-27 closed (owed with 19-12/19-13, before any baseline publication)
- [ ] UF-3 closed: delete `origin/ci/snapshot-gate` after run 42951290351 ends (open, low)

**Approval:** verified 2026-11-11 (threat register), with four threats accepted-deferred by the owner (msg 3573) on the
condition above.
