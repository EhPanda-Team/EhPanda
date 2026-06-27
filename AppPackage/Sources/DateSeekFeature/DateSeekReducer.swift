import ComposableArchitecture
import AppModels
import Foundation
import HapticsClient

/// A headless, reusable sub-reducer for the "Seek to date" control.
///
/// Despite the matching name, this reducer is **not** the companion of `DateSeekPickerView`: it
/// owns no view, and the picker owns no reducer. `DateSeekPickerView` is a store-agnostic
/// presentation component, while `DateSeekReducer` is logic-only, designed to be embedded — via
/// `Scope` — into any gallery-list reducer that exposes a `DateSeekNavigation`.
///
/// It owns the picker's UI state (selected date, presented navigation), validates and clamps the
/// date, and resolves a seek `URL`, which it hands back to its host through `delegate(.performSeek)`.
/// The host performs the request and stores the result, because the gallery list and its loading
/// state belong to the host — not to this control.
@Reducer
public struct DateSeekReducer: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var date = Date()
        /// The navigation whose picker is presented; `nil` while the sheet is dismissed.
        public var navigation: DateSeekNavigation?

        public init() {}
    }

    public enum Action {
        case present(DateSeekNavigation)
        case setNavigation(DateSeekNavigation?)
        case performSeek(DateSeekDirection)
        case delegate(Delegate)
    }

    @CasePathable
    public enum Delegate: Equatable {
        case performSeek(URL)
    }

    @Dependency(\.hapticsClient) private var hapticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .present(let navigation):
                state.date = navigation.clampedDate(state.date)
                state.navigation = navigation
                return .run(operation: { _ in await hapticsClient.generateFeedback(.light) })

            case .setNavigation(let navigation):
                state.navigation = navigation
                return .none

            case .performSeek(let direction):
                guard let navigation = state.navigation,
                      let url = navigation.seekURL(date: state.date, direction: direction)
                else {
                    return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })
                }
                state.navigation = nil
                return .send(.delegate(.performSeek(url)))

            case .delegate:
                return .none
            }
        }
    }
}
