import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import CookieClient
import Foundation
import HapticsClient
@testable import SettingFeature
import Sharing
import Testing

// The Cloudflare challenge state machine, driven entirely offline through the `LoginClient` seam.
// Every round the live wall would answer is scripted here as an `HTTPURLResponse`, so the reducer's
// own classifier (`isCloudflareChallenge`) consumes exactly what production would without a network.
//
// Exhaustivity is the point of this suite, not a formality: the two behaviours that matter most —
// "a non-challenged response adds no UI" and "a cancelled challenge fires nothing" — are *absences*,
// and an exhaustive `TestStore` is what turns an absence into an assertion.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
struct LoginChallengeFlowTests {

    // MARK: - C2: the no-wall path adds nothing

    @MainActor
    @Test
    func unchallengedLoginReachesLoginDoneWithNoChallengeSurface() async throws {
        let passing = try Self.passingResponse()
        let harness = Self.makeHarness(
            responses: [passing],
            cookieClient: .testing(memberID: Self.memberID, passHash: Self.passHash),
            focusedField: .password
        )

        await harness.store.send(.login) { state in
            state.focusedField = nil
            state.loginState = .loading
        }
        await harness.store.receive(.loginDone(.success(passing))) { state in
            state.loginState = .idle
        }
        await harness.store.finish()

        // The exhaustive store already failed the test if a challenge or a toast had appeared; these
        // restate the criterion in the terms C2 is written in.
        #expect(harness.store.state.destination == nil)
        #expect(harness.store.state.toast == nil)
        #expect(harness.store.state.challengeRounds == 0)
        #expect(harness.receivedClearances.value == [nil])
        #expect(harness.dismissCount.value == 1)
    }

    // MARK: - C3 / D-01: a challenged response puts the surface on screen immediately

    @MainActor
    @Test
    func challengedLoginPresentsTheSurfaceWhileStillLoading() async throws {
        let harness = Self.makeHarness(responses: [try Self.challengedResponse()])

        await harness.store.send(.login) { state in
            state.loginState = .loading
        }
        await harness.store.receive(.challengeDetected) { state in
            state.challengeRounds = 1
            state.destination = .challenge(Defaults.URL.login)
        }
        await harness.store.finish()

        // D-03: the spinner spans detect → solve → retry, so the attempt is still `.loading` while
        // the wall is on screen.
        #expect(harness.store.state.loginState == .loading)
    }

    // MARK: - C3 / C4 / D-06: capture dismisses the surface and replays the POST with the pair

    @MainActor
    @Test
    func capturedClearanceDismissesTheSurfaceAndRetriesCarryingThePair() async throws {
        let passing = try Self.passingResponse()
        let harness = Self.makeHarness(
            responses: [try Self.challengedResponse(), passing],
            cookieClient: .testing(memberID: Self.memberID, passHash: Self.passHash)
        )

        await harness.store.send(.login) { state in
            state.loginState = .loading
        }
        await harness.store.receive(.challengeDetected) { state in
            state.challengeRounds = 1
            state.destination = .challenge(Defaults.URL.login)
        }
        await harness.store.send(.challengeClearanceCaptured(Self.firstClearance)) { state in
            state.$cloudflareClearance.withLock({ $0 = Self.firstClearance })
            state.destination = nil
        }
        await harness.store.receive(.loginDone(.success(passing))) { state in
            state.loginState = .idle
        }
        await harness.store.finish()

        // The first POST went out bare and the retry carried the captured pair — C4 at the seam.
        #expect(harness.receivedClearances.value == [nil, Self.firstClearance])
        #expect(harness.dismissCount.value == 1)
    }

    /// Driven against the reducer directly rather than through a `TestStore`, deliberately.
    ///
    /// SwiftUI echoes a dismissal the reducer performed itself back through the same binding a swipe
    /// uses, and after a capture that echo lands while the retry is still in flight — `destination`
    /// already nil, `loginState` still `.loading`. `TestStore` cannot express it: it models a nil
    /// write to already-nil `@Presents` state as illegal and rejects the send with "Can't send action
    /// to dismissed test store", while production sends exactly that. That mismatch is a large part of
    /// why the swipe defect survived an otherwise exhaustive suite, so this case steps around the
    /// harness instead of around the behaviour.
    @MainActor
    @Test
    func swiftUIsEchoOfTheReducersOwnDismissalDoesNotAbortTheAttempt() {
        withDependencies {
            $0.defaultInMemoryStorage = InMemoryStorage()
        } operation: {
            var state = LoginReducer.State()
            state.username = Self.username
            state.password = Self.password
            state.loginState = .loading

            // Destination already nil — the shape a programmatic dismissal's echo arrives in. A real
            // swipe still has `.challenge` here, and that difference is the entire discriminator.
            _ = LoginReducer().reduce(into: &state, action: .binding(.set(\.destination, nil)))

            // Left alone: aborting here would cancel the retry a capture had just started.
            #expect(state.loginState == .loading)
        }
    }

