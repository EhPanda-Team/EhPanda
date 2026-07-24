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

*Phase: 14-analytics-instrumentation*
*Decisions answered: 2026-07-24*
