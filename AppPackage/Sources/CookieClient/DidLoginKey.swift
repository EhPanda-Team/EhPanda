import ComposableArchitecture
import Sharing

/// Read-only projection of `CookieClient.didLogin` into SwiftUI observation.
///
/// `HTTPCookieStorage` stays the single source of truth: nothing is mirrored into feature `State`.
/// The key re-derives `didLogin` from the jar on every `cookiesDidChange` element, so any mutation
/// path (logout `clearAll`, WebView login, igneous refresh, manual cookie edits) re-renders every
/// `@SharedReader(.didLogin)` view.
public struct DidLoginKey: SharedReaderKey {
    /// Sharing's reference cache is a process-wide weak table keyed by `AnyHashable(id)` alone, so
    /// every `@SharedReader(.didLogin)` shares one reference (and one jar subscription); the
    /// dedicated nominal type rules out collisions with any other key. The flip side: readers alive
    /// at the same time share the first reader's captured client, so concurrent contexts must not
    /// install different clients (the app has one live client; tests keep to a single reader).
    public struct KeyID: Hashable, Sendable {}

    private let client: CookieClient

    public init() {
        // Resolved at key creation, matching the repo's withDependencies-in-#Preview init-capture
        // semantics: previews constructing views inside `operation:` get the preview client.
        @Dependency(\.cookieClient) var client
        self.client = client
    }

    public var id: KeyID { KeyID() }

    public func load(context: LoadContext<Bool>, continuation: LoadContinuation<Bool>) {
        continuation.resume(returning: client.didLogin)
    }

    public func subscribe(
        context: LoadContext<Bool>, subscriber: SharedSubscriber<Bool>
    ) -> SharedSubscription {
        let task = Task { [client] in
            for await _ in client.cookiesDidChange() {
                subscriber.yield(client.didLogin)
            }
        }
        return SharedSubscription { task.cancel() }
    }
}

extension SharedReaderKey where Self == DidLoginKey.Default {
    /// `@SharedReader(.didLogin)` — live login state derived from the cookie jar.
    public static var didLogin: Self {
        Self[DidLoginKey(), default: false]
    }
}
