---
phase: 15-continued-background-downloads
plan: 52
subsystem: downloads
tags: [background-processing, continued-session, test-double-fidelity, source-census, gap-closure, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-50's re-derived run-proof census in DownloadSourceInventoryTests, the table this plan's addition had to leave unmoved — the census-rebasing hazard the plan's depends_on named"
  - phase: 15-continued-background-downloads
    provides: "15-51's head 09f6b8f3 and its 884/0 full-suite total, the baseline this plan's 886 is accounted against"
  - phase: 15-continued-background-downloads
    provides: "BackgroundProcessingClientSpy's timing paragraph, which stated the rule this plan turned into a build"
provides:
  - "A BackgroundProcessingClient.unavailable double that suspends at all three endpoints, mirroring the spy, with its reason stated in its own doc"
  - "testClientDoubleSuspensionSitesMatchTheRecordedCensus — the property half, counting the yields of every hand-built double at this seam, observed RED against the real atomic double before the correction"
  - "testClientDoubleConstructionSitesMatchTheRecordedCensus — the population half, counting the doubles themselves through the seam's endpoint label, observed RED against a planted construction in a file no table had heard of"
  - "downloadsTestFiles(in:) / clientDoubleFiles(in:) — the test-target scoping seam, the mirror of clientModuleFiles(in:), so no census in the suite is scoped by accident"
  - "A pointer from the spy's header to the census that enforces its rule"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A census whose population is DERIVED from a token rather than listed, so a new subject's file joins by existing rather than by being remembered"
    - "Two census halves that fail on different events — a property half and a population half — because neither subsumes the other"
    - "Falsifying a population half by planting a temporary subject, since it is green from the moment it is written"
    - "A census token chosen as the seam's endpoint LABEL rather than its type name, because the type name misses the `Self(` spelling the real violation used"
    - "Keeping zero counts in a per-file table where a zero IS the failure, instead of dropping the key as every sibling census does"

key-files:
  created: []
  modified:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift

# Decisions
decisions:
  - "The construction token is the seam's endpoint label rather than its type name: a type-name token matches `BackgroundProcessingClient(` and misses `Self(` inside an extension — which is exactly how the offending double is spelled, so a type-name census would have carried its blind spot precisely where the violation lived."
  - "The property half keeps zero counts rather than dropping them, unlike all five sibling censuses, because a double that stops suspending entirely is the failure it exists to name and a dropped key would hide it."
  - "The property half's file population is derived through the construction token rather than listed, so a new double's file enters it automatically; the population half is what makes that new file's arrival fail a build."
  - "The macro-synthesized unimplemented value and the module's `live` and `noop` values are classified OUT with reasons — a timing census must not demand yields from generated or production code."
  - "Both new censuses are scoped to the test target through a new `downloadsTestFiles(in:)` seam, the mirror of `clientModuleFiles(in:)`, so the five pre-existing tables cannot re-base."

# Metrics
duration: 38min
completed: 2026-08-07
tasks_completed: 2
files_changed: 3
status: complete
---

# Phase 15 Plan 52: Client Double Timing Fidelity Summary

The `.unavailable` client double now suspends at all three endpoints where the main-actor-confined
live seam suspends, and the timing rule that had lived as prose in one file's header is owned by a
two-part build-time census whose halves were each observed failing before either was trusted.

## Task 1 — the classification, the two-part census, and its two separate falsifications

### Step 1: the population, enumerated and classified

The enumeration grep, run at head `09f6b8f3`:

```
grep -rn "BackgroundProcessingClient(" AppPackage/Tests/ AppPackage/Sources/
grep -rn "static let\|static var" AppPackage/Sources/BackgroundProcessingClient/
```

Every `BackgroundProcessingClient` value the downloads test target can reach, and its class:

| Value | Where | Class | Why it is in that class |
|---|---|---|---|
| `BackgroundProcessingClientSpy.client` | `DownloadFeatureTestSupportTypes.swift:292` | **(a) HAND-BUILT DOUBLE — IN** | Written closure by closure to stand in for a main-actor-confined seam; its own header states the timing obligation |
| `BackgroundProcessingClient.unavailable` | `DownloadContinuedSessionExpirationTests.swift:428` | **(a) HAND-BUILT DOUBLE — IN** | Same: a hand-written stand-in for the same seam, differing only in what it answers |
| `BackgroundProcessingClient()` | `DownloadContinuedSessionTests.swift:14` | **(b) GENERATED — OUT** | Macro-synthesized by `@DependencyClient`; nobody writes its endpoints and its whole purpose is to report an issue when called. Demanding a yield from it would be demanding one from generated code |
| `BackgroundProcessingClient.live` | `BackgroundProcessingClient.swift:68` | **(c) PRODUCTION — OUT** | Not a double at all: the forwarder onto `ContinuedProcessingSession` that every double stands in for. It is the thing whose timing the census measures others against |
| `BackgroundProcessingClient.noop` | `BackgroundProcessingClient.swift:93` | **(c) PRODUCTION — OUT** | The module's public inert value, shipped in `Sources` and used as a baseline by cases comparing against "no session at all". A test census must not demand yields from a production surface |

The pre-derived expectation of exactly two members in class (a) was re-derived at this head and holds.

### Step 2: both halves' numbers, derived from source

**Property half — suspension points.** The spy's three closures each open with a yield, verified in
source at `DownloadFeatureTestSupportTypes.swift:294` (`start`), `:336` (`updateProgress`) and
`:365` (`finish`) — three, counted rather than assumed. Grep and result at Task 1's head:

```
$ for f in AppPackage/Tests/DownloadsFeatureTests/*.swift; do
    n=$(grep -v '^\s*//' "$f" | grep -o -F "Task.yield()" | wc -l); ...
  done
  DownloadFeatureTestSupportTypes.swift: 3
  joined: 3
```

`DownloadContinuedSessionRunProofTests.swift:64` also names the token, in a doc comment, and is
excluded by the suite's existing executable-line filter — which is why the census counts through
`callSiteCount` rather than a raw grep.

Expected table, three closures apiece across the two class-(a) doubles:

```swift
private static let expectedClientDoubleSuspensionSites = [
    "DownloadContinuedSessionExpirationTests.swift": 3,
    "DownloadFeatureTestSupportTypes.swift": 3
]
private static let expectedClientDoubleSuspensionTotal = 6
```

**Population half — construction sites.** Grep and result:

```
$ grep -rn "updateProgress:" AppPackage/Tests/DownloadsFeatureTests/
  DownloadFeatureTestSupportTypes.swift:335:            updateProgress: { sessionID, ... in
  DownloadContinuedSessionExpirationTests.swift:436:        updateProgress: { _, _, _, _ in
```

```swift
private static let expectedClientDoubleConstructionSites = [
    "DownloadContinuedSessionExpirationTests.swift": 1,
    "DownloadFeatureTestSupportTypes.swift": 1
]
private static let expectedClientDoubleConstructionTotal = 2
```

**Why the token is the endpoint label, not the type name.** A type-name token matches
`BackgroundProcessingClient(` and misses `Self(` written inside an extension of the type — which is
exactly how the `.unavailable` double is spelled. A type-name census would therefore have had its
blind spot precisely where the real violation lived. Every hand-built value must supply all three
endpoints, so the label reaches both spellings, while the macro-synthesized no-argument value
supplies none and falls out by construction rather than by an exclusion someone must remember.

**Both halves exclude comment lines** through the suite's existing `callSiteCount` →
`executableLines` filter, which drops every line whose trimmed prefix is `//`.

**Both tokens are fragment-assembled**, quoted verbatim:

```swift
private static var clientDoubleEndpointToken: String { "updateProgress" + ":" }
private static var clientDoubleSuspensionToken: String { "Task" + ".yield()" }
```

This is not decorative here: `DownloadSourceInventoryTests.swift` lives *inside* the tree these two
censuses count over, so a token written whole would count itself. Verified after the edit — a grep
for either token over the census file's executable lines returns nothing.

### Step 3: every pre-existing census re-derived under the new scoping, and unmoved

Re-derived by grep at head `09f6b8f3` (before) and re-run in the suite after the addition (after).
Every value is equal on both sides.

| Census | Table before | Table after | Total before | Total after |
|---|---|---|---|---|
| Scheduling-block call sites | `Folders 2, PublicAPI 1, Scheduling 1, Testing 1` | identical | 5 | 5 |
| Monotonic-floor writers | `ContinuedSession 4, ExecutionSupport 1` | identical | 5 | 5 |
| Schedulable-read call sites | `ContinuedSession 2, PendingWork 1` | identical | 3 | 3 |
| Pending-page-list evaluations | `ExecutionSupport 1` | identical | 1 | 1 |
| Run-proof sites (15-50's six) | `ContinuedSession 2, Execution 1, ExecutionSupport 1, Manager 1, Persistence 1` | identical | 6 | 6 |

Nothing moved because nothing *could*: the addition changes neither `scannedDirectories` nor
`clientModuleFiles(in:)`, and the two new censuses re-scope through a new `downloadsTestFiles(in:)`
seam instead. Both scoping docs were corrected in the same commit — the suite header and the
`scannedDirectories` doc both said "every census keeps counting the client module alone", which the
addition would have turned into exactly the kind of false premise this suite exists to police.

### Step 4: the property half's falsification, with the double still atomic

Order stated plainly: this reading was taken at commit `45c2ac14`, **before** any line of the double
changed. Verbatim from the run:

```
✘ Test testClientDoubleSuspensionSitesMatchTheRecordedCensus() recorded an issue at
  DownloadSourceInventoryTests.swift:466:9: Expectation failed:
  (suspensionSites → ["DownloadFeatureTestSupportTypes.swift": 3,
                      "DownloadContinuedSessionExpirationTests.swift": 0])
  == (Self.expectedClientDoubleSuspensionSites → ["DownloadFeatureTestSupportTypes.swift": 3,
                                                  "DownloadContinuedSessionExpirationTests.swift": 3])
✘ ... at DownloadSourceInventoryTests.swift:480:9: Expectation failed:
  (Self.callSiteCount(of: Self.clientDoubleSuspensionToken, in: joined) → 3)
  == (Self.expectedClientDoubleSuspensionTotal → 6)
✘ Test run with 8 tests in 1 suite failed after 0.172 seconds with 2 issues.
** TEST FAILED **
EXIT=65
```

The failure names `DownloadContinuedSessionExpirationTests.swift` with observed `0` beside expected
`3`, which is the whole point of the reading: it proves the token assembles to something really
present, that the walk reaches the file the atomic double lives in, and that the expected number was
not fitted to the tree. The non-zero exit is the evidence. In the same run the population half and
all five pre-existing censuses and the prose assertion passed — one reading, one red, seven green.

### Step 5: the population half's falsification, which had to be planted

That half was green from the moment it was written, so it was falsified deliberately: a throwaway
`BackgroundProcessingClient(start:updateProgress:finish:)` was added to
`DownloadContinuedSessionTests.swift` — a file **neither** table had ever heard of, which is the
case the property half structurally cannot catch. Verbatim:

```
✘ Test testClientDoubleConstructionSitesMatchTheRecordedCensus() recorded an issue at
  DownloadSourceInventoryTests.swift:500:9: Expectation failed:
  (constructionSites → ["DownloadFeatureTestSupportTypes.swift": 1,
                        "DownloadContinuedSessionTests.swift": 1,
                        "DownloadContinuedSessionExpirationTests.swift": 1])
  == (Self.expectedClientDoubleConstructionSites → ["DownloadContinuedSessionExpirationTests.swift": 1,
                                                    "DownloadFeatureTestSupportTypes.swift": 1])
✘ ... at DownloadSourceInventoryTests.swift:512:9: Expectation failed:
  (Self.callSiteCount(of: Self.clientDoubleEndpointToken, in: joined) → 3)
  == (Self.expectedClientDoubleConstructionTotal → 2)
```

A bonus observation worth recording: in the same run the property half's *derived* population picked
the planted file up too — `["...SupportTypes.swift": 3, "...ExpirationTests.swift": 0,
"...ContinuedSessionTests.swift": 0]` — which demonstrates the derivation is live rather than a
second hand-maintained list.

**The plant was removed.** Confirmed by grep after removal, back at the recorded values:

```
DownloadContinuedSessionExpirationTests.swift: 1
DownloadFeatureTestSupportTypes.swift: 1
joined total: 2
```

and by `git status`, which showed `DownloadContinuedSessionTests.swift` unmodified. The
post-removal **green** reading is the full run below, where both halves pass.

### Step 6: both censuses' docs

Property half, quoted:

```
/// Every suspension point inside the target's hand-built client doubles, named per file.
///
/// **What this number means.** `BackgroundProcessingClient.live` forwards onto a `@MainActor`
/// store, so each of its three endpoints hops off the calling actor. A double that answers
/// synchronously is therefore not a faster stand-in but a DIFFERENT seam: it certifies as
/// impossible every reentrancy the live one admits, and a suite green against it is green about
/// a world that does not exist. Three closures apiece across two doubles is the six below.
///
/// The full argument for the rule lives on `BackgroundProcessingClientSpy`'s header, where it
/// was written and — until this census — honoured alone; a reader who wants the reasoning
/// rather than the count should start there.
///
/// **What would move it.** A closure that stops yielding, an endpoint added to the seam, or a
/// new hand-built double in a file this table has never heard of. The last of those is
/// invisible here, which is the entire reason `expectedClientDoubleConstructionSites` sits
/// beside it rather than folded into it.
///
/// **What a failure obliges.** Re-derive the rule from the live value's isolation and re-read
/// the named double's closures against the spy's three; the table is rewritten from that
/// derivation and never adjusted to whatever the tree currently holds.
///
/// The population is DERIVED rather than listed — the files below are whichever scanned test
/// files build a value of the type. Zero counts are kept rather than dropped, unlike every
/// census above, because a double that stops suspending ENTIRELY is the exact failure this half
/// exists to name and a dropped key would let it vanish from the observed table instead.
```

Population half, quoted:

```
/// Every hand-built client double in the downloads test target, named per file.
///
/// **What this number means.** A POPULATION rather than a property. Two hand-built doubles
/// exist — the recording spy and the `.unavailable` refusal value — and the timing obligation
/// above covers exactly those two. Three further values of the type are reachable from this
/// target and none is counted, because none is a hand-built double: the macro-synthesized
/// no-argument value, whose endpoints nobody writes and whose whole purpose is to report an
/// issue when called, and the module's public `live` and `noop` values, which are production
/// surfaces a test census must not demand yields from.
///
/// **What would move it.** A new hand-built double anywhere under the test target, including in
/// a file the suspension table has never heard of — the case that table structurally cannot
/// catch.
///
/// **What a failure obliges.** Re-derive the population FIRST: classify the new value as
/// hand-built, generated or production, and only if it is hand-built add it here AND to the
/// suspension table with a yield opening each of its closures. Neither number is adjusted until
/// the double itself passes.
```

Each states what its number means, what would move it, and that a failure obliges a re-derivation
before the table is touched. The property half additionally states the timing rule in its own words
and names the spy's header as where the rule's full argument lives.

## Task 2 — the correction, its doc, the per-case re-read, and full green

### Step 1: the corrected double, beside the spy it mirrors

The spy's three closures (`DownloadFeatureTestSupportTypes.swift:293`, `:335`, `:364`):

```swift
start: { title, subtitle, completedUnitCount, totalUnitCount in
    await Task.yield()
    let shouldRefuse = self.state.withLock { ... }
```
```swift
updateProgress: { sessionID, completedUnitCount, totalUnitCount, subtitle in
    await Task.yield()
    // The live store accepts progress only for the identity it still owns.
```
```swift
finish: { sessionID, success in
    await Task.yield()
    // The live store records the request at this seam but releases only a matching ID.
```

The corrected double, same suspension in the same position — before anything is built, recorded or
returned — and otherwise untouched:

```swift
    static let unavailable = Self(
        start: { _, _, _, _ in
            await Task.yield()
            let events = AsyncStream<BackgroundProcessingEvent> { continuation in
                continuation.yield(.unavailable)
                continuation.finish()
            }
            return BackgroundProcessingSession(id: UUID(), events: events)
        },
        updateProgress: { _, _, _, _ in
            await Task.yield()
        },
        finish: { _, _ in
            await Task.yield()
        }
    )
```

The stream it builds, the event it yields and the finish it performs are its subject and are
unchanged. The resulting per-file count is **3**, and it became 3 by the correction — the expected
number was recorded at `45c2ac14` against an observed 0, so it cannot have been fitted to this.

### Step 2: the double's own doc, and the spy header's pointer

The double's doc, quoted in full:

```
/// Answers every start with an identified session that immediately reports unavailable —
/// what the Simulator reports, and what the system reports when it will not grant a task.
///
/// **Why all three closures suspend before they do anything.** The live value forwards onto
/// `ContinuedProcessingSession`, a `@MainActor` type, so every endpoint hops off the calling
/// actor — and while a call is over there the coordinator's actor is reentrant. A double that
/// answers synchronously does not merely run faster; it certifies that window as impossible.
/// Three lines of `ensureContinuedSession` exist for nothing but surviving it: the ownership
/// re-check behind the start (`DownloadClient+ContinuedSession.swift:358`), the additive floor
/// seed that folds in a withdrawal landing inside the hop (`:373`), and the merged trust seed
/// that folds in a push landing there (`:403-407`). Every case below runs this double through
/// exactly that stretch, so with the hop removed their coverage of those three was nominal.
///
/// The family makes it the one least able to afford an atomic double, per
/// `DownloadContinuedSessionRunProofTests`' suite doc: `.unavailable` is the ORDINARY outcome
/// rather than an exotic one, and three of the four arms that yield it fire inside the store's
/// own start.
///
/// The suspensions mirror `BackgroundProcessingClientSpy`'s three rather than inventing a
/// second convention, and the rule is no longer honoured by convention alone:
/// `DownloadSourceInventoryTests.testClientDoubleSuspensionSitesMatchTheRecordedCensus` counts
/// them, so a closure that stops yielding fails a build.
```

The three coordinator line anchors were **re-derived at this head** rather than copied from the
plan, which cited `:268`, `:283` and `:313` — 15-50's edits shifted them to `:358`, `:373` and
`:403-407`. The plan's anchors would have been a false premise the day they were written.

The sentence added to the spy's header, quoted:

```
/// That timing rule is no longer stated here and honoured only here, which is how the sibling
/// `.unavailable` double came to ship atomic one file over (G-15-32).
/// `DownloadSourceInventoryTests` now owns it in two halves: one counts the suspension points of
/// every hand-built double at this seam, so a closure that stops yielding fails a build, and one
/// counts the doubles themselves, so a NEW hand-built double cannot appear atomic in a file no
/// table has heard of. The reasoning stays here; the enforcement is there.
```

### Step 3: the per-case re-read, one case at a time

Both cases running the double, re-read end to end rather than judged from the double's site.

**`testUnavailableSessionLeavesQueueStateEqualToTheInertClient`** (`:174`), reached through
`runPageFlushScenario(client:gid:)`.
- *What it asserts:* the queue-state snapshot after twelve page flushes plus a forced final flush is
  equal running against `.unavailable` and against `.noop`; the snapshot holds one gallery; no
  gallery carries a `lastError`; every gallery's `completedPageCount` equals its `pageCount`.
- *Ordering-dependent assertions:* none. `testingEnsureContinuedSession()` is awaited to completion
  before the flush loop begins, so the added hop opens and closes before the first flush is issued,
  and nothing else drives the coordinator concurrently. The comparison is a terminal read.
- *Held only because the double was atomic?* No. The claim is about page bookkeeping across a
  no-session path, and its baseline is `.noop`, whose `start` returns nil — a different shape from
  the atomic answer in the first place. **Verdict: unaffected.** Passed after the correction.

**`testUnavailableSessionSurfacesNothingAndLeavesNoLiveSession`** (`:189`), reached through
`makeInactiveCoordinator(gid:client:)`.
- *What it asserts:* `togglePause(gid:).get()` reports success even though the session it asked for
  was refused outright; after settling, the download carries no `lastError` and no session is left
  believing it is live.
- *Ordering-dependent assertions:* yes, and the case already knew it — the liveness read is behind
  `waitUntil { await !context.manager.testingHasContinuedSession() }` rather than taken directly,
  because the teardown lands on the consuming task rather than on the tap. That is precisely the
  assertion the added window could have broken had it been a direct read; it is not, so the wider
  window is absorbed by the existing settle point rather than by luck.
- *Held only because the double was atomic?* The `.get()` is the one worth checking. With the
  suspension added, this double's `start` still returns a non-nil session, so the path taken is the
  post-start stretch — the ownership re-check at `:358`, the additive floor seed at `:373`, the
  merged trust seed at `:403-407` — now genuinely crossed over a suspension instead of a straight
  line. Nothing else mutates the coordinator during that window in this case, so the re-check
  passes and the tap still reports success. **Verdict: unaffected, but for the first time the three
  lines it drives are exercised across a real hop.** Passed after the correction.

No case changed behaviour, so no verdict about production was reached and **nothing was raised as a
production finding**. No production line was changed, by construction.

### Step 4: the residue sweep

| Check | Result |
|---|---|
| (a) Property half passes and its per-file numbers match Task 1's derivation | PASS — derived `3 + 3`, joined `6`, exactly the recorded expectations |
| (b) Population half passes and its count is back at the recorded value after the plant's removal | PASS — `1 + 1`, joined `2` |
| (c) No doc in the downloads test target still describes the timing rule as spy-header-only, or the double as synchronous/atomic | PASS — the spy header now names the census; a target-wide grep for `atomic`/`synchronous` leaves only (i) statements of what an atomic double *costs*, in the rule and in the two census docs, and (ii) unrelated subjects: a runner's synchronous recording, `ensureContinuedSession`'s synchronous reset block, the retirement inside `processDownload`'s `defer`, a reader-flush guard, a refused store start, and a release token |
| (d) Every pre-existing census still matches its Task 1 re-derived value | PASS — all five green in the full run, tables unchanged |

### Step 5: full green, with the movement accounted for

One unfiltered invocation, `** TEST SUCCEEDED ** [98.036 sec]`, exit `0`.

- **886 tests, 0 failures.** Against `09f6b8f3`'s **884**, the movement is `+2`, accounted for case by
  case: `testClientDoubleSuspensionSitesMatchTheRecordedCensus` and
  `testClientDoubleConstructionSitesMatchTheRecordedCensus`, both from Task 1. Task 2 added no cases.
- All eight cases of `DownloadSourceInventoryTests` pass, including the five pre-existing censuses
  and the prose assertion.
- Both cases running the corrected double pass.

**Did the correction visibly change any pre-existing case's behaviour?** Stated plainly: **no.**
Every case that was green before the suspension was added is green after it, and none changed its
observable outcome. That is the weaker of the two possible results and it is worth naming as such —
the correction did not *catch* anything, it removed a certification. What it bought is that the
three coordinator lines defending the client start's main-actor hop are now exercised in a world
where their window can actually open, so a future defect in them is expressible in this suite
instead of being ruled out by the double.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 — missing critical correctness] Corrected two scoping docs the addition would have falsified**
- **Found during:** Task 1, Step 3.
- **Issue:** the suite header and the `scannedDirectories` doc both stated that "every census keeps
  counting the client module alone, through `clientModuleFiles(in:)`". Adding two test-target-scoped
  censuses makes that false — the exact doc-versus-source shape this suite exists to police, written
  by the round adding the police.
- **Fix:** both now say that every census names its tree explicitly, through `clientModuleFiles(in:)`
  or `downloadsTestFiles(in:)`, and that five count the client module while two count the test target.
- **Files modified:** `DownloadSourceInventoryTests.swift`.
- **Commit:** `45c2ac14`.

**2. [Rule 1 — false premise in a source anchor] Re-derived the three coordinator line anchors**
- **Found during:** Task 2, Step 2.
- **Issue:** the plan cited `+ContinuedSession.swift:268`, `:283` and `:313` for the ownership
  re-check, additive floor seed and merged trust seed. 15-50's edits moved them.
- **Fix:** re-derived by grep at this head — `:358`, `:373`, `:403-407` — and the double's doc cites
  those. Copying the plan's numbers would have shipped a false anchor on day one.
- **Files modified:** `DownloadContinuedSessionExpirationTests.swift`.
- **Commit:** `99e8ea74`.

No other deviations; no architectural decision was needed and no checkpoint was reached.

## Prohibitions — status

| Prohibition | Status |
|---|---|
| Must not correct the double before the suspension half is landed and observed FAILING | HONOURED — RED taken at `45c2ac14`, correction landed at `99e8ea74` |
| Must not re-baseline any pre-existing census | HONOURED — all five re-derived, before and after recorded, every value equal |
| Must not demand a suspension from a value that is not a hand-built double | HONOURED — generated and both production values classified OUT with reasons, and out of the census's *scope* rather than merely excluded from its table |
| Must not declare the correction inert | HONOURED — both cases re-read individually and recorded by name above |
| Must not change any production line | HONOURED — diff confirms three files, all under `AppPackage/Tests/DownloadsFeatureTests` |
| Must not reach for a lint or concurrency escape hatch | HONOURED — SwiftLint `--strict` clean on all changed files; no suppression, no `swiftlint:disable`; `awk 'length($0)>120'` returns nothing; longest changed file is 707 lines against the 1000-line ERROR limit |

## Diff scope

```
$ { git diff --name-only 09f6b8f3 HEAD; } | grep -v "^AppPackage/Tests/DownloadsFeatureTests/"
  (nothing outside — confirmed)
```

Three files, all in the downloads test target:
`DownloadSourceInventoryTests.swift`, `DownloadContinuedSessionExpirationTests.swift`,
`DownloadFeatureTestSupportTypes.swift`. `DownloadContinuedSessionTests.swift` was touched only by
the temporary plant and restored to its committed state before either commit.

## Commits

| Commit | Type | What |
|---|---|---|
| `45c2ac14` | test | The two-part census, landed RED against the still-atomic double |
| `99e8ea74` | fix | The corrected double, its doc, and the spy header's pointer to the census |

## What this plan does NOT claim

- No criterion's verdict moves. This is a test double's fidelity; SC3 and SC4 name the surfaces the
  double stands in front of, not a verdict this plan repairs.
- No device-observable behaviour changes. `15-UAT.md` test 2 remains an independent open axis that
  nothing here can discharge — this plan reaches no device path, and `.unavailable` is precisely the
  outcome a Simulator produces.
- The correction caught no live defect. See Step 5 above; that is stated rather than dressed up.

## Verification evidence

- Three `xcodebuild` invocations, strictly one at a time, none overlapping another.
  1. Targeted census suite at `45c2ac14`, double still atomic — `** TEST FAILED **`, exit `65`, the
     property half red naming `DownloadContinuedSessionExpirationTests.swift` with `0` vs `3`.
  2. Targeted census suite with the plant — `** TEST FAILED **`, exit `65`, the population half red
     naming `DownloadContinuedSessionTests.swift` and its joined total `3` vs `2`.
  3. Full unfiltered `FeatureTests` after the correction — `** TEST SUCCEEDED **`, exit `0`,
     886 tests, 0 failures.
- SwiftLint (`--strict`, DerivedData artifactbundle binary) clean on every changed file.

## Self-Check: PASSED

- `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift` — FOUND
- Commit `45c2ac14` — FOUND
- Commit `99e8ea74` — FOUND
