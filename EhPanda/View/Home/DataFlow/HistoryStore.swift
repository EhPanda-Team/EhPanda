//
//  HistoryStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import Foundation
import ComposableArchitecture

struct HistoryState: Equatable {
    enum Route: Equatable {
        case detail(String)
        case clearHistory
    }

    init() {
        _detailState = .init(.init())
    }

    @BindingState var route: Route?
    @BindingState var keyword = ""
    @BindingState var clearDialogPresented = false

    var filteredGalleries: [Gallery] {
        guard !keyword.isEmpty else { return galleries }
        return galleries.filter({ $0.title.caseInsensitiveContains(keyword) })
    }
    var galleries = [Gallery]()
    var loadingState: LoadingState = .idle

    @Heap var detailState: DetailState!
}

enum HistoryAction: BindableAction {
    case binding(BindingAction<HistoryState>)
    case setNavigation(HistoryState.Route?)
    case clearSubStates
    case clearHistoryGalleries

    case fetchGalleries
    case fetchGalleriesDone([Gallery])

    case detail(DetailAction)
}

struct HistoryEnvironment {
    let urlClient: URLClient
    let fileClient: FileClient
    let imageClient: ImageClient
    let deviceClient: DeviceClient
    let hapticsClient: HapticsClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let clipboardClient: ClipboardClient
    let appDelegateClient: AppDelegateClient
    let uiApplicationClient: UIApplicationClient
}

let historyReducer = Reducer<HistoryState, HistoryAction, HistoryEnvironment>.combine(
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
            state.detailState = .init()
            return .init(value: .detail(.teardown))

        case .clearHistoryGalleries:
            return .merge(
                environment.databaseClient.clearHistoryGalleries().fireAndForget(),
                .init(value: .fetchGalleries)
                    .delay(for: .milliseconds(200), scheduler: DispatchQueue.main).eraseToEffect()
            )

        case .fetchGalleries:
            guard state.loadingState != .loading else { return .none }
            state.loadingState = .loading
            return environment.databaseClient.fetchHistoryGalleries().map(HistoryAction.fetchGalleriesDone)

        case .fetchGalleriesDone(let galleries):
            state.loadingState = .idle
            if galleries.isEmpty {
                state.loadingState = .failed(.notFound)
            } else {
                state.galleries = galleries
            }
            return .none

        case .detail:
            return .none
        }
    }
    .binding(),
    detailReducer.pullback(
        state: \.detailState,
        action: /HistoryAction.detail,
        environment: {
            .init(
                urlClient: $0.urlClient,
                fileClient: $0.fileClient,
                imageClient: $0.imageClient,
                deviceClient: $0.deviceClient,
                hapticsClient: $0.hapticsClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                appDelegateClient: $0.appDelegateClient,
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    )
)
