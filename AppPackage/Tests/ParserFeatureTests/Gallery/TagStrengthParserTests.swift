import AppModels
import Foundation
import Kanna
@testable import ParserFeature
import Testing
import TestingSupport

struct TagStrengthParserTests: TestHelper {
    @Test(arguments: zip(["gt", "gtl", "gtw"], [GalleryTag.VoteStrength.strong, .active, .weak]))
    func detailPreservesStrengthSeparatelyFromPersonalVotes(
        cssClass: String, expected: GalleryTag.VoteStrength
    ) throws {
        let doc = try htmlDocument(filename: .galleryDetail)
        var element = try #require(doc.at_xpath("//*[@id='taglist']//div"))
        var anchor = try #require(element.at_xpath(".//a"))
        element["class"] = cssClass
        anchor["class"] = "tdn"
        let (_, state) = try Parser.parseGalleryDetail(doc: doc, gid: "2725078")
        let tags = state.tags.flatMap(\.contents)
        #expect(tags.map(\.voteStrength) == [expected])
        #expect(tags.first?.isVotedDown == true)
    }

    @Test
    func listPreservesStrength() throws {
        let doc = try htmlDocument(filename: .frontPageCompactList)
        let tags = try Parser.parseGalleries(doc: doc).flatMap(\.tags).flatMap(\.contents)
        #expect(tags.isEmpty == false)
        #expect(tags.allSatisfy({ $0.voteStrength != nil }))
        #expect(tags.contains(where: { $0.voteStrength == .strong }))
    }

    @Test
    func legacyCacheHasUnknownStrengthAndNewRecordsRoundTrip() throws {
        let data = Data(#"{"rawNamespace":"artist","text":"name","isVotedUp":true,"isVotedDown":false}"#.utf8)
        let legacy = try JSONDecoder().decode(GalleryTag.Content.self, from: data)
        #expect(legacy.voteStrength == nil)
        let strong = GalleryTag.Content(
            rawNamespace: "artist", text: "name", isVotedUp: false, isVotedDown: false, voteStrength: .strong
        )
        let decoded = try JSONDecoder().decode(GalleryTag.Content.self, from: JSONEncoder().encode(strong))
        #expect(decoded == strong)
    }
}
