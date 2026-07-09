# Phase 1: Isolated Dependency Modernization - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-10T00:49:22+09:00
**Phase:** 1-Isolated Dependency Modernization
**Areas discussed:** Fork/local-module strategy, Markdown migration shape, DeprecatedAPI removal boundary, Color/visual parity expectations

---

## Fork/local-module strategy

| Question | Options Presented | User's choice |
|----------|-------------------|---------------|
| How tightly should `SwiftyOpenCC` and `UIImageColors` preserve current APIs? | API-compatible fork; Wrapper allowed; You decide | App-fit APIs. Change APIs if that maximizes EhPanda; keep current shape only if best-fit. |
| How should EhPanda consume the modernized code? | External fork repos with tags; Local packages inside this repo; You decide | Consume as app-owned local modules inside this repo. |
| What quality bar should the local consumed code meet? | Full project bar; Focused modernization; You decide | Full project bar. |
| How should planning treat local module shape? | Clean-room local modules; Vendored upstream shape; You decide per dependency | Clean-room local modules. |
| What naming convention applies? | Freeform clarification | Use original package names for consumed local modules; reserve `*Ext` for extensions of real external packages. |

**Notes:** The modernization target includes the formerly external code itself: latest Swift/tooling, latest APIs, bug fixes, removed restrictions, tests/lint/docs where practical, and parity evidence. `SystemNotificationExt` should eventually be renamed to `SystemNotification`, but that cleanup is deferred unless coupled.

---

## Markdown migration shape

| Question | Options Presented | User's choice |
|----------|-------------------|---------------|
| What should be the migration goal for tag translation markdown parsing? | Bug-compatible parity; Best-fit behavior with fixture lock; You decide | Best-fit behavior with fixture lock. |
| How should `DetailView`'s direct `CommonMark` import be handled? | Eliminate direct dependency; Keep direct render usage; You decide | Eliminate direct dependency. |
| What should the local markdown module be called? | Markdown; MarkdownClient; Keep `CommonMarkExt` temporarily | Use external `Markdown`; helper/extensions should be `MarkdownExt` if needed. |
| What parity evidence is required? | Focused fixtures; Fixture + UI smoke; Broader snapshot coverage | Focused fixtures for `parseTexts`, `parseLinks`, and `parseImages`. |

**Notes:** The user linked `swift-markdown`'s `Package.swift`; the external product/target is `Markdown`, so an app-owned module named `Markdown` would conflict.

---

## DeprecatedAPI removal boundary

| Question | Options Presented | User's choice |
|----------|-------------------|---------------|
| How much change is allowed around the DF stream path? | Narrow replacement first; Modernize DF internals; Full rethink if needed | Rethink freely, but preserve domain fronting. Skip if current deprecated API is the only viable path. |
| What evidence is acceptable before skipping? | Documented technical proof; Build/runtime blocker proof; You decide | Mixture of documented technical proof and technical request verification. |
| What behavior is non-negotiable? | Current request semantics; Only SNI/Host split; You decide | Current request semantics. |
| How should risk be managed if a replacement exists? | Seam + parity tests; Direct replacement; Feature flag fallback | Direct replacement; user will find testers in China. |

**Notes:** Domain fronting is used to bypass SNI filtering. Local E2E testing is not possible without relevant network conditions, so technical verification must be honest about what it does and does not prove.

---

## Color/visual parity expectations

| Question | Options Presented | User's choice |
|----------|-------------------|---------------|
| How exact should `UIImageColors` output parity be? | Perceptual parity; Algorithm parity; Best-fit redesign | Preserve the package's existing behavior; only refactor tech stack/latest APIs. |
| How strict should latest `Colorful` animation/background parity be? | Behavior/appearance parity; Minor polish allowed; You decide | Minor polish allowed. |
| What evidence is required? | Sample image fixtures + visual smoke; Fixture-only; Snapshot-heavy | Leave final visual verification to user verification. |
| How should automated coverage be phrased? | Technical tests only; No automated tests; You decide | Technical tests only where deterministic. |

**Notes:** Visual judgment is a human verification task; automated tests should cover deterministic technical behavior only.

---

## the agent's Discretion

- Keep current API shapes where they are already best-fit for EhPanda.
- Skip `DeprecatedAPI` removal if research shows domain fronting cannot be preserved.
- Choose deterministic technical tests for visual/color work where useful.

## Deferred Ideas

- Rename `SystemNotificationExt` to `SystemNotification` outside Phase 1 unless directly coupled.