    // MARK: - D-09 / D-10 / D-11 / C5: two rounds, then the dedicated failure

    @MainActor
    @Test
    func thirdChallengeExhaustsTheBoundAndFailsThroughTheStructuredError() async throws {
        let harness = Self.makeHarness(
            responses: [
                try Self.challengedResponse(),
                try Self.challengedResponse(),
                try Self.challengedResponse()
            ]
        )

        await harness.store.send(.login) { state in
            state.loginState = .loading
        }
        await harness.store.receive(.challengeDetected) { state in
            state.challengeRounds = 1
            state.destination = .challenge(Defaults.URL.login)
        }
        await harness.store.send(.challengeClearanceCaptured(Self.firstClearance)) { state in
            state.$cloudflareClearance.withLock({ $0 = Self.firstClearance })
            state.destination = nil
        }
        await harness.store.receive(.challengeDetected) { state in
            state.challengeRounds = 2
            state.destination = .challenge(Defaults.URL.login)
        }
        await harness.store.send(.challengeClearanceCaptured(Self.secondClearance)) { state in
            state.$cloudflareClearance.withLock({ $0 = Self.secondClearance })
            state.destination = nil
        }
        // The bound trips here: the third challenge presents nothing and increments nothing.
        await harness.store.receive(.challengeDetected)
        await harness.store.receive(.loginDone(.failure(.cloudflareChallengeFailed))) { state in
            state.loginState = .failed(.cloudflareChallengeFailed)
            state.toast = .error(
                .init(
                    error: .cloudflareChallengeFailed,
                    context: [.action: "Login", .statusCode: 403]
                )
            )
        }
        await harness.store.finish()

        #expect(harness.store.state.challengeRounds == 2)
        #expect(harness.store.state.destination == nil)
        // Each round replaced the held pair, so the third POST carried the most recent one (D-06).
        #expect(harness.receivedClearances.value == [nil, Self.firstClearance, Self.secondClearance])
    }

    // MARK: - D-06: a pair held from earlier in the session is attached proactively

    @MainActor
    @Test
    func heldClearanceIsAttachedToTheVeryFirstPost() async throws {
        let passing = try Self.passingResponse()
        let harness = Self.makeHarness(
            responses: [passing],
            cookieClient: .testing(memberID: Self.memberID, passHash: Self.passHash),
            heldClearance: Self.heldClearance
        )

        await harness.store.send(.login) { state in
            state.loginState = .loading
        }
        await harness.store.receive(.loginDone(.success(passing))) { state in
            state.loginState = .idle
        }
        await harness.store.finish()

        // No challenge was ever presented because the still-valid pair rode along from the start —
        // which is why an expiring clearance needs no timer.
        #expect(harness.receivedClearances.value == [Self.heldClearance])
        #expect(harness.store.state.challengeRounds == 0)
    }

    // MARK: - Hardening: a capture with nothing on screen is ignored

    @MainActor
    @Test
    func captureWithNoChallengePresentedIsIgnored() async {
        let harness = Self.makeHarness(responses: [])

        // No state mutation and no effect: a straggler from an already-cancelled surface must not
        // write the shared holder or start a POST.
        await harness.store.send(.challengeClearanceCaptured(Self.firstClearance))
        await harness.store.finish()

        #expect(harness.store.state.cloudflareClearance == nil)
        #expect(harness.receivedClearances.value.isEmpty)
    }

    // MARK: - D-02: both ways out of the sheet are silent

