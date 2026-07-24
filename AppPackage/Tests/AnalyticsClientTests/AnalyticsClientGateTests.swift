import AnalyticsClient
import ComposableArchitecture
import Testing

// Where D-13's absent-credential gate is proven. Under the test host there is no build-time app ID
// (`AppInfoAnalyticsTests` pins that), so `AnalyticsClient.live` is structurally the no-op client and
// the SDK is never referenced. A passing run counts as proof precisely because a reachable-but-
// uninitialized SDK would raise its own assertion during these calls: driving every signal through
// the live client without a crash or a reported issue *is* the assertion that it is unreachable.
//
// The suite also pins the two clients every later instrumentation plan inherits — the loud
// `unimplemented` default and the `.noop`-derived spy — so those plans build on a known-good pattern.
@Suite
struct AnalyticsClientGateTests {
    // Every signal fixture drives the live client and `start`, under the test host where no app ID is
    // present. If the gate were wrong and the SDK were reached, its uninitialized-manager assertion
    // would fire here; a green run is the proof that a nil app ID makes the whole client inert.
    @Test
    func theLiveClientIsInertUnderTheTestHost() {
        AnalyticsClient.live.start()

        for fixture in AnalyticsSignalRenderingTests.fixtures {
            AnalyticsClient.live.send(fixture.signal)
        }
    }

    // The explicit no-op accepts every fixture case and `start` without effect — the shape a nil app
    // ID resolves `live` to.
    @Test
    func theNoopClientAcceptsEverySignalWithoutEffect() {
        AnalyticsClient.noop.start()

        for fixture in AnalyticsSignalRenderingTests.fixtures {
            AnalyticsClient.noop.send(fixture.signal)
        }
    }

    // The test default is the unimplemented client, so an un-hardened test that emits fails loudly.
    // `withKnownIssue` both catches the reported issue and fails if none is reported, so the loud
    // default is proven loud rather than assumed (D-12 / wave 5's premise).
    @Test
    func theUnimplementedClientReportsAnIssueWhenSendIsCalled() {
        withKnownIssue {
            AnalyticsClient.unimplemented.send(.cloudflareChallengeEncountered)
        }
    }

    @Test
    func theUnimplementedClientReportsAnIssueWhenStartIsCalled() {
        withKnownIssue {
            AnalyticsClient.unimplemented.start()
        }
    }

    // The spy idiom every later instrumentation plan uses: take `.noop`, replace `send` with a
    // `LockIsolated`-backed collector, and the client records exactly the signals it is given, in
    // order. Proving it here means those plans inherit a known-good capture pattern.
    @Test
    func aSpyBuiltFromNoopRecordsEverySignalInOrder() {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        var client = AnalyticsClient.noop
        client.send = { signal in recorded.withValue({ $0.append(signal) }) }

        let signals = AnalyticsSignalRenderingTests.fixtures.map(\.signal)
        for signal in signals {
            client.send(signal)
        }

        #expect(recorded.value == signals)
    }
}
