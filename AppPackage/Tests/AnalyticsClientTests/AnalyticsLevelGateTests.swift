@testable import AnalyticsClient
import AppModels
import ComposableArchitecture
import CookieClient
import Foundation
import Sharing
import Testing

// The analytics level decides what leaves the app (D-06a, D-06b, D-06f, DD-09a), proven against a
// recording `TelemetrySDK` and a recording install-signal trigger, with a non-nil test app ID. The
// signals are the rendering suite's fixtures, so a case added to `AnalyticsSignal` needs a fixture
// (its count is pinned there), a `minimumLevel` (the switch is exhaustive) and an entry in
// `basicCases` or `fullOnlyCases` below, or this suite fails.
//
// Each case has its own in-memory defaults for `@Shared(.setting)`, so the cases run in parallel; a
// "relaunch" is a new client over the same defaults and the same recorders.
@Suite
struct AnalyticsLevelGateTests {
    /// Screens and features, and kinds of errors (D-06f), and the 3.0 flows (20-12, signed off): the
    /// first-launch screens, the analytics choice and comment moderation, all under "which screens and
    /// features you use".
    private static let basicCases: Set<String> = [
        "tabOpened", "homeSectionViewed", "filterPanelOpened", "quickSearchPanelOpened", "savedSearchUsed",
        "tagTapped", "searchPerformed", "errorSurfaced", "loginFailed", "cloudflareChallengeEncountered",
        "firstLaunchCompleted", "analyticsLevelChanged", "commentReportOutcome", "commentPosterBlocked",
        "commentPosterUnblocked", "blockedCommentShown", "commentPostingWarningAnswered"
    ]
    /// Reading and download activity (D-06f).
    private static let fullOnlyCases: Set<String> = [
        "galleryDetailOpened", "readingSessionEnded", "downloadStateChanged"
    ]
    /// The one default parameter at Basic: where the app came from (20-12 §3, owner msg 2842).
    private static let basicDefaultParameterKeys: Set<String> = ["App.distributionChannel"]
    private static let defaultParameterKeys: Set<String> = [
        "App.host", "App.loggedIn", "App.readingDirection", "App.dualPageMode", "App.translateTags",
        "App.distributionChannel"
    ]

    // MARK: Before the choice

    @Test
    func noLevelMakesNoSDKCallAndNoInstallSignal() {
        let harness = GateHarness(level: nil)

        harness.client.apply(nil)
        harness.sendEveryFixture()

        #expect(harness.sdk.calls.value.isEmpty)
        #expect(harness.installSignals.value == 0)
    }

    @Test(arguments: [nil, .minimal, .basic, .full] as [AnalyticsLevel?])
    func aSignalSentBeforeAnyApplyIsDropped(level: AnalyticsLevel?) {
        let harness = GateHarness(level: level)

        harness.sendEveryFixture()

        #expect(harness.sdk.calls.value.isEmpty)
        #expect(harness.installSignals.value == 0)
    }

    // MARK: Minimal

    @Test
    func minimalSendsTheInstallSignalAndNeverInitialisesTheSDK() {
        let harness = GateHarness(level: .minimal)

        harness.client.apply(.minimal)
        harness.sendEveryFixture()
        harness.client.apply(.minimal)
        harness.sendEveryFixture()

        #expect(harness.installSignals.value == 2)
        #expect(harness.sdk.calls.value.isEmpty)
    }

    @Test
    func minimalNeverInitialisesTheSDKAcrossARelaunch() {
        let harness = GateHarness(level: .minimal)
        harness.client.apply(.minimal)
        harness.sendEveryFixture()

        let relaunched = harness.relaunched()
        relaunched.client.apply(.minimal)
        relaunched.sendEveryFixture()

        #expect(harness.sdk.initializeCount == 0)
        #expect(harness.sdk.calls.value.isEmpty)
        // Each apply asks the sender; the sender itself sends once per install
        // (`InstallSignalSenderTests`).
        #expect(harness.installSignals.value == 2)
    }

    // MARK: Basic

    @Test
    func basicInitialisesTheSDKOnceAndSendsTheInstallSignal() {
        let harness = GateHarness(level: .basic)

        harness.client.apply(.basic)
        harness.client.apply(.basic)

        #expect(harness.sdk.initializeCount == 1)
        #expect(harness.sdk.calls.value.first == .initialize(appID: GateHarness.appID, salt: GateHarness.salt))
        #expect(harness.installSignals.value == 2)
    }

