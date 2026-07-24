@testable import AnalyticsClient
import AppModels
import Testing

// One fixture per signal case: the value a reducer emits, beside the exact wire form it must
// produce. A named struct rather than a positional tuple — the table is long, and `.0`/`.1` reads
// would carry no meaning at the assertion site.
struct SignalRenderingFixture: Sendable {
    let signal: AnalyticsSignal
    let rendered: AnalyticsSignal.Rendered
}

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

    // Every expected name and key is written out as a literal rather than read back from the
    // rendering layer. These are dashboard identifiers: a rename must fail a test that names the
    // column it would orphan, not quietly follow the source it is supposed to be pinning.
    //
    // Every fixture is built from inputs whose content strings are the sentinel, so the same table
    // serves the no-content sweep below without a second set of values to keep in sync.
    private static let fixtures: [SignalRenderingFixture] = [
        SignalRenderingFixture(
            signal: .homeSectionViewed(.frontpage),
            rendered: .signal(name: "Navigation.homeSectionViewed", parameters: ["Navigation.section": "frontpage"])
        ),
        SignalRenderingFixture(
            signal: .tabOpened(.downloads),
            rendered: .signal(name: "Navigation.tabOpened", parameters: ["Navigation.tab": "downloads"])
        ),
        // Two tags under `female` and one under a namespace the site does not publish. The counts
        // ship exact per D-16, so this reads `2` and `1` rather than a bucket spelling, and the
        // unrecognized namespace lands on the one anonymous key instead of minting its own.
        SignalRenderingFixture(
            signal: .galleryDetailOpened(
                category: .artistCG,
                tagNamespaces: .init(tags: [
                    tag(namespace: "female", contents: [sentinel, "\(sentinel)-second"]),
                    tag(namespace: sentinel, contents: ["\(sentinel)-unrecognized"])
                ])
            ),
            rendered: .signal(name: "Navigation.galleryDetailOpened", parameters: [
                "Gallery.category": "artistCG",
                "Gallery.tagNamespace.female": "2",
                "Gallery.tagNamespace.unrecognized": "1"
            ])
        ),
        // `female:` plus the sentinel, a space, and the sentinel again — two words, tag syntax
        // recognized, fifty characters. The length ships exact as D-08's original exception.
        SignalRenderingFixture(
            signal: .searchPerformed(
                shape: .init(keyword: "female:\(sentinel) \(sentinel)"),
                resultCount: .sixToTwenty
            ),
            rendered: .signal(name: "Search.performed", parameters: [
                "Search.wordCount": "2-5",
                "Search.usedTagSyntax": "true",
                "Search.keywordLength": "50",
                "Search.resultCount": "6-20"
            ])
        ),
        SignalRenderingFixture(
            signal: .filterPanelOpened(.frontpage),
            rendered: .signal(name: "Search.filterPanelOpened", parameters: ["Search.surface": "frontpage"])
        ),
        SignalRenderingFixture(
            signal: .quickSearchPanelOpened(.searchRoot),
            rendered: .signal(name: "Search.quickSearchPanelOpened", parameters: ["Search.surface": "searchRoot"])
        ),
        SignalRenderingFixture(
            signal: .quickSearchWordUsed,
            rendered: .signal(name: "Search.quickSearchWordUsed", parameters: [:])
        ),
        SignalRenderingFixture(
            signal: .tagTapped(namespace: .female),
            rendered: .signal(name: "Search.tagTapped", parameters: ["Gallery.tagNamespace": "female"])
        ),
        SignalRenderingFixture(
            signal: .readingSessionEnded(pagesRead: .twentyOneToFifty, duration: .oneToFiveMinutes),
            rendered: .signal(name: "Reading.sessionEnded", parameters: [
                "Reading.pagesRead": "21-50",
                "Reading.duration": "1-5m"
            ])
        ),
        SignalRenderingFixture(
            signal: .downloadStateChanged(.failed),
            rendered: .signal(name: "Download.stateChanged", parameters: ["Download.outcome": "failed"])
        ),
        // The one signal that is not a plain signal: it routes to the SDK's error preset, so the
        // identifier is the closed `AppErrorKind` spelling and the free-form `message:` parameter
        // the preset also offers is never reached. The sentinel rides in the error's payload.
        SignalRenderingFixture(
            signal: .errorSurfaced(.init(.copyrightClaim(sentinel))),
            rendered: .error(id: "copyrightClaim", category: .appState, parameters: [:])
        ),
        SignalRenderingFixture(
            signal: .loginFailed(.captchaRequired),
            rendered: .signal(name: "Account.loginFailed", parameters: [
                "Account.loginFailureKind": "captchaRequired"
            ])
        ),
        SignalRenderingFixture(
            signal: .cloudflareChallengeEncountered,
            rendered: .signal(name: "Account.cloudflareChallengeEncountered", parameters: [:])
        )
    ]

    // The whole analytics vocabulary a reducer can reach is thirteen signals wide. Pinning the
    // number here is what makes the sweeps below exhaustive: a case added without a fixture fails
    // this assertion rather than slipping through untested.
    @Test
    func theVocabularyIsThirteenSignalsWide() {
        #expect(Self.fixtures.count == 13)
    }

    // The whole dictionary is compared, not a key-by-key spot check. A spot check would let an
    // unexpected extra parameter through, which is exactly the leak shape this suite exists to
    // catch — a future change adding one more key would pass every assertion that only looks up
    // the keys it already knows about.
    @Test(arguments: AnalyticsSignalRenderingTests.fixtures)
    func everySignalRendersToItsPinnedWireForm(fixture: SignalRenderingFixture) {
        #expect(fixture.signal.rendered == fixture.rendered)
    }

    // A tag whose namespace the app does not recognize was scraped under text that may not be
    // reproduced, so it renders under the same anonymous spelling the per-gallery counts use.
    @Test
    func anUnrecognizedTagNamespaceRendersToTheAnonymousSpelling() {
        let rendered = AnalyticsSignal.tagTapped(namespace: nil).rendered

        #expect(rendered == .signal(name: "Search.tagTapped", parameters: ["Gallery.tagNamespace": "unrecognized"]))
    }
}
