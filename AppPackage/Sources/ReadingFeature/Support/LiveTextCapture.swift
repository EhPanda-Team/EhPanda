#if DEBUG
import AppModels
import Dependencies
import Synchronization

/// The Live Text a capture launch shows on one reader page (17-06, D-06).
///
/// Only a launch capturing the reading-live-text screen installs one, and only in Debug builds. The
/// reader then starts with Live Text on and runs no recognition of its own except where `source`
/// asks for it, so no Vision pass can replace what the capture shows or compete with it for time.
/// What the reader did with the page is kept as ``outcome``, which the capture diagnostics read: the
/// reader's Live Text state belongs to its view, so the reducer state cannot report it.
public final class LiveTextCapture: Sendable {
    public enum Source: Equatable, Sendable {
        /// Show these groups, which a recording of the page saved, and recognize nothing.
        case replay([LiveTextGroup])
        /// Recognize the page as the reader always does, so a recording can save what it found.
        case record
    }

    /// What the reader did with the capture's page.
    public enum Outcome: Equatable, Sendable {
        /// The page shows the replayed groups.
        case replayed([LiveTextGroup])
        /// The reader's own recognizer found these groups, asked for these languages.
        case recognized([LiveTextGroup], recognitionLanguages: [String]?)
        /// The reader asked for Live Text on a gallery other than the capture's.
        case otherGallery(String)
    }

    /// What the reader does with one page it asks Live Text for.
    enum Decision: Equatable {
        /// Show these groups instead of recognizing the page.
        case show([LiveTextGroup])
        /// Recognize the page as usual.
        case recognize
        /// Leave the page without Live Text.
        case skip
    }

    public let gid: String
    public let page: Int
    public let source: Source
    private let state = Mutex<Outcome?>(nil)

    public init(gid: String, page: Int, source: Source) {
        self.gid = gid
        self.page = page
        self.source = source
    }

    /// What the reader did with the capture's page, or `nil` until it asked for it.
    public var outcome: Outcome? {
        state.withLock({ $0 })
    }

    /// Decides how the reader treats `page` of gallery `gid` once it asks Live Text for it.
    ///
    /// Only the capture's own page gets Live Text. A request from another gallery is kept as the
    /// outcome, so the capture fails rather than show a page whose groups belong elsewhere.
    func decision(gid: String, page: Int) -> Decision {
        guard gid == self.gid else {
            state.withLock({ $0 = .otherGallery(gid) })
            return .skip
        }
        guard page == self.page else {
            return .skip
        }
        switch source {
        case .replay(let groups):
            state.withLock({ $0 = .replayed(groups) })
            return .show(groups)
        case .record:
            return .recognize
        }
    }

    /// Keeps what the reader's recognizer found on `page`, when this capture records that page.
    func recognized(_ groups: [LiveTextGroup], page: Int, recognitionLanguages: [String]?) {
        guard source == .record, page == self.page else {
            return
        }
        state.withLock({ $0 = .recognized(groups, recognitionLanguages: recognitionLanguages) })
    }
}

extension DependencyValues {
    /// The Live Text a capture launch shows on its reader page, or `nil` outside such a launch.
    public var liveTextCapture: LiveTextCapture? {
        get { self[LiveTextCaptureKey.self] }
        set { self[LiveTextCaptureKey.self] = newValue }
    }
}

private enum LiveTextCaptureKey: DependencyKey {
    static var liveValue: LiveTextCapture? { nil }
    static var testValue: LiveTextCapture? { nil }
}
#endif
