@testable import AppComponents
import AppModels
import Testing
import TestingSupport

// The rows under My Tags' Add Tag field (G-1 of quick 261126-wzg): the site's suggestions first, in the site's order,
// then the local translations' matches the site did not list; an alias row puts its canonical tag in the field and
// names the alias. The tags and their translations are invented.
@Suite(.isolatedAppStorage)
struct TagNameSuggestionTests {
    private static let glasses = SiteTagSuggestion(
        id: 9001, tag: SiteTag(namespace: .female, name: "sample glasses"), canonical: nil
    )
    private static let frames = SiteTagSuggestion(
        id: 9002,
        tag: SiteTag(namespace: .female, name: "sample glass frames"),
        canonical: SiteTag(namespace: .female, name: "sample spectacles")
    )

    @Test
    func theSitesRowsComeFirstAndATranslationMatchTheyListIsLeftOut() {
        let listed = TagTranslation(namespace: .female, key: "sample glasses", value: "Translated Sample Glasses")
        let unlisted = TagTranslation(namespace: .female, key: "sample glassware", value: "Translated Sample Glassware")
        let matches = [
            TagSuggestion(tag: listed, weight: 2, originalKeyword: "sample gl", matchesNamespace: false),
            TagSuggestion(tag: unlisted, weight: 1, originalKeyword: "sample gl", matchesNamespace: false)
        ]

        let rows = TagNameSuggestion.rows(
            site: [Self.glasses, Self.frames],
            translationMatches: matches,
            tag: "sample gl",
            translations: ["femalesample glasses": listed, "femalesample glassware": unlisted]
        )

        #expect(rows.map(\.id) == [.site(9001), .site(9002), .translation("female:sample glassware")])
        #expect(rows.map(\.insertedName) == [
            "female:sample glasses", "female:sample spectacles", "female:sample glassware"
        ])
        #expect(rows.map(\.alias) == [nil, "female:sample glass frames", nil])
        #expect(rows.map(\.suggestion.tag) == [
            listed, TagTranslation(namespace: .female, key: "sample spectacles", value: ""), unlisted
        ])
    }

    // Without translations a site row shows the tag by its own name, the typed term and namespace highlighted.
    @Test
    func withoutTranslationsASiteRowShowsItsOwnName() throws {
        let rows = TagNameSuggestion.rows(
            site: [Self.glasses], translationMatches: [], tag: "f:sample gl", translations: [:]
        )

        let row = try #require(rows.first)
        #expect(rows.count == 1)
        #expect(row.suggestion.tag == TagTranslation(namespace: .female, key: "sample glasses", value: ""))
        #expect(row.suggestion.keyRange != nil)
        #expect(row.suggestion.matchesNamespace)
        #expect(row.alias == nil)
    }
}
