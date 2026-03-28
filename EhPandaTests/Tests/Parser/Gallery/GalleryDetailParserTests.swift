//
//  GalleryDetailParserTests.swift
//  EhPandaTests
//

import Kanna
import Testing
@testable import EhPanda

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
        #expect(detail.rating == 4.5)
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
}
