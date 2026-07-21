# Phase 11 — Exception Inventory & Capstone Verification

**Generated:** 2026-07-21 (plan 11-29, the capstone)
**Status:** awaiting owner batch review

---

## How to read this document

Per the CONTEXT exception-review flow (D-01, applied): executors did **not** pause mid-execution
for exception approval. Candidate exceptions were written in the D-02 form (`// reason: …` +
`// swiftlint:disable:next`) as they arose, and **the owner reviews the full batch here, at
phase-end verification. Unapproved entries get reworked, not shipped.**

Two things this document deliberately separates:

1. **Exceptions this phase created** (§2) from **exceptions that pre-date it** (§3). A pre-existing
   `cyclomatic_complexity` disable in ParserFeature is not a Phase 11 artifact and must not be
   reviewed as one.
2. **What the phase delivered** from **what it did not** (§7). Three of the phase's stated
   must-haves are unachievable as written or only half-done. They are recorded plainly rather than
   dressed up.

Everything below is grounded in the tree at HEAD, enumerated with the standalone SwiftLint binary
or `grep` + `git blame`, not carried forward from plan text. Where a prior summary's claim did not
survive contact with the tree, the discrepancy is called out.

---

## 1. The verification battery

Every command and its verbatim result. The standalone binary is the DerivedData artifactbundle
`swiftlint` (version **0.65.0**); it is not on `PATH`.

### 1.1 Rule zero-check — all eight enforced rules

```
swiftlint lint --strict --no-cache --reporter json --config .swiftlint.yml \
    AppPackage/Sources AppPackage/Tests App ShareExtension
```

**Result: `Found 0 violations, 0 serious in 452 files`, exit 0.** Zero entries for every rule id,
including all eight LINT-01 deliverables:

| Rule | Kind | Violations |
|---|---|---:|
| `lifecycle_modifiers` | custom | 0 |
| `binding_initializer` | custom | 0 |
| `unchecked_subscript_index_access` | custom | 0 |
| `labeled_tuple_elements` | custom | 0 |
| `optional_try` | custom | 0 |
| `single_line_trailing_closure` | custom | 0 |
| `sorted_imports` | built-in opt-in | 0 |
| `multiline_function_chains` | built-in opt-in | 0 |

stderr carried **no** `Invalid configuration … Falling back to default` line, so no rule is silently
discarded.

> **A note on "seven".** The phase is framed around seven rules; there are **eight**.
> `single_line_trailing_closure` is a full LINT-01 deliverable (ROADMAP criterion 1 names it, and
> waves 11-26/11-27 swept 215 sites for it), but it is routinely omitted from the phase's own
> shorthand. All eight are verified here.

### 1.2 Negative control — proving the rules actually fire

A zero-violation lint is exactly what a silently-discarded config also produces. This phase found
**two** config constructs that are inert in a way that reads as success (§8), so the zero above
proves nothing on its own. A throwaway probe was linted against the **live** config and deleted:

| Rule | Probe construct | Fired |
|---|---|---|
| `lifecycle_modifiers` | `.onAppear { … }` | ✓ |
| `binding_initializer` | `Binding(get:set:)` | ✓ |
| `unchecked_subscript_index_access` | `a[i]` | ✓ |
| `labeled_tuple_elements` | `-> (Int, String)` | ✓ |
| `optional_try` | `try? f()` | ✓ |
| `single_line_trailing_closure` | `[1].map { $0 * 2 }` | ✓ |
| `sorted_imports` | `import SwiftUI` before `import Foundation` | ✓ |
| `multiline_function_chains` | two calls sharing the base line | ✓ |

All eight fire. The rules are registered and enforcing.

### 1.3 Clean build under the plugin — source AND test targets

```
xcodebuild build             -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air'
xcodebuild build-for-testing -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air'
```

**`** BUILD SUCCEEDED ** [23.580 sec]`** and **`** TEST BUILD SUCCEEDED ** [29.240 sec]`**,
0 errors, 0 warnings, run sequentially (never concurrently).

Both are required. The app-scheme build does **not** lint `Tests/` — the `e8589355` incident class,
where a 137-character line in a test file passed the app gate and broke the test build.

### 1.4 Full parallel suite

```
cd AppPackage && xcodebuild test -scheme AppPackage-Package \
    -destination 'platform=iOS Simulator,name=iPhone Air'
```

**`** TEST SUCCEEDED ** [67.992 sec]`, exit 0, 0 failures.**

`TEST SUCCEEDED` alone is not evidence on this project: the XCTest summary lines print
`Executed 0 tests` (everything is Swift Testing), so a suite that silently ran nothing prints the
same banner. The Swift Testing `Test run with N tests` lines were summed:

**565 tests across 18 test runs (= 18 targets).** Matches the expected count exactly.

### 1.5 Cookie-logging scan

```
bash Scripts/check-cookie-logging.sh
```

**`Cookie logging audit passed.`, exit 0.**

### 1.6 Test-plan coverage audit

11-22.1 flagged that nothing re-audits `FeatureTests.xctestplan` against the test directories, and
that the drift it repaired went unnoticed across at least three target additions. Checked here:

- `AppPackage/Tests/*/` directories: **18**
- `FeatureTests.xctestplan` `testTargets`: **18**
- Set difference in **both** directions: **empty**

No drift today. The gap 11-22.1 identified — that nothing enforces this — remains open (§8).

---

## 2. Exceptions this phase created

