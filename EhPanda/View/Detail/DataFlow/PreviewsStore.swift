//
//  PreviewsStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/16.
//

import Foundation
import ComposableArchitecture

struct PreviewsState: Equatable {
    enum Route {
        case reading
    }
    struct CancelID: Hashable {
        let id = String(describing: PreviewsState.self)
    }

    @BindingState var route: Route?

    var gallery: Gallery = .empty
    var loadingState: LoadingState = .idle
    var databaseLoadingState: LoadingState = .loading

    var previewURLs = [Int: URL]()
    var previewConfig: PreviewConfig = .normal(rows: 4)

    var readingState = ReadingState()

    mutating func updatePreviewURLs(_ previewURLs: [Int: URL]) {
        self.previewURLs = self.previewURLs.merging(
            previewURLs, uniquingKeysWith: { stored, _ in stored }
        )
    }
}

enum PreviewsAction: BindableAction {
    case binding(BindingAction<PreviewsState>)
    case setNavigation(PreviewsState.Route?)
    case clearSubStates

    case syncPreviewURLs([Int: URL])
    case updateReadingProgress(Int)

    case teardown
    case fetchDatabaseInfos(String)
    case fetchDatabaseInfosDone(GalleryState)
    case fetchPreviewURLs(Int)
    case fetchPreviewURLsDone(Result<[Int: URL], AppError>)

    case reading(ReadingAction)
}

struct PreviewsEnvironment {
    let urlClient: URLClient
    let imageClient: ImageClient
    let deviceClient: DeviceClient
    let hapticsClient: HapticsClient
    let cookiesClient: CookiesClient
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
            state.readingState = .init()
            return .init(value: .reading(.teardown))

        case .syncPreviewURLs(let previewURLs):
            return environment.databaseClient
                .updatePreviewURLs(gid: state.gallery.id, previewURLs: previewURLs).fireAndForget()

        case .updateReadingProgress(let progress):
            return environment.databaseClient
                .updateReadingProgress(gid: state.gallery.id, progress: progress).fireAndForget()

        case .teardown:
            return .cancel(id: PreviewsState.CancelID())

        case .fetchDatabaseInfos(let gid):
            guard let gallery = environment.databaseClient.fetchGallery(gid: gid) else { return .none }
            state.gallery = gallery
            return environment.databaseClient.fetchGalleryState(gid: state.gallery.id)
                    .map(PreviewsAction.fetchDatabaseInfosDone).cancellable(id: PreviewsState.CancelID())

        case .fetchDatabaseInfosDone(let galleryState):
            if let previewConfig = galleryState.previewConfig {
                state.previewConfig = previewConfig
            }
            state.previewURLs = galleryState.previewURLs
            state.databaseLoadingState = .idle
            return .none

        case .fetchPreviewURLs(let index):
            guard state.loadingState != .loading,
                  let galleryURL = state.gallery.galleryURL
            else { return .none }
            state.loadingState = .loading
            let pageNum = state.previewConfig.pageNumber(index: index)
            return GalleryPreviewURLsRequest(galleryURL: galleryURL, pageNum: pageNum)
                .effect.map(PreviewsAction.fetchPreviewURLsDone).cancellable(id: PreviewsState.CancelID())

        case .fetchPreviewURLsDone(let result):
            state.loadingState = .idle

            switch result {
            case .success(let previewURLs):
                guard !previewURLs.isEmpty else {
                    state.loadingState = .failed(.notFound)
                    return .none
                }
                state.updatePreviewURLs(previewURLs)
                return .init(value: .syncPreviewURLs(previewURLs))
            case .failure(let error):
                state.loadingState = .failed(error)
            }
            return .none

        case .reading(.onPerformDismiss):
            return .init(value: .setNavigation(nil))

        case .reading:
            return .none
        }
    }
    .haptics(
        unwrapping: \.route,
        case: /PreviewsState.Route.reading,
        hapticsClient: \.hapticsClient
    )
    .binding(),
    readingReducer.pullback(
        state: \.readingState,
        action: /PreviewsAction.reading,
        environment: {
            .init(
                urlClient: $0.urlClient,
                imageClient: $0.imageClient,
                deviceClient: $0.deviceClient,
                hapticsClient: $0.hapticsClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                appDelegateClient: $0.appDelegateClient
            )
        }
    )
)
