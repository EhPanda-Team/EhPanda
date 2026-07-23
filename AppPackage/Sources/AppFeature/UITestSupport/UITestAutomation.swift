import ClipboardClient
import ComposableArchitecture
import Foundation

public enum UITestAutomation {
    public static func prepareIfNeeded() {
        #if DEBUG
        prepare(environment: ProcessInfo.processInfo.environment)
        #endif
    }

    #if DEBUG
    struct Configuration: Sendable {
        let fixtureDirectory: URL?
        let clipboardClient: ClipboardClient?
        let shouldStubNetwork: Bool
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
        if let clipboardClient = configuration.clipboardClient {
            prepareDependencies {
                $0.clipboardClient = clipboardClient
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

        guard shouldStubNetwork || clipboardClient != nil else {
            return nil
        }
        return Configuration(
            fixtureDirectory: fixtureDirectory,
            clipboardClient: clipboardClient,
            shouldStubNetwork: shouldStubNetwork
        )
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