**Total: 8 `swiftlint:disable` directives**, across two rules. Every one carries a `// reason:` line
and prose argument in place, and every one was landed in the same commit that flipped its rule (a
directive naming a not-yet-registered rule trips `superfluous_disable_command`).

Verified by `git blame`: all 8 date to `df693e44` (11-11), `3bf28440` (11-17) or `5c7b56fc` (11-12).

### 2.1 `lifecycle_modifiers` — 6 exceptions

| # | Site | Token | Argument | From |
|---|---|---|---|---|
| 1 | `AppPackage/Sources/ReadingFeature/ReadingView.swift:122` | `.onDisappear` | Tears down two **view-owned `@State` handlers** — in-flight Vision requests and a repeating autoplay timer. Neither is reducer state, and no value change marks the view's removal. Dropping it leaks a timer that keeps turning pages of a reader nobody is looking at. The persistence half is already handled by the reducer on `.onPerformDismiss`. | 11-09 |
| 2 | `AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift:142` | `.onAppear` | **Lazy-container materialization *is* the intended fetch/prefetch trigger.** No reducer signal reproduces it: `pageModel.index` moves only on settled page changes, dual-page maps one position to two indices, and the vertical list renders many containers at once. `onScrollTargetVisibilityChange` fires at visibility, whereas prefetch exists to run *ahead* of it. | 11-09 |
| 3 | `AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift:340` | `.task(id: url)` | **Cancellation is load-bearing.** Ties the download to both the view's lifetime and the URL's identity; `load()` reads `Task.isCancelled` to tell a cancellation from a real failure. The only non-banned alternative (`.onChange(of:initial:)` + unstructured `Task`) drops that and leaks concurrent image downloads on the reader's hottest path. | 11-09 |
| 4 | `AppPackage/Sources/SystemNotification/View+Toast.swift:80` | `.task(id: id)` | **Cancellation is the mechanism.** The auto-dismiss timer must die the instant the toast is replaced or flicked away, and keying on the state id restarts it per toast. The alternative orphans one 3-second sleep per replaced toast. | 11-11 |
| 5 | `AppPackage/Sources/AppComponents/AppAlertState.swift:251` | `.onAppear` | Alert `TextField` focus must be raised one runloop **after** the field joins the responder chain. The field renders into a separate presentation container the host cannot observe, so no action or value change marks that moment. `.defaultFocus` was considered and rejected — whether it is honoured inside an alert container is not something the build gate can prove, and the failure is silent (the keyboard simply never appears). | 11-11 |
| 6 | `AppPackage/Sources/AppComponents/PreviewImageView.swift:97` | `.task(id: cacheKey)` | **Cancellation sheds off-screen work.** `loadThumbnail()` reads `Task.isCancelled` so a cell scrolled off screen drops its in-flight decode. Store-less component reused across every grid, so there is no owning reducer; the cache key is derived from file metadata read in the view. | 11-11 |

### 2.2 `unchecked_subscript_index_access` — 2 exceptions

The phase's only two, out of **240 matches** resolved across five waves (11-13…11-17).

| # | Site | Invariant | Why not restructured |
|---|---|---|---|
| 1 | `AppPackage/Sources/AppModels/Persistent/GalleryHistory+Operations.swift:43` | `firstIndex(where:)` only ever yields a subscriptable index, restated as an explicit `precondition` | The mutation must happen **in place** — the sibling `recordGalleryOpen`'s `removeAll` + `insert` idiom would move the entry to the front, and this function's contract is explicitly "leaving its recency and position untouched" |
| 2 | `AppPackage/Sources/PreviewSupport/PreviewIdentifiers.swift:1046` | `precondition(all.indices.contains(index))` on the line above | The type exists to **trap loudly** rather than substitute a wrapped-around identifier — the trap is the feature, so the subscript cannot be removed |

Both preconditions are, by construction, **unfirable**. That is the honest reading of a rule that
asks for *guarded* access — where the guard is a `firstIndex` call or an explicit `precondition`,
restating it at the access is documentation, not defence. But if you would rather the exception form
mean "a check that can actually fail", these two have no principled annotation available, since
neither subscript can be removed. **A decision point, recorded in §5.**

### 2.3 Exceptions this phase created for the other six rules

**None.** Across `optional_try` (316 inventoried sites), `binding_initializer`,
`labeled_tuple_elements`, `single_line_trailing_closure` (215 sites), `sorted_imports` (893
violations) and `multiline_function_chains` (43 sites), **not one `swiftlint:disable` directive was
written.** Four consecutive flips (11-24, 11-25, 11-27, 11-28) shipped with an empty directive
payload.

> Consequence worth knowing: the D-02 exception form is **untested for `optional_try`
> specifically**. 11-17 probed it end-to-end for the subscript rule and confirmed it composes with
> `swiftlint_disable_requires_reason` and `superfluous_disable_command`; the mechanism is
> rule-agnostic, so it should behave identically — but the first contributor who genuinely needs one
> will be exercising it for the first time.

---

## 3. Pre-existing exceptions — NOT phase artifacts

**20 directives**, none created by this phase. Listed so the §2 set can be read as complete, and so
none of these is mistaken for Phase 11 work. `git blame` attribution given.

