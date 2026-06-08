//
//  DownloadsReducer.swift
//  EhPanda
//

import Foundation
import ComposableArchitecture

@Reducer
struct DownloadsReducer {
    @CasePathable
    enum Route: Equatable {
        case inspector(String)
        case detail(String)
        case reading(String)
    }

    private enum CancelID {
        case observeDownloads
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?
        var keyword = ""
        var filter: DownloadListFilter = .all
        var downloads = [DownloadedGallery]()
        var loadingState: LoadingState = .loading
        var hasLoadedInitialDownloads = false

        var detailState: Heap<DetailReducer.State?>
        var readingState = ReadingReducer.State()
        var inspectorState = DownloadInspectorReducer.State()
        var readingRequestID = UUID()

        init() {
            detailState = .init(.init())
        }

        var filteredDownloads: [DownloadedGallery] {
            downloads.filter {
                $0.matches(filter: filter)
                    && (
                        keyword.isEmpty
                            || $0.searchableText.caseInsensitiveContains(keyword)
                    )
            }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case clearSubStates

        case onAppear
        case teardown
        case bootstrapDownloads
        case fetchDownloads
        case fetchDownloadsDone([DownloadedGallery])
        case observeDownloads
        case observeDownloadsDone([DownloadedGallery])
        case refreshDownloads
        case refreshDownloadsDone
        case openReading(String)
        case openReadingDone(UUID, String, Result<(DownloadedGallery, DownloadManifest), AppError>)
        case toggleDownloadPause(String)
        case toggleDownloadPauseDone(Result<Void, AppError>)
        case updateDownload(String)
        case updateDownloadDone(Result<Void, AppError>)
        case deleteDownload(String)
        case deleteDownloadDone(Result<Void, AppError>)

        case detail(DetailReducer.Action)
        case reading(ReadingReducer.Action)
        case inspector(DownloadInspectorReducer.Action)
    }

    @Dependency(\.downloadClient) private var downloadClient

    var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.route) { _, state in
                state.route == nil ? .send(.clearSubStates) : .none
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                if case .detail(let gid) = route,
                   let download = state.downloads.first(where: { $0.gid == gid }) {
                    var detailState = DetailReducer.State()
                    detailState.gallery = download.gallery
                    state.detailState.wrappedValue = detailState
                } else if case .inspector(let gid) = route {
                    state.inspectorState = .init(gid: gid)
                }
                return route == nil ? .send(.clearSubStates) : .none

            case .clearSubStates:
                state.detailState.wrappedValue = .init()
                state.readingState = .init()
                state.inspectorState = .init()
                return .merge(
                    .send(.detail(.teardown)),
                    .send(.reading(.teardown)),
                    .send(.inspector(.teardown))
                )

            case .onAppear:
                guard !state.hasLoadedInitialDownloads else { return .none }
                state.hasLoadedInitialDownloads = true
                return .merge(
                    .send(.fetchDownloads),
                    .send(.observeDownloads),
                    .send(.bootstrapDownloads)
                )

            case .teardown:
                return .cancel(id: CancelID.observeDownloads)

            case .bootstrapDownloads:
                return .run { send in
                    await downloadClient.refreshDownloads()
                    await send(.refreshDownloadsDone)
                }

            case .fetchDownloads:
                state.loadingState = .loading
                return .run { send in
                    await send(.fetchDownloadsDone(await downloadClient.fetchDownloads()))
                }

            case .fetchDownloadsDone(let downloads), .observeDownloadsDone(let downloads):
                guard state.downloads != downloads || state.loadingState != .idle else {
                    return .none
                }
                state.downloads = downloads
                state.loadingState = .idle
                return .none

            case .observeDownloads:
                return .run { send in
                    for await downloads in downloadClient.observeDownloads() {
                        await send(.observeDownloadsDone(downloads))
                    }
                }
                .cancellable(id: CancelID.observeDownloads, cancelInFlight: true)

            case .refreshDownloads:
                return .run { send in
                    await downloadClient.refreshDownloads()
                    await send(.refreshDownloadsDone)
                }

            case .refreshDownloadsDone:
                return .none

            case .openReading(let gid):
                let requestID = UUID()
                state.readingRequestID = requestID
                state.readingState = .init(contentSource: .remote)
                if let download = state.downloads.first(where: { $0.gid == gid }) {
                    state.readingState.applyDownloadFallback(download)
                }
                return .run { send in
                    await send(
                        .openReadingDone(
                            requestID,
                            gid,
                            await downloadClient.loadManifest(gid)
                        )
                    )
                }

            case .openReadingDone(let requestID, let gid, let result):
                guard state.readingRequestID == requestID else { return .none }
                if case .success(let (download, manifest)) = result {
                    state.readingState = .init(contentSource: .local(download, manifest))
                }
                state.route = .reading(gid)
                return .none

            case .toggleDownloadPause(let gid):
                return .run { send in
                    await send(.toggleDownloadPauseDone(await downloadClient.togglePause(gid)))
                }

            case .toggleDownloadPauseDone(let result):
                if case .failure = result {
                    return .run { _ in
                        await downloadClient.reconcileDownloads()
                    }
                }
                return .none

            case .updateDownload(let gid):
                return .run { send in
                    await send(.updateDownloadDone(await downloadClient.retry(gid, .update)))
                }

            case .updateDownloadDone:
                return .none

            case .deleteDownload(let gid):
                return .run { send in
                    await send(.deleteDownloadDone(await downloadClient.delete(gid)))
                }

            case .deleteDownloadDone:
                return .none

            case .detail:
                return .none

            case .reading(.onPerformDismiss):
                return .send(.setNavigation(nil))

            case .reading:
                return .none

            case .inspector:
                return .none
            }
        }

        Scope(state: \.detailState.wrappedValue!, action: \.detail) {
            DetailReducer()
        }
        Scope(state: \.readingState, action: \.reading) {
            ReadingReducer()
        }
        Scope(state: \.inspectorState, action: \.inspector) {
            DownloadInspectorReducer()
        }
    }
}

private extension ReadingReducer.State {
    mutating func applyDownloadFallback(_ download: DownloadedGallery) {
        gallery = download.gallery
        language = .other
    }
}
