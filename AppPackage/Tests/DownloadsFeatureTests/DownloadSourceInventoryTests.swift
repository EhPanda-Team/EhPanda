import Foundation
import Testing

/// Fails the build when a source inventory a load-bearing doc comment cites moves.
///
/// This module's docs carry several censuses of source — "the writers this re-clears", "the only
/// sites that take a scheduling block", "five writers, verified exhaustive at this HEAD" — because
/// the invariants they state are not derivable from the one function a reader is looking at. Such an
/// inventory is correct on the day it is written and unowned forever after: nothing fails when a
/// sixth site appears, so the comment silently becomes a false premise, and a later fix reasoning
/// from it lands wrong. That is not hypothetical here. It is the recorded generator of G-15-3,
/// G-15-7, G-15-13 and G-15-19, and of the five doc-vs-source contradictions of G-15-20 — three of
/// which were written by the doc-correction work of the round before.
///
/// A corrected comment alone therefore closes nothing; it only resets the clock. So every inventory
/// that survives in a doc is paired here with an equality that a drift breaks, on the pattern
/// `DownloadLogPrivacyInvariantTests.expectedHashMaskedCounts` already establishes: a repository-root
/// walk, a known-member guard so a walk that found nothing cannot pass vacuously, detection tokens
/// assembled from fragments so a repository grep gate cannot match the check that enforces it, and a
/// per-file table asserted alongside a separately-counted joined total, which no two same-named
/// files can collapse.
///
/// One claim here is a SENTENCE rather than an inventory, and it is the original reason the walk
/// grew past the client module to the downloads test target. A doc claim is load-bearing wherever it is
/// written, and a Sources-scoped guard cannot see a retired claim that survives in a test — which is
/// not hypothetical either: it is G-15-29. Every census names the tree it counts over EXPLICITLY —
/// through `clientModuleFiles(in:)`, `downloadsTestFiles(in:)` or `clientDoubleFiles(in:)` —
/// because a census counts over the files the scan returns, so a table that never said which tree
/// it meant re-bases itself the moment the walk widens. Five censuses count the client module
/// alone; the two double-fidelity censuses count the downloads test target PLUS the processing
/// client's own module. That second tree used to be excluded on the classification that its two
/// public values are "production surfaces", and G-15-36 is what that classification hid: `noop` is
/// a hand-built double under a Test mark, it is the DEFAULT client of `DownloadCoordinator.init`,
/// and its atomic endpoints certified the seam's reentrancy windows as impossible across most of
/// the suite. `live` alone carries no yield obligation — its main-actor hop is the genuine article
/// the convention simulates.
///
/// A failure here is not a defect by itself. It means source moved and a doc that cites it must be
/// re-read and re-derived before the table is updated — which is the whole point.
@Suite
struct DownloadSourceInventoryTests {
    private struct ScannedFile {
        let relativePath: String
        let contents: String

        var fileName: String {
            relativePath.split(separator: "/").last.map(String.init) ?? relativePath
        }
    }

    private static let clientModuleDirectory = "AppPackage/Sources/DownloadClient"
    private static let downloadsTestDirectory = "AppPackage/Tests/DownloadsFeatureTests"
    private static let processingClientModuleDirectory = "AppPackage/Sources/BackgroundProcessingClient"

    /// Both trees this suite walks, and the reason the walk is wider than the censuses are.
    ///
    /// The test target joined the walk because a load-bearing doc claim does not stop being
    /// load-bearing when it is written in a test. The retired single-authority sentence was
    /// corrected in `+PendingWork.swift` and went on standing in two suites, where a
    /// Sources-scoped scan structurally could not see it (G-15-29).
    ///
    /// The walk excludes this file itself, so the prose assertion cannot read this suite's own
    /// description of the rule back as a violation of it; `scannedFiles()` carries that argument.
    ///
    /// Only the prose assertion reads this whole set. Every census re-scopes it first — the five
    /// production censuses to the client module through `clientModuleFiles(in:)`, the two
    /// double-fidelity censuses to this directory through `downloadsTestFiles(in:)` — so widening
    /// the walk moved no table then and adding a test-scoped table moves none now. That scoping is
    /// load-bearing rather than tidy: `DownloadZeroPagePayloadTests` evaluates the run's pending page
    /// list three times, so an unscoped pending-list census would have silently re-baselined itself
    /// from one to four the moment this directory joined — trading one unowned claim for a censused
    /// one that had quietly stopped meaning what its doc says.
    private static let scannedDirectories = [
        clientModuleDirectory,
        downloadsTestDirectory,
        processingClientModuleDirectory
    ]

