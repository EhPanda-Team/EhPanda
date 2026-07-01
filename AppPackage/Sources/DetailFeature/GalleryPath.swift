import ComposableArchitecture

// The shared set of gallery drill-down screens. Every gallery host drives a flat `StackState` of these
// elements: tapping a gallery pushes `.detail`, which in turn asks the host (via its `Delegate` actions)
// to push `.previews`/`.comments`/`.detailSearch`/`.galleryInfos`, and `.comments`/`.detailSearch` can
// push another `.detail`. Hosts that also stack their own list screens (Home, SearchRoot) nest this enum
// as a `.gallery(GalleryPath)` case so the gallery routing stays defined in one place.
@Reducer
public enum GalleryPath {
    case detail(DetailReducer)
    case previews(PreviewsReducer)
    case comments(CommentsReducer)
    case detailSearch(DetailSearchReducer)
    case galleryInfos(GalleryInfosReducer)
}

extension GalleryPath.State: Equatable {}
