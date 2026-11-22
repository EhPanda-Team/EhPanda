import AnalyticsClient
import AppComponents
import ApplicationClient
public import AppModels
import AppTools
public import ComposableArchitecture
import CookieClient
import EhSettingClient
import Foundation
import Resources
public import Sharing

@Reducer
public struct EhSettingReducer: Sendable {
    public enum Dialog: Equatable, Sendable {
        case confirmDeleteProfile
    }

    private enum CancelID {
        case fetchEhSetting
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        @Presents public var confirmationDialog: ConfirmationDialogState<Dialog>?
        @SharedReader(.setting) public var setting: Setting
        public var editingProfileName = ""
        public var ehSetting: EhSetting?
        public var ehProfile: EhProfile?
        public var loadingState: LoadingState = .idle
        /// The options whose save or profile action the site has not answered, each one's control disabled until
        /// then.
        public var updatingOptions: Set<Option> = []
        /// The revision of the most recently started save or profile action.
        ///
        /// Every request posts or acts on the whole form, so the newest answer already shows the site after every
        /// older change. Only it is applied; an older answer only re-enables its option.
        public var latestRevision = 0

        /// Applies the site's settings to the form.
        ///
        /// `resettingProfileName` is true for the first load and for a profile action's answer, and false for an
        /// option save's answer, so a profile name being typed is not wiped by an unrelated save.
        mutating func setEhSetting(_ ehSetting: EhSetting, resettingProfileName: Bool) {
            let ehProfile: EhProfile = ehSetting.ehProfiles
                .filter(\.isSelected).first.forceUnwrapped
            self.ehSetting = ehSetting
            self.ehProfile = ehProfile
            if resettingProfileName {
                editingProfileName = ehProfile.name
            }
        }
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case confirmationDialog(PresentationAction<Dialog>)
        case deleteProfileButtonTapped
        case setKeyboardHidden

        case fetchEhSetting
        case fetchEhSettingDone(Result<EhSetting, AppError>)
        case performAction(action: EhProfileAction?, name: String?, set: Int)
        case updateDone(option: Option, revision: Int, result: Result<EhSetting, AppError>)
        case refetchDone(option: Option, revision: Int, result: Result<EhSetting, AppError>)
    }

    @Dependency(\.applicationClient) private var applicationClient
    @Dependency(\.cookieClient) private var cookieClient
    @Dependency(\.ehSettingClient) private var ehSettingClient

    public init() {}

    public var body: some Reducer<State, Action> {
        // Every option saves the moment its form value changes, and this is the one place that starts a save.
        // `onChange` is attached to `BindingReducer` alone, so it sees only the form's own writes. The answers the
        // `Reduce` below applies never reach it, so a site answer cannot start a save. An option already updating is
        // ignored, because its control is disabled anyway.
        BindingReducer()
            .onChange(of: \.ehSetting) { oldValue, state in
                guard let oldValue, let newForm = state.ehSetting else { return .none }
                let host = state.setting.galleryHost
                var effects = [Effect<Action>]()
                for option in Option.changes(from: oldValue, to: newForm) {
                    guard !state.updatingOptions.contains(option) else { continue }
                    effects.append(
                        startUpdate(of: option, state: &state) { () async throws(AppError) in
                            try await ehSettingClient.submitChanges(host, newForm)
                        }
                    )
                }
                return .merge(effects)
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .deleteProfileButtonTapped:
                state.confirmationDialog = ConfirmationDialogState(titleVisibility: .hidden) {
                    TextState(localized: .RLocalizable.delete)
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDeleteProfile) {
                        TextState(localized: .RLocalizable.delete)
                    }
                    ButtonState(role: .cancel) {
                        TextState(localized: .RLocalizable.cancel)
                    }
                } message: {
                    TextState(localized: .deleteProfileDescription)
                }
                return .none

            case .confirmationDialog(.presented(.confirmDeleteProfile)):
                guard let value = state.ehProfile?.value else { return .none }
                return .send(.performAction(action: .delete, name: nil, set: value))

            case .confirmationDialog:
                return .none

            case .setKeyboardHidden:
                return .run(operation: { _ in await applicationClient.hideKeyboard() })

            case .fetchEhSetting:
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                let host = state.setting.galleryHost
                return .run { send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await ehSettingClient.fetchSettings(host)
                    }
                    await send(.fetchEhSettingDone(result))
                }
                .cancellable(id: CancelID.fetchEhSetting)

            case .fetchEhSettingDone(let result):
                state.loadingState = .idle

                switch result {
                case .success(let ehSetting):
                    state.setEhSetting(ehSetting, resettingProfileName: true)
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .performAction(let action, let name, let set):
                guard !state.updatingOptions.contains(.profile) else { return .none }
                let host = state.setting.galleryHost
                return startUpdate(of: .profile, state: &state) { () async throws(AppError) in
                    try await ehSettingClient.performProfileAction(host, action, name, set)
                }

            case .updateDone(let option, let revision, let result):
                guard revision == state.latestRevision else {
                    state.updatingOptions.remove(option)
                    return .none
                }

                switch result {
                case .success(let ehSetting):
                    state.updatingOptions.remove(option)
                    state.setEhSetting(ehSetting, resettingProfileName: option == .profile)
                    return .none
                case .failure:
                    let host = state.setting.galleryHost
                    return .run { send in
                        let result = await Result.Swift::init { () async throws(AppError) in
                            try await ehSettingClient.fetchSettings(host)
                        }
                        await send(.refetchDone(option: option, revision: revision, result: result))
                    }
                }

            // A failed latest request refetches, so that a save which did not take shows the site's value. The
            // option stays disabled until this answer returns. If the refetch fails too, only the control is
            // re-enabled. There is no alert, toast or error state for saves.
            case .refetchDone(let option, let revision, let result):
                state.updatingOptions.remove(option)
                guard revision == state.latestRevision, case .success(let ehSetting) = result else { return .none }
                state.setEhSetting(ehSetting, resettingProfileName: option == .profile)
                return .none
            }
        }
        .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
        // Only the first load's failure is shown, so only it is counted. A failed save or profile action shows
        // nothing, and the latest one quietly refetches.
        .signalsErrors(of: \.loadingState.failed, on: .ehSetting)
    }

    /// Marks `option` as updating, takes the next revision and starts `request` under it.
    ///
    /// No `.cancellable`: a save is never cancelled by another save, because each posts the whole form and the
    /// newest answer shows the site after all of them.
    private func startUpdate(
        of option: Option,
        state: inout State,
        request: @escaping @Sendable () async throws(AppError) -> EhSetting
    ) -> Effect<Action> {
        state.updatingOptions.insert(option)
        state.latestRevision += 1
        let revision = state.latestRevision
        return .run { send in
            let result = await Result.Swift::init { () async throws(AppError) in
                try await request()
            }
            await send(.updateDone(option: option, revision: revision, result: result))
        }
    }
}
