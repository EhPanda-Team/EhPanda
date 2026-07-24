---
phase: 14-analytics-instrumentation
plan: 13
completed: 2026-07-25
tasks_completed: 3
tasks_total: 3
requirements-completed: []
---

# 14-13 Summary: DetailFeature instrumentation

**Six emission sites in `DetailFeature` — the tag tap (via a new namespace-carrying reducer action), three download outcomes, and the detail-search screen's two panels — plus thirteen exact-sequence `TestStore` cases, five of which assert *silence* to lock down boundaries that were previously only comments.**

## What shipped

| Site | Signal | Placement |
|------|--------|-----------|
| Tag tap | `tagTapped(namespace:)` | New `tagSearchTapped(keyword:namespace:)` action |
| Download start | `downloadStateChanged(.started)` | `startDownloadDone` **success arm** |
| Download retry | `downloadStateChanged(.retried)` | `retryDownloadDone` **success arm** |
| Download delete | `downloadStateChanged(.deleted)` | `deleteDownloadDone` **success arm** |
| Detail-search filter panel | `filterPanelOpened(.detailSearch)` | `filtersButtonTapped` |
| Detail-search quick-search | `quickSearchPanelOpened(.detailSearch)` | `quickSearchButtonTapped` |

### The tag namespace rides on the action

D-07 permits a tag's namespace; D-06 forbids its text. The namespace was known in the tag row (it already reads it for the row header) but was dropped before the reducer saw only an assembled search keyword. Recovering it by parsing that keyword back apart would have put tag text on the analytics path, so the namespace now travels through a new action instead.

The search behavior is unchanged: the reducer merges the emission with a send of the same `.delegate(.pushDetailSearch(keyword))` the view sent directly before, in the same reducer turn. The callback widening touched six sites — `TagsSection`'s declaration, `TagRow`'s declaration, the row's invocation, the preview stub, and the single supplier in `DetailView` — all now consistent.

`tagDetailButtonTapped` stays silent: it presents an informational sheet, not a search, and `TagDetail` carries no namespace to emit.

## Verified inventory: a fourth download completion case

The plan asked for the download-completion inventory to be verified by search rather than trusted. It named start, retry and delete. The module has a **fourth**: `toggleDownloadPauseDone`.

It is deliberately **not** instrumented. `DownloadOutcome` has cases `started`, `retried`, `completed`, `failed`, `deleted`, `moved` — there is no `paused`, so pause/resume is structurally inexpressible in the closed vocabulary and sits outside D-05's taxonomy. Widening a locked signal vocabulary is an owner decision, not an executor's, so it is raised here rather than silently added. Both of its arms are pinned by a zero-signal test, so adding an emission there becomes a test failure rather than a quiet taxonomy change.

`openReadingDone` and `fetchVersionMetadataDone` are download-adjacent but are not download outcomes.

## Failure ownership

No failure arm emits. The `failed` outcome belongs to the downloads-list transition diff (plan 14-15), which observes a download failing during transfer. Counting start-time failures here as well would make one metric name mean two different things. Three zero-signal tests enforce that split.

## Tests

`DetailFeatureTests` → **TEST SUCCEEDED**, 19 tests in the target.

- Tag-tap sweep over `TagNamespace.allCases` plus `nil`, asserting the recorded signal **and** the forwarded keyword in one test. Splitting them would let a later change keep the signal passing while breaking the search (T-14-16).
- Sentinel-keyword reflection assertion: the sentinel survives nowhere in the recorded signal's stored leaf graph (T-14-01).
- Five empty-recorded-sequence assertions: three download failure arms, the tag-detail sheet, and pause/resume.

## Deviations from plan

1. **Files beyond `files_modified`.** The plan lists `DetailReducer.swift`, but this reducer's body is split across sibling extension files. The `tagSearchTapped` handler went to `DetailReducer+Actions.swift` and the download emissions to `DetailReducer+Download.swift`, where that code actually lives. `DetailView.swift` (in the plan's list) and the two extension files were all touched.

2. **`analyticsClient` is internal, not `private`.** The plan specifies `private`. Because the reducer body spans extension files in other files, `private` type members are invisible to them — the same constraint plan 14-11 hit in `HomeReducer`. Declared internal with an explanatory comment, matching every other dependency this reducer vends. `DetailSearchReducer`, whose body is in one file, kept `private` as specified.

3. **Delegate assertion form.** The plan implies a nested case-path assertion. `DetailReducer.Delegate` is `Equatable` but not `@CasePathable`, so `\.delegate.pushDetailSearch` does not compile. Used `receive(\.delegate, .pushDetailSearch(keyword))` — the case path with an expected payload value — which asserts the keyword itself and needed no production annotation added for test convenience.

4. **Executed inline rather than by a subagent.** The first dispatch of this plan was terminated mid-Task-1 by a provider weekly-quota limit, having widened `TagsSection`'s callback but not `TagRow`'s, its invocation, the preview stub, or the supplier in `DetailView` — leaving the tree non-compiling. The remainder was completed inline with a commit after each verified step, so an interruption cannot leave a broken tree. The recovered Task 1 work was preserved rather than discarded.

## Notes for later plans

- **14-15** owns the `failed` download outcome via the downloads-list transition diff. This module deliberately leaves it alone.
- **14-17** (or an owner decision) may want to consider whether pause/resume deserves a `DownloadOutcome` case. Currently it is unmeasured by construction.
- `ANALYTICS-01` remains `[ ]` — it spans the phase and 14-17 closes it out.
