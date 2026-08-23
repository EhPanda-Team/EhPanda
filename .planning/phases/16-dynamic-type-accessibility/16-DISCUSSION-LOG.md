# Phase 16: Dynamic Type Accessibility - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-23
**Phase:** 16-dynamic-type-accessibility
**Areas discussed:** Agent/human handoff shape, Verification surface + auth screens, Type-ramp sample points, Screen inventory boundary, The five known AX5 edge cases, minimumScaleFactor residue, Regression protection, Evidence artifacts + content privacy

---

## Agent/human handoff shape

| Option | Description | Selected |
|--------|-------------|----------|
| Audit → you fix all → one final pass | Agent produces one complete findings work order up front; owner fixes everything; agent runs a single end-to-end verification pass | |
| Per-finding loop (recommended) | Agent audits, owner fixes one finding, agent re-verifies that screen, repeat to zero | |
| Per-screen batches | Findings grouped by host screen; owner fixes a screen, agent re-verifies that screen | |
| *(free text)* | Owner rejected the premise: he hunts the findings down himself; the agent's job is the verification sweep only | ✓ |

**User's choice:** free text — "i will hunt down them myself. the verify part is you max out the font size (ax6), open every screens, scroll down to the bottom and make sure there is no degraded interface anywhere."

**Notes:** This removed the agent-produced work order entirely. Three follow-ups were raised as plain text: (1) iOS tops out at AX5, not AX6 — confirmed "yes ax5"; (2) whether max-only replaces Phase 10's D-03 three-point sample — answered "no, keep that three sizes"; (3) what counts as degraded — answered "degraded means the interface provides less information under larger font size setting. removing decoration to save space is okay, but the interface should always provide same contents." Reporting cadence answered in the same turn: "when you find one, record and move on, report when you finished scanning every pages."

---

## Verdict rule — truncation baseline

| Option | Description | Selected |
|--------|-------------|----------|
| Strict: any new truncation is a finding (recommended) | Anything reading in full at `.large` but truncating at XXL/AX3/AX5 is recorded, primary or secondary. Supersedes Phase 10's secondary-text exemption | ✓ |
| Reachable-elsewhere exemption | Truncation acceptable when the same value is fully readable on a screen reachable from there | |
| Keep Phase 10's rule | Secondary text may truncate at any size; only essential/primary text counts | |

**User's choice:** Strict.
**Notes:** Puts roughly 20 `lineLimit(1)` sites that 10-10 waved through back in scope.

---

## Verification surface

| Option | Description | Selected |
|--------|-------------|----------|
| Simulator (recommended) | `simctl ui booted content_size` for scriptable size switching; `EHPANDA_AUTOMATION_*` available for a logged-in session; no passcode friction | ✓ |
| Physical test iPhone | Matches Phase 15 precedent; costs manual Settings navigation per size change and a passcode per runner launch | |
| Simulator sweep, device confirmation | Full sweep on simulator, then re-walk only findings on real hardware | |

**User's choice:** Simulator.

---

## Authenticated content

| Option | Description | Selected |
|--------|-------------|----------|
| Owner logs in once, by hand (recommended) | Session left in one dedicated simulator's data container; agent never touches a credential | ✓ |
| `EHPANDA_AUTOMATION_*` env injection | Cookie values passed at launch through the existing seam; reproducible from cold, but the values pass through the agent | |
| Unauthenticated where possible, owner drives the rest | Zero exposure, but the sweep stops being one continuous pass | |

**User's choice:** Hand-login.
**Notes:** The env-injection seam exists and works; it was rejected on credential-exposure grounds, not on capability. Recorded in CONTEXT.md so it is not re-proposed as a convenience.

---

## Device / orientation matrix

| Option | Description | Selected |
|--------|-------------|----------|
| iPhone portrait only | ~20 screens × 3 sizes; leaves iPad and all landscape unverified | |
| iPhone + iPad, portrait (recommended) | Adds iPad regular width, where `isRegularWidthPad` routes to different layouts | |
| iPhone + iPad, both orientations | Full matrix; landscape at AX5 is the harshest case | ✓ |
| iPhone both orientations, iPad portrait | Prioritizes iPhone landscape over low-risk iPad landscape | |

**User's choice:** Full matrix — 12 passes over every screen.

---

## Type-ramp sample points

| Option | Description | Selected |
|--------|-------------|----------|
| Large end only — the three sizes stand (recommended) | XXL / AX3 / AX5 and nothing else | ✓ |
| Add xSmall as a fourth size | Catches fixed frames leaving dead space when text shrinks | |
| Add Bold Text at AX5 | Wider glyphs at the same size class can tip a barely-fitting label into truncation | |

**User's choice:** Large end only.

---

## Screen inventory boundary

