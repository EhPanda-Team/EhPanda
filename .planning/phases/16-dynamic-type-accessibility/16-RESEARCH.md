# Phase 16: Accessibility (Dynamic Type + Assistive Technology) - Research

**Researched:** 2026-08-23
**Domain:** iOS 26 SwiftUI accessibility — Dynamic Type verification tooling, SwiftLint regex enforcement, VoiceOver / Voice Control semantics, Reduce Motion gating, WCAG contrast on asset-catalog colours, XCUITest `performAccessibilityAudit()`, App Store Accessibility Nutrition Label criteria
**Confidence:** HIGH for everything measured against the live tree and the installed Xcode 26.6 SDK; MEDIUM for Apple's published Nutrition Label criteria (official docs, fetched this session); LOW only where explicitly tagged `[ASSUMED]`

## Summary

Phase 16 is two phases wearing one number. **Round 1** is a *verification* job for the agent: the owner reflows by hand, the agent drives a 12-pass simulator matrix (iPhone + iPad × portrait + landscape × XXL / AX3 / AX5) over every screen on the owner's hand-logged-in simulator, records findings under the owner's "less information = degraded" rule, and re-verifies. Its only agent-authored code is four error-level SwiftLint custom rules. Every mechanism round 1 needs already exists on this machine and was exercised in this session: `xcrun simctl ui <UDID> content_size <token>` switches Dynamic Type live (no relaunch; SpringBoard re-rendered at AX5 within a second), `agent-device orientation landscape-left|portrait` rotates the simulator, `sim-use`/`agent-device` read the accessibility tree and drive taps, and the standalone SwiftLint 0.65.0 binary in DerivedData confirmed the four proposed regexes flag exactly **5 / 0 / 0 / 0** violations today, with the `dynamicTypeSize` rule leaving `@Environment(\.dynamicTypeSize)` reads legal.

**Round 2** is an *implementation* job with an audit-first half. The tree has 13 accessibility call sites in total, so VoiceOver/Voice Control coverage is a high-volume, mechanical pass — but it is smaller than the raw counts suggest: of the 53 `Image(systemSymbol:)` sites, only ~14 are icon-only *controls* without a `Label`, the 37 toolbar items are almost all `Label(.key, systemSymbol:)`-backed (free VoiceOver label and Voice Control name), and the real gaps are the 10 `.onTapGesture` custom tappables (two of which, `ExcludeToggle` and `CategoryCell`, are unlabeled custom toggles). Reduce Motion needs gating on roughly 20 of the 107 animation sites (springs, slides, scale transitions, the spinning download icon, list insert/remove animations); the other ~85 are opacity crossfades or `numericText` that D-29 keeps ungated. The contrast work is settled by measurement: re-derived this session from the 84 colorset variants, **45/84 fail 4.5:1 with white text, 0/84 fail with best-of-black/white, worst case 4.62:1 (ExHentai Game CG, light), 47 badges flip to black, the crossover is L = 0.1791 (4.58:1), and all 40 Increase Contrast variants are *less* contrasty than their standard counterparts** — every D-26/D-27 number holds. Two sites render white on a category colour, not one: `CategoryLabel` and the Filters screen's `CategoryCell`.

**Primary recommendation:** Plan round 1 as a screen-inventory-driven sweep with a resumable verdict table in the repo and screenshots only in the scratchpad, gated by the lint rules landing *after* the owner's `minimumScaleFactor` removal; plan round 2 as inventory-driven mechanical passes (labels → Voice Control → motion → contrast → colour-alone), each pinned by a source-scan or colorset test in the `AppPackage` test targets plus a fixture-reachable `performAccessibilityAudit()` suite in `EhPandaUITests` run on a simulator that is **not** the owner's logged-in one.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

---

## Round 1 — Dynamic Type (A11Y-01)

### Work split

- **D-01: The owner finds and fixes; the agent verifies.** The agent produces no reflow work
  order for the owner to execute against, and writes no reflow code. It runs the sweep, records
  findings, and re-verifies. The one exception is D-16's lint rules.
- **D-02: Scanning protocol = record and move on.** The agent does not interrupt the sweep to
  raise each finding as it lands. It records the finding, continues to the next screen, and
  reports the complete list once every page has been scanned.

### The verdict rule — what "degraded" means

- **D-03: Degraded = the interface provides *less information* at a larger font size.** The
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

- **D-16: Four error-level SwiftLint custom rules, written by the agent, wired into
  `.swiftlint.yml`.** The build-tool plugin runs them on every build, so enforcement is automatic
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
- **D-18: The `.system(size:)` rule matches numeric literals only.** `@ScaledMetric`-fed forms
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

- **D-26: Category *background* colours are frozen; the badge *text* colour becomes adaptive.**
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
- **D-27: The Increase Contrast variants are re-authored — but this is a should-fix, not a
  blocker.** The colorsets already ship `contrast: high` entries, and they currently make contrast
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

- **D-30: Voice Control is verified in English, with a structural guard for the other five
  locales.** Input labels derive from the same `LocalizedStringResource` keys as the visible
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

### Deferred Ideas (OUT OF SCOPE)

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
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| A11Y-01 | Complete full-range Dynamic Type readability and operability (AX1–AX5) on the Phase 10 foundation: no information loss at XXL/AX3/AX5, reflow only, `minimumScaleFactor` 5 → 0, default `.large` parity outranks the ban, four error-level SwiftLint rules, owner-signed 12-pass simulator sweep on a hand-logged-in simulator | §Round-1 verification mechanics (simctl tokens verified live, `agent-device orientation` for rotation, simulator identification, tool choice); §Screen inventory (D-12, 42 surfaces with routes and gating); §D-04 re-judgement checklist (30 `lineLimit(1)` code sites, 5 `minimumScaleFactor`, 5 fixed `frame(width:height:)`, 6 fixed widths); §SwiftLint rules (exact YAML, verified 5/0/0/0 today, fixture-validated positives and negatives); §Validation Architecture |
| A11Y-02 | VoiceOver, Voice Control, Reduced Motion, Sufficient Contrast, Differentiate Without Color to the Nutrition Label bar; labels from catalog keys with a structural no-hardcoded-string guard; meaningful motion gated; 84/84 category variants pass via adaptive badge text; `performAccessibilityAudit()` on the `UITests` plan plus manual VO/VC walkthrough; Nutrition Label recommendation | §Round-2 inventories (icon-only controls classified, toolbar items, 10 custom tappables with per-site disposition); §SwiftUI API set (verified against the Xcode 26.6 SDK, including the missing `LocalizedStringResource` overload on `accessibilityInputLabels`); §D-30 guard (rule validated, 0 violations today); §Reduce Motion inventory (in-scope vs ungated lists); §Contrast (formula, re-measured numbers, two white-on-category sites, colorset parsing with three component encodings, test design); §Differentiate Without Color audit; §`performAccessibilityAudit()` (API, fixture reachability, which simulator); §Nutrition Label criteria per category (cited) |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

Directives extracted from the repository `CLAUDE.md` (identical to `AGENTS.md`) that bind this phase. The planner must verify compliance.

| # | Directive | Effect on this phase |
|---|-----------|----------------------|
| C-1 | **Read `.swiftlint.yml` before writing Swift; never suppress/disable a rule without explicit owner permission** | The four D-16 rules and the D-30 guard are *added* rules; any surviving violation must be fixed at the root or go through the 11-EXCEPTIONS `// reason:` + `swiftlint:disable:next` protocol with owner review. Note the existing `swiftlint_disable_requires_reason` rule already errors on a disable without a preceding `// reason:` comment. |
| C-2 | **Reducer naming: `Feature` suffix is the project preference** (existing code still uses `Reducer`; follow the file you are in) | No new reducers expected in this phase. |
| C-3 | **New module → own `.swiftlint.yml` with `parent_config`** | Not expected; if the adaptive-colour helper lands in an existing module (`AppComponents` or `AppTools`) no new config is needed. |
| C-4 | **Labeled localized-format arguments**: numeric args via named `%#@variable@` substitutions; string args positional `%@`; plural categories coherent across locales | Every new accessibility string with a number (e.g. "Page 3 of 120", "4.5 stars") must use named substitutions; the existing `accessibility.downloading` key in `DetailFeature/Resources/Localizable.xcstrings` is the template. |
| C-5 | **`shouldTranslate: false` keys still need every locale filled** | Applies if any accessibility key is marked non-translated (unlikely; labels should translate). |
| C-6 | **Confirmation dialog / alert placement on the stable action source** | Any `accessibilityAction`-triggered confirmation must keep the existing anchor; do not hoist modifiers for convenience. |
| C-7 | **Download manifest SSOT / download-folder invariant** | Untouched by this phase; do not let accessibility edits in `DownloadsFeature` reach into status derivation. |
| C-8 | **No absolute home paths in generated docs** — write `$HOME/…` or repo-relative | This file, the plans, the verdict table and summaries: `$HOME/.claude/skills/swift-accessibility-skill/…`, `$HOME/Library/Developer/Xcode/DerivedData/…`. |
| C-9 | **Local project reference privacy** — never name another local project in any artifact | No local project was consulted for this research. |
| C-10 | **App shell / `AppPackage` layout; third-party deps only in `AppPackage/Package.swift`** | No new dependency is needed (see Standard Stack). |
| From 16-CONTEXT D-32 | **No screenshot ever enters the repo** | All `simctl io screenshot` / `sim-use screenshot` / `agent-device screenshot` output goes to the session scratchpad; plans must not `git add` `.png`/`.jpg`. A `.gitignore`-style guard is *not* a substitute for discipline because the scratchpad is outside the repo anyway. |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Dynamic Type reflow (round 1) | SwiftUI view layer (`AppPackage/Sources/*Feature`, `AppComponents`, `GalleryListComponents`) | — | Layout is a view concern; reducers/state untouched. Owner-implemented. |
| Dynamic Type verification sweep | Tooling tier (simulator + `simctl` + `agent-device`/`sim-use`) | Planning docs (`.planning/phases/16-…/` verdict table) | Nothing in the app changes for verification; evidence is text in the repo, images in the scratchpad. |
| Lint enforcement (D-16, D-30 guard) | Build tier (`.swiftlint.yml` + SwiftLint build-tool plugin) | — | Runs on every `xcodebuild`; no CI job, no script. |
| VoiceOver / Voice Control semantics | SwiftUI view layer | `Resources` / module `Localizable.xcstrings` catalogs | Labels are view modifiers fed by catalog keys; no reducer state needed (state is expressed as traits computed from existing view inputs). |
| Reduce Motion gating | SwiftUI view layer (`@Environment(\.accessibilityReduceMotion)`) | — | Environment read at the animating view; the existing 5 sites are the house pattern. |
| Adaptive badge text colour | `AppComponents` (`CategoryLabel`, `CategoryCell`) with the luminance helper in `AppTools` (`Color` extension) | Asset catalog (`App/Assets.xcassets/Category/Colors`) stays byte-identical | The helper is pure colour math; `AppTools` already hosts `ColorCodable.swift` and is imported by `AppComponents`. |
| Contrast / byte-identity regression tests | `AppPackage/Tests` (Swift Testing, repository-root walk pattern) | — | The colorsets live in the app target, so the test reads them from disk the way `DownloadLogPrivacyInvariantTests` reads sources. |
| `performAccessibilityAudit()` | `EhPandaUITests` target on the non-default `UITests.xctestplan` | `AppFeature/UITestSupport` (hermetic stub network, fixtures) | XCUITest only; reachability bounded by the fixture set. |
| Manual VoiceOver / Voice Control walkthrough | Physical device (`Owner-iPhone-Test`, iPhone 11, connected) | Accessibility Inspector on the simulator for label/trait inspection | The Simulator has neither VoiceOver nor Voice Control. |

## Standard Stack

No new packages. Everything this phase needs ships with Xcode 26.6 / iOS 26 or is already installed.

