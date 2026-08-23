# Phase 16: Accessibility (Dynamic Type + Assistive Technology) - Context

**Gathered:** 2026-08-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Make EhPanda accessible across **six of the nine App Store Accessibility Nutrition Label
categories**, in two sequential rounds against the settled UI.

**Round 1 — Dynamic Type.** Complete full-range readability and operability (AX1–AX5) on the
font-scaling + reflow foundation Phase 10 delivered in plans 10-10 / 10-11, and close the
owner-signed device gate that criterion 5 has owed since Phase 10. Requirement **A11Y-01**.

**Round 2 — assistive technology.** Systematic support for **VoiceOver, Voice Control,
Reduced Motion, Sufficient Contrast, and Differentiate Without Color**. Requirement **A11Y-02**.

**Round 1 runs first** (D-23), so round 2 lands against settled layout. The staleness window
this opens is narrow and is closed by a targeted re-sweep (D-25).

**The implementation split differs by round** — this is the single most important thing for a
planner to get right:

| | Who implements | Who verifies |
|---|---|---|
| **Round 1** | The **owner**, by hand. Do not spawn executor agents for reflow work. | Agent |
| Round 1 carve-out | **Agent** writes the four SwiftLint rules (D-16) — lint config, not layout logic | Agent |
| **Round 2** | **Agent**, owner-reviewed | Agent + owner sign-off |
| Round 2 caveat | Sufficient Contrast and Differentiate Without Color are **audit-first** — measure before building (D-20) | — |

**Target bar (D-19):** the App Store Accessibility Nutrition Label pass/fail criteria, which
require every *common user task* to work, not just the main screen. Dark Interface is expected
to already pass; Captions and Audio Descriptions are not applicable (no video). The phase closes
with a Nutrition Label recommendation naming which categories are claimable.

</domain>

<decisions>
## Implementation Decisions

---

## Round 1 — Dynamic Type (A11Y-01)

### Work split

- **D-01: The owner finds and fixes; the agent verifies.** The agent produces no reflow work
  order for the owner to execute against, and writes no reflow code. It runs the sweep, records
  findings, and re-verifies. The one exception is D-16's lint rules.
  - **Amendment (owner, in chat, 2026-08-24):** the owner still writes every reflow fix by
    hand, but asked the agent to *also* (a) extract a name-free catalogue of large-font reflow
    patterns from a reference project's history, and (b) after the sweep, propose which pattern
    applies to which finding, with the finding's before-screenshot sent in chat. A proposal is
    prose + pattern id, never a diff or patch. The sweep plans (16-04 … 16-09) run as written;
    plan 16-10's report gains a per-finding "Suggested pattern" column.
- **D-02: Scanning protocol = record and move on.** The agent does not interrupt the sweep to
  raise each finding as it lands. It records the finding, continues to the next screen, and
  reports the complete list once every page has been scanned.

### The verdict rule — what "degraded" means

- **D-03: Degraded = the interface provides less information at a larger font size.** The
  owner's rule verbatim, and the sole verdict basis. Removing decoration to save space is
  acceptable; the interface must always provide the same *contents*.
  - **Fine:** a label wrapping to 2–3 lines; a row growing taller so fewer fit per screen;
    decorative chrome (icons, dividers, ornament) dropped to make room.
  - **Degraded:** essential or secondary text clipped, cut off, or ellipsised; content
    overlapping; a control pushed off-screen or unreachable; a value abbreviated away.
- **D-04: Strict truncation reading — this supersedes Phase 10's secondary-text exemption.**
  Any value that reads in full at `.large` but truncates at XXL / AX3 / AX5 is a finding,
  regardless of whether the field is primary or secondary and regardless of whether the full
  value is reachable on another screen. Phase 10's 10-10 audit waved through roughly 20
  `lineLimit(1)` sites (uploader, date, page count, category token) on exactly the exemption
  this decision removes — **those sites are back in scope and must be re-judged against D-03,
  not inherited as "fine."**

### Sample points on the type ramp

- **D-05: Three sizes — XXL / AX3 / AX5.** Phase 10's D-03 sample stands unchanged; the owner
  explicitly declined narrowing to max-only.
