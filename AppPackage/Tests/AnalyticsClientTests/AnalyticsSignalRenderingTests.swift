@testable import AnalyticsClient
import AppModels
import Testing

@Suite
struct AnalyticsSignalRenderingTests {
    // Distinctive enough that a substring search for it cannot collide with a signal name, a
    // parameter key, a bucket spelling or any other rendering a payload legitimately carries.
    private static let sentinel = "zqxsentinelsignal4718"

    private static func tag(namespace: String, contents: [String]) -> GalleryTag {
        GalleryTag(
            rawNamespace: namespace,
            contents: contents.map({
                GalleryTag.Content(rawNamespace: namespace, text: $0, isVotedUp: false, isVotedDown: false)
            })
        )
    }

    // One representative value of every case, each built from inputs whose content strings are the
    // sentinel. The count is pinned below, so a fourteenth case cannot ship without a fixture.
    private static let signals: [AnalyticsSignal] = [
        .homeSectionViewed(.frontpage),
        .tabOpened(.downloads),
        .galleryDetailOpened(
            category: .artistCG,
            tagNamespaces: .init(tags: [
                tag(namespace: "female", contents: [sentinel, "\(sentinel)-second"]),
                tag(namespace: sentinel, contents: ["\(sentinel)-unrecognized"])
            ])
        ),
        .searchPerformed(shape: .init(keyword: "female:\(sentinel) \(sentinel)"), resultCount: .sixToTwenty),
        .filterPanelOpened(.frontpage),
        .quickSearchPanelOpened(.searchRoot),
        .quickSearchWordUsed,
        .tagTapped(namespace: .female),
        .readingSessionEnded(pagesRead: .twentyOneToFifty, duration: .oneToFiveMinutes),
        .downloadStateChanged(.failed),
        .errorSurfaced(.init(.copyrightClaim(sentinel))),
        .loginFailed(.captchaRequired),
        .cloudflareChallengeEncountered
    ]

    // The whole analytics vocabulary a reducer can reach is thirteen signals wide. Pinning the
    // number here is what makes the exhaustive suites below exhaustive: a case added without a
    // fixture fails this assertion rather than slipping through untested.
    @Test
    func theVocabularyIsThirteenSignalsWide() {
        #expect(Self.signals.count == 13)
    }
}
