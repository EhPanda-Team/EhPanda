//
//  PreviewsReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/16.
//

import Foundation
import ComposableArchitecture

struct PreviewsReducer: ReducerProtocol {
    enum Route {
        case reading
    }

    private enum CancelID: CaseIterable {
        case fetchDatabaseInfos, fetchPreviewURLs
    }

    struct State: Equatable {
        @BindingState var route: Route?

        var gallery: Gallery = .empty
        var loadingState: LoadingState = .idle
        var databaseLoadingState: LoadingState = .loading

        var previewURLs = [Int: URL]()
        var previewConfig: PreviewConfig = .normal(rows: 4)

        var readingState = ReadingReducer.State()

        mutating func updatePreviewURLs(_ previewURLs: [Int: URL]) {
            self.previewURLs = self.previewURLs.merging(
                previewURLs, uniquingKeysWith: { stored, _ in stored }
            )
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case clearSubStates

        case syncPreviewURLs([Int: URL])
        case updateReadingProgress(Int)

        case teardown
        case fetchDatabaseInfos(String)
        case fetchDatabaseInfosDone(GalleryState)
        case fetchPreviewURLs(Int)
        case fetchPreviewURLsDone(Result<[Int: URL], AppError>)

        case reading(ReadingReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Reduce { state, action in
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
                return databaseClient
                    .updatePreviewURLs(gid: state.gallery.id, previewURLs: previewURLs).fireAndForget()

            case .updateReadingProgress(let progress):
                return databaseClient
                    .updateReadingProgress(gid: state.gallery.id, progress: progress).fireAndForget()

            case .teardown:
                return .cancel(ids: CancelID.allCases)

            case .fetchDatabaseInfos(let gid):
                guard let gallery = databaseClient.fetchGallery(gid: gid) else { return .none }
                state.gallery = gallery
                return databaseClient.fetchGalleryState(gid: state.gallery.id)
                    .map(Action.fetchDatabaseInfosDone).cancellable(id: CancelID.fetchDatabaseInfos)

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
                    .effect.map(Action.fetchPreviewURLsDone).cancellable(id: CancelID.fetchPreviewURLs)

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
            case: /Route.reading,
            hapticsClient: hapticsClient
        )

        Scope(state: \.readingState, action: /Action.reading, child: ReadingReducer.init)
    }
}