### Core
| Library / Tool | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI accessibility modifiers (`accessibilityLabel/Hint/Value(LocalizedStringResource)`, `accessibilityInputLabels`, `accessibilityHidden`, `accessibilityAddTraits`, `accessibilityElement(children:)`, `accessibilityAction`, `accessibilitySortPriority`, `accessibilityFocused`, `accessibilityRepresentation`) | iOS 26 SDK (iPhoneSimulator26.5.sdk) | VoiceOver / Voice Control semantics | `[VERIFIED: Xcode 26.6 SDK swiftinterface]` — `accessibilityLabel/Hint/Value` all carry a `Foundation.LocalizedStringResource` overload; `accessibilityInputLabels` does **not** (only `[Text]`, `[LocalizedStringKey]`, `[S: StringProtocol]`). |
| `@Environment(\.accessibilityReduceMotion)`, `\.accessibilityDifferentiateWithoutColor`, `\.colorSchemeContrast`, `\.dynamicTypeSize` (+ `DynamicTypeSize.isAccessibilitySize`) | iOS 26 SDK | Gating motion, optional colour-alone enhancements, reflow breakpoints | `[VERIFIED: SwiftUICore swiftinterface lines 11703, 11724, 17999, 18013, 18393]` |
| `Color.resolve(in: EnvironmentValues) -> Color.Resolved` with `linearRed/linearGreen/linearBlue` | iOS 17+, in SwiftUICore | Relative luminance for the adaptive badge text | `[VERIFIED: SwiftUICore swiftinterface 2217–2228, 13469]` — the linear fields are exactly WCAG's linearised channels, so no gamma decode is needed. |
| `XCUIApplication.performAccessibilityAudit(for:_:)` + `XCUIAccessibilityAuditType` | XCUIAutomation, iOS 17+ | Automated audit on the `UITests` plan | `[VERIFIED: XCUIAutomation swiftinterface + `XCUIAccessibilityAuditTypes.h`]` |
| SwiftLint (build-tool plugin via `SwiftLintPlugins` ≥ 0.64.1; artifact binary 0.65.0) | 0.65.0 | D-16 rules + D-30 guard | Already wired (`AppPackage/Package.swift:19,59`); regexes validated this session with the same binary. |
| `xcrun simctl ui <UDID> content_size|appearance|increase_contrast` | Xcode 26.6 | Dynamic Type / appearance / Increase Contrast switching | `[VERIFIED: ran live]` |
| `agent-device` | 0.20.8 | Simulator orientation (`orientation landscape-left`), snapshots, taps, screenshots to scratchpad | `[VERIFIED: `agent-device help orientation`]` |
| `sim-use` | 0.13.0 | Alternative AX-tree reader/tapper (`sim-use ui`, `tap --label`) | Installed at `/opt/homebrew/bin/sim-use` |
| Accessibility Inspector.app | Xcode 26.6 bundle | Simulator-side label/trait/frame inspection, contrast eyedropper, Settings tab (Reduce Motion, Bold Text, Increase Contrast, Button Shapes) | `[VERIFIED: present under the Xcode bundle's `Contents/Applications`]` |
| Swift Testing (`@Suite`/`@Test`, `#require`) | bundled | Source-scan and colorset tests | 178 test files / ~1020 `@Test`s already use it. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `swift-accessibility-skill` (user skill) | 0.2.0 | First-Draft Rules, per-axis references, Nutrition Label recommendation format, `audit-template.swift` | Load before any round-2 code; its `#available` guards are unnecessary at the iOS 26 floor (see Pitfalls). |
| `ViewThatFits` / `@Environment(\.dynamicTypeSize)` | iOS 16+/15+ | Owner's reflow tools | Round 1, owner-written. |
| `@ScaledMetric(relativeTo:)` | iOS 14+ | Parity-exact replacement for fixed frames (literal == scaled at `.large`) | 8 live sites; the D-15 template. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `agent-device orientation …` for rotation | `osascript` keystrokes to Simulator.app (⌘← / ⌘→) | Needs macOS Accessibility permission for the terminal and a frontmost Simulator window; `agent-device` is scriptable and verifiable. `sim-use gesture rotate-cw` is a two-finger *content* rotation, not device orientation — do not use it for this. |
| Reading colorset JSON in a unit test | Resolving the asset colours at runtime through `UIColor(named:)` in an XCTest on the app target | Runtime resolution would need the app bundle and a trait collection per variant; the JSON walk is hermetic, pins byte-identity with a hash, and already has a house pattern (`DownloadLogPrivacyInvariantTests`). |
| SwiftLint regex for the D-30 guard | A Swift Testing source scan (the `DownloadSourceInventoryTests` pattern) | The lint rule fires on every build and matches the existing `accessibility_*` rules' shape; the test scan is the fallback if a multi-line literal shape escapes the regex. Recommend the lint rule; keep the scan in reserve. |
| `performAccessibilityAudit()` on the owner's logged-in simulator | Run on a separate simulator (iPhone 17e / 27.0 iPhone Air) | `xcodebuild test` reinstalls the app and the runner; a reinstall preserves the data container in practice, but "in practice" is the wrong standard for D-09 infrastructure. Use a different simulator. |

**Installation:** none. `npm`/`pip`/`cargo` are irrelevant to this phase.

## Package Legitimacy Audit

No external packages are installed by this phase. `gsd-tools query package-legitimacy check` was not run because there is nothing to check.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| (none) | — | — | — | — | — | — |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
ROUND 1 (owner fixes, agent verifies)
                                                                  
  Screen inventory (D-12) ──┐                                     
                            ▼                                     
  for device in {iPhone Air ADE09605…, iPad Pro 11 8250D97E…}     
    for orientation in {portrait, landscape}    ← agent-device orientation <o>
      for size in {XXL, AX3, AX5}               ← xcrun simctl ui <UDID> content_size <token>
        for screen in inventory:                                  
          navigate (agent-device press / sim-use tap) ─► scroll to bottom ─► screenshot → scratchpad
             │                                                    
             ▼                                                    
          judge against D-03/D-04 ──► append row to 16-SWEEP.md verdict table (text only, repo)
             │                                                    
             └─► finding? record + continue (D-02); send before/after in chat (D-33)
                                                                  
  owner fixes ──► agent re-walks touched screens (resumable: table rows carry status)
  owner removes 5 × minimumScaleFactor ──► agent lands 4 lint rules ──► build green = gate
                                                                  
ROUND 2 (agent implements, owner reviews)                         
                                                                  
  inventories (this file) ──► mechanical passes:                  
     labels/traits/hidden ──► input labels ──► motion gating ──► badge text colour ──► colour-alone fixes
             │                                                    
             ├─► lint: accessibility_hardcoded_string (D-30) on every build
             ├─► unit tests: CategoryColorContrastTests (84/84 ≥ 4.5, hash byte-identity)
             ├─► UI tests: AccessibilityAuditUITests (performAccessibilityAudit per fixture-reachable screen)
             └─► manual: VoiceOver + Voice Control walkthrough on Owner-iPhone-Test
                                                                  
  D-25 targeted re-sweep of screens that gained a glyph ──► Nutrition Label recommendation (per category)
```

### Recommended Project Structure

No new directories. Touch points:

```
.swiftlint.yml                                   # +4 D-16 rules, +1 D-30 guard (custom_rules block)
.planning/phases/16-dynamic-type-accessibility/
├── 16-SWEEP.md                                  # round-1 verdict table (screen × device × orientation × size), resumable
├── 16-FINDINGS.md                               # numbered findings + the 5 pre-registered D-13 items with dispositions
└── 16-NUTRITION-LABEL.md                        # closing recommendation in the skill's format
AppPackage/Sources/AppTools/Color+Contrast.swift  # relativeLuminance(in:), contrastingForeground(on:in:) (pure math)
AppPackage/Sources/AppComponents/CategoryView.swift  # CategoryLabel + CategoryCell adopt the helper; CategoryCell gains button/selected semantics
AppPackage/Tests/AppToolsTests/ColorContrastTests.swift
AppPackage/Tests/AppComponentsTests/…             # (or AppModelsTests) CategoryColorsetInvariantTests: 84/84 + hash pin
EhPandaUITests/AccessibilityAuditUITests.swift    # performAccessibilityAudit per reachable screen
EhPandaUITests/Fixtures/…                         # optional new HTML fixtures (favorites, torrents, archives) if the audit is to reach them
<module>/Resources/Localizable.xcstrings          # accessibility.* keys, six locales
```

### Pattern 1: Round-1 sweep command sequence (verified)

**What:** The exact shell the sweep runs per pass.
**When to use:** every (device, orientation, size) cell.

```bash
# Source: xcrun simctl ui (Xcode 26.6) — verified live 2026-08-23
IPHONE=ADE09605-A44E-4F00-BE12-235970217355   # iPhone Air, iOS 26.5 (owner confirms which sim is the logged-in one; see Open Questions)
IPAD=8250D97E-9AB0-42FD-99DB-07B0094BF8C7     # iPad Pro 11-inch (M5), iOS 26.5

xcrun simctl list devices available            # enumerate; never `erase`, never `shutdown` the logged-in sim mid-sweep
xcrun simctl boot "$IPHONE" 2>/dev/null        # idempotent if already booted

xcrun simctl ui "$IPHONE" content_size         # read back: e.g. `medium`
xcrun simctl ui "$IPHONE" content_size extra-extra-large                         # XXL
xcrun simctl ui "$IPHONE" content_size accessibility-extra-large                 # AX3
xcrun simctl ui "$IPHONE" content_size accessibility-extra-extra-extra-large     # AX5

agent-device orientation landscape-left        # or: portrait
agent-device open app.ehpanda --foreground     # bundle id; returns the initial AX snapshot
agent-device screenshot "$SCRATCHPAD/iphone-land-ax5-home.png"   # scratchpad ONLY (D-32)
agent-device scroll down 10 --settle           # scroll to the bottom (the owner's rule: above-the-fold is not verified)

xcrun simctl ui "$IPHONE" content_size medium  # restore what was there before (the sweep must leave the sim as found)
```

Token table (from `simctl ui` usage text, `[VERIFIED: ran `xcrun simctl ui` with no args]`):

| Slider position | `DynamicTypeSize` | `content_size` token |
|---|---|---|
| 1–3 | `.xSmall` / `.small` / `.medium` | `extra-small` / `small` / `medium` |
| 4 (default) | `.large` | `large` |
| 5 | `.xLarge` | `extra-large` |
| 6 | `.xxLarge` | `extra-extra-large` |
| 7 (**XXL**) | `.xxxLarge` | `extra-extra-extra-large` |
| 8 (AX1) | `.accessibility1` | `accessibility-medium` |
| 9 (AX2) | `.accessibility2` | `accessibility-large` |
| 10 (**AX3**) | `.accessibility3` | `accessibility-extra-large` |
| 11 (AX4) | `.accessibility4` | `accessibility-extra-extra-large` |
| 12 (**AX5**) | `.accessibility5` | `accessibility-extra-extra-extra-large` |

So the three D-05 sample points are `extra-extra-extra-large`, `accessibility-extra-large`, `accessibility-extra-extra-extra-large`. Note the naming skew: "XXL" in the owner's vocabulary is iOS's *xxxLarge* (slider 7, the last non-accessibility size), which is what Phase 10 D-03 meant. Confirm with the owner in the first sweep report by naming the token used.

Also available and relevant to round 2: `xcrun simctl ui <UDID> appearance light|dark` and `xcrun simctl ui <UDID> increase_contrast enabled|disabled` `[VERIFIED]`. There is **no** `simctl` switch for orientation, Reduce Motion, Bold Text, Reduce Transparency, Grayscale, VoiceOver or Voice Control.

### Pattern 2: Catalog-keyed accessibility label (house pattern, D-30)

**What:** Every accessibility string comes from a generated `LocalizedStringResource` symbol.
**When to use:** every icon-only control, every custom tappable, every `accessibilityValue`.

```swift
// Source: repo — DetailView+HeaderSection.swift:152, AppearanceSettingView.swift:42, DownloadBadgeLabel.swift:28
Button(action: unfavorAction) {
    Label(.favorited, systemSymbol: .heartFill)   // Label title IS the VoiceOver label and the Voice Control name
        .labelStyle(.iconOnly)
}

Image(systemSymbol: .eyeSlash)
    .accessibilityLabel(.privacyMask)              // LocalizedStringResource overload (iOS 17+)

// A value with a number: named substitution per CLAUDE.md C-4 (template: accessibility.downloading key)
.accessibilityValue(.accessibilityPageOf(current: index + 1, total: pageCount))

// Voice Control alternates — NO LocalizedStringResource overload exists on accessibilityInputLabels,
// and the existing accessibility_text_argument rule bans Text(...) inside accessibility modifiers,
// so feed the StringProtocol overload from the catalog:
.accessibilityInputLabels([String(localized: .favorites), String(localized: .favoritesAlternate)])
```

Catalog key convention already in use: `accessibility.<name>` in the module's `Resources/Localizable.xcstrings` → generated symbol `.accessibility<Name>` (e.g. `accessibility.pause_action` → `.accessibilityPauseAction`). Six locales: `en`, `de`, `ja`, `ko`, `zh-Hans`, `zh-Hant` `[VERIFIED: DetailFeature catalog]`.

### Pattern 3: Custom tappable → real control (house pattern)

**What:** `DownloadListRow` is the repo's existing answer for a non-`Button` tappable.
**When to use:** the 10 `.onTapGesture` sites (see inventory). Prefer converting to `Button` + `.buttonStyle(.plain)` where the rendered appearance is identical; otherwise use this modifier triple.

```swift
// Source: repo — DownloadsView+Subviews.swift:391-413
GalleryDetailCell(...)
    .allowsHitTesting(false)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(.rect)
    .onTapGesture(perform: openAction)
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel(download.title)
```

For custom *toggles* (`ExcludeToggle`, `LaboratorySettingView` cell, `CategoryCell`) the required shape is `.accessibilityAddTraits(.isToggle)` (iOS 17+) **or** `.accessibilityRepresentation { Toggle(isOn: $isOn) { Text(.key) } }`, plus `.accessibilityAddTraits(isOn ? .isSelected : [])` is *not* the idiom — state for a toggle is the toggle value, for a selection it is `.isSelected`. Pick per semantic:

| Site | Semantic | Idiom |
|---|---|---|
| `EhSettingView+Sections3.swift:169-185` `ExcludeToggle` | on/off | `.accessibilityRepresentation { Toggle(.excludeX, isOn: $isOn) }` — gives label, value ("on"/"off"), trait, and Voice Control name in one move |
| `LaboratorySettingView.swift:52-75` feature cell | on/off | same representation, or `Button` + `.isToggle` trait + `.accessibilityValue` |
| `CategoryView.swift:74-100` `CategoryCell` | selected/filtered | `Button` + `.accessibilityAddTraits(isFiltered ? [] : .isSelected)` (note inverted sense: `isFiltered == true` means *excluded*) |
| `AppearanceSettingView.swift:106-118` `AppIconRow` | selected | `Button` + `.accessibilityAddTraits(isSelected ? .isSelected : [])`; hide the checkmark image |

### Pattern 4: Reduce Motion gating (house pattern)

**What:** Read the environment, substitute a dissolve or `nil`.
**When to use:** the in-scope motion sites (see Reduce Motion inventory).

```swift
// Source: repo — View+Toast.swift:34-105, DownloadsView+Subviews.swift:129-131, ViewModifiers.swift:10-20
@Environment(\.accessibilityReduceMotion) private var reduceMotion

