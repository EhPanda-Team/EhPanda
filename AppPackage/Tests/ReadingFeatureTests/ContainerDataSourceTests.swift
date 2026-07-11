import Testing
import AppModels
@testable import ReadingFeature

// Wave-0 regression guard for DEP-05. Freezes `ReadingReducer.State.containerDataSource` — the
// dual-page / cover-exception stack collapsing that produces the `[Int]` the pager pages over —
// so the paging-construct swap cannot silently change what a "page" is. `isLandscape:` is always
// passed explicitly; the suite never reads the `DeviceUtil.isLandscape` process global.
@Suite
struct ContainerDataSourceTests {
    private func makeState(pageCount: Int) -> ReadingReducer.State {
        var gallery = Gallery.preview
        gallery.pageCount = pageCount
        return ReadingReducer.State(gallery: gallery)
    }

    private func makeDualPageSetting(exceptCover: Bool) -> Setting {
        var setting = Setting()
        setting.readingDirection = .leftToRight
        setting.enablesDualPageMode = true
        setting.exceptCover = exceptCover
        return setting
    }

    @Test
    func zeroPagesProduceEmptyDataSource() {
        let state = makeState(pageCount: 0)
        #expect(state.containerDataSource(setting: Setting(), isLandscape: false) == [])
        #expect(state.containerDataSource(setting: makeDualPageSetting(exceptCover: true), isLandscape: true) == [])
    }

    // Single-page mode (portrait, or dual-page off): one stack per reading page.
    @Test(arguments: [1, 2, 5, 6])
    func singlePageModeListsEveryPage(pageCount: Int) {
        let state = makeState(pageCount: pageCount)
        let dualButPortrait = makeDualPageSetting(exceptCover: false)
        #expect(state.containerDataSource(setting: Setting(), isLandscape: false) == Array(1...pageCount))
        #expect(state.containerDataSource(setting: dualButPortrait, isLandscape: false) == Array(1...pageCount))
    }

    // Dual-page landscape without the cover exception: stacks start at every odd page.
    @Test(arguments: zip([1, 2, 5, 6], [[1], [1], [1, 3, 5], [1, 3, 5]]))
    func dualPageCollapsesIntoOddStrides(pageCount: Int, expected: [Int]) {
        let state = makeState(pageCount: pageCount)
        #expect(
            state.containerDataSource(setting: makeDualPageSetting(exceptCover: false), isLandscape: true)
                == expected
        )
    }

    // Dual-page landscape with the cover exception: the cover stands alone, then stacks start at
    // every even page.
    @Test(arguments: zip([1, 2, 5, 6], [[1], [1, 2], [1, 2, 4], [1, 2, 4, 6]]))
    func coverExceptionKeepsCoverSingle(pageCount: Int, expected: [Int]) {
        let state = makeState(pageCount: pageCount)
        #expect(
            state.containerDataSource(setting: makeDualPageSetting(exceptCover: true), isLandscape: true)
                == expected
        )
    }
}
