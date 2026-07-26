import AnalyticsClient
import AppComponents
import AppModels
import ComposableArchitecture
import CookieClient
import Foundation
import NetworkingFeature
@testable import SettingFeature
import Sharing
import Testing

// Exact-sequence proof for the login flow's two emission sites, in the module that handles
// credentials.
//
// Three assertions here carry weight beyond the emissions themselves:
//
//   - The failure case is asserted as an **exact one-element sequence**, not a membership check. A
//     membership assertion would still pass if a generic `errorSurfaced` signal were emitted
//     alongside the classified one — which is precisely the double-count the production exclusion
//     exists to prevent (T-14-13).
//   - Sentinel credentials sit in the store's initial state and are proven, by reflection over the
//     whole recorded signal graph, to survive nowhere. Both signals carry a closed enum with no field
//     capable of holding a string, and this is what pins that (T-14-01).
//   - Cancelling a challenge records nothing beyond the encounter already counted. Cancelling is a
//     deliberate user choice, not a failure.
//
// Every case gets its own `InMemoryStorage`, so the process-wide `@Shared(.cloudflareClearance)`
// holder cannot leak between cases or into the Phase 12 suites in this target.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
@Suite
struct AnalyticsEmissionTests {

    // MARK: Classified login failures

    // Sweeps the five mapped errors plus one unmapped case exercising the catch-all kind, so a new
    // AppError case that should be classified cannot quietly land in `other` unnoticed.
    //
    // `.loginRejected` carries the forum's refusal wording, and the recorded signal is asserted as an
    // exact one-element sequence below — so this argument doubles as the proof that the wording does
    // not ride along into analytics with it.
    @MainActor
    @Test(arguments: [
        (error: AppError.loginCaptchaRequired, kind: LoginFailureKind.captchaRequired),
        (error: AppError.cloudflareChallengeFailed, kind: LoginFailureKind.cloudflareChallengeFailed),
        (error: AppError.networkingFailed, kind: LoginFailureKind.networkingFailed),
        (error: AppError.loginRejected("You must enter a username"), kind: LoginFailureKind.rejected),
        (error: AppError.unknown, kind: LoginFailureKind.rejected),
        (error: AppError.quotaExceeded, kind: LoginFailureKind.other)
    ])
    func aFailedLoginRecordsOneClassifiedSignal(error: AppError, kind: LoginFailureKind) async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = Self.makeStore(recorded: recorded)

        await store.send(.loginDone(.failure(error)))
        await store.skipInFlightEffects(strict: false)

