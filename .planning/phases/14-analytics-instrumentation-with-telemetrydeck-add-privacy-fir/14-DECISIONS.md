# Phase 14: Analytics Instrumentation (TelemetryDeck) — Owner Decisions D-15 … D-19

**Answered:** 2026-07-24
**Status:** Locked — downstream plans read these as inputs

These are the five questions research deliberately left open because no locked decision
D-01 … D-14 covered them. The owner answered all five on 2026-07-24.

They **extend** the locked spine recorded in `14-CONTEXT.md`. Two of them — **D-16** and
**D-19** — also **amend** a locked decision, and each says so plainly in its own section
rather than presenting itself as a reading or a clarification. Everything else in
D-01 … D-14 stands unchanged.

Four of the five follow the recommendation research made. One — **D-16** — does not, and it
is written at greater length for exactly that reason.

### D-15: The gallery category ships the full eleven-case enum

**The complete `Category` enum is transmitted — all eleven cases, including `imageSet`
("Image Set") and `private` ("Private").** The recommendation was accepted.

*Question:* D-07 permits "the E-Hentai category enum" and then parenthetically lists nine
names — was the omission of two cases deliberate narrowing, or incomplete recitation?

*Answer:* incomplete recitation. The named entity in D-07 is the enum itself, and the owner's
framing throughout was "collect everything that's not privacy sensitive". Dropping two cases
would have been a tightening of D-07, which `14-CONTEXT.md` forbids.

The enum lives at `AppPackage/Sources/AppModels/Gallery/Category.swift` and has eleven cases;
the analytics vocabulary mirrors all eleven. `Category.private` is a display-only bucket in
this codebase (per decision 09-02) and may never occur in a real payload — it is included
anyway, because excluding it on the grounds that it is unlikely would be narrowing D-07 by a
different route.

*Owned by:* plan 14-03 (the vocabulary types).

### D-16: Per-namespace tag counts ship as exact integers — an amendment to D-08

**Per-namespace tag counts are transmitted as exact `Int` values, not through `CountBucket`.**
The recommendation to bucket them was **declined**.

*Question:* D-07 permits "which namespaces are present … and how many of each"; D-08 requires
counters to ship as buckets, naming exactly one exception. Do per-namespace counts go through
`CountBucket`?

*Answer:* no. They ship exact. Research recommended reading D-08's exception list as
exhaustive; the owner read it as **non-exhaustive** and chose exact counts.

**This amends D-08, which is a locked decision.** D-08 reads: "One documented exception:
search keyword length ships exact." After this decision **D-08 has two documented exceptions**,
not one:

1. **Exact search-keyword length** — the original exception, from D-07/D-08 as written.
2. **Exact per-namespace tag counts** — this decision.

This is recorded as an amendment on purpose. A future reader auditing the D-08 bucketing
guarantee will find analytics payloads carrying exact integers, and this section is the only
place that can explain why they are there. D-16 did not clarify D-08 and did not merely apply
it — it widened it.

**Direction and cost.** The change *widens* what is collected rather than narrowing it, so it
does not violate the phase's standing rule that D-01 … D-14 must never be tightened. It is not
free, though, and the owner made the call with the tradeoff in view: exact counters measured
against the stable per-install identifier of D-10 are materially more distinguishing than
buckets, so this increases the aggregate re-identification surface that D-08's bucketing
existed to reduce. Tag namespaces were already the weakly content-revealing item on the D-07
allow-list — the discussion record in `14-CONTEXT.md` notes they were recommended for removal
and reinstated in full by the owner — and exact counts on that same axis compound rather than
offset that.

**Downstream consequences — flagged here, corrected elsewhere.** This plan writes only this
file; its verification asserts that nothing outside `.planning/` is modified. Three artifacts
now assert something that is no longer true, and each belongs to another plan:

1. **`AppPackage/Sources/AnalyticsClient/Buckets.swift`** (shipped by plan 14-01) carries a
   header comment reading "The single documented exception — exact search-keyword length — is
   minted elsewhere and is deliberately not expressible here." That is now factually wrong:
   there are two exceptions. Plan **14-17** (documentation and bookkeeping close-out) is the
   natural owner of the correction, or plan **14-03** if it touches the file first. Neither
   plan lists `Buckets.swift` in its `files_modified` today, so whichever takes it must add it.