private var toastAnimation: Animation { reduceMotion ? .easeInOut(duration: 0.15) : .bouncy }
private var toastTransition: AnyTransition { reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity) }

// Modifier form:
.animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: pages.count)

// Spinning icon (DetailView+HeaderSection.swift:137-141, 158): Apple names spinning explicitly — replace with a
// static symbol + .symbolEffect(.pulse) or ProgressView when reduceMotion, never just "slower".
```

### Pattern 5: Adaptive badge text colour (D-26)

```swift
// Source: SwiftUICore swiftinterface (Color.resolve(in:), Color.Resolved.linearRed/Green/Blue) + WCAG 2.x formula
import SwiftUI

extension Color.Resolved {
    /// WCAG 2.x relative luminance. `Color.Resolved` already stores linearised sRGB channels.
    public var relativeLuminance: Double {
        0.2126 * Double(linearRed) + 0.7152 * Double(linearGreen) + 0.0722 * Double(linearBlue)
    }
}

extension Color {
    /// WCAG contrast ratio between two resolved colours, ≥ 1.
    public static func contrastRatio(_ a: Color.Resolved, _ b: Color.Resolved) -> Double {
        let (hi, lo) = a.relativeLuminance >= b.relativeLuminance
            ? (a.relativeLuminance, b.relativeLuminance)
            : (b.relativeLuminance, a.relativeLuminance)
        return (hi + 0.05) / (lo + 0.05)
    }

    /// Black or white, whichever contrasts more with `self` in `environment`.
    /// The two ratios cross at L = √0.0525 − 0.05 ≈ 0.1791, where both equal ≈ 4.583:1 —
    /// so the chosen colour is never below 4.58:1 for any background.
    public func contrastingForeground(in environment: EnvironmentValues) -> Color {
        resolve(in: environment).relativeLuminance > 0.1791 ? .black : .white
    }
}

// CategoryLabel (CategoryView.swift:28-37):
@Environment(\.self) private var environment
Text(text)
    .font(font.bold())
    .lineLimit(1)
    .foregroundStyle(color.contrastingForeground(in: environment))   // was .white
```

`@Environment(\.self)` hands the view its full `EnvironmentValues`, which carries `colorScheme` and `colorSchemeContrast`, so the asset colour resolves to the correct one of its four variants — including the `contrast: high` entries — and the foreground follows automatically. Use the **better-of** rule, not "white unless it fails": it is the only rule with the 4.58 floor, and it is what D-26's "47 flip" count corresponds to (a "white unless < 4.5" rule would flip 45 and have no structural floor beyond 4.5).

### Pattern 6: Colorset invariant test (D-26 regression protection)

```swift
// Source: repo pattern — DownloadLogPrivacyInvariantTests.repositoryRoot()/scannedFiles(); colorset JSON schema observed in App/Assets.xcassets
@Suite struct CategoryColorsetInvariantTests {
    // 1) Walk App/Assets.xcassets/Category/Colors/{E-Hentai,ExHentai}/*.colorset/Contents.json from the repository root.
    // 2) Parse each `colors[]` entry: appearances → variant key (light | dark | high | dark+high);
    //    components red/green/blue are STRINGS in one of THREE encodings — "0.910" (0…1 float),
    //    "0x11" (hex byte), "163" (decimal byte, ExHentai/Cosplay only) — normalise all three.
    //    Assert color-space == "srgb" (every variant is today).
    // 3) Known-member guard: require exactly 84 variants and that ExHentai/Game CG/light is present
    //    (so an empty walk cannot pass vacuously).
    // 4) For each variant: luminance via the same linearisation as Color.Resolved
    //    (c ≤ 0.04045 ? c/12.92 : ((c+0.055)/1.055)^2.4) → assert max(ratioWhite, ratioBlack) ≥ 4.5.
    // 5) Byte-identity: SHA-256 over the concatenated Contents.json bytes (sorted by path) == pinned hex.
    //    A colour edit (including D-27's HC re-authoring, if done) must re-pin deliberately.
}
```

Running the helper's Swift implementation of (4) against the parsed JSON and comparing to the Python-derived table in this file (worst 4.62, 47 flips) is the acceptance check for the helper itself.

### Pattern 7: `performAccessibilityAudit()` on the `UITests` plan

```swift
// Source: XCUIAutomation swiftinterface (Xcode 26.6) + repo EhPandaUITests/Support/DeepLinkLauncher.swift
import XCTest

@MainActor
final class AccessibilityAuditUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testGalleryDetailAudit() throws {
        let app = XCUIApplication()
        try app.openCold(try XCTUnwrap(UITestConstants.galleryURL(scheme: "ehpanda")))   // hermetic fixture, no login
        app.requireElement("detail_view")
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .hitRegion, .trait, .contrast, .textClipped, .dynamicType]) { issue in
            // return true ONLY for a documented, owner-approved exclusion; log everything
            print(issue.compactDescription, issue.detailedDescription)
            return false
        }
    }
}
```

No `#available` guard: the deployment target is iOS 26 (`IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `Package.swift` `platforms: [.iOS(.v26)]`), so the skill template's iOS 17 guards would be dead code and the user's "prefer modern APIs" rule applies.

### Anti-Patterns to Avoid
- **`.accessibilityLabel` on a control that already has visible text** — overrides the automatic label and desynchronises Voice Control ("Tap Send" fails when the label says "Submit"). Only icon-only and custom elements get labels.
- **State in the label** (`"Favorited"` vs `"Not favorited"`) — use `.isSelected` / toggle representation; the existing `favoriteButton` (HeaderSection:162-190) already does this right by swapping two `Label`s.
- **Gating opacity crossfades and `numericText`** — out of scope per D-29; it flattens motion Apple never asked to flatten and changes nothing vestibular.
- **A `dynamicTypeSize` regex that matches the environment read** — `\.dynamicTypeSize\b` would block the owner's reflow; the verified form is `\.dynamicTypeSize\s*\(` (modifier only).
- **`xcrun simctl ui booted …`** with two booted simulators — `booted` silently resolves to one of them (it resolved to the iPad in this session while the iPhone was the intended target). Always pass the UDID.
- **Running `xcodebuild test` (UI tests) or `simctl erase`/`uninstall` against the logged-in simulator** — reinstalling is probably safe, erasing is not; the plan must name a *different* simulator for the UI-test audit.
- **`sim-use gesture rotate-cw` for orientation** — it is a two-finger content rotation. Use `agent-device orientation`.
- **Hand-rolled WCAG math from gamma-encoded `Color.Resolved.red/green/blue`** — the struct's stored fields are already linear; reading `.red` and linearising again double-decodes.
- **Committing any image** (D-32).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Custom toggle semantics | Label + value + trait triple by hand | `.accessibilityRepresentation { Toggle(...) }` | One modifier yields label, value, trait, Voice Control name and the adjustable action. |
| Menu selection state | `Text + Image(.checkmark)` inside each `Button` (ToolbarItems.swift:132-140, 160-168, 188-196; ControlPanel.swift:196-230) | `Picker` with `.pickerStyle(.menu)`/inline inside the `Menu` | Renders the same checkmark and announces "selected" as a trait; avoids hand-labelling 3 menus × N items. Verify appearance parity at `.large` before swapping. |
| Dynamic Type switching | Driving the Settings app | `xcrun simctl ui <UDID> content_size` | Verified live; no relaunch needed. |
| Device rotation | AppleScript keystrokes | `agent-device orientation <o>` | Scriptable, no macOS permission dance. |
| Label/trait inspection on the simulator | Guessing from source | Accessibility Inspector (Xcode → Open Developer Tool) inspection mode + `agent-device snapshot` / `sim-use ui` | Reads the real AX tree SwiftUI produced. |
| Audit engine | Custom XCUITest assertions per element | `performAccessibilityAudit()` | Apple's Inspector engine: labels, contrast, hit regions, traits, Dynamic Type, clipping. |
| Luminance | Per-site hex tables | `Color.resolve(in:)` + `Color.Resolved.linear*` | Resolves the asset's *current* variant (light/dark/HC) for free. |
| Repository-root file walks in tests | Ad-hoc `#filePath` arithmetic | The `repositoryRoot()` / `knownMembers` pattern from `DownloadLogPrivacyInvariantTests` | Refuses vacuous walks; already proven. |

**Key insight:** SwiftUI's native controls give VoiceOver and Voice Control everything for free; nearly all of round 2's real work is (a) replacing the 10 custom tappables with native semantics, (b) labelling the ~14 genuinely icon-only controls from catalog keys, and (c) gating ~20 motion sites. Custom machinery would be slower *and* less correct than the framework.

## Runtime State Inventory

Not applicable — this is not a rename/refactor/migration phase. Explicitly: no stored data, live service config, OS-registered state, secrets, or build artifacts embed anything this phase changes. The one runtime-state item is **phase infrastructure**, not code: the owner's logged-in simulator data container (D-09), which every plan must leave untouched (no `erase`, no `uninstall`, no `clear-app-state`).

## Round-1 verification mechanics (focus area 1)

### What exists on this machine `[VERIFIED: probed 2026-08-23]`

| Item | State |
|---|---|
| Xcode | 26.6 (17F113); SDK iPhoneSimulator26.5 |
| Booted simulators | iPhone Air `ADE09605-A44E-4F00-BE12-235970217355` (iOS 26.5, content_size was `medium`, appearance `dark`, increase_contrast `disabled`); iPad Pro 11-inch (M5) `8250D97E-9AB0-42FD-99DB-07B0094BF8C7` (iOS 26.5, content_size `large`) |
| Other simulators | iPhone 17e `88B217DA…` (iOS 26.4); iPhone Air `BE5CFCC0…` + iPad Pro 11 `B3BA322D…` (iOS 27.0) — candidates for the UI-test audit so the logged-in sim is never touched |
| EhPanda installs | Both booted sims carry `app.ehpanda` **and** `app.ehpanda.personal` (`$(BUNDLE_ID_SUFFIX)` build variant); the iPad also carries `app.ehpanda.UITests.xctrunner`. **The owner must say which bundle id holds the login** — `agent-device open app.ehpanda` vs `app.ehpanda.personal` is not guessable. |
| Physical devices | `Owner-iPhone-Test` (iPhone 11, connected) and `Owner-iPhone` (iPhone 16 Pro, paired) — the VoiceOver / Voice Control walkthrough surface |
| `agent-device` | 0.20.8 — `orientation`, `open --foreground` (returns AX snapshot), `press/scroll --settle`, `screenshot`, `settings appearance light|dark` |
| `sim-use` | 0.13.0 — `ui` (AX outline with `@N`), `tap --label`, `gesture scroll-up`, `screenshot` |
| Accessibility Inspector | present in the Xcode bundle |
| SwiftLint | 0.65.0 artifact binary under `$HOME/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/…/macos/swiftlint` (not on PATH) |

### Does the app pick up `content_size` live?

Yes for the system: setting AX5 on the iPhone Air re-rendered SpringBoard's icon labels at accessibility size within ~1 s, no reboot, no relaunch `[VERIFIED: screenshot compared in-session; the sim was restored to `medium` afterwards]`. A running SwiftUI app re-lays out on the same `UIContentSizeCategory.didChangeNotification`; EhPanda was not running during the probe, so in-app live update is `[ASSUMED]` (A1) — the first sweep pass should confirm it once and record it. If a screen ever fails to re-layout live, `agent-device open --relaunch` is the fallback and costs nothing (the data container persists).

### Orientation

`agent-device orientation portrait|portrait-upside-down|landscape-left|landscape-right` `[VERIFIED: help text]`. Read back via the `App:` header tag in `sim-use ui` output (shows `(landscape-right)`), or `agent-device snapshot`. Landscape at AX5 is the harshest cell (D-10); iPad landscape also flips `isRegularWidthPad` layouts, so it is a genuinely different surface.

### Which driver for a 12-pass × ~42-screen sweep

