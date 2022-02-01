//
//  PreviewsStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/16.
//

import ComposableArchitecture

struct PreviewsState: Equatable {
    enum Route {
        case reading
    }
    struct CancelID: Hashable {
        let id = String(describing: PreviewsState.self)
    }

    @BindableState var route: Route?
    let gallery: Gallery

    var loadingState: LoadingState = .idle
    var databaseLoadingState: LoadingState = .loading

    var previews = [Int: String]()
    var previewConfig: PreviewConfig = .normal(rows: 4)

    var readingState = ReadingState(gallery: .empty)

    mutating func updatePreviews(_ previews: [Int: String]) {
        self.previews = self.previews.merging(
            previews, uniquingKeysWith: { stored, _ in stored }
        )
    }
}

enum PreviewsAction: BindableAction {
    case binding(BindingAction<PreviewsState>)
    case setNavigation(PreviewsState.Route?)
    case clearSubStates
    case setupReadingState

    case syncPreviews([Int: String])
    case updateReadingProgress(Int)

    case cancelFetching
    case fetchDatabaseInfos
    case fetchDatabaseInfosDone(GalleryState)
    case fetchPreviews(Int)
    case fetchPreviewsDone(Result<[Int: String], AppError>)

    case reading(ReadingAction)
}

struct PreviewsEnvironment {
    let urlClient: URLClient
    let imageClient: ImageClient
    let deviceClient: DeviceClient
    let hapticClient: HapticClient
    let databaseClient: DatabaseClient
    let clipboardClient: ClipboardClient
    let appDelegateClient: AppDelegateClient
}

let previewsReducer = Reducer<PreviewsState, PreviewsAction, PreviewsEnvironment>.combine(
    .init { state, action, environment in
        switch action {
        case .binding(\.$route):
            return state.route == nil ? .init(value: .clearSubStates) : .none

        case .binding:
            return .none

        case .setNavigation(let route):
            state.route = route
            return route == nil ? .init(value: .clearSubStates) : .none

        case .clearSubStates:
            return .merge(
                .init(value: .setupReadingState),
                .init(value: .reading(.teardown))
            )

        case .setupReadingState:
            state.readingState = .init(gallery: state.gallery)
            return .none

        case .syncPreviews(let previews):
            guard !state.gallery.id.isValidGID else { return .none }
            return environment.databaseClient
                .updatePreviews(gid: state.gallery.id, previews: previews).fireAndForget()

        case .updateReadingProgress(let progress):
            guard !state.gallery.id.isValidGID else { return .none }
            return environment.databaseClient
                .updateReadingProgress(gid: state.gallery.id, progress: progress).fireAndForget()

        case .cancelFetching:
            return .cancel(id: PreviewsState.CancelID())

        case .fetchDatabaseInfos:
            return environment.databaseClient.fetchGalleryState(state.gallery.id)
                    .map(PreviewsAction.fetchDatabaseInfosDone).cancellable(id: PreviewsState.CancelID())

        case .fetchDatabaseInfosDone(let galleryState):
            if let previewConfig = galleryState.previewConfig {
                state.previewConfig = previewConfig
            }
            state.previews = galleryState.previews
            state.databaseLoadingState = .idle
            return .init(value: .setupReadingState)

        case .fetchPreviews(let index):
            guard state.loadingState != .loading else { return .none }
            state.loadingState = .loading
            let pageNum = state.previewConfig.pageNumber(index: index)
            return GalleryPreviewsRequest(galleryURL: state.gallery.galleryURL, pageNum: pageNum)
                .effect.map(PreviewsAction.fetchPreviewsDone).cancellable(id: PreviewsState.CancelID())

        case .fetchPreviewsDone(let result):
            state.loadingState = .idle

            switch result {
            case .success(let previews):
                guard !previews.isEmpty else {
                    state.loadingState = .failed(.notFound)
                    return .none
                }
                state.updatePreviews(previews)
                return .init(value: .syncPreviews(previews))
            case .failure(let error):
                state.loadingState = .failed(error)
            }
            return .none

        case .reading:
            return .none
        }
    }
    .binding(),
    readingReducer.pullback(
        state: \.readingState,
        action: /PreviewsAction.reading,
        environment: {
            .init(
                urlClient: $0.urlClient,
                imageClient: $0.imageClient,
                deviceClient: $0.deviceClient,
                hapticClient: $0.hapticClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                appDelegateClient: $0.appDelegateClient
            )
        }
    )
)
