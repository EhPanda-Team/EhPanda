import AppModels
import Foundation
import Testing

// The My Tags model (port of PR 462 item 10): site colours, the kind, the highlight (design approved 2026-11-22), the
// cache's selection and updates, and the optional field on the stored user. The tags and sets are invented.
struct MyTagsTests {
    private static let glasses = MyTag(
        id: 101, name: "female:sample glasses", isWatched: true, isHidden: false, color: nil, weight: 10
    )
    private static let artist = MyTag(
        id: 201, name: "artist:sample artist", isWatched: false, isHidden: false, color: nil, weight: 5
    )
    private static let slate = SiteColor(red: 0xA0, green: 0xB0, blue: 0xC0)
    private static let green = SiteColor(red: 0x22, green: 0xAA, blue: 0x55)

    @Test(arguments: ["#A0B0C0", "a0b0c0", "#a0B0c0"])
    func aSiteColourReadsEitherCaseWithOrWithoutTheHash(hex: String) {
        #expect(SiteColor(hex: hex) == Self.slate)
        #expect(SiteColor(hex: hex)?.hex == "#A0B0C0")
    }

    @Test(arguments: ["", "#", "#12345", "#1234567", "#GGGGGG", "12 456", "-12345"])
    func anythingButSixHexDigitsIsNoColour(hex: String) {
        #expect(SiteColor(hex: hex) == nil)
    }

    @Test
    func aSiteColourSurvivesTheTripThroughAColourAndClampsItsChannels() {
        #expect(SiteColor(Self.slate.color) == Self.slate)
        #expect(SiteColor(red: -1, green: 256, blue: 0x80) == SiteColor(red: 0, green: 255, blue: 0x80))
    }

    @Test
    func aKindReadsAndSetsBothFlags() {
        var tag = Self.glasses
        #expect(tag.kind == .watched)
        tag.kind = .hidden
        #expect(!tag.isWatched && tag.isHidden)
        tag.kind = .flagged
        #expect(!tag.isWatched && !tag.isHidden)
        tag.isWatched = true
        tag.isHidden = true
        #expect(tag.kind == .hidden)
    }

    @Test
    func theHighlightIsTheFirstEnabledSetsEntryInItsColourElseTheSets() {
        var coloured = Self.glasses
        coloured.color = Self.slate
        let disabled = MyTagSet(id: 1, name: "Tagset #1", isEnabled: false, color: nil, tags: [coloured])
        let enabled = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: true, color: Self.green, tags: [Self.glasses])
        let later = MyTagSet(id: 3, name: "Third", isEnabled: true, color: nil, tags: [coloured])

        let myTags = MyTags(tagSets: [disabled, enabled, later])

