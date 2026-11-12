import CoreGraphics
@testable import ReadingFeature
import Testing

// Pins which touches count as on the reader slider's thumb. The preview opens for a touch that begins on the thumb and
// for none that begins on the track away from it. The slider is 248.4 pt wide on an iPhone 11, its thumb 37 pt wide,
// so the thumb's centre travels from 18.5 pt to 229.9 pt.
@Suite
struct SliderThumbTests {
    private let range: ClosedRange<Float> = 1...156
    private let width: CGFloat = 248.4

    private func contains(_ position: CGFloat, value: Float, isReversed: Bool = false) -> Bool {
        SliderThumb.contains(position, value: value, range: range, trackWidth: width, isReversed: isReversed)
    }

    @Test
    func aTouchOnTheThumbAtTheStartOfTheRangeCounts() {
        #expect(contains(18.5, value: 1))
        #expect(contains(2, value: 1))
        #expect(contains(40, value: 1))
    }

    @Test
    func aTouchOnTheThumbAtTheEndOfTheRangeCounts() {
        #expect(contains(229.9, value: 156))
        #expect(contains(246, value: 156))
    }

    @Test
    func aTouchOnTheThumbInTheMiddleCountsAndOneOnTheTrackDoesNot() {
        // Page 78.5 of 156 puts the centre at 124.2 pt.
        #expect(contains(124.2, value: 78.5))
        #expect(contains(124.2 + 20, value: 78.5))
        #expect(!contains(124.2 + 40, value: 78.5))
        #expect(!contains(124.2 - 40, value: 78.5))
        #expect(!contains(240, value: 78.5))
        #expect(!contains(10, value: 78.5))
    }

    @Test
    func aTouchOnTheTrackAwayFromTheThumbDoesNotCountWhereverTheThumbIs() {
        #expect(!contains(200, value: 1))
        #expect(!contains(30, value: 156))
    }

    @Test
    func aReversedSliderHasItsThumbOnTheMirroredSide() {
        // Page 1 of a reversed slider is drawn at the far end.
        #expect(contains(229.9, value: 1, isReversed: true))
        #expect(!contains(18.5, value: 1, isReversed: true))
        #expect(contains(18.5, value: 156, isReversed: true))
        #expect(!contains(229.9, value: 156, isReversed: true))
    }

    @Test
    func aSliderNotYetMeasuredHasNoThumbToTouch() {
        #expect(!SliderThumb.contains(10, value: 1, range: range, trackWidth: 0, isReversed: false))
        #expect(!SliderThumb.contains(10, value: 1, range: 1...1, trackWidth: width, isReversed: false))
    }
}