    /// One file per scanned directory, so an enumerator that silently walked nothing cannot let a
    /// test pass vacuously.
    ///
    /// The test target's member is deliberately the file that carried the retired claim rather than
    /// an arbitrary one: a known member proves the walk found SOMETHING, and naming this file makes
    /// it prove the walk reaches where the claim actually lived.
    private static let knownMembers = [
        clientModuleDirectory + "/DownloadClient+Manager.swift",
        downloadsTestDirectory + "/DownloadContinuedSessionBasisTests.swift",
        processingClientModuleDirectory + "/BackgroundProcessingClient.swift"
    ]
    private static let repositoryRootMarkers = ["App", "AppPackage"]

    /// The scanner's own detection tokens, assembled from fragments so a repository grep gate
    /// counting either inventory cannot match the suite that pins it.
    private static var schedulingBlockCallToken: String { "block" + "Scheduling(" }
    private static var schedulableReadToken: String { "schedulable" + "Downloads()" }
    private static var floorPropertyName: String { "lastPushed" + "CompletedPageCount" }
    private static var queueEnqueueToken: String { "queueStore" + ".enqueue(" }
    private static var pendingPageListToken: String { "pendingPage" + "Indices(" }
    private static var runProofPropertyName: String { "runProgress" + "Bases" }
    /// The hand-built client double's construction token, and it is the seam's own endpoint LABEL
    /// rather than the type name on purpose.
    ///
    /// A type-name token matches `BackgroundProcessingClient(` and misses `Self(` written inside an
    /// extension of the type — which is exactly how the `.unavailable` double this census was
    /// written for is spelled, so a type-name census would have carried its blind spot precisely
    /// where the real violation lived. Every hand-built value must supply all three endpoints, so
    /// the label reaches both spellings, while the macro-synthesized no-argument value supplies
    /// none and falls out by construction rather than by an exclusion someone has to remember.
    private static var clientDoubleEndpointToken: String { "updateProgress" + ":" }
    /// The suspension each closure of a hand-built double must open with, assembled from fragments
    /// for the reason every token here is: this file sits inside the tree the double censuses count
    /// over, so a token written whole would count itself.
    private static var clientDoubleSuspensionToken: String { "Task" + ".yield()" }
    /// The retired claim's recorded phrasings, assembled from fragments for exactly the reason the
    /// census tokens are: a repository grep counting the claim must not match the check that forbids
    /// it, or the check becomes part of the inventory it polices.
    private static var retiredAuthorityPhrases: [String] {
        ["one" + " authority", "sole" + " authority", "only" + " authority"]
    }
    private static var declarationPrefix: String { "func" + " " }
    private static var storedDeclarationPrefix: String { "var" + " " }
    private static var mutationOperators: [String] { ["=", "+=", "-=", "*=", "/="] }

    /// Every site that takes a gallery's scheduling block, named per file.
    ///
    /// This is the census `writeSettledPauseRecord`'s doc reasons from: it states that no
    /// queue-mobilizing entry point takes a block, and the way that invariant can rot is a mobilizer
    /// quietly gaining one, or a new blocking operation appearing that nobody dispositioned against
    /// G-15-8's release-then-converge rule. Both move a number here.
    ///
    /// Derived from source rather than copied: `commitPause` (`+Scheduling.swift`), `delete`
    /// (`+PublicAPI.swift`), `deleteFolder` and `moveDownload` (`+Folders.swift`), and the testing
    /// forwarder (`+Testing.swift`) that lets a suite stage two overlapping holders without racing
    /// two real operations. The declaration itself is excluded, as are doc-comment mentions — the
    /// count is of calls.
    private static let expectedSchedulingBlockCallSites = [
        "DownloadClient+Folders.swift": 2,
        "DownloadClient+PublicAPI.swift": 1,
        "DownloadClient+Scheduling.swift": 1,
        "DownloadClient+Testing.swift": 1
    ]

    /// The table's sum, asserted separately against a count taken over the joined scanned text.
    ///
    /// The table is keyed by file name, so two same-named files anywhere under the module would
    /// collapse into one entry and hide a site. The joined count cannot collapse.
    private static let expectedSchedulingBlockCallTotal = 5

    /// Every mutation of the monotonic floor under the numerator a session pushes, named per file.
    ///
    /// This is the inventory `lastPushedCompletedPageCount`'s own doc carries, and that doc used to
    /// close by asking the reader to re-run the grep it was derived from. It now names this table
    /// instead. The four in `+ContinuedSession.swift` are the session-start reset, the seed merge
    /// after the client start returns, the teardown zero and the per-push re-latch; the one in
    /// `+ExecutionSupport.swift` is D-G7-01's withdrawal, whose single implementation serves both of
    /// its call sites — which is why one rule counts once here.
    private static let expectedFloorWriters = [
        "DownloadClient+ContinuedSession.swift": 4,
        "DownloadClient+ExecutionSupport.swift": 1
    ]

    /// The floor table's sum, asserted the same way and for the same reason.
    private static let expectedFloorWriterTotal = 5

