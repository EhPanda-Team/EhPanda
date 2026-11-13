@testable import AppFeature
import AppModels
import Foundation
import Kanna
import ParserFeature
import Testing
import TestingSupport

struct GalleryDetailParserTests: TestHelper {
    @Test
    func testExample() throws {
        let document = try htmlDocument(filename: .galleryDetail)
        let (detail, state) = try Parser.parseGalleryDetail(doc: document, gid: "2725078")
        #expect(detail.gid == "2725078")
        #expect(detail.title == "[Artist] mks")
        #expect(detail.jpnTitle == "[アーティスト] mks")
        #expect(detail.isFavorited == false)
        #expect(detail.visibility == .yes)
        #expect(detail.rating == 4.74)
        #expect(detail.userRating == 0)
        #expect(detail.ratingCount == 110)
        #expect(detail.category == .nonH)
        #expect(detail.language == .japanese)
        #expect(detail.uploader == "Pokom")
        #expect(
            detail.coverURL?.absoluteString
                == "https://ehgt.org/03/08/0308268821e99628b05a19fa54e2fc0fa9ad8f4b-1705560-1012-1470-png_250.jpg"
        )
        #expect(detail.archiveURL?.absoluteString == "https://e-hentai.org/archiver.php?gid=3103480&token=0000000000")
        #expect(detail.parentURL?.absoluteString == "https://e-hentai.org/g/2930572/daf4b9880d/")
        #expect(detail.favoritedCount == 591)
        #expect(detail.pageCount == 156)
        #expect(detail.sizeCount == 314.3)
        #expect(detail.sizeType == "MiB")
        #expect(detail.torrentCount == 1)
        #expect(state.tags.count == 1)
        #expect(state.previewURLs.count == 40)
        #expect(state.previewConfig == .normal(rows: 4))
        #expect(state.comments.count == 10)
    }

    /// The star image turns into the user's own rating once they rate, while the label keeps the average.
    @Test
    func testRatedGalleryKeepsTheAverageApartFromTheUserRating() throws {
        let detail = try detail(replacing: [(unratedStars, ratedStars)])
        #expect(detail.rating == 4.74)
        #expect(detail.userRating == 2.5)
    }

    /// Without the label, the stars stand in for the average only while they still show it.
    @Test
    func testMissingLabelFallsBackToTheStarsOnlyBeforeTheUserRates() throws {
        let unrated = try detail(replacing: [(averageLabel, "")])
        #expect(unrated.rating == 4.5)
        #expect(unrated.userRating == 0)

        let rated = try detail(replacing: [(averageLabel, ""), (unratedStars, ratedStars)])
        #expect(rated.rating == 0)
        #expect(rated.userRating == 2.5)
    }

    // MARK: Favorite slot
    private static let notFavorite = #"<div style="float:left; cursor:pointer" id="fav"></div>"#
        + ##"<div style="float:left">&nbsp; <a id="favoritelink" href="#" onclick="return false">"##
        + #"<img src="https://ehgt.org/g/mr.gif" /> Add to Favorites</a></div>"#

    /// The Favorited state of the page's favorite box: the slot's icon in `#fav` (a sprite shifted 19 points
    /// per slot, the first at -2) and the slot's name in the link.
    private func favoritedBox(name: String, spriteOffset: Int?) -> String {
        let icon = spriteOffset.map {
            #"<div class="i" style="background-image:url(https://ehgt.org/g/fav.png); "#
                + #"background-position:0px \#($0)px; margin-top:-1px"></div>"#
        } ?? ""
        return #"<div style="float:left; cursor:pointer" id="fav">"# + icon + #"</div>"#
            + ##"<div style="float:left">&nbsp; <a id="favoritelink" href="#" onclick="return false">"##
            + name + "</a></div>"
    }

    @Test
    func anUnfavoritedGalleryHasNoSlot() throws {
        let detail = try detail(replacing: [])
        #expect(detail.isFavorited == false)
        #expect(detail.favoriteTagIndex == nil)
        #expect(detail.favoriteTagName == nil)
    }

    // Regression: #462 stored only the slot's name and never set the index its own colour lookup read.
    @Test(arguments: [(0, -2), (1, -21), (4, -78), (9, -173)])
    func theSlotIsReadFromTheFavoriteIcon(_ slot: Int, _ offset: Int) throws {
        let favorited = try detail(replacing: [
            (Self.notFavorite, favoritedBox(name: "Read later", spriteOffset: offset))
        ])
        #expect(favorited.isFavorited)
        #expect(favorited.favoriteTagName == "Read later")
        #expect(favorited.favoriteTagIndex == slot)
    }

    @Test
    func withoutTheIconADefaultNameStillGivesTheSlot() throws {
        let favorited = try detail(replacing: [
            (Self.notFavorite, favoritedBox(name: "Favorites 6", spriteOffset: nil))
        ])
        #expect(favorited.favoriteTagName == "Favorites 6")
        #expect(favorited.favoriteTagIndex == 6)
    }

    @Test
    func aRenamedSlotWithoutTheIconKeepsItsNameAndLeavesTheSlotToTheUsersFolderNames() throws {
        let favorited = try detail(replacing: [
            (Self.notFavorite, favoritedBox(name: "Read later", spriteOffset: nil))
        ])
        #expect(favorited.isFavorited)
        #expect(favorited.favoriteTagName == "Read later")
        #expect(favorited.favoriteTagIndex == nil)
    }

    @Test
    func anIconOffsetOutsideTheTenSlotsIsNotASlot() throws {
        let favorited = try detail(replacing: [
            (Self.notFavorite, favoritedBox(name: "Read later", spriteOffset: -400))
        ])
        #expect(favorited.favoriteTagIndex == nil)
    }

    // The site names the colour of the user's own rating in the star class, so the colour is read, not guessed from
    // the value.
    @Test(arguments: [("irr", UserRatingTint.red), ("irg", .green), ("irb", .blue)])
    func theUserRatingColourIsTheStarClass(_ starClass: String, _ tint: UserRatingTint) throws {
        let rated = try detail(replacing: [
            (averageLabel, ""),
            (unratedStars, #"class="ir \#(starClass)" style="background-position:-32px -21px""#)
        ])
        #expect(rated.userRatingTint == tint)
    }

    @Test
    func anUnratedGalleryHasNoRatingColour() throws {
        #expect(try detail(replacing: []).userRatingTint == nil)
    }

    private let averageLabel = "Average: 4.74"
    private let unratedStars = #"class="ir" style="background-position:0px -21px""#
    private let ratedStars = #"class="ir irr" style="background-position:-32px -21px""#

    private func detail(replacing replacements: [(String, String)]) throws -> GalleryDetail {
        var html = try htmlString(filename: .galleryDetail)
        for (target, replacement) in replacements {
            try #require(html.contains(target))
            html = html.replacing(target, with: replacement)
        }
        let document = try Kanna.HTML(html: html, encoding: .utf8)
        return try Parser.parseGalleryDetail(doc: document, gid: "2725078").0
    }
}