| Site | Rule(s) | Origin |
|---|---|---|
| `AppPackage/Sources/ParserFeature/Parser+Profile.swift:23` | `cyclomatic_complexity` `function_body_length` | `4d05cd03` "Resolve lint issues" |
| `AppPackage/Sources/ParserFeature/Parser+Profile.swift:33` | `line_length` | `4d05cd03` |
| `AppPackage/Sources/ParserFeature/Parser+Profile.swift:205` | `line_length` | `4d05cd03` |
| `AppPackage/Sources/ParserFeature/Parser+Greeting.swift:6` | `cyclomatic_complexity` | `4d05cd03` |
| `AppPackage/Sources/ParserFeature/Parser+Comment.swift:7` | `cyclomatic_complexity` `function_body_length` | `4d05cd03` |
| `AppPackage/Sources/ParserFeature/Parser+Comment.swift:82` | `function_body_length` `cyclomatic_complexity` | `4d05cd03` |
| `AppPackage/Sources/ParserFeature/Parser+Torrent.swift:7` | `cyclomatic_complexity` `function_body_length` | `4d05cd03` |
| `AppPackage/Sources/ParserFeature/Parser+Shared.swift:138` | `cyclomatic_complexity` | `4d05cd03` |
| `AppPackage/Sources/ParserFeature/Parser+Detail.swift:13` | `function_body_length` | `4d05cd03` |
| `AppPackage/Sources/ParserFeature/Parser+Detail.swift:222` | `cyclomatic_complexity` | `4d05cd03` |
| `AppPackage/Sources/AppModels/Gallery/Language.swift:9` | `line_length` | `75029014` (2022) |
| `AppPackage/Sources/AppModels/Gallery/Language.swift:29` | `switch_case_alignment` `line_length` | `4d05cd03` |
| `AppPackage/Sources/AppModels/Gallery/GalleryDetail.swift:123` | `identifier_name` | `9555b7bd` "Extract AppModels module" |
| `AppPackage/Sources/AppModels/Support/EhSetting.swift:95` | `line_length` | `9555b7bd` |
| `AppPackage/Sources/AppModels/Support/BrowsingCountry.swift:5` | `line_length` | `75029014` (2022) |
| `AppPackage/Sources/AppTools/Defaults.swift:85` | `nesting` `identifier_name` | `9555b7bd` |
| `AppPackage/Sources/AppTools/DeviceType.swift:7` | `identifier_name` | `87c0cc2d` (Phase 5) |
| `AppPackage/Sources/ReadingFeature/Support/LiveTextHandler.swift:2` | `line_length` | `ef7395de` (2025) |
| `AppPackage/Sources/PreviewSupport/PreviewIdentifiers.swift:4` | `file_length` | `5c7b56fc` (11-12) — see note |

**One boundary case.** `PreviewIdentifiers.swift:4`'s `file_length` disable was created **by this
phase** (11-12), but it is not a LINT-01 rule exception — the file is a 1,048-line table of frozen
UUID literals, of which 1,000 are data. It is listed here rather than in §2 because reviewing it as
a lint-ratchet exception would misclassify it, but it is the phase's work and you may want to see it.

### 3.1 A gap in `swiftlint_disable_requires_reason`

**14 of the 20 pre-existing disables carry no `// reason:` line at all**, and the repo lints clean.

The rule's regex requires `// reason:` on the line immediately preceding the directive, but it
declares `match_kinds: [comment]` — so the *whole match*, including the preceding line, must be
comment-kind. A disable whose preceding line is code (`extension Parser {`, `case yes`, a blank
line) is **never matched**, and the reason requirement never applies to it.

Only 6 disables in the tree carry a reason line: the 2 subscript exceptions, `DeviceType.swift`,
`BrowsingCountry.swift`, `LiveTextHandler.swift`, and `PreviewIdentifiers.swift`'s `file_length`.
The 6 `lifecycle_modifiers` exceptions carry multi-line prose arguments whose last line is a comment,
which is what satisfies the rule for them.

This is not a Phase 11 regression — the rule pre-dates the phase — but the phase's exception
mechanism rests on it, so the limit is worth knowing: **the reason requirement is enforced only
where a comment already precedes the directive.** Closing it means matching on the directive line
alone and inspecting the preceding line independently, which a `match_kinds`-scoped regex cannot do.

---

## 4. Retained serialization traits

**None. Zero `.serialized` traits survive anywhere in `AppPackage/Tests`.**

`grep -rn '\.serialized' AppPackage/Tests` returns exactly one hit, and it is **prose** —
`DidLoginKeyTests.swift:20`, a comment explaining why a trait would be pointless.

All 41 traits inventoried at phase start were removed:

| Wave | Traits removed | Mechanism |
|---|---:|---|
| 11-19 | 1 (`FileClientTests`) | `FileClient.live(applicationSupportURL:cachesURL:)` — injectable roots with production defaults (D-12) |
| 11-20 | 2 (`DownloadImageParsingTests`, `DownloadImageParsingCacheTests`) + 1 (`ImageClientTests`) | Pointed the tests at the `DataCache` the production path actually reads, instead of priming a Kingfisher cache it stopped consulting |
| 11-21 | 38 (`DownloadsFeatureTests`) | Per-suite diagnosis; one real failure fixed with `DownloadCoordinator.init(now:)` rather than a widened bound |

### The one documented keeper — and what it actually is

`AppPackage/Tests/CookieClientTests/DidLoginKeyTests.swift` is the D-14 exception, and it is worth
being precise: **there is no trait**, and adding one would be theatre. `.serialized` orders cases
*within* a suite, and this suite has exactly one case. **The isolation mechanism is the suite's
shape**, and the in-file comment says so rather than implying a trait is doing the work.

