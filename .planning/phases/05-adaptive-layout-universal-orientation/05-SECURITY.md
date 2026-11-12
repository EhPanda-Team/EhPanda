---
phase: 5
slug: adaptive-layout-universal-orientation
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: 2026-07-13
---

# Phase 5 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

Phase 5 (adaptive layout + universal orientation) is a view-layer/layout modernization:
`DeviceUtil` → `DeviceClient`, `GeometryReader` → `onGeometryChange`, gesture/geometry
source swaps, orientation-lock removal, and presentation-routing fixes. It introduces
no new network, authentication, persistence, or untrusted-input surface. All 18 plan
threat registers were authored at plan time (`register_authored_at_plan_time: true`),
every threat is low-severity with an `accept` disposition, and none require an
implementation control. Per the L1 short-circuit rule (`threats_open: 0`,
`register_authored_at_plan_time: true`, `asvs_level == 1`), grep-depth verification is
sufficient and no auditor subagent was spawned.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| gesture input → reader math | Tap/pinch coordinates are OS-supplied SwiftUI gesture values (not untrusted network input); the reader only maps them to layout offsets. | OS-supplied gesture geometry (non-sensitive) |
| (no new external boundary) | Device class, container geometry, and interface-style reads are OS-supplied idioms. No plan in this phase adds an external input, network, auth, or persistence path. | OS-supplied layout/idiom values |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-05-01 | None | DeviceType / DeviceClient | low | accept | No security-relevant surface; device class is an OS-supplied idiom, not untrusted data. Phase 7 privacy blur / auto-lock untouched. | closed |
| T-05-02 | Information Disclosure | Orientation lock removal | low | accept | Orientation lock is NOT a confidentiality control (D-09); Phase 7 biometric auto-lock + background privacy blur remain in place. No content-at-rest / lock-screen change. | closed |
| T-05-03 | None | Idiom / metric view swaps | low | accept | Pure view-layer conversion; device class + container geometry are OS-supplied. | closed |
| T-05-04 | None | AppComponents metric / idiom swaps | low | accept | View-layer sizing conversion; geometry + device class OS-supplied. | closed |
| T-05-05 | None | Detail metric / Defaults dissolution | low | accept | View-layer sizing conversion; geometry + size class OS-supplied. | closed |
| T-05-06 | None | Home carousel / card sizing | low | accept | View-layer sizing/idiom conversion; geometry + device class OS-supplied. | closed |
| T-05-07 | None | GeometryReader → onGeometryChange | low | accept | Geometry OS-supplied; OCR boxes derive from already-decoded local image data, not new external input. | closed |
| T-05-08 | None | GestureHandler purification / geometry source | low | accept | Gesture coordinates + geometry OS-supplied (not network input); parity harness guards behavior, not a security boundary. | closed |
| T-05-09 | None | Reader gesture / geometry source swap | low | accept | Removing an orientation-derived layout branch is not a confidentiality change (D-09). GestureHandlerTests guard parity. | closed |
| T-05-10 | None | DeviceUtil deletion / Defaults dissolution / ApplicationClient window lookup | low | accept | Inlined window lookup is the same connected-scene enumeration as before, used only to set interface style (cosmetic). No surface added or removed. | closed |
| T-05-11 | None | AboutView metadata placement | low | accept | UI-only relocation of constant, already-shipped copyright/version strings; no attack surface introduced. | closed |
| T-05-12 | None | Reader placeholder sizing | low | accept | Layout-only sizing-modifier change; no attack surface introduced. | closed |
| T-05-13 | None | GalleryCardCell sizing | low | accept | Layout-only change (removes a redundant sizing modifier); no attack surface introduced. | closed |
| T-05-14 | None | SettingTextField a11y label + reusable sheet cancel actions | low | accept | UI-only accessibility/scoping change; no input-validation, network, auth, or persistence surface. | closed |
| T-05-15 | None | Favorites toolbar grouping | low | accept | UI-only toolbar regrouping; reducer/routing untouched; no attack surface introduced. | closed |
| T-05-16 | None | Reader upper toolbar safe geometry | low | accept | Layout-only safe-area inset; no attack surface introduced. | closed |
| T-05-17 | None | Home root surface + scene manifest | low | accept | UI/manifest-only; disabling multi-scene REMOVES the previously advertised shared-state multi-window path rather than adding surface. | closed |
| T-05-18 | None | Gallery detail routing (push vs present) | low | accept | Presentation-routing-only investigation/fix; no attack surface introduced. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on (high) count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-05-01 | T-05-01 | Device class is an OS-supplied idiom, not untrusted data; no security surface. | Chihchy (plan-time disposition) | 2026-07-13 |
| AR-05-02 | T-05-02 | Orientation lock is not a confidentiality control (D-09); Phase 7 privacy controls remain in place. | Chihchy (plan-time disposition) | 2026-07-13 |
| AR-05-03 | T-05-03 | Pure view-layer idiom/metric conversion; OS-supplied inputs only. | Chihchy (plan-time disposition) | 2026-07-13 |
| AR-05-04 | T-05-04 | View-layer sizing conversion; OS-supplied inputs only. | Chihchy (plan-time disposition) | 2026-07-13 |
| AR-05-05 | T-05-05 | View-layer sizing conversion + Defaults dissolution; OS-supplied inputs only. | Chihchy (plan-time disposition) | 2026-07-13 |
| AR-05-06 | T-05-06 | Home view-layer sizing/idiom conversion; OS-supplied inputs only. | Chihchy (plan-time disposition) | 2026-07-13 |
| AR-05-07 | T-05-07 | Geometry OS-supplied; OCR boxes derive from local decoded image data. | Chihchy (plan-time disposition) | 2026-07-13 |
| AR-05-08 | T-05-08 | Gesture coordinates + geometry OS-supplied, not network input. | Chihchy (plan-time disposition) | 2026-07-13 |
| AR-05-09 | T-05-09 | Removing an orientation-derived branch is not a confidentiality change (D-09). | Chihchy (plan-time disposition) | 2026-07-13 |
| AR-05-10 | T-05-10 | Inlined window lookup is the same scene enumeration; cosmetic interface-style set only. | Chihchy (plan-time disposition) | 2026-07-13 |
| AR-05-11 | T-05-11 | UI-only relocation of constant strings. | Chihchy (plan-time disposition) | 2026-07-13 |
| AR-05-12 | T-05-12 | Layout-only sizing change. | Chihchy (plan-time disposition) | 2026-07-13 |
| AR-05-13 | T-05-13 | Layout-only change (redundant modifier removed). | Chihchy (plan-time disposition) | 2026-07-13 |
| AR-05-14 | T-05-14 | UI-only a11y/scoping change. | Chihchy (plan-time disposition) | 2026-07-13 |
| AR-05-15 | T-05-15 | UI-only toolbar regrouping; reducer/routing untouched. | Chihchy (plan-time disposition) | 2026-07-13 |
| AR-05-16 | T-05-16 | Layout-only safe-area inset. | Chihchy (plan-time disposition) | 2026-07-13 |
| AR-05-17 | T-05-17 | UI/manifest-only; multi-scene removal reduces shared-state surface. | Chihchy (plan-time disposition) | 2026-07-13 |
| AR-05-18 | T-05-18 | Presentation-routing-only fix. | Chihchy (plan-time disposition) | 2026-07-13 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-07-13 | 18 | 18 | 0 | gsd-secure-phase (L1 short-circuit, no auditor spawn) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-07-13
