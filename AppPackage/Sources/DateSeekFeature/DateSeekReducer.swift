import ComposableArchitecture
import AppModels
import Foundation
import HapticsClient

/// A headless, reusable feature for the "Date seek" control.
///
/// Despite the matching name, this reducer is **not** the companion of `DateSeekPickerView`: it
/// owns no view, and the picker owns no reducer. `DateSeekPickerView` is a store-agnostic
/// presentation component, while `DateSeekReducer` is logic-only, designed to be presented — as a
/// `@Presents` destination — by any gallery-list reducer that exposes a `DateSeekNavigation`.
///
/// It is a self-contained sheet feature: it owns the picker's UI state (selected date, the
/// navigation being seeked), validates and clamps the date, and resolves a seek `URL`. It reports
/// that URL back to its host through `delegate(.performSeek)` and then dismisses itself. The host
/// performs the request and stores the result, because the gallery list and its loading state
/// belong to the host — not to this control.
@Reducer
public struct DateSeekReducer: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var date: Date
        /// The navigation whose picker is presented.
        public var navigation: DateSeekNavigation

        public init(navigation: DateSeekNavigation) {
            self.navigation = navigation
            self.date = navigation.clampedDate(Date())
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case performSeek(DateSeekDirection)
        case delegate(Delegate)
    }

    @CasePathable
    public enum Delegate: Equatable {
        case performSeek(URL)
    }

    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.dismiss) private var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .performSeek(let direction):
                guard let url = state.navigation.seekURL(date: state.date, direction: direction) else {
                    return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })
                }
                return .merge(
                    .send(.delegate(.performSeek(url))),
                    .run(operation: { _ in await dismiss() })
                )

            case .delegate:
                return .none
            }
        }
    }
}
