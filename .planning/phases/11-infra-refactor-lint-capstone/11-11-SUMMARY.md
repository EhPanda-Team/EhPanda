---
phase: 11-infra-refactor-lint-capstone
plan: 11
subsystem: ui-lifecycle
tags: [swiftui, lifecycle, lint, swiftlint, binding, pagination]
requires:
  - "Lifecycle migrations from 11-07/11-08/11-09/11-10 (all other modules already clean)"
  - "11-09's finding that a disable directive cannot precede its rule"
provides:
  - "`lifecycle_modifiers` live at error — SwiftUI lifecycle callbacks are now build-gated repo-wide"
  - "`binding_initializer` live at error, narrowed to the closure form only"
  - "`AutoLoadNextPage` — one scroll-geometry pagination modifier shared by both gallery list styles"
  - "Six reason-annotated D-02 exception directives, the complete set for the owner's 11-29 review"
affects:
  - "Every future build: both rules are enforced by the SwiftLint build-tool plugin on source AND test targets"
  - "ReadingFeature (directives only, no behaviour change)"
tech-stack:
  added: []
  patterns:
    - "Deleting a view-local mirror of presentation state removes its lifecycle callbacks as a side effect"
    - "Scroll-geometry pagination (`onScrollGeometryChange` + `onScrollPhaseChange`) as the general replacement for last-cell `.onAppear`"
    - "`Binding($optional)` as the projected replacement for `Binding(get:set:)` presence bindings"
key-files:
  created: []
  modified:
    - .swiftlint.yml
    - AppPackage/Sources/SystemNotification/View+Toast.swift
    - AppPackage/Sources/GalleryListComponents/GalleryList.swift
    - AppPackage/Sources/AppComponents/AppAlertState.swift
    - AppPackage/Sources/AppComponents/PreviewImageView.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift
    - AppPackage/Tests/SystemNotificationTests/ToastInteractionTests.swift
decisions:
  - "The toast's two lifecycle callbacks were deleted, not exempted: `ToastInteractionState` was a view-local mirror of the presentation binding, and both callbacks existed only to keep the mirror in sync. Every guard it provided is already provided by the `item?.state.id == presentedID` checks that surround it."
  - "`DetailList` adopted `ThumbnailList`'s Phase 2 (D-36) scroll-geometry auto-load rather than getting a new mechanism. The two lists now share one `AutoLoadNextPage` modifier; the duplicated guards and threshold are gone."
  - "`binding_initializer`'s regex is D-05's narrowed form. The drafted regex banned every `Binding(` and would have flagged all ~29 projected sites, which are the idiom the rule is meant to steer toward."
  - "Three exceptions kept and three added, all six annotated in-place with prose plus a `disable:next` directive, landed in the same commit as the flip."
metrics:
  duration: ~35 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 11: Component Lifecycle + Rule Flip Summary

`lifecycle_modifiers` and `binding_initializer` are live at error with zero violations across `AppPackage/Sources`, `AppPackage/Tests`, `App` and `ShareExtension`. The last four lifecycle sites resolved as two deletions, one migration and one exception; the flip, the fixes and all six exception directives landed in a single commit, as 11-09's finding required.

## Site count

Plan and prompt said four Sources sites plus one in `AppPackage/Tests`. Re-enumerated at HEAD: **four Sources sites, zero in Tests**. The Tests site the prompt carried forward does not exist — the grep across `AppPackage/Tests` returns nothing for the rule's tokens.

| # | Site | Verdict | Where it went |
|---|---|---|---|
| 1 | `View+Toast.swift:75` `.onAppear` | **deleted** | maintained a redundant mirror; `.task`'s first statement did the same thing |
| 2 | `View+Toast.swift:78` `.onDisappear` | **deleted** | same mirror; the `item` guards already cover it |
| 3 | `View+Toast.swift:81` `.task(id:)` | **exception** | auto-dismiss timer; cancellation-on-replacement is the mechanism |
| 4 | `GalleryList.swift:139` `.onAppear` | **migrate** | shared `AutoLoadNextPage` scroll-geometry modifier |
| 5 | `AppAlertState.swift:248` `.onAppear` | **exception** | alert TextField focus hop |
| 6 | `PreviewImageView.swift:91` `.task(id:)` | **exception** | thumbnail decode; cancellation sheds off-screen work |

