import AnalyticsClient
import AppLaunchAutomationClient
import AppModels
import ComposableArchitecture
import CookieClient
import DownloadClient
import Foundation
import HapticsClient
@testable import ReadingFeature
import Sharing
import Testing

// Exact-sequence proof for the reader-session signal — this module's single emission site.
//
// The date dependency is driven from a mutable box rather than `.constant`, so a test can advance it
// across a bucket boundary and assert the resulting `DurationBucket` deterministically. A wall-clock
// read here is the classic way this kind of test becomes flaky.
//
// Two properties beyond the happy path are pinned deliberately:
//
//   - Presenting emits nothing, and dismissing a never-presented reader emits nothing. One signal per
//     session is the whole shape of this metric (T-14-13).
//   - Scrubbing back and forth does not inflate the page count. That assertion is what distinguishes
//     a visited-page set from a naive counter — the difference between measuring reading and
//     measuring fidgeting.
//
// Pages are read the way the reader reads them since 18-07: a turn, then the pager settling on the
// page, which commits it to the reader's one page (`ReaderPosition`) and from there to the session.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
@Suite
struct AnalyticsEmissionTests {

    // MARK: Silence

    @MainActor
    @Test
    func presentingTheReaderRecordsNothing() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeReadingStore(recorded: recorded, now: LockIsolated(Self.origin))

        await store.send(.onPresented)
        await store.skipInFlightEffects(strict: false)

        #expect(recorded.value.isEmpty)
    }

    // A reader torn down without ever being presented has no session start instant. It must emit
    // nothing rather than reporting a zero-duration session that never happened.
    @MainActor
    @Test
    func dismissingWithoutPresentingRecordsNothing() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeReadingStore(recorded: recorded, now: LockIsolated(Self.origin))

        await store.send(.onPerformDismiss)
        await store.skipInFlightEffects(strict: false)

        #expect(recorded.value.isEmpty)
    }

    // MARK: The session signal

    // The page the pager settles on is the page the session counts, whatever turn was asked for: a turn
    // the pager does not reach counts the page it shows (DD-02), and a turn still under way counts
    // nothing yet.
    @MainActor
    @Test
    func theSessionCountsThePagesThePagerSettledOn() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeReadingStore(recorded: recorded, now: LockIsolated(Self.origin))

        await store.send(.onPresented)
        await store.send(.turn(toPage: 9))
        #expect(store.state.visitedPages == [1])
        for _ in 0...ReaderPosition.retryLimit {
            await store.send(.pagerSettled(shown: 2, generation: 0))
        }
        await store.skipReceivedActions(strict: false)

        #expect(store.state.readingProgress == 2)
        #expect(store.state.visitedPages == [1, 2])
    }

    @MainActor
    @Test
    func dismissingAfterReadingRecordsOneSessionSignal() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let now = LockIsolated(Self.origin)
        let store = makeReadingStore(recorded: recorded, now: now)

        await store.send(.onPresented)
        // Pages 2, 3, 4 joining the seeded opening page 1 — four distinct pages.
        for page in 2...4 { await Self.read(page, in: store) }
        now.setValue(Self.origin.addingTimeInterval(90))
        await store.send(.onPerformDismiss)
        await store.skipInFlightEffects(strict: false)

        expectNoDifference(
            recorded.value,
            [.readingSessionEnded(pagesRead: .twoToFive, duration: .oneToFiveMinutes)]
        )
    }

    // The assertion that makes the pages-read metric mean something: revisiting pages must not
    // inflate it. Both sequences reach the same three pages, so both must report the same bucket.
    @MainActor
    @Test
    func scrubbingBackAndForthDoesNotInflateThePageCount() async {
        let straightThrough = await Self.recordedSession(pages: [2, 3, 4], elapsed: 90)
        let scrubbed = await Self.recordedSession(pages: [2, 3, 4, 3, 2], elapsed: 90)

        expectNoDifference(scrubbed, straightThrough)
        expectNoDifference(
            scrubbed,
            [.readingSessionEnded(pagesRead: .twoToFive, duration: .oneToFiveMinutes)]
        )
    }

    // MARK: Duration bucket boundaries
    //
    // Driven at a boundary and one tick past it, in both directions across two different boundaries.
    // Bucketing is the accepted mitigation for counter-based re-identification (T-14-02), so the
    // boundaries are worth pinning rather than assuming.

    @MainActor
    @Test(arguments: [
        (elapsed: 9.0, expected: DurationBucket.underTenSeconds),
        (elapsed: 10.0, expected: DurationBucket.tenToSixtySeconds),
        (elapsed: 59.0, expected: DurationBucket.tenToSixtySeconds),
        (elapsed: 60.0, expected: DurationBucket.oneToFiveMinutes)
    ])
    func sessionDurationLandsInTheExpectedBucket(
        elapsed: TimeInterval,
        expected: DurationBucket
    ) async {
        let recorded = await Self.recordedSession(pages: [2], elapsed: elapsed)

        expectNoDifference(recorded, [.readingSessionEnded(pagesRead: .twoToFive, duration: expected)])
    }
}

