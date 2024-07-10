//
//  ArchivesReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/19.
//

import Foundation
import TTProgressHUD
import ComposableArchitecture

@Reducer
struct ArchivesReducer {
    enum Route {
        case messageHUD
        case communicatingHUD
    }

    private enum CancelID: CaseIterable {
        case fetchArchive, fetchArchiveFunds, fetchDownloadResponse
    }

    struct State: Equatable {
        @BindingState var route: Route?
        @BindingState var selectedArchive: GalleryArchive.HathArchive?

        var loadingState: LoadingState = .idle
        var hathArchives = [GalleryArchive.HathArchive]()

        var messageHUDConfig = TTProgressHUDConfig()
        var communicatingHUDConfig: TTProgressHUDConfig = .communicating
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)

        case syncGalleryFunds(String, String)

        case teardown
        case fetchArchive(String, URL, URL)
        case fetchArchiveDone(String, URL, Result<(GalleryArchive, String?, String?), AppError>)
        case fetchArchiveFunds(String, URL)
        case fetchArchiveFundsDone(Result<(String, String), AppError>)
        case fetchDownloadResponse(URL)
        case fetchDownloadResponseDone(Result<String, AppError>)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.cookieClient) private var cookieClient

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return .none

            case .syncGalleryFunds(let galleryPoints, let credits):
                return .run { _ in
                    await databaseClient.updateGalleryFunds(galleryPoints: galleryPoints, credits: credits)
                }

            case .teardown:
                return .merge(CancelID.allCases.map(Effect.cancel(id:)))

            case .fetchArchive(let gid, let galleryURL, let archiveURL):
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                return .run { send in
                    let response = await GalleryArchiveRequest(archiveURL: archiveURL).response()
                    await send(.fetchArchiveDone(gid, galleryURL, response))
                }
                .cancellable(id: CancelID.fetchArchive)

            case .fetchArchiveDone(let gid, let galleryURL, let result):
                state.loadingState = .idle
                switch result {
                case .success(let (archive, galleryPoints, credits)):
                    guard !archive.hathArchives.isEmpty else {
                        state.loadingState = .failed(.notFound)
                        return .none
                    }
                    state.hathArchives = archive.hathArchives
                    if let galleryPoints = galleryPoints, let credits = credits {
                        return .send(.syncGalleryFunds(galleryPoints, credits))
                    } else if cookieClient.isSameAccount {
                        return .send(.fetchArchiveFunds(gid, galleryURL))
                    } else {
                        return .none
                    }
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .fetchArchiveFunds(let gid, let galleryURL):
                guard let galleryURL = galleryURL.replaceHost(to: Defaults.URL.ehentai.host) else { return .none }
                return .run { send in
                    let response = await GalleryArchiveFundsRequest(gid: gid, galleryURL: galleryURL).response()
                    await send(.fetchArchiveFundsDone(response))
                }
                .cancellable(id: CancelID.fetchArchiveFunds)

            case .fetchArchiveFundsDone(let result):
                if case .success(let (galleryPoints, credits)) = result {
                    return .send(.syncGalleryFunds(galleryPoints, credits))
                }
                return .none

            case .fetchDownloadResponse(let archiveURL):
                guard let selectedArchive = state.selectedArchive,
                      state.route != .communicatingHUD
                else { return .none }
                state.route = .communicatingHUD
                return .run {send in
                    let response = await SendDownloadCommandRequest(
                        archiveURL: archiveURL,
                        resolution: selectedArchive.resolution.parameter
                    )
                    .response()
                    await send(.fetchDownloadResponseDone(response))
                }
                .cancellable(id: CancelID.fetchDownloadResponse)

            case .fetchDownloadResponseDone(let result):
                state.route = .messageHUD
                let isSuccess: Bool
                switch result {
                case .success(let response):
                    switch response {
                    case L10n.Constant.Website.Response.hathClientNotFound:
                        state.messageHUDConfig = .error(caption: L10n.Localizable.Website.Response.hathClientNotFound)
                        isSuccess = false
                    case L10n.Constant.Website.Response.hathClientNotOnline:
                        state.messageHUDConfig = .error(caption: L10n.Localizable.Website.Response.hathClientNotOnline)
                        isSuccess = false
                    case L10n.Constant.Website.Response.invalidResolution:
                        state.messageHUDConfig = .error(caption: L10n.Localizable.Website.Response.invalidResolution)
                        isSuccess = false
                    default:
                        state.messageHUDConfig = .success(caption: response)
                        isSuccess = true
                    }
                case .failure:
                    state.messageHUDConfig = .error
                    isSuccess = false
                }
                return .run { _ in
                    hapticsClient.generateNotificationFeedback(isSuccess ? .success : .error)
                }
            }
        }
    }
}