The rationale: Sharing's reference cache is a process-global weak table keyed by `AnyHashable(id)`;
`.didLogin` has one constant id, so every reader resolves to one reference that captured whichever
`cookieClient` was in scope when it was first created. Per-test key ids are not the escape hatch —
they would dissolve the coupling and the coverage together, because the point is to test the
*production* key.

### A production race found and fixed here, and one still open

11-20's stability runs surfaced a **real flake**, root-caused to production code rather than papered
over: `DidLoginKey.subscribe` created its jar stream *inside* the consuming `Task`, so a notification
published between `subscribe` returning and the task starting reached zero subscribers and was lost.
Fixed by creating the stream synchronously in `subscribe`.

**The same window still exists, narrower, in the live `CookieClient`** — see §6.1.

---

## 5. Retained `@MainActor` annotations

**185 survivors across 45 test files.** Every one sits on a **member**, never on a suite type, and
every retaining file carries a comment naming the requirement and stating that unannotated cases are
deliberately free.

### Phase-wide sweep result

| | Files annotated | Fully freed | Retaining | Annotations | `@Test` cases | Isolated | Freed |
|---|---:|---:|---:|---:|---:|---:|---:|
| 11-22 (Downloads) | 27 | 3 | 24 | 108 → 104 | 104 | 92 → 85 | 7 |
| 11-22.1 (6 targets) | 23 | 2 | 21 | 34 → 81 | 82 | 82 → 72 | 10 |
| **Phase total** | **50** | **5** | **45** | **142 → 185** | **186** | **174 → 157** | **17** |

Annotation count **rose**, from 142 to 185, while isolation **narrowed**. That is the honest
arithmetic of following "narrowest scope" literally: one suite-level attribute covering N cases is
replaced by attributes on the M members that actually need it, and M can exceed 1.

### The three requirements, phase-wide

| Requirement | Scope | Note |
|---|---|---|
| TCA `TestStore.init` / `TestStore.state` are main-actor-isolated | dominant — the large majority of survivors | Not removable without a change to TCA |
| `PageHandler` is a `@MainActor` type | `ReadingFeatureTests/PageHandlerTests` (10) | Production type; see §6.8 |
| `GestureHandler` is a `@MainActor` type | `ReadingFeatureTests/GestureHandlerTests` (5) | Production type; see §6.8 |

### Why no survivor sits on a suite type

Marking the **type** `@MainActor` makes its `DownloadFeatureTestCase` conformance main-actor-isolated,
and these suites call protocol requirements from inside `@Sendable` dependency closures. That
combination does not compile:

```
error: main actor-isolated conformance of 'DetailReducerMetadataTests' to
'DownloadFeatureTestCase' cannot be used in caller isolation inheriting-isolated context
```

It broke two files outright and is latent in fourteen more. **Rule applied uniformly: annotate
members, never the suite type.** Verified at HEAD — zero `@MainActor` on a suite type declaration.

### Parallelism, proven

680 of 690 case-starts occur before the first case in their bundle finishes (11-22.1's run logs; 690
> 565 because parameterized cases count once per argument). Per-bundle: `DownloadsFeatureTests`
254/254, `ReadingFeatureTests` 90/90, `SettingFeatureTests` 78/78, `AppFeatureTests` 36/36,
`ParserFeatureTests` 34/34, `CookieClientTests` 15/15.

---

## 6. Decisions and findings for the owner

### 6.1 DECISION — narrow `lifecycle_modifiers` to exempt `.task(id:)`

**This halves the exception list, and it is the single highest-value item in this document.**

Three of the six `lifecycle_modifiers` exceptions — §2.1 sites **3, 4 and 6** — are one argument
stated in three places: **`.task(id:)` used for its *cancellation*, not to start work.** In every
one, the consuming code branches on `Task.isCancelled` (or relies on the timer dying), and every
non-banned alternative (`.onChange(of:initial:)` firing an unstructured `Task`) drops the
cancellation and leaks work.

D-06 makes `lifecycle_modifiers` a blanket ban on `.onAppear` / `.onDisappear` / `.task`. If the
regex were narrowed to exempt the `.task(id:)` form specifically, **three of six exceptions
disappear**, and the rule's remaining three are each a genuinely distinct argument (view-owned
handler teardown, lazy-container materialization, alert focus timing).

The principled framing 11-11 raised: *if you want the count down, narrow the rule rather than
re-argue the sites individually.*

**Not implemented.** This is a rule-tuning decision that belongs to the owner, and this plan is
explicitly not authorized to add, remove or retune a rule. Recorded as a question.

Counter-argument worth weighing: `.task(id:)` can also be used simply to start work, in which case
exempting it opens a hole D-06 deliberately closed. A narrowing would be a change in what the rule
means, not just in how many exceptions it needs.

### 6.2 The `DidLoginKey` race still exists in the live client

11-20 fixed the subscription-registration race in `DidLoginKey.subscribe`. **The same shape survives
in `CookieClient.live`** — `AppPackage/Sources/CookieClient/CookieClient.swift:37–39` builds its
`NotificationCenter` observer inside an inner `Task` within the `AsyncStream` initializer, so a jar
mutation in the instant after subscription can still be missed **in production**.

Verified present at HEAD. Impact is smaller than in the testing store — the key's `load` re-reads
`didLogin` at creation, so only a change inside that window is lost, and the next change corrects it
— but this is a real production race, not a test artifact. Closing it means awaiting observer
registration before the stream is considered live.

*(11-20)*

