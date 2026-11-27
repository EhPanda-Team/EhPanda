import AppModels
import Foundation
import ParserFeature
import Testing

/// The API's answers to `tagsuggest` in the shapes probed on 2026-11-26 (G-1 and G-4 of quick 261126-wzg), with
/// invented ids and tags.
struct TagSuggestParserTests {
    private static let glasses = SiteTagSuggestion(
        id: 9001, tag: SiteTag(namespace: .female, name: "sample glasses"), canonical: nil
    )

    // The probed object: a tag, and an alias whose canonical tag a choice inserts; the entries come in ascending id
    // order.
    @Test
    func anAnswerReadsItsTagsAndAliasesInIdOrder() throws {
        let answer = #"{"tags":{"9102":{"ns":"female","tn":"sample glass frames","mid":9101,"mns":"female","#
            + #""mtn":"sample spectacles"},"9001":{"ns":"female","tn":"sample glasses"}}}"#

        #expect(try Parser.parseTagSuggestions(data: Data(answer.utf8)) == [
            Self.glasses,
            SiteTagSuggestion(
                id: 9102,
                tag: SiteTag(namespace: .female, name: "sample glass frames"),
                canonical: SiteTag(namespace: .female, name: "sample spectacles")
            )
        ])
    }

    // With no match the site answers an empty array, as PHP writes an empty map.
    @Test
    func anAnswerWithoutAMatchIsAnEmptyArray() throws {
        #expect(try Parser.parseTagSuggestions(data: Data(#"{"tags":[]}"#.utf8)).isEmpty)
    }

    // An entry the field could not take is left out and the rest kept: a namespace the app does not know (for an
    // alias, its canonical tag's too), an empty name, a key that is no id. A `mid` of null is no alias, as on the site.
    @Test
    func anEntryTheFieldCouldNotTakeIsLeftOut() throws {
        let answer = #"{"tags":{"9001":{"ns":"female","tn":"sample glasses"},"9002":{"ns":"sample","tn":"sample"},"#
            + #""9003":{"ns":"female","tn":"sample lens","mid":9004,"mns":"sample","mtn":"sample"},"#
            + #""9005":{"ns":"female","tn":""},"9006":{"ns":"female","tn":"sample frame","mid":null},"#
            + #""x":{"ns":"female","tn":"sample keyless"}}}"#

        #expect(try Parser.parseTagSuggestions(data: Data(answer.utf8)) == [
            Self.glasses,
            SiteTagSuggestion(id: 9006, tag: SiteTag(namespace: .female, name: "sample frame"), canonical: nil)
        ])
    }

    // `login` is an expired session, `error` a refusal; anything else without the tags fails as a parse failure.
    @Test(arguments: [
        (#"{"login":"sample"}"#, AppError.loginRequired),
        (#"{"error":"Sample refusal"}"#, AppError.unknown),
        ("{}", AppError.parseFailed),
        ("[]", AppError.parseFailed),
        (#"{"tags":[{"ns":"female","tn":"sample glasses"}]}"#, AppError.parseFailed),
        (#"{"tags":"sample"}"#, AppError.parseFailed),
        ("<html></html>", AppError.parseFailed)
    ])
    func anAnswerWithoutTheTagsFails(answer: String, error: AppError) {
        #expect(throws: error) {
            try Parser.parseTagSuggestions(data: Data(answer.utf8))
        }
    }
}
