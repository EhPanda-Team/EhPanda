import AnalyticsClient
import AppModels
import ComposableArchitecture
import Testing

// The transition semantics of `signalsErrors`, proven on a fixture reducer whose actions do nothing but write
// the observed state. Every case asserts the exact sequence of recorded signals, because the operator's whole
// promise is "one signal per transition into a failure": a missing signal and a duplicate are both failures.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are main-actor-isolated,
// so every store-driving case needs it. Annotating the type instead would make the suite's protocol
// conformances main-actor-isolated too (see 11-22-SUMMARY.md).
@Suite
struct ErrorSignalReducerTests {
    // Distinctive enough that a substring search for it cannot collide with any rendering a signal carries.
    private static let sentinel = "zqxsentinelerrorsignal5203"

    @MainActor
    @Test
    func aTransitionIntoAFailureRecordsOneSignal() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeStore(recording: recorded)

        await store.send(.loadingStateChanged(.failed(.networkingFailed))) {
            $0.loadingState = .failed(.networkingFailed)
        }
        await store.finish()

        #expect(recorded.value == [.errorSurfaced(.networkingFailed, screen: .search)])
    }

    @MainActor
    @Test
    func reAssigningTheSameFailureRecordsNothingMore() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeStore(recording: recorded)

        await store.send(.loadingStateChanged(.failed(.networkingFailed))) {
            $0.loadingState = .failed(.networkingFailed)
        }
        await store.send(.loadingStateChanged(.failed(.networkingFailed)))
        await store.finish()

        #expect(recorded.value == [.errorSurfaced(.networkingFailed, screen: .search)])
    }

    @MainActor
    @Test
    func aRetryThatFailsAgainRecordsAgain() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeStore(recording: recorded)

        await store.send(.loadingStateChanged(.failed(.networkingFailed))) {
            $0.loadingState = .failed(.networkingFailed)
        }
        await store.send(.loadingStateChanged(.loading)) {
            $0.loadingState = .loading
        }
        await store.send(.loadingStateChanged(.failed(.networkingFailed))) {
            $0.loadingState = .failed(.networkingFailed)
        }
        await store.finish()

        #expect(
            recorded.value == [
                .errorSurfaced(.networkingFailed, screen: .search),
                .errorSurfaced(.networkingFailed, screen: .search)
            ]
        )
    }

    @MainActor
    @Test
    func aDifferentFailureRecordsItsOwnKind() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeStore(recording: recorded)

        await store.send(.loadingStateChanged(.failed(.networkingFailed))) {
            $0.loadingState = .failed(.networkingFailed)
        }
        await store.send(.loadingStateChanged(.failed(.parseFailed))) {
            $0.loadingState = .failed(.parseFailed)
        }
        await store.finish()

        #expect(
            recorded.value == [
                .errorSurfaced(.networkingFailed, screen: .search),
                .errorSurfaced(.parseFailed, screen: .search)
            ]
        )
    }

    @MainActor
    @Test
    func anActionThatChangesNothingObservedRecordsNothing() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeStore(recording: recorded)

        await store.send(.unrelatedChanged(1)) {
            $0.unrelated = 1
        }
        await store.finish()

        #expect(recorded.value.isEmpty)
    }

    // `AppErrorKind` binds no associated value, so the file-operation message cannot travel. Reflecting over the
    // whole recorded signal graph proves it rather than trusting the type's shape.
    @MainActor
    @Test
    func aFailureCarryingTextRecordsOnlyItsKind() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeStore(recording: recorded)

        await store.send(.loadingStateChanged(.failed(.fileOperationFailed(Self.sentinel)))) {
            $0.loadingState = .failed(.fileOperationFailed(Self.sentinel))
        }
        await store.finish()

        #expect(recorded.value == [.errorSurfaced(.fileOperationFailed, screen: .search)])
        let leaves = Mirror(reflecting: recorded.value).leafRenderings
        #expect(leaves.contains(where: { $0.contains(Self.sentinel) }) == false)
    }

    // MARK: Dictionary form

    // Both keys are new to the dictionary, so this also proves that a key whose first value is a failure
    // records. The signals are ordered by kind, not by key.
    @MainActor
    @Test
    func twoKeysFailingInOneActionRecordTwoSignals() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeStore(recording: recorded)

        await store.send(.loadingStatesChanged([1: .failed(.parseFailed), 2: .failed(.networkingFailed)])) {
            $0.loadingStates = [1: .failed(.parseFailed), 2: .failed(.networkingFailed)]
        }
        await store.finish()

        #expect(
            recorded.value == [
                .errorSurfaced(.networkingFailed, screen: .toplists),
                .errorSurfaced(.parseFailed, screen: .toplists)
            ]
        )
    }

    @MainActor
    @Test
    func reAssigningOneKeysSameFailureRecordsNothingMore() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeStore(recording: recorded)

        await store.send(.loadingStatesChanged([1: .failed(.networkingFailed)])) {
            $0.loadingStates = [1: .failed(.networkingFailed)]
        }
        await store.send(.loadingStatesChanged([1: .failed(.networkingFailed), 2: .loading])) {
            $0.loadingStates = [1: .failed(.networkingFailed), 2: .loading]
        }
        await store.finish()

        #expect(recorded.value == [.errorSurfaced(.networkingFailed, screen: .toplists)])
    }

    @MainActor
    @Test
    func aKeyThatFailsAgainAfterLoadingRecordsAgain() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeStore(recording: recorded)

        await store.send(.loadingStatesChanged([1: .failed(.networkingFailed)])) {
            $0.loadingStates = [1: .failed(.networkingFailed)]
        }
        await store.send(.loadingStatesChanged([1: .loading])) {
            $0.loadingStates = [1: .loading]
        }
        await store.send(.loadingStatesChanged([1: .failed(.networkingFailed)])) {
            $0.loadingStates = [1: .failed(.networkingFailed)]
        }
        await store.finish()

        #expect(
            recorded.value == [
                .errorSurfaced(.networkingFailed, screen: .toplists),
                .errorSurfaced(.networkingFailed, screen: .toplists)
            ]
        )
    }

    @MainActor
    @Test
    func aKeyRemovedOrSetToIdleRecordsNothing() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeStore(recording: recorded)

        await store.send(.loadingStatesChanged([1: .loading, 2: .loading])) {
            $0.loadingStates = [1: .loading, 2: .loading]
        }
        await store.send(.loadingStatesChanged([1: .idle])) {
            $0.loadingStates = [1: .idle]
        }
        await store.finish()

        #expect(recorded.value.isEmpty)
    }
}

