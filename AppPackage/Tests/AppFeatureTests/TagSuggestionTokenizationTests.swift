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

    // Regression: E-Hentai's `~tag` (OR) and `-tag` (exclude) prefixes made the whole token fail to match
    // any tag, so no suggestion appeared while typing them. The prefix is ignored for matching and put
    // back when the suggestion is chosen.
    @Test(arguments: ["~", "-"])
    func searchPrefixIsIgnoredForMatchingAndKeptOnCompletion(_ prefix: String) throws {
        let translation = TagTranslation(namespace: .female, key: "cat", value: "貓")
        let handler = TagTranslationHandler()
        var keyword = "\(prefix)f:cat"
        handler.analyze(text: &keyword, translations: ["female:cat": translation])

        let suggestion = try #require(handler.suggestions.first)
        #expect(suggestion.originalKeyword == "\(prefix)f:cat")
        #expect(suggestion.tag == translation)

        handler.autoComplete(suggestion: suggestion, keyword: &keyword)
        #expect(keyword == "\(prefix)f:cat$ ")
    }

    @Test(arguments: ["~", "-"])
    func searchPrefixWithoutNamespaceStillMatchesTheKey(_ prefix: String) throws {
        let translation = TagTranslation(namespace: .female, key: "cat", value: "貓")
        let handler = TagTranslationHandler()
        var keyword = "\(prefix)ca"
        handler.analyze(text: &keyword, translations: ["female:cat": translation])

        let suggestion = try #require(handler.suggestions.first)
        #expect(suggestion.tag == translation)

        handler.autoComplete(suggestion: suggestion, keyword: &keyword)
        #expect(keyword == "\(prefix)f:cat$ ")
    }

    @Test
    func searchPrefixAfterEarlierTermsKeepsThoseTerms() throws {
        let translation = TagTranslation(namespace: .female, key: "cat", value: "貓")
        let handler = TagTranslationHandler()
        var keyword = "中文 -f:cat"
        handler.analyze(text: &keyword, translations: ["female:cat": translation])

        let suggestion = try #require(handler.suggestions.first)
        handler.autoComplete(suggestion: suggestion, keyword: &keyword)
        #expect(keyword == "中文 -f:cat$ ")
    }

    @Test
    func tagWithoutPrefixCompletesWithoutOne() throws {
        let translation = TagTranslation(namespace: .female, key: "cat", value: "貓")
        let handler = TagTranslationHandler()
        var keyword = "ca"
        handler.analyze(text: &keyword, translations: ["female:cat": translation])

        let suggestion = try #require(handler.suggestions.first)
        handler.autoComplete(suggestion: suggestion, keyword: &keyword)
        #expect(keyword == "f:cat$ ")
    }

    @Test(arguments: [("-f:cat", "-"), ("~f:cat", "~"), ("~-f:cat", "~-"), ("f:cat", ""), ("", "")])
    func searchPrefixIsTheLeadingOperators(_ term: String, _ expected: String) {
        #expect(TagTranslationHandler.searchPrefix(of: term) == expected)
    }

    // The saved-search editor is a `TextEditor`: its text must not be rewritten while the user types,
    // because rewriting the bound text under a marked (CJK composition) range cancels or corrupts the
    // composition and moves the cursor. Suggestions are therefore read from the text as it is, and the
    // normalisation (double spaces, full-width colons) is applied to what the user typed only when a
    // suggestion is chosen.
    @Test
    func readingSuggestionsNeverNeedsTheTextRewritten() throws {
        let translation = TagTranslation(namespace: .female, key: "cat", value: "貓")
        let handler = TagTranslationHandler()
        handler.analyze(readingText: "f：cat", translations: ["female:cat": translation])

        let suggestion = try #require(handler.suggestions.first)
        #expect(suggestion.tag == translation)
        #expect(suggestion.originalKeyword == "f:cat")
    }

    @Test
    func completingTextThatWasNotRewrittenReplacesTheWholeTypedTerm() throws {
        // A term made of two words, typed with a doubled space the editor left alone.
        let translation = TagTranslation(namespace: .female, key: "big cat", value: "")
        let handler = TagTranslationHandler()
        var text = "中文 big  cat"
        handler.analyze(readingText: text, translations: ["female:big cat": translation])

        let suggestion = try #require(handler.suggestions.first)
        handler.autoComplete(suggestion: suggestion, keyword: &text)
        #expect(text == "中文 " + suggestion.tag.searchKeyword + " ")
    }
}
