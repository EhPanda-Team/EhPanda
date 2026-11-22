public import ComposableArchitecture
public import DetailFeature

// The Home tab's navigation stack: its five full-list screens plus the shared gallery drill-down,
// nested as a `.gallery` case so the gallery routing stays defined once in `GalleryPath`.
@Reducer
public enum HomePath {
    case frontPage(FrontPageReducer)
    case popular(PopularReducer)
    case toplists(ToplistsReducer)
    case watched(WatchedReducer)
    case history(HistoryReducer)
    case gallery(GalleryPath.Body = GalleryPath.body)
}

extension HomePath.State: Equatable {}

extension HomePath.State: GalleryRouteIdentifiable {
    public var routeKey: String {
        switch self {
        case .frontPage:
            return "frontPage"
        case .popular:
            return "popular"
        case .toplists:
            return "toplists"
        case .watched:
            return "watched"
        case .history:
            return "history"
        case .gallery(let state):
            return "gallery/\(state.routeKey)"
        }
    }
}

extension HomePath.State {
    /// The scoped action that flushes the reader this screen presents, if any: a list screen's own
    /// reader, or one presented inside the nested gallery drill-down.
    public var readingFlushAction: HomePath.Action? {
        switch self {
        case .frontPage(let state):
            state.reading.flushAction.map({ .frontPage(.reading($0)) })
        case .popular(let state):
            state.reading.flushAction.map({ .popular(.reading($0)) })
        case .toplists(let state):
            state.reading.flushAction.map({ .toplists(.reading($0)) })
        case .watched(let state):
            state.reading.flushAction.map({ .watched(.reading($0)) })
        case .history(let state):
            state.reading.flushAction.map({ .history(.reading($0)) })
        case .gallery(let state):
            state.readingFlushAction.map({ .gallery($0) })
        }
    }
}

extension StackState where Element == HomePath.State {
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