    /// Every entrance to the queue store, named per file.
    ///
    /// This is the census `validationErrors`' own declaration reasons from: "anything that enqueues
    /// must clear it at or before the enqueue". That rule is not derivable from any one of these
    /// sites, and its failure mode is silent — the map outranks queue membership in `displayStatus`,
    /// so a gallery enqueued with an entry standing derives `.error`, fails both arms of
    /// `shouldSchedule`, and sits in the queue store forever without running. That is the G-15-5 dead
    /// end, and it is exactly what `enqueue(payload:)` did: four of the five entrances cleared, the
    /// fifth never called `clearDownloadFailureState` at all, and nothing counted them.
    ///
    /// Derived from source rather than copied: `resume` (`+Scheduling.swift`), `performRetry` and
    /// `performRetryPages` (`+RetryHelpers.swift`), `enqueue` (`+PublicAPI.swift`), and the testing
    /// forwarder (`+Testing.swift`). A failure means an entrance was added or removed; re-read each
    /// one against the clearing rule BEFORE updating this number, because a new entrance that does
    /// not clear is precisely the defect this stands for.
    private static let expectedQueueEnqueueCallSites = [
        "DownloadClient+PublicAPI.swift": 1,
        "DownloadClient+RetryHelpers.swift": 2,
        "DownloadClient+Scheduling.swift": 1,
        "DownloadClient+Testing.swift": 1
    ]

    /// The enqueue table's sum, asserted the same way and for the same reason.
    private static let expectedQueueEnqueueCallTotal = 5

    /// Every call of the shared schedulable-work read, named per file.
    ///
    /// This is the caller list the read's own header carries and the G-15-8 paragraph in
    /// `+Manager.swift` repeats: the pending-work gate in `+PendingWork.swift`, and the session
    /// snapshot plus the expiration sweep in `+ContinuedSession.swift`. Both docs also state what is
    /// deliberately NOT in it — `scheduleNextIfNeededCore`, which shares only the predicate and reads
    /// its own queue-scoped set — so those sentences rot in three ways: a fourth reader appearing, a
    /// reader being removed, or the scheduler gaining this call. Each moves a number here, and the
    /// last one moves it into a file the table does not list at all.
    ///
    /// That is not a hypothetical rot path. The single-authority sentence was false in two files at
    /// once, uncaught across five rounds, and the second of them was written by a round whose job was
    /// correcting the first (G-15-24). Nothing counted it until this table.
    ///
    /// Derived from source rather than copied. The declaration is excluded, as are doc-comment
    /// mentions — this function has more of those than calls — because the count is of calls.
    private static let expectedSchedulableReadCallSites = [
        "DownloadClient+ContinuedSession.swift": 2,
        "DownloadClient+PendingWork.swift": 1
    ]

    /// The read table's sum, asserted the same way and for the same reason.
    private static let expectedSchedulableReadCallTotal = 3

    /// Every evaluation of the run's pending page list, named per file.
    ///
    /// This is the inventory `prepareWorkingSeedAnnouncingProgress`'s doc reasons from, and it is
    /// the one census whose expected value is a rule rather than a tally: the list must be derived
    /// EXACTLY ONCE per run, inside the preparation, and handed to `performDownload` for the page
    /// loop. Two evaluations is how G-15-27 could recur — the announcement's gate and the loop would
    /// each hold their own answer, and a later fix moving one and not the other grants trust for
    /// work the loop never does (T-15-47-03). `performDownload` held the second evaluation until
    /// this round; nothing failed when it did.
    ///
    /// Derived from source rather than copied. The declaration is excluded, as are doc-comment
    /// mentions and the `pendingPageIndices:` argument labels the page loop is threaded through,
    /// which carry a colon rather than a paren — the count is of calls.
    private static let expectedPendingPageIndicesCallSites = [
        "DownloadClient+ExecutionSupport.swift": 1
    ]

    /// The pending-list table's sum, asserted the same way and for the same reason.
    private static let expectedPendingPageIndicesCallTotal = 1

