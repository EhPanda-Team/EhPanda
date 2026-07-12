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
    // Window for the `performingChanges` echo guards around a programmatic index write. The
    // index and each surface's scroll position mirror one another through onChange observers,
    // so a one-sided write echoes back through the opposite observer and would re-write the
    // side that just changed — canceling an in-flight scroll. Writers raise their flag, then
    // lower it after this delay: long enough for the observer round-trip to settle, short
    // enough not to swallow the user's next gesture (timing verified by device UAT).
    static let echoGuardDuration = 0.2

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
