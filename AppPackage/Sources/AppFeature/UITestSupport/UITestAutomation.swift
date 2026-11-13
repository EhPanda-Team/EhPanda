import AnalyticsClient
import AppLaunchAutomationClient
import ApplicationClient
import AppModels
import AppTools
import ClipboardClient
import ComposableArchitecture
import CookieClient
import DeviceClient
import DFClient
import DownloadClient
import Foundation
import HapticsClient
import LibraryClient
import ReadingFeature
import SearchFeature
import Sharing
import UIKit
import UserDefaultsClient
#if DEBUG && canImport(Appshot) && canImport(AppshotProtocol)
import AppshotProtocol
#endif

public enum UITestAutomation {
    public static var shouldDetectClipboardURL: Bool {
        #if DEBUG
        shouldDetectClipboardURL(environment: ProcessInfo.processInfo.environment)
        #else
        false
        #endif
    }

    public static func prepareIfNeeded() {
        #if DEBUG
        prepare(environment: ProcessInfo.processInfo.environment)
        #endif
    }

    #if DEBUG
    /// Which arm of `togglePause`'s refusal `EHPANDA_UITEST_FORCE_PAUSE_REFUSAL` forces.
    ///
    /// **The two values are the two refusals the boundary can actually answer**, and both are
    /// unreachable by hand on a device: `canTogglePause` excludes every status that produces them,
    /// so the control is only tappable during a render-versus-tap race the screen's own reload
    /// closes first (DEF-15-08). Set the key to exactly `notFound` or `unknown` — surrounding
    /// whitespace is trimmed, and any other value is not an override at all, the same disposition
    /// an unrecognised `EHPANDA_AUTOMATION_TAB` gets.
    ///
    /// **The override reaches BOTH surfaces**, because it replaces the endpoint rather than a
    /// screen's handling of it: the downloads list's swipe/context-menu Pause (which reports since
    /// DEF-15-05) and the inspector's Pause both raise it. Device recipe: launch with only this key
    /// set — no stubbed network, so the real library is on screen — open Downloads, and tap
    /// Pause/Resume on any active or paused download. The refusal toast appears from the list; the
    /// inspector's row does the same from inside the sheet.
    ///
    /// Note the one cost: installing the override reads `$0.downloadClient`, which creates the live
    /// `DownloadClient` inside `AppDelegate.init` — earlier than it would otherwise be built. That
    /// happens in DEBUG only, and only when this key is set.
    enum PauseRefusal: String, Sendable {
        case notFound
        case unknown

        var error: AppError {
            switch self {
            case .notFound: .notFound
            case .unknown: .unknown
            }
        }
    }

    /// The first-launch answers an automated launch starts from (D-03, A-8).
    ///
    /// Every UI test, capture and hosted visual-test launch would otherwise stop at the age wall, so
    /// each is preset past both screens unless `EHPANDA_UITEST_FIRST_LAUNCH` asks for the real first
    /// launch (`show`) or for its analytics choice alone (`analytics`), which the first-launch UI tests
    /// use. Any other value of the key is ignored, and the key is read only here, inside `#if DEBUG`
    /// (P-9).
    enum FirstLaunchPreset: Equatable, Sendable {
        /// The current age declaration confirmed and the Minimal level chosen. Test hosts carry no
        /// analytics app ID, so even Minimal's install signal is a no-op there.
        case answered
        /// Both answers cleared, so the launch meets the age wall, then the analytics choice.
        case cleared
        /// The current age declaration confirmed and the level cleared, so the launch opens on the
        /// analytics choice.
        case ageConfirmed

        static let environmentKey = "EHPANDA_UITEST_FIRST_LAUNCH"

        /// Writes this preset's answers into `setting`.
        func apply(to setting: inout Setting) {
            switch self {
            case .answered:
                setting.ageDeclarationVersion = AgeDeclaration.currentVersion
                setting.analyticsLevel = .minimal
            case .cleared:
                // Cleared rather than left alone: a stubbed launch keeps the simulator's storage, so
                // a preset an earlier launch wrote would otherwise skip the screens under test.
                setting.ageDeclarationVersion = nil
                setting.analyticsLevel = nil
            case .ageConfirmed:
                setting.ageDeclarationVersion = AgeDeclaration.currentVersion
                setting.analyticsLevel = nil
            }
        }
    }

