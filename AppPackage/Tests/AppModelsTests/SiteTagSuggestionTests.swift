import AppModels
import Testing

// The site's tag completer as the app follows it (G-1 and G-4 of quick 261126-wzg; `tagcompleter` in the site's
// `ehg_mytags.c.js`, read 2026-11-26): the text it sends, when it sends nothing, which entries of the answer its list
// keeps, and what choosing one inserts. The tags are invented.
struct SiteTagSuggestionTests {
    private static let glasses = SiteTagSuggestion(
        id: 9001, tag: SiteTag(namespace: .female, name: "sample glasses"), canonical: nil
    )

    @Test(arguments: [
        ("x:sample", "mixed:sample"),
        ("mix:sample", "mixed:sample"),
        ("mixed:sample", "mixed:sample"),
        ("mis:sample", "temp:sample"),
        ("misc:sample", "temp:sample"),
        ("co:sample", "cosplayer:sample"),
        ("cos:sample", "cosplayer:sample"),
        ("lo:sample", "location:sample"),
        ("t:sample", "temp:sample"),
        ("f:sample", "female:sample"),
        ("m:sample", "male:sample"),
        ("r:sample", "reclass:sample"),
        ("l:sample", "language:sample"),
        ("lang:sample", "language:sample"),
        ("p:sample", "parody:sample"),
        ("c:sample", "character:sample"),
        ("char:sample", "character:sample"),
        ("g:sample", "group:sample"),
        ("a:sample", "artist:sample"),
        ("o:sample", "other:sample")
    ])
    func aLooseNamespaceIsWrittenOut(typed: String, sent: String) {
        #expect(TagSuggestQuery(typed)?.text == sent)
    }

    // No namespace, an upper-case or unknown one, or a space before it is sent as typed; quotes are removed; the
    // namespace runs to the last colon.
    @Test(arguments: [
        ("sample gl", "sample gl"),
        ("F:sample", "F:sample"),
        ("zz:sample", "zz:sample"),
        (" f:sample", " f:sample"),
        (#""f:sample gl""#, "female:sample gl"),
        ("f:x:sample", "female:sample")
    ])
    func otherTextsAreSentAsTheSiteSendsThem(typed: String, sent: String) {
        #expect(TagSuggestQuery(typed)?.text == sent)
    }

    @Test
    func theTermIsWhatFollowsTheNamespace() {
        #expect(TagSuggestQuery("f:sample gl")?.term == "sample gl")
        #expect(TagSuggestQuery("sample gl")?.term == "sample gl")
    }

    @Test(arguments: ["", "s", "female:", "female:s", "f:s", #""s""#])
    func fewerThanTwoCharactersAfterTheNamespaceAskNothing(typed: String) {
        #expect(TagSuggestQuery(typed) == nil)
    }

    // The site's list keeps an entry whose own `namespace:tag` holds the text at the start of a word, in any case.
    @Test(arguments: ["female:sample gl", "f:sample gl", "FEMALE:SAMPLE", "sample gl", "glass", "fem"])
    func anEntryMatchesTheTextAtAWordStart(typed: String) throws {
        #expect(Self.glasses.matches(try #require(TagSuggestQuery(typed))))
    }

    @Test(arguments: ["male:sample", "ample", "lasses", "female:gl", "sample  gl"])
    func anEntryDoesNotMatchTheTextInsideAWord(typed: String) throws {
        #expect(!Self.glasses.matches(try #require(TagSuggestQuery(typed))))
    }

    // An alias is matched by its own name and inserts its canonical tag; a tag inserts itself.
    @Test
    func anAliasInsertsItsCanonicalTag() throws {
        let alias = SiteTagSuggestion(
            id: 9002,
            tag: SiteTag(namespace: .female, name: "sample glass frames"),
            canonical: SiteTag(namespace: .female, name: "sample spectacles")
        )

        #expect(alias.matches(try #require(TagSuggestQuery("sample gl"))))
        #expect(!alias.matches(try #require(TagSuggestQuery("sample sp"))))
        #expect(alias.insertedTag.fullName == "female:sample spectacles")
        #expect(Self.glasses.insertedTag.fullName == "female:sample glasses")
    }
}