    /// Every site naming the run-scoped progress measurement, named per file.
    ///
    /// This is the census the property's own declaration reasons from, and the claim it owns is a
    /// LIFETIME. Each of the seven is exactly one role: the declaration in `+Manager.swift`; the
    /// announcement at the run's own preparation in `+ExecutionSupport.swift`; the landing at the
    /// manifest page flush in `+Persistence.swift`, which is the one point every landed page
    /// passes; the basis-first read of the credited-pages definition, the has-a-reading predicate
    /// the D-G7-01 bracket and the run-exit freeze share, and the departure reconcile's live-run
    /// branch selector, all in `+ContinuedSession.swift`; and the retirement at the run's end in
    /// `+Execution.swift`.
    ///
    /// **What the count pins.** Seven sites pin the lifetime AND the arithmetic: an eighth site is
    /// almost always a second reader of the credited basis outside the single definition, which is
    /// how the opening rule and the departure rule come to disagree about one gallery, or a second
    /// landing point, which is how a page comes to be credited twice or not at all — G-15-35 was
    /// exactly a landing route (`performCacheCapture`) that recorded a page while advancing no
    /// measurement. The `+Persistence.swift` entry is therefore load-bearing as a count of ONE.
    ///
    /// It is a whole-name count rather than a mutation count on purpose, because the way this
    /// invariant rots is a READ or a CLEAR appearing rather than an assignment. The specific rot
    /// this pins against is a clear being added to `markContinuedSessionEnded` or to
    /// `ensureContinuedSession`'s reset — conflating a session boundary with a run boundary, which
    /// is precisely the defect G-15-26 recorded — and either would take `+ContinuedSession.swift`
    /// from three to four.
    ///
    /// Derived from source rather than copied. Doc-comment mentions are excluded, as everywhere else
    /// here — this property has more of those than uses.
    private static let expectedRunProofSites = [
        "DownloadClient+ContinuedSession.swift": 3,
        "DownloadClient+Execution.swift": 1,
        "DownloadClient+ExecutionSupport.swift": 1,
        "DownloadClient+Manager.swift": 1,
        "DownloadClient+Persistence.swift": 1
    ]

    /// The run-proof table's sum, asserted the same way and for the same reason.
    private static let expectedRunProofSiteTotal = 7

    /// Every suspension point inside the scanned hand-built client doubles, named per file.
    ///
    /// **What this number means.** `BackgroundProcessingClient.live` forwards onto a `@MainActor`
    /// store, so each of its three endpoints hops off the calling actor. A double that answers
    /// synchronously is therefore not a faster stand-in but a DIFFERENT seam: it certifies as
    /// impossible every reentrancy the live one admits, and a suite green against it is green about
    /// a world that does not exist. Three closures apiece across three doubles is the nine below.
    ///
    /// The full argument for the rule lives on `BackgroundProcessingClientSpy`'s header, where it
    /// was written and — until this census — honoured alone; a reader who wants the reasoning
    /// rather than the count should start there.
    ///
    /// The module's own row counts `noop`'s three yields and nothing of `live`'s: `live` needs no
    /// simulated suspension because its main-actor hop is the genuine article the convention
    /// simulates, while `noop` is a hand-built double that happens to ship in the module as the
    /// coordinator's default client, which is exactly why its atomicity was the census's blind
    /// spot for a round (G-15-36).
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
    /// The population is DERIVED rather than listed — the files below are whichever scanned files
    /// in the two double-bearing trees build a value of the type. Zero counts are kept rather than
    /// dropped, unlike every census above, because a double that stops suspending ENTIRELY is the
    /// exact failure this half exists to name and a dropped key would let it vanish from the
    /// observed table instead.
    private static let expectedClientDoubleSuspensionSites = [
        "BackgroundProcessingClient.swift": 3,
        "DownloadContinuedSessionExpirationTests.swift": 3,
        "DownloadFeatureTestSupportTypes.swift": 3
    ]

    /// The suspension table's sum, asserted separately for the reason every joined total here is.
    private static let expectedClientDoubleSuspensionTotal = 9

    /// Every construction-shaped naming of the seam's endpoints in the double-bearing trees,
    /// named per file.
    ///
    /// **What this number means.** A POPULATION rather than a property. Three hand-built doubles
    /// exist — the recording spy, the `.unavailable` refusal value and the module's `noop`
    /// default — and the timing obligation above covers exactly those three. The module file's
    /// count of three is one declaration plus two constructions: the endpoint-label token
    /// necessarily matches the `updateProgress` property declaration and the `live` value there,
    /// and both rows are deliberately counted rather than filtered, so a fourth match in that file
    /// means a new value appeared and must be classified. `live` is the one construction with no
    /// yield obligation — its hop is real — and the macro-synthesized no-argument value supplies
    /// no endpoints and falls out by construction.
    ///
    /// **What would move it.** A new hand-built double anywhere under either scanned tree,
    /// including in a file the suspension table has never heard of — the case that table
    /// structurally cannot catch.
    ///
    /// **What a failure obliges.** Re-derive the population FIRST: classify the new value as
    /// hand-built, generated or the genuine live surface, and only if it is hand-built add it here
    /// AND to the suspension table with a yield opening each of its closures. Neither number is
    /// adjusted until the double itself passes.
    private static let expectedClientDoubleConstructionSites = [
        "BackgroundProcessingClient.swift": 3,
        "DownloadContinuedSessionExpirationTests.swift": 1,
        "DownloadFeatureTestSupportTypes.swift": 1
    ]

