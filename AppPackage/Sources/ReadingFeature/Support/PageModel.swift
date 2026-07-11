import Observation

// Replaces the SwiftUIPager `Page` object as the reader's single plain-index source of truth
// (DEP-05 / D-07): the horizontal paging ScrollView, the vertical AdvancedList, autoplay, the
// slider, tap-to-turn, and resume seeding all read and write this one index. It mirrors the exact
// `Page` surface the reader used (`.index`, `.update(.next)`/`.update(.new(index:))`,
// `.withIndex(_:)`) so those call sites survive the swap as a type change only. Like `Page`,
// `update` performs the raw increment/set; clamping to the data source's bounds belongs to the
// write sites, which own the data source.
@Observable
@MainActor
final class PageModel {
    var index: Int

    enum Update {
        case next
        case new(index: Int)
    }

    init(index: Int = 0) {
        self.index = index
    }

    static func withIndex(_ index: Int) -> PageModel {
        PageModel(index: index)
    }

    func update(_ update: Update) {
        switch update {
        case .next:
            index += 1

        case .new(let index):
            self.index = index
        }
    }
}
