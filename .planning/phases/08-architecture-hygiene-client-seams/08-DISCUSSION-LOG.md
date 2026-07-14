# Phase 8: Architecture Hygiene & Client Seams - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-14
**Phase:** 8-Architecture Hygiene & Client Seams
**Areas discussed:** Cookies → Keychain (QUAL-01), Which Utils become clients (HYG-01), DataCache de-globalization (HYG-01), QUAL-02 test bar

---

## Cookies → Keychain (QUAL-01)

The user asked to research the actual concern before deciding. Research established: the Apple DTS
durability warning targets app-group cross-process cookie stores (not EhPanda's single-process
case); Keychain hardens at-rest storage but is *less* reliable under sideload distribution
(Team-ID re-sign orphans items; `errSecMissingEntitlement -34018`). Several sub-options were
explored (A durable mirror, A+ session-only hybrid, B source-of-truth) before the user surfaced
two decisive constraints — the manual cookie-edit/clipboard-export UI (credential is
intentionally user-portable) and the Keychain-unavailable/orphaning risk under re-signing — plus
their lived experience of never observing cookie loss.

| Option | Description | Selected |
|--------|-------------|----------|
| Drop Keychain, keep logging audit | Rescope QUAL-01: no Keychain migration; keep only "no cookie value at .public". Reconcile REQUIREMENTS/ROADMAP. | ✓ |
| Keep minimal mirror (variant A) | Best-effort Keychain mirror hydrated into HTTPCookieStorage. | |
| Do the full original requirement | Keychain migration + logging audit as originally written. | |

**User's choice:** Drop the Keychain migration; keep the cookie-logging audit only.
**Notes:** User challenged the improvement the change would buy ("years, never seen cookie loss").
Agreed the Keychain move is a premium exceeding its expected payout here, and that the honest move
is to rescope + document (like Phase 6's rejected decomposition), not to build for a "best
practice" checkbox. The logging audit is near-zero-cost hygiene and stays.

---

## Which Utils become clients (HYG-01)

Four sub-decisions. Grounding: the injected clients already exist; the Utils are redundant/direct
callers; `AppUtil.galleryHost` is backed by a manual UserDefaults mirror shadowing `@Shared(.setting)`.

**galleryHost de-globalization**

| Option | Description | Selected |
|--------|-------------|----------|
| @Shared(.appStorage) single truth | Move host to a standalone @Shared(.appStorage) key; views @SharedReader. | |
| Parameterize all the way | Views take host from store state/params; all ~44 requests take host explicitly; delete global read + mirror. | ✓ |
| Keep mirror, rename only | Retain UserDefaults mirror architecture; just rename AppUtil.galleryHost. | |

**View-layer global reads (CookieUtil.didLogin ×12, HapticsUtil ×4)**

| Option | Description | Selected |
|--------|-------------|----------|
| Views use @Dependency | Views read @Dependency(\.cookieClient)/(\.hapticsClient) directly; ban .live/.shared/static in consumers. | ✓ |
| Promote to reducer state | didLogin → reducer state; haptics → action-dispatched. | |
| Hybrid | didLogin → state, haptics → @Dependency. | |

**URLUtil (pure builders) + FileUtil (path constants)**

| Option | Description | Selected |
|--------|-------------|----------|
| Retain as pure namespaces | Keep as pure constants/helpers, drop *Util naming, no client wrapper. | ✓ |
| Wrap into clients per requirement text | Fold URLUtil→URLClient, FileUtil→FileClient, all @Dependency. | |

**galleryHost UserDefaults mirror**

| Option | Description | Selected |
|--------|-------------|----------|
| Keep the mirror (parity) | Retain mirror write + launch restore (via userDefaultsClient). | |
| Remove it entirely | Delete mirror write + launch restore; host lives only in @Shared(.setting). | ✓ |

**User's choice:** Parameterize host all the way; views use `@Dependency` (direct `.live`/`.shared`
forbidden); `CookieUtil`/`HapticsUtil` folded into their clients and deleted; `URLUtil`/`FileUtil`
kept as pure namespaces (no wrapper); UserDefaults mirror removed entirely.
**Notes:** Accepted behavior change — setting-blob loss resets host to `.ehentai`. `AppUtil` type
eliminated; `dispatchMainSync` deleted as dead code (zero callers); `version`/`build`/`isTesting`
placement delegated to Claude's discretion.

---

## DataCache de-globalization (HYG-01)

The user asked whether choosing the standalone-dependency option preserves the `actor`.

| Option | Description | Selected |
|--------|-------------|----------|
| Standalone @Dependency(\.dataCache), keep actor, delete static shared | DataCache stays an actor; new DependencyKey (liveValue = single instance); ImageClient/LibraryClient/DownloadClient resolve \.dataCache; ReadingView uses @Dependency. | ✓ |
| Fold into ImageClient | ImageClient becomes sole owner; other clients depend on ImageClient. | |

**User's choice:** Standalone `@Dependency(\.dataCache)`, `actor` type unchanged, `static shared`
deleted.
**Notes:** Confirmed the actor is retained. Rejected folding into ImageClient (would create
client→client dependencies and contradicts DataCache's documented reader-pipeline scope).

---

## QUAL-02 test bar

| Option | Description | Selected |
|--------|-------------|----------|
| Confirm NetworkingFeature satisfied | Phase 4 baselines close QUAL-02's networking share; no new networking tests. | ✓ |
| Add more networking tests | Supplement Phase 4 coverage this phase. | |

| Option | Description | Selected |
|--------|-------------|----------|
| Reworked-seam-first, behavior matrix | CookieClient (didLogin matrix, Set-Cookie parsing, sync/fulfill/import) + ImageClient (cache hit/miss, retry, per-test DataCache + pixel dims). | ✓ |
| Exhaustive full-behavior suites | Every public behavior of both clients, including untouched paths. | |

**User's choice:** Confirm NetworkingFeature satisfied by Phase 4 (clears the STATE.md blocker);
CookieClient + ImageClient covered reworked-seam-first with a behavior matrix.
**Notes:** No coverage padding for client paths this phase doesn't touch. New test targets carry a
`parent_config` `.swiftlint.yml`.

---

## Claude's Discretion

- `AppUtil.version`/`build` and `isTesting` placement after `AppUtil` is eliminated.
- `URLUtil`/`FileUtil` final relocation and naming.
- `DataCache` `testValue` strategy (must use a per-test instance in tests regardless).
- Removing the stale empty `AppPackage/Sources/AuthorizationClient/` directory if orphaned.
- Plan/wave decomposition.

## Deferred Ideas

None — discussion stayed within phase scope. The dropped Keychain cookie migration is out of the
milestone (owner decision), not deferred to a later phase.
