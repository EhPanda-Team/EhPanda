---
phase: 8
slug: architecture-hygiene-client-seams
status: verified
threats_open: 0
asvs_level: 1
created: 2026-07-14
---

# Phase 8 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Cookie value → diagnostic log sink | Authentication cookies must not enter OSLog output at a readable privacy level. | `ipb_member_id`, `ipb_pass_hash`, and `igneous` cookie values |
| Cookie value → at-rest store | Authentication cookies remain in `HTTPCookieStorage`; migration to a different store is outside this milestone. | Authentication cookies and session state |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-08-01 | Information Disclosure | `logger.*` interpolations in `AppPackage/Sources` | high | mitigate | `Scripts/check-cookie-logging.sh` audits cookie-bearing public log interpolation and confines `getCookiesDescription` to its clipboard consumer; the gate exits successfully. | closed |
| T-08-02 | Information Disclosure | `getCookiesDescription` clipboard export | low | accept | Export remains an explicit user action in account settings and the logging gate verifies that the description does not reach a logger. | closed |
| T-08-03 | Information Disclosure / Tampering | Authentication cookies in `HTTPCookieStorage` | medium | accept | D-01 records the compatibility and portability rationale for retaining the existing storage model; at-rest migration is explicitly outside this milestone. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above `workflow.security_block_on` count toward `threats_open`.*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-08-01 | T-08-02 | Clipboard export is intentional, user initiated, and excluded from diagnostic logging. | Phase decision D-02 | 2026-07-14 |
| AR-08-02 | T-08-03 | Retaining `HTTPCookieStorage` avoids credential orphaning after sideload Team-ID changes and preserves the established portable-credentials model. | Phase decision D-01 | 2026-07-14 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-07-14 | 3 | 3 | 0 | Codex (`gsd-secure-phase`, ASVS L1) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-07-14
