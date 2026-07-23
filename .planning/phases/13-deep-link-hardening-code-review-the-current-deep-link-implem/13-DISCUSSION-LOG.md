# Phase 13: Deep Link Hardening - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-23
**Phase:** 13-Deep Link Hardening
**Areas discussed:** Malformed-link failure UX, UI test harness strategy, Test route coverage, Parsing hardening depth

---

## Malformed-link failure UX

| Option | Description | Selected |
|--------|-------------|----------|
| Error toast | Phase 9 path: persistent tappable toast → ErrorInfoView with URL and reason | ✓ |
| Lightweight toast only | Brief non-tappable "Unsupported link" notice | |
| Keep silent no-op | Leave current behavior (likely fails criterion 3) | |

**User's choice:** Error toast for explicit opens (ehpanda:// scheme / ShareExtension).

| Option | Description | Selected |
|--------|-------------|----------|
| Silent for non-gallery | Non-gallery clipboard URL stays silent; only a recognized gallery link that fails to resolve toasts | ✓ |
| Same as explicit opens | Any clipboard URL passing the host check gets the error toast | |
| You decide | Claude picks the boundary during planning | |

**User's choice:** Silent for non-gallery clipboard URLs.

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated case | New AppError case (e.g. unsupportedDeepLink) with tailored description + recovery suggestion | ✓ |
| Reuse existing case | Map to an existing AppError with URL in ErrorInfo context | |
| You decide | Planner chooses within Phase 9 conventions | |

**User's choice:** Dedicated AppError case (Phase 12 D-10 precedent).

| Option | Description | Selected |
|--------|-------------|----------|
| Existing mapping is enough | GalleryReverseRequest's AppError flows into the toast with URL context | ✓ |
| Add deep-link-specific context | Enrich ErrorInfo with entry source (scheme/clipboard/share) | |
| You decide | Planner picks context rows | |

**User's choice:** Existing mapping is enough for failed fetches.

---

## UI test harness strategy

| Option | Description | Selected |
|--------|-------------|----------|
| XCUITest target | New UI-testing bundle in EhPanda.xcodeproj, system-open deep-link delivery | ✓ |
| TCA integration tests + owner UAT | Reducer-level routing tests, on-screen leg by owner UAT | |
| Both layers | XCUITest smoke set + TCA matrix breadth | |

**User's choice:** XCUITest target.

| Option | Description | Selected |
|--------|-------------|----------|
| Hermetic via stubs | Launch-environment flag swaps in stubbed gallery responses | ✓ |
| Local loopback server | Test bundle serves fixture HTML from localhost | |
| Live network | Tests fetch real galleries from e-hentai.org | |

**User's choice:** Hermetic via stubs.

| Option | Description | Selected |
|--------|-------------|----------|
| 2nd test plan, same scheme | UITests.xctestplan beside FeatureTests on the EhPanda scheme; FeatureTests stays default | ✓ |
| Add to FeatureTests plan | UI tests join the single existing plan, run on every full test invocation | |
| Separate scheme | Dedicated UI-testing scheme | |

**User's choice:** Second test plan on the same scheme.
**Notes:** User first asked to verify the existing setup — confirmed one shared scheme (EhPanda) with exactly one test plan (FeatureTests.xctestplan, all 18 unit targets) — before deciding.

| Option | Description | Selected |
|--------|-------------|----------|
| iPhone only | One iPhone simulator covers routing; iPad by owner UAT | |
| iPhone + iPad | Same tests on both idioms | |
| You decide | Planner picks from code-review findings | |

**User's choice:** Free-text — "Mainly iPhone. Plus iPad exclusive paths only": iPhone primary; iPad tested only where a code path is iPad-exclusive (e.g. presentGalleryDetail tab-modal entry).

**Area follow-up note (free text):** While closing this area the user pre-seeded route coverage wants: test opening a gallery link from the share extension and clipboard detection, and comment-view deep links — (1) fetch and open gallery detail, (2) locate to a specific row of the previews page. Item (2) was later superseded during the route-coverage discussion (reader landing kept).

---

## Test route coverage

