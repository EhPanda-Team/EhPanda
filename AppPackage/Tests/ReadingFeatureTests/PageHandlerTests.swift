import Testing
import AppModels
@testable import ReadingFeature

// Wave-0 regression guard for DEP-05. These cases freeze `PageHandler.mapToPager`/`mapFromPager` —
// the pure stack-index ↔ reading-page mapping, including the dual-page cover-exception math —
// before the reader is re-seamed from the SwiftUIPager `Page` onto a plain index (D-07).
// `PageHandler` survives the swap byte-for-byte; only its caller changes, so any drift caught here
// is a re-seam bug. Every call passes `isLandscape:` explicitly so the suite never reads the
// `DeviceUtil.isLandscape` process global and stays deterministic off-device.
@MainActor
@Suite
struct PageHandlerTests {
    private func makeSetting(
        readingDirection: ReadingDirection = .leftToRight,
        enablesDualPageMode: Bool = false,
        exceptCover: Bool = false
    ) -> Setting {
        var setting = Setting()
        setting.readingDirection = readingDirection
        setting.enablesDualPageMode = enablesDualPageMode
        setting.exceptCover = exceptCover
        return setting
    }

    // Single-page mode applies when the device is portrait OR dual-page is off: the maps are a
    // plain ±1 offset between the 0-based pager index and the 1-based reading page.
    @Test(arguments: 0..<10)
    func singlePageModeIsPlusMinusOne(pagerIndex: Int) {
        let handler = PageHandler()
        let dualButPortrait = makeSetting(enablesDualPageMode: true)
        let landscapeButSingle = makeSetting()
        #expect(
            handler.mapFromPager(index: pagerIndex, pageCount: 100, setting: dualButPortrait, isLandscape: false)
                == pagerIndex + 1
        )
        #expect(
            handler.mapFromPager(index: pagerIndex, pageCount: 100, setting: landscapeButSingle, isLandscape: true)
                == pagerIndex + 1
        )
        #expect(
            handler.mapToPager(index: pagerIndex + 1, setting: dualButPortrait, isLandscape: false) == pagerIndex
        )
        #expect(
            handler.mapToPager(index: pagerIndex + 1, setting: landscapeButSingle, isLandscape: true) == pagerIndex
        )
    }

    // Dual-page landscape without the cover exception: stack i shows pages {2i+1, 2i+2}, so the
    // stack's first reading page is 2i+1; stack 0 is guarded to page 1.
    @Test(arguments: zip([0, 1, 2, 3, 10], [1, 3, 5, 7, 21]))
    func dualPageMapsStackToOddFirstPage(pagerIndex: Int, readingPage: Int) {
        let handler = PageHandler()
        let setting = makeSetting(enablesDualPageMode: true)
        #expect(
            handler.mapFromPager(index: pagerIndex, pageCount: 100, setting: setting, isLandscape: true)
                == readingPage
        )
    }

    // Both pages of a dual stack map back to the same stack index: pages {2i+1, 2i+2} → i,
    // with pages 0/1 guarded to stack 0.
    @Test(arguments: zip([0, 1, 2, 3, 4, 5, 21, 22], [0, 0, 0, 1, 1, 2, 10, 10]))
    func dualPageMapsReadingPageToStack(readingPage: Int, pagerIndex: Int) {
        let handler = PageHandler()
        let setting = makeSetting(enablesDualPageMode: true)
        #expect(handler.mapToPager(index: readingPage, setting: setting, isLandscape: true) == pagerIndex)
    }

    // Cover exception: the cover stands alone, so stack i (>0) shows pages {2i, 2i+1} and its
    // first reading page is 2i; stack 0 is the cover (page 1).
    @Test(arguments: zip([0, 1, 2, 3, 10], [1, 2, 4, 6, 20]))
    func coverExceptionMapsStackToEvenFirstPage(pagerIndex: Int, readingPage: Int) {
        let handler = PageHandler()
        let setting = makeSetting(enablesDualPageMode: true, exceptCover: true)
        #expect(
            handler.mapFromPager(index: pagerIndex, pageCount: 100, setting: setting, isLandscape: true)
                == readingPage
        )
    }

    // Cover exception reverse map: pages {2i, 2i+1} → i, with the cover pages 0/1 guarded to stack 0.
    @Test(arguments: zip([0, 1, 2, 3, 4, 5, 20, 21], [0, 0, 1, 1, 2, 2, 10, 10]))
    func coverExceptionMapsReadingPageToStack(readingPage: Int, pagerIndex: Int) {
        let handler = PageHandler()
        let setting = makeSetting(enablesDualPageMode: true, exceptCover: true)
        #expect(handler.mapToPager(index: readingPage, setting: setting, isLandscape: true) == pagerIndex)
    }

    // The last-page clamp: when a stack's first page is the second-to-last page
    // (result + 1 == pageCount), the map lands on the final page itself — and that clamped page
    // still maps back to the same stack.
    @Test
    func lastPageCoverExceptionClampsToPageCount() {
        let handler = PageHandler()
        let plain = makeSetting(enablesDualPageMode: true)
        let cover = makeSetting(enablesDualPageMode: true, exceptCover: true)
        #expect(handler.mapFromPager(index: 2, pageCount: 6, setting: plain, isLandscape: true) == 6)
        #expect(handler.mapFromPager(index: 2, pageCount: 5, setting: cover, isLandscape: true) == 5)
        #expect(handler.mapToPager(index: 6, setting: plain, isLandscape: true) == 2)
        #expect(handler.mapToPager(index: 5, setting: cover, isLandscape: true) == 2)
        // One page longer and the clamp geometry no longer applies.
        #expect(handler.mapFromPager(index: 2, pageCount: 7, setting: plain, isLandscape: true) == 5)
        #expect(handler.mapFromPager(index: 2, pageCount: 6, setting: cover, isLandscape: true) == 4)
    }

    // mapToPager(mapFromPager(i)) == i in every mode — the identity the re-seamed reader relies on
    // when it round-trips the shared index through reading-page space (slider, resume-seed).
    @Test(arguments: 0..<12)
    func roundTripIdentityHoldsInEveryMode(pagerIndex: Int) {
        let handler = PageHandler()
        let modes: [(setting: Setting, isLandscape: Bool)] = [
            (makeSetting(), false),
            (makeSetting(enablesDualPageMode: true), true),
            (makeSetting(enablesDualPageMode: true, exceptCover: true), true)
        ]
        for mode in modes {
            let readingPage = handler.mapFromPager(
                index: pagerIndex, pageCount: 100, setting: mode.setting, isLandscape: mode.isLandscape
            )
            #expect(
                handler.mapToPager(index: readingPage, setting: mode.setting, isLandscape: mode.isLandscape)
                    == pagerIndex
            )
        }
    }

    // RTL stays logical: the data source is forward and only the view's layoutDirection flips, so
    // the mapping must not vary with readingDirection (only `.vertical` gates dual-page off).
    @Test(arguments: 0..<10)
    func mappingIsDirectionAgnostic(pagerIndex: Int) {
        let handler = PageHandler()
        for exceptCover in [false, true] {
            let ltr = makeSetting(
                readingDirection: .leftToRight, enablesDualPageMode: true, exceptCover: exceptCover
            )
            let rtl = makeSetting(
                readingDirection: .rightToLeft, enablesDualPageMode: true, exceptCover: exceptCover
            )
            #expect(
                handler.mapFromPager(index: pagerIndex, pageCount: 100, setting: ltr, isLandscape: true)
                    == handler.mapFromPager(index: pagerIndex, pageCount: 100, setting: rtl, isLandscape: true)
            )
            #expect(
                handler.mapToPager(index: pagerIndex + 1, setting: ltr, isLandscape: true)
                    == handler.mapToPager(index: pagerIndex + 1, setting: rtl, isLandscape: true)
            )
        }
    }
}