Recommend **`agent-device`** as the primary driver: it owns orientation, returns an AX snapshot diff after every `--settle` action (which doubles as a cheap "did the label truncate?" signal — truncated `Text` still reports its full label, so the *screenshot* is the verdict basis, not the snapshot), and writes screenshots to an explicit path. Use `sim-use ui` when a `@N` alias outline is handier for dense lists. Either way: one simulator action at a time, screenshots only under the scratchpad, and re-run `ui`/`snapshot` after every navigation (alias caches go stale). Per the skill pitfalls: a rotated device needs a fresh `ui` before tapping.

### Resumability (Claude's discretion, recommended shape)

Make `16-SWEEP.md` the state: one row per (screen, device, orientation, size) with status `pending | pass | finding:#N | re-verify | accepted`. A session resumes by reading the first `pending`/`re-verify` row. Re-verification after owner fixes: **batched per owner commit** — the owner's fix commit touches files; map files → screens via the inventory's "files" column; re-walk only those rows at the three sizes, mark `pass` or re-open the finding. A full 12-pass re-sweep is only for the phase gate.

### Evidence discipline

- Screenshot path root: the session scratchpad (`/private/tmp/claude-501/…/scratchpad/` in this session; any `/tmp` path is fine, a repo path is not).
- Verdict table rows carry a *written* description ("uploader name ellipsised at AX3 portrait; full value visible at .large"), never a filename that implies the image is recoverable from the repo.
- Before/after images go to the owner in chat (D-33).

## Screen inventory, re-derived (focus area 2 / D-12)