- **D-06: AX5 is the maximum.** iOS's Larger Text slider has 12 positions (7 standard + 5
  accessibility) and SwiftUI's `DynamicTypeSize` ends at `.accessibility5`. There is no AX6;
  "max out the font size" resolves to AX5.
- **D-07: Large end only.** No `xSmall` pass, no Bold Text pass. The rule is about information
  lost when text *grows*.

### Verification surface

- **D-08: Simulator, not the physical device.** Both variables are scriptable there:
  `xcrun simctl ui booted content_size …` switches the type size without driving the Settings
  UI, which makes a 12-pass matrix tractable and repeatable.
- **D-09: The owner logs in by hand, once, on a dedicated simulator.** He signs in through the
  app's `WKWebView` login and leaves the session in that simulator's data container; the agent
  boots it and drives. **The agent never handles a credential** — no cookie value passes through
  a prompt, an env file, shell history, or any artifact. This is what unblocks the account-gated
  screens (Detail, Comments, Archives, Torrents, Reading, Favorites) that Phase 10's static audit
  could not reach.
  - Consequence to plan around: erasing or resetting that simulator loses the session and needs
    the owner again. **Treat the logged-in simulator as phase infrastructure.**
  - The `EHPANDA_AUTOMATION_IPB_MEMBER_ID` / `IPB_PASS_HASH` / `IGNEOUS` launch seam exists and
    would also work, but was **rejected** on credential-exposure grounds. Do not re-propose it.
- **D-10: Matrix = iPhone + iPad × portrait + landscape × 3 sizes.** Twelve passes over every
  screen. iPad is not a re-run of iPhone: `isRegularWidthPad` routes detail and setting surfaces
  to different layouts entirely (Phase 5), so its AX5 failure modes are genuinely different.
  Landscape at AX5 is the harshest case — least vertical space, most reflow pressure.

### Scope of the sweep

- **D-11: App screens and sheets only.** Every SwiftUI screen EhPanda draws, including modals,
  sheets, popovers, alerts, toasts, and the error surface. **Explicitly excluded:** WebView-rendered
  screens (EhSetting web pages, the Cloudflare challenge surface), the ShareExtension, and
  system-provided UI (`BGContinuedProcessingTask` card, iOS share sheet, photo picker).
- **D-12: The screen inventory is re-derived against today's tree, not inherited.** Phase 10's
  per-screen table (10-10-SUMMARY.md § "Per-screen coverage") predates Phases 11–15 — the
  Cloudflare login surface, the analytics opt-out row in General Settings, and the Phase 15
  download changes all landed after it. Use it as a starting checklist, not as the inventory.

### The five known AX5 edge cases

