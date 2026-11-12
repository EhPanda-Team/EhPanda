---
phase: 7
slug: root-privacy-mask-auto-lock-removal
status: verified
threats_open: 0
asvs_level: 1
block_on: high
register_authored_at_plan_time: true
created: 2026-07-14
---

# Phase 7 — Security

> Per-phase security contract for the root privacy mask and custom auto-lock removal.

---

## Audit Summary

| Metric | Count |
|--------|------:|
| Threats registered | 20 |
| Mitigations verified | 15 |
| Accepted dispositions documented | 5 |
| Closed | 20 |
| Open at or above `high` | 0 |
| Open below `high` | 0 |
| Unregistered flags | 0 |

This is an ASVS Level 1 verification. Every declared mitigation was checked in current source or
tests at its cited location. The five accepted risks below reproduce plan-time, owner-approved
low-severity dispositions; this audit does not introduce any new acceptance.

The final coverage contract is the gap-corrected bijection: 39 runtime presentation roots map to 39
unique executable masks. Earlier plan references to 40 applications included one nested Download
Inspector duplicate. Removing that duplicate preserved every runtime root while ensuring each root is
masked exactly once.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| App foreground → App Switcher/background | iOS may capture a snapshot as the scene becomes inactive or backgrounded. | Potentially sensitive gallery, reader, account, and diagnostic UI content. |
| Scene lifecycle before settings initialization | Scene transitions may occur before persisted settings finish loading. | The transient privacy-mask value and background-entry latch. |
| App root → separately presented roots | SwiftUI sheets and full-screen covers form independent runtime presentation roots. | App content presented outside the root `TabView` hierarchy. |
| Removed biometric client → OS per-app lock | In-app biometric re-authentication was removed and re-authentication responsibility is deferred to the OS. | User authentication posture; no biometric credential data remains in the app path. |
| Package graph and app metadata | Removing the biometric module must not leave package, entitlement, or localized metadata residue. | Build dependencies and declared app capabilities. |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation / Evidence | Status |
|-----------|----------|-----------|----------|-------------|-----------------------|--------|
| T-07-01 | Information Disclosure | Shared privacy-mask default and end-to-end flow | medium | mitigate | `AppSharedKeys.swift:74-78` defines the in-memory `Double` default as `0`; `AppReducer.swift:82-99` writes the lifecycle value; the 39-root inventory proves every runtime root reads it through `.privacyMask()`. | closed |
| T-07-02 | Tampering | Package installation surface | low | accept | No external package was added by this phase. Documented as accepted risk AR-07-01. | closed |
| T-07-03 | Information Disclosure | Inactive-scene blur timing | high | mitigate | `AppReducer.swift:82-99` writes `privacyMaskIntensity` on `.inactive` before the settings gate; `AppReducerScenePhaseTests.swift:22-42` verifies inactive then active writes. | closed |
| T-07-04 | Repudiation / Denial | Foreground greeting and clipboard cardinality | medium | mitigate | `AppReducerScenePhaseTests.swift:17-59` exhaustively receives one greeting and one enabled clipboard action, zero disabled clipboard actions, and finishes without disabled exhaustivity; `:123-130` counts the dependency invocation. | closed |
| T-07-05 | Elevation of Privilege | Removal of custom biometric auto-lock | low | accept | Re-authentication is intentionally deferred to the OS per-app lock while the privacy mask remains. Documented as accepted risk AR-07-02. | closed |
| T-07-06 | Information Disclosure | Four app-level roots | high | mitigate | `TabBarView.swift:68`, `:71`, `:78`, and `:92` apply the mask to the app root and its three app-level presentations; inventory ROOT-01 through ROOT-04 maps them uniquely. | closed |
| T-07-07 | Spoofing / Elevation | Orphaned Face ID capability metadata | medium | mitigate | Current-source absence audit finds no `LocalAuthentication`, `LAContext`, or `NSFaceIDUsageDescription` in app sources, `App/Info.plist`, or `App/InfoPlist.xcstrings`; the removed client is also absent from `Package.swift`. | closed |
| T-07-08 | Tampering | Package graph after target removal | low | accept | The removed in-repository target added no registry dependency and Phase 7 did not modify `Package.resolved`. Documented as accepted risk AR-07-03. | closed |
| T-07-09 | Information Disclosure | Home and Favorites roots | high | mitigate | Inventory ROOT-21 through ROOT-28 maps all eight distinct Home/Favorites runtime roots to eight unique live mask applications. | closed |
| T-07-10 | Information Disclosure | Temporary vestigial blur parameters | low | accept | The sequential migration temporarily accepted zero-valued parameters behind an already-masked app root; current source contains no `blurRadius` or `autoBlur`. Documented as accepted risk AR-07-04. | closed |
| T-07-11 | Information Disclosure | Search and Downloads roots | high | mitigate | Inventory ROOT-18 through ROOT-20 and ROOT-31 through ROOT-35 maps all eight distinct runtime roots to unique masks. The earlier ninth application was the removed nested Download Inspector duplicate, not another root. | closed |
| T-07-12 | Information Disclosure | Downloads reader full-screen cover | high | mitigate | `DownloadsView.swift:63-71` presents the reader and applies its sole mask at `:71`; inventory ROOT-20 confirms the mapping. | closed |
| T-07-13 | Information Disclosure | Detail roots | high | mitigate | Inventory ROOT-05 through ROOT-17 maps all 13 Detail runtime roots to 13 unique live mask sites. | closed |
| T-07-14 | Information Disclosure | Detail reader full-screen cover | high | mitigate | `DetailView.swift:208-216` presents the reader and applies its sole mask at `:216`; inventory ROOT-11 confirms the mapping. | closed |
| T-07-15 | Information Disclosure | App activity-log run-picker | high | mitigate | `AppActivityLogsView.swift:49-51` applies `.privacyMask()` directly to the presented `RunPickerSheet`; inventory ROOT-37 records the live site. | closed |
| T-07-16 | Information Disclosure | Reader and Settings web-view roots | high | mitigate | Inventory ROOT-29, ROOT-30, ROOT-36, ROOT-38, and ROOT-39 maps both reader presentations and all three Settings web-view presentations to unique masks. | closed |
| T-07-17 | Information Disclosure | Uniform runtime-root coverage | high | mitigate | `07-PRIVACY-MASK-INVENTORY.md` re-runnable audit passes with 39 roots, 39 unique live sites, 39 executable masks, 41 presentation modifiers, and 3 preview-only exclusions. The prior device-level approval in `07-08-SUMMARY.md` remains applicable because gap closure removed only a nested duplicate. | closed |
| T-07-18 | Repudiation | Scene-phase exactly-once launch effects | medium | mitigate | The exhaustive tests in `AppReducerScenePhaseTests.swift:17-59` receive every expected foreground action and assert clipboard dependency counts of `1` and `0`; no `withExhaustivity(.off)` remains. | closed |
| T-07-19 | Elevation of Privilege | Residual re-authentication posture | low | accept | The intentional OS-owned re-authentication posture and retained privacy mask were owner-approved; orphaned biometric metadata is absent. Documented as accepted risk AR-07-05. | closed |
| T-07-20 | Information Disclosure | Pre-settings scene-transition race | high | mitigate | `AppReducer.swift:82-99` performs active/inactive mask writes and background latching before `hasLoadedInitialSetting`; `AppReducerScenePhaseTests.swift:61-77` exhaustively verifies inactive-to-background behavior with settings unloaded. | closed |

