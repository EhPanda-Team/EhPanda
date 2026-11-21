import AppModels
import AppTools
import ComposableArchitecture
import Sharing

// MARK: - Webtoon detection (D-04 to D-07)
extension ReadingReducer {
    /// Decides once whether the open gallery is a webtoon (D-06, D-07). It runs after every action, so the verdict
    /// lands the moment the known sizes allow one, whatever brought them: a size recorded from any source, a newly
    /// committed page, or the option turned on in the reading settings (`webtoonReadingPreferenceChanged`). With the
    /// option off, or with a verdict already recorded, it does nothing.
    var webtoonReducer: some ReducerOf<Self> {
        Reduce { state, _ in
            guard state.setting.alwaysReadsWebtoonsVertically, state.isWebtoon == nil,
                  let isWebtoon = state.webtoonVerdictFromKnownSizes
            else { return .none }
            record(isWebtoon: isWebtoon, in: &state)
            return .none
        }
    }

    /// Records the verdict for the session and in the browsing history, through the same upsert as the reading
    /// progress (D-07), so the gallery is checked only once. A gallery the history cannot key keeps its verdict for
    /// the session.
    private func record(isWebtoon: Bool, in state: inout State) {
        state.isWebtoon = isWebtoon
        let gid = state.gallery.id
        let token = state.gallery.token
        guard gid.isValidGID else { return }
        @Shared(.galleryHistory) var galleryHistory
        $galleryHistory.withLock {
            $0.recordWebtoonVerdict(gid: gid, token: token, isWebtoon: isWebtoon, date: date.now)
        }
    }
}

extension ReadingReducer.State {
    /// The height-to-width ratio from which a page is extremely tall (D-05): a phone screenshot is about 2.17 and a
    /// manga page about 1.4.
    static let webtoonAspectRatio = 2.5

    /// The three pages a verdict is drawn from (D-04): the page before `page`, `page` and the page after it, moved
    /// inside the gallery on its first and last page. `nil` for a gallery of fewer than three pages, which is never
    /// detected.
    static func webtoonSamplePages(around page: Int, pageCount: Int) -> ClosedRange<Int>? {
        guard pageCount >= 3 else { return nil }
        let first = min(max(page - 1, 1), pageCount - 2)
        return first...(first + 2)
    }

    /// The verdict the known sizes give around the committed page (D-05, D-06): a webtoon when the three sampled
    /// pages are all extremely tall, not one when any of them is not, and `nil` while a sampled page's size is not
    /// known yet. The sizes are the reader's own (`pageSizes`), from whichever source gave them.
    var webtoonVerdictFromKnownSizes: Bool? {
        guard let pages = Self.webtoonSamplePages(around: position.page, pageCount: gallery.pageCount) else {
            return nil
        }
        let sizes = pages.compactMap({ pageSizes[$0]?.pixelSize })
        guard sizes.count == pages.count else { return nil }
        return sizes.allSatisfy({ Double($0.height) / Double($0.width) >= Self.webtoonAspectRatio })
    }
}
