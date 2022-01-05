//
//  HomeStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/05.
//

import SwiftUI
import Kingfisher
import UIImageColors
import ComposableArchitecture

struct HomeState: Equatable {
    var popularGalleries = [Gallery]()
    var popularLoadingState: LoadingState = .idle
    var frontpageGalleries = [Gallery]()
    var frontpageLoadingState: LoadingState = .idle
    var toplistsGalleries = [Int: [Gallery]]()
    var toplistsLoadingState = [Int: LoadingState]()

    var rawFilter: Filter?
    var filter: Filter {
        rawFilter ?? .init()
    }

    @BindableState var cardPageIndex = 1
    @BindableState var currentCardID = ""
    var rawCardColors = [String: [Color]]()
    var cardColors: Binding<[Color]?> {
        .init(
            get: {
                rawCardColors[currentCardID]
            },
            set: { _ in }
        )
    }

    mutating func setPopularGalleries(_ galleries: [Gallery]) {
        let sortedGalleries = galleries.sorted { lhs, rhs in
            lhs.title.count > rhs.title.count
        }
        var trimmedGalleries = Array(sortedGalleries.prefix(10)).duplicatesRemoved
        if trimmedGalleries.count >= 6 {
            trimmedGalleries = Array(trimmedGalleries.prefix(6))
        }
        popularGalleries = trimmedGalleries
        currentCardID = trimmedGalleries[cardPageIndex].gid
    }
}

enum HomeAction: BindableAction {
    case binding(BindingAction<HomeState>)
    case fetchAllGalleries
    case fetchAllToplistsGalleries
    case fetchPopularGalleries
    case fetchPopularGalleriesDone(Result<[Gallery], AppError>)
    case fetchFrontpageGalleries(Int? = nil)
    case fetchFrontpageGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)
    case fetchToplistsGalleries(Int, Int? = nil)
    case fetchToplistsGalleriesDone(Int, Result<(PageNumber, [Gallery]), AppError>)
    case analyzeImageColors(String, RetrieveImageResult)
}

struct HomeEnvironment {
    let libraryClient: LibraryClient
    let databaseClient: DatabaseClient
}

let homeReducer = Reducer<HomeState, HomeAction, HomeEnvironment> { state, action, environment in
    switch action {
    case .binding(\.$cardPageIndex):
        guard state.cardPageIndex < state.popularGalleries.count else { return .none }
        state.currentCardID = state.popularGalleries[state.cardPageIndex].gid
        return .none

    case .binding:
        return .none

    case .fetchAllGalleries:
        return .merge(
            .init(value: .fetchPopularGalleries),
            .init(value: .fetchFrontpageGalleries()),
            .init(value: .fetchAllToplistsGalleries)
        )

    case .fetchAllToplistsGalleries:
        return .merge(
            ToplistsType.allCases.map({ HomeAction.fetchToplistsGalleries($0.categoryIndex) })
                .map(Effect<HomeAction, Never>.init)
        )

    case .fetchPopularGalleries:
        guard state.popularLoadingState != .loading else { return .none }
        state.popularLoadingState = .loading
        state.rawCardColors = [String: [Color]]()
        return PopularItemsRequest(filter: state.filter)
            .effect.map(HomeAction.fetchPopularGalleriesDone)

    case .fetchPopularGalleriesDone(let result):
        state.popularLoadingState = .idle
        switch result {
        case .success(let galleries):
            guard !galleries.isEmpty else {
                state.popularLoadingState = .failed(.notFound)
                return .none
            }
            state.setPopularGalleries(galleries)
            return environment.databaseClient.cacheGalleries(galleries).fireAndForget()
        case .failure(let error):
            state.popularLoadingState = .failed(error)
        }
        return .none

    case .fetchFrontpageGalleries(let pageNum):
        guard state.frontpageLoadingState != .loading else { return .none }
        state.frontpageLoadingState = .loading
        return FrontpageItemsRequest(filter: state.filter, pageNum: pageNum)
            .effect.map(HomeAction.fetchFrontpageGalleriesDone)

    case .fetchFrontpageGalleriesDone(let result):
        state.frontpageLoadingState = .idle
        switch result {
        case .success(let (_, galleries)):
            guard !galleries.isEmpty else {
                state.frontpageLoadingState = .failed(.notFound)
                return .none
            }
            state.frontpageGalleries = galleries
            return environment.databaseClient.cacheGalleries(galleries).fireAndForget()
        case .failure(let error):
            state.frontpageLoadingState = .failed(error)
        }
        return .none

    case .fetchToplistsGalleries(let index, let pageNum):
        guard state.toplistsLoadingState[index] != .loading else { return .none }
        state.toplistsLoadingState[index] = .loading
        return ToplistsItemsRequest(catIndex: index, pageNum: pageNum)
            .effect.map({ HomeAction.fetchToplistsGalleriesDone(index, $0) })

    case .fetchToplistsGalleriesDone(let index, let result):
        state.toplistsLoadingState[index] = .idle
        switch result {
        case .success(let (_, galleries)):
            guard !galleries.isEmpty else {
                state.toplistsLoadingState[index] = .failed(.notFound)
                return .none
            }
            state.toplistsGalleries[index] = galleries
            return environment.databaseClient.cacheGalleries(galleries).fireAndForget()
        case .failure(let error):
            state.toplistsLoadingState[index] = .failed(error)
        }
        return .none

    case .analyzeImageColors(let gid, let result):
        guard !state.rawCardColors.keys.contains(gid) else { return .none }
        if let colors = environment.libraryClient.analyzeImageColors(result.image) {
            state.rawCardColors[gid] = [
                colors.primary, colors.secondary,
                colors.detail, colors.background
            ]
            .map(Color.init)
        }
        return .none
    }
}
.binding()