    @MainActor
    @Test
    func swipingTheChallengeAwayAbortsTheAttemptSilently() async throws {
        let harness = Self.makeHarness(responses: [try Self.challengedResponse()])

        await harness.store.send(.login) { state in
            state.loginState = .loading
        }
        await harness.store.receive(.challengeDetected) { state in
            state.challengeRounds = 1
            state.destination = .challenge(Defaults.URL.login)
        }
        // The action SwiftUI actually sends for a swipe on a state-only destination. It is NOT
        // `.destination(.dismiss)`: every `Destination` case is `@ReducerCaseIgnored`, so no
        // `PresentationAction` is ever routed and the swipe arrives as a plain binding write.
        // This case used to drive `.dismiss` and passed while production did nothing at all —
        // the sheet went away and the login button span forever.
        await harness.store.send(.binding(.set(\.destination, nil))) { state in
            state.loginState = .idle
            state.destination = nil
        }
        // Nothing else arrives. On an exhaustive store that silence IS the assertion: a retry or an
        // error toast would surface here as an unasserted action or an unasserted state change.
        await harness.store.finish()

        #expect(harness.store.state.toast == nil)
        #expect(harness.store.state.cloudflareClearance == nil)
        #expect(harness.receivedClearances.value == [nil])
    }

    @MainActor
    @Test
    func cancellingTheChallengeIsSilentAndLeavesTheNextAttemptAFullBudget() async throws {
        let passing = try Self.passingResponse()
        let harness = Self.makeHarness(
            responses: [try Self.challengedResponse(), passing],
            cookieClient: .testing(memberID: Self.memberID, passHash: Self.passHash)
        )

        await harness.store.send(.login) { state in
            state.loginState = .loading
        }
        await harness.store.receive(.challengeDetected) { state in
            state.challengeRounds = 1
            state.destination = .challenge(Defaults.URL.login)
        }
        await harness.store.send(.cancelChallenge) { state in
            state.destination = nil
            state.loginState = .idle
        }

        // A fresh tap is a fresh attempt, so the round counter starts over rather than resuming
        // wherever the cancelled attempt left it.
        await harness.store.send(.login) { state in
            state.loginState = .loading
            state.challengeRounds = 0
        }
        await harness.store.receive(.loginDone(.success(passing))) { state in
            state.loginState = .idle
        }
        await harness.store.finish()

        #expect(harness.store.state.toast == nil)
    }

    // MARK: - D-11: the failure toast taps through to the detail surface

    @MainActor
    @Test
    func tappingTheFailureToastPresentsTheErrorInfoSurface() async {
        let errorInfo = ErrorInfo(
            error: .cloudflareChallengeFailed,
            context: [.action: "Login", .statusCode: 403]
        )
        let harness = Self.makeHarness(responses: [], toast: .error(errorInfo))

        await harness.store.send(.presentErrorInfo(errorInfo)) { state in
            state.destination = .errorInfo(errorInfo)
        }
        await harness.store.finish()
    }

    // MARK: - Regression: the web-login flow is untouched

    @MainActor
    @Test
    func webLoginPresentationAndDismissalAreUnaffectedByTheChallengeHandling() async {
        let harness = Self.makeHarness(responses: [])

        await harness.store.send(.presentWebView(Defaults.URL.webLogin)) { state in
            state.destination = .webView(Defaults.URL.webLogin)
        }
        // The dismiss handler is guarded on the challenge case, so a web-login dismissal still runs
        // the plain `.ifLet` teardown: no abort, no `loginState` change, no cancellation.
        await harness.store.send(.destination(.dismiss)) { state in
            state.destination = nil
        }
        await harness.store.finish()

        #expect(harness.store.state.loginState == .idle)
        #expect(harness.store.state.toast == nil)
    }

    // MARK: - Regression: the response's credentials are applied before success is judged

    @MainActor
    @Test
    func credentialsFromTheResponseApplyBeforeSuccessIsJudged() async throws {
        let response = try Self.credentialBearingResponse()
        // An *empty* jar, unlike every other success case in this suite. A clearance-carrying retry
        // sets `httpShouldHandleCookies = false`, so URLSession files nothing itself and the
        // reducer's own `setCredentials` is the only thing that can make `didLogin` true. Handing
        // the reducer a pre-populated jar — which the other cases do, for their own good reasons —
        // is exactly what let this ordering bug through an otherwise exhaustive suite.
        let harness = Self.makeHarness(responses: [response], cookieClient: .testing())

        await harness.store.send(.login) { state in
            state.loginState = .loading
        }
        await harness.store.receive(.loginDone(.success(response))) { state in
            state.loginState = .idle
        }
        await harness.store.finish()

        // Reading `didLogin` before applying the response reported this *successful* login as a
        // failure: `.failed(.unknown)`, an error toast, and a login screen that never popped.
        #expect(harness.store.state.loginState == .idle)
        #expect(harness.store.state.toast == nil)
        #expect(harness.dismissCount.value == 1)
    }

    // MARK: - Fixtures

