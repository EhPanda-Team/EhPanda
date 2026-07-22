---
phase: 11
slug: infra-refactor-lint-capstone
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on (high) severity
threats_open: 0
asvs_level: 1
created: 2026-07-22
---

# Phase 11 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
> Verified retroactively (State B) from the plan-time STRIDE registers in all 32 `*-PLAN.md`
> files and the `## Threat Flags` / inline threat confirmations in their SUMMARYs. Register was
> authored at plan time (`register_authored_at_plan_time: true`); ASVS L1; block-on `high`.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Remote HTML → parser | Untrusted e-hentai/exhentai page content enters `ParserFeature` | Scraped markup, gallery metadata |
| Parser / clients → OSLog | New/refactored `logger.error` lines cross into the system log | Error values + fixed descriptors only |
| Server pagination cursor → view | `PageNumber.hasNextPage()` drives fetch-more in gallery lists | Server-controlled boolean/cursor |
| Test seams → production | Dependency-injection default arguments added for testability | Injected clients/clocks (tests only) |
| Package registry → build | Third-party package installs (supply chain) | None — zero packages installed this phase |

---

## Threat Register

All threats CLOSED. `mitigate` threats carry a gate that the corresponding SUMMARY and the phase
`11-VERIFICATION.md` (status: passed, 9/9) confirm passed; `accept` threats are low-severity and
recorded in the Accepted Risks Log. The Information-Disclosure mitigations were additionally
re-confirmed at code level this audit: `Scripts/check-cookie-logging.sh` → exit 0.

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-11-01 | Information Disclosure | new `logger.error` in ParserFeature | high | mitigate | Fixed descriptors + `error` value only, `privacy: .public`; cookie-logging gate | closed |
| T-11-02 | Tampering (input validation) | `parseGalleries` mode branches | medium | mitigate | Throwing on unparseable input; existing `AppError` surface | closed |
| T-11-03 | Information Disclosure | new logger calls in DownloadClient | high | mitigate | Fixed op descriptors + error values; cookie-logging gate | closed |
| T-11-04 | Information Disclosure | new logger calls | high | mitigate | Fixed descriptors + error values; cookie-logging gate | closed |
| T-11-05 | Denial of Service | catch paths altering download control flow | medium | mitigate | Fallbacks mirrored exactly; deterministic DownloadsFeature suite | closed |
| T-11-06 | Information Disclosure | new logger calls in AppTools/DataCache | medium | mitigate | No payloads/URLs logged; cookie-logging gate | closed |
| T-11-07 | Tampering | JSONValue decode-order drift | high | mitigate | Bit-identical probe order; AppModels schema/migration tests | closed |
| T-11-08 | Information Disclosure | logger calls near request/cookie machinery | high | mitigate | Fixed descriptors + error values; cookie-logging gate (NetworkingFeature gained no logging) | closed |
| T-11-09 | Denial of Service | orphaned child effects after dismissal | medium | mitigate | TCA `forEach`/`ifLet` auto-cancel; verified by `poppingCancelsTheChildObservation` TestStore test | closed |
| T-11-10 | Denial of Service | missed load on a construction path | medium | mitigate | Exhaustive construction-site pairing; TestStore per path | closed |
| T-11-11 | Denial of Service | orphaned sub-screen effects | low | mitigate | `ifLet` auto-cancellation on dismissal | closed |
| T-11-12 | Denial of Service | reader image-load order/cancellation drift | high | mitigate | Cancellation IDs preserved verbatim; construction-site pairing; ReadingFeature suite | closed |
| T-11-13 | Denial of Service | pump left running after dismissal | medium | mitigate | Dismissal interception + TCA auto-cancellation; Phase 7 exactly-once tests | closed |
| T-11-14 | Denial of Service | premature rule flip breaking builds | medium | mitigate | Flip in same commit as last fix; binary zero-check before commit | closed |
| T-11-15 | Tampering | stable preview UUIDs used outside previews | low | mitigate | Consumers restricted to `#Preview`; diff-checked (`172ef103`) | closed |
| T-11-16 | Denial of Service | out-of-bounds trap in reader paging | medium | mitigate | Guards/validated locals; PageHandler suites | closed |
| T-11-17 | Denial of Service | out-of-bounds trap on malformed HTML | high | mitigate | Guards route to existing parse-error paths (AppError) | closed |
| T-11-18 | Denial of Service | out-of-bounds trap on malformed response data | high | mitigate | Reachable traps (Request+Detail/Account) now route into existing error paths; parity suites | closed |
| T-11-19 | Denial of Service | histogram out-of-bounds trap | medium | mitigate | Trap surface removed with the index arithmetic; parity fixtures (latent, not live) | closed |
| T-11-20 | Denial of Service | residual out-of-bounds traps | medium | mitigate | Genuinely-reachable byte/URL reads (AnimatedImage, URLClient, AppError+Context) route to nil/false/empty; binary zero-check | closed |
| T-11-21 | Denial of Service | false-positive regex breaking valid builds | medium | mitigate | Tuned to zero on clean tree + nine-case positive-control probe before flip | closed |
| T-11-22 | Tampering | seam changing production storage location | high | mitigate | Default expressions preserve current derivation verbatim; acceptance asserts it | closed |
| T-11-23 | Tampering | production image-cache identity drift via seam | high | mitigate | No seam added; production default unchanged; DownloadsFeature suite | closed |
| T-11-24 | Tampering | hidden shared state surfacing as parallel-run flake | medium | mitigate | Per-suite diagnosis before removal; double stability runs; inject-over-serialize | closed |
| T-11-25 | Denial of Service | flaky suite from premature annotation removal | medium | mitigate | Compiler-driven narrow-scope restore; full-suite gate ×3–4 (11-22 + 11-22.1) | closed |
| T-11-26 | Repudiation | silently weakened test assertions during conversion | medium | mitigate | Assertion changes forbidden; identical 253-test count across runs | closed |
| T-11-27 | Denial of Service | flip with residual Tests violations | high | mitigate | `build-for-testing` in the flip commit; binary zero-check | closed |
| T-11-28 | Denial of Service | `--fix` breaking `#if`-wrapped imports | medium | mitigate | Manual review of 3 conditional-import files; 18-target build; 565-test suite | closed |
| T-11-29 | Denial of Service | typo during mass rewrap | low | mitigate | Compiler gate per half; diff-shape replay; 565-test suite | closed |
| T-11-30 | Denial of Service | flip with residual Tests violations | medium | mitigate | Binary zero-check + `build-for-testing` in the flip commit | closed |
| T-11-31 | Denial of Service | chain reformat introducing line_length violations | low | mitigate | 120-char pre-measure; `--strict` zero; both build gates + 565-test suite | closed |
| T-11-32 | Repudiation | undocumented exceptions escaping review | medium | mitigate | Grep+`git blame` inventory exhaustive by construction; `swiftlint_disable_requires_reason` at error | closed |
| T-11-33 | Denial of Service | DetailList trailing-row trigger → unbounded `fetchMoreAction` | medium | mitigate | Fires only on last-row visibility edge; reducer `hasNextPage()` + `footerLoadingState != .loading` guards (set synchronously) make a duplicate send a no-op | closed |
| T-11-34 | Denial of Service | `AutoLoadNextPage` re-applied to incompatible layout | medium | mitigate | Second trigger deleted from DetailList so the two cannot both fire; owner thumbnail-mode chain-fetch check | closed |
| T-11-36 | Denial of Service | hostile server count/file-size strings in a resized row | low | mitigate | Existing line-limit + minimum-scale-factor modifiers unchanged; only icon scale changed | closed |
| T-11-38 | Tampering | lint-bar erosion via suppression to force appearance parity | medium | mitigate | `swiftlint:disable`/rule edits/severity changes forbidden per task; build under SwiftLint-at-error is the gate; `git diff` asserts `.swiftlint.yml` untouched | closed |
| T-11-35 | Tampering | server-controlled `PageNumber.hasNextPage()` | low | accept | See Accepted Risks Log | closed |
| T-11-37 | Information Disclosure | rendered gallery/torrent metadata | low | accept | See Accepted Risks Log | closed |
| T-11-SC | Tampering (supply chain) | package installs | low | accept | See Accepted Risks Log | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above `high` count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-11-1 | T-11-SC | Supply chain: registered in every plan's threat model; the phase installed **zero** packages (RESEARCH Package Legitimacy Audit: none), so no new dependency provenance to verify. | owner | 2026-07-22 |
| AR-11-2 | T-11-35 | Server-controlled pagination cursor: a lying `hasNextPage()` yields at most one extra fetch per scroll arrival, already rate-limited by the reducer's synchronous `footerLoadingState` guard. Pre-existing; cleared by the G-11-7 diagnosis. | owner | 2026-07-22 |
| AR-11-3 | T-11-37 | Rendered gallery/torrent metadata: the G-11-8 fix is an icon-metric change only — no new field is surfaced, added, or reformatted. | owner | 2026-07-22 |
| AR-11-4 | (pre-existing, out of scope) | `DownloadClient+ResponseValidation.swift`'s unexpected-HTML `logger.error` interpolates `requestURL?.absoluteString`. It predates Phase 11, was left untouched, and passes `Scripts/check-cookie-logging.sh`. Noted here for visibility; not a Phase 11-introduced threat. Candidate for a future logging-hygiene pass. | owner | 2026-07-22 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-07-22 | 39 | 39 | 0 | gsd-secure-phase (State B, retroactive from plan-time registers) |

Notes:
- 39 = 38 numbered threats (T-11-01…T-11-38) + the recurring supply-chain threat T-11-SC (registered per-plan, consolidated to one row).
- Short-circuit applied per workflow: `threats_open: 0 AND register_authored_at_plan_time: true AND asvs_level == 1` → L1 grep-depth sufficient, no deeper auditor pass required. The one code-level spot-check performed (`check-cookie-logging.sh`, the primary Information-Disclosure control) passed.
- The Information-Disclosure class (logging) is the only genuinely new attack surface in an otherwise lint/refactor phase; every SUMMARY independently records "no new network, auth, file-access or schema surface."

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-07-22
