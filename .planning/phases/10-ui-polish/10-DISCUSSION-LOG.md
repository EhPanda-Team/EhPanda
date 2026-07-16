# Phase 10: UI Polish - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-17
**Phase:** 10-ui-polish
**Areas discussed:** Dynamic Type ambition, Numeric-text application, Preview enrichment depth, Parity verification stance

---

## Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Dynamic Type ambition | Scope/verify comprehensive DT (criterion 5) | ✓ |
| Numeric-text application | Which numbers get monospacedDigit + numericText | ✓ |
| Preview enrichment depth | How deep to enrich 42 migrated previews | ✓ |
| Parity verification stance | How to prove no regression across mechanical swaps | ✓ |

**User's choice:** All four.
**Notes:** Mechanical sweeps (rename, cornerRadius, foregroundColor, Label, empty-string, inSheet) left to research/planning; builder flagged that criterion 5 (Dynamic Type) is far heavier than the other 10 items.

---

## Dynamic Type ambition

### Scoping

| Option | Description | Selected |
|--------|-------------|----------|
| Full audit+fix, split out | DT becomes its own phase; Phase 10 keeps the polish items | |
| Full audit+fix, in Phase 10 | Keep everything together; Phase 10 gains a large DT wave | ✓ |
| Regression-guard only | Narrow criterion 5 to don't-regress + fix egregious breakage; comprehensive DT deferred | |

**User's choice:** Full audit+fix, in Phase 10.

### Remediation stance

| Option | Description | Selected |
|--------|-------------|----------|
| Reflow, cap as last resort | Prefer reflow; allow dynamicTypeSize(…maxSize) on non-essential space-constrained UI only | |
| Reflow, never cap | Text always grows; every layout adapts; zero caps anywhere | ✓ |
| You decide per-site | Best-judgment reflow-first, documented cap as last resort | |

**User's choice:** Reflow, never cap.
**Notes:** Absolute — no `dynamicTypeSize(…maxSize)` anywhere, not even on compact chrome.

### Verification

| Option | Description | Selected |
|--------|-------------|----------|
| Device UAT at AX5 | Manual device pass, every screen, max accessibility size | |
| Device UAT, spot-check sizes | Manual device pass, sample a few sizes | |
| Previews + targeted device | Enriched-preview DT variants + device UAT on highest-risk screens | |
| **Other → sim-use, a few sizes** | Drive the simulator via the sim-use skill, sampling a few DT sizes | ✓ |

**User's choice:** `sim-use` with a few sizes (free-text).

### DT sizes to sample

| Option | Description | Selected |
|--------|-------------|----------|
| XXL + AX3 + AX5 | Largest standard + mid-accessibility + max | ✓ |
| XXL + AX5 | Largest standard + max only | |
| L + AX3 + AX5 | Baseline L + mid + max accessibility | |

**User's choice:** XXL + AX3 + AX5, across every user-facing screen including sheets.

---

## Numeric-text application

### monospacedDigit coverage

| Option | Description | Selected |
|--------|-------------|----------|
| All number-bearing text | Uniform monospacedDigit everywhere numbers appear | |
| Changing / column-aligned only | Only updating or aligned numbers; skip static one-offs | |
| You decide per-site | Best-judgment per site | |
| **Other → same set as numericText** | Apply monospacedDigit only to the numericText (changing) set | ✓ |

**User's choice:** Only changing numbers — the same set as numericText (free-text). monospacedDigit and numericText travel together; static numbers get neither.

### numericText animation targets

| Option | Description | Selected |
|--------|-------------|----------|
| Live values only | Reader page indicator, download progress %/size | |
| Live + user-driven changes | Also favorite/comment counts on refresh, rating on tap, cache size after clear | ✓ |
| You decide per-site | Wherever a value visibly changes | |

**User's choice:** Live + user-driven changes.

---

## Preview enrichment depth

### Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Pragmatic by view | Stateful views get full realistic-state matrix; trivial leaf views get one clean #Preview | ✓ |
| Full matrix everywhere | Exhaustive named states on all 42 | |
| Migrate + light enrich | Migrate all; add states only where obvious | |

**User's choice:** Pragmatic by view.

### Variants

| Option | Description | Selected |
|--------|-------------|----------|
| DynType + dark on stateful views | Standardize AX-size + dark-mode named cases on enriched previews | |
| Color-scheme only | Dark-mode variants where useful; leave DT to sim-use | |
| You decide where useful | Per-criterion judgment, no blanket rule | |
| **Other → don't specify / no fixed size or scheme** | Don't standardize variants; don't pin a fixed size/scheme; default environment | ✓ |

**User's choice:** Don't specify variants or fix a size/scheme (free-text). Previews cover content states only at the default environment; DT/appearance proven by the sim-use pass.

---

## Parity verification stance

| Option | Description | Selected |
|--------|-------------|----------|
| Build + risk-tiered sim-use | Build clean/no-new-warnings; sim-use before/after on layout-affecting swaps (ZStack, cornerRadius, Label); diff-review for foregroundStyle | ✓ |
| Snapshot tests on touched views | Add SnapshotTesting baselines; strongest but introduces snapshot infra | |
| Build-only + diff review | Build clean + careful diff; no runtime visual check | |

**User's choice:** Build + risk-tiered sim-use.

---

## Claude's Discretion

Mechanical items with rules already fixed by the ROADMAP criteria, left to research/planning:
`SystemNotificationExt`→`SystemNotification` rename, `cornerRadius(_:corners:)`→`clipShape`,
deprecated-API sweep (`foregroundColor`→`foregroundStyle`), empty-string audit, `Label` conversion,
`\.inSheet` removal (native replacement mechanism chosen at plan time).

## Deferred Ideas

None. Splitting comprehensive Dynamic Type into its own phase was considered and explicitly rejected (kept in Phase 10).
