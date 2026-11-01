import AppModels
import Foundation
import TagTranslationFeature
import Testing

struct TagDatabaseCompatibilityTests {
    @Test(arguments: ["", " \n\t"])
    func emptyTranslationPreservesOriginalDisplayAndSearch(value: String) {
        let tag = TagTranslation(namespace: .location, key: "school", value: value)
        let translator = TagTranslator(translations: ["locationschool": tag])
        #expect(tag.displayValue == "school")
        #expect(tag.searchKeyword == "location:school$")
        #expect(translator.lookup(word: "location:school", returnOriginal: false).text == "location:school")
        #expect(translator.lookup(word: "locationschool", returnOriginal: false).translation == tag)
        #expect(translator.lookup(word: "location:school", returnOriginal: true).translation == nil)
        let suggestion = tag.getSuggestion(keyword: "sch", originalKeyword: "sch", matchesNamespace: false)
        #expect(suggestion.weight > 0)
        #expect(suggestion.weight.isFinite)
        #expect(suggestion.displayValue == "school")
    }

    @Test
    func linksAloneExposeDetailsWithOriginalTitle() throws {
        let tag = TagTranslation(namespace: .artist, key: "example", value: "", description: "",
                                 linksString: "[profile](https://example.com/profile)")
        let detail = try #require(tag.detail)
        #expect(detail.title == "example")
        #expect(detail.description.isEmpty)
        #expect(detail.links == [URL(string: "https://example.com/profile")])
    }

    @Test
    func imagesAloneExposeDetailsWithoutDuplicates() throws {
        let image = "![sample](https://example.com/sample.png)"
        let tag = TagTranslation(namespace: .other, key: "sample", value: image, description: image)
        #expect(try #require(tag.detail).imageURLs == [URL(string: "https://example.com/sample.png")])
        let valueOnly = TagTranslation(namespace: .other, key: "sample", value: image)
        #expect(try #require(valueOnly.detail).imageURLs == [URL(string: "https://example.com/sample.png")])
    }

    @Test
    func emptyMetadataDoesNotOfferEmptyDetails() {
        let tag = TagTranslation(namespace: .female, key: "glasses", value: "", description: " \n", linksString: "")
        #expect(tag.detail == nil)
    }

    @Test
    func markdownSuggestionUsesRenderedTextRange() {
        let tag = TagTranslation(namespace: .other, key: "example", value: "![icon](https://example.com/i.png) 眼鏡")
        let suggestion = tag.getSuggestion(keyword: "眼鏡", originalKeyword: "眼鏡", matchesNamespace: false)
        #expect(suggestion.weight > 0)
        #expect(suggestion.displayValue.contains("[眼鏡]("))
        #expect(suggestion.displayValue.contains("example.com") == false)
    }

    @Test
    func untranslatedAndJapaneseValuesShareSearchSyntax() {
        let tag = TagTranslation(namespace: .female, key: "glasses", value: "眼鏡")
        #expect(tag.getSuggestion(keyword: "眼鏡", originalKeyword: "眼鏡", matchesNamespace: false).weight > 0)
        #expect(tag.searchKeyword == "f:glasses$")
        #expect(TagTranslator(translations: ["femaleglasses": tag])
            .lookup(word: "female:glasses", returnOriginal: false).text == "female:眼鏡")
    }
}
