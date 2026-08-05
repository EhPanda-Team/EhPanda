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
/// The client is injected directly into its one consumer. The macro-synthesized
/// `BackgroundProcessingClient()` value leaves every endpoint unimplemented so tests fail loudly
/// on any call they did not arrange, and `testUnimplementedClientReportsAnIssueForEveryEndpoint`
/// calls all three of its endpoints to prove it.
///
/// That sentence is about the unimplemented VALUE and claims nothing about the session store
/// behind `.live`, which this seam only forwards to. The store's own lifecycle — including the
/// three arms that yield `.unavailable` and both arms of its launch handler's nil-task path — is
/// covered separately by `ContinuedProcessingSessionTests` over the store's injected scheduling
/// seam, whose spy can refuse a registration and throw from a submission.
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

// MARK: Test
extension BackgroundProcessingClient {
    public static let noop = Self(
        start: { _, _, _, _ in nil },
        updateProgress: { _, _, _, _ in },
        finish: { _, _ in }
    )
}