// MARK: Spy

private extension AnalyticsClient {
    // The `LockIsolated` capture idiom: take the inert `.noop` client and replace its one `send`
    // closure with a collector, so a test asserts exactly which signals crossed the reducer → client
    // boundary and in what order. `start` stays inert. Relies on the client's `var` closure properties.
    static func recording(into recorded: LockIsolated<[AnalyticsSignal]>) -> Self {
        var client = AnalyticsClient.noop
        client.send = { signal in recorded.withValue({ $0.append(signal) }) }
        return client
    }
}

// MARK: Fixtures and stores

private extension AnalyticsEmissionTests {
    static let origin = Date(timeIntervalSince1970: 0)

    /// A gallery with pages enough to turn through.
    static var gallery: Gallery {
        var gallery = Gallery.preview
        gallery.pageCount = 12
        return gallery
    }

    /// Reads `page` as the reader does: a turn to it, and the pager of the first generation settling on it.
    @MainActor
    static func read(_ page: Int, in store: TestStoreOf<ReadingReducer>) async {
        await store.send(.turn(toPage: page))
        await store.send(.pagerSettled(shown: page, generation: 0))
        await store.skipReceivedActions(strict: false)
    }

    // Drive one full session — present, visit `pages`, advance the clock by `elapsed`, dismiss — and
    // return the recorded signals. Shared so the scrub and boundary cases compare like with like.
    @MainActor
    static func recordedSession(pages: [Int], elapsed: TimeInterval) async -> [AnalyticsSignal] {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let now = LockIsolated(origin)
        let store = AnalyticsEmissionTests().makeReadingStore(recorded: recorded, now: now)

        await store.send(.onPresented)
        for page in pages { await read(page, in: store) }
        now.setValue(origin.addingTimeInterval(elapsed))
        await store.send(.onPerformDismiss)
        await store.skipInFlightEffects(strict: false)

        return recorded.value
    }

    // The date generator reads the box on every call, so advancing the box between `onPresented` and
    // `onPerformDismiss` is what produces a deterministic elapsed interval. The clock is a `TestClock`
    // that is never advanced, so the page-change debounce never fires and cannot interleave with the
    // assertions — the debounce is not what these cases are about.
    @MainActor
    func makeReadingStore(
        recorded: LockIsolated<[AnalyticsSignal]>,
        now: LockIsolated<Date>
    ) -> TestStoreOf<ReadingReducer> {
        let inMemoryStorage = InMemoryStorage()

        return withDependencies {
            $0.defaultInMemoryStorage = inMemoryStorage
        } operation: {
            let store = TestStore(
                initialState: ReadingReducer.State(gallery: Self.gallery),
                reducer: ReadingReducer.init,
                withDependencies: {
                    $0.analyticsClient = .recording(into: recorded)
                    $0.appLaunchAutomationClient = .none
                    $0.continuousClock = TestClock()
                    $0.cookieClient = .noop
                    $0.date = DateGenerator({ now.value })
                    $0.defaultInMemoryStorage = inMemoryStorage
                    $0.downloadClient = .noop
                    $0.hapticsClient = .noop
                }
            )
            store.exhaustivity = .off(showSkippedAssertions: false)
            return store
        }
    }
}
