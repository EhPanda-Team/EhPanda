import AppModels
import ComposableArchitecture
import ApplicationClient

@Reducer
public struct AppearanceSettingReducer: Sendable {
    // Pushes handled by SettingReducer, which owns the Setting navigation stack.
    public enum Delegate: Equatable, Sendable {
        case pushAppIcon
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public init() {}
    }

    public enum Action: Equatable, Sendable {
        case delegate(Delegate)
        // The theme picker writes `preferredColorScheme` into `@Shared(.setting)`, which dispatches no
        // action, so the view bridges the change here for this reducer to apply the interface style.
        case preferredColorSchemeChanged(PreferredColorScheme)
    }

    @Dependency(\.applicationClient) private var applicationClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .delegate:
                return .none

            case .preferredColorSchemeChanged(let colorScheme):
                return .run { _ in await applicationClient.setUserInterfaceStyle(colorScheme.userInterfaceStyle) }
            }
        }
    }
}
