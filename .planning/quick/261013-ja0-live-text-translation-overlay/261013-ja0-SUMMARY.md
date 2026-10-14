---
phase: quick-261013-ja0
plan: 01
status: complete
subsystem: reading
tags: [live-text, translation, vision, swiftui, coretext]
completed: 2026-10-14
requirements-completed: [QUICK-261013-ja0]
provides:
  - On-device translated page overlays with sampled fills and bounded text sizes
  - Serial nearest-page translation with one SwiftUI-owned session per language pair
  - Deterministic existing capture behavior and a translation replay handoff
  - Monochrome and animated palette states for the translate toolbar symbol
affects: [17-localized-screenshot-capture-harness]
key-files:
  created:
    - AppPackage/Sources/LiveTextTranslation/
    - AppPackage/Tests/LiveTextTranslationTests/
  modified:
    - AppPackage/Sources/AppModels/Gallery/Language.swift
    - AppPackage/Sources/ReadingFeature/Support/LiveTextHandler.swift
    - AppPackage/Sources/ReadingFeature/Support/LiveTextView.swift
    - AppPackage/Sources/ReadingFeature/Support/ReadingToolbar.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
deferred-items: [JA0-D1]
---

# Live Text translation overlay summary

Live Text now paints translated text over recognized page regions using Apple's on-device
Translation framework. The owner accepted the reviewed result and closed the task on 2026-10-14,
with the intermittent first-request stall retained as unresolved deferred item JA0-D1.

## Delivered behavior

- Gallery languages supported by Vision receive explicit recognition codes. Unmapped galleries
  allow automatic language detection. Source resolution handles Chinese script variants and falls
  back to language recognition; the target follows the reader's preferred app languages.
- Live Text presents translations by default. Same-language pages, pending pages and pages that
  cannot be translated keep the existing highlight presentation. Unchanged translations and
  letterless groups keep their original lettering.
- Balloon detection removes lettering within sampled paper regions and fits translations to the
  balloon's shape. Other regions use sampled fills, or white plates when the surrounding image is
  too busy. CoreText measures and draws the same layout. Each page uses one size S or 85% of S.
- Grouping joins stacked lines and overlapping passages. Spaced languages, including Korean, keep
  words whole. Chinese and Japanese try whole words first, then allow character breaks before
  resorting to a plate. A hopeless group may truncate; tapping it retains the system translation
  popover so the full text can be read. That popover chooses its own target language.
- Translation batches run one page at a time, nearest to the visible page first. Layout can proceed
  independently after each response. Session and batch IDs reject stale results after cancellation
  or reactivation. Completed pages remain cached for the reader session.
- One SwiftUI-owned TranslationSession handles downloads and translation for its language pair.
  The batch call owns the system download prompt, waiting and translation. There is no separate
  `prepareTranslation()` call in the final implementation. Public cancellation is handled before
  model-readiness classification; a declined pair stays deferred until the next activation.
- The toolbar uses `translate`: static monochrome while off, palette with the app's accent color
  and a repeating pulse while on. The localized label, selected accessibility trait and minimum
  44 by 44 point touch target remain. Plain SwiftUI button styling is needed for the pulse to render
  in the toolbar; the automatic style produced a static image in device comparisons.

The implementation adds no automatic retries, readiness polling, arbitrary delays, private
Translation error-code matching, concurrency suppressions or temporary diagnostic logging.

## Implementation commits

The 25 local commits were cherry-picked into `feature/gsd-phase-17` after `d34a0af3b` on
2026-10-14. Their original feature base was `a9f287617`. The documentation commits were rewritten
so the references below identify the integrated commits; nothing was pushed.

