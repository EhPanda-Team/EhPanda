import ComposableArchitecture

// Shared routing for gallery stacks. `nextScreen` maps a gallery element's delegate action to the
// screen that should be pushed next, so every host appends new elements the same way regardless of
// whether it stacks `GalleryPath` directly or nested under a `.gallery` case.
public enum GalleryNavigation {
    public static func nextScreen(for action: GalleryPath.Action) -> GalleryPath.State? {
        switch action {
        case let .detail(.delegate(delegate)):
            switch delegate {
            case .pushPreviews(let gid):
                return .previews(.init(gid: gid))
            case let .pushComments(gid, token, apiKey, galleryURL, comments, scrollCommentID):
                return .comments(.init(
                    gid: gid, token: token, apiKey: apiKey,
                    galleryURL: galleryURL, comments: comments, scrollCommentID: scrollCommentID
                ))
            case .pushDetailSearch(let keyword):
                return .detailSearch(.init(keyword: keyword))
            case let .pushGalleryInfos(gallery, galleryDetail):
                return .galleryInfos(.init(gallery: gallery, galleryDetail: galleryDetail))
            }

        case let .comments(.delegate(delegate)):
            switch delegate {
            case let .pushDetail(gid, deepLink):
                return .detail(.init(gid: gid, pendingDeepLink: deepLink))
            case .performedCommentAction:
                return nil
            }

        case let .detailSearch(.delegate(.pushDetail(gid))):
            return .detail(.init(gid: gid))

        default:
            return nil
        }
    }
}

extension StackState where Element == GalleryPath.State {
    // The id of the pushed `.detail` element for `gid`, so a comment action performed on a deeper
    // `.comments` screen can refresh the detail it belongs to.
    public func detailID(forGID gid: String) -> StackElementID? {
        for id in ids {
            guard let element = self[id: id] else { continue }
            if case .detail(let state) = element, state.gid == gid {
                return id
            }
        }
        return nil
    }
}
