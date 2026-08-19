import AppModels
import ClipboardClient
import ComposableArchitecture
import DownloadClient
import Foundation

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
    /// `DownloadClient` inside `EhPandaApp.init` — earlier than it would otherwise be built. That
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
        let pauseRefusal: PauseRefusal?
    }

    @discardableResult
    static func prepare(
        environment: [String: String],
        now: Date = .now
    ) -> Configuration? {
        guard let configuration = resolve(environment: environment, now: now) else {
            return nil
        }

        if configuration.shouldStubNetwork {
            UITestStubURLProtocol.configure(fixtureDirectory: configuration.fixtureDirectory)
            URLProtocol.registerClass(UITestStubURLProtocol.self)
        }
        // One preparation for every dependency override, so the get-then-set below is accepted:
        // reading `$0.downloadClient` caches the live client under the current preparation id, and
        // the setter only admits a key whose cached value carries that id.
        if configuration.clipboardClient != nil || configuration.pauseRefusal != nil {
            prepareDependencies {
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

    static func resolve(
        environment: [String: String],
        now: Date
    ) -> Configuration? {
        let shouldStubNetwork = trimmedValue(
            environment: environment,
            key: "EHPANDA_UITEST_STUB_NETWORK"
        ) == "1"
        let fixtureDirectory = trimmedValue(
            environment: environment,
            key: "EHPANDA_UITEST_FIXTURE_DIR"
        )
        .map(URL.init(fileURLWithPath:))
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
        return Configuration(
            fixtureDirectory: fixtureDirectory,
            clipboardClient: clipboardClient,
            shouldStubNetwork: shouldStubNetwork,
            pauseRefusal: pauseRefusal
        )
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
