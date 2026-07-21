import AppModels
import ComposableArchitecture
import DetailFeature
import Kingfisher
import NetworkingFeature
import Sharing
import SwiftUI

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

            // Presentation-driven lifecycle: Home is a tab root that outlives any single visit, so
            // the app reducer sends this when the Home tab becomes the active one — replacing the
            // former view `onAppear`. The empty guard keeps it idempotent across tab switches.
            case .onPresented:
                guard state.popularGalleries.isEmpty else { return .none }
                return .send(.fetchAllGalleries)

            case .galleryTapped(let gallery),
                 let .path(.element(id: _, action: .frontpage(.delegate(.pushDetail(gallery))))),
                 let .path(.element(id: _, action: .popular(.delegate(.pushDetail(gallery))))),
                 let .path(.element(id: _, action: .toplists(.delegate(.pushDetail(gallery))))),
                 let .path(.element(id: _, action: .watched(.delegate(.pushDetail(gallery))))),
                 let .path(.element(id: _, action: .history(.delegate(.pushDetail(gallery))))):
                return GalleryNavigation.routeGalleryDetail(
                    deviceType: deviceClient.deviceType,
                    present: { .delegate(.presentGalleryDetail(gallery)) },
                    push: { .pushGalleryDetail(gallery) }
                )

            case .pushGalleryDetail(let gallery):
                let screen = GalleryPath.State.detail(.init(gallery: gallery))
                return GalleryNavigation.presentationEffect(
                    id: state.path.appendGuardingDuplicate(.gallery(screen)),
                    screen: screen,
                    embed: { .path(.element(id: $0, action: .gallery($1))) }
                )

            case .delegate:
                return .none

            case .sectionTapped(let type):
                switch type {
                case .frontpage:
                    return presentationEffect(
                        id: state.path.appendGuardingDuplicate(.frontpage(.init())),
                        action: .frontpage(.onPresented)
                    )
                case .toplists:
                    return presentationEffect(
                        id: state.path.appendGuardingDuplicate(.toplists(.init())),
                        action: .toplists(.onPresented)
                    )
                }

            case .miscTapped(let type):
                switch type {
                case .popular:
                    return presentationEffect(
                        id: state.path.appendGuardingDuplicate(.popular(.init())),
                        action: .popular(.onPresented)
                    )
                case .watched:
                    return presentationEffect(
                        id: state.path.appendGuardingDuplicate(.watched(.init())),
                        action: .watched(.onPresented)
                    )
                case .history:
                    return presentationEffect(
                        id: state.path.appendGuardingDuplicate(.history(.init())),
                        action: .history(.onPresented)
                    )
                }

            case let .path(.element(id: _, action: .gallery(.comments(.delegate(.performedCommentAction(gid)))))):
                guard let id = state.path.galleryDetailID(forGID: gid) else { return .none }
                return .send(.path(.element(id: id, action: .gallery(.detail(.fetchGalleryDetail)))))

            case let .path(.element(id: _, action: .gallery(galleryAction))):
                guard let next = GalleryNavigation.nextScreen(for: galleryAction) else { return .none }
                return GalleryNavigation.presentationEffect(
                    id: state.path.appendGuardingDuplicate(.gallery(next)),
                    screen: next,
                    embed: { .path(.element(id: $0, action: .gallery($1))) }
                )

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
                        .map({ Action.fetchToplistsGalleries(index: $0.categoryIndex) })
                        .map(Effect<Action>.send)
                )

            case .fetchPopularGalleries:
                guard state.popularLoadingState != .loading else { return .none }
                state.popularLoadingState = .loading
                state.rawCardColors = [String: [Color]]()
                let filter = state.globalFilter
                let host = state.setting.galleryHost
                return .run { send in
                    do throws(AppError) {
                        let galleries = try await PopularGalleriesRequest(host: host, filter: filter).response()
                        await send(.fetchPopularGalleriesDone(.success(galleries)))
                    } catch {
                        await send(.fetchPopularGalleriesDone(.failure(error)))
                    }
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
                    return .none
                case .failure(let error):
                    state.popularLoadingState = .failed(error)
                }
                return .none

            case .fetchFrontpageGalleries:
                guard state.frontpageLoadingState != .loading else { return .none }
                state.frontpageLoadingState = .loading
                let filter = state.globalFilter
                let host = state.setting.galleryHost
                return .run { send in
                    do throws(AppError) {
                        let response = try await FrontpageGalleriesRequest(host: host, filter: filter).response()
                        await send(
                            .fetchFrontpageGalleriesDone(
                                .success((pageNumber: response.pageNumber, galleries: response.galleries))
                            )
                        )
                    } catch {
                        await send(.fetchFrontpageGalleriesDone(.failure(error)))
                    }
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
                    return .none
                case .failure(let error):
                    state.frontpageLoadingState = .failed(error)
                }
                return .none

            case .fetchToplistsGalleries(let catIndex, let pageNum):
                guard state.toplistsLoadingState[catIndex] != .loading else { return .none }
                state.toplistsLoadingState[catIndex] = .loading
                let host = state.setting.galleryHost
                return .run { send in
                    do throws(AppError) {
                        let galleries = try await ToplistsGalleriesRequest(
                            host: host,
                            catIndex: catIndex,
                            pageNum: pageNum
                        )
                        .response()
                        await send(.fetchToplistsGalleriesDone(index: catIndex, result: .success(galleries)))
                    } catch {
                        await send(.fetchToplistsGalleriesDone(index: catIndex, result: .failure(error)))
                    }
                }

            case .fetchToplistsGalleriesDone(let catIndex, let result):
                state.toplistsLoadingState[catIndex] = .idle
                switch result {
                case .success(let (_, galleries)):
                    guard !galleries.isEmpty else {
                        state.toplistsLoadingState[catIndex] = .failed(.notFound)
                        return .none
                    }
                    state.toplistsGalleries[catIndex] = galleries
                    return .none
                case .failure(let error):
                    state.toplistsLoadingState[catIndex] = .failed(error)
                }
                return .none

            case .analyzeImageColors(let gid, let result):
                guard !state.rawCardColors.keys.contains(gid) else { return .none }
                return .run { send in
                    let colors = await libraryClient.analyzeImageColors(result.image)
                    await send(.analyzeImageColorsDone(gid: gid, colors: colors))
                }

            case .analyzeImageColorsDone(let gid, let colors):
                state.rawCardColors[gid] = colors
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }

    /// Kicks off a freshly pushed screen's presentation action, the reducer-side replacement for the
    /// screen's former view `onAppear`. A `nil` id means `appendGuardingDuplicate` deduped the push,
    /// so no new screen was presented and nothing should start.
    private func presentationEffect(id: StackElementID?, action: HomePath.Action) -> Effect<Action> {
        guard let id else { return .none }
        return .send(.path(.element(id: id, action: action)))
    }
}
