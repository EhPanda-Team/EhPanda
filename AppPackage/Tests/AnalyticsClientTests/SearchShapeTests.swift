@testable import AnalyticsClient
import AppModels
import Testing

// One fixture per assertion pair. A named struct rather than a positional tuple: the table below
// is long, and `.0`/`.1` reads would carry no meaning at the assertion site.
struct SearchShapeFixture: Sendable {
    let keyword: String
    let wordCount: CountBucket
    let usedTagSyntax: Bool
}

@Suite
struct SearchShapeTests {
    // Distinctive enough that a substring search for it cannot collide with a bucket spelling or
    // any other rendering the reduced value legitimately contains.
    private static let sentinel = "zqxsentinelkeyword4718"

    private func words(_ count: Int) -> String {
        (0..<count).map({ String($0) }).joined(separator: " ")
    }

    @Test(arguments: [
        SearchShapeFixture(keyword: "", wordCount: .zero, usedTagSyntax: false),
        SearchShapeFixture(keyword: "   \t ", wordCount: .zero, usedTagSyntax: false),
        SearchShapeFixture(keyword: "artbook", wordCount: .one, usedTagSyntax: false),
        SearchShapeFixture(keyword: "  artbook  ", wordCount: .one, usedTagSyntax: false),
        SearchShapeFixture(keyword: "one two three four five", wordCount: .twoToFive, usedTagSyntax: false),
        SearchShapeFixture(keyword: "female:sole female", wordCount: .twoToFive, usedTagSyntax: true),
        SearchShapeFixture(keyword: "f:sole female", wordCount: .twoToFive, usedTagSyntax: true),
        SearchShapeFixture(keyword: "cos:someone", wordCount: .one, usedTagSyntax: true),
        SearchShapeFixture(keyword: "-female:sole", wordCount: .one, usedTagSyntax: true),
        SearchShapeFixture(keyword: "\"female:big breasts$\"", wordCount: .twoToFive, usedTagSyntax: true),
        SearchShapeFixture(keyword: "artbook language:english", wordCount: .twoToFive, usedTagSyntax: true),
        SearchShapeFixture(keyword: "note:this is not a namespace", wordCount: .twoToFive, usedTagSyntax: false),
        SearchShapeFixture(keyword: "https://example.com", wordCount: .one, usedTagSyntax: false),
        SearchShapeFixture(keyword: "10:30 showtime", wordCount: .twoToFive, usedTagSyntax: false),
        SearchShapeFixture(keyword: "日本語🐱", wordCount: .one, usedTagSyntax: false)
    ])
    func searchShapeReducesEveryKeywordShape(fixture: SearchShapeFixture) {
        let shape = SearchShape(keyword: fixture.keyword)

        #expect(shape.wordCount == fixture.wordCount)
        #expect(shape.usedTagSyntax == fixture.usedTagSyntax)
    }

    // The word count is the one part of the shape that goes through the shared bucket vocabulary,
    // so both sides of every boundary it can land on are exercised.
    @Test
    func wordCountFollowsTheSharedBucketBoundaries() {
        #expect(SearchShape(keyword: words(1)).wordCount == .one)
        #expect(SearchShape(keyword: words(2)).wordCount == .twoToFive)
        #expect(SearchShape(keyword: words(5)).wordCount == .twoToFive)
        #expect(SearchShape(keyword: words(6)).wordCount == .sixToTwenty)
        #expect(SearchShape(keyword: words(20)).wordCount == .sixToTwenty)
        #expect(SearchShape(keyword: words(21)).wordCount == .twentyOneToFifty)
    }

    // Length ships exact — the original documented exception to D-08's bucketing rule, permitted
    // by D-07 with the owner's reasoning recorded. It counts grapheme clusters, so a multi-byte
    // keyword measures what a reader would call its length rather than its UTF-8 byte count.
    @Test
    func keywordLengthIsTheExactGraphemeCount() {
        #expect(SearchShape(keyword: "").keywordLength == 0)
        #expect(SearchShape(keyword: "abc").keywordLength == 3)
        #expect(SearchShape(keyword: " abc ").keywordLength == 5)
        #expect(SearchShape(keyword: "日本語🐱").keywordLength == 4)
    }

    @Test
    func anEmptyKeywordReducesToTheEmptyShape() {
        let shape = SearchShape(keyword: "")

        #expect(shape.wordCount == .zero)
        #expect(shape.usedTagSyntax == false)
        #expect(shape.keywordLength == 0)
    }

    // The point of this whole type, and the reason D-19 was worth an amendment: the keyword is a
    // bare `String` on a public initializer, which D-09 forbids everywhere else in this module.
    // What buys that exception is this test — the keyword text is a distinctive sentinel, and none
    // of it may appear anywhere in the constructed value's stored graph.
    @Test
    func noKeywordTextSurvivesTheReduction() {
        let shape = SearchShape(keyword: "female:\(Self.sentinel) \(Self.sentinel) \(Self.sentinel)-tail")
        let renderings = [String(describing: shape)] + Mirror(reflecting: shape).leafRenderings

        // Guards against a vacuous pass: an empty rendering list would satisfy the loop below
        // without having inspected anything at all.
        #expect(renderings.count > 1)

        for rendering in renderings {
            #expect(rendering.contains(Self.sentinel) == false, "the sentinel survived in \(rendering)")
        }
    }

    // A length is a number, so it cannot carry text — but a future change storing the keyword to
    // derive something new would be caught here even if the sentinel happened to be numeric.
    @Test
    func theReducedShapeStoresOnlyThreeValues() {
        let shape = SearchShape(keyword: "female:\(Self.sentinel)")
        let labels = Mirror(reflecting: shape).children.compactMap({ $0.label })

        #expect(labels == ["wordCount", "usedTagSyntax", "keywordLength"])
    }
}