    @Test
    func basicSendsExactlyTheScreenFeatureAndErrorSignalsWithOnlyTheChannelAsADefaultParameter() {
        let harness = GateHarness(level: .basic)
        harness.client.apply(.basic)

        let sent = harness.sendEachFixtureRecordingWhatReachedTheSDK()

        #expect(Set(sent.keys) == Self.basicCases)
        for (name, defaultParameters) in sent {
            #expect(
                Set(defaultParameters.keys) == Self.basicDefaultParameterKeys,
                "\(name) carried \(defaultParameters.keys.sorted())"
            )
        }
    }

    // MARK: Full

    @Test
    func fullSendsEverySignalWithTheFiveSettingsParametersAndTheChannel() {
        let harness = GateHarness(level: .full)
        harness.client.apply(.full)

        let sent = harness.sendEachFixtureRecordingWhatReachedTheSDK()

        #expect(Set(sent.keys) == Self.basicCases.union(Self.fullOnlyCases))
        #expect(sent.count == 20)
        for (name, defaultParameters) in sent {
            #expect(Set(defaultParameters.keys) == Self.defaultParameterKeys, "\(name)")
        }
        #expect(harness.sdk.initializeCount == 1)
    }

    // MARK: Level changes

    @Test
    func loweringToMinimalTerminatesTheSDKAndDropsEverySignal() {
        let harness = GateHarness(level: .full)
        harness.client.apply(.full)

        harness.setLevel(.minimal)
        harness.client.apply(.minimal)
        let before = harness.sdk.calls.value.count
        harness.sendEveryFixture()
        harness.client.apply(.minimal)

        #expect(harness.sdk.terminateCount == 1)
        #expect(harness.sdk.calls.value.dropFirst(before).isEmpty)
        #expect(harness.sdk.calls.value.map(\.kind) == [.initialize, .terminate])
    }

    @Test
    func raisingFromMinimalInitialisesTheSDKAgain() {
        let harness = GateHarness(level: .full)
        harness.client.apply(.full)
        harness.setLevel(.minimal)
        harness.client.apply(.minimal)

        harness.setLevel(.basic)
        harness.client.apply(.basic)

        #expect(harness.sdk.initializeCount == 2)
        #expect(harness.sdk.terminateCount == 1)
        #expect(harness.sdk.calls.value.map(\.kind) == [.initialize, .terminate, .initialize])
        #expect(harness.installSignals.value == 3)
    }

    @Test
    func loweringFromFullToBasicKeepsTheSDKAndDropsTheFullOnlySignals() {
        let harness = GateHarness(level: .full)
        harness.client.apply(.full)

        harness.setLevel(.basic)
        harness.client.apply(.basic)
        let sent = harness.sendEachFixtureRecordingWhatReachedTheSDK()

        #expect(harness.sdk.initializeCount == 1)
        #expect(harness.sdk.terminateCount == 0)
        #expect(Set(sent.keys) == Self.basicCases)
    }

    // A level stored lower than the running SDK, before `apply` catches up, already drops signals:
    // `send` reads the stored level live.
    @Test
    func theStoredLevelGatesSignalsBeforeApplyCatchesUp() {
        let harness = GateHarness(level: .full)
        harness.client.apply(.full)
        harness.sdk.calls.setValue([])

        harness.setLevel(.minimal)
        harness.sendEveryFixture()
        harness.setLevel(nil)
        harness.sendEveryFixture()

        #expect(harness.sdk.calls.value.isEmpty)
    }

    // MARK: Classification

    @Test(arguments: AnalyticsSignalRenderingTests.fixtures)
    func everySignalHasTheLevelItsDescriptionPromises(fixture: SignalRenderingFixture) {
        let name = GateHarness.caseName(of: fixture.signal)
        let expected: AnalyticsLevel? = if Self.basicCases.contains(name) {
            .basic
        } else if Self.fullOnlyCases.contains(name) {
            .full
        } else {
            nil
        }

        #expect(expected != nil, "\(name) has no expected level in this suite")
        #expect(fixture.signal.minimumLevel == expected)
        #expect(!fixture.signal.isSent(at: nil))
        #expect(!fixture.signal.isSent(at: .minimal))
        #expect(fixture.signal.isSent(at: .basic) == (expected == .basic))
        #expect(fixture.signal.isSent(at: .full))
    }

    @Test
    func theClassificationCoversEveryCaseOnce() {
        let names = AnalyticsSignalRenderingTests.fixtures.map({ GateHarness.caseName(of: $0.signal) })

        #expect(Set(names).count == 20)
        #expect(Self.basicCases.isDisjoint(with: Self.fullOnlyCases))
        #expect(Set(names) == Self.basicCases.union(Self.fullOnlyCases))
    }
}

// MARK: Recorders

