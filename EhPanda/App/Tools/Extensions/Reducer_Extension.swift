//
//  Reducer_Extension.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/02.
//

import SwiftUI
import ComposableArchitecture

extension ReducerProtocol {
    func haptics<Enum, Case>(
        unwrapping enum: @escaping (State) -> Enum?,
        case casePath: CasePath<Enum, Case>,
        hapticsClient: HapticsClient,
        style: UIImpactFeedbackGenerator.FeedbackStyle = .light
    ) -> some ReducerProtocol<State, Action> {
        onBecomeNonNil(unwrapping: `enum`, case: casePath) { _, _ in
            .fireAndForget({ hapticsClient.generateFeedback(style) })
        }
    }

    private func onBecomeNonNil<Enum, Case>(
        unwrapping enum: @escaping (State) -> Enum?,
        case casePath: CasePath<Enum, Case>,
        perform additionalEffects: @escaping (inout State, Action) -> EffectTask<Action>
    ) -> some ReducerProtocol<State, Action> {
        Reduce { state, action in
            let previousCase = Binding.constant(`enum`(state)).case(casePath).wrappedValue
            let effects = reduce(into: &state, action: action)
            let currentCase = Binding.constant(`enum`(state)).case(casePath).wrappedValue

            return previousCase == nil && currentCase != nil
            ? .merge(effects, additionalEffects(&state, action))
            : effects
        }
    }
}

// MARK: Recurse
struct RecurseReducer<State, Action, Base: ReducerProtocol>: ReducerProtocol
where State == Base.State, Action == Base.Action {
    let base: (Reduce<State, Action>) -> Base

    public init(@ReducerBuilder<State, Action> base: @escaping (Reduce<State, Action>) -> Base) {
        self.base = base
    }

    public var body: some ReducerProtocol<State, Action> {
        var `self`: Reduce<State, Action>!
        self = Reduce { state, action in
            base(self).reduce(into: &state, action: action)
        }
        return self
    }
}

// MARK: Logging
struct LoggingReducer<State, Action, Base: ReducerProtocol>: ReducerProtocol
where State == Base.State, Action == Base.Action {
    let base: Base

    init(@ReducerBuilder<State, Action> base: () -> Base) {
        self.base = base()
    }

    @ReducerBuilder<State, Action>
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            if case .setting(.binding(let bindingAction)) = action as? AppReducer.Action {
                Logger.info("setting(EhPanda.SettingReducer.Action.\(bindingAction.customDumpMirror.subjectType)")
            } else {
                Logger.info(action)
            }
            return base.reduce(into: &state, action: action)
        }
    }
}