| Work | Commits |
| --- | --- |
| Approved plan | `6c2fea3de` |
| Recognition language codes and matching capture-test fixture | `78764091e` |
| Translation module, fitting, rendering, pipeline and reader integration | `37ee67100`, `165c00893`, `6bd510ea5`, `508627e07`, `303cf0909`, `5decf7618` |
| Korean word boundaries and passage grouping | `912867a66`, `a900ffb67` |
| Balloon painting, shaped rooms and CJK fitting | `3fe2bf4b7`, `2dee3d9fe`, `92f21e5d2`, `3424af99c`, `9f1c394d5` |
| Observe translated pages immediately | `c281170aa` |
| Join overlapping passages | `26a3377de` |
| Translate nearest pages first | `3827c9b57` |
| Reuse downloaded language pairs | `ce5b2aac8` |
| Keep translation in one SwiftUI-owned session | `270676f55` |
| Let the batch own downloads and respect cancellation | `45fe4c34f` |
| Record unresolved first-request stall | `019b351a1` |
| Translate toolbar symbol and animated state | `7871bd59a`, `7afd7fbf8` |

## Verification and acceptance

### Final automated gates

After removing the throwaway real-page probe, run 110 built the four affected test targets and
executed them on the dedicated iOS Simulator, with one test invocation at a time:

| Target | Tests | Result |
| --- | ---: | --- |
| AppFeatureTests | 108 | Passed, including capture integration |
| AppModelsTests | 86 | Passed |
| LiveTextTranslationTests | 77 | Passed |
| ReadingFeatureTests | 62 | Passed |
| Total | 333 | Passed |

AppModelsTests intentionally records one expected issue in
`privateFilterValueReportsIssueAndReturnsZero`, asserting that the display-only private category
reports misuse in filter math. This is an existing diagnostic assertion, not an unexpected failure.

The final simulator build passed with zero compiler warnings or errors. The final iPad Release
build (run 109) and strict SwiftLint checks also passed. The app installed for owner review is that
clean Release build. Result bundle: `build/ja0/results/110-close.xcresult`; logs:
`build/ja0/logs/110-close-build.log` and `build/ja0/logs/110-close-tests.log`.

### Integration verification

Run 111 repeated the simulator build and affected tests after cherry-picking onto the phase branch.
The build passed with zero compiler warnings or errors. All 336 tests passed: 111 AppFeature,
86 AppModels, 77 LiveTextTranslation and 62 ReadingFeature tests. The three additional AppFeature
tests come from the phase branch; AppModels retains its one expected issue described above.
Result bundle: `build/ja0/results/111-integration.xcresult`; logs:
`build/ja0/logs/111-integration-build.log` and `build/ja0/logs/111-integration-tests.log`.

All 38 implementation and test files changed by this task are byte-identical to the accepted
feature tip. Each rewritten GSD SHA reference was checked against its containing commit's ancestry.
The phase checkout's existing unstaged edit and four staged entries were preserved separately
from these commits.

### Runtime and visual evidence

The initial iOS 27 Simulator probe reported the required Translation pairs as unsupported and an
installed-session attempt threw `unsupportedLanguagePairing`. Vision recognition support was
verified there; live Translation verification therefore used physical devices. The earlier draft
records iPhone 11 checks, including same-language highlighting and English to Traditional Chinese.
The takeover and final verification used only the authorized iPad mini 6.

Earlier real-page renders used host translations at iPhone and iPad widths for English to Japanese,
Traditional Chinese, Simplified Chinese, Korean and German. These are layout evidence, not proof of
every language and appearance combination on physical hardware. The original full Cartesian visual
matrix was not rerun at closure. The owner reviewed the supplied iPad captures, requested the toolbar
changes, then explicitly accepted closure with the recorded limitations.

On the final download flow, two consecutive prompt cancellations and reactivations in one reader
returned public `CocoaError.userCancelled`. A third prompt completed downloading and continued to
translate without another activation. Native connection-cleanup messages were still observed;
there was no application translation-failure toast or internal translation error in that run.

Three independent Japanese cold-launch workloads completed all 18 text-bearing pages of the
20-page sample. Times are measured from automation tap completion to layout readiness, not to a
captured first frame:

| Run | Initial availability | Completed pages | Page 20 ready | Last page ready |
| --- | --- | --- | --- | --- |
| 99 | supported | 18/18 | 4.091512 s | 27.015175 s |
| 100 | supported | 18/18 | 3.753084 s | 26.989630 s |
| 101 | supported | 18/18 | 3.982138 s | 27.881614 s |

