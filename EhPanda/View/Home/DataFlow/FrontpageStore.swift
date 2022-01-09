//
//  FrontpageStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/08.
//

import ComposableArchitecture

struct FrontpageState: Equatable {
    @BindableState var keyword = ""
    @BindableState var jumpPageIndex = ""
    @BindableState var jumpPageAlertFocused = false
    @BindableState var jumpPageAlertPresented = false

    // Will be passed over from `appReducer`
    var filter = Filter()

    var filteredGalleries: [Gallery] {
        guard !keyword.isEmpty else { return galleries }
        return galleries.filter({ $0.title.localizedCaseInsensitiveContains(keyword) })
    }
    var galleries = [Gallery]()
    var pageNumber = PageNumber()
    var loadingState: LoadingState = .idle
    var footerLoadingState: LoadingState = .idle

    mutating func insertGalleries(_ galleries: [Gallery]) {
        galleries.forEach { gallery in
            if !self.galleries.contains(gallery) {
                self.galleries.append(gallery)
            }
        }
    }
}

enum FrontpageAction: BindableAction {
    case binding(BindingAction<FrontpageState>)
    case onDisappear
    case onFiltersButtonTapped
    case performJumpPage
    case presentJumpPageAlert
    case setJumpPageAlertFocused(Bool)
    case fetchGalleries(Int? = nil)
    case fetchGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)
    case fetchMoreGalleries
    case fetchMoreGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)
}

struct FrontpageEnvironment {
    let hapticClient: HapticClient
    let databaseClient: DatabaseClient
}

let frontpageReducer = Reducer<FrontpageState, FrontpageAction, FrontpageEnvironment> { state, action, environment in
    switch action {
    case .binding(\.$jumpPageAlertPresented):
        if !state.jumpPageAlertPresented {
            state.jumpPageAlertFocused = false
        }
        return .none

    case .binding:
        return .none

    case .onDisappear:
        state.jumpPageAlertPresented = false
        state.jumpPageAlertFocused = false
        return .none

    case .onFiltersButtonTapped:
        return .none

    case .performJumpPage:
        guard let index = Int(state.jumpPageIndex), index > 0, index <= state.pageNumber.maximum + 1 else {
            return environment.hapticClient.generateNotificationFeedback(.error).fireAndForget()
        }
        return .init(value: .fetchGalleries(index - 1))

    case .presentJumpPageAlert:
        state.jumpPageAlertPresented = true
        return environment.hapticClient.generateFeedback(.light).fireAndForget()

    case .setJumpPageAlertFocused(let isFocused):
        state.jumpPageAlertFocused = isFocused
        return .none

    case .fetchGalleries(let pageNum):
        guard state.loadingState != .loading else { return .none }
        state.loadingState = .loading
        state.pageNumber.current = 0
        return FrontpageGalleriesRequest(filter: state.filter, pageNum: pageNum)
            .effect.map(FrontpageAction.fetchGalleriesDone)

    case .fetchGalleriesDone(let result):
        state.loadingState = .idle
        switch result {
        case .success(let (pageNumber, galleries)):
            guard !galleries.isEmpty else {
                guard pageNumber.current < pageNumber.maximum else {
                    state.loadingState = .failed(.notFound)
                    return .none
                }
                return .init(value: .fetchMoreGalleries)
            }
            state.pageNumber = pageNumber
            state.galleries = galleries
            return environment.databaseClient.cacheGalleries(galleries).fireAndForget()
        case .failure(let error):
            state.loadingState = .failed(error)
        }
        return .none

    case .fetchMoreGalleries:
        let pageNumber = state.pageNumber
        guard pageNumber.current + 1 <= pageNumber.maximum,
              state.footerLoadingState != .loading,
              let lastID = state.galleries.last?.id
        else { return .none }
        state.footerLoadingState = .loading
        let pageNum = pageNumber.current + 1
        return MoreFrontpageGalleriesRequest(filter: state.filter, lastID: lastID, pageNum: pageNum)
            .effect.map(FrontpageAction.fetchMoreGalleriesDone)

    case .fetchMoreGalleriesDone(let result):
        state.footerLoadingState = .idle
        switch result {
        case .success(let (pageNumber, galleries)):
            state.pageNumber = pageNumber
            state.insertGalleries(galleries)

            var effects: [Effect<FrontpageAction, Never>] = [
                environment.databaseClient.cacheGalleries(galleries).fireAndForget()
            ]
            if galleries.isEmpty, pageNumber.current < pageNumber.maximum {
                effects.append(.init(value: .fetchMoreGalleries))
            }
            return .merge(effects)

        case .failure(let error):
            state.footerLoadingState = .failed(error)
        }
        return .none
    }
}
.binding()