        #expect(
            myTags.highlight(fullName: "female:sample glasses") == MyTagHighlight(kind: .watched, color: Self.green)
        )
        #expect(
            MyTags(tagSets: [later]).highlight(fullName: "female:sample glasses")
                == MyTagHighlight(kind: .watched, color: Self.slate)
        )
    }

    @Test
    func aTagInNoEnabledSetHasNoHighlightAndOneWithNoColourHasNone() {
        let disabled = MyTagSet(id: 1, name: "Tagset #1", isEnabled: false, color: nil, tags: [Self.glasses])
        let plain = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: true, color: nil, tags: [Self.artist])
        let myTags = MyTags(tagSets: [disabled, plain])

        #expect(myTags.highlight(fullName: "female:sample glasses") == nil)
        #expect(myTags.highlight(fullName: "artist:sample artist") == MyTagHighlight(kind: .flagged, color: nil))
        #expect(myTags.highlight(fullName: "artist:no such tag") == nil)
    }

    @Test
    func theSelectedSetIsTheOneLastChosenElseTheFirst() {
        let first = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [])
        let second = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: nil, tags: [])
        let myTags = MyTags(tagSets: [first, second])

        #expect(myTags.selectedTagSet == first)
        #expect(myTags.selecting(2).selectedTagSet == second)
        #expect(myTags.selecting(9).selectedTagSet == first)
        #expect(myTags.selecting(2).selectedTagSetID == 2)
        #expect(MyTags(tagSets: []).selectedTagSet == nil)
    }

    @Test
    func aPageReplacesItsSetInThePickersOrderAndKeepsTheSelection() {
        let first = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [Self.glasses])
        let second = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: Self.green, tags: [Self.artist])
        let third = MyTagSet(id: 3, name: "Third", isEnabled: true, color: nil, tags: [])
        let emptied = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [])
        let cache = MyTags(tagSets: [first, second, third], selectedTagSetID: 2)

        let applied = cache.applying(Self.page(emptied, tagSetIDs: [2, 1, 4]))

        #expect(applied == MyTags(tagSets: [second, emptied], selectedTagSetID: 2))
    }

    // New Tag Set reads the set it made, which the cache lacks (N-6 of quick 261126-pfh): the page's own set takes its
    // place in the picker's order, while set 4, which the cache lacks too, stays out until the next fetch.
    @Test
    func aPageOfASetTheCacheLacksTakesItsPlaceInThePickersOrder() {
        let first = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [Self.glasses])
        let second = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: Self.green, tags: [Self.artist])
        let made = MyTagSet(id: 3, name: "Fixture Holds", isEnabled: false, color: nil, tags: [])
        let cache = MyTags(tagSets: [first, second], selectedTagSetID: 3)

        let applied = cache.applying(Self.page(made, tagSetIDs: [1, 3, 2, 4]))

        #expect(applied == MyTags(tagSets: [first, made, second], selectedTagSetID: 3))
    }

    @Test
    func anUpdateReplacesOneSetOrOneTagAndKeepsTheRest() {
        var edited = Self.glasses
        edited.kind = .hidden
        edited.color = Self.slate
        edited.weight = -5
        let first = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [Self.glasses, Self.artist])
        let second = MyTagSet(id: 2, name: "Fixture Picks", isEnabled: false, color: nil, tags: [Self.glasses])
        var recoloured = second
        recoloured.isEnabled = true
        recoloured.color = Self.green
        let cache = MyTags(tagSets: [first, second], selectedTagSetID: 2)

        #expect(
            cache.updating(edited, inTagSet: 1)
                == MyTags(
                    tagSets: [
                        MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: nil, tags: [edited, Self.artist]),
                        second
                    ],
                    selectedTagSetID: 2
                )
        )
        #expect(cache.updating(recoloured) == MyTags(tagSets: [first, recoloured], selectedTagSetID: 2))
    }

    @Test
    func aGalleryTagIsNamedAsMyTagsTitlesItAndTakesTheCacheElseTheListColour() {
        let content = GalleryTag.Content(
            rawNamespace: "female", text: "sample glasses", isVotedUp: false, isVotedDown: false,
            backgroundColor: SiteColor(red: 0x33, green: 0x77, blue: 0xFF).color
        )
        let uncoloured = GalleryTag.Content(
            rawNamespace: "artist", text: "sample artist", isVotedUp: false, isVotedDown: false
        )
        let myTags = MyTags(tagSets: [
            MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: Self.green, tags: [Self.glasses])
        ])
        let standIn = MyTagHighlight(kind: .flagged, color: SiteColor(red: 0x33, green: 0x77, blue: 0xFF))

        #expect(content.myTagsName == "female:sample glasses")
        #expect(content.myTagHighlight(in: myTags) == MyTagHighlight(kind: .watched, color: Self.green))
        #expect(content.myTagHighlight(in: nil) == standIn)
        #expect(uncoloured.myTagHighlight(in: nil) == nil)
        #expect(uncoloured.myTagHighlight(in: myTags) == nil)
    }

    @Test
    func aUserStoredBeforeMyTagsDecodesWithoutThemAndTheyRoundTrip() throws {
        let older = try JSONDecoder().decode(User.self, from: Data(#"{"schemaVersion": 1}"#.utf8))
        #expect(older.myTags == nil)

        let tagSet = MyTagSet(id: 1, name: "Tagset #1", isEnabled: true, color: Self.slate, tags: [Self.glasses])
        let user = User(favoriteCategories: [0: "Favorites 0"], myTags: MyTags(tagSets: [tagSet], selectedTagSetID: 1))
        let decoded = try JSONDecoder().decode(User.self, from: JSONEncoder().encode(user))
        #expect(decoded == user)
    }

    private static func page(_ tagSet: MyTagSet, tagSetIDs: [Int]) -> MyTagsPage {
        MyTagsPage(tagSet: tagSet, tagSetIDs: tagSetIDs, apiuid: 1234567, apikey: "0123456789abcdef", message: nil)
    }
}
