//
//  PreviewsReducer.swift
//  EhPanda
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
        case fetchDatabaseInfos
        case observeDownloads
        case loadLocalPreviewURLs
        case fetchPreviewURLs
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?

        var gallery: Gallery = .empty
        var loadingState: LoadingState = .idle
        var databaseLoadingState: LoadingState = .loading

        var previewURLs = [Int: URL]()
        var localPreviewURLs = [Int: URL]()
        var previewConfig: PreviewConfig = .normal(rows: 4)
        var localPreviewRequestID = UUID()

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
        case observeDownloads(String)
        case observeDownloadsDone([DownloadedGallery])
        case loadLocalPreviewURLs(String)
        case loadLocalPreviewURLsDone(UUID, [Int: URL])
        case openReading(Int)
        case openReadingDone(Result<(DownloadedGallery, DownloadManifest), AppError>)
        case fetchPreviewURLs(Int)
        case fetchPreviewURLsDone(Result<[Int: URL], AppError>)

        case reading(ReadingReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.downloadClient) private var downloadClient
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
                return .merge(
                    .run { [state] send in
                        guard let dbState = await databaseClient.fetchGalleryState(
                            gid: state.gallery.id
                        ) else { return }
                        await send(.fetchDatabaseInfosDone(dbState))
                    }
                    .cancellable(id: CancelID.fetchDatabaseInfos),
                    .send(.observeDownloads(gid)),
                    .send(.loadLocalPreviewURLs(gid))
                )

            case .fetchDatabaseInfosDone(let galleryState):
                if let previewConfig = galleryState.previewConfig {
                    state.previewConfig = previewConfig
                }
                state.previewURLs = galleryState.previewURLs
                state.databaseLoadingState = .idle
                return .none

            case .observeDownloads(let gid):
                guard gid.isValidGID else { return .none }
                return .run { send in
                    var previousRelevantDownloads = [DownloadedGallery]()
                    var hadRelevantDownloads = false
                    for await downloads in downloadClient.observeDownloads() {
                        let relevantDownloads = downloads.filter { $0.gid == gid }
                        let hasRelevantDownloads = !relevantDownloads.isEmpty
                        guard hasRelevantDownloads || hadRelevantDownloads else { continue }
                        if relevantDownloads == previousRelevantDownloads {
                            hadRelevantDownloads = hasRelevantDownloads
                            continue
                        }
                        previousRelevantDownloads = relevantDownloads
                        hadRelevantDownloads = hasRelevantDownloads
                        await send(.observeDownloadsDone(relevantDownloads))
                    }
                }
                .cancellable(id: CancelID.observeDownloads, cancelInFlight: true)

            case .observeDownloadsDone:
                return .send(.loadLocalPreviewURLs(state.gallery.id))

            case .loadLocalPreviewURLs(let gid):
                guard gid.isValidGID else {
                    state.localPreviewRequestID = UUID()
                    state.localPreviewURLs = .init()
                    return .none
                }
                let requestID = UUID()
                state.localPreviewRequestID = requestID
                return .run { send in
                    let localPreviewURLs: [Int: URL]
                    switch await downloadClient.loadLocalPageURLs(gid) {
                    case .success(let pageURLs):
                        localPreviewURLs = pageURLs
                    case .failure:
                        localPreviewURLs = [:]
                    }
                    await send(.loadLocalPreviewURLsDone(requestID, localPreviewURLs))
                }
                .cancellable(id: CancelID.loadLocalPreviewURLs, cancelInFlight: true)

            case .loadLocalPreviewURLsDone(let requestID, let localPreviewURLs):
                guard state.localPreviewRequestID == requestID else { return .none }
                guard state.localPreviewURLs != localPreviewURLs else { return .none }
                state.localPreviewURLs = localPreviewURLs
                return .none

            case .openReading:
                state.readingState = .init(contentSource: .remote)
                return .run { [galleryID = state.gallery.id] send in
                    guard galleryID.isValidGID else {
                        await send(.openReadingDone(.failure(.notFound)))
                        return
                    }
                    await send(.openReadingDone(await downloadClient.loadManifest(galleryID)))
                }

            case .openReadingDone(let result):
                if case .success(let (download, manifest)) = result {
                    state.readingState = .init(contentSource: .local(download, manifest))
                } else {
                    state.readingState.contentSource = .remote
                    state.readingState.localPageURLs = state.localPreviewURLs
                }
                state.route = .reading()
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
