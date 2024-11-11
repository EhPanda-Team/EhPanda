//
//  PreviewsReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/16.
//

import Foundation
import ComposableArchitecture

@Reducer
struct PreviewsReducer {
    @CasePathable
    enum Route: Equatable {
        case reading(EquatableVoid = .init())
    }

    private enum CancelID: CaseIterable {
        case fetchDatabaseInfos, fetchPreviewURLs
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?

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

    var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.route) { _, newValue in
                Reduce({ _, _ in newValue == nil ? .send(.clearSubStates) : .none })
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .send(.clearSubStates) : .none

            case .clearSubStates:
                state.readingState = .init()
                return .send(.reading(.teardown))

            case .syncPreviewURLs(let previewURLs):
                return .run { [state] _ in
                    await databaseClient.updatePreviewURLs(gid: state.gallery.id, previewURLs: previewURLs)
                }

            case .updateReadingProgress(let progress):
                return .run { [state] _ in
                    await databaseClient.updateReadingProgress(gid: state.gallery.id, progress: progress)
                }

            case .teardown:
                return .merge(CancelID.allCases.map(Effect.cancel(id:)))

            case .fetchDatabaseInfos(let gid):
                guard let gallery = databaseClient.fetchGallery(gid: gid) else { return .none }
                state.gallery = gallery
                return .run { [state] send in
                    guard let dbState = await databaseClient.fetchGalleryState(gid: state.gallery.id) else { return }
                    await send(.fetchDatabaseInfosDone(dbState))
                }
                .cancellable(id: CancelID.fetchDatabaseInfos)

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
                return .run { send in
                    let response = await GalleryPreviewURLsRequest(galleryURL: galleryURL, pageNum: pageNum).response()
                    await send(.fetchPreviewURLsDone(response))
                }
                .cancellable(id: CancelID.fetchPreviewURLs)

            case .fetchPreviewURLsDone(let result):
                state.loadingState = .idle

                switch result {
                case .success(let previewURLs):
                    guard !previewURLs.isEmpty else {
                        state.loadingState = .failed(.notFound)
                        return .none
                    }
                    state.updatePreviewURLs(previewURLs)
                    return .send(.syncPreviewURLs(previewURLs))
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .reading(.onPerformDismiss):
                return .send(.setNavigation(nil))

            case .reading:
                return .none
            }
        }
        .haptics(
            unwrapping: \.route,
            case: \.reading,
            hapticsClient: hapticsClient
        )

        Scope(state: \.readingState, action: \.reading, child: ReadingReducer.init)
    }
}
