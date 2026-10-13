import Foundation
@testable import LiveTextTranslation
import Testing
import Translation

// A page is translated from its gallery's language, or the language its text is written in, into the
// reader's most preferred language; a page already in that language is left as it is.
struct LiveTextLanguageResolverTests {
    private static let english = Locale.Language(identifier: "en")

    private static func texts(_ texts: String...) -> [LiveTextSourceText] {
        texts.map({ LiveTextSourceText(groupID: UUID(), text: $0) })
    }

    /// A client for `preferred` readers whose device answers `status` for every pair, except the ones
    /// `statuses` names by their target's language code.
    private static func client(
        preferred: [String],
        status: LanguageAvailability.Status = .installed,
        statuses: [String: LanguageAvailability.Status] = [:]
    ) -> LiveTextTranslationClient {
        LiveTextTranslationClient(
            preferredLanguages: {
                preferred.map(Locale.Language.init(identifier:))
            },
            availability: { _, target in
                statuses[target.languageCode?.identifier ?? ""] ?? status
            },
            translate: { _, _ in
                Issue.record("Resolving a route translates nothing.")
                return [:]
            }
        )
    }

    @Test
    func aGalleryLanguageNamesTheSource() async {
        let route = await LiveTextLanguageResolver.route(
            for: Self.texts("Where are you going?"),
            candidates: [.init(identifier: "ja-JP")],
            client: Self.client(preferred: ["en-US"])
        )

        #expect(route == .translate(.init(source: .init(identifier: "ja-JP"), target: .init(identifier: "en-US"))))
    }

    @Test(arguments: [
        (text: "你要去哪裡？我們今天在這裡吃飯吧。", script: "Hant"),
        (text: "你要去哪里？我们今天在这里吃饭吧。", script: "Hans")
    ])
    func theTextChoosesAmongTheGallerysScripts(text: String, script: String) async throws {
        let route = await LiveTextLanguageResolver.route(
            for: Self.texts(text),
            candidates: [.init(identifier: "zh-Hans"), .init(identifier: "zh-Hant")],
            client: Self.client(preferred: ["ja-JP"])
        )

        guard case .translate(let pair) = route else {
            Issue.record("Expected a translation, got \(route)")
            return
        }
        #expect(pair.source.script?.identifier == script)
    }

    @Test
    func withoutAGalleryLanguageTheTextNamesTheSource() async {
        let route = await LiveTextLanguageResolver.route(
            for: Self.texts("Où est-ce que tu vas ? Je t'ai dit de rester ici avec nous."),
            candidates: [],
            client: Self.client(preferred: ["en-US"])
        )

        #expect(route == .translate(.init(source: .init(identifier: "fr"), target: .init(identifier: "en-US"))))
    }

    @Test
    func aTextWithoutLanguageAndWithoutAGalleryLanguageIsUnidentified() async {
        let route = await LiveTextLanguageResolver.route(
            for: Self.texts("\u{2665}", "!?"),
            candidates: [],
            client: Self.client(preferred: ["en-US"])
        )

        #expect(route == .failed(.unidentifiedLanguage))
    }

    @Test(arguments: ["en-US", "en-GB", "en"])
    func aPageInTheReadersLanguageIsLeftAsItIs(preferred: String) async {
        let route = await LiveTextLanguageResolver.route(
            for: Self.texts("Where are you going?"),
            candidates: [.init(identifier: "en-US")],
            client: Self.client(preferred: [preferred, "ja-JP"])
        )

        #expect(route == .untranslated)
    }

    @Test
    func aPairWithoutModelsIsDownloadedFirst() async {
        let route = await LiveTextLanguageResolver.route(
            for: Self.texts("Where are you going?"),
            candidates: [.init(identifier: "en-US")],
            client: Self.client(preferred: ["ja-JP"], status: .supported)
        )

        #expect(route == .download(.init(source: .init(identifier: "en-US"), target: .init(identifier: "ja-JP"))))
    }

    @Test
    func anUnsupportedTargetFallsBackToTheNextPreferredLanguage() async {
        let route = await LiveTextLanguageResolver.route(
            for: Self.texts("Where are you going?"),
            candidates: [.init(identifier: "en-US")],
            client: Self.client(preferred: ["yue-HK", "en-GB", "ja-JP"], statuses: ["yue": .unsupported])
        )

        #expect(route == .translate(.init(source: .init(identifier: "en-US"), target: .init(identifier: "ja-JP"))))
    }

    @Test
    func noSupportedTargetFailsWithTheMostPreferredOne() async {
        let route = await LiveTextLanguageResolver.route(
            for: Self.texts("Where are you going?"),
            candidates: [Self.english],
            client: Self.client(preferred: ["yue-HK", "ja-JP"], status: .unsupported)
        )

        #expect(route == .failed(.unsupportedLanguages(source: Self.english, target: .init(identifier: "yue-HK"))))
    }

    @Test(arguments: [
        (language: "en-US", other: "en-GB", reads: true),
        (language: "zh-Hans", other: "zh-Hant", reads: false),
        (language: "zh-Hant-TW", other: "zh-Hant", reads: true),
        (language: "ja-JP", other: "ja", reads: true),
        (language: "pt-BR", other: "es", reads: false)
    ])
    func languagesReadAlikeByLanguageAndScript(language: String, other: String, reads: Bool) {
        #expect(Locale.Language(identifier: language).reads(as: .init(identifier: other)) == reads)
    }

    @Test(arguments: [
        (language: "de", writesInCase: true),
        (language: "ru", writesInCase: true),
        (language: "ja", writesInCase: false),
        (language: "zh-Hant", writesInCase: false),
        (language: "ko", writesInCase: false),
        (language: "ar", writesInCase: false)
    ])
    func scriptsWithLetterCase(language: String, writesInCase: Bool) {
        #expect(Locale.Language(identifier: language).writesInCase == writesInCase)
    }
}
