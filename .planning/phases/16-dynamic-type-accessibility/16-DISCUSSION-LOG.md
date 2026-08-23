# Phase 16: Accessibility (Dynamic Type + Assistive Technology) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-23
**Phase:** 16-dynamic-type-accessibility
**Areas discussed (round 1 — Dynamic Type):** Agent/human handoff shape, Verification surface + auth screens, Type-ramp sample points, Screen inventory boundary, The five known AX5 edge cases, minimumScaleFactor residue, Regression protection, Evidence artifacts + content privacy
**Areas discussed (round 2 — assistive technology, added mid-discussion):** Round-2 work split, Round ordering, Target bar, Category colours & contrast, Reduce Motion scope, Verification method, Voice Control across locales, Nutrition Label gap policy, Dynamic Type re-check

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

---
---

# Round 2 — Assistive Technology (added mid-discussion)

> The owner interrupted before `/gsd-plan-phase` to add a second round to Phase 16:
> "add supports for voiceover, voice control, reduced motion, sufficient contrast,
> differentiate without color alone." This required rewriting ROADMAP.md Phase 16 and
> adding an `A11Y` section to REQUIREMENTS.md, both approved before the edits were made.

## Round-2 work split

| Option | Description | Selected |
|--------|-------------|----------|
| Agent implements round 2 (recommended) | Label/input-label/motion-gating work is high-volume and mechanical with no visual judgment call | ✓ |
| Same split — owner implements, agent verifies | Consistent with round 1; ~150 label sites by hand | |
| Split by axis | Agent does mechanical axes, owner does judgment ones | |

**User's choice:** Agent implements — "option 1, but please note that Sufficient Contrast and Differentiate w/o color might have already been implemented."
**Notes:** Turned those two axes audit-first (D-20). The baseline scan agreed: `DownloadBadgeLabel` already varies its symbol by status, and category badges already carry the category name as text.

---

## Round ordering

| Option | Description | Selected |
|--------|-------------|----------|
| Round 2 first, then Dynamic Type (recommended) | DT sweep runs once against final text and layout | |
| Dynamic Type first, then round 2 | Closes criterion 5's long-outstanding gate sooner; risks staleness | ✓ |
| Interleaved per screen | Nothing goes stale; loses batched size-switching | |

**User's choice:** Dynamic Type first.
**Notes:** Staleness surface turned out narrow — accessibility labels aren't rendered and the eventual colour fix moves no layout, so only a newly added glyph can invalidate anything. Closed by D-25's targeted re-sweep.

---

## Target bar

| Option | Description | Selected |
|--------|-------------|----------|
| App Store Accessibility Nutrition Label (recommended) | Apple's pass/fail criteria; every common task, not just the main screen; shippable App Store artifact | ✓ |
| WCAG 2.2 Level AA | Precise numeric thresholds; not what Apple checks | |
| Per-axis checklists we define | Most control; no external authority | |

**User's choice:** Nutrition Label.

---

## Category colours and contrast

| Option | Description | Selected |
|--------|-------------|----------|
| High-contrast variant behind Increase Contrast (recommended) | Brand colour untouched by default; compliant variant only under `.increased` | |
| Fix the colours outright | Compliant for everyone; collides with the no-redesign constraint | |
| Report only — owner rules per colour | No change without an explicit call | |
| *(free text)* | "always keep them as-is" | ✓ *(later reversed)* |

**User's first choice:** freeze all colours.
**Then measured:** 45 of 84 variants below 4.5:1, and — the finding that changed the conversation — the colorsets already ship `contrast: high` variants that make contrast *worse* (E-Hentai Manga 2.56 → 1.79 with Increase Contrast on).
**Follow-up asked:** whether the freeze covered the Increase Contrast entries too, and what happens to an unclaimable Nutrition Label category. **Owner dismissed both questions**, then returned with: *"alright, do what you think it's necessary to do with the colors, including category colors."*
**Resolution (agent's call under delegation):** D-26 — freeze all 84 backgrounds byte-identical, make the badge *text* colour adaptive black/white on resolved background luminance. Verified 84/84 pass AA, worst case 4.62:1, structural floor 4.58:1 for any possible colour. 47 badges flip to black text.

---

## Reduce Motion scope

| Option | Description | Selected |
|--------|-------------|----------|
| Meaningful motion only (recommended) | Gate springs/slides/scale/transitions; leave subtle crossfades and numeric-text transitions | ✓ |
| Gate everything that animates | All ~107 sites; easiest to grep-verify; flattens motion Apple never targeted | |
| Classify all 107 sites first | Most rigorous; adds an audit pass before any code | |

**User's choice:** Meaningful motion only.

---

## Verification method (round 2)

| Option | Description | Selected |
|--------|-------------|----------|
| Automated audit + manual walkthrough (recommended) | `performAccessibilityAudit()` on the Phase 13 `UITests` plan, plus a manual VoiceOver/Voice Control pass | ✓ |
| Manual walkthrough only | No new test code; no regression guard | |
| Automated only | Repeatable gate; can't judge label sense or focus order | |

**User's choice:** Both.

---

## Voice Control across locales

| Option | Description | Selected |
|--------|-------------|----------|
| Verify in English, rely on the catalog (recommended) | Labels share `LocalizedStringResource` keys with visible text, so matching is structural; add a no-hardcoded-label check | ✓ |
| Verify all six locales | Catches translator wording drift; 6× the pass | |
| English plus one CJK locale | Highest-value second sample | |

**User's choice:** English plus the structural guard.

---

## Nutrition Label gap policy

| Option | Description | Selected |
|--------|-------------|----------|
| Record as an accepted gap (recommended) | Documented tradeoff; the rest still get claimed | |
| Come back to me with the numbers | Treat an unclaimable category as a trigger to reopen the blocking decision | ✓ |
| All six or the phase isn't done | A single blocker holds the phase open | |

**User's choice:** Come back with the numbers.
**Notes:** Asked once earlier and dismissed; re-put after the colour decision made the situation less likely.

---

## Dynamic Type re-check after round 2

| Option | Description | Selected |
|--------|-------------|----------|
| Targeted re-sweep of touched screens (recommended) | Re-walk only screens where round 2 adds a visible element | ✓ |
| Keep round 2 layout-neutral by construction | Nothing to re-check; constrains how non-colour work is solved | |
| Full 12-pass re-sweep | Airtight; doubles round 1's largest cost | |

**User's choice:** Targeted re-sweep.

---

## ROADMAP / REQUIREMENTS edits

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — update both (recommended) | Rewrite Phase 16 goal/criteria/mode; add A11Y-01 and A11Y-02 | ✓ |
| CONTEXT.md only for now | Planner reconciles later; ROADMAP stays wrong meanwhile | |
| Show me a draft first | Proposal in chat before writing | |

**User's choice:** Update both.
**Result:** ROADMAP Phase 16 rewritten (title, goal, per-round implementation mode, target bar, 12 success criteria, accessibility baseline); REQUIREMENTS gained an `A11Y` section with A11Y-01/A11Y-02 and two traceability rows; coverage 23/23 → 25/25.
