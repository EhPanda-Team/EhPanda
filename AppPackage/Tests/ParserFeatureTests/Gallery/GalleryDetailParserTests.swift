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
