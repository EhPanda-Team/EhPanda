# Phase 16: Dynamic Type Accessibility - Context

**Gathered:** 2026-08-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Prove — and get the owner's signature on — full-range Dynamic Type readability **and
operability** across every user-facing app screen, on top of the font-scaling + reflow
foundation Phase 10 delivered in plans 10-10 / 10-11.

**This phase is human-implemented; the agent verifies.** The owner hunts down and fixes
every breakage himself. The agent's deliverable is the *verification sweep* plus its
findings report, not reflow code. **Do not spawn executor agents for reflow work.**

There is exactly one carve-out from verify-only, granted in this discussion: **the agent
writes the four SwiftLint custom rules** that lock the foundation in (D-11). Those are lint
configuration, not layout logic.

**What "verify" concretely means (owner's own words):** set the font size to the maximum,
open every screen, scroll each one to the bottom, and confirm no interface is degraded.
Sampled at three sizes rather than only the max (D-03).

The phase closes when the sweep reports zero open findings, the four lint rules are green
at error, and the owner signs the on-device/simulator UAT.

</domain>

<decisions>
## Implementation Decisions

### Work split (agent vs. owner)

- **D-01: The owner finds and fixes; the agent verifies.** The agent produces no reflow
  work order for the owner to execute against, and writes no reflow code. It runs the
  sweep, records findings, and re-verifies. The one exception is D-11's lint rules.
- **D-02: Scanning protocol = record and move on.** The agent does not interrupt the sweep
  to raise each finding as it lands. It records the finding, continues to the next screen,
  and reports the complete list once every page has been scanned.

### The verdict rule — what "degraded" means

- **D-03: Degraded = the interface provides *less information* at a larger font size.**
  This is the owner's rule verbatim and it is the sole verdict basis. Removing decoration
  to save space is acceptable; the interface must always provide the same *contents*.
  - **Fine:** a label wrapping to 2–3 lines; a row growing taller so fewer fit per screen;
    decorative chrome (icons, dividers, ornament) dropped to make room.
  - **Degraded:** essential or secondary text clipped, cut off, or ellipsised; content
    overlapping; a control pushed off-screen or made unreachable; a value abbreviated away.
- **D-04: Strict truncation reading — this supersedes Phase 10's secondary-text exemption.**
  Any value that reads in full at `.large` but truncates at XXL / AX3 / AX5 is a finding,
  regardless of whether the field is primary or secondary and regardless of whether the
  full value is reachable on another screen. Phase 10's 10-10 audit waved through roughly
  20 `lineLimit(1)` sites (uploader, date, page count, category token) on exactly the
  exemption this decision removes — **those sites are back in scope and must be re-judged
  against D-03, not inherited as "fine."**

### Sample points on the type ramp

- **D-05: Three sizes — XXL / AX3 / AX5.** Phase 10's D-03 sample stands unchanged; the
  owner explicitly declined narrowing to max-only.
- **D-06: AX5 is the maximum.** iOS's Larger Text slider has 12 positions (7 standard + 5
  accessibility) and SwiftUI's `DynamicTypeSize` ends at `.accessibility5`. There is no
  AX6; "max out the font size" resolves to AX5.
- **D-07: Large end only.** No `xSmall` pass, no Bold Text pass. The rule is about
  information lost when text *grows*.

### Verification surface

- **D-08: Simulator, not the physical device.** Both variables are scriptable there:
  `xcrun simctl ui booted content_size …` switches the type size without driving the
  Settings UI, which makes a 12-pass matrix tractable and repeatable.
- **D-09: The owner logs in by hand, once, on a dedicated simulator.** He signs in through
  the app's `WKWebView` login and leaves the session in that simulator's data container;
  the agent boots it and drives. **The agent never handles a credential** — no cookie value
  passes through a prompt, an env file, shell history, or any artifact. This is what
  unblocks the account-gated screens (Detail, Comments, Archives, Torrents, Reading,
  Favorites) that Phase 10's static audit could not reach.
  - Consequence to plan around: erasing or resetting that simulator loses the session and
    needs the owner again. Treat the logged-in simulator as phase infrastructure.
  - The `EHPANDA_AUTOMATION_IPB_MEMBER_ID` / `IPB_PASS_HASH` / `IGNEOUS` launch seam exists
    and would also work, but was **rejected** on credential-exposure grounds.
- **D-10: Matrix = iPhone + iPad × portrait + landscape × 3 sizes.** Twelve passes over
  every screen. iPad is not a re-run of iPhone: `isRegularWidthPad` routes detail and
  setting surfaces to different layouts entirely (Phase 5), so its AX5 failure modes are
  genuinely different. Landscape at AX5 is the harshest case — least vertical space, most
  reflow pressure.

