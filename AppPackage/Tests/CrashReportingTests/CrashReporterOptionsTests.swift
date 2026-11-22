import AppModels
@testable import CrashReporting
import Sentry
import Testing

/// Every SDK switch that could record more than the crash is asserted here, so a changed SDK default, a
/// removed line or a reordered edit cannot turn one on unnoticed.
@Suite
struct CrashReporterOptionsTests {
    private static let dsn = "https://0123456789abcdef0123456789abcdef@o0.ingest.example.invalid/0"

    private let options = CrashReporter.options(dsn: Self.dsn, channel: .github)

    @Test
    func carriesTheDsnAndTheChannelAsTheEnvironment() {
        #expect(options.dsn == Self.dsn)
        #expect(options.environment == "github")
    }

    @Test(arguments: DistributionChannel.allCases)
    func theEnvironmentIsTheChannelsRawValue(_ channel: DistributionChannel) {
        let options = CrashReporter.options(dsn: Self.dsn, channel: channel)

        #expect(options.environment == channel.rawValue)
    }

    @Test
    func keepsTheSdkDefaultsForReleaseAndDist() {
        #expect(options.releaseName == Options().releaseName)
        #expect(options.dist == nil)
    }

    @Test
    func configuresNoTracingProfilingOrReplay() {
        #expect(options.tracesSampleRate == nil)
        #expect(options.tracesSampler == nil)
        #expect(!options.isTracingEnabled)
        #expect(options.configureProfiling == nil)
        #expect(options.sessionReplay.sessionSampleRate == 0)
        #expect(options.sessionReplay.onErrorSampleRate == 0)
    }

    @Test
    func sendsNoDefaultPii() {
        #expect(!options.sendDefaultPii)
    }

    @Test
    func recordsCrashesOnly() {
        #expect(options.enableCrashHandler)
        #expect(options.attachStacktrace)
        #expect(!options.enableAutoSessionTracking)
        #expect(!options.enableWatchdogTerminationTracking)
        #expect(!options.enableAppHangTracking)
        #expect(!options.enableCaptureFailedRequests)
    }

    @Test
    func recordsNothingAboutTheNetworkOrTheScreen() {
        #expect(!options.enableNetworkBreadcrumbs)
        #expect(!options.enableAutoBreadcrumbTracking)
        #expect(!options.enableSwizzling)
        #expect(!options.enableDataSwizzling)
        #expect(!options.enableFileManagerSwizzling)
        #expect(options.maxBreadcrumbs == 0)
        #expect(options.maxFeatureFlags == 0)
        #expect(!options.attachScreenshot)
        #expect(!options.attachViewHierarchy)
    }

    @Test
    func switchesTracingInstrumentationOff() {
        #expect(!options.enableAutoPerformanceTracing)
        #expect(!options.enableNetworkTracking)
        #expect(!options.enableFileIOTracing)
        #expect(!options.enableCoreDataTracing)
        #expect(!options.enableUIViewControllerTracing)
        #expect(!options.enableUserInteractionTracing)
        #expect(!options.enablePreWarmedAppStartTracing)
        #expect(!options.enableStandaloneAppStartTracing)
        #expect(!options.enableTimeToFullDisplayTracing)
        #expect(!options.enableGraphQLOperationTracking)
        #expect(!options.enablePersistingTracesWhenCrashing)
        #expect(!options.enablePropagateTraceparent)
    }

    @Test
    func switchesEveryOtherSignalOff() {
        #expect(!options.enableMetrics)
        #expect(!options.enableLogs)
        #expect(!options.enableSpotlight)
        #expect(!options.enableMemoryIntrospection)
        #expect(!options.sendClientReports)
        #expect(!options.enableMetricKit)
        #expect(!options.enableMetricKitRawPayload)
        #expect(!options.enableScopePersistence)
        #expect(options.experimental.metrickit.enabledDiagnosticReports.isEmpty)
        #expect(options.experimental.metrickit.enabledMetricReports.isEmpty)
    }

    // This test is nonisolated, so it also proves the callback carries no main-actor isolation: Swift 6
    // traps when a main-actor closure runs elsewhere, which is where the SDK calls it.
    @Test
    func beforeSendScrubsTheEventAndNeverDropsIt() throws {
        let beforeSend = try #require(options.beforeSend)
        let event = Event()
        event.user = Sentry.User(userId: "someone")
        event.context = ["custom": ["key": "value"], "os": ["name": "iOS"]]

        let result = beforeSend(event)

        #expect(result === event)
        #expect(event.user == nil)
        #expect(event.context?["custom"] == nil)
        #expect(event.context?["os"]?["name"] as? String == "iOS")
    }
}
