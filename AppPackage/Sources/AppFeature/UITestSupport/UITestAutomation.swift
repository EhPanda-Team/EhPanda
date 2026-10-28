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
import Sharing
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

    struct Configuration: Sendable {
        let fixtureDirectory: URL?
        let clipboardClient: ClipboardClient?
        let shouldStubNetwork: Bool
        let shouldUseVisualTestHost: Bool
        let pauseRefusal: PauseRefusal?
        /// A capture launch's validated scene. A capture takes no other UI-test key, so every
        /// other field is inert when this is set.
        let captureScene: CaptureScene?
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
                try CaptureScenePreparation.install(captureScene)
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
            URLProtocol.registerClass(UITestStubURLProtocol.self)
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
                    configureVisualTestHost(&$0)
                }
                if let clipboardClient = configuration.clipboardClient {
                    $0.clipboardClient = clipboardClient
                }
                if let refusal = configuration.pauseRefusal {
                    $0.downloadClient.togglePause = { _ in throw refusal.error }
                }
            }
        }
        return configuration
    }

    /// Install isolated fixtures both for hosted rendering and explicitly on the app's Store.
    /// Global preparation alone cannot bind the host Store to fixtures when XCTest changes scopes.
    static func configureVisualTestHost(_ dependencies: inout DependencyValues) {
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
        dependencies.defaultAppStorage = UserDefaults.inMemory
        dependencies.defaultInMemoryStorage = InMemoryStorage()
        dependencies.date.now = fixedDate
        dependencies.uuid = .incrementing
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
                captureScene: captureScene
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
        .map({ URL(filePath: $0) })
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
            captureScene: nil
        )
        #if DEBUG && canImport(Appshot) && canImport(AppshotProtocol)
        configuration.appshotScene = appshot
        #endif
        return configuration
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