        // Exact one-element sequence, deliberately: this is what would fail if a generic
        // `errorSurfaced` signal were ever added alongside the classified one.
        expectNoDifference(recorded.value, [.loginFailed(kind)])
    }

    // The mapping asserted directly, independently of the reducer wiring. This list is not a
    // completeness check and does not need to be: the production `switch` has no `default:` arm, so a
    // new `AppError` case is a compile error there rather than a silent fall into `other`. That is a
    // stronger guarantee than any sweep a test could perform, since `AppError` carries associated
    // values and cannot be `CaseIterable`.
    @Test(arguments: [
        (error: AppError.loginCaptchaRequired, kind: LoginFailureKind.captchaRequired),
        (error: AppError.cloudflareChallengeFailed, kind: LoginFailureKind.cloudflareChallengeFailed),
        (error: AppError.networkingFailed, kind: LoginFailureKind.networkingFailed),
        (error: AppError.loginRejected("Bad password."), kind: LoginFailureKind.rejected),
        (error: AppError.unknown, kind: LoginFailureKind.rejected),
        (error: AppError.quotaExceeded, kind: LoginFailureKind.other),
        (error: AppError.notFound, kind: LoginFailureKind.other),
        (error: AppError.fileOperationFailed("disk"), kind: LoginFailureKind.other)
    ])
    func theErrorToKindMappingIsStable(error: AppError, kind: LoginFailureKind) {
        #expect(LoginReducer.loginFailureKind(for: error) == kind)
    }

    @MainActor
    @Test
    func aSuccessfulLoginRecordsNothing() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = Self.makeStore(recorded: recorded, cookieClient: .previewLoggedIn)

        await store.send(.loginDone(.success(nil)))
        await store.skipInFlightEffects(strict: false)

        #expect(recorded.value.isEmpty)
    }

    // MARK: Cloudflare challenges

    @MainActor
    @Test
    func detectingAChallengeRecordsOneEncounter() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = Self.makeStore(recorded: recorded)

        await store.send(.challengeDetected)
        await store.skipInFlightEffects(strict: false)

        expectNoDifference(recorded.value, [.cloudflareChallengeEncountered])
    }

    // Two rounds, then the round that exhausts the bound. The third detection still records an
    // encounter and additionally converts into a failure, so the exhausted sequence reads as three
    // walls and one failure rather than as a single event.
    @MainActor
    @Test
    func walkingTwoRoundsRecordsTwoEncountersAndTheThirdAlsoFails() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = Self.makeStore(recorded: recorded)

        await store.send(.challengeDetected)
        await store.send(.challengeDetected)
        await store.skipInFlightEffects(strict: false)
        expectNoDifference(
            recorded.value,
            [.cloudflareChallengeEncountered, .cloudflareChallengeEncountered]
        )

        recorded.setValue([])
        await store.send(.challengeDetected)
        await store.skipInFlightEffects(strict: false)
        expectNoDifference(
            recorded.value,
            [
                .cloudflareChallengeEncountered,
                .loginFailed(.cloudflareChallengeFailed)
            ]
        )
    }

    @MainActor
    @Test
    func cancellingAChallengeRecordsNothingFurther() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = Self.makeStore(recorded: recorded)

        await store.send(.challengeDetected)
        await store.skipInFlightEffects(strict: false)
        recorded.setValue([])

        await store.send(.cancelChallenge)
        await store.skipInFlightEffects(strict: false)

        #expect(recorded.value.isEmpty)
    }

    // MARK: Credentials never reach a signal

    @MainActor
    @Test
    func noRecordedSignalCarriesTheSentinelCredentials() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = Self.makeStore(recorded: recorded)

        await store.send(.challengeDetected)
        await store.send(.loginDone(.failure(.loginCaptchaRequired)))
        await store.skipInFlightEffects(strict: false)

        #expect(recorded.value.isEmpty == false)
        let leaves = Mirror(reflecting: recorded.value).leafRenderings
        #expect(leaves.contains(where: { $0.contains(Self.sentinelUsername) }) == false)
        #expect(leaves.contains(where: { $0.contains(Self.sentinelPassword) }) == false)
    }
}

// MARK: Spy

private extension AnalyticsClient {
    // The `LockIsolated` capture idiom: take the inert `.noop` client and replace its one `send`
    // closure with a collector, so a test asserts exactly which signals crossed the reducer → client
    // boundary and in what order. `start` stays inert. Relies on the client's `var` closure properties.
    static func recording(into recorded: LockIsolated<[AnalyticsSignal]>) -> Self {
        var client = AnalyticsClient.noop
        client.send = { signal in recorded.withValue({ $0.append(signal) }) }
        return client
    }
}

// MARK: Fixtures and stores

private extension AnalyticsEmissionTests {
    static let sentinelUsername = "SENTINEL_USERNAME_must_never_leak"
    static let sentinelPassword = "SENTINEL_PASSWORD_must_never_leak"

    @MainActor
    static func makeStore(
        recorded: LockIsolated<[AnalyticsSignal]>,
        cookieClient: CookieClient = .testing()
    ) -> TestStoreOf<LoginReducer> {
        // Per-case storage isolates the process-wide `@Shared(.cloudflareClearance)` holder, matching
        // this target's Phase 12 login suites.
        let storage = InMemoryStorage()
        let store = TestStore(initialState: makeInitialState(), reducer: LoginReducer.init) {
            $0.analyticsClient = .recording(into: recorded)
            $0.cookieClient = cookieClient
            $0.defaultInMemoryStorage = storage
            $0.dismiss = DismissEffect {}
            $0.hapticsClient = .noop
            $0.loginClient = LoginClient { _, _, _ in nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }

    // Evaluated inside `TestStore.init`'s prepared dependencies (the parameter is an autoclosure), so
    // the state's `@Shared` holder resolves against this case's own storage.
    static func makeInitialState() -> LoginReducer.State {
        var state = LoginReducer.State()
        state.username = sentinelUsername
        state.password = sentinelPassword
        return state
    }
}

// Mirrors plan 14-03's `ContentLeakProbe` reflection helper. That helper lives in the
// `AnalyticsClientTests` target, which this target cannot import; the walk is reproduced verbatim
// here rather than reimplemented differently, so both privacy proofs reflect over values the same
// way — reaching every stored leaf, including ones the public API never exposes.
private extension Mirror {
    var leafRenderings: [String] {
        children.flatMap({ child in
            let nested = Mirror(reflecting: child.value).leafRenderings
            return nested.isEmpty ? [String(describing: child.value)] : nested
        })
    }
}