## The toast: a deletion, not two exceptions

`ToastViewModifier` held `@State private var interactionState = ToastInteractionState()` — a struct tracking "which toast id is presented, and its `ErrorInfo`". `.onAppear` filled it, `.onDisappear` cleared it, and `.task`'s first line filled it again with identical arguments.

That state was a mirror of `item`, the presentation binding the modifier already holds. Every consumer of the mirror sat behind an `item?.state.id == presentedID` guard that answers the same question directly:

- `errorButtonTapped` guarded on `item?.state.id` **and** on `interactionState.activate` — the second check is implied by the first, since the tap's own `item = nil` invalidates any repeat.
- `dismiss` called `interactionState.dismiss` **and** guarded on `item?.state.id`.

The interesting window is the removal transition: SwiftUI keeps the toast on screen while it slides away, so a replaced-or-dismissed toast is briefly still tappable. Both mechanisms reject it there — the mirror because its `presentedID` moved on, the binding because `item` is nil or carries a new id. So the mirror is redundant in exactly the case it was written for.

Deleting it took `ToastInteractionState` (22 lines) and both callbacks with it. The remaining `.task(id:)` is the only lifecycle use the toast needs, and it is an honest one.

**Coverage change:** `ToastInteractionTests` lost its four state-machine tests along with the type. Its fifth test — `onlyDiagnosticErrorsRemainPresented`, which pins the Phase 9 persistent-diagnostic-toast rule that an `ErrorInfo` toast does not auto-hide — never touched `ToastInteractionState` and is unchanged. Nothing that was true of the shipped app stopped being tested; what was lost was tests of a type that no longer exists. Flagged below.

## GalleryList: reuse, not reinvention

`ThumbnailList` already solved this exact problem in Phase 2. Its comment even says it was "mirroring DetailList's paginate-on-scroll behavior" — but it did so with `onScrollGeometryChange` + `onScrollPhaseChange` and a documented pair of guards, because the naive version fed an endless fetch loop: the load's own append perturbs scroll geometry, which re-triggers the load.

So `DetailList` did not need a new mechanism, it needed the one already in the file. Both lists now call a single `AutoLoadNextPage` view modifier holding the guards, the 300pt threshold and the `FetchTrigger` type; the `@State` pair and the trigger struct are no longer duplicated in `ThumbnailList`.

Behaviour notes:

- **Trigger depth.** Was "the last cell materialized"; is now "within 300pt of the bottom". Comparable in practice — a `List` materializes rows slightly ahead of the viewport — and 300pt is the value Phase 2 already shipped for the other style.
- **DetailList is now guarded where it was not.** The old `.onAppear` had no loading-state or once-per-page guard at all: any re-appearance of the last cell re-fired `fetchMoreAction`. It now fires at most once per gallery count, only while `footerLoadingState == .idle`, and only during a user-driven scroll phase (or when the viewport is underfilled and cannot scroll). Strictly fewer redundant fetches, never fewer pages.
- **DetailList's footer is unaffected.** It is a sibling row shown only when the footer state is *not* idle, and the auto-load requires idle — so the two cannot interleave, and the footer-anchoring feedback loop the Phase 2 comment warns about cannot arise.

## The Binding fix

`AppAlertState.swift:235` built its `isPresented` from a `Binding(get:set:)` pair. Replaced with `Binding($item)` — SwiftUINavigation's optional-to-Bool projection, which has the same semantics (read presence; on a false write, clear through the given transaction). `isPresent()` was tried first, as the plan suggested, and is **deprecated** in the current dependency graph in favour of exactly this initializer; the build surfaced it as a warning.

The `.alert` modifier is still attached to `content` — the same anchor, unchanged, per the confirmation-dialog placement rule.

## The rule flip

