import ComposableArchitecture

// MARK: Recurse
public struct RecurseReducer<State, Action, Base: Reducer>: Reducer
where State == Base.State, Action == Base.Action {
    let base: (Reduce<State, Action>) -> Base

    public init(@ReducerBuilder<State, Action> base: @escaping (Reduce<State, Action>) -> Base) {
        self.base = base
    }

    public var body: some Reducer<State, Action> {
        var `self`: Reduce<State, Action>!
        self = Reduce { state, action in
            base(self)._reduce(into: &state, action: action)
        }
        return self
    }
}
