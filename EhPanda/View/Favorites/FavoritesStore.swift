//
//  FavoritesStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/29.
//

import Foundation
import ComposableArchitecture

// MARK: Environment
struct FavoritesEnvironment {

}

// MARK: State
struct FavoritesState: Equatable {
    @BindableState var keyword = ""
    @BindableState var jumpPageIndex = ""
    @BindableState var jumpPageAlertFocused = false

    var index = -1
    var sortOrder: FavoritesSortOrder?

    var rawGalleries = [Int: [Gallery]]()
    var rawPageNumber = [Int: PageNumber]()
    var rawLoadingState = [Int: LoadingState]()
    var rawFooterLoadingState = [Int: LoadingState]()

    var galleries: [Gallery]? {
        get {
            rawGalleries[index]
        }
        set {
            rawGalleries[index] = newValue
        }
    }
    var pageNumber: PageNumber? {
        get {
            rawPageNumber[index]
        }
        set {
            rawPageNumber[index] = newValue
        }
    }
    var loadingState: LoadingState? {
        get {
            rawLoadingState[index]
        }
        set {
            rawLoadingState[index] = newValue
        }
    }
    var footerLoadingState: LoadingState? {
        get {
            rawFooterLoadingState[index]
        }
        set {
            rawFooterLoadingState[index] = newValue
        }
    }

    mutating func insertGalleries(index: Int, galleries: [Gallery]) {
        galleries.forEach { gallery in
            if rawGalleries[index]?.contains(gallery) == false {
                rawGalleries[index]?.append(gallery)
            }
        }
    }
}

// MARK: Action
enum FavoritesAction: BindableAction {
    case binding(BindingAction<FavoritesState>)
    case performJumpPage
    case presentJumpPageAlert
    case setFavoritesIndex(Int)
    case fetchGalleries(Int? = nil, FavoritesSortOrder? = nil)
    case fetchGalleriesDone(Int, Result<(PageNumber, FavoritesSortOrder?, [Gallery]), AppError>)
    case fetchMoreGalleries
    case fetchMoreGalleriesDone(Int, Result<(PageNumber, FavoritesSortOrder?, [Gallery]), AppError>)
}

// MARK: Reducer
let favoritesReducer = Reducer<FavoritesState, FavoritesAction, FavoritesEnvironment> { state, action, _ in
    Logger.info(action)
    switch action {

    case .binding:
        return .none

    case .performJumpPage:
        guard let index = Int(state.jumpPageIndex),
              let pageNumber = state.pageNumber,
              index <= pageNumber.maximum + 1
        else {
            HapticUtil.generateNotificationFeedback(style: .error)
            return .none
        }
        return .init(value: .fetchGalleries(index))

    case .presentJumpPageAlert:
        state.jumpPageAlertFocused = true
        HapticUtil.generateFeedback(style: .light)
        return .none

    case .setFavoritesIndex(let index):
        state.index = index
        guard state.galleries?.isEmpty != false else { return .none }
        return .init(value: FavoritesAction.fetchGalleries())

    case .fetchGalleries(let pageNum, let sortOrder):
        guard state.loadingState != .loading else { return .none }
        state.loadingState = .loading
        if state.pageNumber == nil {
            state.pageNumber = PageNumber()
        } else {
            state.pageNumber?.current = 0
        }
        return FavoritesItemsRequest(favIndex: state.index, pageNum: pageNum, sortOrder: sortOrder)
            .effect.map { [index = state.index] result in FavoritesAction.fetchGalleriesDone(index, result) }

    case .fetchGalleriesDone(let targetFavIndex, let result):
        state.rawLoadingState[targetFavIndex] = .idle

        switch result {
        case .success(let (pageNumber, sortOrder, galleries)):
            guard !galleries.isEmpty else {
                guard pageNumber.current < pageNumber.maximum else {
                    state.rawLoadingState[targetFavIndex] = .failed(.notFound)
                    return .none
                }
                return .init(value: .fetchMoreGalleries)
            }
            state.rawPageNumber[targetFavIndex] = pageNumber
            state.rawGalleries[targetFavIndex] = galleries
            state.sortOrder = sortOrder
            PersistenceController.add(galleries: galleries)
        case .failure(let error):
            state.rawLoadingState[targetFavIndex] = .failed(error)
        }
        return .none

    case .fetchMoreGalleries:
        let pageNumber = state.pageNumber ?? PageNumber()
        guard pageNumber.current + 1 <= pageNumber.maximum,
              state.footerLoadingState != .loading
        else { return .none }

        state.footerLoadingState = .loading
        let pageNum = pageNumber.current + 1
        let lastID = state.galleries?.last?.id ?? ""
        return MoreFavoritesItemsRequest(favIndex: state.index, lastID: lastID, pageNum: pageNum)
            .effect.map { [index = state.index] result in FavoritesAction.fetchMoreGalleriesDone(index, result) }

    case .fetchMoreGalleriesDone(let targetFavIndex, let result):
        state.rawFooterLoadingState[targetFavIndex] = .idle

        switch result {
        case .success(let (pageNumber, sortOrder, galleries)):
            state.rawPageNumber[targetFavIndex] = pageNumber
            state.insertGalleries(index: targetFavIndex, galleries: galleries)
            state.sortOrder = sortOrder
            PersistenceController.add(galleries: galleries)
            if galleries.isEmpty, pageNumber.current < pageNumber.maximum {
                return .init(value: .fetchMoreGalleries)
            }
        case .failure(let error):
            state.rawFooterLoadingState[targetFavIndex] = .failed(error)
        }
        return .none
    }
}
.binding()