2. **`ANALYTICS-01`** in `.planning/REQUIREMENTS.md` (opened by plan 14-01) states "every
   counter and duration ships as a bucket, with exact search-keyword length as the single
   documented exception". Also now wrong. Plan **14-17** already owns closing out this
   requirement and should correct the wording there.
3. **Plan 14-03's `TagNamespaceCounts`** must carry exact `Int` counts, not `CountBucket`
   values, and plan **14-05**'s `AnalyticsSignal` cases that carry tag counts follow suit.
   `CountBucket` remains the correct and required vocabulary for every other counter — result
   counts, pages read, and the rest — and `DurationBucket` is untouched by this decision.

### D-17: A random 64-character salt, set once, stored beside the app ID

**A random 64-character salt is generated now and stored in the same gitignored
`Config/Analytics.local.xcconfig` that carries the TelemetryDeck app ID (D-13), surfaced to the
app through a second `Info.plist` key.** The recommendation was accepted; the
accept-the-empty-default alternative was declined.

*Question:* the SDK's `Config.salt` defaults to an empty string and its own documentation
recommends a random 64-character value. No locked decision covered it.

**This value is write-once.** The salt is being chosen once, now, and must never change
afterwards. Changing it after release re-derives every anonymized identifier, so every existing
install looks new to the vendor — permanently resetting retention and DAU/MAU, and severing
each install's accumulated history from its future. There is no migration for this and no way
to reconcile the two sides afterwards. Treat the value in the local xcconfig as immutable once
a build carrying it has shipped.

The salt rides in the same gitignored file as the app ID, so a release build that carries the
file carries both, and a build that carries neither already transmits nothing under D-13.

*Owned by:* plan **14-04**, which owns the xcconfig and `Info.plist` plumbing.

### D-18: A SwiftLint custom rule enforces the single-SDK-import boundary

**Approved.** A `custom_rules` entry rejecting the TelemetryDeck SDK import outside the
`AnalyticsClient` module is added to the root `.swiftlint.yml`, with an `excluded:` path for
that module.

*Question:* D-12 says only `AnalyticsClient` imports the SDK. Today that is a convention held
up by review. Should a lint rule make it structural?

*Answer:* yes. The rule makes D-12 enforceable at build time and stands as a second layer
behind the D-09 type wall — the wall stops a `String` from reaching a payload, and the rule
stops a contributor from bypassing the wall entirely by calling the SDK directly. Research
proposed rather than assumed this, because every custom rule in this repository has been a
deliberate owner-approved addition; it is now an approved one.

The repository's standing policy applies to the new rule exactly as it does to the existing
ones: suppressing it, disabling it, or adding a `// swiftlint:disable` for it is forbidden
without the owner's explicit permission.

*Consequence:* plan **14-17**'s conditional lint task is **in scope** and must be executed. It
already lists `.swiftlint.yml` in its `files_modified`.

### D-19: The D-09 wall sits at the `AnalyticsClient` module boundary — an amendment to D-09

**`TagNamespaceCounts(tags:)` and `SearchShape(keyword:)` live inside the `AnalyticsClient`
module and are the audited reduction boundary.** The recommendation was accepted; the fallback
of moving both derivations into `AppModels` was declined.

*Question:* D-09 says `AnalyticsClient`'s public API must not accept a bare `String` anywhere.
Two payloads need content-derived values that only the app domain can compute — the
per-namespace tag counts for an opened gallery, and the search shape. Where exactly does the
wall sit?

**This amends D-09, and the departure is literal.** `SearchShape(keyword: String)` is a
`public init` on a `public` type inside `AnalyticsClient`. Accepting this reading therefore
puts **one `String` parameter on `AnalyticsClient`'s public API**. D-09 as written forbids
exactly that — "must not accept a bare `String` anywhere". This is a real departure from a
locked decision, not a technicality, and it must not be read as a clarification of D-09. The
owner **amended D-09** to permit this single audited initializer, and nothing else.

Recording it matters because D-09's whole value is that it is checkable by reading the module's
public signatures. After this change one signature no longer reads as compliant, and a future
reviewer comparing `AnalyticsClient`'s public surface against D-09 will find the mismatch.
This section is the only place that explains it.

`TagNamespaceCounts(tags: [GalleryTag])` does **not** carry this problem — `GalleryTag` is a
domain type, not a `String`, so that initializer is compliant with D-09 as literally written.

