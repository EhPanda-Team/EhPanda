import AppModels

// An audited reduction boundary (D-19).
//
// `TagNamespaceCounts.init(tags:)` is one of exactly two places in this module that accept app
// content, and everything it stores is closed vocabulary: a namespace key drawn from a fixed case
// set, and an integer. No tag text — neither a content string nor the raw namespace a tag was
// scraped under — is read into a stored property. That makes D-06's never-send guarantee a
// property of the type rather than an outcome of review, and `TagNamespaceCountsTests` proves it
// by reflecting over a constructed value rather than by reading this file.
//
// The counts ship exact rather than bucketed. That is D-16, an owner amendment giving D-08 its
// second documented exception; every other counter in this module still ships as a `CountBucket`.
// `init(tags: [GalleryTag])` takes a domain type rather than a `String`, so it is compliant with
// D-09 as literally written — the amendment D-19 records covers `SearchShape`, not this type.

/// The namespace a counted tag belongs to.
///
/// `unrecognized` is one shared bucket for every tag whose `rawNamespace` is not a known
/// `TagNamespace`. The raw namespace is scraped text and may not be reproduced, so an unknown
/// namespace contributes to a single anonymous key rather than minting a key spelled after itself.
public enum TagNamespaceKey: Hashable, Sendable {
    case known(TagNamespace)
    case unrecognized
}

extension TagNamespaceKey {
    var analyticsName: String {
        switch self {
        case .known(let namespace):
            namespace.rawValue

        case .unrecognized:
            "unrecognized"
        }
    }
}

public struct TagNamespaceCounts: Equatable, Sendable {
    /// How many tags the gallery carries in each namespace it actually uses.
    ///
    /// A namespace the gallery does not use is absent from the dictionary rather than present
    /// with a zero, so the key set is itself the "which namespaces are present" half of D-07 and
    /// the values are the "how many of each" half.
    public let countsByNamespace: [TagNamespaceKey: Int]

    public init(tags: [GalleryTag]) {
        var counts = [TagNamespaceKey: Int]()

        // A `GalleryTag` is one namespace holding the individual tags scraped under it, so the
        // count D-07 asks for is the number of contents, not the number of `GalleryTag` values.
        // Summing rather than assigning keeps that true even if a gallery ever presents the same
        // namespace twice.
        for tag in tags where tag.contents.isEmpty == false {
            let key = tag.namespace.map(TagNamespaceKey.known) ?? .unrecognized

            counts[key, default: 0] += tag.contents.count
        }

        self.countsByNamespace = counts
    }
}
