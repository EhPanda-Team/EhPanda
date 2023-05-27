//
//  ArchivesReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/19.
//

import Foundation
import TTProgressHUD
import ComposableArchitecture

struct ArchivesReducer: ReducerProtocol {
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

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return .none

            case .syncGalleryFunds(let galleryPoints, let credits):
                return databaseClient
                    .updateGalleryFunds(galleryPoints: galleryPoints, credits: credits).fireAndForget()

            case .teardown:
                return .cancel(ids: CancelID.allCases)

            case .fetchArchive(let gid, let galleryURL, let archiveURL):
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                return GalleryArchiveRequest(archiveURL: archiveURL)
                    .effect.map({ Action.fetchArchiveDone(gid, galleryURL, $0) })
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
                        return .init(value: .syncGalleryFunds(galleryPoints, credits))
                    } else if cookieClient.isSameAccount {
                        return .init(value: .fetchArchiveFunds(gid, galleryURL))
                    } else {
                        return .none
                    }
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .fetchArchiveFunds(let gid, let galleryURL):
                guard let galleryURL = galleryURL.replaceHost(to: Defaults.URL.ehentai.host) else { return .none }
                return GalleryArchiveFundsRequest(gid: gid, galleryURL: galleryURL)
                    .effect.map(Action.fetchArchiveFundsDone).cancellable(id: CancelID.fetchArchiveFunds)

            case .fetchArchiveFundsDone(let result):
                if case .success(let (galleryPoints, credits)) = result {
                    return .init(value: .syncGalleryFunds(galleryPoints, credits))
                }
                return .none

            case .fetchDownloadResponse(let archiveURL):
                guard let selectedArchive = state.selectedArchive,
                      state.route != .communicatingHUD
                else { return .none }
                state.route = .communicatingHUD
                return SendDownloadCommandRequest(
                    archiveURL: archiveURL, resolution: selectedArchive.resolution.parameter
                )
                .effect.map(Action.fetchDownloadResponseDone).cancellable(id: CancelID.fetchDownloadResponse)

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
                return .fireAndForget({ hapticsClient.generateNotificationFeedback(isSuccess ? .success : .error) })
            }
        }
    }
}