/// One SDK call, as the recording fake saw it.
enum SDKCall: Equatable, Sendable {
    case initialize(appID: String, salt: String?)
    case terminate
    case signal(name: String, defaultParameters: [String: String])
    case errorOccurred(id: String, defaultParameters: [String: String])

    enum Kind: Equatable {
        case initialize
        case terminate
        case signal
    }

    var kind: Kind {
        switch self {
        case .initialize:
            .initialize

        case .terminate:
            .terminate

        case .signal, .errorOccurred:
            .signal
        }
    }
}

/// Records every call, and evaluates the configured default parameters at each signal, as the SDK
/// does.
final class RecordingSDK: Sendable {
    let calls = LockIsolated<[SDKCall]>([])
    private let configuration = LockIsolated<TelemetrySDK.Configuration?>(nil)

    var initializeCount: Int {
        calls.value.filter({ $0.kind == .initialize }).count
    }

    var terminateCount: Int {
        calls.value.filter({ $0.kind == .terminate }).count
    }

    var sdk: TelemetrySDK {
        TelemetrySDK(
            initialize: { [calls, configuration] config in
                configuration.setValue(config)
                calls.withValue({ $0.append(.initialize(appID: config.appID, salt: config.salt)) })
            },
            terminate: { [calls, configuration] in
                configuration.setValue(nil)
                calls.withValue({ $0.append(.terminate) })
            },
            signal: { [calls, configuration] name, _ in
                let defaultParameters = configuration.value?.defaultParameters() ?? [:]
                calls.withValue({ $0.append(.signal(name: name, defaultParameters: defaultParameters)) })
            },
            errorOccurred: { [calls, configuration] id, _, _ in
                let defaultParameters = configuration.value?.defaultParameters() ?? [:]
                calls.withValue({ $0.append(.errorOccurred(id: id, defaultParameters: defaultParameters)) })
            }
        )
    }
}

/// A live-gated client over a recording SDK and a counting install trigger, with its own storage.
struct GateHarness {
    static let appID = "TEST-APP-ID"
    static let salt = "test-salt"

    let defaults: UserDefaults
    let sdk: RecordingSDK
    let installSignals: LockIsolated<Int>
    let client: AnalyticsClient

    init(
        level: AnalyticsLevel?,
        defaults: UserDefaults = .inMemory,
        sdk: RecordingSDK = RecordingSDK(),
        installSignals: LockIsolated<Int> = LockIsolated(0)
    ) {
        self.defaults = defaults
        self.sdk = sdk
        self.installSignals = installSignals
        client = AnalyticsClient.live(
            appID: Self.appID,
            salt: Self.salt,
            sdk: sdk.sdk,
            installSignal: InstallSignalTrigger(ensureSent: { installSignals.withValue({ $0 += 1 }) })
        )
        setLevel(level)
    }

    /// A new client over the same storage and recorders, as after a relaunch.
    func relaunched() -> Self {
        withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            @Shared(.setting) var setting
            return Self(level: setting.analyticsLevel, defaults: defaults, sdk: sdk, installSignals: installSignals)
        }
    }

    func setLevel(_ level: AnalyticsLevel?) {
        withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            @Shared(.setting) var setting
            $setting.withLock {
                $0.analyticsLevel = level
                $0.galleryHost = .ehentai
            }
        }
    }

    func sendEveryFixture() {
        withDependencies {
            $0.defaultAppStorage = defaults
            $0.cookieClient = .testing()
        } operation: {
            for fixture in AnalyticsSignalRenderingTests.fixtures {
                client.send(fixture.signal)
            }
        }
    }

    /// Sends each fixture alone and returns, by case name, the default parameters of each one that
    /// reached the SDK.
    func sendEachFixtureRecordingWhatReachedTheSDK() -> [String: [String: String]] {
        var reached: [String: [String: String]] = [:]
        withDependencies {
            $0.defaultAppStorage = defaults
            $0.cookieClient = .testing()
        } operation: {
            for fixture in AnalyticsSignalRenderingTests.fixtures {
                let before = sdk.calls.value.count
                client.send(fixture.signal)
                for call in sdk.calls.value.dropFirst(before) {
                    switch call {
                    case .signal(_, let defaultParameters), .errorOccurred(_, let defaultParameters):
                        reached[Self.caseName(of: fixture.signal)] = defaultParameters

                    case .initialize, .terminate:
                        break
                    }
                }
            }
        }
        return reached
    }

    /// The case's name, without its associated values.
    static func caseName(of signal: AnalyticsSignal) -> String {
        let description = String(describing: signal)
        return String(description.prefix(while: { $0 != "(" }))
    }
}
