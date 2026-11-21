import AppModels
import Foundation
import Kanna
import ParserFeature
import Testing
import TestingSupport

/// What a list row says about the signed-in user and the site, read from the live fixtures: the favorites
/// slot (a coloured border and the slot's name on the posted-date box), the user's own rating (a star class
/// other than plain `ir`) and an expunged gallery (the posted date inside `<s>`).
///
/// The counts below were taken from the fixtures' HTML directly, not from the parser.
struct GalleryStatusParserTests: TestHelper {
    private static let favorites: [HTMLFilename] = [
        .favoritesMinimalList, .favoritesMinimalPlusList, .favoritesCompactList,
        .favoritesExtendedList, .favoritesThumbnailList
    ]
    private static let withoutMarks: [HTMLFilename] = [
        .frontPageMinimalList, .frontPageMinimalPlusList, .frontPageCompactList,
        .frontPageExtendedList, .frontPageThumbnailList,
        .popularMinimalList, .popularMinimalPlusList, .popularCompactList,
        .popularExtendedList, .popularThumbnailList,
        .watchedMinimalList, .watchedMinimalPlusList, .watchedCompactList,
        .watchedExtendedList, .watchedThumbnailList
    ]

    private func galleries(_ filename: HTMLFilename) throws -> [Gallery] {
        try Parser.parseGalleries(doc: htmlDocument(filename: filename))
    }

    private func galleries(html: String) throws -> [Gallery] {
        try Parser.parseGalleries(doc: Kanna.HTML(html: html, encoding: .utf8))
    }

    @Test(arguments: favorites)
    func everyRowOfAFavoritesPageIsAFavoriteWithItsSlot(_ filename: HTMLFilename) throws {
        let rows = try galleries(filename)
        #expect(rows.count == 100, "\(filename)")
        #expect(rows.allSatisfy({ $0.isFavorite }), "\(filename)")
        #expect(rows.filter({ $0.favoriteTagIndex == 0 }).count == 97, "\(filename)")
        #expect(rows.filter({ $0.favoriteTagIndex == 1 }).count == 2, "\(filename)")
        #expect(rows.filter({ $0.favoriteTagIndex == 2 }).count == 1, "\(filename)")
        // The slot's name is the page's own, whatever the user renamed it to.
        #expect(rows.allSatisfy({ $0.favoriteTagName == "Favorites \($0.favoriteTagIndex ?? -1)" }), "\(filename)")
    }

    @Test(arguments: favorites)
    func theDateStruckThroughOnAFavoritesPageMarksTheGalleryExpunged(_ filename: HTMLFilename) throws {
        #expect(try galleries(filename).filter(\.isExpunged).count == 3, "\(filename)")
    }

    @Test(arguments: favorites)
    func aStarClassOtherThanPlainIrMarksTheGalleryRated(_ filename: HTMLFilename) throws {
        #expect(try galleries(filename).filter(\.hasRated).count == 3, "\(filename)")
    }

    @Test(arguments: withoutMarks)
    func pagesWithNothingToMarkMarkNothing(_ filename: HTMLFilename) throws {
        let rows = try galleries(filename)
        #expect(rows.isEmpty == false, "\(filename)")
        #expect(rows.allSatisfy({ !$0.isFavorite && !$0.isExpunged && !$0.hasRated }), "\(filename)")
    }

    @Test
    func aToplistRowsStruckThroughDateIsExpungedAndNothingElse() throws {
        let rows = try galleries(.toplistsCompactList)
        #expect(rows.count == 50)
        #expect(rows.filter(\.isExpunged).count == 4)
        #expect(rows.allSatisfy({ !$0.isFavorite && !$0.hasRated }))
    }

    // Every user-rating star class counts, not only the blue one #462 looked for: the site draws the user's own
    // rating red, green or blue by value (`irr`, `irg`, `irb`), and none of them is the plain `ir` average.
    @Test(arguments: ["irr", "irg", "irb"])
    func everyUserRatingClassMarksTheGalleryRated(_ userClass: String) throws {
        let html = try htmlString(filename: .favoritesCompactList)
        let rewritten = html
            .replacing(#"class="ir irb""#, with: #"class="ir \#(userClass)""#)
        #expect(try galleries(html: rewritten).filter(\.hasRated).count == 3)
    }

    @Test
    func thePlainAverageStarClassIsNotARating() throws {
        let html = try htmlString(filename: .favoritesCompactList)
        let rewritten = html.replacing(#"class="ir irb""#, with: #"class="ir""#)
        let rows = try galleries(html: rewritten)
        #expect(rows.contains(where: \.hasRated) == false)
    }

    @Test
    func aBorderColourTheAppDoesNotKnowKeepsTheNameWithoutASlot() throws {
        let html = try htmlString(filename: .favoritesCompactList)
        let rewritten = html.replacing("border-color:#fa0", with: "border-color:#123")
        let unknown = try galleries(html: rewritten).filter({ $0.favoriteTagName == "Favorites 2" })
        #expect(unknown.count == 1)
        #expect(unknown.allSatisfy({ $0.favoriteTagIndex == nil && $0.isFavorite }))
    }
}