// MARK: Fixture

private struct FixtureState: Equatable {
    var loadingState: LoadingState = .idle
    var loadingStates = [Int: LoadingState]()
    var unrelated = 0
}

private enum FixtureAction {
    case loadingStateChanged(LoadingState)
    case loadingStatesChanged([Int: LoadingState])
    case unrelatedChanged(Int)
}

private extension ErrorSignalReducerTests {
    @MainActor
    func makeStore(recording recorded: LockIsolated<[AnalyticsSignal]>) -> TestStore<FixtureState, FixtureAction> {
        TestStore(initialState: FixtureState()) {
            Reduce<FixtureState, FixtureAction> { state, action in
                switch action {
                case .loadingStateChanged(let loadingState):
                    state.loadingState = loadingState

                case .loadingStatesChanged(let loadingStates):
                    state.loadingStates = loadingStates

                case .unrelatedChanged(let unrelated):
                    state.unrelated = unrelated
                }
                return .none
            }
            .signalsErrors(of: \.loadingState.failed, on: .search)
            .signalsErrors(of: \.loadingStates, on: .toplists)
        } withDependencies: {
            $0.analyticsClient = .recording(into: recorded)
        }
    }
}

// MARK: Spy

private extension AnalyticsClient {
    // The `LockIsolated` capture idiom (AnalyticsClientGateTests): take the inert `.noop` client and replace
    // its one `send` closure with a collector, so a test asserts exactly which signals crossed the reducer →
    // client boundary and in what order.
    static func recording(into recorded: LockIsolated<[AnalyticsSignal]>) -> Self {
        var client = AnalyticsClient.noop
        client.send = { signal in recorded.withValue({ $0.append(signal) }) }
        return client
    }
}
