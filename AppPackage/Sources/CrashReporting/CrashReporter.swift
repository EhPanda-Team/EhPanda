import AppModels
import Foundation
import Sentry

/// Crash reporting: records crashes only, and nothing about the person.
///
/// Nothing here ever sends a report by hand. The only reports are the crashes the SDK finds on the next
/// launch after one happened, scrubbed by ``CrashReportScrubber`` before they leave the device. The
/// `crash_reporting_start_only` lint rule keeps it that way: `SentrySDK.start` is the one SDK call.
///
/// Crash reports are not analytics data, so starting the SDK does not wait for, read or depend on the
/// analytics choice (`Setting.analyticsLevel`): it runs at launch under every level.
public enum CrashReporter {
    /// The environment key XCTest sets in every process it hosts.
    static let xcTestHostKey = "XCTestConfigurationFilePath"

    /// Whether this is a Debug build. The only conditional compilation of the module lives here, so the
    /// call site stays outside any DEBUG logic.
    static let isDebugBuild: Bool = {
        #if DEBUG
        true
        #else
        false
        #endif
    }()

    /// Starts crash reporting for this process, and reports whether it started.
    ///
    /// The app delegate calls it as the first statement of its launch path, so that a crash anywhere
    /// later in launch is still caught.
    @MainActor
    @discardableResult
    public static func start() -> Bool {
        start(
            dsn: AppInfo.sentryDSN,
            channel: DistributionChannel.current,
            isDebugBuild: isDebugBuild,
            processEnvironment: ProcessInfo.processInfo.environment,
            startSDK: { SentrySDK.start(options: $0) }
        )
    }

    /// The start rule, testable: it takes everything it decides on, and reports whether it started.
    ///
    /// It refuses, without calling `startSDK`, in three cases:
    /// - A Debug build. Every EhPanda unit test, UI test, hosted visual test, capture and launch
    ///   automation run exists only in Debug builds, so this one refusal keeps all of them out of the
    ///   crash data. The module deliberately never reads the app's automation environment keys: the
    ///   Release isolation scan forbids their text in a Release binary.
    /// - A process hosted by XCTest, in any configuration (a test host can be built in Release).
    /// - A missing or empty DSN, which is every build from source and every fork: only the release
    ///   workflows supply one (see `AppInfo.sentryDSN`).
    @discardableResult
    static func start(
        dsn: String?,
        channel: DistributionChannel,
        isDebugBuild: Bool,
        processEnvironment: [String: String],
        startSDK: (Options) -> Void
    ) -> Bool {
        guard !isDebugBuild,
              processEnvironment[xcTestHostKey] == nil,
              let dsn, !dsn.isEmpty
        else { return false }
        startSDK(options(dsn: dsn, channel: channel))
        return true
    }

    /// The SDK options.
    ///
    /// Every switch that could record more than the crash is set explicitly, so a changed SDK default
    /// cannot turn it on, and the SDK is pinned exactly so that a new option can only arrive through a
    /// reviewed bump that rechecks this list. Release and dist stay at the SDK defaults, and no traces
    /// sample rate, sampler, profiling or replay is configured.
    ///
    /// This is nonisolated on purpose. The SDK calls `beforeSend` on its own queue, and a closure
    /// literal formed inside a `@MainActor` function is inferred main-actor-isolated, which Swift 6
    /// traps on when the closure then runs off the main thread.
    static func options(dsn: String, channel: DistributionChannel) -> Options {
        let options = Options()
        options.dsn = dsn
        options.environment = channel.rawValue

        // Nothing about the person: no default PII, and no user is ever set.
        options.sendDefaultPii = false

        // Crashes only.
        options.enableCrashHandler = true
        options.attachStacktrace = true
        options.enableAutoSessionTracking = false
        options.enableWatchdogTerminationTracking = false
        options.enableAppHangTracking = false
        options.enableCaptureFailedRequests = false

        // Nothing about the network or the screen.
        options.enableNetworkBreadcrumbs = false
        options.enableAutoBreadcrumbTracking = false
        options.enableSwizzling = false
        options.enableDataSwizzling = false
        options.enableFileManagerSwizzling = false
        options.maxBreadcrumbs = 0
        options.maxFeatureFlags = 0
        options.attachScreenshot = false
        options.attachViewHierarchy = false

        // No tracing or profiling instrumentation.
        options.enableAutoPerformanceTracing = false
        options.enableNetworkTracking = false
        options.enableFileIOTracing = false
        options.enableCoreDataTracing = false
        options.enableUIViewControllerTracing = false
        options.enableUserInteractionTracing = false
        options.enablePreWarmedAppStartTracing = false
        options.enableStandaloneAppStartTracing = false
        options.enableTimeToFullDisplayTracing = false
        options.enableGraphQLOperationTracking = false
        options.enablePersistingTracesWhenCrashing = false
        options.enablePropagateTraceparent = false

        // No other signal: metrics, logs, replay, MetricKit, Spotlight, memory introspection, client reports
        // and the persisted scope.
        options.enableMetrics = false
        options.enableLogs = false
        options.enableSpotlight = false
        options.enableMemoryIntrospection = false
        options.sendClientReports = false
        options.enableMetricKit = false
        options.enableMetricKitRawPayload = false
        options.enableScopePersistence = false
        options.sessionReplay.sessionSampleRate = 0
        options.sessionReplay.onErrorSampleRate = 0
        options.experimental.metrickit.enabledDiagnosticReports = []
        options.experimental.metrickit.enabledMetricReports = []

        // Last, and formed here and never in `start()`: every event passes the scrubber before it is sent.
        options.beforeSend = { CrashReportScrubber.scrub($0) }
        return options
    }
}
