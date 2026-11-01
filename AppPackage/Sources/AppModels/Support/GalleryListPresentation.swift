import Foundation

/// The independently remembered gallery list contexts.
public enum GalleryListScope: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Keeps the value it was stored with before the Front Page rename.
    case frontPage = "frontpage"
    case popular
    case toplists
    case favorites
    case search
    case downloads
    case watched
    case history

    public var id: Self { self }
}

/// The two supported presentations for a gallery list.
public enum GalleryListDisplayMode: Int, Codable, CaseIterable, Identifiable, Sendable {
    case row
    case grid

    public var id: Int { rawValue }
}

/// Persisted presentation choices for each semantic list scope.
public struct GalleryListPresentation: Codable, Equatable, Sendable {
    public var frontPage: GalleryListDisplayMode
    public var popular: GalleryListDisplayMode
    public var toplists: GalleryListDisplayMode
    public var favorites: GalleryListDisplayMode
    public var search: GalleryListDisplayMode
    public var downloads: GalleryListDisplayMode
    public var watched: GalleryListDisplayMode
    public var history: GalleryListDisplayMode

    /// `frontpage` is the key saved before the Front Page rename, so existing choices stay readable.
    private enum CodingKeys: String, CodingKey {
        case frontPage = "frontpage"
        case popular, toplists, favorites, search, downloads, watched, history
    }

    public init(
        frontPage: GalleryListDisplayMode = .row,
        popular: GalleryListDisplayMode = .row,
        toplists: GalleryListDisplayMode = .row,
        favorites: GalleryListDisplayMode = .row,
        search: GalleryListDisplayMode = .row,
        downloads: GalleryListDisplayMode = .row,
        watched: GalleryListDisplayMode = .row,
        history: GalleryListDisplayMode = .row
    ) {
        self.frontPage = frontPage
        self.popular = popular
        self.toplists = toplists
        self.favorites = favorites
        self.search = search
        self.downloads = downloads
        self.watched = watched
        self.history = history
    }

    public subscript(scope: GalleryListScope) -> GalleryListDisplayMode {
        get {
            switch scope {
            case .frontPage: frontPage
            case .popular: popular
            case .toplists: toplists
            case .favorites: favorites
            case .search: search
            case .downloads: downloads
            case .watched: watched
            case .history: history
            }
        }
        set {
            switch scope {
            case .frontPage: frontPage = newValue
            case .popular: popular = newValue
            case .toplists: toplists = newValue
            case .favorites: favorites = newValue
            case .search: search = newValue
            case .downloads: downloads = newValue
            case .watched: watched = newValue
            case .history: history = newValue
            }
        }
    }
}