| Option | Description | Selected |
|--------|-------------|----------|
| App screens + sheets (baseline) | Every SwiftUI screen, incl. modals, sheets, popovers, alerts, toasts, error surface | ✓ |
| WebView-rendered screens | EhSetting web pages + Cloudflare challenge surface — the native chrome around them | |
| ShareExtension | 86 lines, no visible SwiftUI text of its own | |
| System-provided UI | `BGContinuedProcessingTask` card, iOS share sheet, photo picker | |

**User's choice:** Baseline only (multi-select; the other three left unselected).
**Notes:** Re-deriving the inventory against today's tree was treated as obviously necessary rather than offered as a choice — Phase 10's table predates Phases 11–15.

---

## The five known AX5 edge cases

| Option | Description | Selected |
|--------|-------------|----------|
| Fold into the sweep (recommended) | No special status; judged by the same rule as everything else | |
| Pre-register as named items | Five named entries with explicit per-case disposition, so criterion 4 ticks off item by item | ✓ |
| Rule on them now, before the sweep | Owner decides each up front, from memory of Phase 10 | |

**User's choice:** Pre-register as named items.

---

## minimumScaleFactor residue

| Option | Description | Selected |
|--------|-------------|----------|
| Report where it visibly engages (recommended) | Evidence-driven: a finding only where the shrink actually does work at AX5 | |
| All five are findings | Follows Phase 10's D-02 literally — shrink is a cap in disguise | |
| Grandfathered — out of scope | Shrink preserves information, so it passes the owner's rule | |
| *(free text)* | Ban the API outright | ✓ |

**User's choice:** free text — "ban minimumScaleFactor."
**Notes:** Stronger than any option offered. Merged this area into Regression Protection, since a ban *is* the protection mechanism. Three plain-text follow-ups were then put to the owner and answered in one line — "you write the swiftlint rule, parity wins, wire it automatically":
- Who writes the lint rule, given "agent verify-only" → the agent writes it (config, not reflow logic).
- Whether the ban may break default-`.large` parity at sites where the shrink already engages there → **parity wins**; the replacing reflow must preserve default appearance.
- Whether the grep battery becomes automatic or stays a documented manual check → automatic.

---

## Regression protection — `dynamicTypeSize` rule scoping

| Option | Description | Selected |
|--------|-------------|----------|
| Ban the modifier, allow the read (recommended) | `.dynamicTypeSize(` as a modifier is an error; `@Environment(\.dynamicTypeSize)` stays available as a reflow tool | ✓ |
| Ban both, unblock by exception | Blanket match; reads go through the Phase 11 `// reason:` exception protocol | |
| Ban both, no reads at all | Reflow must come from `ViewThatFits` / wrapping / `@ScaledMetric` alone | |

**User's choice:** free text "allow dynamicTypeSize", which was ambiguous between *no rule at all* and *ban the modifier only*. Disambiguated as plain text — options (a) no rule and (b) ban the cap, allow the read. Owner answered "**b**".
**Notes:** The flaw was raised before writing the rule: a blanket regex would block the owner's own reflow work, since branching on the environment read is how a row becomes a VStack at AX sizes.

---

## Evidence artifacts + content privacy

| Option | Description | Selected |
|--------|-------------|----------|
| Text-only in repo; images stay out (recommended) | Verdict table committed; screenshots in scratchpad only, surfaced on request | |
| Text in repo, images sent per finding | Same artifact, but every finding's before/after is actively sent to the owner in chat | ✓ |
| Commit screenshots of content-free screens only | Mixed rule; a misjudgment is permanent in git history | |

**User's choice:** Text in repo, images sent per finding.
**Notes:** Driven by the repo being public and the sweep screenshotting real adult gallery content at AX5.

---

## Requirement ID

| Option | Description | Selected |
|--------|-------------|----------|
| `A11Y-01` (recommended) | New category; Dynamic Type is the last untouched accessibility axis | ✓ |
| `POLISH-04` | Extends the existing group where the Phase 10 foundation was booked | |
| You decide | Agent picks once the requirement text is written | |

**User's choice:** `A11Y-01`.

---

## Claude's Discretion

- The shape of the re-derived screen inventory and how a "screen" is counted for the 12-pass matrix.
- How a finding is re-verified after the owner fixes it (per-screen re-walk vs. batched re-sweep), and whether the sweep is resumable across sessions. Surfaced at the closing check and deliberately left to the planner.
- The wording of the `A11Y-01` requirement text and its acceptance bullet.
- The precise regex form of each of the four SwiftLint rules, subject to the modifier-only and numeric-literal-only constraints.

## Deferred Ideas

- **`xSmall` and Bold Text passes** — declined for this phase; both catch real but different failures. Candidates for a future accessibility phase.
- **WebView chrome at AX5** — the native nav bar / toolbar / dismiss chrome around EhSetting web pages and the Cloudflare challenge surface is ours and can still break, even though WebKit owns the text inside.
- **ShareExtension and system-provided UI** — excluded; the only thing worth checking there is whether the strings handed to Apple's UI break, which is not layout work.
