import AppModels

// The complete analytics vocabulary. A reducer can emit nothing that is not spelled below, because
// `AnalyticsClient.send` accepts this type and nothing else — so "what may this app transmit?" is
// answered by reading one enum rather than by auditing every call site. That is the load-bearing
// half of D-09.
//
// Not one associated value is a `String`, a `URL`, `Data`, or an AppModels content type. Every
// payload is a closed enum, a `Bool`, a bucket, or one of D-08's two documented exact-`Int`
// exceptions, so a contributor cannot express a title, a keyword or a tag value here even by
// accident. `Category` and `TagNamespace` are permitted by D-07: both are closed case sets, and
// only a namespace ever travels — a tag value never does (D-06).
//
// Three omissions are deliberate, and each is listed so a later reader does not "fix" them:
//
// 1. Launch and foreground have no signal. The SDK already emits one of its own
//    (`sendNewSessionBeganSignal` defaults true, per `COVERAGE.md`); a second would double-count
//    against the vendor's own session insights.
// 2. Reading direction and dual-page mode are absent from `readingSessionEnded`. D-11 puts them on
//    *every* signal as global default parameters, evaluated at emission time — carrying them a
//    second time on one signal would duplicate a dashboard column for no analytical gain.
// 3. Which settings are enabled in the field has no dedicated signal, for the same reason: D-11
//    already covers it.

public enum AnalyticsSignal: Equatable, Sendable {
    // MARK: Navigation

    case homeSectionViewed(HomeSection)
    case tabOpened(AppTab)
    case galleryDetailOpened(category: Category, tagNamespaces: TagNamespaceCounts)

    // MARK: Search and discovery

    case searchPerformed(shape: SearchShape, resultCount: CountBucket)
    case filterPanelOpened(SearchSurface)
    case quickSearchPanelOpened(SearchSurface)
    case quickSearchWordUsed
    case tagTapped(namespace: TagNamespace?)

    // MARK: Reading and downloads

    case readingSessionEnded(pagesRead: CountBucket, duration: DurationBucket)
    case downloadStateChanged(DownloadOutcome)

    // MARK: Errors and account

    case errorSurfaced(AppErrorKind)
    case loginFailed(LoginFailureKind)
    case cloudflareChallengeEncountered
}
