import AppModels
@testable import CrashReporting
import Sentry
import Testing

/// What the start rule does, through the overload that takes everything it decides on. The live entry is
/// covered once, under the test host.
@Suite
struct CrashReporterStartTests {
    private static let dsn = "https://0123456789abcdef0123456789abcdef@o0.ingest.example.invalid/0"

    /// Records how many times, and with which options, the SDK would have been started.
    private final class StartRecorder {
        private(set) var started: [Options] = []

        func record(_ options: Options) {
            started.append(options)
        }
    }

    @Test(arguments: [nil, ""])
    func neverStartsWithoutADsn(_ dsn: String?) {
        let recorder = StartRecorder()

        let started = CrashReporter.start(
            dsn: dsn,
            channel: .github,
            isDebugBuild: false,
            processEnvironment: [:],
            startSDK: recorder.record
        )

        #expect(!started)
        #expect(recorder.started.isEmpty)
    }

    @Test
    func neverStartsInADebugBuild() {
        let recorder = StartRecorder()

        let started = CrashReporter.start(
            dsn: Self.dsn,
            channel: .github,
            isDebugBuild: true,
            processEnvironment: [:],
            startSDK: recorder.record
        )

        #expect(!started)
        #expect(recorder.started.isEmpty)
    }

    @Test
    func neverStartsInAProcessXCTestHosts() {
        let recorder = StartRecorder()

        let started = CrashReporter.start(
            dsn: Self.dsn,
            channel: .github,
            isDebugBuild: false,
            processEnvironment: [CrashReporter.xcTestHostKey: "/tmp/run.xctestconfiguration"],
            startSDK: recorder.record
        )

        #expect(!started)
        #expect(recorder.started.isEmpty)
    }

    @Test
    func startsOnceForAReleaseLaunchWithADsn() {
        let recorder = StartRecorder()

        let started = CrashReporter.start(
            dsn: Self.dsn,
            channel: .github,
            isDebugBuild: false,
            processEnvironment: ["HOME": "/var/mobile"],
            startSDK: recorder.record
        )

        #expect(started)
        #expect(recorder.started.count == 1)
        #expect(recorder.started.first?.dsn == Self.dsn)
    }

    @Test(arguments: DistributionChannel.allCases)
    func handsOverTheChannelAsTheEnvironment(_ channel: DistributionChannel) {
        let recorder = StartRecorder()

        CrashReporter.start(
            dsn: Self.dsn,
            channel: channel,
            isDebugBuild: false,
            processEnvironment: [:],
            startSDK: recorder.record
        )

        #expect(recorder.started.first?.environment == channel.rawValue)
    }

    @MainActor
    @Test
    func theLiveEntryNeverStartsUnderTheTestHost() {
        #expect(AppInfo.sentryDSN == nil)
        #expect(!CrashReporter.start())
    }
}
