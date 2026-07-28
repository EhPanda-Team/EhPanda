import ComposableArchitecture
import Foundation

/// An identified continued-processing session and the events it reports.
///
/// A caller must present this handle's id to complete the session. That extends the identity
/// invariant used by every late-arriving coordinator mutation across the client seam.
public struct BackgroundProcessingSession: Sendable {
    public let id: UUID
    public let events: AsyncStream<BackgroundProcessingEvent>

    public init(id: UUID, events: AsyncStream<BackgroundProcessingEvent>) {
        self.id = id
        self.events = events
    }
}

/// Wraps the system's continued-processing task so a user-started, foreground-initiated job
/// keeps running after the app is backgrounded, surfaced by the system-provided progress card.
///
/// The client is domain-agnostic: callers supply already-localized strings and already-clamped
/// counts, and nothing about what the work *is* lives here.
///
/// It is both resolvable through `DependencyValues` — which is where the unimplemented
/// `testValue` lives — and injected directly into its one consumer. That double shape is
/// deliberate, and diverges from the execution-assertion client it replaces, which had no
/// `DependencyValues` entry at all.
@DependencyClient
public struct BackgroundProcessingClient: Sendable {
    /// Registers and submits a session, returning its identified event stream. The stream
    /// finishes itself after `expired`, after `unavailable`, or after `finish`, so a consuming
    /// effect never needs external cancellation. A `nil` result means the store's single-session
    /// guard refused the call, which is observable and retryable rather than a dead stream.
    ///
    /// The counts are the caller's already-clamped snapshot at submission time. They are
    /// recorded before the request is submitted so a task the system launches immediately
    /// adopts real progress rather than an empty `Progress`.
    public var start: @Sendable (
        _ title: String,
        _ subtitle: String,
        _ completedUnitCount: Int64,
        _ totalUnitCount: Int64
    ) async -> BackgroundProcessingSession?
    /// Pushes fresh counts and a refreshed subtitle to the named system card. The caller owns
    /// clamping and monotonicity. A push is applied only when `sessionID` names the session the
    /// store currently holds, so a caller that lost ownership across its own suspension cannot
    /// repaint a successor's card.
    public var updateProgress: @Sendable (
        _ sessionID: UUID,
        _ completedUnitCount: Int64,
        _ totalUnitCount: Int64,
        _ subtitle: String
    ) async -> Void
    /// Completes `sessionID` only when it is the session the store currently holds.
    ///
    /// A caller that lost ownership across its own suspension must not be able to end a
    /// successor.
    public var finish: @Sendable (_ sessionID: UUID, _ success: Bool) async -> Void
}

extension BackgroundProcessingClient {
    public static let live = Self(
        start: { title, subtitle, completedUnitCount, totalUnitCount in
            await ContinuedProcessingSession.shared.start(
                title: title,
                subtitle: subtitle,
                completedUnitCount: completedUnitCount,
                totalUnitCount: totalUnitCount
            )
        },
        updateProgress: { sessionID, completedUnitCount, totalUnitCount, subtitle in
            await ContinuedProcessingSession.shared.updateProgress(
                sessionID: sessionID,
                completedUnitCount: completedUnitCount,
                totalUnitCount: totalUnitCount,
                subtitle: subtitle
            )
        },
        finish: { sessionID, success in
            await ContinuedProcessingSession.shared.finish(sessionID: sessionID, success: success)
        }
    )
}

// MARK: API
public enum BackgroundProcessingClientKey: DependencyKey {
    public static let liveValue = BackgroundProcessingClient.live
    public static let previewValue = BackgroundProcessingClient.noop
    public static let testValue = BackgroundProcessingClient()
}

extension DependencyValues {
    public var backgroundProcessingClient: BackgroundProcessingClient {
        get { self[BackgroundProcessingClientKey.self] }
        set { self[BackgroundProcessingClientKey.self] = newValue }
    }
}

// MARK: Test
extension BackgroundProcessingClient {
    public static let noop = Self(
        start: { _, _, _, _ in nil },
        updateProgress: { _, _, _, _ in },
        finish: { _, _ in }
    )
}
