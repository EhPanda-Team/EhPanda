//
//  DateSeekReducer.swift
//  EhPanda
//

import ComposableArchitecture
import Foundation

/// A headless, reusable sub-reducer for the "Seek to date" control.
///
/// Despite the matching name, this reducer is **not** the companion of `DateSeekPickerView`: it
/// owns no view, and the picker owns no reducer. `DateSeekPickerView` is a store-agnostic
/// presentation component, while `DateSeekReducer` is logic-only, designed to be embedded — via
/// `Scope` — into any gallery-list reducer that exposes a `DateSeekNavigation`.
///
/// It owns the picker's UI state (selected date, presentation route), validates and clamps the
/// date, and resolves a seek `URL`, which it hands back to its host through `delegate(.performSeek)`.
/// The host performs the request and stores the result, because the gallery list and its loading
/// state belong to the host — not to this control.
@Reducer
struct DateSeekReducer {
    @CasePathable
    enum Route: Equatable {
        /// Carries the navigation in scope, so the picker is only ever entered with a non-optional one.
        case picker(DateSeekNavigation)
    }

    @ObservableState
    struct State: Equatable {
        /// Kept in sync by the host whenever its page number changes.
        var navigation: DateSeekNavigation?
        var date = Date()
        var route: Route?
    }

    enum Action {
        case present
        case setRoute(Route?)
        case performSeek(DateSeekDirection)
        case delegate(Delegate)
    }

    @CasePathable
    enum Delegate: Equatable {
        case performSeek(URL)
    }

    @Dependency(\.hapticsClient) private var hapticsClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .present:
                guard let navigation = state.navigation, navigation.isEnabled else {
                    return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })
                }
                state.date = navigation.clampedDate(state.date)
                state.route = .picker(navigation)
                return .run(operation: { _ in await hapticsClient.generateFeedback(.light) })

            case .setRoute(let route):
                state.route = route
                return .none

            case .performSeek(let direction):
                guard case let .picker(navigation)? = state.route,
                      let url = navigation.seekURL(date: state.date, direction: direction)
                else {
                    return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })
                }
                state.route = nil
                return .send(.delegate(.performSeek(url)))

            case .delegate:
                return .none
            }
        }
    }
}
