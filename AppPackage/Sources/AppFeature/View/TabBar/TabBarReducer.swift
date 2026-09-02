import AppModels
import ComposableArchitecture
import DeviceClient

@Reducer
struct TabBarReducer {
    @ObservableState
    struct State: Equatable {
        var tabBarItemType: TabBarItemType = .home
    }

    enum Action: Equatable {
        case delegate(Delegate)
        case selectSettingInline
        case setTabBarItemType(TabBarItemType)
    }

    @CasePathable
    enum Delegate: Equatable {
        case presentSetting
    }

    @Dependency(\.deviceClient) private var deviceClient

    private enum CancelID {
        case settingDeviceResolution
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none

            case .selectSettingInline:
                state.tabBarItemType = .setting
                return .none

            case .setTabBarItemType(.setting):
                return .run { send in
                    let deviceType = await deviceClient.deviceType()
                    guard !Task.isCancelled else { return }
                    await send(
                        deviceType == .pad
                            ? .delegate(.presentSetting)
                            : .selectSettingInline
                    )
                }
                .cancellable(id: CancelID.settingDeviceResolution, cancelInFlight: true)

            case .setTabBarItemType(let type):
                state.tabBarItemType = type
                return .cancel(id: CancelID.settingDeviceResolution)
            }
        }
    }
}