    /// The population table's sum, asserted the same way and for the same reason.
    private static let expectedClientDoubleConstructionTotal = 5

    @Test
    func testSchedulingBlockCallSitesMatchTheRecordedCensus() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try Self.requireKnownMembers(in: files)

        let moduleFiles = Self.clientModuleFiles(in: files)

        var callSites = [String: Int]()
        for file in moduleFiles {
            let count = Self.callSiteCount(of: Self.schedulingBlockCallToken, in: file.contents)
            guard count > 0 else { continue }
            callSites[file.fileName, default: 0] += count
        }
        #expect(
            callSites == Self.expectedSchedulingBlockCallSites,
            """
            The scheduling-block census moved. Re-derive which operations now take a block, \
            re-read the invariant in writeSettledPauseRecord's doc against them, and only then \
            update this table.
            """
        )

        let joined = moduleFiles.map(\.contents).joined(separator: "\n")
        #expect(
            Self.callSiteCount(of: Self.schedulingBlockCallToken, in: joined)
                == Self.expectedSchedulingBlockCallTotal
        )
    }

    @Test
    func testFloorWriterAssignmentsMatchTheRecordedCensus() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try Self.requireKnownMembers(in: files)

        let moduleFiles = Self.clientModuleFiles(in: files)

        var writers = [String: Int]()
        for file in moduleFiles {
            let count = Self.mutationCount(of: Self.floorPropertyName, in: file.contents)
            guard count > 0 else { continue }
            writers[file.fileName, default: 0] += count
        }
        #expect(
            writers == Self.expectedFloorWriters,
            """
            The monotonic-floor writer census moved. Re-derive the writers, re-read the inventory \
            on the property's own declaration against them, and only then update this table.
            """
        )

        let joined = moduleFiles.map(\.contents).joined(separator: "\n")
        #expect(
            Self.mutationCount(of: Self.floorPropertyName, in: joined) == Self.expectedFloorWriterTotal
        )
    }

    @Test
    func testQueueEnqueueCallSitesMatchTheRecordedCensus() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try Self.requireKnownMembers(in: files)

        let moduleFiles = Self.clientModuleFiles(in: files)

        var callSites = [String: Int]()
        for file in moduleFiles {
            let count = Self.callSiteCount(of: Self.queueEnqueueToken, in: file.contents)
            guard count > 0 else { continue }
            callSites[file.fileName, default: 0] += count
        }
        #expect(
            callSites == Self.expectedQueueEnqueueCallSites,
            """
            The queue-entrance census moved. Re-read EVERY entrance against the rule on \
            validationErrors' declaration — anything that enqueues must clear the failure state at \
            or before the enqueue — and only then update this table. An entrance that does not \
            clear leaves a gallery queued and permanently unschedulable.
            """
        )

        let joined = moduleFiles.map(\.contents).joined(separator: "\n")
        #expect(
            Self.callSiteCount(of: Self.queueEnqueueToken, in: joined)
                == Self.expectedQueueEnqueueCallTotal
        )
    }

    @Test
    func testSchedulableDownloadsCallSitesMatchTheRecordedCensus() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try Self.requireKnownMembers(in: files)

        let moduleFiles = Self.clientModuleFiles(in: files)

        var callSites = [String: Int]()
        for file in moduleFiles {
            let count = Self.callSiteCount(of: Self.schedulableReadToken, in: file.contents)
            guard count > 0 else { continue }
            callSites[file.fileName, default: 0] += count
        }
        #expect(
            callSites == Self.expectedSchedulableReadCallSites,
            """
            The schedulable-read caller census moved. Re-derive who reads through the shared \
            schedulable-work function and whether the scheduler now does, re-read that function's \
            own header and the G-15-8 paragraph in +Manager.swift against them, and only then \
            update this table.
            """
        )

        let joined = moduleFiles.map(\.contents).joined(separator: "\n")
        #expect(
            Self.callSiteCount(of: Self.schedulableReadToken, in: joined)
                == Self.expectedSchedulableReadCallTotal
        )
    }

    @Test
    func testPendingPageListEvaluationsMatchTheRecordedCensus() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try Self.requireKnownMembers(in: files)

        let moduleFiles = Self.clientModuleFiles(in: files)

        var callSites = [String: Int]()
        for file in moduleFiles {
            let count = Self.callSiteCount(of: Self.pendingPageListToken, in: file.contents)
            guard count > 0 else { continue }
            callSites[file.fileName, default: 0] += count
        }
        #expect(
            callSites == Self.expectedPendingPageIndicesCallSites,
            """
            The pending-page-list census moved. A run derives that list exactly once, inside \
            prepareWorkingSeedAnnouncingProgress, and hands it to performDownload; a second \
            evaluation lets the announcement's gate and the page loop disagree about what this run \
            will fetch. Re-derive who evaluates it and why before updating this table.
            """
        )

        let joined = moduleFiles.map(\.contents).joined(separator: "\n")
        #expect(
            Self.callSiteCount(of: Self.pendingPageListToken, in: joined)
                == Self.expectedPendingPageIndicesCallTotal
        )
    }

    @Test
    func testRunScopedPageWorkProofSitesMatchTheRecordedCensus() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try Self.requireKnownMembers(in: files)

        let moduleFiles = Self.clientModuleFiles(in: files)

        var sites = [String: Int]()
        for file in moduleFiles {
            let count = Self.callSiteCount(of: Self.runProofPropertyName, in: file.contents)
            guard count > 0 else { continue }
            sites[file.fileName, default: 0] += count
        }
        #expect(
            sites == Self.expectedRunProofSites,
            """
            The run-scoped progress measurement census moved. The measurement has exactly seven \
            roles — its declaration, the announcement at the run's own preparation, the landing at \
            the manifest page flush, the credited-pages definition's basis-first read, the \
            has-a-reading predicate, the departure reconcile's live-run branch selector, and the \
            retirement at the run's end. An eighth site is almost always one of three known \
            defects: a clear added at a SESSION boundary (G-15-26 — a session ending is not the \
            run ending, and erasing the measurement there leaves an in-flight repair contributing \
            zero for the rest of its re-download), a second reader of the credited basis outside \
            the single definition (the opening rule and the departure rule then disagree about one \
            gallery), or a second landing point (a page credited twice or not at all, which is \
            G-15-35). Re-derive the lifetime against the property's own declaration before \
            updating this table.
            """
        )

        let joined = moduleFiles.map(\.contents).joined(separator: "\n")
        #expect(
            Self.callSiteCount(of: Self.runProofPropertyName, in: joined)
                == Self.expectedRunProofSiteTotal
        )
    }

    @Test
    func testClientDoubleSuspensionSitesMatchTheRecordedCensus() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try Self.requireKnownMembers(in: files)

        let doubleFiles = Self.clientDoubleFiles(in: files)
        try #require(doubleFiles.isEmpty == false)

        var suspensionSites = [String: Int]()
        for file in doubleFiles {
            suspensionSites[file.fileName, default: 0] += Self.callSiteCount(
                of: Self.clientDoubleSuspensionToken,
                in: file.contents
            )
        }
        #expect(
            suspensionSites == Self.expectedClientDoubleSuspensionSites,
            """
            A hand-built client double's timing no longer mirrors the seam it stands for. The live \
            value forwards onto a main-actor store, so all three of its endpoints hop off the \
            calling actor; a double that answers synchronously certifies as impossible every \
            reentrancy production admits, and the coordinator's post-start ownership re-check, its \
            additive floor seed and its merged observation seed are then exercised in a world \
            where the window they exist to survive cannot open. Re-read the named double's \
            closures against the spy's three and make them suspend before touching this table.
            """
        )

        let joined = doubleFiles.map(\.contents).joined(separator: "\n")
        #expect(
            Self.callSiteCount(of: Self.clientDoubleSuspensionToken, in: joined)
                == Self.expectedClientDoubleSuspensionTotal
        )
    }

    @Test
    func testClientDoubleConstructionSitesMatchTheRecordedCensus() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try Self.requireKnownMembers(in: files)

        let treeFiles = Self.clientDoubleTreeFiles(in: files)

        var constructionSites = [String: Int]()
        for file in treeFiles {
            let count = Self.callSiteCount(of: Self.clientDoubleEndpointToken, in: file.contents)
            guard count > 0 else { continue }
            constructionSites[file.fileName, default: 0] += count
        }
        #expect(
            constructionSites == Self.expectedClientDoubleConstructionSites,
            """
            The hand-built client double population moved. Classify the new value before touching \
            this table: a macro-synthesized unimplemented value carries no timing obligation and \
            the live value's main-actor hop is the genuine article, while a hand-built stand-in \
            for this seam — wherever it ships, the module's noop default included (G-15-36) — \
            does. Only a hand-built one belongs here, and it belongs in the suspension table \
            beside it, with a suspension opening each of its closures.
            """
        )

        let joined = treeFiles.map(\.contents).joined(separator: "\n")
        #expect(
            Self.callSiteCount(of: Self.clientDoubleEndpointToken, in: joined)
                == Self.expectedClientDoubleConstructionTotal
        )
    }

    /// No scanned doc may name the shared schedulable read as the scheduler's single authority.
    ///
    /// **The retired claim, in plain words.** It called the shared schedulable read the
    /// scheduler's sole authority on what may start — every start, it said, passes through that
    /// one read. Stating it here in the wording the check forbids is deliberate, and it is the
    /// capability the scanner's self-exclusion exists to grant: before that exclusion this sentence
    /// could not be written, so the file that owns the rule was the one file forbidden to say what
    /// the rule is about. A repository-wide grep for the phrasing therefore no longer sums to zero;
    /// this occurrence is it, and the live guard is this assertion rather than any grep.
    ///
    /// The claim is retired, and what retired it is source: `scheduleNextIfNeededCore` performs its
    /// OWN read — `queueStore.gids`, then `indexedDownloads()` or `indexedDownloads(gids:)` — and
    /// reaches `isSchedulableDownload` through `nextQueuedDownload` /
    /// `nextUnqueuedSchedulableDownload`. What it shares with the shared read is the PREDICATE, not
    /// the read. The shared read's three callers are `hasPendingWork()`, `schedulableSnapshot()` and
    /// `pauseAllSchedulable(expiring:)`, which the caller census above already owns for Sources.
    ///
    /// This owns the SENTENCE rather than a count, and it owns it across the test target too,
    /// because that is exactly where the wording kept surviving: corrected in `+PendingWork.swift`
    /// and left standing in two suites a Sources-scoped census could not reach (G-15-29). Unlike
    /// every census here it reads whole files rather than executable lines — policing prose is the
    /// entire point, so the comment filter would make it vacuous.
    ///
    /// A failure means a doc states the retired claim again, or a legitimate new sentence collides
    /// with the phrasing. Either way the caller list is re-derived from source FIRST and the
    /// sentence is rewritten from that derivation — never from this test's wording.
    @Test
    func testNoScannedDocNamesTheSharedReadAsTheSchedulersSoleAuthority() throws {
        let files = try Self.scannedFiles()
        try #require(files.isEmpty == false)
        try Self.requireKnownMembers(in: files)

        var offenders = [String]()
        for file in files where Self.namesTheRetiredClaim(file.contents) {
            offenders.append(file.relativePath)
        }
        #expect(
            offenders.sorted() == [],
            """
            The retired single-authority claim is present in \
            \(offenders.sorted().joined(separator: ", ")). The schedulable read has three callers \
            and the scheduler is not one of them: it performs its own indexed read and shares only \
            the predicate. Re-derive that caller list from source and rewrite the sentence from the \
            derivation before touching this check.
            """
        )
    }
}

