import AnalyticsClient
import Foundation
import Testing

// One fixture per assertion triple. A named struct rather than a positional tuple: the boundary
// tables below are long, and `.0`/`.1`/`.2` reads would carry no meaning at the assertion site.
private struct CountFixture: Sendable {
    let count: Int
    let bucket: CountBucket
    let rendering: String
}

private struct DurationFixture: Sendable {
    let seconds: TimeInterval
    let bucket: DurationBucket
    let rendering: String
}

@Suite
struct BucketTests {
    // Both values on every edge, one interior value per bucket, and the negative-input clamp.
    @Test(arguments: [
        CountFixture(count: -1_000, bucket: .zero, rendering: "0"),
        CountFixture(count: -1, bucket: .zero, rendering: "0"),
        CountFixture(count: 0, bucket: .zero, rendering: "0"),
        CountFixture(count: 1, bucket: .one, rendering: "1"),
        CountFixture(count: 2, bucket: .twoToFive, rendering: "2-5"),
        CountFixture(count: 3, bucket: .twoToFive, rendering: "2-5"),
        CountFixture(count: 5, bucket: .twoToFive, rendering: "2-5"),
        CountFixture(count: 6, bucket: .sixToTwenty, rendering: "6-20"),
        CountFixture(count: 13, bucket: .sixToTwenty, rendering: "6-20"),
        CountFixture(count: 20, bucket: .sixToTwenty, rendering: "6-20"),
        CountFixture(count: 21, bucket: .twentyOneToFifty, rendering: "21-50"),
        CountFixture(count: 35, bucket: .twentyOneToFifty, rendering: "21-50"),
        CountFixture(count: 50, bucket: .twentyOneToFifty, rendering: "21-50"),
        CountFixture(count: 51, bucket: .fiftyOnePlus, rendering: "51+"),
        CountFixture(count: 5_000, bucket: .fiftyOnePlus, rendering: "51+"),
        CountFixture(count: .max, bucket: .fiftyOnePlus, rendering: "51+")
    ])
    func countBucketMapsEveryBoundary(fixture: CountFixture) {
        let bucket = CountBucket(count: fixture.count)

        #expect(bucket == fixture.bucket)
        #expect(bucket.rawValue == fixture.rendering)
    }

    @Test(arguments: [
        DurationFixture(seconds: -1_000, bucket: .underTenSeconds, rendering: "0-10s"),
        DurationFixture(seconds: -0.001, bucket: .underTenSeconds, rendering: "0-10s"),
        DurationFixture(seconds: 0, bucket: .underTenSeconds, rendering: "0-10s"),
        DurationFixture(seconds: 4, bucket: .underTenSeconds, rendering: "0-10s"),
        DurationFixture(seconds: 9.999, bucket: .underTenSeconds, rendering: "0-10s"),
        DurationFixture(seconds: 10, bucket: .tenToSixtySeconds, rendering: "10-60s"),
        DurationFixture(seconds: 35, bucket: .tenToSixtySeconds, rendering: "10-60s"),
        DurationFixture(seconds: 59.999, bucket: .tenToSixtySeconds, rendering: "10-60s"),
        DurationFixture(seconds: 60, bucket: .oneToFiveMinutes, rendering: "1-5m"),
        DurationFixture(seconds: 180, bucket: .oneToFiveMinutes, rendering: "1-5m"),
        DurationFixture(seconds: 299.999, bucket: .oneToFiveMinutes, rendering: "1-5m"),
        DurationFixture(seconds: 300, bucket: .fiveToTwentyMinutes, rendering: "5-20m"),
        DurationFixture(seconds: 700, bucket: .fiveToTwentyMinutes, rendering: "5-20m"),
        DurationFixture(seconds: 1_199.999, bucket: .fiveToTwentyMinutes, rendering: "5-20m"),
        DurationFixture(seconds: 1_200, bucket: .overTwentyMinutes, rendering: "20m+"),
        DurationFixture(seconds: 86_400, bucket: .overTwentyMinutes, rendering: "20m+"),
        DurationFixture(seconds: .infinity, bucket: .overTwentyMinutes, rendering: "20m+")
    ])
    func durationBucketMapsEveryBoundary(fixture: DurationFixture) {
        let bucket = DurationBucket(seconds: fixture.seconds)

        #expect(bucket == fixture.bucket)
        #expect(bucket.rawValue == fixture.rendering)
    }

    // Totality without restating the switch: sweeping ascending inputs must never revisit an
    // earlier bucket (no overlaps), and every declared case must be reachable (no dead case).
    // Together with the boundary table above, that is the D-08 "no gaps, no overlaps" guarantee.
    @Test
    func countBucketIsTotalAndMonotonic() {
        let order = Dictionary(
            uniqueKeysWithValues: CountBucket.allCases.enumerated().map({ ($0.element, $0.offset) })
        )
        var highestReached = 0
        var reached = Set<CountBucket>()

        for count in -20...120 {
            let bucket = CountBucket(count: count)
            let position = order[bucket] ?? -1

            #expect(position >= highestReached, "count \(count) fell back to an earlier bucket")
            highestReached = max(highestReached, position)
            reached.insert(bucket)
        }

        #expect(reached.count == CountBucket.allCases.count)
    }

    @Test
    func durationBucketIsTotalAndMonotonic() {
        let order = Dictionary(
            uniqueKeysWithValues: DurationBucket.allCases.enumerated().map({ ($0.element, $0.offset) })
        )
        var highestReached = 0
        var reached = Set<DurationBucket>()

        for seconds in stride(from: -30.0, through: 1_500.0, by: 0.5) {
            let bucket = DurationBucket(seconds: seconds)
            let position = order[bucket] ?? -1

            #expect(position >= highestReached, "duration \(seconds) fell back to an earlier bucket")
            highestReached = max(highestReached, position)
            reached.insert(bucket)
        }

        #expect(reached.count == DurationBucket.allCases.count)
    }

    // A NaN duration is a programming error upstream, never a user event. Classifying it as the
    // longest session would silently inflate a metric, so it clamps to the shortest bucket the
    // same way a negative duration does.
    @Test
    func notANumberDurationClampsToTheShortestBucket() {
        #expect(DurationBucket(seconds: .nan) == .underTenSeconds)
    }

    @Test
    func everyRenderingIsDistinct() {
        let renderings = CountBucket.allCases.map(\.rawValue) + DurationBucket.allCases.map(\.rawValue)

        #expect(Set(renderings).count == renderings.count)
    }
}
