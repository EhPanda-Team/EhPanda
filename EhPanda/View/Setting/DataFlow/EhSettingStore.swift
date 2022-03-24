//
//  EhSettingStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/01.
//

import ComposableArchitecture

struct EhSettingState: Equatable {
    enum Route: Equatable {
        case webView(URL)
        case deleteProfile
    }
    struct CancelID: Hashable {
        let id = String(describing: EhSettingState.self)
    }

    @BindableState var route: Route?
    @BindableState var editingProfileName = ""
    @BindableState var ehSetting: EhSetting?
    @BindableState var ehProfile: EhProfile?
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

enum EhSettingAction: BindableAction, Equatable {
    case binding(BindingAction<EhSettingState>)
    case setNavigation(EhSettingState.Route?)
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

struct EhSettingEnvironment {
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
    let uiApplicationClient: UIApplicationClient
}

let ehSettingReducer = Reducer<EhSettingState, EhSettingAction, EhSettingEnvironment> { state, action, environment in
    switch action {
    case .binding:
        return .none

    case .setNavigation(let route):
        state.route = route
        return .none

    case .setKeyboardHidden:
        return environment.uiApplicationClient.hideKeyboard().fireAndForget()

    case .setDefaultProfile(let profileSet):
        return environment.cookiesClient.setOrEditCookie(
            for: Defaults.URL.host, key: Defaults.Cookie.selectedProfile, value: String(profileSet)
        )
        .fireAndForget()

    case .teardown:
        return .cancel(id: EhSettingState.CancelID())

    case .fetchEhSetting:
        guard state.loadingState != .loading else { return .none }
        state.loadingState = .loading
        return EhSettingRequest().effect.map(EhSettingAction.fetchEhSettingDone)
            .cancellable(id: EhSettingState.CancelID())

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
            .effect.map(EhSettingAction.submitChangesDone).cancellable(id: EhSettingState.CancelID())

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
            .effect.map(EhSettingAction.performActionDone).cancellable(id: EhSettingState.CancelID())

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
    case: /EhSettingState.Route.webView,
    hapticClient: \.hapticClient
)
.binding()
