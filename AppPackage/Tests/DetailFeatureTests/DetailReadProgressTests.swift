@testable import DetailFeature
import Testing

/// The Read button's progress ring is the resume page over the gallery's page count; no saved page draws no ring.
struct DetailReadProgressTests {
    @Test
    func theRingIsTheResumePageOverThePageCount() {
        #expect(ReadProgress.fraction(page: 12, pageCount: 156) == 12.0 / 156.0)
        #expect(ReadProgress.fraction(page: 78, pageCount: 156) == 0.5)
    }

    @Test
    func theLastPageIsAFullRing() {
        #expect(ReadProgress.fraction(page: 156, pageCount: 156) == 1)
        #expect(ReadProgress.fraction(page: 1, pageCount: 1) == 1)
    }

    // A page past the count (a count that shrank, or a resume page saved from a longer copy) never overdraws the ring.
    @Test(arguments: [157, 1000, Int.max])
    func aPagePastTheCountClampsToAFullRing(_ page: Int) {
        #expect(ReadProgress.fraction(page: page, pageCount: 156) == 1)
    }

    @Test(arguments: [0, -1, Int.min])
    func noSavedPageDrawsNoRing(_ page: Int) {
        #expect(ReadProgress.fraction(page: page, pageCount: 156) == nil)
    }

    // An unknown count (the detail page not fetched yet, no cover count) cannot be divided by.
    @Test(arguments: [0, -1, Int.min])
    func anUnknownPageCountDrawsNoRing(_ pageCount: Int) {
        #expect(ReadProgress.fraction(page: 12, pageCount: pageCount) == nil)
    }

    @Test
    func voiceOverHearsTheResumePageAndTheTotal() {
        #expect(ReadProgress.accessibilityValue(page: 12, pageCount: 156) == "Page 12 of 156")
        #expect(ReadProgress.accessibilityValue(page: 156, pageCount: 156) == "Page 156 of 156")
    }

    @Test
    func withoutATotalVoiceOverHearsTheResumePageAlone() {
        #expect(ReadProgress.accessibilityValue(page: 12, pageCount: 0) == "Page 12")
    }

    @Test
    func aGalleryThatWasNeverReadHasNoValue() {
        #expect(ReadProgress.accessibilityValue(page: 0, pageCount: 156).isEmpty)
    }
}