Both rules landed in commit `df693e44` together with the last fix and all six directives. Splitting them is not possible: a `disable:next` for a commented-out rule trips `superfluous_disable_command`, and the rule itself trips without the directives.

`lifecycle_modifiers` is uncommented **exactly as drafted**. `binding_initializer` uses D-05's narrowed regex:

```
\bBinding\s*(?:<[^>]*>)?\s*\(\s*get\s*:
```

The drafted regex was `\bBinding\s*<[^>]+>\s*\(|\bBinding\s*\(` — every `Binding(` call, which would have flagged all ~29 projected sites (`Binding($setting.galleryHost)`, `Binding($store.ehSetting)`, …). Those are the idiom the rule exists to encourage. The message was updated to name what is actually banned.

## Verification

- **Standalone SwiftLint binary** over `AppPackage/Sources AppPackage/Tests App ShareExtension` — **0 violations**, JSON reporter, exit 0.
- **Negative control.** A zero-result lint is also what a silently-ignored config produces, so a throwaway probe file was linted before committing: `lifecycle_modifiers` fired on `.onAppear { }`, `binding_initializer` fired on a multi-line `Binding(get:set:)`, and `Binding($x)` on the next line was **not** flagged. Probe deleted; `git status` before the commit showed only the six intended files.
- The six `disable:next` directives are themselves proof the rule is registered — an unknown rule id there would trip `superfluous_disable_command`, which reports zero.
- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED**, 0 errors, 0 warnings (run after each task, and again after the flip).
- `xcodebuild build-for-testing -scheme EhPanda` — **TEST BUILD SUCCEEDED**. Test targets carry the plugin, so this is the gate the app-scheme build does not give.
- Full `AppPackage-Package` suite — **TEST SUCCEEDED**, 0 failures (60s). The two pre-existing `withKnownIssue` markers are unchanged.
- The ~29 projected `Binding($x)` sites are untouched — `git diff` for the flip commit shows only the six files, and the only `Binding` line changed is `AppAlertState.swift:235`.
- `LINT-01` left open — it flips at 11-29.

## Deviations from Plan

### Auto-fixed / expanded scope

**1. [Rule 3 - Blocking] `isPresent()` is deprecated**

- **Found during:** Task 2
- **Issue:** The plan named `$item.isPresent()` as the canonical projected form. It compiles, but emits `'isPresent()' is deprecated: Use 'Binding.init(_:)' to project an optional binding to a Boolean, instead.` This repo builds at zero warnings.
- **Fix:** Used `Binding($item)`, the replacement the deprecation names. Same semantics, and it matches the projected style already used ~29 times elsewhere.
- **Commit:** `df693e44`

**2. [Rule 1 - Bug] `ToastInteractionState` deleted, taking four tests with it**

- **Found during:** Task 1
- **Issue:** Detailed above. Keeping it would have meant asking the owner to sanction two lint exceptions for the upkeep of state that duplicates the presentation binding.
- **Fix:** Type, both callbacks and the four tests of the type removed; the fifth test in that file (the Phase 9 autoHide rule) kept.
- **Commit:** `09c27d91`

**3. [Scope] `ThumbnailList` modified though the plan listed only `DetailList`'s file**

- **Found during:** Task 1
- **Issue:** Same file, but the plan's framing was "fix DetailList". Giving `DetailList` its own copy of the scroll-geometry logic would have duplicated the guards whose subtlety the Phase 2 comment spends nine lines explaining — the next person to touch one would have to find the other.
- **Fix:** Extracted `AutoLoadNextPage` once; both lists call it. Net −20 lines in that file.
- **Commit:** `09c27d91`

### Plan counts that did not match the tree

The prompt's carry-forward listed one lifecycle site in `AppPackage/Tests`, "in scope". There is none — the token grep across `AppPackage/Tests` is empty, and the standalone binary confirms zero violations there with the rule active. Noted rather than treated as a miss.

## D-02 exception candidates for owner review (11-29)

Six sites, the complete repo-wide set. Three carried over from 11-09 (prose already in place, directives added here), three new. Every one carries its argument in-place above the directive.

