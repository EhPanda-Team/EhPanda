@testable import AnalyticsClient
import AppModels
import Testing

@Suite
struct TagNamespaceCountsTests {
    // Distinctive enough that a substring search for it cannot collide with a bucket spelling, a
    // namespace name or any other rendering the reduced value legitimately contains.
    private static let sentinel = "zqxsentineltag4718"

    private func tag(namespace: String, contents: [String]) -> GalleryTag {
        GalleryTag(
            rawNamespace: namespace,
            contents: contents.map({
                GalleryTag.Content(rawNamespace: namespace, text: $0, isVotedUp: false, isVotedDown: false)
            })
        )
    }

    @Test
    func anEmptyTagListYieldsNoCounts() {
        let counts = TagNamespaceCounts(tags: [])

        #expect(counts.countsByNamespace.isEmpty)
    }

    @Test
    func oneNamespaceWithOneTagCountsOne() {
        let counts = TagNamespaceCounts(tags: [tag(namespace: "artist", contents: ["someone"])])

        #expect(counts.countsByNamespace == [.known(.artist): 1])
    }

    // Counts are exact per D-16, an owner amendment giving D-08 a second documented exception, so
    // six tags read as 6 rather than collapsing into the `6-20` bucket every other counter uses.
    // The value itself is the assertion here; there is no bucket boundary left to sit on.
    @Test
    func sixTagsInOneNamespaceCountExactlySix() {
        let contents = (0..<6).map({ "tag-\($0)" })
        let counts = TagNamespaceCounts(tags: [tag(namespace: "female", contents: contents)])

        #expect(counts.countsByNamespace == [.known(.female): 6])
    }

    // D-07 names `female` and `male` explicitly, having reinstated them after they were
    // recommended for removal. They are counted like any other namespace.
    @Test
    func severalNamespacesAreCountedIndependently() {
        let counts = TagNamespaceCounts(tags: [
            tag(namespace: "female", contents: ["one", "two", "three"]),
            tag(namespace: "male", contents: ["one", "two"]),
            tag(namespace: "language", contents: ["one"]),
            tag(namespace: "parody", contents: ["one", "two", "three", "four"])
        ])

        #expect(counts.countsByNamespace == [
            .known(.female): 3,
            .known(.male): 2,
            .known(.language): 1,
            .known(.parody): 4
        ])
    }

    // A namespace absent from the gallery is absent from the dictionary rather than present with
    // a zero, so the key set is itself the "which namespaces are present" half of D-07.
    @Test
    func namespacesTheGalleryDoesNotUseAreAbsentRatherThanZero() {
        let counts = TagNamespaceCounts(tags: [tag(namespace: "group", contents: ["one"])])

        #expect(counts.countsByNamespace.count == 1)
        #expect(counts.countsByNamespace[.known(.artist)] == nil)
        #expect(counts.countsByNamespace[.unrecognized] == nil)
    }

    // The raw namespace of an unrecognized tag is scraped text, so it may not become a key of its
    // own. Every unrecognized tag lands on one shared anonymous key instead.
    @Test
    func unrecognizedNamespacesCollapseOntoOneKey() {
        let counts = TagNamespaceCounts(tags: [
            tag(namespace: "notanamespace", contents: ["one"]),
            tag(namespace: "alsonotanamespace", contents: ["two", "three"]),
            tag(namespace: "female", contents: ["four"])
        ])

        #expect(counts.countsByNamespace == [.unrecognized: 3, .known(.female): 1])
    }

    @Test
    func aTagCarryingNoContentsContributesNoKey() {
        let counts = TagNamespaceCounts(tags: [
            tag(namespace: "female", contents: []),
            tag(namespace: "male", contents: ["one"])
        ])

        #expect(counts.countsByNamespace == [.known(.male): 1])
    }

    @Test
    func everyNamespaceKeySpellingIsDistinct() {
        var spellings = TagNamespace.allCases.map({ TagNamespaceKey.known($0).analyticsName })
        spellings.append(TagNamespaceKey.unrecognized.analyticsName)

        #expect(Set(spellings).count == spellings.count)
        #expect(spellings.allSatisfy({ $0.isEmpty == false }))
    }

    // The point of this whole type. Everything the reduction was handed is a distinctive sentinel
    // — the tag text, and the raw namespace of the unrecognized tag — and none of it may appear
    // anywhere in the constructed value's stored graph. This is what makes D-06 provable rather
    // than reviewed: exact counts do not weaken it, because what it proves is that no tag *text*
    // survives, which is orthogonal to whether the counts are bucketed.
    @Test
    func noTagTextSurvivesTheReduction() {
        let counts = TagNamespaceCounts(tags: [
            tag(namespace: "female", contents: [Self.sentinel, "\(Self.sentinel)-second"]),
            tag(namespace: Self.sentinel, contents: ["\(Self.sentinel)-unrecognized"])
        ])
        let renderings = [String(describing: counts)] + Mirror(reflecting: counts).leafRenderings

        // Guards against a vacuous pass: an empty rendering list would satisfy the loop below
        // without having inspected anything at all.
        #expect(renderings.count > 1)

        for rendering in renderings {
            #expect(rendering.contains(Self.sentinel) == false, "the sentinel survived in \(rendering)")
        }
    }
}