### Scope of the sweep

- **D-11: App screens and sheets only.** Every SwiftUI screen EhPanda draws, including
  modals, sheets, popovers, alerts, toasts, and the error surface. **Explicitly excluded:**
  WebView-rendered screens (EhSetting web pages, the Cloudflare challenge surface — Phase 10
  already ruled WebKit's own text sizing out of remediation scope), the ShareExtension, and
  system-provided UI (the `BGContinuedProcessingTask` progress card, the iOS share sheet,
  the photo picker).
- **D-12: The screen inventory is re-derived against today's tree, not inherited.** Phase
  10's per-screen table (10-10-SUMMARY.md § "Per-screen coverage") predates Phases 11–15 —
  the Cloudflare login surface, the analytics opt-out row in General Settings, and the
  Phase 15 download changes all landed after it. Use it as a starting checklist, not as the
  inventory.

### The five known AX5 edge cases

- **D-13: Pre-registered as named items with an explicit per-case disposition.** The five
  from ROADMAP criterion 4 — Detail stats-strip abbreviation, long-tag right-edge clip in
  the tag cloud, reader total-page counter wrap, Favorites trailing-glyph clip, hero-carousel
  title truncation — are carried as named entries in the findings report, each closing as
  **fixed** or **explicitly accepted (with the owner's reason recorded)**. They are tracked
  alongside, not merged into, the sweep's own findings, so criterion 4 can be ticked off
  item by item and none is silently dropped.
  - Note: under D-03 a wrap is *not* degradation, so "reader total-page counter wrap" may
    well close as accepted on the rule alone. That still gets recorded as a disposition.

### `minimumScaleFactor` and default-size parity

- **D-14: `minimumScaleFactor` is banned outright.** Not judged case by case, not
  grandfathered. All 5 surviving sites are removed and the target count is **0**, enforced
  by D-16's lint rule. Current sites: `GalleryListComponents/Cells/GalleryDetailCell.swift`
  (2), `DetailFeature/DetailView+CommentCells.swift`, `DetailFeature/DetailView+HeaderSection.swift`
  (0.72), `DetailFeature/Comments/CommentsView.swift`.
- **D-15: Default-size (`.large`) parity outranks the ban.** Removing a shrink changes
  behavior at the default size wherever that shrink currently engages there — e.g. the 0.72
  factor on the Detail header's category label, which plausibly engages at default for a
  long category name. Where the ban and parity collide, **parity wins**: the replacing
  reflow must preserve default-size appearance. The agent verifies both halves — no
  information loss at XXL/AX3/AX5 *and* no visible change at `.large`.

### Regression protection (the agent's one implementation carve-out)

- **D-16: Four error-level SwiftLint custom rules, written by the agent, wired into
  `.swiftlint.yml`.** The build-tool plugin runs them on every build, so enforcement is
  automatic — no separate script, no CI job. All four currently read clean, so each lands
  at zero violations:

  | Rule | Bans | Current count |
  |---|---|---|
  | `minimumScaleFactor` | any use (D-14) | 5 → must reach 0 |
  | `.dynamicTypeSize(` as a **view modifier** | caps and clamps (Phase 10 D-02) | 0 |
  | `GeometryReader` | any use (Phase 5 constraint) | 0 |
  | `.system(size: <numeric literal>)` | fixed-pixel fonts | 0 |

- **D-17: The `dynamicTypeSize` rule bans the modifier but allows the environment read.**
  `.dynamicTypeSize(…)` as a modifier is what "never cap" forbids; `@Environment(\.dynamicTypeSize)`
  is a *read* — how a view asks "am I at an accessibility size?" in order to switch an
  HStack to a VStack, which is exactly the reflow the owner will be writing. A blanket
  regex would block his own fixes. The rule must match the modifier form only.
- **D-18: The `.system(size:)` rule matches numeric literals only.** `@ScaledMetric`-fed
  forms such as `.font(.system(size: reloadSymbolSize))` are the Phase 10 pattern and stay
  legal; only `\.system\(size: [0-9]` is an error.
- **D-19: The Phase 11 exception protocol is the only escape hatch.** A `// reason:` comment
  plus `// swiftlint:disable:next`, owner-reviewed. Per AGENTS.md, suppressing or disabling
  a rule without the owner's explicit permission is forbidden.

### Evidence and artifacts

- **D-20: Text in the repo; screenshots never enter it.** EhPanda's repository is public and
  the sweep screenshots real adult gallery content at AX5. The committed artifact is a
  **verdict table** — screen × device × orientation × size, with a written description of
  each finding. Screenshots live in the session scratchpad only. **No screenshot is ever
  committed, not even of a screen judged content-free** — a mistake there is permanent in
  git history.
- **D-21: The agent actively sends the owner a before/after image per finding**, in chat,
  rather than only on request — so each finding can be judged visually without opening the
  simulator. Same zero-leak property; the images go to the owner, never to disk in the repo.
- **D-22: Requirement ID is `A11Y-01`, a new category in REQUIREMENTS.md.** Dynamic Type is
  the last untouched accessibility axis — VoiceOver labels and decorative-icon handling
  landed in Phases 5 and 7 — so a category named for the axis leaves room for future
  accessibility work rather than burying it under POLISH. ROADMAP's "Requirements: TBD" for
  Phase 16 is updated to `A11Y-01` during planning.

### Claude's Discretion

- The exact shape of the re-derived screen inventory (D-12) and how a "screen" is counted
  for the 12-pass matrix.
- How a finding is re-verified after the owner fixes it (per-screen re-walk vs. batched
  re-sweep), and whether the sweep runs in one sitting or is resumable across sessions.
  These were surfaced and deliberately left to the planner.
- The wording of the `A11Y-01` requirement text and its acceptance bullet.
- The precise regex form of each of the four SwiftLint rules, subject to D-17 and D-18.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Authoritative scope
- `.planning/ROADMAP.md` §"Phase 16: Dynamic Type Accessibility" — the 5 success criteria
  and the "human-implemented; agent verify-only" implementation mode. Criterion 4 names the
  five edge cases D-13 pre-registers.
- `.planning/ROADMAP.md` §"Phase 10: UI Polish" criterion 5 — where this work was carved
  out from, and the record of what the Phase 10 foundation did and did not deliver.
- `.planning/REQUIREMENTS.md` — currently has **no** entry for this phase; `A11Y-01` is
  added here per D-22. §"Out of Scope" carries the "any visual redesign" parity constraint.

### The Phase 10 foundation this phase verifies
- `.planning/phases/10-ui-polish/10-CONTEXT.md` §"Dynamic Type (criterion 5)" — D-01/D-02/D-03.
  **D-02 (reflow, never cap; no `dynamicTypeSize` cap anywhere) is absolute and carries
  forward unchanged.** D-03's XXL/AX3/AX5 sample carries forward as this phase's D-05.
- `.planning/phases/10-ui-polish/10-10-SUMMARY.md` — the whole-app audit: the 7 fixed-font
  conversions, the full 33-site `lineLimit(1)` verdict table, the 9-site fixed-height table,
  and the per-screen coverage table. **Read with D-04 in mind:** its "fine" verdicts for
  secondary-text truncation no longer hold.
- `.planning/phases/10-ui-polish/10-11-SUMMARY.md` — the B1–B10 reflow verdict table and the
  `@ScaledMetric(relativeTo:)`-for-fixed-frames pattern (literal == scaled at `.large`, so
  default parity is exact by construction). This is the reference pattern for D-15.
- `.planning/phases/10-ui-polish/10-UAT.md` test 7 — the D-03 device UAT recorded as
  `skipped`, deferred to this phase. This is the gate criterion 5 still owes.

### Project rules that constrain this phase
- `CLAUDE.md` (repo root, a.k.a. AGENTS.md) — the SwiftLint read-first rule and the
  no-suppression rule that D-19 depends on; the confirmation-dialog/alert placement rule
  (relevant wherever a reflow touches a dialog anchor).
- `.swiftlint.yml` (repo root) — where D-16's four custom rules land; read the existing
  custom regex rules first and match their shape.
- `.planning/phases/11-infra-refactor-lint-capstone/11-EXCEPTIONS.md` — the 8 approved
  repo-wide exceptions and the `// reason:` + `swiftlint:disable:next` protocol D-19 cites.
- `.planning/codebase/CONVENTIONS.md` — established SwiftUI/TCA conventions.

### Source landmarks
- The 5 `minimumScaleFactor` sites D-14 removes: `AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift:155,166`,
  `AppPackage/Sources/DetailFeature/DetailView+CommentCells.swift:42`,
  `AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift:73`,
  `AppPackage/Sources/DetailFeature/Comments/CommentsView.swift:165`.
- `AppPackage/Sources/AppLaunchAutomationClient/AppLaunchAutomation.swift` — the
  `EHPANDA_AUTOMATION_*` launch seam, including the three login-cookie keys. Documented
  because it is the obvious alternative to D-09 and was **rejected**; do not reintroduce it.

</canonical_refs>

<code_context>
## Existing Code Insights

### Foundation state (re-verified 2026-08-23, at branch `feature/gsd-phase-16`)

| Gate | Count | Note |
|---|---|---|
| `dynamicTypeSize` | 0 | no cap anywhere; D-17's rule lands at zero |
| `GeometryReader` | 0 | Phase 5 constraint holds |
| `.system(size: <literal>)` | 0 | all 7 Phase 10 conversions hold |
| `minimumScaleFactor` | 5 | down from 8; **D-14 drives this to 0** |
| `@ScaledMetric` | 8 | the reflow pattern to copy |
| `lineLimit(1)` | 31 | D-04 puts most of these back in scope |
| fixed `frame(height:)` | 5 | icons/touch-target chrome, per 10-10's verdict rule |

### Reusable assets
- **`sim-use` / iOS Simulator control** — the sweep driver. `xcrun simctl ui booted content_size`
  switches Dynamic Type without driving Settings, which is what makes 12 passes tractable.
- **`@ScaledMetric(relativeTo:)` pattern (8 live sites)** — the parity-exact way to relax a
  fixed metric: the literal equals the scaled value at `.large`, so default parity is exact
  by construction. This is the template for every D-15-constrained fix.
- **Existing custom SwiftLint regex rules in `.swiftlint.yml`** — 8 rules already live at
  error from Phase 11; D-16's four follow their established shape rather than inventing one.
- **Accessibility skills available** — `swift-accessibility-skill`, `swiftui-pro`,
  `pfw-modern-swiftui` should inform both the sweep's judgment and the lint-rule authoring.

### Established patterns
- **Adaptive layout landed in Phase 5:** size classes, `onGeometryChange`,
  `containerRelativeFrame`, `ViewThatFits`, no `GeometryReader`. Reflow builds on these;
  `ViewThatFits` and the `@Environment(\.dynamicTypeSize)` read (legal per D-17) are the
  two tools for "stack this row vertically at AX sizes."
- **VoiceOver labels and decorative-icon handling already landed** (Phases 5 & 7). Dynamic
  Type is the one remaining accessibility axis, which is why D-22 opens the `A11Y` category.
- **Parity discipline:** every prior phase in this milestone held appearance parity. D-15
  makes that explicit for the one place the ban collides with it.

### Integration points
- **Sequential `xcodebuild` only** — no overlapping invocations on this machine. Any
  build/test wave in the plan must serialize.
- **The logged-in simulator is phase infrastructure** (D-09) — plans must not assume a
  clean simulator, and must not erase or reset it.
- **`.swiftlint.yml` is a build-tool plugin at error severity** — landing D-16's rules with
  any surviving violation breaks the build for everyone, so the `minimumScaleFactor` removal
  (D-14, owner-implemented) must precede or accompany its rule.

</code_context>

<specifics>
## Specific Ideas

- **The verdict rule is the owner's, in his words:** "degraded means the interface provides
  less information under larger font size setting. removing decoration to save space is
  okay, but the interface should always provide same contents." Every judgment call in the
  sweep resolves against that sentence, not against a generic accessibility checklist.
- **The sweep procedure is equally literal:** max out the font size, open every screen,
  **scroll down to the bottom**, confirm nothing is degraded. The scroll-to-bottom is not
  incidental — a screen that looks fine above the fold is not verified.
- **Credentials never touch the agent.** The owner chose hand-login specifically over the
  available env-injection seam. Do not propose the seam again as a convenience.
- **No screenshot reaches the repo, ever** — including screens that look content-free. The
  repository is public and git history is permanent.
- **`minimumScaleFactor` is banned, not managed.** The owner's answer was "ban
  minimumScaleFactor," which is stronger than the case-by-case option offered. Target 0.

</specifics>

<deferred>
## Deferred Ideas

- **Small-end and Bold Text passes** (`xSmall`; Accessibility › Bold Text at AX5) —
  considered and declined for this phase (D-07). Both catch real but different failures:
  `xSmall` catches fixed frames leaving dead space when text shrinks; Bold Text widens
  glyphs without changing the size class, so labels that barely fit at AX5 can tip into
  truncation. Worth revisiting if a future accessibility phase opens.
- **WebView chrome at AX5** — the native nav bar / toolbar / dismiss chrome around the
  EhSetting web pages and the Cloudflare challenge surface is ours and can still break, even
  though WebKit owns the text inside. Excluded from this sweep by D-11; a candidate for a
  later pass.
- **ShareExtension and system-provided UI** — excluded by D-11. The extension is 86 lines
  with no visible SwiftUI text, and the `BGContinuedProcessingTask` card / share sheet /
  photo picker are Apple-rendered. The only thing ever worth checking there is whether the
  strings we hand them break, which is not layout work.

</deferred>

---

*Phase: 16-dynamic-type-accessibility*
*Context gathered: 2026-08-23*
