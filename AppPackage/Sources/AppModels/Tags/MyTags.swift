import Foundation
public import SwiftUI

// The account's My Tags as the site's My Tags page (`/mytags`) shows them, read live on both hosts on 2026-11-22
// (port of PR 462 item 10). The app keeps one cached copy, every tag set with its tags, and draws every tag's My Tags
// symbol from it (design approved 2026-11-22).

/// A colour as the site writes it, `#RRGGBB`, kept as its three 8-bit channels.
///
/// An edit sends the colour back in the same form, so the channels are stored as the site has them rather than as a
/// `Color`, whose floating-point components would not give the exact value back.
public struct SiteColor: Codable, Equatable, Hashable, Sendable {
    public let red: Int
    public let green: Int
    public let blue: Int

    /// Each channel is clamped to 0...255.
    public init(red: Int, green: Int, blue: Int) {
        self.red = min(max(red, 0), 255)
        self.green = min(max(green, 0), 255)
        self.blue = min(max(blue, 0), 255)
    }

    /// Reads `#RRGGBB` or `RRGGBB` in either case; anything else is nil.
    public init?(hex: String) {
        let digits = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit), let value = Int(digits, radix: 16)
        else { return nil }
        self.init(red: (value >> 16) & 0xFF, green: (value >> 8) & 0xFF, blue: value & 0xFF)
    }

    /// The site colour nearest to `color` in sRGB; a channel outside sRGB is clamped.
    public init(_ color: Color) {
        let resolved = color.resolve(in: EnvironmentValues())
        self.init(
            red: Int((Double(resolved.red) * 255).rounded()),
            green: Int((Double(resolved.green) * 255).rounded()),
            blue: Int((Double(resolved.blue) * 255).rounded())
        )
    }

    /// `#RRGGBB` in upper case, the form an edit sends and the page shows.
    public var hex: String {
        String(format: "#%02lX%02lX%02lX", red, green, blue)
    }

    public var color: Color {
        Color(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }
}

/// How a tag is kept in My Tags, the one choice the site's page offers per tag: neither watched nor hidden (the
/// design's Normal), watched or hidden.
public enum MyTagKind: CaseIterable, Equatable, Hashable, Sendable {
    case flagged
    case watched
    case hidden
}

/// One tag of a tag set, as its row on the site's My Tags page shows it.
public struct MyTag: Codable, Equatable, Hashable, Identifiable, Sendable {
    /// The weights the site's edit accepts ("Weight must be between 99 and -99").
    public static let weightRange = -99...99
    /// The weight a new tag starts at, the site's add row's default.
    public static let defaultWeight = 10

    /// The site's tag id, the one the gallery page's tag menu uses too.
    public let id: Int
    /// The full `namespace:tag`, as the row's preview titles it.
    public let name: String
    public var isWatched: Bool
    public var isHidden: Bool
    /// The tag's own colour; nil takes its set's.
    public var color: SiteColor?
    public var weight: Int

    public init(id: Int, name: String, isWatched: Bool, isHidden: Bool, color: SiteColor?, weight: Int) {
        self.id = id
        self.name = name
        self.isWatched = isWatched
        self.isHidden = isHidden
        self.color = color
        self.weight = weight
    }

    /// The two flags as the one choice the site's page makes; Hidden wins if both are set, and setting a kind sets
    /// both.
    public var kind: MyTagKind {
        get {
            if isHidden { return .hidden }
            return isWatched ? .watched : .flagged
        }
        set {
            isWatched = newValue == .watched
            isHidden = newValue == .hidden
        }
    }
}

/// A tag to add to a tag set, as the site's add row takes it.
public struct MyTagDraft: Equatable, Sendable {
    /// The full `namespace:tag`, or a bare tag, which the site files under temp.
    public let name: String
    public let kind: MyTagKind
    public let color: SiteColor?
    public let weight: Int

    public init(name: String, kind: MyTagKind, color: SiteColor?, weight: Int) {
        self.name = name
        self.kind = kind
        self.color = color
        self.weight = weight
    }
}

/// One tag set of My Tags: its name, whether it is enabled, its default colour, its tags in the page's order, and
/// whether the site offers to delete it.
public struct MyTagSet: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: Int
    /// Set here only by `MyTags.renaming(_:to:)`, so a rename shows at once (W-3 of quick 261126-wzf).
    public internal(set) var name: String
    /// Only the tags of an enabled set take effect, on the site and in the app's highlight.
    public var isEnabled: Bool
    /// The colour of the set's tags that have none of their own.
    public var color: SiteColor?
    public var tags: [MyTag]
    /// Whether the set's page, as last read, offers deleting the set (U-1 of quick 261126-udx). Which sets the site
    /// offers it for is its own rule, unknown here, so only the page says it; every page read brings its word into
    /// the cache with the rest of the set.
    ///
    /// Never stored: `CodingKeys` leaves it out, so a stored set keeps the shape it always had and decodes as before,
    /// and a set read back from storage offers nothing until a page of it is read again. A stored offer could outlive
    /// the page that made it.
    public private(set) var isDeletable = false

    /// The stored fields; `isDeletable` is left out on purpose (see its note).
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case isEnabled
        case color
        case tags
    }

    public init(
        id: Int,
        name: String,
        isEnabled: Bool,
        color: SiteColor?,
        tags: [MyTag],
        isDeletable: Bool = false
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.color = color
        self.tags = tags
        self.isDeletable = isDeletable
    }
}

/// How a tag of an enabled tag set stands out wherever tags are drawn: its state's symbol, in its colour (its own,
/// else its set's; nil draws the symbol in the label's colour).
public struct MyTagHighlight: Equatable, Hashable, Sendable {
    public let kind: MyTagKind
    public let color: SiteColor?

