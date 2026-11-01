@testable import DetailFeature
import Foundation
import Resources
import Testing

/// A count of one must read as singular wherever the UI shows a count next to its noun, or a
/// one-page gallery says "1 pages". English and German have the `one` category; the other locales
/// have no singular, so their single variant needs no coverage.
struct GalleryCountWordingTests {
    struct Wording: Sendable {
        let locale: String
        let count: Int
        let pages: String
        let stars: String
        let ratings: String
        let favoritedUnit: String
        let pageUnit: String
    }

    private func text(_ resource: LocalizedStringResource, locale: String) -> String {
        var resource = resource
        resource.locale = Locale(identifier: locale)
        return String(localized: resource)
    }

    @Test(arguments: [
        Wording(
            locale: "en", count: 1, pages: "1 page", stars: "1 star", ratings: "1 Rating",
            favoritedUnit: "Time", pageUnit: "Page"
        ),
        Wording(
            locale: "en", count: 2, pages: "2 pages", stars: "2 stars", ratings: "2 Ratings",
            favoritedUnit: "Times", pageUnit: "Pages"
        ),
        Wording(
            locale: "de", count: 1, pages: "1 Seite", stars: "1 Stern", ratings: "1 Stimme",
            favoritedUnit: "Mal", pageUnit: "Seite"
        ),
        Wording(
            locale: "de", count: 2, pages: "2 Seiten", stars: "2 Sterne", ratings: "2 Stimmen",
            favoritedUnit: "Mal", pageUnit: "Seiten"
        )
    ])
    func wordingFollowsTheCount(_ wording: Wording) {
        let count = wording.count
        #expect(text(.RLocalizable.pages(count: count), locale: wording.locale) == wording.pages)
        #expect(text(.RLocalizable.stars(count: count), locale: wording.locale) == wording.stars)
        #expect(text(.ratingsCount(count: count), locale: wording.locale) == wording.ratings)
        #expect(text(.favoritedUnit(count: count), locale: wording.locale) == wording.favoritedUnit)
        #expect(text(.pageCountUnit(count: count), locale: wording.locale) == wording.pageUnit)
    }
}