Counting rule (Claude's discretion): a **screen** is a distinct SwiftUI surface the user can land on — a tab root, a pushed path element, a sheet, a full-screen cover, a popover/menu, an alert/confirmation dialog, or a toast. Cells are counted with their hosting list, not separately; the five gallery-list hosts (Frontpage, Popular, Watched, Favorites, Search results) share `GalleryList` + `GalleryDetailCell`/`GalleryThumbnailCell`, so a cell finding is recorded once and tagged "all list hosts". Menus (`Menu { … }`) are counted as popover surfaces because at AX5 their item text reflows too.

| # | Screen / surface | Route (how to reach) | Primary files | Login-gated | Fixture-reachable (UI test) | D-11 |
|---|---|---|---|---|---|---|
| 1 | Tab bar shell | launch | `AppFeature/View/TabBar/TabBarView.swift` (4 presentation sites) | no | yes | in |
| 2 | Home (root: hero carousel + sections) | Home tab | `HomeFeature/HomeView.swift`, `HomeView+Sections.swift`, `GalleryCardCell.swift`, `GalleryRankingCell.swift` | no (popular only) | yes (`FrontPageList.html` serves `/` and `/popular`) | in |
| 3 | Home › Frontpage | push | `HomeFeature/Frontpage/FrontpageView.swift` (+ Filters, DateSeek sheets) | no | yes | in |
| 4 | Home › Popular | push | `Popular/PopularView.swift` | no | yes | in |
| 5 | Home › Watched | push | `Watched/WatchedView.swift` (login placeholder vs list) | **yes** | no fixture | in |
| 6 | Home › History | push | `History/HistoryView.swift` (+ clear alert) | no | yes (local) | in |
| 7 | Home › Toplists (+ type menu) | push | `Toplists/ToplistsView.swift`, `ToolbarItems.swift` `ToplistsTypeMenu` | no | partial | in |
| 8 | Favorites (root, index menu, sort menu) | Favorites tab | `FavoritesFeature/FavoritesView.swift`, `ToolbarItems.swift` | **yes** | no | in |
| 9 | Search root (history keywords, quick-search chips) | Search tab | `SearchFeature/SearchRootView.swift`, `SearchRootView+Keywords.swift`, `GalleryHistoryCell.swift` | no | yes (local) | in |
| 10 | Search results | submit | `SearchFeature/SearchView.swift` | no | no fixture (`/?f_search=`→404) | in |
| 11 | Downloads (root, rows, swipe actions, confirm dialogs) | Downloads tab | `DownloadsFeature/DownloadsView.swift` | no | yes (empty state) | in |
| 12 | Downloads › Inspector sheet | row inspect | `DownloadsView+Subviews.swift` `DownloadInspectorView` | no | needs a download | in |
| 13 | Downloads › Move-to-folder / FolderManager | row action | `DetailFeature/FolderManager/FolderManagerView.swift` | **yes** | no | in |
| 14 | Gallery Detail (header, stats strip, description, tags, previews, comments preview) | any list cell; deep link `ehpanda://e-hentai.org/g/<gid>/<token>/` | `DetailFeature/DetailView*.swift` (8 presentation sites) | **yes** (live) | **yes** (`GalleryDetail.html`) | in |
| 15 | Detail › Previews | push | `Previews/PreviewsView.swift` | yes | yes | in |
| 16 | Detail › Comments (+ post/edit sheet, vote actions) | push; deep link `…/#c<id>` | `Comments/CommentsView.swift`, `Components/PostCommentView.swift` | yes | yes (comment deep link) | in |
| 17 | Detail › Detail Search | tag tap | `DetailSearch/DetailSearchView.swift` | yes | no | in |
| 18 | Detail › Gallery Infos | push | `GalleryInfos/GalleryInfosView.swift` | yes | yes (static) | in |
| 19 | Detail › Archives sheet | header action | `Archives/ArchivesView.swift` | **yes** | no fixture | in |
| 20 | Detail › Torrents sheet | header action | `Torrents/TorrentsView.swift` | **yes** | no fixture | in |
| 21 | Detail › Tag Detail sheet | tag context menu | `Components/TagDetailView.swift` | no | yes | in |
| 22 | Detail › Share sheet / NewDawn sheet | header / greeting | `AppComponents/NewDawnView.swift` | — | — | share = system (out); NewDawn in |
| 23 | Detail › download confirm dialogs (delete / retry mode) | header download button | `DetailReducer+Download.swift`, `DetailView.swift` | yes | partial | in |
| 24 | Reading (paging stack, zoom/pan, tap zones) | Detail › Read; deep link `ehpanda://e-hentai.org/s/<token>/<gid>-<page>` | `ReadingFeature/ReadingView.swift`, `ReadingViewComponents.swift` | yes | **yes** (`GallerySinglePage.html`) | in |
| 25 | Reading › Control panel (upper/lower, slider preview, menus) | tap | `Support/ControlPanel.swift` | yes | yes | in |
| 26 | Reading › Reading Setting sheet | panel gear | `ReadingSettingFeature/ReadingSettingView.swift` | no | yes | in |
| 27 | Reading › share / Live Text overlay | panel | `Support/LiveTextView.swift` | — | — | share = system (out) |
| 28 | Setting root | Setting tab (push or modal on iPad per `isRegularWidthPad`) | `SettingFeature/SettingView.swift` | no | yes | in |
| 29 | Setting › Account (cookie state, logout confirm) | push | `AccountSetting/AccountSettingView.swift` | state varies | yes | in |
| 30 | Setting › Login (native form + WebView/challenge) | push | `Login/LoginView.swift` | no | native form only | native chrome in; WebView/Cloudflare out |
| 31 | Setting › General (analytics opt-out row, translations, cache, confirm dialogs) | push | `GeneralSetting/GeneralSettingView.swift` | no | yes | in |
| 32 | Setting › General › Activity Logs (+ detail sheet) | push | `AppActivityLogs/AppActivityLogsView.swift` | no | yes | in |
| 33 | Setting › Appearance (+ App Icon picker) | push | `AppearanceSetting/AppearanceSettingView.swift` | no | yes | in |
| 34 | Setting › Reading | push | `ReadingSettingFeature/ReadingSettingView.swift` | no | yes | in |
| 35 | Setting › Download | push | `Components/DownloadSettingView.swift` | no | yes | in |
| 36 | Setting › Laboratory | push | `Components/LaboratorySettingView.swift` | no | yes | in |
| 37 | Setting › About | push | `Components/AboutView.swift` | no | yes | in |
| 38 | Setting › EhSetting (native sections 1–3, delete-profile confirm) | push | `EhSetting/EhSettingView*.swift` | **yes** | no fixture | native in; web pages out |
| 39 | Filters sheet (category grid, advanced) | toolbar | `FiltersFeature/FiltersView.swift`, `AppComponents/CategoryView.swift` | no | yes | in |
| 40 | Quick Search sheet (+ editor) | toolbar | `QuickSearchFeature/QuickSearchView.swift` | no | yes | in |
| 41 | Date Seek picker | toolbar | `DateSeekFeature/DateSeekPickerView.swift` | no | yes | in |
| 42 | Error surface (`ErrorInfoView` sheet) + toasts | any failure / `toast_message` | `AppComponents/ErrorInfoView.swift`, `SystemNotification/ToastMessageView.swift`, `View+Toast.swift` | no | yes (malformed deep link produces the error) | in |

Additions since Phase 10's table: Cloudflare challenge destination in `LoginReducer.Destination.challenge` (out of scope, WebView), the analytics opt-out row in General Settings (#31), Phase 15's download inspector + validation rows + swipe/context actions + pause-refusal toast (#11–#13), the `SystemNotification` toast module (#42), and the Setting › App Icon picker. Login-gated surfaces that only the D-09 simulator can reach: #5, #8, #13, #19, #20, #38, and the *live* variants of #14–#18 / #23–#25 (the fixture variants are reachable without login but carry fixture content, not real galleries).

## D-04 re-judgement checklist (focus area 3)

### `lineLimit(1)` — 30 code sites (31 grep hits; `ToastMessageView.swift:78` is a comment) `[VERIFIED: grep]`

| File:line | What is clipped | Phase-10 verdict | D-04 status |
|---|---|---|---|
| `DateSeekFeature/DateSeekPickerView.swift:122` | picker row text | fine | re-judge |
| `SystemNotification/ToastMessageView.swift:65`, `:70` | toast title / subtitle | B1 fixed (toast) | re-judge (subtitle) |
| `SettingFeature/EhSetting/EhSettingView+Sections3.swift:131` | section value | B3 / fine | re-judge |
| `SettingFeature/AppActivityLogs/AppActivityLogsView.swift:224` | log category chip | fine | re-judge |
| `ReadingFeature/Support/ControlPanel.swift:176` | page indicator "n / total" | fine | **D-13 item: reader total-page counter wrap** |
| `HomeFeature/GalleryRankingCell.swift:39` | ranking cell subtitle | fine | re-judge |
| `SearchFeature/GalleryHistoryCell.swift:32` | history cell secondary | fine | re-judge |
| `GalleryListComponents/Cells/GalleryDetailCell.swift:107` | uploader | fine (secondary exemption) | **back in scope** |
| `GalleryDetailCell.swift:152`, `:163` | stats (with the 2 `minimumScaleFactor`s) | fine | **back in scope + D-14** |
| `GalleryListComponents/DownloadBadgeLabel.swift:19` | badge progress | fine | re-judge |
| `GalleryListComponents/Cells/GalleryThumbnailCell.swift:99` | thumbnail cell footnote | fine | re-judge |
| `AppComponents/TagCloudView.swift:122` | tag text | fine | **D-13 item: long-tag right-edge clip** |
| `AppComponents/CategoryView.swift:31` (`CategoryLabel`), `:87` (`CategoryCell`) | category name | fine | re-judge (D-15 collision for the 0.72 site) |
| `AppComponents/TagSuggestionView.swift:111`, `:116` | suggestion rows | fine | re-judge |
| `DetailFeature/DetailView+CommentCells.swift:37`, `:43` | comment author / date | fine | **back in scope + D-14** |
| `DetailFeature/DetailView+HeaderSection.swift:72` | header category label | fine | **D-14 0.72 site; D-15 parity** |
| `DetailView+HeaderSection.swift:324` | header secondary line | fine | re-judge |
| `DetailFeature/DetailView+Subviews.swift:99`, `:116` | stats strip values | fine | **D-13 item: Detail stats-strip abbreviation** |
| `DetailFeature/Comments/CommentsView.swift:166` | comment header | fine | **back in scope + D-14** |
| `DetailFeature/Torrents/TorrentsView.swift:110`, `:124` | torrent meta | "shrink-absorbed" | re-judge (no shrink any more) |
| `DetailFeature/Archives/ArchivesView.swift:143`, `:202` | funds / price | fine | re-judge |
| `QuickSearchFeature/QuickSearchView.swift:40` | quick-search name | fine | re-judge |

D-13's other two items map to: Favorites trailing-glyph clip → `FavoritesView.swift` toolbar/menu glyphs + `GalleryDetailCell` trailing symbols (`:140` `photoOnRectangleAngled`); hero-carousel title truncation → `HomeFeature/GalleryCardCell.swift:73` (`lineLimit(4)`).

### `minimumScaleFactor` — 5 sites, target 0 `[VERIFIED: grep + SwiftLint run]`

`GalleryDetailCell.swift:155` (0.75), `:166` (0.75), `DetailView+CommentCells.swift:42` (0.75), `DetailView+HeaderSection.swift:73` (0.72, the D-15 collision), `Comments/CommentsView.swift:165` (0.75).

### Fixed frames `[VERIFIED: grep]`

| Site | Kind | Note |
|---|---|---|
| `SettingView.swift:109` `frame(width: 45, height: 45)` | icon chrome | Phase 10 judged chrome OK; AX5 `.largeTitle` icon may exceed 45pt — re-check |
| `AppearanceSettingView.swift:146` `frame(width: 60, height: 60)` | app-icon image | chrome |
| `ControlPanel.swift:166`, `:296` `frame(width: 44, height: 44)` | touch targets | keep (44pt minimum) |
| `DownloadsView+Subviews.swift:145` `frame(width: 20, height: 20)` | progress spinner slot | chrome |
| `DetailView+CommentCells.swift:51` `frame(width: 300, height: cardHeight)` | comment card (`cardHeight` is `@ScaledMetric`) | width fixed at 300 — re-check at AX5 iPhone portrait |
| `GeneralSettingView.swift:69` `frame(width: 50)`; `EhSettingView+Sections2.swift:44` (10), `:164`, `:177` (200) | fixed widths | re-check: 200pt controls at AX5 |
| `View+Toast.swift:57` `minHeight: 44`; `StateViews.swift:49` `minHeight: 50` | minimums | fine |

## SwiftLint rules (focus area 4 / D-16–D-18, D-30)

### Existing config facts `[VERIFIED: read .swiftlint.yml]`

- `custom_rules` already holds **21** rules (CONTEXT's "8" counts the Phase 11 battery; `accessibility_empty_string`, `accessibility_text_argument`, `analytics_sdk_import_boundary`, `label_text_image_shorthand`, `system_name_image_parameter`, `shape_initializer_argument`, … landed since). All use `severity: error` and `excluded_match_kinds: [comment, string]` (+ `doccomment` where prose may quote the banned form). One rule uses `excluded:` (path regex) and one uses `match_kinds: [comment]` + `capture_group`.
- The existing `accessibility_text_argument` rule **bans `Text(` inside any accessibility modifier** and tells you to pass a `LocalizedStringResource` — which does not exist for `accessibilityInputLabels`. Use the `[String(localized: .key)]` form (StringProtocol overload) for input labels.
- The `swiftlint_disable_requires_reason` rule is the mechanical half of the 11-EXCEPTIONS protocol: a `// swiftlint:disable:next` without a preceding `// reason:` line is itself an error.
- Spelling trap documented inline three times: the kind is `doccomment`, not `doc_comment`; one invalid kind silently discards the whole rule.
- 50 nested `.swiftlint.yml` files each say `parent_config: ../../../.swiftlint.yml`; a rule added at the root applies everywhere.

### The five rules, validated

Run with the 0.65.0 artifact binary against `AppPackage/Sources App ShareExtension EhPandaUITests AppPackage/Tests` `[VERIFIED]`:

| Rule | Regex | Today | Fixture positives / negatives |
|---|---|---|---|
| `no_minimum_scale_factor` | `\.minimumScaleFactor\s*\(` | **5** (the D-14 sites, exact lines) | ✓ fires on `.minimumScaleFactor(0.5)`; silent in comments |
| `no_dynamic_type_size_modifier` | `\.dynamicTypeSize\s*\(` | **0** | ✓ fires on `.dynamicTypeSize(.large)` and `.dynamicTypeSize(...xxxLarge)`; **silent** on `@Environment(\.dynamicTypeSize)`, `dynamicTypeSize.isAccessibilitySize`, `dynamicTypeSize >= .accessibility1` |
| `no_geometry_reader` | `\bGeometryReader\b` | **0** | ✓ fires on `GeometryReader { … }`; silent in comments |
| `no_fixed_system_font_size` | `\.system\(\s*size:\s*[0-9]` | **0** | ✓ fires on `.system(size: 16)` and `.system(size:16.5, weight:)`; **silent** on `.system(size: size)` (`@ScaledMetric`-fed, the 5 live sites) and `.system(.body)` |
| `accessibility_hardcoded_string` (D-30 guard) | `\.accessibility(Label\|Value\|Hint\|InputLabels)\s*\(\s*\[?\s*"` | **0** | ✓ fires on `.accessibilityLabel("Hardcoded")`, `.accessibilityInputLabels(["Hard", "Coded"])`, `.accessibilityHint("x")`; silent on `.accessibilityLabel(.key)`, `(title)`, `(String(localized: …))`, `([.keyA, .keyB])` |

Exact YAML to append under `custom_rules:` (messages are suggestions; keep them in the house voice):

```yaml
  no_minimum_scale_factor:
    name: "No minimumScaleFactor"
    regex: '\.minimumScaleFactor\s*\('
    message: "minimumScaleFactor is banned (Phase 16 D-14): it is a Dynamic Type cap in disguise. Reflow instead — wrap, ViewThatFits, or stack at accessibility sizes."
    excluded_match_kinds:
      - comment
      - doccomment
      - string
    severity: error

  no_dynamic_type_size_modifier:
    name: "No dynamicTypeSize Modifier"
    # Matches the MODIFIER form only. `@Environment(\.dynamicTypeSize)` and property reads such as
    # `dynamicTypeSize.isAccessibilitySize` have no `(` after the name and stay legal (D-17).
    regex: '\.dynamicTypeSize\s*\('
    message: "Capping or clamping Dynamic Type with .dynamicTypeSize(...) is banned (Phase 10 D-02). Read @Environment(\\.dynamicTypeSize) and reflow instead."
    excluded_match_kinds:
      - comment
      - doccomment
      - string
    severity: error

  no_geometry_reader:
    name: "No GeometryReader"
    regex: '\bGeometryReader\b'
    message: "GeometryReader is banned (Phase 5). Use onGeometryChange, containerRelativeFrame, or ViewThatFits."
    excluded_match_kinds:
      - comment
      - doccomment
      - string
    severity: error

  no_fixed_system_font_size:
    name: "No Fixed System Font Size"
    # Numeric literals only (D-18); `.system(size: scaledMetricValue)` stays legal.
    regex: '\.system\(\s*size:\s*[0-9]'
    message: "A numeric-literal .system(size:) font does not scale with Dynamic Type. Use a text style, or feed the size from @ScaledMetric(relativeTo:)."
    excluded_match_kinds:
      - comment
      - doccomment
      - string
    severity: error

  accessibility_hardcoded_string:
    name: "Accessibility Hardcoded String"
    # Do NOT exclude `string` here: the violation IS the string literal.
    regex: '\.accessibility(Label|Value|Hint|InputLabels)\s*\(\s*\[?\s*"'
    message: "Accessibility strings must come from the string catalog (a generated LocalizedStringResource key) so they cannot drift from the visible text and stay localized in every locale (D-30)."
    excluded_match_kinds:
      - comment
      - doccomment
    severity: error
```

Sequencing constraint (D-14 × build plugin): `no_minimum_scale_factor` breaks every build until the owner's 5 removals land. Land it in the *same* commit as (or after) those removals; the other four can land immediately at zero. A negative-control probe (write the banned form in a scratch file, see the error, delete it) belongs in the plan's verification, matching the 11-EXCEPTIONS §1.2 pattern.

How errors surface: the `SwiftLintBuildToolPlugin` runs during every `xcodebuild build`; a custom-rule violation is an `error:` diagnostic with file:line:col in the build log, and the module fails to build. With `commit gate = clean build`, the rule is self-enforcing.

## Round-2 VoiceOver / Voice Control inventory (focus area 5)

### The 53 `Image(systemSymbol:)` sites, classified `[VERIFIED: grep + source read]`

| Class | Sites | Action |
|---|---|---|
| **Already inside a `Label` or `Button` with text / already labelled** (no work) | `ToastMessageView:47,51` (inside combined element), `SettingView:105` (Label icon), `LaboratorySettingView:63` (Label icon), `AppearanceSettingView:39,43` (labelled/hidden), `HomeView+Sections:466` (section icon next to text), `SearchRootView+Keywords:111`, `TagSuggestionView:94,101`, `DownloadBadgeLabel:14` (children ignored), `DownloadsView+Subviews:171` (combined), `HeaderSection:155` (labelled), `TorrentsView:81,88,95,102` (paired with text) | verify with Inspector only |
| **Decorative → `.accessibilityHidden(true)`** | `TagCloudView:117` (`.opacity(0)` spacer), `ViewModifiers:38` (chevron `withArrow`), `GalleryDetailCell:140`, `GalleryThumbnailCell:89`, `DetailView+Subviews:174` (`photoOnRectangleAngled` page glyphs next to the count), `AppActivityLogsView:212` (level dot — but see DWC), `ArchivesView:133,140` (G/C coin glyphs next to numbers), `GeneralSettingView:52` (warning glyph next to text), `ListNoticeView:21` | hide, or combine with sibling text via `.accessibilityElement(children: .combine)` |
| **Selection checkmarks inside `Menu` buttons** | `ToolbarItems:138,166,194`, `ControlPanel:201,209,228`, `DownloadsView:158` | replace with `Picker` in menu *or* `.accessibilityAddTraits(.isSelected)` on the button + hide the image |
| **State icons carrying meaning (need label/value, shape already differs)** | `AccountSettingView:175` (cookie valid/invalid), `EhSettingView+Sections3:176` (`ExcludeToggle`), `AppearanceSettingView:153` (app icon selected), `DetailView+CommentCells:29` / `CommentsView:156` (vote thumbs), `RatingView:60,65,70` (stars) | `RatingView` → `.accessibilityElement(children: .ignore)` + `.accessibilityLabel(.rating)` + `.accessibilityValue(.ratingOutOfFive(rating:))`; thumbs → label "Voted up/down"; toggles → Pattern 3 |
| **Icon-only controls that need a label** | `DateSeekPickerView:103` (nav arrows), `ControlPanel:214` (dual-page glyph), `:233` (timer), `DetailView+CommentCells:69` / `DetailView+Subviews:164` (`squareAndPencil` compose/edit), `HeaderSection:168` (heart menu label), `:228` (`centerSymbol` in progress ring), `FolderManagerView:81,90` | `.accessibilityLabel(.key)` from the module catalog |
| **Reference implementation** | `SFSafeSymbolsExt/SFSafeSymbols+LocalizedStringResource.swift:13` | the `Label(_ titleResource:systemSymbol:)` initialiser the whole app uses — why most buttons are already labelled |

### The 37 toolbar items `[VERIFIED: 19 `ToolbarItem(` + 18 `CustomToolbarItem` sites]`

Nearly all wrap `Button { } label: { Label(.key, systemSymbol:) }` or `ToolbarFeaturesMenu` (`Label(.more, systemSymbol: .ellipsisCircle).labelStyle(.iconOnly)`) — VoiceOver and Voice Control names come for free from the `Label` title. Audit them with Accessibility Inspector rather than editing: the only expected edits are `CustomToolbarItem`'s `HStack(spacing: 14)` (make sure it does not combine children into one element — it does not by default) and the three `Menu`s with checkmark items (above).

### The 10 `.onTapGesture` custom tappables `[VERIFIED: grep]`

| Site | Today | Disposition |
|---|---|---|
| `SettingView.swift:117` setting row (+ `onLongPressGesture`) | Label-based row, tap + long-press | Convert to `Button` (`.buttonStyle(.plain)`) or add `.isButton`; long-press alternative via `.accessibilityAction(named:)` if it does something user-visible |
| `LaboratorySettingView.swift:69` feature cell | custom toggle | Pattern 3 toggle representation |
| `AppearanceSettingView.swift:115` app-icon row | custom selectable | `Button` + `.isSelected`, hide checkmark image |
| `EhSettingView+Sections3.swift:180` `ExcludeToggle` | `Color.clear.overlay(Image)` + tap — **no label, no trait, no value** | Pattern 3 toggle representation (highest-priority VoiceOver blocker found) |
| `CategoryView.swift:96` `CategoryCell` | opacity-only selection, tap | `Button` + `.isSelected` (inverted sense) + haptics kept |
| `TagSuggestionView.swift:122` suggestion row | tap | `Button` |
| `CommentsView.swift:177`, `:182` link taps inside comment text | tap on `LinkedText` runs | `.accessibilityAction(named: link)` per link, or expose links via `accessibilityRotor("Links")` |
| `ArchivesView.swift:252` archive option cell | tap with `isDisabled` guard | `Button` + `.disabled(isDisabled)` |
| `DownloadsView+Subviews.swift:409` `DownloadListRow` | **already** `.isButton` + label | reference pattern; add `accessibilityAction`s for the swipe actions (pause/resume/delete) per Apple's VC criterion 2 |

Context menus (`.contextMenu` on tag cells, download rows, comment cells) must be exposed as custom actions per Apple's criteria; whether SwiftUI already surfaces `contextMenu` items as VoiceOver actions on iOS 26 is an Open Question to verify on the device walkthrough before adding duplicates.

### Reader (screen #24) specifics

Page turns are edge taps / swipes (`ReadingView.swift:147-163`: `SpatialTapGesture`, `MagnifyGesture`, `DragGesture`) with no button equivalent while the panel is hidden. Apple's VC criterion 2 and VO criterion 5 both require gesture alternatives: add `.accessibilityAction(named: .nextPage)` / `.previousPage`, `.accessibilityZoomAction` for pinch, and `.accessibilityScrollAction` only if the native `ScrollView` paging does not already satisfy "Scroll left/right" (it should — verify). The page indicator (`ControlPanel:172-176`) should carry `.accessibilityValue` so the slider reads "page 12 of 120"; the `Slider` itself gets a label.

### Focus and announcements

Existing: `@AccessibilityFocusState` on error toasts (`View+Toast.swift:37,61`). Needed: post-navigation focus is SwiftUI-automatic for `NavigationStack` pushes and `.sheet`; custom overlays (reader control panel, slider preview) need `accessibilityFocused` when shown. Async content (gallery detail loaded, download complete) → `AccessibilityNotification.Announcement(String(localized: .key)).post()` (iOS 17+; no fallback needed at the iOS 26 floor).

## Reduce Motion inventory (focus area 7 / D-29)

Counts `[VERIFIED: grep]`: 89 `.animation(`, 3 `withAnimation`, 4 `.transition(`, 11 `.contentTransition(` = 107; 5 `accessibilityReduceMotion` reads (`View+Toast:34`, `GalleryCardCell:13`, `ViewModifiers:10`, `DownloadsView+Subviews:13,152`).

### Out of scope by D-29 (leave ungated) — ~85 sites
- All 11 `.contentTransition(.numericText…)` and their paired `.animation(…, value:)` (DownloadSettingView:17-18, GeneralSettingView:122-123, ControlPanel:174, DownloadBadgeLabel:18-20, DetailView+Subviews:101-125, ArchivesView:130-138, DownloadsView+Subviews:180-190 — the last two already gated via `countAnimation`).
- All ~45 `.animation(.default) { $0.opacity(…) }` crossfades (loading/error/empty-state swaps in EhSettingView, GeneralSettingView, LoginView, AppActivityLogsView, ReadingViewComponents, FavoritesView, HomeView, WatchedView, GalleryList, StateViews, SubSection, DetailView, HeaderSection favourite swap, CommentsView, TorrentsView, ArchivesView, TagDetailView, DownloadsView, QuickSearchView, CommentCells:30).
- Colour-only animations: `CategoryView:90`, `ArchivesView:246` (background colour), `LaboratorySettingView:73`, `ArchivesView:40` (redacted).
- Already gated: toast (`View+Toast`), hero gradient (`GalleryCardCell` + `CardGradientView` freezes the Metal field and seeds the palette), privacy mask (`ViewModifiers`), inspector counts.

### In scope (gate → dissolve or `nil`) — ~20 sites
| Site | Motion | Replacement |
|---|---|---|
| `DetailView+HeaderSection.swift:137-141` + `:158` | **spinning** download icon (`rotationEffect` 0→360, `repeatForever`) during metadata preparation | Apple names spinning explicitly: under reduce motion show a static symbol with `.symbolEffect(.pulse)` or a `ProgressView`; never a slower spin |
| `DownloadsView+Subviews.swift:140-143` | `.transition(.opacity.combined(with: .scale(scale: 0.85)))` | `.opacity` only (the view already reads `reduceMotion`) |
| `ReadingView.swift:110` `.animation(.linear(0.1), value: gestureHandler.offset)`, `:113` (`scale`) | pan/zoom follow-through | `nil` under reduce motion (content still moves with the finger; only the eased settle is removed) |
| `ReadingView.swift:114` `showsPanel`; `ControlPanel.swift:100-101` (`showsSliderPreview`, `.offset(y: showsPanel ? 0 : 50)`) | panel slide in/out, preview pop | opacity crossfade |
| `ReadingView.swift:351` `withAnimation { scrollPositionID = … }` | animated page jump (slide across pages) | `withAnimation(reduceMotion ? nil : .default)` |
| `CommentsView.swift:93` `withAnimation { proxy.scrollTo(…) }` | animated scroll to a deep-linked comment | un-animated `scrollTo` |
| `EhSettingView+Sections3.swift:181` `withAnimation { isOn.toggle() }` | symbol swap | fine as crossfade; becomes moot if `ExcludeToggle` is rebuilt |
| `DetailView.swift:27-29` (`showsUserRating`, `showsFullTitle`, `galleryDetail`) | layout expand/collapse (height slides) | `nil` under reduce motion |
| List diff animations: `SearchRootView.swift:150-152`, `QuickSearchView.swift:75,87`, `FolderManagerView.swift:49-50`, `TorrentsView.swift:55`, `DownloadsView.swift:93`, `GeneralSettingView.swift:145-147`, `HomeView.swift:64` | row insert/remove/move slides | `nil` (instant) or `.opacity` transition |
| `ControlPanel.swift:180` `.animation(.default, value: title)` | title change (text cross-dissolve) | fine; keep |

Rule of thumb for the planner: anything that changes **position or size** (move/slide/scale/rotate, including implicit list diffs and height changes) is in scope; anything that changes only **opacity, colour, or digits** is out.

### Verifying Reduce Motion without a device

`simctl ui` has no Reduce Motion switch. Options, in order: Accessibility Inspector → Settings tab → Reduce Motion (affects the simulator live) `[CITED: skill testing-auditing.md; Apple Inspector docs]`; driving the simulator's Settings app (Accessibility › Motion) with `agent-device`; `xcrun simctl spawn <UDID> defaults write com.apple.Accessibility ReduceMotionEnabled -bool true` followed by an app relaunch `[ASSUMED]` (A2 — validate in Wave 0 before relying on it). The `#Preview` route does **not** work: `accessibilityReduceMotion`, `colorSchemeContrast`, `accessibilityDifferentiateWithoutColor` are read-only environment values and `.environment(\.accessibilityReduceMotion, true)` is silently ignored `[CITED: skill testing-auditing.md]`.

## Contrast (focus area 8 / D-26–D-28)

### Formula `[CITED: WCAG 2.x via skill display-settings.md; linearisation matches `Color.Resolved`]`
- sRGB channel c → linear: `c ≤ 0.04045 ? c/12.92 : ((c+0.055)/1.055)^2.4`
- L = 0.2126 R + 0.7152 G + 0.0722 B
- ratio = (L_hi + 0.05) / (L_lo + 0.05); text 4.5:1, large text (≥ 18pt regular / ≥ 14pt bold) 3:1, non-text 3:1.
- Crossover where black and white tie: (L+0.05)² = 1.05 × 0.05 → L = 0.17913, ratio 4.583.

Badge text is `.footnote.bold()` (13pt) in cells and `.headline` (17pt semibold) in the Detail header — both below the 18pt/14pt-bold "large text" line, so **4.5:1 applies everywhere**, including at AX5 (the threshold is about *minimum* size; scaling up only helps).

### Re-measured numbers `[VERIFIED: computed from the 84 colorset entries this session]`

| Metric | Value |
|---|---|
| Variants | 84 (11 categories × 2 hosts × 4, minus `Private` which has only light/dark: 22 colorsets, 20 × 4 + 2 × 2) |
| White text below 4.5:1 | **45 / 84** |
| Best-of-black/white below 4.5:1 | **0 / 84** |
| Worst best-of | **4.62:1 — ExHentai / Game CG / light** (white 4.55, black 4.62) |
| Variants where black beats white (L > 0.1791) | **47** (two of them pass with white too: E-Hentai Asian Porn dark+high 4.51, ExHentai Game CG light 4.55) |
| HC variants with lower white-text contrast than their standard sibling | **40 / 40** (CONTEXT said "nearly every"; it is every one) |
| HC variants with lower *best-of* contrast than standard | 19 / 40 — so after D-26, Increase Contrast still makes half the badges slightly less contrasty (D-27's should-fix) |
| Examples (white→black): E-Hentai Manga light 2.56→8.21, HC 1.78→11.78; Artist CG light 1.93→10.90, HC 1.37→15.36; Western light 2.30→9.13, HC 1.92→10.92 | matches D-27's cited values |

### Colorset facts the test must handle `[VERIFIED: read JSON]`
- Path: `App/Assets.xcassets/Category/Colors/{E-Hentai,ExHentai}/<Category>.colorset/Contents.json`; appearance keys `luminosity: dark`, `contrast: high`, both, or none.
- Component strings come in **three encodings** across the 84 entries: 156 hex bytes (`"0x11"`), 90 floats (`"0.910"`), 6 decimal bytes (`"163"`, ExHentai/Cosplay only). A parser that handles only two produces luminance 34750 for Cosplay (observed). All `color-space` values are `srgb`.
- Byte-identity pin: hash the 22 `Contents.json` files in sorted-path order; D-27's re-authoring, if ever done, must re-pin on purpose.
- Resolution path at runtime: `Category.color(host:)` → `Color("E-Hentai/Manga")` from the **main bundle** (`AppModels/Gallery/Category.swift:25`), i.e. the app target's catalog; tests in `AppPackage` cannot resolve it by name, which is why the JSON walk is the right test surface.

### Where the rule lives (Claude's discretion → recommendation)
`AppTools` (`Color+Contrast.swift`): pure `Color.Resolved` math, no UI. `AppComponents` already imports `AppTools`; `AppModels` should not grow view-environment code. Unit-test the helper in `AppToolsTests` with hand-built `Color.Resolved` values (black, white, the crossover, the worst variant).

### The second white-on-category site
`CategoryView.swift:84` **`CategoryCell`** (Filters sheet) draws `.foregroundStyle(.white)` on `category.color(host:).opacity(isFiltered ? 0.3 : 1)`. It needs the same adaptive rule — and because the filtered state dims the background to 30 % over the sheet background, resolve against the *composited* colour or drop the opacity trick in favour of a distinct selected/unselected treatment; measure both states. The other `.white` sites (`NewDawnView:107` on a drawn yellow/orange canvas, `HeaderSection:196` read button on `.glassProminent` accent) are D-28 items to measure, not category sites.

### Non-category inventory (D-28) `[VERIFIED: grep]`
16 `Color(.systemGray…)` (tag chips `systemGray5` bg with `.primary` text — passes; `AppActivityLogRow` chip), 29 `.tint(` (swipe actions teal/orange/indigo/red — Apple colours on system backgrounds, measure the text-on-tint), 0 hex literals in views (the "2 hex literals" are in `AppTools/ColorCodable.swift` encoding, not rendering). Known risk items: `.secondary` text on `glassEffect` (toast, Laboratory cells — 17 `glassEffect`/material sites; Apple's criteria require the Reduce Transparency check), `.yellow` rating stars on white/black (non-text, 3:1: `.yellow` on white is ~1.3:1 — a real finding unless the stars are judged decorative duplicates of the numeric rating shown next to them), `.orange` offline notice text (`DetailView:281`, orange on white ≈ 2.9:1 at `.subheadline.semibold` — likely fails 4.5:1), log-level dots (non-text, colour-only — see DWC).

## Differentiate Without Color audit (focus area 9 / D-20)

| State | Site | Non-colour carrier today | Verdict |
|---|---|---|---|
| Download status badge | `DownloadBadgeLabel` | symbol per status + progress text | pass (reference) |
| Inspector page-group status | `DownloadsView+Subviews:171` | `status.symbol` + title text | pass |
| Detail download button status | `HeaderSection:155-158, 292-303` | symbol per status (`trash`, `arrow…rotate90`, `wrench`, `exclamationmarkCircle`, `playFill`, `icloudAndArrowDown`) + label | pass |
| Favourited | `HeaderSection:162-190` | `heart` vs `heartFill` | pass |
| Rating | `RatingView` + numeric rating text | fill level is shape; number alongside | pass (but contrast, above) |
| Comment vote | `CommentCells:29`, `CommentsView:156` | thumbs up vs down glyph | pass |
| Cookie validity | `AccountSettingView:175` | `xmarkCircle` vs `checkmarkCircle` | pass |
| Exclude toggle | `EhSettingView+Sections3:176` | `nosign` vs `circle` | pass visually; VO/VC fail (no semantics) |
| Toast success/error | `ToastMessageView:47-53` | checkmark vs warning triangle | pass |
| Offline notice | `DetailView:277-281` | wifi glyph + text | pass |
| **Activity log level** | `AppActivityLogsView:212` + `AppActivityLog.swift:74-80` | **colour-only dot** (indigo/blue/gray/orange/red) | **fail** → add level text (e.g. "error") or distinct symbols per level; smallest parity-preserving fix: keep the dot, add `.accessibilityLabel` *and* a visible level glyph variant (`circle.fill` / `exclamationmark.circle.fill` / `xmark.octagon.fill`) |
| **Filter category selected/excluded** | `CategoryCell` opacity 0.3 | luminance only | grayscale-survivable (brightness differs) but weak; VO has no `.isSelected` → fix with trait; consider a strike-through or `nosign` overlay for excluded, measured at `.large` for parity |
| **Laboratory feature on/off** | `LaboratorySettingView:52-55` | tint vs `.secondary` text + tinted vs gray background | luminance differs; add toggle semantics; grayscale test decides whether a glyph is needed |
| Swipe action kinds | `DownloadsView:203-230` | each has a `Label` with text | pass |
| Links in comments | `LinkedText` | verify underline/weight, not colour alone | audit |

The grayscale test (Settings › Accessibility › Display & Text Size › Colour Filters › Grayscale) has no `simctl` switch; drive the Settings app or use the device. Record the pass per screen in the same verdict table.

## `performAccessibilityAudit()` (focus area 6 / D-31)

### API `[VERIFIED: Xcode 26.6 XCUIAutomation swiftinterface + headers]`
`@MainActor func performAccessibilityAudit(for auditTypes: XCUIAccessibilityAuditType = .all, _ issueHandler: ((XCUIAccessibilityAuditIssue) throws -> Bool)? = nil) throws` on `XCUIApplication`, iOS 17+. Types: `.contrast`, `.elementDetection`, `.hitRegion`, `.sufficientElementDescription` (all platforms); `.dynamicType`, `.textClipped`, `.trait` (iOS); `.action`, `.parentChild` (macOS only); `.all`. `XCUIAccessibilityAuditIssue`: `element: XCUIElement?`, `compactDescription`, `detailedDescription`, `auditType`. Handler returns `true` to ignore.

### Wiring `[VERIFIED: read UITests.xctestplan, project.pbxproj, EhPandaUITests/Support]`
- `UITests.xctestplan` already targets `EhPandaUITests` (bundle `app.ehpanda.UITests`, `TEST_TARGET_NAME = EhPanda`), `retryOnFailure` × 3, and is attached to the `EhPanda` scheme alongside the default `FeatureTests` plan. A new `AccessibilityAuditUITests.swift` in the target is picked up with **no plan edit**.
- Run: `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests -destination 'platform=iOS Simulator,id=<NOT the logged-in sim>'`. Sequential with every other `xcodebuild test` on this machine.
- Support already present: `XCUIApplication.launchStubbed(extraEnvironment:)`, `openCold(url)`, `openWarm(url)`, `requireElement(id)`; `UITestConstants` with gallery/single-page/comment deep links; launch env `EHPANDA_UITEST_STUB_NETWORK=1` + `EHPANDA_UITEST_FIXTURE_DIR`; `-AppleLanguages (en)` is forced — matches D-30's English verification.
- Non-credential launch seams that *are* fine to use: `EHPANDA_AUTOMATION_TAB` (start on a tab) and `EHPANDA_AUTOMATION_GALLERY_URL` (open a gallery at launch) in `AppLaunchAutomationClient/AppLaunchAutomation.swift:50-62`. The `IPB_*`/`IGNEOUS` keys are off limits (D-09).

### Reachability — say it plainly
The UI-test install is hermetic: `UITestStubURLProtocol` answers `/g/*` with `GalleryDetail.html` (or `…Alt`), `/s/*` with `GallerySinglePage.html`, `/` and `/popular` with `FrontPageList.html`, everything else 404. **The audit can reach Home, Frontpage/Popular lists, Detail, Previews, Comments (via the `#c<id>` deep link), Gallery Infos, Reading + control panel + reading settings, all Setting screens, Filters/QuickSearch/DateSeek, Downloads (empty state), History, the error surface and toasts — without any credential.** It **cannot** reach Favorites, Watched, Archives, Torrents, EhSetting native sections, Folder Manager, or live comment/tag voting, because no fixture exists for those responses. Two honest options for the plan: (a) scope the automated audit to the reachable set and cover the rest by the manual device walkthrough plus Inspector on the logged-in simulator; (b) add hermetic HTML fixtures for favorites / archiver / torrents pages (they are just parser inputs — no credential involved) and extend `fixtureName(for:)`. (b) is cheap and permanent; recommend it as a stretch task, not a gate.

### Caveats
- The `.dynamicType` audit type changes the app's text size during the audit and checks for clipping; run it on a throwaway simulator, not the D-09 one, and expect it to surface round-1 regressions as a side effect `[CITED: skill testing-auditing.md; WWDC23 "Perform accessibility audits for your app"]`.
- Contrast audits produce false positives on text over images/gradients (hero carousel, reader). Use the issue handler to *log* and, only with an owner-approved written reason, ignore — never a blanket `return true`.
- `performAccessibilityAudit` audits what is on screen; each test must navigate, `requireElement`, then audit. Scroll and audit again for long screens.

## Nutrition Label criteria (focus area 10) `[CITED: App Store Connect help, fetched 2026-08-23]`

Source pages: `developer.apple.com/help/app-store-connect/manage-app-accessibility/` → `overview-of-accessibility-nutrition-labels`, `larger-text-evaluation-criteria`, `voiceover-evaluation-criteria`, `voice-control-evaluation-criteria`, `sufficient-contrast-evaluation-criteria`, `reduced-motion-evaluation-criteria`, `differentiate-without-color-alone-evaluation-criteria` (a `dark-interface-evaluation-criteria` sibling exists; not fetched).

**Global rule:** "users must be able to complete all of the common tasks of your app using that feature" — common tasks = primary functionality, first launch, login, purchase (n/a), settings. Labels are answered **per device** in App Store Connect (iPhone and iPad separately) — which is exactly why D-10's iPad passes matter. Inaccurate labels violate Review Guideline 2.3.

| Category | Apple's pass criteria (condensed, official wording where possible) | EhPanda common tasks to prove |
|---|---|---|
| **Larger Text** | Text enlarges to ≥ 200 % or the system max; body text in primary views scales without overlap or "severe truncation"; wrap rather than truncate; if truncation is unavoidable the full text is reachable in another view; hierarchy preserved; test at the accessibility sizes and across languages | browse lists, open detail, read, download, search, settings, login form |
| **VoiceOver** | Concise labels on all controls (no type/state in the label); type and state via traits; all visible text speakable; banners/alerts announced via `AccessibilityNotification`; navigation complete and logical, no skips/loops, no cursor reset on reload, focus moves into new screens/modals; activation gesture equals tap; context menus and gestures as custom actions; modals trap; custom elements equivalent to native | same list + reader page turns, comment/tag actions, download management |
| **Voice Control** | Every tappable under "Show numbers" and "Show names"; names match visible text; swipes/long-presses/hidden UI via custom actions; "Scroll down" works; dictation/select/delete in every text field; auto-hide delays cancellable | reader control panel auto-hide, swipe actions on downloads, search field, login fields, filters |
| **Sufficient Contrast** | 4.5:1 text, 3:1 non-text/controls/state markers, **by default**; both light and dark; verified with **Bold Text + Increase Contrast + Reduce Transparency all enabled**; translucency considered; Increase Contrast support itself is optional but must not *reduce* contrast | badges (D-26), toasts on glass, secondary text, tints, stars |
| **Reduced Motion** | Disable depth/parallax/animated blur; remove or replace spinning/vortex/multi-axis; stop auto-advancing carousels (or give a control); meaningful animations **replaced** by dissolve/highlight/colour shift, decorative ones removed; detect the system setting | spinning download icon, panel slides, page jumps, list diffs, hero gradient (already frozen) |
| **Differentiate Without Color Alone** | No colour as the sole differentiator; add placement/shape/iconography/text; grayscale filter test; design this way by default | log-level dots, filter selection, laboratory toggles |
| **Dark Interface** | Responds to system Dark Mode (or dark by default), consistent, contrast holds in dark | expected to pass; verify during the contrast pass in `appearance dark` |
| Captions / Audio Descriptions | Do not claim without video/audio content | N/A |

Closing artifact: use the skill's recommendation template (`SKILL.md` §"Prepare Nutrition Label recommendation") — per-task × per-category matrix, "could claim / should not claim" with reasons; phrase as a recommendation, never as a claim.

## Common Pitfalls

### Pitfall 1: Ambiguous `booted`
**What goes wrong:** `xcrun simctl ui booted …` targets whichever booted device CoreSimulator picks (here: the iPad while the iPhone was meant).
**How to avoid:** Always the UDID. Record both UDIDs in the plan.
**Warning signs:** `content_size` read-back does not match what you just set.

### Pitfall 2: Leaving the owner's simulator in a changed state
**What goes wrong:** the sweep ends with the sim at AX5 / landscape / dark, and the owner's next manual session is confusing.
**How to avoid:** read and record `content_size`, `appearance`, `increase_contrast`, orientation at the start; restore at the end of every session (`medium` was the iPhone Air's value).

### Pitfall 3: Erasing the login
**What goes wrong:** `simctl erase`, `agent-device settings clear-app-state`, `xcrun simctl uninstall`, or a UI-test run that reinstalls on the D-09 simulator.
**How to avoid:** the plan names the UI-test simulator explicitly (iPhone 17e or the 27.0 pair) and forbids the four commands on the logged-in UDID.

### Pitfall 4: The `minimumScaleFactor` rule lands before the removals
**What goes wrong:** every module fails to build for everyone.
**How to avoid:** sequence the rule commit after/with the owner's removal commit; land the other four rules immediately.

### Pitfall 5: Regex too wide / too narrow
**What goes wrong:** `\.dynamicTypeSize\b` blocks `@Environment(\.dynamicTypeSize)`; `\.system\(size: [0-9]` without `\s*` misses `size:16`.
**How to avoid:** the fixture in this research (9 positives, 12 negatives) is the acceptance test; keep it as a scratch negative-control step, not a committed file.

### Pitfall 6: `accessibilityInputLabels` has no `LocalizedStringResource` overload
**What goes wrong:** `.accessibilityInputLabels([.key])` does not compile; `[Text(.key)]` trips `accessibility_text_argument`.
**How to avoid:** `[String(localized: .key)]`. Verified against the SDK interface.

### Pitfall 7: Over-labelling
**What goes wrong:** adding `.accessibilityLabel` to `Label`-backed buttons duplicates or desynchronises Voice Control names.
**How to avoid:** inventory first; only the ~14 icon-only sites and the custom tappables get labels.

### Pitfall 8: Contrast math on gamma-encoded channels
**What goes wrong:** `Color.Resolved.red` is gamma-encoded; linearising the already-linear stored fields, or not linearising the gamma ones, both give wrong luminance.
**How to avoid:** use `linearRed/Green/Blue` in Swift; in the JSON test, linearise the sRGB strings once, after handling the three encodings.

### Pitfall 9: Better-of vs white-unless-fails
**What goes wrong:** picking "white unless < 4.5" drops the 4.58 structural floor and changes the flip count (45 vs 47), contradicting D-26's stated numbers.
**How to avoid:** threshold on luminance 0.1791 (better-of).

### Pitfall 10: Read-only environment values in previews
**What goes wrong:** `.environment(\.accessibilityReduceMotion, true)` in `#Preview` compiles and does nothing.
**How to avoid:** Accessibility Inspector Settings tab or device settings; only `dynamicTypeSize` and `colorScheme` are writable in previews.

### Pitfall 11: Availability guards at the iOS 26 floor
**What goes wrong:** copying the skill template's `#available(iOS 17, …)` / `XCTSkip` scaffolding adds dead code and violates the project's modern-API preference.
**How to avoid:** call the APIs directly; deployment target is 26.0.

### Pitfall 12: Git hygiene for images
**What goes wrong:** a screenshot written next to the verdict table gets swept into a docs commit.
**How to avoid:** every screenshot path starts with the scratchpad; `git status` shows no `*.png` before any `docs(16)` commit; plans include that check.

### Pitfall 13: Screen-level `accessibilityElement(children: .contain)` on the reader
`ReadingView.swift:83` wraps the reader in a `.contain` element for the UI tests' `reading_view` id; make sure label/action work inside it still surfaces children (it does for `.contain`; it would not for `.ignore`).

## Code Examples

See Architecture Patterns 1–7 above (all sourced from the repo, the Xcode 26.6 SDK interfaces, or Apple's documentation). One more, the rating view (icon-only, value-bearing):

```swift
// Source: repo RatingView.swift + SwiftUI accessibilityValue(LocalizedStringResource) overload (SDK-verified)
RatingView(rating: gallery.rating)
    .foregroundStyle(.yellow)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(.rating)
    .accessibilityValue(.ratingOutOfFive(rating: gallery.rating))   // catalog key; numeric arg via named substitution (C-4)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `#available(iOS 17)` guards around `performAccessibilityAudit`, `AccessibilityNotification`, `Color.resolve` | Call directly | Project floor is iOS 26 | No dead code |
| `UIAccessibility.post(notification: .announcement, …)` | `AccessibilityNotification.Announcement(…).post()` | iOS 17 | SwiftUI-native, no UIKit import |
| `Text(...)` / string literals in accessibility modifiers | `LocalizedStringResource` overloads + catalog keys (`accessibility_text_argument` rule already bans `Text`) | Phase 10/15 + this phase's D-30 guard | Structural localisation |
| `lineLimit(1)` + `minimumScaleFactor` shrink-to-fit | wrap / `ViewThatFits` / `@ScaledMetric` / `@Environment(\.dynamicTypeSize)` stacking | Phase 10 → this phase bans the shrink | No information loss |
| Manual Inspector audits | `performAccessibilityAudit()` in XCUITest | Xcode 15 | Permanent regression gate |
| Hand-authored per-variant colours for contrast | Frozen backgrounds + luminance-adaptive foreground | D-26 | Brand intact, AA guaranteed |

**Deprecated/outdated:** `Color.cgColor`-based channel reads (deprecated in favour of `resolve(in:)`, per the SwiftUICore interface: "deprecated … renamed: resolve(in:)").

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A *running* EhPanda re-lays out live on `simctl ui content_size` (verified for SpringBoard; the app was not running during the probe) | Round-1 mechanics | Low — fallback is `agent-device open --relaunch`, data container persists |
| A2 | `xcrun simctl spawn <UDID> defaults write com.apple.Accessibility ReduceMotionEnabled -bool true` toggles Reduce Motion on the simulator after relaunch | Reduce Motion verification | Low — Accessibility Inspector's Settings tab is the documented route |
| A3 | SwiftUI `.contextMenu` items are not automatically exposed as VoiceOver custom actions on iOS 26 (so explicit `accessibilityAction`s are needed) | VO/VC inventory | Medium — duplicates in the Actions rotor if wrong; verify on device before adding |
| A4 | Reinstalling the app via `xcodebuild` preserves the simulator data container (not relied on — the plan uses a separate simulator) | `performAccessibilityAudit` | None if the plan keeps the separation |
| A5 | `.yellow` rating stars are judged non-text (3:1) and the numeric rating beside them is the informational carrier | Contrast | Medium — if the owner wants the stars themselves compliant, the colour must darken in light mode (a visible change needing authorisation like D-26) |
| A6 | "XXL" in the owner's vocabulary means slider position 7 (`xxxLarge`, token `extra-extra-extra-large`), as in Phase 10 D-03 | Token table | Low — confirm in the first sweep report |

## Open Questions

1. **Which simulator and which bundle id hold the login?** Both booted sims carry `app.ehpanda` and `app.ehpanda.personal`. The owner must name the UDID + bundle id; the plan should hard-code both and forbid erase/uninstall/UI-test runs on that UDID.
2. **Does `.contextMenu` already surface as VoiceOver actions on iOS 26?** (A3) Decides whether tag/download/comment rows need explicit `accessibilityAction`s. Verify on `Owner-iPhone-Test` in the first manual pass.
3. **Does Apple require the `.dynamicType`/`.textClipped` audit types to pass for the Larger Text label?** The label criteria are task-based, not audit-based; treat the audit as a regression gate and the owner-signed sweep as the evidence. Recommendation: run all iOS audit types but let only `.sufficientElementDescription`, `.hitRegion`, `.trait`, `.contrast` be hard failures initially; promote `.textClipped`/`.dynamicType` to hard failures once round 1 is signed.
4. **Fixtures for Favorites / Archives / Torrents** (option (b) above): worth adding so the automated audit covers more login-gated screens without any credential — owner's call on scope.
5. **Rating-star colour** (A5) — audit-first outcome that may need an owner decision like D-26.
6. **`CategoryCell` excluded-state treatment**: opacity 0.3 is luminance-only; if the grayscale test reads as ambiguous, the fix (strike-through / `nosign` overlay) is a visible change at `.large` — surface to the owner with the measurement rather than deciding silently (D-22).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode + iOS 26.5 simulator runtime | everything | ✓ | 26.6 (17F113) | — |
| Booted iPhone Air / iPad Pro 11 (iOS 26.5) | 12-pass sweep | ✓ | UDIDs above | — |
| Spare simulators (iPhone 17e 26.4; iPhone Air + iPad 27.0) | UI-test audit without touching D-09 | ✓ | — | create one with `simctl create` |
| `xcrun simctl ui content_size/appearance/increase_contrast` | round 1 + contrast | ✓ | — | — |
| `agent-device` (orientation, snapshot, screenshot) | round 1 | ✓ | 0.20.8 | `sim-use` + AppleScript rotation |
| `sim-use` | round 1 | ✓ | 0.13.0 | `agent-device` |
| Accessibility Inspector | round 2 inspection, Reduce Motion / Bold Text / Increase Contrast simulation | ✓ | Xcode 26.6 bundle | device Settings |
| SwiftLint 0.65.0 artifact binary | rule validation | ✓ | 0.65.0 | a clean `xcodebuild build` (plugin) |
| Physical iPhone (`Owner-iPhone-Test`, iPhone 11, connected) | VoiceOver / Voice Control walkthrough | ✓ | — | none — the Simulator has neither feature |
| Python 3 | one-off colorset maths (research only) | ✓ | 3.10 | Swift test does the same |
| Context7 / `ctx7` | docs lookup | ✗ | — | Apple SDK swiftinterfaces + developer.apple.com (used) |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** Context7 (SDK interfaces + official docs used instead).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (package tests, 178 files / ~1020 `@Test`); XCTest/XCUITest (`EhPandaUITests`, 13 tests) |
| Config file | `AppPackage/Tests/FeatureTests.xctestplan` (default, package tests via app scheme); `UITests.xctestplan` (non-default, UI tests); `AppPackage-Package` scheme runs all package test targets |
| Quick run command | `xcodebuild build -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator'` (build + SwiftLint plugin = lint gate, ~minutes) |
| Full suite command | `cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,id=<spare sim UDID>'` then `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests -destination 'platform=iOS Simulator,id=<spare sim UDID>'` — **one `xcodebuild test` at a time on this machine** |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| A11Y-01 | `minimumScaleFactor` = 0; no `.dynamicTypeSize(` modifier; no `GeometryReader`; no numeric `.system(size:)` | lint (build) | `xcodebuild build -scheme AppFeature …` (plugin errors) + standalone `swiftlint lint --strict --no-cache --config .swiftlint.yml AppPackage/Sources App ShareExtension EhPandaUITests AppPackage/Tests` | ❌ Wave 0: rules in `.swiftlint.yml` |
| A11Y-01 | Readability/operability at XXL/AX3/AX5 × 2 devices × 2 orientations | manual (owner-signed) | sweep per Pattern 1; evidence `16-SWEEP.md` | ❌ Wave 0: verdict table skeleton |
| A11Y-01 | `.large` parity after each owner fix | manual | before/after screenshots at `large` in scratchpad, chat review | — |
| A11Y-02 | No hardcoded accessibility strings | lint (build) | same as above (`accessibility_hardcoded_string`) | ❌ Wave 0 |
| A11Y-02 | Luminance helper correctness (crossover, worst variant, black/white) | unit | `AppPackage-Package` test action (`AppToolsTests/ColorContrastTests.swift`) | ❌ Wave 0 |
| A11Y-02 | 84/84 variants ≥ 4.5:1 with best-of text; colorset bytes unchanged | unit (repo walk) | `AppPackage-Package` test action (`CategoryColorsetInvariantTests.swift`) | ❌ Wave 0 |
| A11Y-02 | Labels / hit regions / traits / contrast on fixture-reachable screens | UI (XCUITest) | `xcodebuild test -scheme EhPanda -testPlan UITests …` (`AccessibilityAuditUITests.swift`) | ❌ Wave 0 |
| A11Y-02 | Reduce Motion gating present on the in-scope sites | source scan (optional) + manual | Swift Testing scan asserting each listed site reads `reduceMotion` (pattern: `DownloadSourceInventoryTests`) | ❌ optional |
| A11Y-02 | VoiceOver reading order / focus; Voice Control "Show names"/"Show numbers" | manual device | walkthrough checklist from `$HOME/.claude/skills/swift-accessibility-skill/resources/qa-checklist.md` | — |
| A11Y-02 | Grayscale / dark + Increase Contrast / Bold Text + Reduce Transparency passes | manual sim/device | `simctl ui … appearance dark`, `increase_contrast enabled`; Inspector Settings tab for Bold Text / Reduce Transparency; Settings app for Grayscale | — |
| A11Y-02 | Nutrition Label recommendation | doc | `16-NUTRITION-LABEL.md` in the skill's format | ❌ phase close |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme AppFeature …` green (lint) + the touched test target via the package scheme.
- **Per wave merge:** full `AppPackage-Package` test action; UI-test plan when `EhPandaUITests` or view semantics changed.
- **Phase gate:** both suites green, owner-signed sweep table complete (no `pending`/`re-verify` rows), all five D-13 items dispositioned, manual VO/VC walkthrough recorded, D-25 re-sweep rows added and passed.

### Wave 0 Gaps
- [ ] `.swiftlint.yml` — five custom rules (four D-16 + D-30 guard); `no_minimum_scale_factor` sequenced after the owner's removals
- [ ] `.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md` — verdict-table skeleton generated from the 42-row inventory × 12 cells, plus the 5 named D-13 rows
- [ ] `AppPackage/Tests/AppToolsTests/ColorContrastTests.swift` — helper tests
- [ ] `AppPackage/Tests/<target>/CategoryColorsetInvariantTests.swift` — 84/84 + hash pin (three component encodings)
- [ ] `EhPandaUITests/AccessibilityAuditUITests.swift` — one test per fixture-reachable screen, deep-link entry via existing `UITestConstants`
- [ ] Catalog keys `accessibility.*` in each touched module, six locales filled
- [ ] (optional) fixtures for favorites / archives / torrents

## Security Domain

`security_enforcement` is enabled; ASVS level 1. This phase adds no network, storage, or auth surface. Applicable controls:

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (no auth code changes) | Credentials never pass through the agent (D-09); the `EHPANDA_AUTOMATION_IPB_*`/`IGNEOUS` seam stays unused |
| V3 Session Management | no | The owner's simulator session is infrastructure; never erased, never exported |
| V4 Access Control | no | — |
| V5 Input Validation | minimal | SwiftLint regexes are configuration, not input handling; UI-test fixtures are static HTML in the test bundle |
| V6 Cryptography | no | SHA-256 in the colorset pin is an integrity check via `CryptoKit`, not a security control |
| V8 Data Protection | **yes** | No screenshot of gallery content enters the repo (D-32); scratchpad only; verdict tables contain no gallery identifiers beyond what the fixtures already publish |

### Known Threat Patterns for this phase
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Credential leakage via launch env / shell history | Information disclosure | D-09: hand login only; plans never reference the IPB/IGNEOUS keys |
| Adult content screenshots committed to a public repo | Information disclosure | D-32: scratchpad-only paths, `git status` image check before docs commits |
| Logged-in simulator destroyed by tooling | Denial of service (phase infrastructure) | Dedicated UDID for UI tests; erase/uninstall/clear-app-state forbidden on the D-09 UDID |
| Lint rule silently disabled by an invalid `match_kinds` spelling | Tampering (accidental) | Negative-control probe per rule (11-EXCEPTIONS §1.2 pattern) |

## Sources

### Primary (HIGH confidence)
- Xcode 26.6 SDK `SwiftUI.swiftmodule` / `SwiftUICore.swiftmodule` `arm64-apple-ios-simulator.swiftinterface` — accessibility modifier overloads, `Color.resolve(in:)`, `Color.Resolved` linear fields, environment values
- Xcode 26.6 `XCUIAutomation.framework` swiftinterface + `XCUIAccessibilityAuditTypes.h` / `XCUIAccessibilityAuditIssue.h` — audit API
- `xcrun simctl ui` usage text and live runs on the booted simulators; `agent-device help orientation|settings|open`; `sim-use` SKILL.md
- Repository tree at `feature/gsd-phase-16` HEAD (`a8829305`): `.swiftlint.yml`, all grep inventories, `CategoryView.swift`, `Category.swift`, colorset JSON (84 variants re-measured), `EhPandaUITests/*`, `UITests.xctestplan`, `AppFeature/UITestSupport/*`, `AppLaunchAutomation.swift` (keys only), `DownloadLogPrivacyInvariantTests.swift`, `DownloadSourceInventoryTests.swift`, `10-10-SUMMARY.md`, `10-UAT.md`, `11-EXCEPTIONS.md`
- SwiftLint 0.65.0 artifact binary runs (rule counts 5/0/0/0/0; fixture positives/negatives)

### Secondary (MEDIUM confidence)
- App Store Connect help: overview + Larger Text / VoiceOver / Voice Control / Sufficient Contrast / Reduced Motion / Differentiate Without Color evaluation criteria (fetched 2026-08-23)
- `$HOME/.claude/skills/swift-accessibility-skill/` — `SKILL.md`, `references/{nutrition-labels,voice-control,display-settings,testing-auditing,voiceover-swiftui}.md`, `resources/audit-template.swift`

### Tertiary (LOW confidence)
- Web search confirming the Simulator lacks VoiceOver/Voice Control (Apple forums, Deque) — consistent with the skill and with long-standing Apple tooling behaviour
- Items A1–A6 in the Assumptions Log

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every API checked against the installed SDK interfaces; tools probed live
- Architecture: HIGH — patterns are the repo's own (toast, badge label, download row, invariant tests) plus SDK-verified signatures
- Pitfalls: HIGH for tooling pitfalls hit in this session (ambiguous `booted`, three colorset encodings, missing InputLabels overload); MEDIUM for device-only behaviours (A3)
- Nutrition Label criteria: MEDIUM — official pages, condensed

**Research date:** 2026-08-23
**Valid until:** 2026-09-22 for stack/API facts (stable); the inventories are valid only at HEAD `a8829305` — re-grep before planning if the owner's round-1 commits land first (they will move line numbers in exactly the files listed under D-04)
