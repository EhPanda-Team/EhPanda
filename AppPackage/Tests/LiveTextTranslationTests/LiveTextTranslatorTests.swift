import AppModels
import CoreGraphics
import Dependencies
import Foundation
@testable import LiveTextTranslation
import Observation
import Testing
import Translation

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LiveTextTranslatorTests {
    private static let japanese = Locale.Language(identifier: "ja")
    private struct TranslationFailed: Error {}

    private static func translator(
        preferred: [Locale.Language] = [japanese],
        status: LanguageAvailability.Status = .installed
    ) -> LiveTextTranslator {
        withDependencies {
            $0.liveTextTranslationClient = LiveTextTranslationClient(
                preferredLanguages: { preferred },
                availability: { _, _ in status }
            )
        } operation: {
            LiveTextTranslator()
        }
    }

    /// A white page.
    private static func image() throws -> CGImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil,
            width: 1000,
            height: 1400,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGBitmapInfo(alpha: .premultipliedLast).rawValue
        ))
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1000, height: 1400))
        return try #require(context.makeImage())
    }

    /// A page's groups, one a level line of each of `lines`, stacked down the page.
    private static func groups(_ lines: String...) throws -> [LiveTextGroup] {
        try lines.enumerated().map { number, line in
            let top = 0.1 + Double(number) * 0.1
            return try #require(LiveTextGroup(blocks: [
                LiveTextBlock(
                    text: line,
                    bounds: LiveTextBounds(
                        topLeft: CGPoint(x: 0.1, y: top),
                        topRight: CGPoint(x: 0.6, y: top),
                        bottomLeft: CGPoint(x: 0.1, y: top + 0.04),
                        bottomRight: CGPoint(x: 0.6, y: top + 0.04)
                    )
                )
            ]))
        }
    }

    /// Hands `line`, recognized in English as `page`, to `translator` without waiting for its translation.
    private static func queue(_ line: String, page: Int, with translator: LiveTextTranslator) throws {
        translator.translate(try groups(line), on: try image(), page: page, recognitionLanguages: ["en-US"])
    }

    /// Consumes exactly the page the view's worker would receive, after language resolution.
    private static func next(
        _ translator: LiveTextTranslator
    ) async throws -> (work: LiveTextTranslationWork, batch: LiveTextTranslationBatch) {
        await translator.waitForTranslations()
        let work = try #require(translator.session)
        var iterator = work.requests.makeAsyncIterator()
        return (work, try #require(await iterator.next()))
    }

    private static func complete(
        _ translator: LiveTextTranslator,
        with translation: (String) -> String = { "訳: \($0)" }
    ) async throws -> [String] {
        let (work, batch) = try await next(translator)
        let translations = Dictionary(
            batch.sources.map({ ($0.groupID, translation($0.text)) }),
            uniquingKeysWith: { first, _ in first }
        )
        translator.finish(batch, in: work.id, with: .success(translations))
        await translator.waitForTranslations()
        return batch.sources.map(\.text)
    }

    @Test(arguments: [LanguageAvailability.Status.installed, .supported])
    func aSupportedPairUsesTheViewSession(status: LanguageAvailability.Status) async throws {
        let translator = Self.translator(status: status)
        let groups = try Self.groups("Where are you going?", "I told you to stay here!")
        translator.translate(groups, on: try Self.image(), page: 3, recognitionLanguages: ["en-US"])
        _ = try await Self.complete(translator)

        let page = try #require(translator.translatedPage(of: groups))
        #expect(page.groups.map(\.text) == ["訳: Where are you going?", "訳: I told you to stay here!"])
        #expect(page.language == Self.japanese)
        #expect(translator.session?.pair.source == Locale.Language(identifier: "en-US"))
        #expect(translator.needsTranslation(page: 3) == false)
        #expect(translator.failure == nil)
    }

    @Test
    func aPageLookedUpBeforeTranslationIsToldOfItsTranslation() async throws {
        let translator = Self.translator()
        let groups = try Self.groups("Where are you going?")
        let changed = LockIsolated(false)
        withObservationTracking {
            _ = translator.translatedPage(of: groups)
        } onChange: {
            changed.setValue(true)
        }
        translator.translate(groups, on: try Self.image(), page: 3, recognitionLanguages: ["en-US"])
        _ = try await Self.complete(translator)
        #expect(changed.value)
        #expect(translator.translatedPage(of: groups) != nil)
    }

    @Test
    func eachPageIsTranslatedOnceAndCompletedPagesSurviveReactivation() async throws {
        let translator = Self.translator()
        try Self.queue("Where are you going?", page: 3, with: translator)
        _ = try await Self.complete(translator)
        translator.endActivation()
        try Self.queue("Where are you going?", page: 3, with: translator)
        await translator.waitForTranslations()
        #expect(translator.session == nil)
        #expect(translator.translatedPages.keys.sorted() == [3])
    }

    @Test
    func pagesAreTranslatedOneAtATimeNearestTheReadingPageFirst() async throws {
        let translator = Self.translator()
        translator.readingPage = 8
        for page in [1, 5, 9, 12, 7] {
            try Self.queue("Page \(page)", page: page, with: translator)
        }
        var texts = [String]()
        for _ in 0..<5 {
            texts += try await Self.complete(translator)
        }
        #expect(texts == ["Page 1", "Page 9", "Page 7", "Page 5", "Page 12"])
        #expect(translator.translatedPages.keys.sorted() == [1, 5, 7, 9, 12])
    }

    @Test
    func theNextPageIsNotDispatchedUntilTheCurrentPageFinishes() async throws {
        let translator = Self.translator()
        try Self.queue("First page", page: 1, with: translator)
        try Self.queue("Second page", page: 2, with: translator)
        let (work, first) = try await Self.next(translator)
        let next = Task {
            var iterator = work.requests.makeAsyncIterator()
            return await iterator.next()
        }
        await translator.waitForTranslations()
        // Ending the session without completing the first request must leave no second request.
        translator.endActivation()
        #expect(await next.value == nil)
        translator.finish(first, in: work.id, with: .success([:]))
        #expect(translator.translatedPages.isEmpty)
        #expect(translator.needsTranslation(page: 1))
        #expect(translator.needsTranslation(page: 2))
    }

    @Test
    func theQueueFollowsTheReaderToItsNewPage() async throws {
        let translator = Self.translator()
        translator.readingPage = 2
        for page in [1, 3, 10, 11] {
            try Self.queue("Page \(page)", page: page, with: translator)
        }
        translator.readingPage = 12
        var texts = [String]()
        for _ in 0..<4 {
            texts += try await Self.complete(translator)
        }
        #expect(texts == ["Page 1", "Page 11", "Page 10", "Page 3"])
    }

    @Test
    func aLatePageReusesTheIdleSessionEvenWhenAvailabilityStillSaysSupported() async throws {
        let translator = Self.translator(status: .supported)
        try Self.queue("First page", page: 1, with: translator)
        _ = try await Self.complete(translator)
        let work = try #require(translator.session)
        let configuration = translator.configuration
        let waiting = Task {
            var iterator = work.requests.makeAsyncIterator()
            return await iterator.next()
        }
        try Self.queue("Later page", page: 2, with: translator)
        let batch = try #require(await waiting.value)
        #expect(batch.sources.map(\.text) == ["Later page"])
        #expect(translator.session?.id == work.id)
        #expect(translator.configuration == configuration)
        translator.finish(batch, in: work.id, with: .success([:]))
        translator.endActivation()
    }

    @Test
    func rapidReactivationRejectsOldResultsAndChangesTheConfiguration() async throws {
        let translator = Self.translator()
        try Self.queue("First page", page: 1, with: translator)
        let (oldWork, oldBatch) = try await Self.next(translator)
        let oldConfiguration = translator.configuration
        translator.endActivation()
        try Self.queue("First page", page: 1, with: translator)
        let (newWork, newBatch) = try await Self.next(translator)
        #expect(newWork.id != oldWork.id)
        #expect(translator.configuration != oldConfiguration)

        let oldTranslations = Dictionary(uniqueKeysWithValues: oldBatch.sources.map({ ($0.groupID, "Old result") }))
        translator.finish(oldBatch, in: oldWork.id, with: .success(oldTranslations))
        translator.sessionEnded(oldWork.id)
        #expect(translator.session?.id == newWork.id)
        #expect(translator.translatedPages.isEmpty)
        #expect(translator.failure == nil)
        translator.finish(newBatch, in: newWork.id, with: .success([:]))
        await translator.waitForTranslations()
        #expect(translator.needsTranslation(page: 1) == false)
    }

    @Test
    func switchingLanguagePairsEndsTheOldStreamWithoutCancellingTheNewOne() async throws {
        let translator = Self.translator()
        try Self.queue("First page", page: 1, with: translator)
        _ = try await Self.complete(translator)
        let oldWork = try #require(translator.session)
        translator.translate(
            try Self.groups("Bonjour le monde"), on: try Self.image(), page: 2, recognitionLanguages: ["fr"]
        )
        let (newWork, batch) = try await Self.next(translator)
        var oldIterator = oldWork.requests.makeAsyncIterator()
        #expect(await oldIterator.next() == nil)
        #expect(newWork.pair.source == Locale.Language(identifier: "fr"))
        translator.sessionEnded(oldWork.id)
        #expect(translator.session?.id == newWork.id)
        translator.finish(batch, in: newWork.id, with: .success([:]))
        await translator.waitForTranslations()
        #expect(translator.needsTranslation(page: 2) == false)
    }

    @Test
    func anUnexpectedWorkerExitMakesItsUnfinishedPagesRetryable() async throws {
        let translator = Self.translator()
        try Self.queue("First page", page: 1, with: translator)
        try Self.queue("Second page", page: 2, with: translator)
        let (work, _) = try await Self.next(translator)
        translator.sessionEnded(work.id)
        #expect(translator.session == nil)
        #expect(translator.needsTranslation(page: 1))
        #expect(translator.needsTranslation(page: 2))
        try Self.queue("First page", page: 1, with: translator)
        _ = try await Self.complete(translator)
        #expect(translator.translatedPages.keys.sorted() == [1])
    }

    @Test
    func turningOffDuringLanguageResolutionCannotStartASessionLater() async throws {
        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<LanguageAvailability.Status>.makeStream()
        let translator = withDependencies {
            $0.liveTextTranslationClient = LiveTextTranslationClient(
                preferredLanguages: { [Locale.Language(identifier: "ja")] },
                availability: { _, _ in
                    started.continuation.yield(())
                    var iterator = release.stream.makeAsyncIterator()
                    return await iterator.next() ?? .supported
                }
            )
        } operation: {
            LiveTextTranslator()
        }
        try Self.queue("First page", page: 1, with: translator)
        var iterator = started.stream.makeAsyncIterator()
        _ = await iterator.next()
        // Attach a waiter before cancellation clears the coordinator's task handle, so the
        // assertion observes the cancelled resolution's completion, not just its cancellation.
        let waiting = AsyncStream<Void>.makeStream()
        let resolution = Task {
            waiting.continuation.yield(())
            await translator.waitForTranslations()
        }
        var waitIterator = waiting.stream.makeAsyncIterator()
        _ = await waitIterator.next()
        translator.endActivation()
        release.continuation.yield(.supported)
        release.continuation.finish()
        started.continuation.finish()
        waiting.continuation.finish()
        await resolution.value
        #expect(translator.session == nil)
        #expect(translator.needsTranslation(page: 1))
    }

    @Test
    func aDeclinedPairIsDeferredUntilReactivationWithoutBlockingOtherLanguages() async throws {
        let translator = Self.translator(status: .supported)
        try Self.queue("First page", page: 1, with: translator)
        try Self.queue("Second page", page: 2, with: translator)
        let (work, batch) = try await Self.next(translator)
        translator.finish(batch, in: work.id, with: .failure(CocoaError(.userCancelled)))
        await translator.waitForTranslations()
        #expect(translator.takeFailure() == nil)
        #expect(translator.session == nil)
        #expect(translator.needsTranslation(page: 2) == false)
        try Self.queue("Later page", page: 3, with: translator)
        await translator.waitForTranslations()
        #expect(translator.session == nil)
        #expect(translator.failure == nil)

        translator.translate(
            try Self.groups("Bonjour le monde"), on: try Self.image(), page: 4, recognitionLanguages: ["fr"]
        )
        _ = try await Self.complete(translator)
        translator.endActivation()
        #expect(translator.needsTranslation(page: 1))
        #expect(translator.needsTranslation(page: 2))
        #expect(translator.needsTranslation(page: 3))
        #expect(translator.needsTranslation(page: 4) == false)
        try Self.queue("First page", page: 1, with: translator)
        _ = try await Self.complete(translator)
        #expect(translator.translatedPages.keys.sorted() == [1, 4])
    }

    @Test
    func unavailableModelsDeferThePairAndRejectItsLateCompletion() async throws {
        let translator = Self.translator(status: .supported)
        try Self.queue("First page", page: 1, with: translator)
        try Self.queue("Second page", page: 2, with: translator)
        let (work, batch) = try await Self.next(translator)
        translator.modelsUnavailable(in: work.id, with: TranslationFailed())
        await translator.waitForTranslations()
        #expect(translator.session == nil)
        #expect(translator.failure == nil)
        #expect(translator.needsTranslation(page: 1) == false)
        #expect(translator.needsTranslation(page: 2) == false)
        translator.endActivation()
        try Self.queue("First page", page: 1, with: translator)
        let (nextWork, nextBatch) = try await Self.next(translator)
        translator.modelsUnavailable(in: work.id, with: TranslationFailed())
        translator.finish(batch, in: work.id, with: .success([:]))
        #expect(translator.session?.id == nextWork.id)
        translator.finish(nextBatch, in: nextWork.id, with: .success([:]))
        await translator.waitForTranslations()
        #expect(translator.needsTranslation(page: 1) == false)
    }

    @Test
    func aFailedPageDoesNotBlockTheNextPageAndIsRetriedAfterReactivation() async throws {
        let translator = Self.translator()
        try Self.queue("First page", page: 1, with: translator)
        try Self.queue("Second page", page: 2, with: translator)
        let (work, batch) = try await Self.next(translator)
        translator.finish(batch, in: work.id, with: .failure(TranslationFailed()))
        #expect(translator.takeFailure() == .translationFailed)
        #expect(try await Self.complete(translator) == ["Second page"])
        #expect(translator.session?.id == work.id)
        #expect(translator.needsTranslation(page: 1) == false)
        translator.endActivation()
        #expect(translator.needsTranslation(page: 1))
        try Self.queue("First page", page: 1, with: translator)
        _ = try await Self.complete(translator)
        #expect(translator.translatedPages.keys.sorted() == [1, 2])
    }

    @Test
    func theReadersLanguageAndPagesWithoutLettersKeepTheirHighlights() async throws {
        let translator = Self.translator(preferred: [.init(identifier: "en-GB")])
        try Self.queue("Where are you going?", page: 1, with: translator)
        try Self.queue("!? 123", page: 2, with: translator)
        await translator.waitForTranslations()
        translator.endActivation()
        #expect(translator.session == nil)
        #expect(translator.translatedPages.isEmpty)
        #expect(translator.needsTranslation(page: 1) == false)
        #expect(translator.needsTranslation(page: 2) == false)
    }

    @Test
    func identityTranslationsKeepTheHighlight() async throws {
        let translator = Self.translator()
        try Self.queue("NASA", page: 1, with: translator)
        _ = try await Self.complete(translator, with: { $0 })
        #expect(translator.translatedPages.isEmpty)
        #expect(translator.needsTranslation(page: 1) == false)
    }

    @Test
    func unsupportedLanguagesAreReportedOncePerActivation() async throws {
        let translator = Self.translator(status: .unsupported)
        try Self.queue("First page", page: 1, with: translator)
        await translator.waitForTranslations()
        #expect(translator.takeFailure()?.kind == .unsupportedLanguages)
        try Self.queue("Second page", page: 2, with: translator)
        await translator.waitForTranslations()
        #expect(translator.failure == nil)
        translator.endActivation()
        #expect(translator.needsTranslation(page: 1) == false)
        try Self.queue("Third page", page: 3, with: translator)
        await translator.waitForTranslations()
        #expect(translator.takeFailure()?.kind == .unsupportedLanguages)
    }
}
