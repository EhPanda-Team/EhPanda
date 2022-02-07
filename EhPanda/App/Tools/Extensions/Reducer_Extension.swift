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
    static func recurse(_ reducer: @escaping (Reducer) -> Reducer) -> Reducer {
        var `self`: Reducer!
        self = Reducer { state, action, environment in
            reducer(self).run(&state, action, environment)
        }
        return self
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
