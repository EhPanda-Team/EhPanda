//
//  ArchivesStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/19.
//

import TTProgressHUD
import ComposableArchitecture

struct ArchivesState: Equatable {
    enum Route {
        case messageHUD
        case communicatingHUD
    }

    @BindableState var route: Route?
    @BindableState var selectedArchive: GalleryArchive.HathArchive?

    var loadingState: LoadingState = .idle
    var hathArchives = [GalleryArchive.HathArchive]()

    var messageHUDConfig = TTProgressHUDConfig()
    var communicatingHUDConfig: TTProgressHUDConfig = .communicating
}

enum ArchivesAction: BindableAction {
    case binding(BindingAction<ArchivesState>)
    case setNavigation(ArchivesState.Route?)

    case syncGalleryFunds(GalleryPoints, Credits)

    case fetchArchive(String, String, String)
    case fetchArchiveDone(String, String, Result<(GalleryArchive, GalleryPoints?, Credits?), AppError>)
    case fetchArchiveFunds(String, String)
    case fetchArchiveFundsDone(Result<(GalleryPoints, Credits), AppError>)
    case fetchDownloadResponse(String)
    case fetchDownloadResponseDone(Result<String, AppError>)
}

struct ArchivesEnvironment {
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
}

let archivesReducer = Reducer<ArchivesState, ArchivesAction, ArchivesEnvironment> { state, action, environment in
    switch action {
    case .binding:
        return .none

    case .setNavigation(let route):
        state.route = route
        return .none

    case .syncGalleryFunds(let galleryPoints, let credits):
        return environment.databaseClient
            .updateGalleryFunds(galleryPoints: galleryPoints, credits: credits).fireAndForget()

    case .fetchArchive(let gid, let galleryURL, let archiveURL):
        guard state.loadingState != .loading else { return .none }
        state.loadingState = .loading
        return GalleryArchiveRequest(archiveURL: archiveURL)
            .effect.map({ ArchivesAction.fetchArchiveDone(gid, galleryURL, $0) })

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
            } else if environment.cookiesClient.isSameAccount() {
                return .init(value: .fetchArchiveFunds(gid, galleryURL))
            } else {
                return .none
            }
        case .failure(let error):
            state.loadingState = .failed(error)
        }
        return .none

    case .fetchArchiveFunds(let gid, let galleryURL):
        return GalleryArchiveFundsRequest(gid: gid, galleryURL: galleryURL)
            .effect.map(ArchivesAction.fetchArchiveFundsDone)

    case .fetchArchiveFundsDone(let result):
        if case .success(let (galleryPoints, credits)) = result {
            return .init(value: .syncGalleryFunds(galleryPoints, credits))
        }
        return .none

    case .fetchDownloadResponse(let archiveURL):
        guard let selectedArchive = state.selectedArchive, state.route != .communicatingHUD else { return .none }
        state.route = .communicatingHUD
        return SendDownloadCommandRequest(archiveURL: archiveURL, resolution: selectedArchive.resolution.parameter)
            .effect.map(ArchivesAction.fetchDownloadResponseDone)

    case .fetchDownloadResponseDone(let result):
        state.route = .messageHUD
        let isSuccess: Bool
        switch result {
        case .success(let response):
            switch response {
            case Defaults.Response.hathClientNotFound,
                Defaults.Response.hathClientNotOnline,
                Defaults.Response.invalidResolution:
                state.messageHUDConfig = .error(caption: response.localized)
                isSuccess = false
            default:
                state.messageHUDConfig = .success(caption: response.localized)
                isSuccess = true
            }
        case .failure:
            state.messageHUDConfig = .error
            isSuccess = false
        }
        return environment.hapticClient.generateNotificationFeedback(isSuccess ? .success : .error).fireAndForget()
    }
}
.binding()