    /// The stored state every stubbed-network launch starts from, so what a UI test finds stored never
    /// depends on the test that ran before it: a stubbed launch keeps the simulator's storage.
    ///
    /// `EHPANDA_UITEST_BLOCKED_USERS` holds the comment block list as a JSON array of
    /// `{"memberID": …, "name": …}` objects; absent or malformed, the list is empty.
    /// `EHPANDA_UITEST_DISPLAY_NAME` names the signed-in user for the own-comment tests; absent, no name is stored.
    /// Both keys are read only here, inside `#if DEBUG` (P-9).
    struct StoragePreset: Equatable, Sendable {
        static let blockedUsersEnvironmentKey = "EHPANDA_UITEST_BLOCKED_USERS"
        static let displayNameEnvironmentKey = "EHPANDA_UITEST_DISPLAY_NAME"

        /// Built through `block(memberID:name:)`, so each member ID is held once and an empty one is dropped.
        let blockedCommentUsers: [BlockedCommentUser]
        let displayName: String?

        init(blockedCommentUsers: [BlockedCommentUser], displayName: String?) {
            self.blockedCommentUsers = blockedCommentUsers.reduce(into: []) { list, user in
                list.block(memberID: user.memberID, name: user.name)
            }
            self.displayName = displayName
        }

        /// Replaces the stored block list and the user's display name in the current app storage.
        func apply() {
            @Shared(.blockedCommentUsers) var blockedUsers
            @Shared(.user) var user
            $blockedUsers.withLock({ $0 = blockedCommentUsers })
            $user.withLock({ $0.displayName = displayName })
        }
    }

    struct Configuration: Sendable {
        let fixtureDirectory: URL?
        let clipboardClient: ClipboardClient?
        let shouldStubNetwork: Bool
        let shouldUseVisualTestHost: Bool
        let pauseRefusal: PauseRefusal?
        /// A capture launch's validated scene. A capture takes no other UI-test key, so every
        /// other field is inert when this is set.
        let captureScene: CaptureScene?
        /// `nil` for a launch that only overrides a client (the clipboard, a pause refusal): it runs
        /// the real app on the user's data, answers included.
        let firstLaunchPreset: FirstLaunchPreset?
        /// A stubbed-network launch's stored block list and display name; `nil` for every other
        /// launch, including a hosted visual test, whose fresh storage already holds neither.
        var storagePreset: StoragePreset?
        /// `EHPANDA_UITEST_REQUEST_LOG`: the file the stub protocol appends each request it sees to.
        /// Only a stubbed-network launch has one.
        var requestLogURL: URL?
        /// `EHPANDA_UITEST_DROP_INITIAL_IDLE=1`: each horizontal pager the reader builds drops its
        /// first `.idle` report (17-VERIFICATION.md R5-1). Only a stubbed-network launch sets it.
        var dropsReaderInitialIdleReport = false
        /// `EHPANDA_UITEST_RECENT_FRAME_LOG`: the file Search's Recently Viewed cards log their leading edges to.
        /// Only a stubbed-network launch has one.
        var recentFrameLogURL: URL?
        /// `EHPANDA_UITEST_REPORT_SCENARIO`: how the stub answers the Report form (18.1-04). Only a stubbed-network
        /// launch reads it; every other launch, and any unknown value, is `ready`.
        var reportScenario = UITestStubURLProtocol.ReportScenario.ready
        #if DEBUG && canImport(Appshot) && canImport(AppshotProtocol)
        var appshotScene: AppshotProtocol.CaptureScene?
        #endif
    }

    /// The one clock reading of every hosted visual test and capture launch.
    static let fixedDate = Date(timeIntervalSince1970: 1_735_689_600)