Installed models can initially be reported as `supported`; that status is not proof that a new
download is actually needed. These successful runs do not resolve the historical first-request
stall documented in [deferred-items.md](deferred-items.md).

Owner review artifacts retained locally:

- `build/ja0/device/103-review-page20-ja.png`: sparse translated page.
- `build/ja0/device/103-review-page7-ja.png`: dense translated page and known layout limitations.
- `build/ja0/device/109-toolbar-off.png`: final monochrome toolbar state.
- `build/ja0/device/109-pulse/on-00.png` through `on-03.png`: final on-state frames at approximately
  0.94, 1.83, 2.70 and 3.58 seconds, showing bright/dim/bright/dim. The app's accent was green.
- `build/ja0/device/109-pulse-contact.png`: cropped contact sheet of those actual frames.

Run 108 also verified that disabling Live Text stopped the pulse and restored a static monochrome
symbol. Reduce Motion was not changed on the device; the opacity pulse follows the project's
existing reduced-motion indicator pattern. No successful screen recording is claimed: the
automation recorder failed on a dense accessibility tree, and native device recording was unsupported.

## Revert-isolation gate

Task 9 compared `git revert --no-commit` for each budgeted reader change on base `a9f287617` and
the feature implementation tip. The gate was repeated after integration against the rewritten
implementation tip `7afd7fbf8`. All 16 comparisons passed. Eight reversions are clean on both tips;
eight have the same pre-existing conflict on both tips. All resulting diff bodies matched after
excluding hunk line numbers and index lines. No attempt touched a file added by this feature, and
the matching diffs establish that no translation hunk was taken along.

| Reader change | Base | Feature tip | Gate |
| --- | --- | --- | --- |
| `bdcd01a3e` | Conflict | Conflict | Pass |
| `c859b4567` | Conflict | Conflict | Pass |
| `3e02a2d41` | Conflict | Conflict | Pass |
| `ceba7df44` | Conflict | Conflict | Pass |
| `8a3851e3e` | Clean | Clean | Pass |
| `8545b0c10` | Clean | Clean | Pass |
| `7aeb4dfa7` | Clean | Clean | Pass |
| `dbb8b9abe` | Clean | Clean | Pass |
| `b0d7f69fa` | Conflict | Conflict | Pass |
| `043a14286` | Conflict | Conflict | Pass |
| `658dc6984` | Conflict | Conflict | Pass |
| `0975aca9d` | Conflict | Conflict | Pass |
| `6eea651db` | Clean | Clean | Pass |
| `2672bc567` | Clean | Clean | Pass |
| `ab670e559` | Clean | Clean | Pass |
| `94d3c3803` | Clean | Clean | Pass |

The worktree returned to its integration branch and clean state after the gate. The full local
reports are `build/ja0/logs/110-final-revert-gate.json` and
`build/ja0/logs/111-integration-revert-gate.json`. This closure commit changes documentation only.

## Plan adjustments and fixes

- Orchestration lives in the new module's observable `LiveTextTranslator`, rather than in
  `LiveTextHandler`. The handler owns it and supplies recognized pages; the view observes published
  translated pages. An observed group-to-page lookup fixed overlays that formerly appeared only
  after recreating a view. A regression test first reproduced that failure.
- The original separate preparation and installed-session design was superseded by the approved
  single-session investigation. Final code uses `View.liveTextTranslations(for:)`; a batch owns
  downloading and cancellation. The plan's `prepareTranslation()` and download-wrapper descriptions
  are historical proposals, not the final API path.
- Shape-aware balloon painting, revised grouping and word-boundary fitting followed the owner's
  visual-review decisions. Nearest-page serial scheduling followed the measured translation
  bottleneck. Overlap grouping and late-page session reuse have regression coverage.
- Most pipeline tests live in LiveTextTranslationTests; ReadingFeatureTests cover handler
  integration, capture guards and failure toasts. The Japanese recognition-code fixture correction
  was folded into the original recognition commit so capture replay agrees with the new mapping.
- The owner later requested the toolbar symbol and state presentation. These supersede the plan's
  original statement that ReadingToolbar.swift would not change; no additional control was added.

