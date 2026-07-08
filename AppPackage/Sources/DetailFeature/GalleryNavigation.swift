import ComposableArchitecture

// Shared routing for gallery stacks. `nextScreen` maps a gallery element's delegate action to the
// screen that should be pushed next, so every host appends new elements the same way regardless of
// whether it stacks `GalleryPath` directly or nested under a `.gallery` case.
public enum GalleryNavigation {
    // Centralizes the device branch every gallery host shares: iPad presents the detail as a modal
    // sheet via the host's `present` delegate; iPhone pushes it inline via the host's `push` action.
    // Actions are supplied as closures because host `Action` types are not `Sendable`.
    public static func routeGalleryDetail<Action>(
        isPad: @escaping @Sendable () async -> Bool,
        present: @escaping @Sendable () -> Action,
        push: @escaping @Sendable () -> Action
    ) -> Effect<Action> {
        .run { send in
            await send(await isPad() ? present() : push())
        }
    }

    public static func nextScreen(for action: GalleryPath.Action) -> GalleryPath.State? {
        switch action {
        case let .detail(.delegate(delegate)):
            switch delegate {
            case let .pushPreviews(gallery, previewConfig, language):
                return .previews(.init(
                    gallery: gallery,
                    previewConfig: previewConfig, language: language
                ))
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
            case let .pushDetail(gallery, deepLink):
                return .detail(.init(gallery: gallery, pendingDeepLink: deepLink))
            case .performedCommentAction:
                return nil
            }

        case let .detailSearch(.delegate(.pushDetail(gallery))):
            return .detail(.init(gallery: gallery))

        default:
            return nil
        }
    }
}

// A stable per-screen identity for suppressing duplicate adjacent pushes. Screens for the same
// destination share a key even when volatile per-init state differs (e.g. the `localPreviewRequestID`
// UUID on detail/previews states), which plain `Equatable` would treat as distinct.
public protocol GalleryRouteIdentifiable {
    var routeKey: String { get }
}

extension StackState where Element: GalleryRouteIdentifiable {
    // Append a screen unless it has the same route key as the current top of the stack, so a rapid
    // double-activation can't push the same detail twice. Only the adjacent element is compared, so
    // legitimate same-gid re-pushes through a deeper screen (Detail → Comments → same Detail) work.
    public mutating func appendGuardingDuplicate(_ element: Element) {
        guard last?.routeKey != element.routeKey else { return }
        append(element)
    }
}

extension GalleryPath.State: GalleryRouteIdentifiable {
    public var routeKey: String {
        switch self {
        case .detail(let state):
            return "detail:\(state.gid)"
        case .previews(let state):
            return "previews:\(state.gid)"
        case .comments(let state):
            return "comments:\(state.gid)"
        case .detailSearch(let state):
            return "detailSearch:\(state.keyword)"
        case .galleryInfos(let state):
            return "galleryInfos:\(state.gallery.id)"
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

    /// The `(id, action)` that flushes the reading session presented by the top element, if the top
    /// element presents one. Used by the app-level scene-phase router so a background force-quit
    /// persists the active reader's last debounced page from navigation state.
    public var topReadingFlush: (id: StackElementID, action: GalleryPath.Action)? {
        guard let id = ids.last, let action = self[id: id]?.readingFlushAction else { return nil }
        return (id, action)
    }
}

extension GalleryPath.State {
    /// The scoped action that flushes the reading session this gallery screen presents, if any. A
    /// reader is a `.reading` destination of `.detail`/`.previews`. A new gallery screen that can host
    /// a reader must be handled here (and any new *host* of a reader registered in `AppReducer`'s
    /// scene-phase router).
    public var readingFlushAction: GalleryPath.Action? {
        switch self {
        case .detail(let detail) where detail.destination?.reading != nil:
            return .detail(.destination(.presented(.reading(.flushReadingProgress))))
        case .previews(let previews) where previews.destination?.reading != nil:
            return .previews(.destination(.presented(.reading(.flushReadingProgress))))
        default:
            return nil
        }
    }
}
