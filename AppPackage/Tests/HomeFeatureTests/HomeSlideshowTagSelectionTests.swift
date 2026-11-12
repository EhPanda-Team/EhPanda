import AppModels
@testable import HomeFeature
import Testing

struct HomeSlideshowTagSelectionTests {
    @Test(arguments: ["()", "[]", "{}", "<>", "（）", "［］", "｛｝", "〈〉", "《》", "「」", "『』", "【】", "〔〕"])
    func excludesNamesInDifferentBrackets(_ pair: String) throws {
        let opening = try #require(pair.first)
        let closing = try #require(pair.last)
        var gallery = Gallery.preview
        gallery.title = "\(opening)ＳＴＵＤＩＯ　Ａ\(closing) Story"
        gallery.tags = [tag("group", ["studio a"]), tag("other", ["watercolor"])]
        #expect(gallery.homeSlideshowTags.map(\.text) == ["watercolor"])
    }

    @Test
    func excludesNestedCreatorNamesButKeepsUnrelatedWordsAndBodyText() {
        var gallery = Gallery.preview
        gallery.title = "[Studio A (Artist-B)] Watercolor [Cartoon] [Unclosed"
        gallery.tags = [
            tag("group", ["studio a"]), tag("artist", ["artist b"]),
            tag("other", ["art", "watercolor", "unclosed"])
        ]
        #expect(gallery.homeSlideshowTags.map(\.text) == ["art", "watercolor", "unclosed"])
    }

    @Test
    func lowOrUnknownStrengthCreatorsCannotDisplaceStrongTags() {
        var gallery = Gallery.preview
        gallery.tags = [
            tag("artist", ["weak artist"], strength: .weak),
            tag("group", ["active circle"], strength: .active),
            tag("artist", ["old cached artist"], strength: nil),
            tag("other", ["watercolor", "landscape", "full color", "extra"])
        ]
        #expect(gallery.homeSlideshowTags.map(\.text) == ["watercolor", "landscape", "full color"])
    }

    @Test
    func creatorsHavePriorityAndEqualStrengthKeepsSourceOrder() {
        var gallery = Gallery.preview
        gallery.tags = [
            tag("other", ["landscape", "watercolor"]),
            tag("group", ["circle"]), tag("artist", ["artist"])
        ]
        #expect(gallery.homeSlideshowTags.map(\.text) == ["circle", "artist", "landscape"])
    }

    @Test
    func filtersDuplicatesAndTitleMatchesBeforeApplyingTheLimit() {
        var gallery = Gallery.preview
        gallery.title = "[Circle (Artist)] Story"
        gallery.tags = [
            tag("language", ["english"]), tag("group", ["circle"]), tag("artist", ["artist"]),
            tag("other", ["Doujinshi", "", "watercolor", "WATERCOLOR", "landscape", "full color"])
        ]
        #expect(gallery.homeSlideshowTags.map(\.text) == ["watercolor", "landscape", "full color"])
    }

    private func tag(
        _ namespace: String, _ names: [String], strength: GalleryTag.VoteStrength? = .strong
    ) -> GalleryTag {
        .init(rawNamespace: namespace, contents: names.map { name in
            .init(rawNamespace: namespace, text: name, isVotedUp: false, isVotedDown: false, voteStrength: strength)
        })
    }
}
