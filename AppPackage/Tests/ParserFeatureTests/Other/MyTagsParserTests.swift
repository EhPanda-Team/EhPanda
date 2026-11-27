import AppModels
import Foundation
import Kanna
import ParserFeature
import Testing
import TestingSupport

/// My Tags pages in the site's markup of 2026-11-22 with invented tags and credentials (port of PR 462 item 10). The
/// inline pages are `MyTagsTagSet1` with one detail changed.
/// `MyTagsTagSet3` is an empty set whose page offers deleting it (quick 261126-udx).
struct MyTagsParserTests: TestHelper {
    @Test
    func aPageReadsItsSetTheOtherSetsAndTheCredentials() throws {
        let page = try Parser.parseMyTags(doc: htmlDocument(filename: .myTagsTagSet1))

        #expect(page == MyTagsPage(
            tagSet: MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [
                MyTag(
                    id: 101, name: "female:sample glasses", isWatched: true, isHidden: false, color: nil, weight: 10
                ),
                MyTag(id: 102, name: "male:sample beard", isWatched: false, isHidden: true, color: nil, weight: 10),
                MyTag(
                    id: 103, name: "other:sample color", isWatched: false, isHidden: false,
                    color: SiteColor(red: 0xA0, green: 0xB0, blue: 0xC0), weight: 10
                ),
                MyTag(
                    id: 104, name: "parody:sample series", isWatched: false, isHidden: false, color: nil, weight: -20
                )
            ]),
            tagSetIDs: [1, 2],
            apiuid: 1234567,
            apikey: "0123456789abcdef",
            message: nil
        ))
    }

    @Test
    func aColouredDisabledSetReadsItsColourAndState() throws {
        let page = try Parser.parseMyTags(doc: htmlDocument(filename: .myTagsTagSet2))

        #expect(page.tagSet == MyTagSet(
            id: 2, name: "Fixture Picks", isEnabled: false, color: SiteColor(red: 0x22, green: 0xAA, blue: 0x55),
            tags: [
                MyTag(id: 201, name: "artist:sample artist", isWatched: false, isHidden: false, color: nil, weight: 5)
            ]
        ))
        #expect(page.tagSetIDs == [1, 2])
    }

    // A control in the tag set form whose `onclick` calls `do_tagset_delete` offers deleting the shown set (U-1 of
    // quick 261126-udx).
    @Test
    func aPageWithTheDeleteControlOffersDeletingItsSet() throws {
        let page = try Parser.parseMyTags(doc: htmlDocument(filename: .myTagsTagSet3))

        #expect(page == MyTagsPage(
            tagSet: MyTagSet(id: 3, name: "Fixture Holds", isEnabled: false, color: nil, tags: [], isDeletable: true),
            tagSetIDs: [1, 2, 3],
            apiuid: 1234567,
            apikey: "0123456789abcdef",
            message: nil
        ))
    }

    // Neither page of 2026-11-22 carries the control, and the tags form's Delete Selected is not it.
    @Test(arguments: [HTMLFilename.myTagsTagSet1, .myTagsTagSet2])
    func aPageWithoutTheDeleteControlOffersNoDelete(filename: HTMLFilename) throws {
        let page = try Parser.parseMyTags(doc: htmlDocument(filename: filename))

        #expect(!page.tagSet.isDeletable)
    }

    // A disabled Delete control offers nothing (U-1a of quick 261126-udx).
    @Test
    func aPageWhoseDeleteControlIsDisabledOffersNoDelete() throws {
        let html = try htmlString(filename: .myTagsTagSet3)
        let target = #"onclick="do_tagset_delete()" value="Delete" />"#
        try #require(html.contains(target))
        let disabled = #"onclick="do_tagset_delete()" value="Delete" disabled="disabled" />"#
        let document = try Kanna.HTML(html: html.replacing(target, with: disabled), encoding: .utf8)
        let page = try Parser.parseMyTags(doc: document)

        #expect(!page.tagSet.isDeletable)
    }

    // A refused form post answers the same page with the reason at the top of `#outer`.
    @Test
    func aRefusalCarriesTheSitesReason() throws {
        let target = #"<div class="stuffbox" id="outer">"#
        let document = try myTagsPage(
            replacing: target,
            with: target + #"<div id="msg"><p>No matching tag found</p></div>"#
        )

        #expect(try Parser.parseMyTags(doc: document).message == "No matching tag found")
    }

    @Test
    func aColourThatIsNotSixHexDigitsFailsThePage() throws {
        let document = try myTagsPage(replacing: ##"value="#A0B0C0""##, with: ##"value="#A0B0CG""##)

        #expect(throws: AppError.parseFailed) {
            try Parser.parseMyTags(doc: document)
        }
    }

    @Test
    func aPageWithoutTheAPIKeyIsNotAMyTagsPage() throws {
        let document = try myTagsPage(replacing: #"var apikey = "0123456789abcdef";"#, with: "")

        #expect(throws: AppError.parseFailed) {
            try Parser.parseMyTags(doc: document)
        }
    }

    @Test
    func aGalleryPageIsNotAMyTagsPage() throws {
        let document = try htmlDocument(filename: .galleryDetail)

        #expect(throws: AppError.parseFailed) {
            try Parser.parseMyTags(doc: document)
        }
    }

    // A list page's tag colour is the gradient's last stop, the tag's own; it stands in until the cached My Tags has
    // loaded (design approved 2026-11-22).
    @Test
    func aListPageTagTakesTheGradientsLastStop() throws {
        let galleries = try Parser.parseGalleries(doc: htmlDocument(filename: .frontPageExtendedList))
        let colours = galleries.flatMap(\.tags).flatMap(\.contents).compactMap(\.backgroundColor)
        #expect(!colours.isEmpty)
        #expect(colours.allSatisfy({ SiteColor($0) == SiteColor(red: 0x33, green: 0x77, blue: 0xFF) }))
    }

    private func myTagsPage(replacing target: String, with replacement: String) throws -> any HTMLDocument {
        let html = try htmlString(filename: .myTagsTagSet1)
        // A guard against a test that silently changes nothing.
        try #require(html.contains(target))
        return try Kanna.HTML(html: html.replacing(target, with: replacement), encoding: .utf8)
    }
}