    @discardableResult
    static func prepare(
        environment: [String: String],
        now: Date = .now
    ) -> Configuration? {
        let resolved: Configuration?
        do {
            resolved = try resolve(environment: environment, now: now)
            #if DEBUG && canImport(Appshot) && canImport(AppshotProtocol)
            AppshotCapture.launchedScene = resolved?.appshotScene
            #endif
            if let captureScene = resolved?.captureScene {
                // The app delegate prepares the launch on the main actor, before the app builds its store.
                let family = MainActor.assumeIsolated({ CaptureDeviceFamily(UIDevice.current.userInterfaceIdiom) })
                try CaptureScenePreparation.install(captureScene, family: family)
                // After the install, so it lands in the capture's isolated storage.
                applyFirstLaunchPreset(resolved?.firstLaunchPreset)
            }
        } catch {
            // A capture launch never degrades to live data or a partial scene: it ends here, before
            // the app builds any state, with the check that failed.
            fatalError("EhPanda refused the capture launch: \(error)")
        }
        guard let configuration = resolved, configuration.captureScene == nil else {
            return resolved
        }

        if configuration.shouldStubNetwork {
            UITestStubURLProtocol.configure(fixtureDirectory: configuration.fixtureDirectory)
            UITestStubURLProtocol.configure(requestLog: configuration.requestLogURL)
            UITestStubURLProtocol.configure(reportScenario: configuration.reportScenario)
            URLProtocol.registerClass(UITestStubURLProtocol.self)
            // Set before the first reader is built; the reader reads it as its environment default.
            ReaderUITestOptions.dropsInitialIdleReport = configuration.dropsReaderInitialIdleReport
            RecentlyViewedUITestOptions.frameLogURL = configuration.recentFrameLogURL
        }
        // Both overrides share one preparation. The get-then-set on `$0.downloadClient` is accepted
        // because the get and the set happen inside the same preparation: reading it caches the live
        // client under the current preparation id, and the setter admits a key whose cached value
        // carries that id.
        if configuration.shouldStubNetwork
            || configuration.shouldUseVisualTestHost
            || configuration.clipboardClient != nil
            || configuration.pauseRefusal != nil
        {
            prepareDependencies {
                if configuration.shouldStubNetwork && !configuration.shouldUseVisualTestHost {
                    // Loading settings must not replace the offline image protocol with the live bypass protocol.
                    $0.dfClient = .noop
                    $0.libraryClient = .live(configuringImageSessions: { session in
                        session.protocolClasses = [UITestStubURLProtocol.self] + (session.protocolClasses ?? [])
                    })
                    if let path = trimmedValue(environment: environment, key: "EHPANDA_UITEST_DOWNLOAD_ROOT") {
                        $0.downloadClient = .live(rootURL: URL(filePath: path, directoryHint: .isDirectory))
                    }
                }
                if configuration.shouldUseVisualTestHost {
                    // The hosted test process renders the app before XCTest enters any test case.
                    // Prepare explicit inert clients before the first Store or shared key is built.
                    configureVisualTestHost(&$0, firstLaunch: configuration.firstLaunchPreset)
                }
                if let clipboardClient = configuration.clipboardClient {
                    $0.clipboardClient = clipboardClient
                }
                if let refusal = configuration.pauseRefusal {
                    $0.downloadClient.togglePause = { _ in throw refusal.error }
                }
            }
        }
        // A visual host's preset went into its own storage above; a stubbed launch keeps the app's.
        if !configuration.shouldUseVisualTestHost {
            applyFirstLaunchPreset(configuration.firstLaunchPreset)
            configuration.storagePreset?.apply()
        }
        return configuration
    }

    /// Whether `environment` presets an automated launch's first-launch answers, and how.
    ///
    /// `isAutomatedLaunch` is a capture, a stubbed-network or a hosted visual-test launch; any other
    /// launch gets no preset whatever the key says.
    static func firstLaunchPreset(
        environment: [String: String],
        isAutomatedLaunch: Bool
    ) -> FirstLaunchPreset? {
        guard isAutomatedLaunch else { return nil }
        switch trimmedValue(environment: environment, key: FirstLaunchPreset.environmentKey) {
        case "show": return .cleared
        case "analytics": return .ageConfirmed
        default: return .answered
        }
    }

    /// The stored state `environment` asks a stubbed-network launch to start from.
    static func storagePreset(environment: [String: String]) -> StoragePreset {
        StoragePreset(
            blockedCommentUsers: blockedUsers(
                trimmedValue(environment: environment, key: StoragePreset.blockedUsersEnvironmentKey)
            ),
            displayName: trimmedValue(environment: environment, key: StoragePreset.displayNameEnvironmentKey)
        )
    }

    /// One entry of `EHPANDA_UITEST_BLOCKED_USERS`, without the stored model's schema version.
    private struct PresetUser: Decodable {
        let memberID: String
        let name: String
    }

