import SwiftUI
import Kingfisher
import ComposableArchitecture
import NetworkingFeature
import AppModels
import Sharing
import DetailFeature

extension HomeReducer {
    @ReducerBuilder<State, Action>
    var reducerBody: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.cardPageIndex) { _, state in
                guard state.cardPageIndex < state.popularGalleries.count else { return .none }
                state.currentCardID = state.popularGalleries[state.cardPageIndex].gid
                state.allowsCardHitTesting = false
                return .run { send in
                    try await Task.sleep(for: .milliseconds(300))
                    await send(.setAllowsCardHitTesting(true))
                }
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .galleryTapped(let gallery),
                 let .path(.element(id: _, action: .frontpage(.delegate(.pushDetail(gallery))))),
                 let .path(.element(id: _, action: .popular(.delegate(.pushDetail(gallery))))),
                 let .path(.element(id: _, action: .toplists(.delegate(.pushDetail(gallery))))),
                 let .path(.element(id: _, action: .watched(.delegate(.pushDetail(gallery))))),
                 let .path(.element(id: _, action: .history(.delegate(.pushDetail(gallery))))):
                return GalleryNavigation.routeGalleryDetail(
                    isPad: deviceClient.isPad,
                    present: { .delegate(.presentGalleryDetail(gallery)) },
                    push: { .pushGalleryDetail(gallery) }
                )

            case .pushGalleryDetail(let gallery):
                state.path.appendGuardingDuplicate(.gallery(.detail(.init(gallery: gallery))))
                return .none

            case .delegate:
                return .none

            case .sectionTapped(let type):
                switch type {
                case .frontpage:
                    state.path.appendGuardingDuplicate(.frontpage(.init()))
                case .toplists:
                    state.path.appendGuardingDuplicate(.toplists(.init()))
                }
                return .none

            case .miscTapped(let type):
                switch type {
                case .popular:
                    state.path.appendGuardingDuplicate(.popular(.init()))
                case .watched:
                    state.path.appendGuardingDuplicate(.watched(.init()))
                case .history:
                    state.path.appendGuardingDuplicate(.history(.init()))
                }
                return .none

            case let .path(.element(id: _, action: .gallery(.comments(.delegate(.performedCommentAction(gid)))))):
                guard let id = state.path.galleryDetailID(forGID: gid) else { return .none }
                return .send(.path(.element(id: id, action: .gallery(.detail(.fetchGalleryDetail)))))

            case let .path(.element(id: _, action: .gallery(galleryAction))):
                if let next = GalleryNavigation.nextScreen(for: galleryAction) {
                    state.path.appendGuardingDuplicate(.gallery(next))
                }
                return .none

            case .path:
                return .none

            case .setAllowsCardHitTesting(let isAllowed):
                state.allowsCardHitTesting = isAllowed
                return .none

            case .fetchAllGalleries:
                return .merge(
                    .send(.fetchPopularGalleries),
                    .send(.fetchFrontpageGalleries),
                    .send(.fetchAllToplistsGalleries)
                )

            case .fetchAllToplistsGalleries:
                return .merge(
                    ToplistsType.allCases
                        .map { Action.fetchToplistsGalleries($0.categoryIndex) }
                        .map(Effect<Action>.send)
                )

            case .fetchPopularGalleries:
                guard state.popularLoadingState != .loading else { return .none }
                state.popularLoadingState = .loading
                state.rawCardColors = [String: [Color]]()
                @Shared(.globalFilter) var storedFilter
                let filter = storedFilter
                return .run { send in
                    let response = await PopularGalleriesRequest(filter: filter).response()
                    await send(.fetchPopularGalleriesDone(response))
                }

            case .fetchPopularGalleriesDone(let result):
                state.popularLoadingState = .idle
                switch result {
                case .success(let galleries):
                    guard !galleries.isEmpty else {
                        state.popularLoadingState = .failed(.notFound)
                        return .none
                    }
                    state.setPopularGalleries(galleries)
                    return .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                case .failure(let error):
                    state.popularLoadingState = .failed(error)
                }
                return .none

            case .fetchFrontpageGalleries:
                guard state.frontpageLoadingState != .loading else { return .none }
                state.frontpageLoadingState = .loading
                @Shared(.globalFilter) var storedFilter
                let filter = storedFilter
                return .run { send in
                    let response = await FrontpageGalleriesRequest(filter: filter).response()
                    await send(.fetchFrontpageGalleriesDone(response.map { ($0.pageNumber, $0.galleries) }))
                }

            case .fetchFrontpageGalleriesDone(let result):
                state.frontpageLoadingState = .idle
                switch result {
                case .success(let (_, galleries)):
                    guard !galleries.isEmpty else {
                        state.frontpageLoadingState = .failed(.notFound)
                        return .none
                    }
                    state.setFrontpageGalleries(galleries)
                    return .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                case .failure(let error):
                    state.frontpageLoadingState = .failed(error)
                }
                return .none

            case .fetchToplistsGalleries(let index, let pageNum):
                guard state.toplistsLoadingState[index] != .loading else { return .none }
                state.toplistsLoadingState[index] = .loading
                return .run { send in
                    let response = await ToplistsGalleriesRequest(catIndex: index, pageNum: pageNum).response()
                    await send(.fetchToplistsGalleriesDone(index, response))
                }

            case .fetchToplistsGalleriesDone(let index, let result):
                state.toplistsLoadingState[index] = .idle
                switch result {
                case .success(let (_, galleries)):
                    guard !galleries.isEmpty else {
                        state.toplistsLoadingState[index] = .failed(.notFound)
                        return .none
                    }
                    state.toplistsGalleries[index] = galleries
                    return .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                case .failure(let error):
                    state.toplistsLoadingState[index] = .failed(error)
                }
                return .none

            case .analyzeImageColors(let gid, let result):
                guard !state.rawCardColors.keys.contains(gid) else { return .none }
                return .run { send in
                    let colors = await libraryClient.analyzeImageColors(result.image)
                    await send(.analyzeImageColorsDone(gid, colors))
                }

            case .analyzeImageColorsDone(let gid, let colors):
                state.rawCardColors[gid] = colors
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
