import AnalyticsClient
import AppComponents
@testable import AppFeature
import AppLaunchAutomationClient
import AppModels
import ClipboardClient
import ComposableArchitecture
import CookieClient
import CustomDump
import DownloadClient
import Foundation
import LogsClient
import Sharing
import Testing
import UserDefaultsClient

// Exact-sequence proof for every AppFeature emission site. Each case drives a reducer through a
// store whose analytics client is a `LockIsolated`-backed spy — `.noop` with its `send` closure
// replaced by a collector — and asserts the *sequence* of recorded signals, not merely that
// something was recorded. The three zero-signal cases are what protect the metrics from
// double-counting and scroll-to-top inflation, so they are asserted explicitly (T-14-13).
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
@Suite
struct AnalyticsEmissionTests {

    // MARK: Tab opens (AppReducer)

    @MainActor
    @Test
    func switchingToADifferentTabRecordsExactlyOneTabOpen() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeAppStore(analyticsClient: .recording(into: recorded), initialTab: .home)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.tabBar(.setTabBarItemType(.setting)))
        await store.finish()

        expectNoDifference(recorded.value, [.tabOpened(.setting)])
    }

    @MainActor
    @Test
    func reTappingTheCurrentTabRecordsNothing() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeAppStore(analyticsClient: .recording(into: recorded), initialTab: .setting)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.tabBar(.setTabBarItemType(.setting)))
        await store.finish()

        expectNoDifference(recorded.value, [])
    }

    // MARK: Modal gallery detail (PresentationFeature)

    @MainActor
    @Test
    func presentingAModalGalleryDetailRecordsOneSignalMatchingTheFixture() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let fixture = sentinelGallery()
        let expected = TagNamespaceCounts(tags: fixture.tags)
        let store = makePresentationStore(analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.presentGalleryDetail(gallery: fixture, downloaded: nil))
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)

        expectNoDifference(
            recorded.value,
            [.galleryDetailOpened(category: fixture.category, tagNamespaces: expected)]
        )
    }

    @MainActor
    @Test
    func modalGalleryDetailSignalCarriesNoFixtureTitleOrTagText() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let fixture = sentinelGallery()
        let store = makePresentationStore(analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.presentGalleryDetail(gallery: fixture, downloaded: nil))
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)

        // Reflect over the whole recorded signal graph — every stored leaf, public or not — and prove
        // the fixture's distinctive title and tag text survive nowhere in it. A closed `Category` plus
        // exact namespace counts cannot carry either sentinel; this pins that (T-14-01).
        let leaves = Mirror(reflecting: recorded.value).leafRenderings
        #expect(leaves.contains(where: { $0.contains(Self.sentinelTitle) }) == false)
        #expect(leaves.contains(where: { $0.contains(Self.sentinelTagText) }) == false)
    }

    // MARK: User-visible errors (PresentationFeature)

    @MainActor
    @Test
    func aDiagnosticsCarryingErrorToastRecordsOneErrorSignalOfTheExpectedKind() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let errorInfo = ErrorInfo(error: .parseFailed, context: [.action: "test"])
        let store = makePresentationStore(analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.setToast(.error(errorInfo)))
        await store.finish()

        expectNoDifference(recorded.value, [.errorSurfaced(.parseFailed)])
    }

    @MainActor
    @Test
    func aCaptionOnlyErrorToastRecordsNothing() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makePresentationStore(analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.setToast(.error(caption: "a caption with no diagnostics")))
        await store.finish()

        expectNoDifference(recorded.value, [])
    }

    @MainActor
    @Test
    func drillingIntoTheErrorDetailScreenRecordsNothing() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let errorInfo = ErrorInfo(error: .parseFailed, context: [.action: "test"])
        let store = makePresentationStore(analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.presentErrorInfo(errorInfo))
        await store.finish()

        expectNoDifference(recorded.value, [])
    }
}

// MARK: Spy