- **D-13: Pre-registered as named items with an explicit per-case disposition.** The five from
  ROADMAP criterion 4 — Detail stats-strip abbreviation, long-tag right-edge clip in the tag
  cloud, reader total-page counter wrap, Favorites trailing-glyph clip, hero-carousel title
  truncation — are carried as named entries in the findings report, each closing as **fixed** or
  **explicitly accepted (with the owner's reason recorded)**. Tracked alongside, not merged into,
  the sweep's own findings, so criterion 4 ticks off item by item and none is silently dropped.
  - Under D-03 a wrap is *not* degradation, so "reader total-page counter wrap" may close as
    accepted on the rule alone. That still gets recorded as a disposition.

### `minimumScaleFactor` and default-size parity

- **D-14: `minimumScaleFactor` is banned outright.** Not judged case by case, not grandfathered.
  All 5 surviving sites are removed and the target count is **0**, enforced by D-16's lint rule.
  Current sites: `GalleryListComponents/Cells/GalleryDetailCell.swift` (2),
  `DetailFeature/DetailView+CommentCells.swift`,
  `DetailFeature/DetailView+HeaderSection.swift` (0.72),
  `DetailFeature/Comments/CommentsView.swift`.
- **D-15: Default-size (`.large`) parity outranks the ban.** Removing a shrink changes behavior
  at the default size wherever that shrink currently engages there — e.g. the 0.72 factor on the
  Detail header's category label, which plausibly engages at default for a long category name.
  Where the ban and parity collide, **parity wins**: the replacing reflow must preserve
  default-size appearance. The agent verifies both halves — no information loss at XXL/AX3/AX5
  *and* no visible change at `.large`.

### Regression protection (the agent's round-1 carve-out)

- **D-16: Four error-level SwiftLint custom rules, written by the agent, wired into `.swiftlint.yml`.**
  The build-tool plugin runs them on every build, so enforcement is automatic
  — no separate script, no CI job.

  | Rule | Bans | Current count |
  |---|---|---|
  | `minimumScaleFactor` | any use (D-14) | 5 → must reach 0 |
  | `.dynamicTypeSize(` as a **view modifier** | caps and clamps (Phase 10 D-02) | 0 |
  | `GeometryReader` | any use (Phase 5 constraint) | 0 |
  | `.system(size: <numeric literal>)` | fixed-pixel fonts | 0 |

- **D-17: The `dynamicTypeSize` rule bans the modifier but allows the environment read.**
  `.dynamicTypeSize(…)` as a modifier is what "never cap" forbids; `@Environment(\.dynamicTypeSize)`
  is a *read* — how a view asks "am I at an accessibility size?" in order to switch an HStack to
  a VStack, which is exactly the reflow the owner will be writing. A blanket regex would block
  his own fixes. Match the modifier form only.
- **D-18: The system-size font rule matches numeric literals only.** The rule targets
  `.system(size:)`; `@ScaledMetric`-fed forms
  such as `.font(.system(size: reloadSymbolSize))` are the Phase 10 pattern and stay legal; only
  `\.system\(size: [0-9]` is an error.
- **D-19 (round-1 half): the Phase 11 exception protocol is the only escape hatch** — a
  `// reason:` comment plus `// swiftlint:disable:next`, owner-reviewed. Per AGENTS.md,
  suppressing or disabling a rule without the owner's explicit permission is forbidden.

---

## Round 2 — Assistive technology (A11Y-02)

### Work split and bar

- **D-20: The agent implements round 2; the owner reviews.** Unlike reflow, this work is
  high-volume and mechanical — labels on 53 `Image(systemSymbol:)` sites, input labels for Voice
  Control, motion gating — with no visual judgment call, which is what round 1's split was
  protecting against. **Sufficient Contrast and Differentiate Without Color are audit-first:**
  the owner's read is that they may already be largely implemented, and the baseline scan agrees
  (`DownloadBadgeLabel` already pairs a status symbol with its color; category badges already
  carry the category name as text). Measure, report, then build only where something fails.
- **D-21: The bar is the App Store Accessibility Nutrition Label** — Apple's own pass/fail
  criteria, requiring every common user task to work rather than just the main screen. It is a
  shippable outcome: the label appears on the App Store listing. Round 1's Larger Text plus round
  2's five axes cover 6 of 9 categories; Dark Interface is expected to already pass; Captions and
  Audio Descriptions are genuinely N/A.
- **D-22: An unclaimable category comes back to the owner with the numbers.** If a decision made
  in this phase blocks a Nutrition Label claim, the agent does **not** silently accept the gap and
  does **not** bend the bar — it reopens the blocking decision with the measurements in hand.

### Sequencing

- **D-23: Round 1 first, then round 2.** Owner's call, over the recommendation to invert.
- **D-24 — why the staleness risk is narrow.** Accessibility labels are not rendered, so the bulk
  of round 2 cannot disturb round 1's verified layout. Only two things can: a **newly added glyph
  or shape** for a non-color indicator, and a **contrast change that alters a rendered element's
  size**. The D-25 colour decision changes text *colour* only, which moves no layout.
- **D-25: Targeted re-sweep of touched screens.** The agent tracks every screen where round 2 adds
  a visible element and re-walks only those at XXL/AX3/AX5 at the end. Typically a handful of
  screens rather than the full 12-pass matrix, closing the staleness hole exactly where it exists.

### Colour and contrast — **agent's call, owner-delegated**

The owner first froze the category colours ("always keep them as-is"), then reversed and delegated:
*"do what you think it's necessary to do with the colors, including category colors."* The decision
below is the agent's, taken under that delegation.

- **D-26: Category background colours are frozen; the badge text colour becomes adaptive.**
  The background carries the brand identity and the at-a-glance scan-ability; the text colour
  carries neither. So all 84 category colour variants (11 categories × 2 hosts × {light, dark,
  light+HC, dark+HC}) stay **byte-identical**, and `CategoryLabel`'s hardcoded
  `.foregroundStyle(.white)` becomes black or white chosen from the **resolved background's
  relative luminance** (`Color.resolve(in:)`, iOS 17+, fine at the iOS 26 floor).
  - **Measured result: 84/84 variants pass WCAG AA, worst case 4.62:1** (ExHentai Game CG, light).
  - **The floor is structural:** for *any* background colour, the better of black/white is
    mathematically ≥ 4.58:1 (the two ratios cross at L ≈ 0.179). This cannot be broken by a colour
    the site introduces later.
  - **Cost, accepted:** 47 of 84 badges flip to black text. That is a visible change, which is
    why it required the owner's authorization. In exchange no brand colour moves and Sufficient
    Contrast becomes claimable.
- **D-27: The Increase Contrast variants are re-authored — but this is a should-fix, not a blocker.**
  The colorsets already ship `contrast: high` entries, and they currently make contrast
  *worse* in nearly every case (E-Hentai Manga 2.56 → 1.79; Artist CG 1.93 → 1.36; Western 2.30 →
  1.92) because they were authored to match the website's brighter colours rather than for
  legibility. A user who enables Increase Contrast gets a less legible badge. Under D-26 they
  already pass AA, so the residual defect is only that "more contrast" yields less — real, but no
  longer a compliance blocker.
- **D-28: Non-category colours are audited on their merits** against 4.5:1 text / 3:1 non-text in
  light, dark and Increase Contrast, and fixed where they fail. They are semantic/system colours
  (15 `Color(.systemGray…)`, 29 `.tint(`, only 2 hex literals) and carry no brand constraint.

### Reduce Motion

- **D-29: Meaningful motion only.** Gate springs, slides, scale and transitions on
  `accessibilityReduceMotion` — replacing them with a dissolve or nothing — and drop purely
  decorative motion. **Subtle crossfades and `.contentTransition(.numericText())` stay
  ungated**: they are not vestibular triggers, which is what the setting exists for, and gating
  them would flatten motion Apple never asked to flatten. Roughly a third of the ~107 animation
  sites are in scope.

### VoiceOver / Voice Control

- **D-30: Voice Control is verified in English, with a structural guard for the other five locales.**
  Input labels derive from the same `LocalizedStringResource` keys as the visible
  text, so per-locale matching is structural rather than something to re-walk by hand. The agent
  verifies `en` and adds a check that **no accessibility label is a hardcoded string** that could
  drift from its visible text.

### Verification (round 2)

- **D-31: Automated audit plus manual walkthrough — both are required by the bar.**
  `performAccessibilityAudit()` on the **existing non-default `UITests` plan** from Phase 13
  catches missing labels, contrast failures and undersized hit targets mechanically across every
  screen, and doubles as a permanent regression gate. A manual VoiceOver and Voice Control pass
  catches what it cannot see — reading order, focus after navigation, and whether a label actually
  reads sensibly. Neither alone meets the Nutrition Label bar.

### Evidence and artifacts (both rounds)

- **D-32: Text in the repo; screenshots never enter it.** EhPanda's repository is public and the
  sweep screenshots real adult gallery content at AX5. The committed artifact is a **verdict
  table** — screen × device × orientation × size, with a written description of each finding.
  Screenshots live in the session scratchpad only. **No screenshot is ever committed, not even of
  a screen judged content-free** — a mistake there is permanent in git history.
- **D-33: The agent actively sends the owner a before/after image per finding**, in chat, rather
  than only on request, so each finding can be judged visually without opening the simulator.
- **D-34: Requirement IDs are `A11Y-01` (round 1) and `A11Y-02` (round 2)**, in a new `A11Y`
  category. Dynamic Type was the last untouched accessibility axis — VoiceOver labels and
  decorative-icon handling landed opportunistically in Phases 5 and 7 — so a category named for
  the domain leaves room for future accessibility work rather than burying it under POLISH.
  **Already written**: ROADMAP.md Phase 16 and REQUIREMENTS.md were updated during this discussion
  (commit below); traceability is 25/25.

### Claude's Discretion

- The shape of the re-derived screen inventory (D-12) and how a "screen" is counted for the
  12-pass matrix.
- How a round-1 finding is re-verified after the owner fixes it (per-screen re-walk vs. batched
  re-sweep), and whether the sweep is resumable across sessions. Surfaced and left to the planner.
- The precise regex form of each of the four SwiftLint rules, subject to D-17 and D-18.
- Where the adaptive text-colour rule lives (a `Color` extension in `AppTools` vs. inline in
  `CategoryLabel`) and whether any other site renders white text on a category colour.
- Which specific animation sites qualify as "meaningful" under D-29.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Authoritative scope
- `.planning/ROADMAP.md` §"Phase 16: Accessibility (Dynamic Type + Assistive Technology)" — 12
  success criteria, the per-round implementation mode, and the Nutrition Label target bar.
  **Rewritten during this discussion** — do not scope from any cached copy.
- `.planning/REQUIREMENTS.md` §"A11Y — Accessibility" — `A11Y-01` and `A11Y-02`. **Added during
  this discussion.** §"Out of Scope" carries the "any visual redesign" parity constraint, which
  D-26 was authorized to cross for the badge text colour only.
- `.planning/ROADMAP.md` §"Phase 10: UI Polish" criterion 5 — where round 1 was carved out from.

### The Phase 10 foundation round 1 verifies
- `.planning/phases/10-ui-polish/10-CONTEXT.md` §"Dynamic Type (criterion 5)" — D-01/D-02/D-03.
  **D-02 (reflow, never cap) is absolute and carries forward unchanged.** D-03's XXL/AX3/AX5
  sample carries forward as this phase's D-05.
- `.planning/phases/10-ui-polish/10-10-SUMMARY.md` — the whole-app audit: 7 fixed-font conversions,
  the 33-site `lineLimit(1)` verdict table, the 9-site fixed-height table, and per-screen coverage.
  **Read with D-04 in mind:** its "fine" verdicts for secondary-text truncation no longer hold.
- `.planning/phases/10-ui-polish/10-11-SUMMARY.md` — the B1–B10 reflow verdict table and the
  `@ScaledMetric(relativeTo:)`-for-fixed-frames pattern (literal == scaled at `.large`, so default
  parity is exact by construction). The reference pattern for D-15.
- `.planning/phases/10-ui-polish/10-UAT.md` test 7 — the D-03 device UAT recorded as `skipped`,
  deferred to this phase. The gate criterion 5 still owes.

### Accessibility guidance
- The `swift-accessibility-skill` skill — First-Draft Rules table, per-axis references
  (`voiceover-swiftui.md`, `voice-control.md`, `display-settings.md`, `nutrition-labels.md`,
  `testing-auditing.md`), and `resources/audit-template.swift`, a drop-in XCUITest for
  `performAccessibilityAudit()`. **Load it before writing any round-2 code.**

### Project rules that constrain this phase
- `CLAUDE.md` (repo root, a.k.a. AGENTS.md) — SwiftLint read-first, the no-suppression rule D-19
  depends on, the labeled-localized-format and every-locale-filled catalog rules (round 2 adds
  localized accessibility strings), and confirmation-dialog/alert placement.
- `.swiftlint.yml` (repo root) — where D-16's four custom rules land; match the shape of the
  existing custom regex rules.
- `.planning/phases/11-infra-refactor-lint-capstone/11-EXCEPTIONS.md` — the 8 approved repo-wide
  exceptions and the `// reason:` + `swiftlint:disable:next` protocol.
- `.planning/codebase/CONVENTIONS.md` — established SwiftUI/TCA conventions.

### Source landmarks
- `AppPackage/Sources/AppComponents/CategoryView.swift` — `CategoryLabel`, whose
  `.foregroundStyle(.white)` on a solid category background is the single site D-26 changes.
- `App/Assets.xcassets/Category/Colors/{E-Hentai,ExHentai}/*.colorset` — the 84 frozen background
  variants; the `contrast: high` entries are the D-27 should-fix.
- `AppPackage/Sources/AppModels/Gallery/Category.swift:25` — `Category.color(host:)`, which resolves
  the asset name; `AppPackage/Sources/AppModels/Gallery/Gallery.swift:146`.
- The 5 `minimumScaleFactor` sites D-14 removes: `GalleryListComponents/Cells/GalleryDetailCell.swift:155,166`,
  `DetailFeature/DetailView+CommentCells.swift:42`, `DetailFeature/DetailView+HeaderSection.swift:73`,
  `DetailFeature/Comments/CommentsView.swift:165`.
- `AppPackage/Sources/GalleryListComponents/DownloadBadgeLabel.swift` — already pairs a status
  symbol with its colour and carries `.accessibilityElement(children: .ignore)` +
  `.accessibilityLabel`. The reference for what "already implemented" looks like under D-20.
- `EhPandaUITests/` + `UITests.xctestplan` (non-default, Phase 13) — where D-31's
  `performAccessibilityAudit()` lands.
- `AppPackage/Sources/AppLaunchAutomationClient/AppLaunchAutomation.swift` — the
  `EHPANDA_AUTOMATION_*` seam, documented because it is the obvious alternative to D-09 and was
  **rejected**.

</canonical_refs>

<code_context>
## Existing Code Insights

### Dynamic Type foundation (re-verified 2026-08-23, branch `feature/gsd-phase-16`)

| Gate | Count | Note |
|---|---|---|
| `dynamicTypeSize` | 0 | no cap anywhere; D-17's rule lands at zero |
| `GeometryReader` | 0 | Phase 5 constraint holds |
| `.system(size: <literal>)` | 0 | all 7 Phase 10 conversions hold |
| `minimumScaleFactor` | 5 | down from 8; **D-14 drives this to 0** |
| `@ScaledMetric` | 8 | the reflow pattern to copy |
| `lineLimit(1)` | 31 | D-04 puts most of these back in scope |
| fixed `frame(height:)` | 5 | icons/touch-target chrome |

### Accessibility baseline (measured 2026-08-23)

**13 accessibility call sites repo-wide**, all added opportunistically during Phases 5/7/9/10/15 —
never a systematic pass:
`accessibilityLabel` 5 · `accessibilityElement` 4 · `accessibilityHidden` 2 · `accessibilityAddTraits` 1 ·
`accessibilityFocused` 1 · `accessibilityIdentifier` 7 (UI tests). **Zero** `accessibilityValue`,
`accessibilityHint`, `accessibilityInputLabels`, `accessibilityAction`, `accessibilitySortPriority`,
`accessibilityRepresentation`, `accessibilityRotor`.

Against that surface: **53** `Image(systemSymbol:)`, **165** buttons, **37** `ToolbarItem`s, **10**
`.onTapGesture` custom tappables. Phase 10's `Label` conversion (**100** `Label(` sites) already
bought many buttons a free VoiceOver label — the gap is concentrated in icon-only toolbar items and
the custom tappables.

**Reduce Motion:** 5 `@Environment(\.accessibilityReduceMotion)` reads (SystemNotification,
GalleryCardCell, ViewModifiers, DownloadsView×2) against **89** `.animation(`, **3** `withAnimation`,
**4** `.transition(`, **11** `.contentTransition(` — roughly 5–10% covered.

**Contrast:** mostly semantic (15 `Color(.systemGray…)`, 29 `.tint(`, 2 hex literals). The exception
is the category colour system — **45 of 84 variants below 4.5:1** against white badge text, and the
Increase Contrast variants are worse than standard in nearly every case (see D-26/D-27).

**Differentiate Without Color:** partly satisfied already — `DownloadBadgeLabel` varies its symbol by
status, and category badges carry the category name as text. Audit-first per D-20.

### Reusable assets
- **`xcrun simctl ui booted content_size`** — scriptable Dynamic Type switching; what makes 12 passes
  tractable.
- **`@ScaledMetric(relativeTo:)` pattern (8 live sites)** — the parity-exact way to relax a fixed
  metric: literal == scaled at `.large`. The template for every D-15-constrained fix.
- **Existing custom SwiftLint regex rules** — 8 already live at error from Phase 11; D-16's four
  follow their shape.
- **The non-default `UITests` plan (Phase 13)** — an existing home for D-31's audit that keeps the
  ordinary scheme unit-only and fast.
- **`swift-accessibility-skill`** — First-Draft Rules and a drop-in `performAccessibilityAudit()`
  template.

### Established patterns
- **Adaptive layout landed in Phase 5:** size classes, `onGeometryChange`, `containerRelativeFrame`,
  `ViewThatFits`, no `GeometryReader`. `ViewThatFits` and the (legal, per D-17)
  `@Environment(\.dynamicTypeSize)` read are the two tools for "stack this row vertically at AX sizes."
- **Parity discipline:** every prior phase in this milestone held appearance parity. D-15 makes that
  explicit where the `minimumScaleFactor` ban collides with it; D-26 is the one authorized visible
  departure, and it moves no brand colour.
- **Localized strings go through `LocalizedStringResource`** and the `.xcstrings` catalogs — round 2's
  accessibility strings must follow AGENTS.md's catalog rules, and D-30's structural guard depends on
  labels coming from catalog keys rather than hardcoded literals.

### Integration points
- **Sequential `xcodebuild` only** — no overlapping invocations on this machine.
- **The logged-in simulator is phase infrastructure** (D-09) — plans must not assume a clean
  simulator, and must not erase or reset it.
- **`.swiftlint.yml` runs as an error-severity build-tool plugin** — landing D-16's rules with any
  surviving violation breaks the build for everyone, so the `minimumScaleFactor` removal (D-14,
  owner-implemented) must precede or accompany its rule.
- **Round 2 lands after round 1's sweep is signed** (D-23), with D-25's targeted re-sweep closing the
  window.

</code_context>

<specifics>
## Specific Ideas

- **The verdict rule is the owner's, in his words:** "degraded means the interface provides less
  information under larger font size setting. removing decoration to save space is okay, but the
  interface should always provide same contents." Every judgment call resolves against that sentence,
  not against a generic accessibility checklist.
- **The sweep procedure is equally literal:** max out the font size, open every screen, **scroll down
  to the bottom**, confirm nothing is degraded. The scroll-to-bottom is not incidental — a screen that
  looks fine above the fold is not verified.
- **Credentials never touch the agent.** The owner chose hand-login specifically over the available
  env-injection seam. Do not propose the seam again as a convenience.
- **No screenshot reaches the repo, ever** — including screens that look content-free. The repository
  is public and git history is permanent.
- **`minimumScaleFactor` is banned, not managed.** The owner's answer was "ban minimumScaleFactor,"
  stronger than the case-by-case option offered. Target 0.
- **Brand colours survive intact; only the text flips.** The whole point of D-26 is that a category
  badge remains instantly recognisable — the background is the identity. 47 badges reading in black
  instead of white is the price, and it was paid deliberately.
- **Reduce Motion is not "turn off animation."** Apple's setting targets vestibular triggers. Numeric
  text transitions from POLISH-01 stay animated on purpose.

</specifics>

<deferred>
## Deferred Ideas

- **`xSmall` and Bold Text passes** (D-07) — both catch real but different failures: `xSmall` catches
  fixed frames leaving dead space when text shrinks; Bold Text widens glyphs without changing the size
  class, so labels that barely fit at AX5 can tip into truncation. Worth revisiting in a future
  accessibility phase.
- **WebView chrome at AX5 and under VoiceOver** — the native nav bar / toolbar / dismiss chrome around
  the EhSetting web pages and the Cloudflare challenge surface is ours and can still break, even though
  WebKit owns the text inside. Excluded by D-11.
- **ShareExtension and system-provided UI** — excluded by D-11. The only thing worth checking there is
  whether the strings handed to Apple's UI break, which is not layout work.
- **The remaining three Nutrition Label categories** — Dark Interface is expected to pass already and
  is not actively worked here; Captions and Audio Descriptions are N/A while the app ships no video.
  If animated-image playback ever grows controls, Captions re-enters scope.
- **Switch Control and Full Keyboard Access** — not among the owner's five axes and not Nutrition Label
  categories, but they share machinery with VoiceOver (custom actions, focus order) and would be cheap
  to add once round 2's semantics exist.

</deferred>

---

*Phase: 16-dynamic-type-accessibility*
*Context gathered: 2026-08-23*
