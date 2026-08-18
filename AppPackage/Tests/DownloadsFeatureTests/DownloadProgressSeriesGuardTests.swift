import Foundation
import Testing

/// Pins the numerator-series guard itself: what it accepts, and every shape it still refuses.
///
/// **Why a suite about an assertion.** `expectTheCompletedSeriesNeverLosesGround` used to demand a
/// strictly non-rewinding series, which is stricter than anything the coordinator can promise: the
/// pair is computed under the actor but delivered across the client seam's main-actor hop, where
/// two pushes can be in flight at once, so one displaced observation can be recorded ahead of the
/// value that supersedes it. Relaxing the guard to accept exactly that is correct, and it is also
/// the moment a guard can quietly stop guarding — a tolerance nobody pins is indistinguishable
/// from a vacuous assertion, and every case that calls the guard would stay green while the
/// numerator lost ground.
///
/// So the acceptance arm and all three refusal arms are pinned here, over synthetic series rather
/// than through a coordinator: the guard reads the numerator column alone, and staging a real
/// regression at the seam would pin the staging rather than the rule.
///
/// `withKnownIssue` is the pin rather than decoration — it fails when its body records *no* issue,
/// so each refusal case falls over the moment the guard stops refusing that shape.
@Suite
struct DownloadProgressSeriesGuardTests: DownloadFeatureTestCase {
    /// The ordinary series: every push at or above the one before it.
    @Test
    func testAClimbingSeriesIsAccepted() {
        expectTheCompletedSeriesNeverLosesGround(makeSeries(numerators: [0, 2, 4, 6]))
    }

    /// The accepted transient: one push delivered out of the order it was computed in, with the
    /// next observation restoring the value it briefly hid.
    @Test
    func testOneDisplacedPushTheNextObservationRepaintsIsAccepted() {
        expectTheCompletedSeriesNeverLosesGround(makeSeries(numerators: [0, 4, 2, 4, 6]))
    }

    /// A dip nothing repaints is lost ground rather than a displaced push: the card is left below
    /// the coordinator's own floor, which is what the scheduler reads before it force-expires the
    /// least-progressing tasks. This is also the shape a D-G7-01 withdrawal makes, which is why a
    /// case that stages one asserts its series per regime instead of leaning on this tolerance.
    @Test
    func testADipNoLaterPushRepaintsIsRefused() {
        withKnownIssue {
            expectTheCompletedSeriesNeverLosesGround(makeSeries(numerators: [0, 4, 2, 3, 6]))
        }
    }

    /// Two displaced pushes are a numerator that keeps losing ground, however promptly each one is
    /// repainted. One is the seam's transient; a second is a pattern.
    @Test
    func testASecondDisplacedPushIsRefused() {
        withKnownIssue {
            expectTheCompletedSeriesNeverLosesGround(makeSeries(numerators: [0, 4, 2, 4, 6, 4, 6]))
        }
    }

    /// A dip in the final position is refused because nothing follows it: the acceptance rests
    /// entirely on the next push repainting, and there is no next push. The card keeps the stale
    /// numerator for as long as the case observes it.
    @Test
    func testADipInTheFinalPositionIsRefused() {
        withKnownIssue {
            expectTheCompletedSeriesNeverLosesGround(makeSeries(numerators: [0, 2, 6, 4]))
        }
    }
}

// MARK: - Helpers

private extension DownloadProgressSeriesGuardTests {
    /// One recorded push per numerator, under one session identity, with the denominator and the
    /// subtitle held constant. The guard reads the numerator column alone, so anything varying
    /// beside it would be scenery a reader has to discount before trusting the case.
    func makeSeries(numerators: [Int64]) -> [BackgroundProcessingClientSpy.ProgressUpdate] {
        let sessionID = UUID()
        return numerators.map { numerator in
            BackgroundProcessingClientSpy.ProgressUpdate(
                sessionID: sessionID,
                completedUnitCount: numerator,
                totalUnitCount: 6,
                inFlightSubunitCount: 0,
                subtitle: "\(numerator) / 6 pages · 1 gallery"
            )
        }
    }
}