### 6.3 `AnimatedImageFeature` has no test target, and 11-17 rewrote its byte parser

Verified: `AppPackage/Tests/` contains **no** `AnimatedImageFeatureTests` directory.

11-17 restructured the GIF/WebP animation-detection walkers — 14 unchecked reads into untrusted
image data — introducing a bounds-checked `byte(_:at:)` accessor, `UInt32(littleEndian:)` /
`UInt32(bigEndian:)` + `loadUnaligned`, and `elementsEqual`. It also **added a missing `offset >= 0`
term** both chunk-size guards lacked; a negative offset previously passed `offset + 4 <= count` and
then read out of bounds.

Correctness rests on argument (byte-for-byte equivalence of the endian conversions on a
little-endian host, identical loop bounds) plus a green full suite. **Nothing tests that an animated
GIF is still detected as animated.** This module is the repo's strongest candidate for a test target.

**UAT in the meantime:** open a gallery containing an animated GIF and one containing an animated
WebP, confirm both still animate rather than showing a first frame; open a static JPEG/PNG gallery
and confirm nothing regressed.

*(11-17)*

### 6.4 The gallery-URL grammar has four independent implementations

Verified at HEAD — all four present:

| Implementation | Location | Strictness |
|---|---|---|
| `Parser.GalleryTitleInfo` | `AppPackage/Sources/ParserFeature/Parser+Types.swift:32`, built at `Parser+List.swift:260` | requires token |
| `URL.galleryIdentifiers` | `AppPackage/Sources/NetworkingFeature/Request+Detail.swift:358` | requires token |
| `GalleryRoute` | `AppPackage/Sources/URLClient/URLClient.swift:29` | token optional |
| inline `popFirst` walk | `AppPackage/Sources/AppModels/Support/AppError+Context.swift` | accepts token-less `/g/<gid>`; handles `/s/` too |

All four decode `/<kind>/<gid>/<token>`. They differ in genuinely meaningful ways — whether `kind`
is validated, whether a token is required, what happens on mismatch — so consolidation is not
mechanical and forcing them together would change at least two behaviourally. **But four copies of
one URL grammar will drift.** Worth a follow-up that puts the grammar in one place with strictness
as a parameter.

Relatedly, **`parseTags` is duplicated**: `Request+GalleriesMetadata.parseTags`
(`AppPackage/Sources/NetworkingFeature/Request+GalleriesMetadata.swift:61`) and
`Parser.parseGalleryTags` (`Parser+List.swift:282`, `Parser+Detail.swift:162`) both group
`"namespace:content"` strings into `[GalleryTag]`, and 11-14 and 11-15 fixed the *identical*
Array-subscript defect in the two copies hours apart. NetworkingFeature already imports
ParserFeature, but the input shapes differ (flat `[String]` from `gdata` JSON vs. HTML nodes) plus
vote flags, so it needs a shared helper rather than a straight call.

*(11-14, 11-15, 11-17)*

### 6.5 `EhSetting`'s remote-parsed arrays have no count invariant

11-15 replaced three unchecked parallel-array loops in `EhSettingRequest`'s form assembly with
`zip` / `prefix(10)`. That removed a genuine trap — a settings page yielding fewer entries than the
static tables would have crashed mid-request-assembly — but it means **a short parse now silently
submits a partial form** rather than crashing. Arguably worse than a loud failure, strictly better
than a trap.

`EhSetting.empty` builds them at 10/10/50 and `EhSetting.categoryNames` derives from
`Category.allFiltersCases`, so the intended counts are knowable. If you want the mismatch to be
loud, the right place is a validation in the `EhSetting` parser — not a re-added trap in the request.

*(11-15)*

### 6.6 `ImageColors.colors` tie-breaks nondeterministically — pre-existing

Verified at HEAD: `AppPackage/Sources/ImageColors/ImageColors.swift:88` and `:116` both call
`.sorted(by: { $0.count > $1.count })` on input derived from `colorCounts.keys`. Swift's sort is
unstable and `Dictionary` iteration order varies with the per-process hash seed, so **two runs on
the same image can return different accent colors when candidate counts tie.**

This predates the milestone and is not a regression. It is recorded because it was **load-bearing in
11-16's parity reasoning**: the histogram walk was reordered from column-major to memory order, and
the argument that this is safe rests partly on the tie-break already being nondeterministic, so
nothing could depend on it.

If you want determinism, the fix is a total-order comparator (tie-break on the packed color value) —
a two-token change to both `sorted` calls, but genuinely an algorithm change.

*(11-16)*

### 6.7 `parseInfoPanel` rejects the whole detail parse rather than degrading one field

Verified at HEAD, `AppPackage/Sources/ParserFeature/Parser+Detail.swift:275–276`:

```swift
guard ![postedDate, parentURL, visibility, language,
        fileSize, sizeType, pageCount, favoritedCount].contains(where: \.isEmpty)
else { throw AppError.parseFailed }
```

A gallery whose "Favorited" row genuinely reads as empty fails the **whole** detail parse. Behaviour
is unchanged from before the phase — 11-14 restated the pre-existing `filter { !$0.isEmpty }.count == 8`
as a named-field guard — and the `"Never" → "0"` / `"Once" → "1"` replacements suggest the remote
page never emits an empty value there. **Worth confirming against a real gallery with zero
favourites**, since a regression here rejects the whole detail rather than degrading one field.

*(11-14)*

### 6.8 Smaller confirmed items

