//
//  HistoryReducer.swift
//  EhPanda
//

import Foundation
import ComposableArchitecture

@Reducer
struct HistoryReducer {
    private enum CancelID {
        case observeDownloads
    }

    @CasePathable
    enum Route: Equatable {
        case detail(String)
        case clearHistory
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?
        var keyword = ""
        var clearDialogPresented = false
        var downloadBadges = [String: DownloadBadge]()

        var filteredGalleries: [Gallery] {
            guard !keyword.isEmpty else { return galleries }
            return galleries.filter({ $0.title.caseInsensitiveContains(keyword) })
        }
        var galleries = [Gallery]()
        var loadingState: LoadingState = .idle

        var detailState: Heap<DetailReducer.State?>

        init() {
            detailState = .init(.init())
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case setNavigation(Route?)
        case clearSubStates
        case clearHistoryGalleries

        case fetchGalleries
        case fetchGalleriesDone([Gallery])
        case fetchDownloadBadges([String])
        case fetchDownloadBadgesDone([String: DownloadBadge])
        case observeDownloads
        case observeDownloadsDone([DownloadedGallery])

        case detail(DetailReducer.Action)
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

            case .onAppear:
                return .send(.observeDownloads)

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .send(.clearSubStates) : .none

            case .clearSubStates:
                state.detailState.wrappedValue = .init()
                return .send(.detail(.teardown))

            case .clearHistoryGalleries:
                return .merge(
                    .run(operation: { _ in await databaseClient.clearHistoryGalleries() }),
                    .run { send in
                        try await Task.sleep(for: .milliseconds(200))
                        await send(.fetchGalleries)
                    }
                )

            case .fetchGalleries:
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                return .run { send in
                    let historyGalleries = await databaseClient.fetchHistoryGalleries()
                    await send(.fetchGalleriesDone(historyGalleries))
                }

            case .fetchGalleriesDone(let galleries):
                state.loadingState = .idle
                if galleries.isEmpty {
                    state.loadingState = .failed(.notFound)
                } else {
                    state.galleries = galleries
                }
                return .send(.fetchDownloadBadges(galleries.map(\.gid)))

            case .fetchDownloadBadges(let gids):
                return .run { send in
                    await send(.fetchDownloadBadgesDone(await downloadClient.badges(gids)))
                }

            case .fetchDownloadBadgesDone(let badges):
                state.downloadBadges = badges
                return .none

            case .observeDownloads:
                return .run { send in
                    for await downloads in downloadClient.observeDownloads() {
                        await send(.observeDownloadsDone(downloads))
                    }
                }
                .cancellable(id: CancelID.observeDownloads, cancelInFlight: true)

            case .observeDownloadsDone(let downloads):
                let visibleGIDs = Set(state.galleries.map(\.gid))
                state.downloadBadges = Dictionary(
                    uniqueKeysWithValues: downloads.compactMap { download in
                        guard visibleGIDs.contains(download.gid) else { return nil }
                        return (download.gid, download.badge)
                    }
                )
                return .none

            case .detail:
                return .none
            }
        }

        Scope(state: \.detailState.wrappedValue!, action: \.detail, child: DetailReducer.init)
    }
}