// MARK: - Census Scanning

private extension DownloadSourceInventoryTests {
    /// Calls of `token`, excluding the declaration that introduces it and every comment line.
    ///
    /// Comments are skipped because both censuses are cited BY comments: counting those mentions
    /// would make a doc that describes the inventory part of the inventory, so correcting a sentence
    /// would move the number it stands for.
    static func callSiteCount(of token: String, in contents: String) -> Int {
        executableLines(in: contents).reduce(into: 0) { total, line in
            guard line.contains(declarationPrefix + token) == false else { return }
            total += occurrences(of: token, in: line)
        }
    }

    /// Mutations of the stored property `name`, excluding its own declaration and every comment line.
    ///
    /// Every mutating form is counted, not just plain assignment: the floor is decremented by
    /// D-G7-01's withdrawal, and a writer that reached it through a compound operator would
    /// otherwise be invisible to the census that claims to name them all.
    static func mutationCount(of name: String, in contents: String) -> Int {
        executableLines(in: contents).reduce(into: 0) { total, line in
            guard line.contains(storedDeclarationPrefix + name) == false else { return }
            for mutation in mutationOperators {
                total += occurrences(of: name + " " + mutation + " ", in: line)
            }
        }
    }

    static func executableLines(in contents: String) -> [String] {
        contents
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter({ $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") == false })
    }

    static func occurrences(of token: String, in text: String) -> Int {
        text.components(separatedBy: token).count - 1
    }
}

// MARK: - Scanning

private extension DownloadSourceInventoryTests {
    /// Every Swift file under the scanned directories except this one.
    ///
    /// **Why this file is excluded, and why the reason is written here.** The exclusion's shape and
    /// its binding name come from `DownloadLogPrivacyInvariantTests.scannedFiles()`, which does the
    /// same thing so that two scanners built from one template stay readable as one pattern. Nothing
    /// else comes from there: that function carries no doc comment, so it implements this decision
    /// without recording it, and the argument below is this suite's own rather than a copy.
    ///
    /// The assembled fragments above remain the FIRST line of defence and this is the second. They
    /// have to: a census counts occurrences, so a token spelled whole here would count itself in
    /// every file it also appears in, and no path filter repairs that. What the exclusion buys is
    /// the one thing fragments cannot. `testNoScannedDocNamesTheSharedReadAsTheSchedulersSoleAuthority`
    /// reads WHOLE FILES rather than executable lines — policing prose is its entire point — so
    /// while this file was in its own scan, the one file whose job is to explain what the retired
    /// claim IS could not spell it out, and the first plainly-worded maintenance edit would have
    /// failed the suite on its own documentation.
    ///
    /// That asymmetry is what made it a scheduled failure rather than a tidy-up: every census
    /// already drops comment lines through `executableLines(in:)`, precisely so a doc describing an
    /// inventory does not become part of it, while the prose assertion deliberately reads past that
    /// filter and went on reading the file that has to describe the rule.
    private static func scannedFiles() throws -> [ScannedFile] {
        let root = try repositoryRoot()
        let fileManager = FileManager.default
        let invariantFilePath = URL(filePath: #filePath).standardizedFileURL.path
        var files = [ScannedFile]()

        for scannedDirectory in scannedDirectories {
            let directory = root.appending(path: scannedDirectory)
            let enumerator = try #require(
                fileManager.enumerator(at: directory, includingPropertiesForKeys: nil)
            )
            for case let url as URL in enumerator
            where url.pathExtension == "swift"
                && url.standardizedFileURL.path != invariantFilePath {
                files.append(
                    ScannedFile(
                        relativePath: repositoryRelativePath(of: url, under: root),
                        contents: try String(contentsOf: url, encoding: .utf8)
                    )
                )
            }
        }
        return files
    }

    /// The client module's own files, which is what every census counts over.
    ///
    /// The walk is wider than the censuses on purpose, and this is the seam that keeps the two
    /// apart. A census counts over the files the scan returns, so a widened scan silently re-bases
    /// every table in this suite unless each one says which tree it means — and one of them really
    /// would have moved: three test-target evaluations of the pending page list are legitimate test
    /// code, not the production duplication that census exists to forbid.
    private static func clientModuleFiles(in files: [ScannedFile]) -> [ScannedFile] {
        files.filter({ $0.relativePath.hasPrefix(clientModuleDirectory + "/") })
    }

    /// The downloads test target's own files.
    ///
    /// The same seam `clientModuleFiles(in:)` is, pointed the other way, and load-bearing for the
    /// same reason: an unscoped census counts over whatever the walk returns, so every table has
    /// to say which tree it means.
    private static func downloadsTestFiles(in files: [ScannedFile]) -> [ScannedFile] {
        files.filter({ $0.relativePath.hasPrefix(downloadsTestDirectory + "/") })
    }

    /// Both trees a hand-built client double can ship in: the downloads test target, and the
    /// processing client's own module — whose `noop` value is a hand-built double under a Test
    /// mark and the coordinator's default client (G-15-36). Scoping the double censuses to the
    /// test target alone is the classification that hid it.
    private static func clientDoubleTreeFiles(in files: [ScannedFile]) -> [ScannedFile] {
        files.filter({ file in
            file.relativePath.hasPrefix(downloadsTestDirectory + "/")
                || file.relativePath.hasPrefix(processingClientModuleDirectory + "/")
        })
    }

    /// The scanned files that build a value of the client type.
    ///
    /// The suspension census's population is derived through this rather than listed, so a new
    /// double's file joins it by existing rather than by being remembered — while the population
    /// census beside it is what makes that new file's arrival fail a build in the first place.
    private static func clientDoubleFiles(in files: [ScannedFile]) -> [ScannedFile] {
        clientDoubleTreeFiles(in: files).filter({ file in
            callSiteCount(of: clientDoubleEndpointToken, in: file.contents) > 0
        })
    }

    /// Whether `contents` states the retired claim in any of its recorded phrasings.
    static func namesTheRetiredClaim(_ contents: String) -> Bool {
        retiredAuthorityPhrases.contains(where: { contents.contains($0) })
    }

    /// Requires every scanned directory to have contributed its named file.
    private static func requireKnownMembers(in files: [ScannedFile]) throws {
        for knownMember in knownMembers {
            try #require(
                files.contains(where: { $0.relativePath == knownMember }),
                "The scan lost its known member \(knownMember); it refuses a vacuous walk."
            )
        }
    }

    static func repositoryRoot() throws -> URL {
        var directory = URL(filePath: #filePath).deletingLastPathComponent()
        var located: URL?

        while located == nil, directory.path != "/" {
            if isRepositoryRoot(directory) {
                located = directory
            } else {
                directory = directory.deletingLastPathComponent()
            }
        }

        return try #require(
            located,
            "Could not locate the repository root; the source census refuses a vacuous scan."
        )
    }

    static func isRepositoryRoot(_ directory: URL) -> Bool {
        let fileManager = FileManager.default
        return repositoryRootMarkers.allSatisfy({ marker in
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(
                atPath: directory.appending(path: marker).path,
                isDirectory: &isDirectory
            )
            return exists && isDirectory.boolValue
        })
    }

    static func repositoryRelativePath(of url: URL, under root: URL) -> String {
        let path = url.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path + "/"
        guard path.hasPrefix(rootPath) else { return path }
        return String(path.dropFirst(rootPath.count))
    }
}