- **`saveTorrent` writes a fixed real Caches path.** Verified at
  `AppPackage/Sources/FileClient/FileClient.swift:181` — `URL.cachesDirectory.appendingPathComponent("\(hash).torrent")`,
  outside 11-19's injected seam. It is an instance method with no access to the injected roots, so
  moving it onto the seam means making it a closure property like the others. No test races on it
  today. *(11-19)*

- **`GestureHandler` and `PageHandler` are `@MainActor` production types pinning 15 test cases.**
  Verified at `AppPackage/Sources/ReadingFeature/Support/GestureHandler.swift:6` and
  `PageHandler.swift:6`. Both are pure coordinate/page arithmetic with no UI in their test path;
  the isolation **looks inherited rather than required**. Removing it would free 15 more cases, but
  it is a production change. *(11-22, 11-22.1)*

- **There is no network seam.** Verified: **50** occurrences of `urlSession: URLSession = .shared`
  as an init default across `AppPackage/Sources/NetworkingFeature`, and reducers never pass one — so
  a `TestStore` cannot stub a fetch. This limited coverage in 11-07 (five pushed screens asserted
  against populated state rather than end-to-end), 11-08 (three sheet seams untested), 11-09
  (Previews and Downloads presentation sends) and 11-10 (the EhSetting store-level push test had to
  be replaced by a mapping assertion, because a real push would issue a **live network request from
  the test suite**). Root-fixing means threading an injectable session through every request type.
  *(11-07, 11-08, 11-09, 11-10, 11-15)*

---

## 7. Must-haves that were not achieved as written

Recorded plainly. Each of these is a place where the phase's stated intent and its delivered result
diverge, and none of them is a reason to hold the phase — but a future reader must be able to tell
them apart from the parts that landed.

### 7.1 11-02's headline must-have is inert

The plan's must-have reads: *"An unparseable gallery-list page throws instead of rendering as an
empty list."* **It cannot hold, and the conversion changed nothing observable.**

11-01's `Parser.degrading` helper (D-04 Group A) makes every row-level failure **non-throwing** — a
bad row logs and is skipped. So after 11-01, none of the five `parse*ModeGalleries` functions can
throw, and 11-02's `(try? f()) ?? []` → `try f()` conversion converts a call that cannot fail. The
only reachable throw from `parseGalleries` is the pre-existing error-banner path, which already
existed.

The executor made the conversion anyway (it is the lint objective, and it future-proofs the
propagation channel) and **correctly declined to invent an "empty means malformed" heuristic** —
that would throw on legitimately-empty search results, which the plan's own acceptance criterion
forbids. 11-02 added two tests that pin the *real* contract: throw when a banner names a cause, `[]`
when the page is validly empty.