## Capture-session handoff

Capture implementation remains owned by phase 17. This task does not add translation recording,
replay, fixture selection or capture-harness changes.

1. **Current deterministic seam:** Debug `LiveTextCapture.Source` supports recorded group replay
   and recognition recording. `LiveTextHandler.translatesPages` is false whenever a capture is
   installed, so current captures show highlights and never call Translation or request models.
2. **Replay insertion point:** extend the capture source with saved translations and feed them into
   the pipeline at the batch-response boundary, before layout. The current native response shape is
   `[UUID: String]`, keyed by each recorded group's ID. `LiveTextTranslatedPage.layOut(groups:sources:
   translations:language:image:)` is the existing public layout entry point. Reuse normal
   normalization, image sampling, geometry, fitting and rendering. Do not run live Translation
   during a deterministic capture or persist pre-rendered overlays as a substitute for layout.
3. **Record shape to carry forward:** retain the OCR record's schema version, gallery/page identity,
   page-image SHA-256, recognition languages, recording provenance, group IDs and recognized blocks.
   Add source/target language identifiers and translations associated with those same group IDs;
   retain or validate normalized source text so a translation cannot silently attach to changed OCR.
   This is a handoff proposal for the capture owner, not a newly shipped or approved JSON schema.
4. **Recognition compatibility:** re-record fixtures for languages that gained explicit recognition
   codes, including Japanese and Korean. Existing English `en-US` records are unaffected by the
   language-code change. Replay already validates image hash, recognition languages and unique IDs.
5. **O-3 source selection:** non-English coordinates (ja, zh-Hant, zh-Hans, ko, de) translate an
   English-original work into the coordinate language. The English coordinate translates another
   language version of that same work into English. Nonexplicit gallery selection and owner-supplied
   explicit material remain separate capture-session responsibilities.
6. **O-4 and O-5:** the marketing Live Text screen has no control panel and uses a different gallery
   from the ordinary reading screen. When translation replay is implemented, amend phase 17 D-15
   from highlighted recognized regions to painted translated regions, including the alternate
   source-language requirement for the English coordinate. Until then, preserve current highlights.

## Deferred work and accepted limits

- **JA0-D1 remains deferred and unresolved:** an intermittent first translation request stalled for
  138.829617 seconds in run 83. Reactivation recovered, but the original call did not return. The
  owner explicitly deferred investigation, accepted closure and will return to it later. Preserve
  the observations and reopen conditions in [deferred-items.md](deferred-items.md); successful later
  runs must not be described as a root-cause fix.
- Dense magazine text can be small under the one-size-per-page rule. A display heading can join
  nearby body text, and plates can overlap or become large. These were shown in owner-review
  screenshots; no additional layout redesign was included at closure.
- OCR and translation quality remain input-dependent. Distressed lettering, names and headings may
  be misread or mistranslated. Narrow CJK balloon rows can still strand short character fragments;
  spaced-language word boundaries are preserved.
- A manual highlight-only mode, target-language setting, persistent translations, animated-page
  translation and alternate translation providers remain outside this task's scope.

## Closure

- All nine planned tasks are complete under the owner's acceptance and explicit JA0-D1 deferral.
- The untracked `RealPageProbeTests.swift` was removed from test sources and retained only as
  `build/ja0/drafts/RealPageProbeTests-retired.swift`. It was never committed.
- The iPad automation session was closed. Cleanup reported stale recording metadata from the
  earlier failed runner, but the session list is empty, the active runner ended successfully and
  the device process inventory contains no AgentDeviceRunner. No usable recording was produced.
- Scratch logs, renders and investigation notes are retained in the phase checkout, ignored under
  `build/ja0/`, during integration cleanup. Essential findings are preserved in this summary and
  the deferred-items document so they do not depend on those local artifacts surviving.
- Per Task 9, the `STATE.md` quick-task row was added during integration, referencing the final
  implementation commit. Phase 17's own workflow position is unchanged. The owner authorized
  removal of only the Live Text worktree and its branch after integration; other session worktrees
  remain outside this cleanup. No push or deferred-item investigation was performed.
