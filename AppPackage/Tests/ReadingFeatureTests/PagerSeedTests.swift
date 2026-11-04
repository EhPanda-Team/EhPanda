import CoreGraphics
@testable import ReadingFeature
import Testing

// Pins when the reader seeds its pager on the resume page: once, at the first measurement of an area it can lay pages
// out in, rather than at the first measurement. A first measurement of 0 by 1 pt had used the seed up without seeding,
// and the reader opened on page 1 under an indicator naming the resume page (see `PagerSeed`).
@Suite
struct PagerSeedTests {
    @Test
    func thePagerIsSeededAtTheFirstReadingAreaNotTheFirstMeasurement() {
        var seed = PagerSeed()
        // The measurements of the iPad reader opening under a full-width bottom bar.
        let measurements = [
            CGSize(width: 0, height: 1), CGSize(width: 834, height: 1052), CGSize(width: 834, height: 1210)
        ]
        let seeds = measurements.map({ PagerSeed.isReadingArea($0) && seed.seeds() })
        #expect(seeds == [false, true, false])
        #expect(seed.isSeeded)
    }

    @Test(arguments: [
        CGSize.zero, CGSize(width: 0, height: 1), CGSize(width: 1, height: 0), CGSize(width: -1, height: 10),
        CGSize(width: CGFloat.infinity, height: 10), CGSize(width: 10, height: CGFloat.nan)
    ])
    func aDegenerateMeasurementIsNoReadingArea(size: CGSize) {
        #expect(!PagerSeed.isReadingArea(size))
    }

    @Test
    func aPagerNotYetMeasuredIsNotSeeded() {
        let seed = PagerSeed()
        #expect(!seed.isSeeded)
        #expect(PagerSeed.isReadingArea(CGSize(width: 834, height: 1052)))
    }
}
