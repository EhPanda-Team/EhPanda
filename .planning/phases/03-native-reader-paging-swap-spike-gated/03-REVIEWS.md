---
phase: 3
reviewers: [claude-in-session]
reviewed_at: 2026-07-12T00:00:00+09:00
plans_reviewed: [03-01-PLAN.md, 03-02-PLAN.md, 03-03-PLAN.md, 03-04-PLAN.md, 03-05-PLAN.md]
note: >
  Owner-directed in-session review — no external CLIs and no subagents were invoked.
  Every plan claim below was verified against the live source tree (file:line cited),
  per the source-grounding rule in the review workflow.
---

# Plan Review — Phase 3: Native Reader Paging Swap (spike-gated)

## Claude (in-session) Review

### Summary

The five plans are unusually well-grounded: every file/line reference I checked against the
working tree is accurate (SwiftUIPager decl `AppPackage/Package.swift:21`, product static `:47`,
the three `.targetDependency(.swiftUIPager)` entries at `:299` (appFeature — confirmed stale, no
`import SwiftUIPager` anywhere under `AppPackage/Sources` except the two real call-site files),
`:718` (homeFeature), `:780` (readingFeature); the acknowledgement row `AboutView.swift:162-163`;
the `acknowledgement.swiftUIPager`/`_link` keys at `Constant.xcstrings:508/550`, both
`shouldTranslate:false` with all six locales filled). The wave structure is risk-correct
(riskiest parity item — the carousel loop — first; the pure-mapping guard before any re-seam;
removal gated behind a blocking human checkpoint with `autonomous: false`). The PageHandler test
spec in 03-01 matches the actual arithmetic in `PageHandler.swift:11-33`, including the
`result + 1 == pageCount` cover clamp and the direction-agnostic property (the mapping only
tests `!= .vertical`, so `.leftToRight` vs `.rightToLeft` is provably identical). One planned
mechanism is, however, demonstrably wrong as specified — the RTL `layoutDirection` flip will
double-reverse dual-page spreads (see HIGH concern) — and the carousel plan misses that
`.viewAligned` does not center the snapped card the way SwiftUIPager does. Both are fixable
with small plan amendments; neither invalidates the phase shape.

### Strengths

- **Source-accurate cleanup inventory (03-05).** All five `Package.swift` SwiftUIPager references
  verified at the stated lines; the appFeature entry at `:299` confirmed stale by grep (only
  `ReadingView.swift:7`, `AdvancedList.swift:2`, `HomeView+Sections.swift:5` import it). The
  xcstrings keys carry verbatim English copies in all six locales exactly as the AGENTS.md
  non-translated-key rule requires, so whole-key deletion is the right shape.
- **The 03-01 behavior table is faithful to the code.** I traced `mapFromPager`/`mapToPager`
  (`PageHandler.swift:11-33`) through single-page, dual-page ±`exceptCover`, and the boundary
  clamp: the specified expectations (`index+1`/`index-1`, `2i+1`/`(i-1)/2`, `2i`/`i/2`,
  `result+1==pageCount → pageCount`) and the round-trip identity all hold on paper, including the
  guard edge cases (`index 0 → 1`, `index 1 → 0`). `containerDataSource` expectations match
  `ReadingReducer.swift:134-147` exactly. Forcing `isLandscape:` explicit (never the
  `DeviceUtil.isLandscape` default at `PageHandler.swift:11`) is the right determinism call and
  matches the inject-over-serialize house rule.
- **D-07 PageModel decision is well-reasoned and verified viable.** The mirrored surface
  (`.index`, `.update(.next)`, `.update(.new(index:))`, `.withIndex`) matches the real
  SwiftUIPager `Page` API (`Page.swift:79-138` in the checkout) and the actual call sites
  (`AdvancedList.swift:39/45/52`, `ReadingView.swift:242/271-283`,
  `ReadingView+Gestures.swift:11-14`), so the type-swap-only diff claim is credible.