*Why the departure was accepted:* the fallback avoids it entirely, but only by spreading the
reduction across five gallery-open sites and every search site, in a module whose tests do not
prove the reduction. That is strictly worse for both auditability and correctness. Keeping both
derivations inside `AnalyticsClient` concentrates every content-reading line in one exhaustively
tested module.

*What is unchanged by this amendment:*

- `AnalyticsClient.send` accepts only `AnalyticsSignal`.
- No `AnalyticsSignal` case has a `String` associated value; every case carries closed enums,
  `Bool`s, bucket values, or the exact `Int`s that D-07 and D-16 permit.
- The signal-carrying API stays `String`-free. The amendment touches one derivation
  initializer, not the transmission path.

*Scope of the amendment:* exactly one initializer. `SearchShape(keyword:)` is the only
`String`-accepting entry point permitted on `AnalyticsClient`'s public surface; a second one
reopens this decision rather than inheriting it.

*Requirements that ride with the approval:* the initializer is marked in source as the single
audited exception to D-09, and is exhaustively tested with sentinel keywords proving that
nothing content-bearing survives the reduction. Plan **14-03** owns both.

---

### D-20: Pause and resume become measurable — an amendment to D-05

**`DownloadOutcome` gains pause/resume coverage, and `toggleDownloadPauseDone` is instrumented.**
Owned by plan **14-17**.

*Question:* plan 14-13 verified the download-completion inventory by search and found a fourth
case the plan had not named — `toggleDownloadPauseDone`. `DownloadOutcome` had no case able to
express it (`started`, `retried`, `completed`, `failed`, `deleted`, `moved`), so pause/resume was
unmeasurable by construction and 14-13 left it uninstrumented, pinned by a zero-signal test, and
raised it rather than widening a locked vocabulary on its own authority.

*Answer:* add the capability. The owner chose to make pause/resume visible rather than leave it
outside the taxonomy.

**This amends D-05**, which fixed the signal families and their outcomes. It is the phase's
**third** amendment to a locked decision, alongside D-16 (D-08) and D-19 (D-09). Like those, it
*widens* rather than narrows, so it clears the standing no-tightening rule.

**Two cases, not one — recorded as an inference, correct it if wrong.** The toggle is
bidirectional: the reducer sends the same action for both directions and decides which happened
from `state.downloadBadge?.status` before mutating it (`.active` → `.inactive` is a pause,
`.inactive` → `.queued` is a resume). A single `paused` case would therefore count two opposite
user actions under one name. This phase has already rejected exactly that error twice — D-16
records it as the reason to keep metrics distinct, and 14-13 assigned download *failure*
exclusively to the downloads-list diff so start-time and transfer-time failures would not share a
name. Applying the same principle, this decision is recorded as **two** cases, `paused` and
`resumed`, rather than one conflated case. The direction is already available at the emission
site, so no new state or plumbing is required.

**What plan 14-17 must do:**

1. Add `paused` and `resumed` to `DownloadOutcome` in
   `AppPackage/Sources/AnalyticsClient/AnalyticsVocabulary.swift`.
2. Add the two rendering entries, if the rendering layer enumerates outcomes explicitly.
3. Emit from `toggleDownloadPauseDone`'s success arm in **both** modules that own the action,
   choosing the outcome from the pre-mutation badge status. The failure arms stay silent,
   consistent with the other three download outcomes:
   - `AppPackage/Sources/DetailFeature/DetailReducer+Download.swift` (found by plan 14-13)
   - `AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift` (found by plan 14-15)

   **Scope correction, added 2026-07-25.** This decision originally named only the `DetailFeature`
   site, because 14-13 was the plan that raised it. Plan 14-15's inventory search then found the
   same action in `DownloadsReducer`. Instrumenting only one would measure pause/resume from the
   detail screen while silently missing it from the downloads list — a half-measured metric, which
   is more misleading than an unmeasured one, since a gap in coverage is indistinguishable from
   users not pausing.
4. **Replace** the `toggleDownloadPauseRecordsNothing` test in
   `AppPackage/Tests/DetailFeatureTests/AnalyticsEmissionTests.swift`. It currently pins the
   *exclusion* and will fail once the emission exists — that is the test working as intended, not
   a regression. It becomes a two-direction emission assertion, keeping a zero-signal assertion
   for the failure arm only.
