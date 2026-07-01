import ComposableArchitecture
import DetailFeature

// The Home tab's navigation stack: its five full-list screens plus the shared gallery drill-down,
// nested as a `.gallery` case so the gallery routing stays defined once in `GalleryPath`.
@Reducer
public enum HomePath {
    case frontpage(FrontpageReducer)
    case popular(PopularReducer)
    case toplists(ToplistsReducer)
    case watched(WatchedReducer)
    case history(HistoryReducer)
    case gallery(GalleryPath.Body = GalleryPath.body)
}

extension HomePath.State: Equatable {}

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