- **The feedback-guard plan copies a proven in-repo idiom.** `AdvancedList.swift:42-53` already
  implements the `performingChanges` + 0.2s settle + `tryScrollTo` shape against the same
  scroll APIs; mirroring it for the horizontal branch is the lowest-risk possible design.
- **Correct gesture-preservation fence (03-04).** `GestureHandler.onSingleTapGestureEnded`
  (`GestureHandler.swift:48-67`) does the RTL inversion on absolute screen coordinates via
  `TouchHandler.shared` — independent of any SwiftUI `layoutDirection` — so the plan's
  "keep the sign, don't re-invert" instruction is exactly right.
- **The blocking human gate (03-05 Task 2) is real.** `autonomous: false`, checkpoint task type,
  explicit resume signals, and Task 3 conditioned on GO — the D-02 all-or-nothing semantics are
  structurally enforced, not aspirational.

### Concerns

- **HIGH — RTL `layoutDirection` flip double-reverses dual-page spreads (03-03/03-04).**
  `imageContainerConfigs` (`ReadingReducer.swift:148-166`) already swaps first/second page for
  RTL (`firstIndex = index + 1` when `isReversed`), and `HorizontalImageStack.body` renders them
  in a plain `HStack(spacing: 0)` (`ReadingViewComponents.swift:104-106`). Under the planned
  `.environment(\.layoutDirection, .rightToLeft)` on the ScrollView subtree, that HStack's visual
  order flips too — so in dual-page RTL landscape the spread renders in LTR order (first-read
  page on the wrong side). Today SwiftUIPager's `.horizontal(.endToStart)` reverses only the
  paging axis, never page content, which is why the config-level swap exists. RESEARCH Pitfall 6
  covers `.scrollPosition(id:)` under RTL but not this content flip, and the 03-05 checklist has
  separate "RTL" and "dual-page landscape" rows but never the combination — so the bug could
  slip to a false GO, or (if caught) trigger an unnecessary NO-GO for something trivially
  fixable. Fix: re-normalize inside each page (e.g. `.environment(\.layoutDirection,
  .leftToRight)` on the `imageStack` content) so only the scroll axis flips, and add an explicit
  "RTL × dual-page landscape spread order" row to 03-GO-NO-GO.md.
- **MEDIUM — `.viewAligned` does not center the snapped card (03-02).** SwiftUIPager centers the
  focused item; with `cardCellWidth = DeviceUtil.windowW * 0.8` (`Defaults+Runtime.swift:13`)
  today's carousel shows ~10% peek on each side. A stock `.scrollTargetBehavior(.viewAligned)`
  aligns the card's leading edge to the content edge — all 20% peek lands on the trailing side
  and the snapped card hugs the leading edge. Neither D-06, RESEARCH Pattern 4, nor plan 03-02
  mentions the required horizontal `.contentMargins`/`.safeAreaPadding` (≈`(windowW −
  cardWidth)/2`) to reproduce centered snap. Without it the very first Task-1 render is a
  visible parity gap on a mandatory-parity surface.
- **MEDIUM — 03-03 Task 1 leaves the package non-compiling at a task boundary.** Deliberate and
  documented (grep-only isolation verify; rescoped in c2e91a40), but the commit-per-task
  protocol then produces a non-building commit (AdvancedList takes `PageModel` while ReadingView
  still passes `Page`). A cleaner split achieves the same waves with every commit green: Task 1 =
  create `PageModel.swift` only (a new unused file compiles standalone), Task 2 = re-seam
  AdvancedList + ReadingView together. Alternatively, instruct the executor explicitly to commit
  Tasks 1+2 as one atomic commit.
- **LOW — duplicate logger declaration (03-04 Task 1).** `ReadingView.swift:15` already declares
  the file-level `private let logger`. The instruction "declare `private let logger = Logger(...)`"
  would be a redeclaration compile error; it should say "use the existing file-level logger".