5. Note in the 14-17 summary that this is an amendment to D-05, so the taxonomy's history stays
   auditable.

**Second scope correction, added 2026-07-25 during 14-17.** Implementation found a **third**
entry point: `DownloadInspectorReducer` also owns a `toggleDownloadPause`/`toggleDownloadPauseDone`
pair. The owner confirmed the emission strategy as **per-reducer at all three sites** — detail
screen, inspector sheet, downloads list — rather than moving pause into the snapshot diff. Two
reasons, both structural:

- The download-outcome family already splits by mechanism: *transfer endings* (`completed`,
  `failed`) are observed by the snapshot diff, while *management actions* (`deleted`, `moved`)
  emit per-reducer at each screen's own completion so they count from any screen. Pause/resume is
  a management action; putting it in the diff would split one category across two mechanisms.
- The diff only sees what the downloads list is observing. A pause from a Home-pushed detail
  screen may never cross that stream, and the resulting gap would be invisible in the data.

The direction is computed **at request time** from state each reducer already holds (the list's
`state.downloads`, the inspector's `state.inspection`, detail's own badge), so no action
signature changes and the existing `Done` flow is untouched. The diff already ignores
active↔inactive transitions, so there is no double-count.

---

### D-21: A download update is its own outcome — a further amendment to D-05

**`DownloadOutcome` gains `updated`, and `updateDownloadDone` is instrumented.** Owned by plan **14-17**.

*Question:* plan 14-15's inventory search found `updateDownloadDone(Result<Void, AppError>)` in
`DownloadsReducer` — the user re-fetching a gallery flagged `updateAvailable`. It is a genuine
user-visible download outcome, but `DownloadOutcome` had no case able to express it: exactly the
situation pause/resume was in before D-20. Plan 14-15 raised it rather than instrumenting it.

*Answer:* add the capability. The owner chose to measure it, consistent with the same choice made
for pause/resume in D-20.

**This amends D-05**, making it the phase's **fourth** amendment to a locked decision, after D-16
(D-08), D-19 (D-09) and D-20 (D-05). Like the others it *widens* rather than narrows, so it clears
the standing no-tightening rule.

**Explicitly rejected alternative:** mapping an update onto the existing `completed` outcome. That
would conflate a first-time download with a re-fetch of an already-downloaded gallery — the same
"two things under one name" error that D-16 records as its central cost and that 14-13's
failure-ownership split exists to avoid. A no-vocabulary-change option was available and was
declined for that reason.

**What plan 14-17 must do:**

1. Add `updated` to `DownloadOutcome` in
   `AppPackage/Sources/AnalyticsClient/AnalyticsVocabulary.swift`, alongside D-20's `paused` and
   `resumed`. All three land in one pass, so the download-outcome family is completed once rather
   than amended repeatedly.
2. Emit from `updateDownloadDone`'s success arm in
   `AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift`. The failure arm stays silent,
   consistent with every other download outcome — a failed update is not an update.
3. Extend `AppPackage/Tests/DownloadsFeatureTests/AnalyticsEmissionTests.swift` with a
   success-arm emission assertion and a failure-arm zero-signal assertion.
4. Note in the 14-17 summary that this is an amendment to D-05, so the taxonomy's history stays
   auditable.

**Naming correction, added 2026-07-25 during 14-17.** Implementation found that the detail
screen's update path — `DetailView` sends `retryDownloadButtonTapped(.update)` — already emits
`.retried` (shipped in plan 14-13), so D-21 as written would have reported one user intent under
two names depending on which screen initiated it. The owner confirmed **one name from both
sites**: `.updated` emits at queue time from the list's `updateDownloadDone` **and** from
detail's `retryDownloadDone` when the pre-mutation badge status was `.updateAvailable`. Genuine
error-retries (pre-mutation status `.error`) keep `.retried`. This narrows plan 14-13's shipped
retry emission and updates its test — recorded as a correction, not a regression. `.updated`
stays a queue-time outcome like `started` and `retried`; detecting it in the finish-time snapshot
diff was considered and rejected as incoherent with the family's timing semantics.

---

*Phase: 14-analytics-instrumentation*
*Decisions answered: 2026-07-24; D-20 added and D-21 added 2026-07-25*