    public init(kind: MyTagKind, color: SiteColor?) {
        self.kind = kind
        self.color = color
    }
}

/// The account's My Tags: every tag set, in the order the site's picker lists them, and the set last chosen on the
/// My Tags page.
///
/// Its updates return a new value rather than mutate: the cache is written through `Shared.withLock`, which returns
/// its closure's value and is not `@discardableResult`.
public struct MyTags: Codable, Equatable, Hashable, Sendable {
    public var tagSets: [MyTagSet]
    /// The tag set last chosen on the My Tags page, the one Add to My Tags adds to; nil until one is chosen.
    public var selectedTagSetID: Int?

    public init(tagSets: [MyTagSet], selectedTagSetID: Int? = nil) {
        self.tagSets = tagSets
        self.selectedTagSetID = selectedTagSetID
    }

    /// The set last chosen, else the site's first.
    public var selectedTagSet: MyTagSet? {
        tagSets.first(where: { $0.id == selectedTagSetID }) ?? tagSets.first
    }

    /// The highlight of the tag named `fullName` (`namespace:tag`): its entry in the first enabled set holding it, in
    /// the picker's order; nil when no enabled set does.
    public func highlight(fullName: String) -> MyTagHighlight? {
        for tagSet in tagSets where tagSet.isEnabled {
            if let tag = tagSet.tags.first(where: { $0.name == fullName }) {
                return MyTagHighlight(kind: tag.kind, color: tag.color ?? tagSet.color)
            }
        }
        return nil
    }

    /// The cache with `tagSetID` as the set last chosen.
    public func selecting(_ tagSetID: Int?) -> MyTags {
        MyTags(tagSets: tagSets, selectedTagSetID: tagSetID)
    }

    /// The cache with `page`'s set in place of the one stored, in the order of the page's picker. The page's own set
    /// takes its place even when the cache lacks it, as the set New Tag Set made does when the page reads it (N-6 of
    /// quick 261126-pfh); any other set the picker lists but the cache lacks stays out until the next fetch, and a set
    /// the picker no longer lists is dropped.
    public func applying(_ page: MyTagsPage) -> MyTags {
        let tagSets = page.tagSetIDs.compactMap { id in
            id == page.tagSet.id ? page.tagSet : self.tagSets.first(where: { $0.id == id })
        }
        return MyTags(tagSets: tagSets, selectedTagSetID: selectedTagSetID)
    }

    /// The cache with `tagSet` in place of the set of the same id.
    public func updating(_ tagSet: MyTagSet) -> MyTags {
        MyTags(tagSets: tagSets.map({ $0.id == tagSet.id ? tagSet : $0 }), selectedTagSetID: selectedTagSetID)
    }

    /// The cache with the set `tagSetID` named `name` (W-3 of quick 261126-wzf): the picker shows a rename at once,
    /// and a rename that failed puts the old name back the same way.
    public func renaming(_ tagSetID: Int, to name: String) -> MyTags {
        let tagSets = self.tagSets.map { tagSet in
            guard tagSet.id == tagSetID else { return tagSet }
            var renamed = tagSet
            renamed.name = name
            return renamed
        }
        return MyTags(tagSets: tagSets, selectedTagSetID: selectedTagSetID)
    }

    /// The cache with `tag` in place of the tag of the same id in the set `tagSetID`.
    public func updating(_ tag: MyTag, inTagSet tagSetID: Int) -> MyTags {
        let tagSets = self.tagSets.map { tagSet in
            guard tagSet.id == tagSetID else { return tagSet }
            var updated = tagSet
            updated.tags = tagSet.tags.map({ $0.id == tag.id ? tag : $0 })
            return updated
        }
        return MyTags(tagSets: tagSets, selectedTagSetID: selectedTagSetID)
    }
}

/// One tag set's page of the site's My Tags, as it is fetched and as the site answers a posted form.
public struct MyTagsPage: Equatable, Sendable {
    /// The set the page shows, the one its picker has selected.
    public let tagSet: MyTagSet
    /// Every set the page's picker lists, in its order.
    public let tagSetIDs: [Int]
    /// The edit API's credentials the page's script carries; they are kept in memory only.
    public let apiuid: Int
    public let apikey: String
    /// The site's reason for refusing a posted form (`#msg`), nil when it took it.
    public let message: String?

    public init(tagSet: MyTagSet, tagSetIDs: [Int], apiuid: Int, apikey: String, message: String?) {
        self.tagSet = tagSet
        self.tagSetIDs = tagSetIDs
        self.apiuid = apiuid
        self.apikey = apikey
        self.message = message
    }
}

/// Every tag set of My Tags, with the edit API's credentials of the first page.
public struct MyTagsResponse: Equatable, Sendable {
    public let myTags: MyTags
    public let apiuid: Int
    public let apikey: String

    public init(myTags: MyTags, apiuid: Int, apikey: String) {
        self.myTags = myTags
        self.apiuid = apiuid
        self.apikey = apikey
    }
}

/// The edit API's answer: taken, or refused with the site's reason.
public enum MyTagEditReply: Equatable, Sendable {
    case accepted
    case refused(String)
}

extension GalleryTag.Content {
    /// The tag's full name as My Tags titles it, `namespace:tag`.
    public var myTagsName: String { "\(rawNamespace):\(text)" }

    /// The My Tags symbol the tag carries wherever tags are drawn: from the cached My Tags once it has loaded; before
    /// that, the colour a list page gave the tag stands in, drawn as a tag of a set, since a list page gives no state.
    public func myTagHighlight(in myTags: MyTags?) -> MyTagHighlight? {
        if let myTags {
            return myTags.highlight(fullName: myTagsName)
        }
        return backgroundColor.map({ MyTagHighlight(kind: .flagged, color: SiteColor($0)) })
    }
}