**This is a direct consequence of D-04 Group A's design and needs an owner decision.**
Distinguishing a validly-empty page from a bannerless malformed one (e.g. detecting a "No hits
found" marker) is a genuine behaviour change that was never planned and is not in scope.

### 7.2 D-13's yield is 17 cases and no measurable wall-clock change

**157 of 186 test cases (84%) remain main-actor-isolated**, and that is a **floor set by TCA's
`TestStore`**, not by annotation hygiene. The sweep is complete and correct across all 50
originally-annotated files; there is nothing left to sweep.

Wall clock: 55.3 s baseline vs 54.9 s after the sweep at identical scope — noise. The full-suite
gate runs 565 tests in ~55 s, which is 42 more tests than the pre-repair 523 in the same time, but
that is a coverage gain, not a speed gain.

If the phase wanted wall-clock from test parallelism, the lever is TCA's testing API, or splitting
reducer tests from IO tests so the latter are not queued behind them. **Not further `@MainActor`
hygiene.** Reported as measured; not presented as a win.

### 7.3 D-09 is half-done

11-12 shipped `PreviewSupport` — 1,000 frozen UUID literals behind a precondition-checked static
subscript — and pointed five gallery-cell preview fixtures at it by index.

**But `AppModels`' shared gallery fixtures still mint random `UUID()`.** Verified at HEAD:
`AppPackage/Sources/AppModels/Gallery/Gallery.swift` lines **15** (`mockGalleries`), **34**
(`preview`) and **57** (`previews(count:)`). **Four of the five files 11-12 fixed render
`Gallery.preview` in their first preview**, so those previews remain non-deterministic across
builds.

If D-09's intent is "no preview fixture has a random identity", this is the remaining half of the
job. It was deliberately not taken: `Gallery` is production model code outside 11-12's file list,
and giving `AppModels` a `PreviewSupport` dependency (or moving the fixtures out of the model
module) is **an architectural call for the owner**, not an auto-fix.

Related: `mockGalleries`' comment is subtly wrong — it says `.preview` "can't stand in because its
`gid` is a fixed constant", but `.preview` is a `static let` holding a *random* UUID, constant
within one process and different every launch. The reasoning it gives for needing distinct ids is
still valid; the stated reason is not.

### 7.4 There is no network seam

See §6.8. Four separate plans flagged it and none took it on. It is the phase's largest standing
coverage limitation, and it is structural rather than an oversight.

---

## 8. Process findings for future phases

### 8.1 An invalid `excluded_match_kinds` value silently discards a whole rule config

**The most dangerous thing this phase found.** SwiftLint responds to an unrecognised entry with:

```
warning: Invalid configuration for '<rule>' rule. Falling back to default.
```

A custom rule has **no default**, so the rule simply vanishes — reporting **zero violations, on any
input, forever**, behind one stderr line that a `--quiet --reporter json` run discards. That is
byte-identical to what a clean codebase produces.

**The spelling is `doccomment`, not `doc_comment`.** Waves 11-15 and 11-16 both independently
recommended `doc_comment`, and 11-17's own brief carried it forward. Had 11-17 shipped it, the flip
commit would have passed every check in its success criteria — zero violations, clean build, clean
`build-for-testing`, green suite — **while enabling nothing at all.** It was caught only because the
first enumeration returned `TOTAL 0` against a tree known to hold ~67 matches.

This is why every flip in this phase carries a negative-control probe, and why §1.2 exists here.
**Recommendation, unchanged from 11-17: make "prove the rule fires" a standing requirement, not a
nicety.** A `Scripts/` probe fixture with known-violating lines and an expected-count assertion, run
alongside `check-cookie-logging.sh`, would make it permanent. Not built here — it is infrastructure,
not this plan's mandate.

The same failure shape applies to a misspelled entry in `opt_in_rules`: not a config error, one
stderr line, nothing enabled.

### 8.2 A custom rule's `excluded:` is a file-path regex

`"\\[validatedIndex\\]"` was source-shaped and could never match a path — dead configuration
masquerading as an escape hatch. **Three plans (11-13, 11-14, 11-15) were written around it** before
11-12 caught it. Deleted in 11-17, not replaced: 240 matches across five waves resolved with exactly
two exception sites, neither of which wanted a token-level escape.

The sibling entry `".*/[^/]*Tests\.swift$"` **is** correct and was verified rather than assumed —
two byte-identical probe files, `FooTests.swift` and `FooHelper.swift`, and only the latter was
flagged. It survives in the config today.

### 8.3 Plan counts drifted in nearly every wave — the binary is the enumerator

| Wave | Plan said | Tree held |
|---|---|---|
| 11-01 | 23 A + 13 B + 6 C | 21 A + 12 B + **9** C |
| 11-03 | "~half of 36" | **21** |
| 11-04 | "~20" | **15** |
| 11-08 | 14 | **10** |
| 11-09 | 8 | **6** |
| 11-13 / 11-14 / 11-15 / 11-16 | 61 / 43 / 29+12 / 27 | **exact** |
| 11-18 | ~35 | **64** (regex mis-tuned in *both* directions) |
| 11-21 | 37 suites | **38** |
| 11-22.1 | 18 files / 5 targets | **23 / 6** |
| 11-24 | 316 sites / 4 files | **11 / 3** |
| 11-25 | 870 / 319 | **893 / 325** |
| 11-26 | ~149 | **145** |
| 11-27 | ~74 | **70** (exact vs 11-26's projection) |
| 11-28 | ~85 | 84 raw / **43 unique** |

Drift went both directions. Every wave reported rather than adjusted, and **the condition actually
verified was always the binary's zero.** That is the right discipline: treat a plan's count as a
hypothesis and the tool as the enumerator.

### 8.4 The recurring high-value refactor: positional array → named struct

The single most valuable pattern the phase found, applied four times:

| Wave | Shape | Matches erased | Defect class removed |
|---|---|---:|---|
| 11-14 | `parseInfoPanel`'s 8-slot `[String]` | 20 | wrong-slot write/read silently mis-maps favourited count onto page count |
| 11-16 | `ImageColors`' 4-element `[Double]` | 22 | wrong-slot write yields a plausible-looking colour nothing catches |
| 11-17 | `RunLogFile`'s positional split | 8 | — |
| 11-18 | `(String, TagTranslation?)` → `TagTranslationLookup` | 13 declarations | `.0`/`.1` positional reads |

**~40 matches erased in two changes** (11-14 + 11-16), each replacing a bug class rather than
annotating it. Where a lint rule points at N sites on one variable, look for the modeling defect
before writing N annotations.

### 8.5 `FeatureTests.xctestplan` was missing 3 of 18 targets until wave 22.1

`CookieClientTests`, `ImageClientTests` and `ReadingFeatureTests` were never added to the test plan
when they were created. Consequences:

- `xcodebuild test -scheme EhPanda` ran **523 tests, not 565**.
- **`build-for-testing -scheme EhPanda` — the phase's standing `Tests/` lint gate — was not
  compiling or linting those three targets.** Any lint conclusion drawn about `Tests/` before wave
  22.1, including 11-19's and 11-20's, was drawn from an incomplete gate. Nothing is currently
  violating; the exposure is retrospective only.
- Two of the three hold this phase's own isolation work (11-20 de-serialized `ImageClientTests` and
  fixed the `DidLoginKey` race in `CookieClientTests`).

Repaired in `320d942d`. **Nothing re-audits it** — §1.6 checked it by hand here and it is clean, but
the same silent drift can recur the next time a target is added. A one-line check comparing
`AppPackage/Tests/*/` against the plan would close it permanently.

### 8.6 Adding labels to a positional return creates a constraint the unlabeled version absorbed

An **unlabeled** tuple converts implicitly to any labeled tuple type; two **differently-labeled**
tuples do not. Labeling `parseMPVKeys`'s return forced it to agree with a `key:` label chosen years
earlier in `ReadingReducer.Action` and `DownloadClient.PageSource.mpv`. The compiler reported
`failed to produce diagnostic for expression` on a 300-line `Reduce { }` body rather than naming the
mismatch.

That silent absorption is exactly what lets a `(A, B)` and a `(B, A)` line up by accident — the
argument *for* the rule — but it means future edits to these signatures are less free than they were.

### 8.7 "UIKit implies main actor" is disproven, twice

11-22 expected a `@MainActor` restore for `UIGraphicsImageRenderer` in `DownloadProcessCacheTests`
and did not get one; 11-22.1 expected the same for `makePNGData` in `ImageClientTests` and did not
get one either. `UIGraphicsImageRendererFormat`, `UIGraphicsImageRenderer` and `UIImage.pngData()`
are all callable from a nonisolated context. **Two independent expectations, both wrong, in the same
direction.** Treat it as a disproven prior rather than re-testing it a third time.

### 8.8 A directive cannot precede its rule — flips must be atomic

`// swiftlint:disable:next <rule>` for a rule SwiftLint does not know trips
`superfluous_disable_command`. So a flip commit must carry the config change, the last fixes **and**
every directive together; splitting it fails lint in either order. Discovered in 11-09, acted on in
11-11, and re-confirmed in 11-12 and 11-17.

### 8.9 Enumerate with a scratch config, never by editing the tracked one

Several plans directed the executor to temporarily uncomment a rule in `.swiftlint.yml`, lint, then
`git checkout --` it. That leaves a window in which the repository holds an error-level rule against
hundreds of live violations — an interrupted or mis-ordered run commits a broken build. 11-26
switched to a scratch config passed via `--config` with `only_rules: [custom_rules]`, which yields
the same work list with the tracked file never written. Adopted by 11-27 and 11-28.

### 8.10 The rules are now permanent, and one message under-hints its best fix

Any future `.onAppear`, `Binding(get:set:)`, `foo[index]`, `-> (A, B)`, `try?`, single-line trailing
closure, unsorted import block or two-calls-on-a-line chain **fails the build**, in Sources and in
test targets.

`unchecked_subscript_index_access`'s message reads *"Subscript index access should be guarded by an
index check"* — but five waves found that the right answer is usually a **rename** (`index` → `page`
/ `catIndex` / `favoritesIndex`, for Dictionary subscripts that cannot trap) or a **structural fix**,
not a guard. That has been an improvement every time, but the next contributor pays the discovery
cost without the context. Worth a message rewrite.