    /// The users a JSON array of `{"memberID": …, "name": …}` objects holds; empty for no value or anything else.
    private static func blockedUsers(_ value: String?) -> [BlockedCommentUser] {
        guard let value else { return [] }
        do {
            return try JSONDecoder().decode([PresetUser].self, from: Data(value.utf8)).map { user in
                BlockedCommentUser(memberID: user.memberID, name: user.name)
            }
        } catch {
            // A malformed list starts the launch from no blocks, the same as an absent one: a test
            // that misspells it sees its blocked comments shown, never another test's list.
            return []
        }
    }

    /// Writes `preset` into the shared setting of the current app storage, before the store reads it.
    static func applyFirstLaunchPreset(_ preset: FirstLaunchPreset?) {
        guard let preset else { return }
        @Shared(.setting) var setting
        $setting.withLock({ preset.apply(to: &$0) })
    }

    /// Install isolated fixtures both for hosted rendering and explicitly on the app's Store.
    /// Global preparation alone cannot bind the host Store to fixtures when XCTest changes scopes.
    static func configureVisualTestHost(_ dependencies: inout DependencyValues) {
        configureVisualTestHost(&dependencies, firstLaunch: .answered)
    }

    /// `configureVisualTestHost(_:)` with the first-launch answers `firstLaunch` asks for, written
    /// into the host's fresh storage; `nil` leaves that storage's never-answered defaults.
    static func configureVisualTestHost(
        _ dependencies: inout DependencyValues,
        firstLaunch: FirstLaunchPreset?
    ) {
        dependencies.analyticsClient = .noop
        dependencies.appLaunchAutomationClient = .none
        dependencies.applicationClient = .noop
        dependencies.clipboardClient = .noop
        dependencies.cookieClient = .noop
        dependencies.deviceClient = .live
        dependencies.downloadClient = .noop
        dependencies.hapticsClient = .noop
        dependencies.libraryClient = .noop
        dependencies.userDefaultsClient = .noop
        // One suite, held: each `UserDefaults.inMemory` access makes a new one.
        let appStorage = UserDefaults.inMemory
        dependencies.defaultAppStorage = appStorage
        dependencies.defaultInMemoryStorage = InMemoryStorage()
        dependencies.date.now = fixedDate
        dependencies.uuid = .incrementing
        withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            applyFirstLaunchPreset(firstLaunch)
        }
    }

    /// The configuration `environment` requests, or `nil` when it requests none.
    ///
    /// Only a capture request can fail: its configuration and fixture are validated here in full.
    static func resolve(
        environment: [String: String],
        now: Date,
        isTesting: Bool = AppInfo.isTesting
    ) throws(CaptureFailure) -> Configuration? {
        #if DEBUG && canImport(Appshot) && canImport(AppshotProtocol)
        let appshot = try AppshotCapture.decode(environment: environment)
        let captureEnvironment: [String: String]
        if let appshot {
            captureEnvironment = try AppshotCapture.captureEnvironment(appshot, environment: environment)
        } else {
            captureEnvironment = environment
        }
        #else
        let captureEnvironment = environment
        if environment.keys.contains("APPSHOT_SCENE") {
            throw .malformedConfiguration(
                "APPSHOT_SCENE requires the explicit local capture composition; prepare a snapshot with the real SDK."
            )
        }
        #endif
        if let captureScene = try CaptureScenePreparation.scene(environment: captureEnvironment) {
            #if DEBUG && canImport(Appshot) && canImport(AppshotProtocol)
            var configuration: Configuration
            #else
            let configuration: Configuration
            #endif
            configuration = Configuration(
                fixtureDirectory: nil,
                clipboardClient: nil,
                shouldStubNetwork: false,
                shouldUseVisualTestHost: false,
                pauseRefusal: nil,
                captureScene: captureScene,
                firstLaunchPreset: firstLaunchPreset(environment: environment, isAutomatedLaunch: true)
            )
            #if DEBUG && canImport(Appshot) && canImport(AppshotProtocol)
            configuration.appshotScene = appshot
            #endif
            return configuration
        }
        #if DEBUG && canImport(Appshot) && canImport(AppshotProtocol)
        let isProbe: Bool
        if let appshot, case .probe = appshot.coordinate {
            isProbe = true
        } else {
            isProbe = false
        }
        #else
        let isProbe = false
        #endif
        let shouldUseVisualTestHost = isProbe || isTesting && trimmedValue(
            environment: environment,
            key: "EHPANDA_VISUAL_TEST_HOST"
        ) == "1"
        let shouldStubNetwork = shouldUseVisualTestHost || trimmedValue(
            environment: environment,
            key: "EHPANDA_UITEST_STUB_NETWORK"
        ) == "1"
        let fixtureDirectory = trimmedValue(
            environment: environment,
            key: "EHPANDA_UITEST_FIXTURE_DIR"
        )
        .map(fileURL(forLaunchPath:))
        let clipboardURL = trimmedValue(
            environment: environment,
            key: "EHPANDA_UITEST_CLIPBOARD_URL"
        )
        .flatMap(URL.init(string:))
        let clipboardClient: ClipboardClient? = if let clipboardURL {
            Self.clipboardClient(
                url: clipboardURL,
                changeCount: Int(now.timeIntervalSinceReferenceDate * 1_000)
            )
        } else {
            nil
        }

        let pauseRefusal = trimmedValue(
            environment: environment,
            key: "EHPANDA_UITEST_FORCE_PAUSE_REFUSAL"
        )
        .flatMap(PauseRefusal.init(rawValue:))

        guard shouldStubNetwork || clipboardClient != nil || pauseRefusal != nil else {
            return nil
        }
        #if DEBUG && canImport(Appshot) && canImport(AppshotProtocol)
        var configuration: Configuration
        #else
        let configuration: Configuration
        #endif
        configuration = Configuration(
            fixtureDirectory: fixtureDirectory,
            clipboardClient: clipboardClient,
            shouldStubNetwork: shouldStubNetwork,
            shouldUseVisualTestHost: shouldUseVisualTestHost,
            pauseRefusal: pauseRefusal,
            captureScene: nil,
            firstLaunchPreset: firstLaunchPreset(environment: environment, isAutomatedLaunch: shouldStubNetwork),
            storagePreset: shouldStubNetwork && !shouldUseVisualTestHost
                ? storagePreset(environment: environment)
                : nil,
            requestLogURL: shouldStubNetwork
                ? trimmedValue(environment: environment, key: "EHPANDA_UITEST_REQUEST_LOG").map({ URL(filePath: $0) })
                : nil,
            dropsReaderInitialIdleReport: shouldStubNetwork
                && trimmedValue(environment: environment, key: "EHPANDA_UITEST_DROP_INITIAL_IDLE") == "1",
            recentFrameLogURL: shouldStubNetwork
                ? trimmedValue(environment: environment, key: "EHPANDA_UITEST_RECENT_FRAME_LOG")
                    .map(fileURL(forLaunchPath:))
                : nil,
            reportScenario: UITestStubURLProtocol.ReportScenario(
                launchValue: shouldStubNetwork
                    ? trimmedValue(environment: environment, key: "EHPANDA_UITEST_REPORT_SCENARIO")
                    : nil
            )
        )
        #if DEBUG && canImport(Appshot) && canImport(AppshotProtocol)
        configuration.appshotScene = appshot
        #endif
        return configuration
    }

    /// A path a launch key names. A leading `~/` is the app's own home, for a launch from a Mac onto a device, where
    /// the app's container path is not known to the launcher.
    private static func fileURL(forLaunchPath path: String) -> URL {
        guard path.hasPrefix("~/") else { return URL(filePath: path) }
        return URL(filePath: NSHomeDirectory()).appending(path: String(path.dropFirst(2)))
    }

    static func shouldDetectClipboardURL(
        environment: [String: String]
    ) -> Bool {
        trimmedValue(
            environment: environment,
            key: "EHPANDA_UITEST_CLIPBOARD_URL"
        ) != nil
    }

    private static func clipboardClient(
        url: URL,
        changeCount: Int
    ) -> ClipboardClient {
        let live = ClipboardClient.live
        return ClipboardClient(
            url: { url },
            changeCount: { changeCount },
            saveText: live.saveText,
            saveImage: live.saveImage,
            saveImageData: live.saveImageData
        )
    }

    private static func trimmedValue(
        environment: [String: String],
        key: String
    ) -> String? {
        environment[key]
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .flatMap(\.nonEmpty)
    }
    #endif
}