- **LOW — carousel initial position & inward-sync parity not pinned (03-02).** Today the carousel
  starts at `.withIndex(1)` (`HomeView+Sections.swift:12`) matching `cardPageIndex = 1`
  (`HomeReducer.swift:20`). The plan never says to seed the initial `.scrollPosition(id:)` from
  the inbound `pageIndex` binding, so a naive implementation starts at card 0. Also
  `.synchronize` is bidirectional while the plan wires outward-only; I verified the reducer never
  writes `cardPageIndex` (only reads: `HomeReducer+Body.swift:13-15`, `HomeReducer.swift:48`), so
  outward-only is adequate — but that verified asymmetry should be stated in the plan/summary so
  a future reducer write doesn't silently desync.
- **LOW — the "Page clamp parity" claim is subtler than stated (03-04).** `Page.index`'s setter
  clamps to `totalPages - 1` (`Page.swift:26-33`), but `totalPages` is only populated by a
  rendered `Pager` — in vertical mode no `Pager` exists, so today's autoplay `.next` is
  effectively unclamped (`totalPages = Int.max`). The planned clamped `jump(...)` is a strict
  improvement, but in vertical autoplay it is a (desirable) behavior change, not exact parity —
  record it in the 03-04 summary so the go/no-go doesn't misread it as drift.
- **LOW — 03-VALIDATION frontmatter is stale.** Still `status: draft`,
  `nyquist_compliant: false`, `wave_0_complete: false`, approval "pending" even though STATE
  records planning finalized and plan-checker passed. Flip or annotate before execution so the
  execution-time sampling contract reads as authoritative.

### Suggestions

1. Amend 03-03 (and echo in 03-04/03-05): scope the `layoutDirection` flip to the scroll axis
   only — re-apply `.leftToRight` on each page's content — and add the combined
   "RTL × dual-page landscape" row to the go/no-go checklist. This is the one change I would
   block on before execution.
2. Amend 03-02 Task 1 to name the centering mechanism explicitly (horizontal
   `.contentMargins(…, for: .scrollContent)` derived from the same `DeviceUtil`-based
   `cardCellSize` the section already uses), and to seed the initial scroll id from `pageIndex`.
3. Re-split 03-03's tasks (PageModel-only first) or mandate a single commit for both tasks, so
   every commit builds.
4. Fix the 03-04 logger wording to reference the existing `ReadingView.swift:15` logger.
5. Minor: 03-02's `.scrollClipDisabled()` is likely unnecessary once the ScrollView spans full
   width (neighbors peek inside bounds); keep it only if the frame is card-sized. Harmless
   either way — just don't let its presence substitute for the missing content margins.

### Risk Assessment

**MEDIUM.** The phase architecture, sequencing, gating, and evidence discipline are strong, and
all mechanical claims check out against source. The residual risk is concentrated in two
specified-but-wrong mechanisms (RTL dual-page double-flip — HIGH, carousel centering — MEDIUM)
plus the known spike-inherent unknowns the plans already gate manually (loop re-center
invisibility, `.paging` landscape FB16486510, programmatic landed-id fidelity). With suggestions
1–2 applied, I would rate the plan set LOW risk relative to its goal, because the D-02 human
gate catches anything that survives.

---

## Consensus Summary

Single in-session reviewer (owner-directed; external CLIs and subagents deliberately not used),
so no cross-reviewer consensus exists. Treat the HIGH concern (RTL dual-page double-flip, plus
the missing combined checklist row) and the first MEDIUM (viewAligned centering) as the two
actionable pre-execution amendments; the rest are polish.

### Agreed Strengths
_n/a — single reviewer. Top strengths: verified-accurate cleanup inventory; test spec faithful
to `PageHandler` math; proven in-repo feedback-guard idiom reused; structurally enforced D-02
human gate._

### Agreed Concerns
_n/a — single reviewer. Highest-priority: RTL `layoutDirection` double-flip on dual-page spreads
(03-03/03-04) and uncentered `.viewAligned` snap (03-02)._

### Divergent Views
_n/a — single reviewer._