*Status values: `open`, `closed`, or `open — below high threshold (non-blocking)`.*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-07-01 | T-07-02 | This phase added no external package or registry install, so a package-legitimacy checkpoint was not applicable. | Phase plan decision | 2026-07-14 |
| AR-07-02 | T-07-05 | Removing in-app biometric re-authentication is an intentional posture change; the OS per-app lock owns re-authentication and the privacy mask remains. | Locked decision D-08 | 2026-07-14 |
| AR-07-03 | T-07-08 | Removing an in-repository target without external dependency changes did not require lockfile regeneration or a supply-chain checkpoint. | Phase plan decision | 2026-07-14 |
| AR-07-04 | T-07-10 | During the sequential migration, remaining zero-valued child parameters were accepted temporarily because the app root already masked the window; those parameters are now fully removed. | Phase plan decision | 2026-07-14 |
| AR-07-05 | T-07-19 | The residual absence of in-app re-authentication is the same intentional OS-owned posture as D-08; device-level privacy-mask coverage was separately approved. | Locked decision D-08 | 2026-07-14 |

Accepted risks are limited to the five low-severity dispositions authored in the phase plans. No
high- or medium-severity threat is accepted.

---

## Unregistered Flags

None. The twelve summaries declare no `## Threat Flags` entries, and implementation review found no
summary-reported attack surface outside T-07-01 through T-07-20.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-07-14 | 20 | 20 | 0 | `gsd-security-auditor` (generic-agent workaround) |

### Verification record

- ASVS level: 1 (presence verification at every declared mitigation site).
- Blocking threshold: `high`.
- Blocking-open threats: 0; therefore frontmatter `threats_open` is `0`.
- Current source absence audit: zero legacy blur/lock/biometric symbols and zero Face ID usage metadata.
- Root bijection audit: 39 runtime roots = 39 unique executable mask sites; no stale inventory lines.
- Tests: current `07-VERIFICATION.md` records all three focused scene-phase tests and the full
  post-gap regression gate as passed.

---

## Sign-Off

- [x] All threats have a disposition (`mitigate` or `accept`; no transfer dispositions were declared)
- [x] Every mitigation is present in current implementation or tests
- [x] Accepted risks are documented without adding new acceptance
- [x] Summary threat flags are incorporated
- [x] `threats_open: 0` confirmed at `block_on: high`
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-07-14
