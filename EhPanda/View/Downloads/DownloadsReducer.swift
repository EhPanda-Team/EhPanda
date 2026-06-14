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
        case folderManager(EquatableVoid = .init())
    }

    private enum CancelID {
        case observeDownloads
        case fetchFolders
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?
        var keyword = ""
        var folderFilter: DownloadFolderFilter = .all
        var folders = [String]()
        var downloads = [DownloadedGallery]()
        var loadingState: LoadingState = .loading
        var hasLoadedInitialDownloads = false

        var detailState: Heap<DetailReducer.State?>
        var readingState = ReadingReducer.State()
        var inspectorState = DownloadInspectorReducer.State()
        var folderManagerState = FolderManagerReducer.State()
        var readingRequestID = UUID()

        init() {
            detailState = .init(.init())
        }

        var filteredDownloads: [DownloadedGallery] {
            downloads.filter {
                $0.matches(folderFilter: folderFilter)
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
        case fetchDownloads
        case fetchDownloadsDone([DownloadedGallery])
        case observeDownloads
        case observeDownloadsDone([DownloadedGallery])
        case refreshDownloads
        case refreshDownloadsDone
        case fetchFolders
        case fetchFoldersDone([String])
        case moveDownload(String, String)
        case moveDownloadDone(Result<Void, AppError>)
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
        case folderManager(FolderManagerReducer.Action)
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
                    detailState.gid = download.gid
                    detailState.gallery = download.gallery
                    _ = DetailReducer().applyDownload(download, state: &detailState)
                    state.detailState.wrappedValue = detailState
                } else if case .inspector(let gid) = route {
                    state.inspectorState = .init(gid: gid)
                }
                return route == nil ? .send(.clearSubStates) : .none

            case .clearSubStates:
                state.detailState.wrappedValue = .init()
                state.readingState = .init()
                state.inspectorState = .init()
                state.folderManagerState = .init()
                return .merge(
                    .send(.detail(.teardown)),
                    .send(.reading(.teardown)),
                    .send(.inspector(.teardown)),
                    .send(.folderManager(.teardown))
                )

            case .onAppear:
                guard !state.hasLoadedInitialDownloads else { return .send(.fetchFolders) }
                state.hasLoadedInitialDownloads = true
                return .merge(
                    .send(.fetchDownloads),
                    .send(.observeDownloads),
                    .send(.fetchFolders)
                )

            case .teardown:
                return .merge(
                    .cancel(id: CancelID.observeDownloads),
                    .cancel(id: CancelID.fetchFolders)
                )

            case .fetchDownloads:
                state.loadingState = .loading
                return .run { send in
                    await send(.fetchDownloadsDone(try await downloadClient.fetchDownloads()))
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
                return .send(.fetchFolders)

            case .fetchFolders:
                return .run { send in
                    await send(.fetchFoldersDone(try await downloadClient.fetchFolders()))
                }
                .cancellable(id: CancelID.fetchFolders, cancelInFlight: true)

            case .fetchFoldersDone(let folders):
                state.folders = folders
                if case .folder(let name) = state.folderFilter,
                   !folders.contains(name) {
                    state.folderFilter = .all
                }
                return .none

            case .moveDownload(let gid, let folderName):
                return .run { send in
                    try await downloadClient.moveDownload(gid, folderName)
                    await send(.moveDownloadDone(.success(())))
                } catch: { error, send in
                    await send(.moveDownloadDone(.failure(error as? AppError ?? .unknown)))
                }

            case .moveDownloadDone(let result):
                if case .success = result {
                    return .send(.fetchFolders)
                }
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
                            .success(try await downloadClient.loadManifest(gid))
                        )
                    )
                } catch: { error, send in
                    await send(.openReadingDone(requestID, gid, .failure(error as? AppError ?? .unknown)))
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
                    try await downloadClient.togglePause(gid)
                    await send(.toggleDownloadPauseDone(.success(())))
                } catch: { error, send in
                    await send(.toggleDownloadPauseDone(.failure(error as? AppError ?? .unknown)))
                }

            case .toggleDownloadPauseDone:
                return .none

            case .updateDownload(let gid):
                return .run { send in
                    try await downloadClient.retry(gid, .update)
                    await send(.updateDownloadDone(.success(())))
                } catch: { error, send in
                    await send(.updateDownloadDone(.failure(error as? AppError ?? .unknown)))
                }

            // List-level mutations don't surface a per-op HUD: the `observeDownloads` stream is the
            // user-facing feedback from the DES-3 write-through index. Failures leave the current
            // observed state in place; the download client performs any targeted surprise repair.
            case .updateDownloadDone:
                return .none

            case .deleteDownload(let gid):
                return .run { send in
                    try await downloadClient.delete(gid)
                    await send(.deleteDownloadDone(.success(())))
                } catch: { error, send in
                    await send(.deleteDownloadDone(.failure(error as? AppError ?? .unknown)))
                }

            case .deleteDownloadDone:
                return .none

            case .detail(.folderManager(.createFolderDone)),
                 .detail(.folderManager(.renameFolderDone)),
                 .detail(.folderManager(.deleteFolderDone)):
                return .send(.fetchFolders)

            case .detail:
                return .none

            case .reading(.onPerformDismiss):
                return .send(.setNavigation(nil))

            case .reading:
                return .none

            case .inspector:
                return .none

            case .folderManager(.createFolderDone),
                 .folderManager(.renameFolderDone),
                 .folderManager(.deleteFolderDone):
                return .send(.fetchFolders)

            case .folderManager:
                return .none
            }
        }

        Scope(state: \.detailState.wrappedValue!, action: \.detail, child: DetailReducer.init)
        Scope(state: \.readingState, action: \.reading, child: ReadingReducer.init)
        Scope(state: \.inspectorState, action: \.inspector, child: DownloadInspectorReducer.init)
        Scope(state: \.folderManagerState, action: \.folderManager, child: FolderManagerReducer.init)
    }
}

private extension ReadingReducer.State {
    mutating func applyDownloadFallback(_ download: DownloadedGallery) {
        gallery = download.gallery
        language = .other
    }
}
