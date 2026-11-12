@testable import AppComponents
import AppModels
import Testing

@MainActor
struct TagSuggestionTokenizationTests {
    @Test(arguments: ["location:sch", "LOCATION:sch", "location:"])
    func fullNamespaceWithoutAbbreviationSupportsCompletion(_ input: String) throws {
        let tag = TagTranslation(namespace: .location, key: "school", value: "")
        let handler = TagTranslationHandler()
        var keyword = input
        handler.analyze(text: &keyword, translations: ["locationschool": tag])
        let suggestion = try #require(handler.suggestions.first)
        #expect(suggestion.matchesNamespace)
        handler.autoComplete(suggestion: suggestion, keyword: &keyword)
        #expect(keyword == "location:school$ ")
    }

    @Test(arguments: ["🐼🐼🐼 ", "中文 ", "artist:\"known name\" "])
    func preservesUnicodeAndQuotedTokensDuringCompletion(_ prefix: String) throws {
        let translation = TagTranslation(namespace: .female, key: "cat", value: "貓")
        let handler = TagTranslationHandler()
        var keyword = prefix + "f:cat"
        handler.analyze(text: &keyword, translations: ["female:cat": translation])

        let suggestion = try #require(handler.suggestions.first)
        #expect(suggestion.originalKeyword == "f:cat")
        #expect(suggestion.tag == translation)

        handler.autoComplete(suggestion: suggestion, keyword: &keyword)
        #expect(keyword == prefix + "f:cat$ ")
    }

    @Test
    func normalizesRepeatedSpacesAndFullWidthColons() throws {
        let translation = TagTranslation(namespace: .female, key: "cat", value: "貓")
        let handler = TagTranslationHandler()
        var keyword = "🐼   f：cat"
        handler.analyze(text: &keyword, translations: ["female:cat": translation])

        #expect(keyword == "🐼 f:cat")
        #expect(try #require(handler.suggestions.first).originalKeyword == "f:cat")
    }
}