### 8.11 One summary artifact is corrupted

`11-27-SUMMARY.md` ends with stray `</content></invoke>` tool-call markup instead of clean Markdown —
a write-truncation artifact. The content above it is complete and intact. Cosmetic, but recorded so
it is not mistaken for a content gap.

---

## 9. Claims in prior summaries that the tree does not support

Checked rather than carried forward.

### 9.1 There are no `withKnownIssue` markers, and there never were

Eight summaries (11-11, 11-13 through 11-21, 11-25 through 11-28) refer to "2 pre-existing
`withKnownIssue` markers", or "3", or "1" — the count itself drifts between waves.

**`grep -rn "withKnownIssue"` over `AppPackage/`, `App/` and `ShareExtension/` returns nothing.**
`git log -S"withKnownIssue" --all` returns **no commit** — the token has never existed in this
repository's history. There are also zero `.disabled` traits and zero `XCTSkip` calls.

The phrase was imprecise reporting, repeated by inheritance. 11-22.1 is the one summary that got it
right and pinned it down.

### 9.2 What the "known issues" actually are — three of them, concretely

From this plan's own full-suite run:

| # | Test | Recorded at | Cause |
|---|---|---|---|
| 1 | `SettingReducerTests.defaultProfileCreationUsesOriginatingHostAfterSharedHostChanges()` | `SettingReducerTests.swift:38:40` | TCA's `store.skipInFlightEffects()` — the API records an `Issue` when it discards in-flight effects |
| 2 | `SettingPresentationTests.pushingAccountLoadsCookies()` | `SettingPresentationTests.swift:71:40` | same — the long-living jar subscription is deliberately skipped, and the file says so in a comment |
| 3 | `AppModelsTests.privateFilterValueReportsIssueAndReturnsZero()` | `Category.swift:45:24` | a **production** `reportIssue(…)` in `Category.filterValue` for the display-only `.private` case — which is precisely what the test's name asserts |

All three are by design. Two come from a TCA testing API, one from production code the test exists
to exercise. **None is a suppressed failure, and none uses `withKnownIssue`.** The count is **3**,
not 2.

Swift Testing surfaces these as "known issues" because `Issue.record` was called and the run still
passed — a different mechanism from `withKnownIssue`, and the source of the confusion.

---

## 10. Summary for the review

| Item | Count | Needs your decision |
|---|---:|---|
| `lifecycle_modifiers` exceptions | 6 | **Yes** — 3 of them collapse if you narrow the rule (§6.1) |
| `unchecked_subscript_index_access` exceptions | 2 | **Yes, if** you want the exception form to mean "a check that can fail" (§2.2) |
| Exceptions for the other six rules | **0** | No |
| Retained `.serialized` traits | **0** | No |
| Retained `@MainActor` annotations | 185 (45 files) | No — all compiler-required; 15 would free if two production types shed `@MainActor` (§6.8) |
| Pre-existing disables (not phase artifacts) | 20 | No |
| Production concerns surfaced | 8 | §6 — none blocking, several worth scheduling |
| Must-haves not achieved as written | 4 | §7 — 11-02's, D-09's second half, D-13's yield, the network seam |

**The battery is fully green: 0 violations across 452 files with all eight rules live and
negative-control-proven, both builds clean, 565 tests passing in parallel across 18 targets, cookie
scan clean, and the test plan covering every target.**