    private static let memberID = "member-fixture"
    private static let passHash = "pass-fixture"
    private static let username = "username-fixture"
    private static let password = "password-fixture"
    private static let firstClearance = CloudflareClearance(
        cookieValue: "clearance-fixture-first", userAgent: "user-agent-fixture-first"
    )
    private static let secondClearance = CloudflareClearance(
        cookieValue: "clearance-fixture-second", userAgent: "user-agent-fixture-second"
    )
    private static let heldClearance = CloudflareClearance(
        cookieValue: "clearance-fixture-held", userAgent: "user-agent-fixture-held"
    )

    /// The exact shape the edge returns for a wall: a 403 carrying `cf-mitigated: challenge`.
    private static func challengedResponse() throws -> HTTPURLResponse {
        try #require(
            HTTPURLResponse(
                url: Defaults.URL.login,
                statusCode: 403,
                httpVersion: nil,
                headerFields: ["cf-mitigated": "challenge"]
            )
        )
    }

    /// A 200 whose `Set-Cookie` carries the credentials a real successful login returns, so
    /// `setCredentials` has something to file into the jar `didLogin` then reads.
    private static func credentialBearingResponse() throws -> HTTPURLResponse {
        try #require(
            HTTPURLResponse(
                url: Defaults.URL.login,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [
                    "Set-Cookie": "\(Defaults.Cookie.ipbMemberId)=\(memberID); "
                        + "\(Defaults.Cookie.ipbPassHash)=\(passHash); path=/"
                ]
            )
        )
    }

    private static func passingResponse() throws -> HTTPURLResponse {
        try #require(
            HTTPURLResponse(url: Defaults.URL.login, statusCode: 200, httpVersion: nil, headerFields: nil)
        )
    }

    /// A `TestStore` plus the two recorders that make the seam observable.
    private struct Harness {
        let store: TestStoreOf<LoginReducer>
        /// The `clearance` argument each scripted POST received, in call order — `nil` for a bare one.
        let receivedClearances: LockIsolated<[CloudflareClearance?]>
        /// How many times the reducer popped the login screen.
        let dismissCount: LockIsolated<Int>
    }

    /// Builds a store around a scripted `LoginClient`.
    ///
    /// Every case gets its own `InMemoryStorage`, so the process-wide `@Shared(.cloudflareClearance)`
    /// holder cannot leak a pair from one case into the next (T-12-20). `heldClearance` is seeded into
    /// that storage *before* the store exists, which is what a pair earned earlier in a session looks
    /// like from the reducer's point of view.
    @MainActor
    private static func makeHarness(
        responses: [HTTPURLResponse],
        cookieClient: CookieClient = .testing(),
        heldClearance: CloudflareClearance? = nil,
        focusedField: LoginReducer.FocusedField? = nil,
        toast: AppAlertState<Never>? = nil
    ) -> Harness {
        let storage = InMemoryStorage()
        if let heldClearance {
            withDependencies {
                $0.defaultInMemoryStorage = storage
            } operation: {
                @Shared(.cloudflareClearance) var clearance
                $clearance.withLock({ $0 = heldClearance })
            }
        }

        let remaining = LockIsolated(responses)
        let receivedClearances = LockIsolated([CloudflareClearance?]())
        let dismissCount = LockIsolated(0)
        let loginClient = LoginClient { _, _, clearance in
            receivedClearances.withValue({ $0.append(clearance) })
            return remaining.withValue { steps in
                guard !steps.isEmpty else {
                    Issue.record("The LoginClient stub ran out of scripted responses.")
                    return nil
                }
                return steps.removeFirst()
            }
        }

        let store = TestStore(
            initialState: makeInitialState(focusedField: focusedField, toast: toast),
            reducer: LoginReducer.init
        ) {
            $0.defaultInMemoryStorage = storage
            $0.cookieClient = cookieClient
            $0.hapticsClient = .noop
            $0.loginClient = loginClient
            $0.dismiss = DismissEffect { dismissCount.withValue({ $0 += 1 }) }
        }
        return Harness(store: store, receivedClearances: receivedClearances, dismissCount: dismissCount)
    }

    // Evaluated inside `TestStore.init`'s prepared dependencies (the parameter is an autoclosure), so
    // the state's `@Shared` holder resolves against this case's own storage.
    private static func makeInitialState(
        focusedField: LoginReducer.FocusedField?,
        toast: AppAlertState<Never>?
    ) -> LoginReducer.State {
        var state = LoginReducer.State()
        state.username = username
        state.password = password
        state.focusedField = focusedField
        state.toast = toast
        return state
    }
}
