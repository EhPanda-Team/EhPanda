//
//  EhSettingReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/01.
//

import Foundation
import ComposableArchitecture

struct EhSettingReducer: ReducerProtocol {
    enum Route: Equatable {
        case webView(URL)
        case deleteProfile
    }

    private enum CancelID: CaseIterable {
        case fetchEhSetting, submitChanges, performAction
    }

    struct State: Equatable {
        @BindingState var route: Route?
        @BindingState var editingProfileName = ""
        @BindingState var ehSetting: EhSetting?
        @BindingState var ehProfile: EhProfile?
        var loadingState: LoadingState = .idle
        var submittingState: LoadingState = .idle

        mutating func setEhSetting(_ ehSetting: EhSetting) {
            let ehProfile: EhProfile = ehSetting.ehProfiles
                .filter(\.isSelected).first.forceUnwrapped
            self.ehSetting = ehSetting
            self.ehProfile = ehProfile
            editingProfileName = ehProfile.name
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case setKeyboardHidden
        case setDefaultProfile(Int)

        case teardown
        case fetchEhSetting
        case fetchEhSettingDone(Result<EhSetting, AppError>)
        case submitChanges
        case submitChangesDone(Result<EhSetting, AppError>)
        case performAction(EhProfileAction?, String?, Int)
        case performActionDone(Result<EhSetting, AppError>)
    }

    @Dependency(\.uiApplicationClient) private var uiApplicationClient
    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.cookieClient) private var cookieClient

    public var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return .none

            case .setKeyboardHidden:
                return uiApplicationClient.hideKeyboard().fireAndForget()

            case .setDefaultProfile(let profileSet):
                return cookieClient.setOrEditCookie(
                    for: Defaults.URL.host, key: Defaults.Cookie.selectedProfile, value: String(profileSet)
                )
                .fireAndForget()

            case .teardown:
                return .cancel(ids: CancelID.allCases)

            case .fetchEhSetting:
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                return EhSettingRequest().effect.map(Action.fetchEhSettingDone)
                    .cancellable(id: CancelID.fetchEhSetting)

            case .fetchEhSettingDone(let result):
                state.loadingState = .idle

                switch result {
                case .success(let ehSetting):
                    state.setEhSetting(ehSetting)
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .submitChanges:
                guard state.submittingState != .loading,
                      let ehSetting = state.ehSetting
                else { return .none }

                state.submittingState = .loading
                return SubmitEhSettingChangesRequest(ehSetting: ehSetting)
                    .effect.map(Action.submitChangesDone).cancellable(id: CancelID.submitChanges)

            case .submitChangesDone(let result):
                state.submittingState = .idle

                switch result {
                case .success(let ehSetting):
                    state.setEhSetting(ehSetting)
                case .failure(let error):
                    state.submittingState = .failed(error)
                }
                return .none

            case .performAction(let action, let name, let set):
                guard state.submittingState != .loading else { return .none }
                state.submittingState = .loading
                return EhProfileRequest(action: action, name: name, set: set)
                    .effect.map(Action.performActionDone).cancellable(id: CancelID.performAction)

            case .performActionDone(let result):
                state.submittingState = .idle

                switch result {
                case .success(let ehSetting):
                    state.setEhSetting(ehSetting)
                case .failure(let error):
                    state.submittingState = .failed(error)
                }
                return .none
            }
        }
        .haptics(
            unwrapping: \.route,
            case: /Route.webView,
            hapticsClient: hapticsClient
        )
    }
}