| # | Site | Token | One-line reason |
|---|---|---|---|
| 1 | `ReadingFeature/ReadingView.swift:123` | `.onDisappear` | Cancels view-owned Vision requests and an autoplay timer; no reducer state, no value change marks removal (11-09) |
| 2 | `ReadingFeature/ReadingViewComponents.swift:143` | `.onAppear` | Lazy-container materialization IS the intended fetch/prefetch trigger; prefetch must run ahead of visibility (11-09) |
| 3 | `ReadingFeature/ReadingViewComponents.swift:341` | `.task(id:)` | Structured cancellation is load-bearing; `load()` branches on `Task.isCancelled` to avoid false failures (11-09) |
| 4 | `SystemNotification/View+Toast.swift:81` | `.task(id:)` | Auto-dismiss timer must die on replacement; the alternative orphans one 3-second sleep per replaced toast |
| 5 | `AppComponents/AppAlertState.swift:252` | `.onAppear` | Alert TextField focus must be applied one runloop after the field joins the responder chain |
| 6 | `AppComponents/PreviewImageView.swift:98` | `.task(id:)` | Cancellation sheds an off-screen cell's in-flight decode; store-less component, no owning reducer |

Sites 3, 4 and 6 are one argument in three places: `.task(id:)` used for *cancellation*, not merely to start work. If the owner wants the count down, the principled move is to narrow the rule's regex to exempt `.task(id:)` — which would resolve three of the six at once — rather than to re-argue them individually. Flagged as a question, not a recommendation.

## Flagged for owner review

**1. Test coverage removed with `ToastInteractionState`.** Four tests deleted along with the type they tested. The invariants they pinned (a stale id cannot activate or dismiss; activation is one-shot) now live in the `item?.state.id == presentedID` guards inside a `ViewModifier`, which is not unit-testable as written. This is a real reduction in *testable surface*, traded for a reduction in *state*. Worth a look if you disagree with the trade.

**2. Device UAT: the toast.** The dismiss/replace paths changed mechanism even though the guards are equivalent. UAT: trigger a success toast and confirm it auto-dismisses after ~3s; trigger one and flick it down early; trigger a network error (diagnostic) toast and confirm it does **not** auto-hide, that tapping it opens the diagnostic, and that a second toast arriving while the first is on screen replaces it cleanly with no flicker or stuck toast.

**3. Device UAT: detail-style gallery list pagination.** The mechanism changed from last-cell appearance to scroll geometry. UAT: with Appearance → list display mode set to **detail**, scroll a multi-page result (Frontpage, Watched, a search) to the bottom and confirm the next page loads at the same point it used to, that it keeps chaining as you continue, and that the scroll position does not jump on append. Then check the underfilled case: a result with fewer galleries than fill the screen should still chain-load until it fills.

**4. Device UAT: the page-jump alert keyboard.** Not changed behaviourally, but its `isPresented` binding was rebuilt. UAT: in the reader, open the page-jump alert and confirm the keyboard comes up focused on the field immediately, and that Cancel/confirm both dismiss it.

**5. `.defaultFocus` was not attempted for site 5.** The plan suggested trying it. It was rejected on the grounds that whether it is honoured inside an alert's presentation container cannot be settled by the build gate, and the failure mode is silent — the keyboard simply never appears. If you want it tried, it is a one-line swap plus a device pass. Recorded so the exception is not read as unexamined.

**6. Both rules are now permanent.** Any future `.onAppear`/`.onDisappear`/`.task` or `Binding(get:set:)` fails the build. That is the intent, but it also means the escape hatch is now a directive that must be argued — the six above are the precedent set.

## Self-Check: PASSED

- `.swiftlint.yml` — FOUND, `lifecycle_modifiers` and `binding_initializer` both uncommented at `severity: error`
- `.planning/phases/11-infra-refactor-lint-capstone/11-11-SUMMARY.md` — FOUND
- Commit `09c27d91` — FOUND
- Commit `df693e44` — FOUND
