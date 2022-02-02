//
//  Reducer_Extension.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/02.
//

import SwiftUI
import ComposableArchitecture

// MARK: Logging
extension Reducer {
    func logging() -> Self {
        .init { state, action, environment in
            Logger.info(action)
            return run(&state, action, environment)
        }
    }
}

// MARK: Haptic
extension Reducer {
    public func onChange<LocalState>(
        of toLocalState: @escaping (State) -> LocalState,
        perform additionalEffects: @escaping (LocalState, inout State, Action, Environment)
        -> Effect<Action, Never>
    ) -> Self where LocalState: Equatable {
        .init { state, action, environment in
            let previousLocalState = toLocalState(state)
            let effects = self.run(&state, action, environment)
            let localState = toLocalState(state)

            return previousLocalState != localState
            ? .merge(effects, additionalEffects(localState, &state, action, environment))
            : effects
        }
    }
    func haptics(
        hapticClient: @escaping (Environment) -> HapticClient,
        style: UIImpactFeedbackGenerator.FeedbackStyle = .soft,
        triggerOnChangeOf trigger: @escaping (State) -> AnyHashable
    ) -> Self {
        onChange(of: trigger) {
            hapticClient($3).generateFeedback(style).fireAndForget()
        }
    }
    func onBecomeNonNil<Enum, Case>(
        unwrapping enum: @escaping (State) -> Enum?,
        case casePath: CasePath<Enum, Case>,
        perform additionalEffects: @escaping (inout State, Action, Environment)
        -> Effect<Action, Never>
    ) -> Self {
        .init { state, action, environment in
            let previousCase = Binding.constant(`enum`(state)).case(casePath).wrappedValue
            let effects = run(&state, action, environment)
            let currentCase = Binding.constant(`enum`(state)).case(casePath).wrappedValue

            return previousCase == nil && currentCase != nil
            ? .merge(effects, additionalEffects(&state, action, environment))
            : effects
        }
    }
    func haptics<Enum, Case>(
        unwrapping enum: @escaping (State) -> Enum?,
        case casePath: CasePath<Enum, Case>,
        hapticClient: @escaping (Environment) -> HapticClient,
        style: UIImpactFeedbackGenerator.FeedbackStyle = .light
    ) -> Self {
        onBecomeNonNil(unwrapping: `enum`, case: casePath) {
            hapticClient($2).generateFeedback(style).fireAndForget()
        }
    }
}
