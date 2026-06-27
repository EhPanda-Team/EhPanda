import AppModels
import ComposableArchitecture

// MARK: Logging
struct LoggingReducer<State, Action, Base: Reducer>: Reducer
where State == Base.State, Action == Base.Action {
    let base: Base

    init(@ReducerBuilder<State, Action> base: () -> Base) {
        self.base = base()
    }

    @ReducerBuilder<State, Action>
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            Logger.info(action)
            return base._reduce(into: &state, action: action)
        }
    }
}
