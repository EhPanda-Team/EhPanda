public import ComposableArchitecture
public import DetailFeature

// The Search tab's navigation stack: the search-results screen plus the shared gallery drill-down,
// nested as a `.gallery` case so the gallery routing stays defined once in `GalleryPath`.
@Reducer
public enum SearchPath {
    case search(SearchReducer)
    case gallery(GalleryPath.Body = GalleryPath.body)
}

extension SearchPath.State: Equatable {}

extension SearchPath.State: GalleryRouteIdentifiable {
    public var routeKey: String {
        switch self {
        case .search:
            return "search"
        case .gallery(let state):
            return "gallery/\(state.routeKey)"
        }
    }
}

extension SearchPath.State {
    /// The scoped action that flushes the reader this screen presents, if any: the results list's
    /// own reader, or one presented inside the nested gallery drill-down.
    public var readingFlushAction: SearchPath.Action? {
        switch self {
        case .search(let state):
            state.reading.flushAction.map({ .search(.reading($0)) })
        case .gallery(let state):
            state.readingFlushAction.map({ .gallery($0) })
        }
    }
}

extension StackState where Element == SearchPath.State {
    // Locate the pushed `.gallery(.detail)` element for `gid` so a comment action performed on a
    // deeper `.comments` screen can refresh the detail it belongs to.
    func galleryDetailID(forGID gid: String) -> StackElementID? {
        for id in ids {
            guard let element = self[id: id] else { continue }
            if case .gallery(.detail(let state)) = element, state.gid == gid {
                return id
            }
        }
        return nil
    }
}
