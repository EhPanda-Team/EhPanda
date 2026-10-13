import AppModels
import CoreGraphics
import Dependencies
import Foundation
@testable import LiveTextTranslation
import Testing
import Translation

// Live Text translates each recognized page once into the reader's language, waits for the system's
// download when the models are missing, keeps the highlight on pages it cannot or need not translate,
// and tells each kind of failure once while Live Text stays on.
@MainActor
struct LiveTextTranslatorTests {
    private nonisolated static let english = Locale.Language(identifier: "en")
    private nonisolated static let japanese = Locale.Language(identifier: "ja")
    private nonisolated static let englishToJapanese = LiveTextLanguagePair(source: english, target: japanese)

    private struct TranslationFailed: Error {}

    /// What the translator asked the client to translate, in order.
    private final class Requests: Sendable {
        let pairs = LockIsolated([LiveTextLanguagePair]())
        let texts = LockIsolated([[String]]())
    }

    /// A translator for a Japanese reader whose device answers `status` for every pair and whose
    /// translations are `translate`'s, recording each request in `requests`.
    private static func translator(
        preferred: [Locale.Language] = [japanese],
        status: LanguageAvailability.Status = .installed,
        requests: Requests = Requests(),
        translate: @escaping @Sendable (String) throws -> String = { "訳: \($0)" }
    ) -> LiveTextTranslator {
        withDependencies {
            $0.liveTextTranslationClient = LiveTextTranslationClient(
                preferredLanguages: { preferred },
                availability: { _, _ in status },
                translate: { texts, pair in
                    requests.pairs.withValue({ $0.append(pair) })
                    requests.texts.withValue({ $0.append(texts.map(\.text)) })
                    return try Dictionary(
                        texts.map({ ($0.groupID, try translate($0.text)) }),
                        uniquingKeysWith: { first, _ in first }
                    )
                }
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
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
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

    private static func translate(
        _ groups: [LiveTextGroup],
        page: Int,
        with translator: LiveTextTranslator,
        in recognitionLanguages: [String]? = ["en-US"]
    ) async throws {
        translator.translate(groups, on: try image(), page: page, recognitionLanguages: recognitionLanguages)
        await translator.waitForTranslations()
    }

    @Test
    func anInstalledPairTranslatesThePage() async throws {
        let requests = Requests()
        let translator = Self.translator(requests: requests)
        let groups = try Self.groups("Where are you going?", "I told you to stay here!")

        try await Self.translate(groups, page: 3, with: translator)

        let page = try #require(translator.translatedPage(of: groups))
        #expect(translator.translatedPages == [3: page])
        #expect(page.groups.map(\.text) == ["訳: Where are you going?", "訳: I told you to stay here!"])
        #expect(page.language == Self.japanese)
        #expect(requests.pairs.value == [.init(source: .init(identifier: "en-US"), target: Self.japanese)])
        #expect(!translator.needsTranslation(page: 3))
        #expect(translator.failure == nil)
    }

    @Test
    func eachPageIsTranslatedOnce() async throws {
        let requests = Requests()
        let translator = Self.translator(requests: requests)
        let groups = try Self.groups("Where are you going?")

        try await Self.translate(groups, page: 3, with: translator)
        try await Self.translate(groups, page: 3, with: translator)

        #expect(requests.texts.value == [["Where are you going?"]])
    }

    @Test
    func aMissingModelWaitsForTheDownloadThenTranslates() async throws {
        let requests = Requests()
        let translator = Self.translator(status: .supported, requests: requests)
        let groups = try Self.groups("Where are you going?")

        try await Self.translate(groups, page: 3, with: translator, in: nil)

        #expect(translator.download == Self.englishToJapanese)
        #expect(translator.translatedPages.isEmpty)
        #expect(!translator.needsTranslation(page: 3))
        #expect(requests.pairs.value.isEmpty)

        translator.finishDownload(of: Self.englishToJapanese, succeeded: true)
        await translator.waitForTranslations()

        #expect(translator.download == nil)
        #expect(translator.translatedPage(of: groups)?.groups.map(\.text) == ["訳: Where are you going?"])
        #expect(requests.pairs.value == [Self.englishToJapanese])
    }

    @Test
    func aDeclinedDownloadKeepsItsPagesUntilLiveTextIsTurnedOnAgain() async throws {
        let translator = Self.translator(status: .supported)

        try await Self.translate(try Self.groups("Where are you going?"), page: 3, with: translator, in: nil)
        translator.finishDownload(of: Self.englishToJapanese, succeeded: false)
        try await Self.translate(try Self.groups("Stay here!"), page: 4, with: translator, in: nil)

        // The declined pair is not offered again while Live Text stays on.
        #expect(translator.download == nil)
        #expect(!translator.needsTranslation(page: 3))
        #expect(!translator.needsTranslation(page: 4))
        #expect(translator.failure == nil)

        translator.endActivation()

        #expect(translator.needsTranslation(page: 3))
        #expect(translator.needsTranslation(page: 4))
    }

    @Test
    func aDownloadThatFinishesForAnotherPairChangesNothing() async throws {
        let translator = Self.translator(status: .supported)

        try await Self.translate(try Self.groups("Where are you going?"), page: 3, with: translator, in: nil)
        translator.finishDownload(of: .init(source: .init(identifier: "fr"), target: Self.japanese), succeeded: false)

        #expect(translator.download == Self.englishToJapanese)
    }

    @Test
    func turningLiveTextOffDropsAWaitingDownload() async throws {
        let translator = Self.translator(status: .supported)

        try await Self.translate(try Self.groups("Where are you going?"), page: 3, with: translator, in: nil)
        translator.endActivation()

        #expect(translator.download == nil)
        #expect(translator.needsTranslation(page: 3))
    }

    @Test
    func aPageInTheReadersLanguageKeepsTheHighlight() async throws {
        let requests = Requests()
        let translator = Self.translator(preferred: [.init(identifier: "en-GB")], requests: requests)

        try await Self.translate(try Self.groups("Where are you going?"), page: 3, with: translator)
        translator.endActivation()

        #expect(translator.translatedPages.isEmpty)
        #expect(!translator.needsTranslation(page: 3))
        #expect(requests.pairs.value.isEmpty)
        #expect(translator.failure == nil)
    }

    @Test
    func aPageWithoutLettersKeepsTheHighlight() async throws {
        let requests = Requests()
        let translator = Self.translator(requests: requests)

        try await Self.translate(try Self.groups("!?", "123"), page: 3, with: translator)

        #expect(translator.translatedPages.isEmpty)
        #expect(!translator.needsTranslation(page: 3))
        #expect(requests.pairs.value.isEmpty)
    }

    @Test
    func aPageWhoseTranslationsReadAsItsLetteringKeepsTheHighlight() async throws {
        let translator = Self.translator(translate: { $0 })

        try await Self.translate(try Self.groups("NASA", "OK"), page: 3, with: translator)

        #expect(translator.translatedPages.isEmpty)
        #expect(!translator.needsTranslation(page: 3))
    }

    @Test
    func anUntranslatablePairIsToldOncePerActivation() async throws {
        let translator = Self.translator(status: .unsupported)

        try await Self.translate(try Self.groups("Where are you going?"), page: 3, with: translator)
        let english = Locale.Language(identifier: "en-US")
        #expect(translator.takeFailure() == .unsupportedLanguages(source: english, target: Self.japanese))
        #expect(translator.takeFailure() == nil)

        try await Self.translate(try Self.groups("Stay here!"), page: 4, with: translator)
        #expect(translator.failure == nil)

        translator.endActivation()
        // The pair stays untranslatable, so its pages are not tried again; a new page tells it again.
        #expect(!translator.needsTranslation(page: 3))
        try await Self.translate(try Self.groups("Wait!"), page: 5, with: translator)
        #expect(translator.failure?.kind == .unsupportedLanguages)
    }

    @Test
    func aFailedTranslationIsToldAndTriedAgainNextTime() async throws {
        let translator = Self.translator(translate: { _ in throw TranslationFailed() })

        try await Self.translate(try Self.groups("Where are you going?"), page: 3, with: translator)

        #expect(translator.failure == .translationFailed)
        #expect(translator.translatedPages.isEmpty)
        #expect(!translator.needsTranslation(page: 3))

        translator.endActivation()

        #expect(translator.failure == nil)
        #expect(translator.needsTranslation(page: 3))
    }

    @Test
    func cancellingStopsTranslationsSoTheyStartAgainLater() async throws {
        let translator = withDependencies {
            $0.liveTextTranslationClient = LiveTextTranslationClient(
                preferredLanguages: { [Self.japanese] },
                availability: { _, _ in .installed },
                translate: { _, _ in
                    try await Task.sleep(for: .seconds(3600))
                    return [:]
                }
            )
        } operation: {
            LiveTextTranslator()
        }

        let groups = try Self.groups("Where are you going?")
        translator.translate(groups, on: try Self.image(), page: 3, recognitionLanguages: nil)
        #expect(!translator.needsTranslation(page: 3))
        translator.cancel()
        await translator.waitForTranslations()

        #expect(translator.needsTranslation(page: 3))
        #expect(translator.translatedPages.isEmpty)
        #expect(translator.failure == nil)
    }
}