private extension AnalyticsClient {
    // The `LockIsolated` capture idiom (AppActivityLogsReducerTests / AnalyticsClientGateTests):
    // take the inert `.noop` client and replace its one `send` closure with a collector, so a test
    // asserts exactly which signals crossed the reducer → client boundary and in what order. `start`
    // stays inert. This relies on the client's `var` closure properties (a deliberate departure from
    // the `let`-based HapticsClient template, recorded in AnalyticsClient.swift).
    static func recording(into recorded: LockIsolated<[AnalyticsSignal]>) -> Self {
        var client = AnalyticsClient.noop
        client.send = { signal in recorded.withValue({ $0.append(signal) }) }
        return client
    }
}

// MARK: Fixtures and stores

private extension AnalyticsEmissionTests {
    static let sentinelTitle = "SENTINEL_TITLE_must_never_leak"
    static let sentinelTagText = "SENTINEL_TAGTEXT_must_never_leak"

    // A gallery whose title and tag text are distinctive sentinels, with two recognized namespaces
    // carrying known counts (female: 2, artist: 1) so the emitted `TagNamespaceCounts` is exactly
    // predictable while the sentinels give the reflection assertion something to hunt for.
    func sentinelGallery() -> Gallery {
        Gallery(
            gid: "9001",
            token: "sentinel-token",
            title: Self.sentinelTitle,
            rating: 4,
            tags: [
                GalleryTag(rawNamespace: "female", contents: [
                    tagContent(Self.sentinelTagText + "-a"),
                    tagContent(Self.sentinelTagText + "-b")
                ]),
                GalleryTag(rawNamespace: "artist", contents: [
                    tagContent(Self.sentinelTagText + "-c")
                ])
            ],
            category: .manga,
            uploader: "Uploader",
            pageCount: 10,
            postedDate: Date(timeIntervalSince1970: 0),
            coverURL: nil,
            galleryURL: nil
        )
    }

    func tagContent(_ text: String) -> GalleryTag.Content {
        GalleryTag.Content(rawNamespace: "female", text: text, isVotedUp: false, isVotedDown: false)
    }

    @MainActor
    func makePresentationStore(analyticsClient: AnalyticsClient) -> TestStoreOf<PresentationFeature> {
        TestStore(
            initialState: PresentationFeature.State(),
            reducer: PresentationFeature.init,
            withDependencies: {
                $0.analyticsClient = analyticsClient
                $0.date = .constant(Date(timeIntervalSince1970: 0))
                $0.downloadClient = .noop
                $0.hapticsClient = .noop
            }
        )
    }

    @MainActor
    func makeAppStore(
        analyticsClient: AnalyticsClient,
        initialTab: TabBarItemType
    ) -> TestStoreOf<AppReducer> {
        let appStorage = UserDefaults.inMemory
        let inMemoryStorage = InMemoryStorage()

        return withDependencies {
            $0.defaultAppStorage = appStorage
            $0.defaultInMemoryStorage = inMemoryStorage
        } operation: {
            var initialState = AppReducer.State()
            initialState.tabBarState.tabBarItemType = initialTab
            initialState.$privacyMaskBlur.withLock({ $0 = 0 })

            return TestStore(
                initialState: initialState,
                reducer: AppReducer.init,
                withDependencies: {
                    $0.analyticsClient = analyticsClient
                    $0.appLaunchAutomationClient = .none
                    $0.clipboardClient = .noop
                    $0.continuousClock = TestClock()
                    $0.cookieClient = .noop
                    $0.defaultAppStorage = appStorage
                    $0.defaultInMemoryStorage = inMemoryStorage
                    $0.downloadClient = .noop
                    $0.hapticsClient = .noop
                    $0.logsClient = .noop
                    $0.userDefaultsClient = .noop
                }
            )
        }
    }
}

// Mirrors plan 14-03's `ContentLeakProbe` reflection helper. That helper lives in the
// `AnalyticsClientTests` target, which this target cannot import; the walk is reproduced verbatim
// here rather than reimplemented differently, so both privacy proofs reflect over values the same
// way — reaching every stored leaf, including ones the public API never exposes.
private extension Mirror {
    var leafRenderings: [String] {
        children.flatMap({ child in
            let nested = Mirror(reflecting: child.value).leafRenderings
            return nested.isEmpty ? [String(describing: child.value)] : nested
        })
    }
}