**Clarification exchange (free text):** The user asked which file decides the page-link landing; traced live: CommentsReducer.handleCommentLink → GalleryNavigation (push) / PresentationFeature.handleGalleryLink (modal) → shared consumption at DetailReducer+Fetch.swift:58 (`.reading` → presentReading, `.comments` → pushComments). User then asked whether the detail→reader landing applied to all entries (yes — shared downstream).

| Option | Description | Selected |
|--------|-------------|----------|
| Keep everywhere | All entries keep detail → auto-reader at the linked page | ✓ (after clarifications) |
| Change everywhere: previews row | Land on detail with previews located at the linked row; no auto-reader | |
| Change everywhere: detail only | Stop at detail; progress still pre-seeds | |

**User's choice:** Free-text sequence — first "opening a gallery link should only open the detail page, not reader; this applies to all entries", then interrupted to clarify scope ("no exception in deep links" — non-deep-link navigation like the Downloads cell tap untouched), then "if the link carries a page number, it's okay to open the reader after opening the detail page". Net result: **keep today's routing everywhere** — /g/ stops at detail; /s/ opens detail then reader; deep links never skip detail. Criterion 1 parity holds; the previews-row idea is superseded.

| Option | Description | Selected |
|--------|-------------|----------|
| Keep | #c → detail → Comments scrolled to the linked comment, every entry | ✓ |
| Detail only | Fragment ignored | |

**User's choice:** Keep.

| Option | Description | Selected |
|--------|-------------|----------|
| E2E through share sheet | XCUITest drives Safari's share sheet, taps the EhPanda extension | ✓ |
| Split coverage | Unit-test the URL rewrite; scheme-open tests cover the in-app leg | |
| You decide | Planner weighs share-sheet reliability | |

**User's choice:** E2E through share sheet (flake risk acknowledged; planner budgets retries/waits).

| Option | Description | Selected |
|--------|-------------|----------|
| Full on scheme, smoke elsewhere | All 3 routes + malformed test via scheme (cold+warm); one representative test per other entry (~8 tests) | ✓ |
| Full matrix everywhere | Every route through every entry (~15–20 tests) | |
| Minimal smoke set | One test per entry | |

**User's choice:** Full on scheme, smoke elsewhere — chosen after requesting a plain-text comparison of options 1 and 2 (convergence on the shared consumption site makes the extra ~10 tests redundant; share-sheet tests are the flakiest surface).

---

## Parsing hardening depth

| Option | Description | Selected |
|--------|-------------|----------|
| Full URLComponents rebuild | Exact host matching, path-component routes, fragment-based #c, optional gallery-ID | ✓ |
| Targeted fixes only | Fix host check and empty-string ID; keep structure | |
| You decide | Code-review findings dictate depth | |

**User's choice:** Full URLComponents rebuild.

| Option | Description | Selected |
|--------|-------------|----------|
| Parity + www variants | e-hentai.org, exhentai.org, plus www. forms | ✓ |
| Strict parity | Exactly the two apex hosts | |
| You decide | Planner verifies served hosts | |

**User's choice:** Parity + www variants.

| Option | Description | Selected |
|--------|-------------|----------|
| Pure parser type | Replace the URLClient dependency with a pure value type per Phase 8 D-06 | ✓ |
| Keep injected client | Harden implementations, keep the seam | |
| You decide | Planner weighs call-site churn | |

**User's choice:** Pure parser type.

| Option | Description | Selected |
|--------|-------------|----------|
| Root-fix nav wait; toast gap discretionary | Deterministic coordination for the 1000ms wait; 500ms gap planner-decided | |
| Root-fix both | Deterministic replacements for both sleeps | ✓ |
| Keep both, document | Accepted pragmatism with comments | |

**User's choice:** Root-fix both.

---

## Claude's Discretion

- Stub-seam mechanism for hermetic UI tests (launch-environment dependency swap) and fixture gallery content.
- Deterministic-coordination mechanism replacing each of the two sleeps.
- Pure parser type's name and module home.
- Accessibility identifiers / assertion hooks the UI tests need on destination screens.
- ErrorInfo context rows carried by the new AppError case.

## Deferred Ideas

- Universal links (associated domains) — new capability, future phase.
- MPV (`/mpv/`) URLs as an openable deep-link route — new capability, future phase.
