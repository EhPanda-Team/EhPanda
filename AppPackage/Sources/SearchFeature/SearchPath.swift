import ComposableArchitecture
import DetailFeature

// The Search tab's navigation stack: the search-results screen plus the shared gallery drill-down,
// nested as a `.gallery` case so the gallery routing stays defined once in `GalleryPath`.
@Reducer
public enum SearchPath {
    case search(SearchReducer)
    case gallery(GalleryPath.Body = GalleryPath.body)
}

extension SearchPath.State: Equatable {}

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
