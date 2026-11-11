import AppModels

// Which analytics level each signal needs (A-3 as amended by D-06f; owner msgs 1869, 1880; developer
// mapping msg 1878). The level descriptions the user agreed to are the contract:
//
// - Basic: "which screens and features you use" and "which kinds of errors occur".
// - Full: "your reading and download activity" on top of Basic.
// - Minimal sends no app signal at all; its one install signal goes through `InstallSignalSender`.
//
// If a signal moves between levels, or a level starts to send something new, the approved description
// must change first, with a new owner approval.

extension AnalyticsSignal {
    /// The lowest level at which this signal is sent.
    ///
    /// The `switch` is exhaustive with no catch-all arm, deliberately: a case added to `AnalyticsSignal`
    /// does not compile until someone decides which level's description covers it.
    var minimumLevel: AnalyticsLevel {
        switch self {
        // Screens and features.
        case .tabOpened, .homeSectionViewed, .filterPanelOpened, .quickSearchPanelOpened, .savedSearchUsed,
             .tagTapped, .searchPerformed:
            .basic

        // Kinds of errors.
        case .errorSurfaced, .loginFailed, .cloudflareChallengeEncountered:
            .basic

        // The 3.0 flows (20-12, signed off): finishing the first-launch screens, changing the level in
        // Settings, and comment moderation. Each is covered by Basic's "which screens and features you
        // use"; no level description changes (owner msg 2837 dropped the report reason for that).
        case .firstLaunchCompleted, .analyticsLevelChanged, .commentReportOutcome, .commentPosterBlocked,
             .commentPosterUnblocked, .blockedCommentShown, .commentPostingWarningAnswered:
            .basic

        // Reading and download activity.
        case .galleryDetailOpened, .readingSessionEnded, .downloadStateChanged:
            .full
        }
    }

    /// Whether this signal is sent at `level`. Nothing is sent before a level is chosen.
    func isSent(at level: AnalyticsLevel?) -> Bool {
        guard let level else { return false }
        return Self.rank(of: minimumLevel) <= Self.rank(of: level)
    }

    /// The levels' order, Minimal < Basic < Full: each sends everything the one before it sends.
    private static func rank(of level: AnalyticsLevel) -> Int {
        switch level {
        case .minimal:
            0

        case .basic:
            1

        case .full:
            2
        }
    }
}
