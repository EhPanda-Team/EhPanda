import AppModels
import Foundation
@testable import LiveTextTranslation
import Testing

// A recognized group reaches translation as one piece of text, joined the way its language writes
// it, and all-caps lettering is sentence-cased when the translation's script has letter case.
struct LiveTextSourceTextTests {
    private static let englishToGerman = LiveTextLanguagePair(
        source: .init(identifier: "en"),
        target: .init(identifier: "de")
    )
    private static let englishToJapanese = LiveTextLanguagePair(
        source: .init(identifier: "en"),
        target: .init(identifier: "ja")
    )

    private static func group(_ lines: [String]) throws -> LiveTextGroup {
        let blocks = lines.enumerated().map { number, line in
            let top = 0.1 + Double(number) * 0.05
            return LiveTextBlock(
                text: line,
                bounds: LiveTextBounds(
                    topLeft: .init(x: 0.1, y: top),
                    topRight: .init(x: 0.5, y: top),
                    bottomLeft: .init(x: 0.1, y: top + 0.04),
                    bottomRight: .init(x: 0.5, y: top + 0.04)
                )
            )
        }
        return try #require(LiveTextGroup(blocks: blocks))
    }

    @Test(arguments: [
        (lines: ["WHERE ARE", "YOU GOING?"], text: "WHERE ARE YOU GOING?"),
        (lines: ["どこに", "行くの？"], text: "どこに行くの？"),
        (lines: ["你要", "去哪裡？"], text: "你要去哪裡？"),
        (lines: ["어디", "가는 거야?"], text: "어디 가는 거야?"),
        (lines: ["I CAN'T BE-", "LIEVE IT"], text: "I CAN'T BELIEVE IT"),
        (lines: ["you can't be-", "lieve it"], text: "you can't believe it"),
        (lines: ["Spider-", "Man is here"], text: "Spider-Man is here"),
        (lines: ["WAIT -", "NO!"], text: "WAIT - NO!"),
        (lines: ["  so   much ", "", "space "], text: "so much space")
    ])
    func linesJoinAsTheirLanguageWritesThem(lines: [String], text: String) throws {
        let source = try #require(LiveTextSourceText(group: Self.group(lines)))

        #expect(source.text == text)
    }

    @Test(arguments: [["!!"], ["...", "?!"], ["12"], ["♥ ♥"]])
    func aGroupWithoutALetterHasNothingToTranslate(lines: [String]) throws {
        #expect(LiveTextSourceText(group: try Self.group(lines)) == nil)
    }

    @Test
    func theTextKeepsItsGroup() throws {
        let group = try Self.group(["Hello"])

        #expect(LiveTextSourceText(group: group)?.groupID == group.id)
    }

    @Test(arguments: [
        (text: "WHERE DO YOU THINK YOU'RE GOING? I TOLD YOU TO STAY HERE!",
         prepared: "Where do you think you're going? I told you to stay here!"),
        (text: "I'M NOT SURE... I'LL GO.", prepared: "I'm not sure... I'll go."),
        (text: "WAIT!! WHAT?", prepared: "Wait!! What?"),
        (text: "HELLO, WORLd", prepared: "Hello, world")
    ])
    func allCapsLetteringIsSentenceCasedForACasedScript(text: String, prepared: String) {
        let source = LiveTextSourceText(groupID: UUID(), text: text)

        #expect(source.prepared(for: Self.englishToGerman).text == prepared)
    }

    @Test
    func allCapsLetteringStaysForAScriptWithoutCase() {
        let source = LiveTextSourceText(groupID: UUID(), text: "WHERE ARE YOU GOING?")

        #expect(source.prepared(for: Self.englishToJapanese) == source)
    }

    @Test(arguments: ["Where are you going?", "OK", "NASA said so", "どこに行くの？"])
    func otherTextIsUnchanged(text: String) {
        let source = LiveTextSourceText(groupID: UUID(), text: text)

        #expect(source.prepared(for: Self.englishToGerman) == source)
    }

    @Test
    func onlyEnglishCapitalizesThePronounI() {
        let italian = LiveTextLanguagePair(source: .init(identifier: "it"), target: .init(identifier: "de"))
        let source = LiveTextSourceText(groupID: UUID(), text: "SONO I MIEI AMICI")

        #expect(source.prepared(for: italian).text == "Sono i miei amici")
    }
}
