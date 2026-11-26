import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import ReadingSettingFeature
import Sharing

// MARK: - Webtoon detection (D-05 to D-07; W-1 to W-3 of quick 261126-iq9)
extension ReadingReducer {
    /// Decides once whether the open gallery is a webtoon (D-06, D-07), and asks for the pages it decides from when
    /// the gallery opens (W-2). It runs after every action, so the verdict lands the moment the known sizes allow
    /// one, whatever brought them: a size recorded from any source, the middle pages' addresses fetched at open, or
    /// the option turned on in the reading settings (`webtoonReadingPreferenceChanged`). With the option off, or with
    /// a verdict already recorded, it does nothing.
    var webtoonReducer: some ReducerOf<Self> {
        Reduce { state, action in
            if state.setting.alwaysReadsWebtoonsVertically, state.isWebtoon == nil,
               let isWebtoon = state.webtoonVerdictFromKnownSizes {
                record(isWebtoon: isWebtoon, in: &state)
            }
            return action.is(\.onPresented) ? fetchWebtoonSample(state) : .none
        }
    }

    /// Asks for the middle pages' image addresses when an unchecked gallery opens with the option on (W-2), through
    /// `fetchImageURLs`, the reader's own page-address fetch, at its own granularity (the thumbnail batch, or the
    /// page of a multi-page viewer). The served URLs' file identifiers record the sizes the verdict needs, and the
    /// fetched addresses are kept, so those pages are ready if the user reads that far. A page whose size is known,
    /// an offline reader and a gallery that is never sampled ask for nothing. A failed fetch records no verdict and is
    /// not retried from here (W-3): the verdict can still land when the normal reading path learns those sizes.
    private func fetchWebtoonSample(_ state: State) -> Effect<Action> {
        guard state.setting.alwaysReadsWebtoonsVertically, state.isWebtoon == nil, !state.isOffline,
              let pages = State.webtoonSamplePages(pageCount: state.gallery.pageCount)
        else { return .none }
        return .merge(
            pages
                .filter({ state.pageSizes[$0] == nil })
                .map({ .send(.fetchImageURLs($0)) })
        )
    }

    /// Records the verdict for the session, for the reading settings if they are open, and in the browsing history
    /// through the same upsert as the reading progress (D-07), so the gallery is checked only once. A verdict that
    /// turns the reader vertical mid-session says so in a toast (D-06); one that leaves the direction as it was (no
    /// webtoon, or a user who already reads vertically) shows none. A gallery the history cannot key keeps its verdict
    /// for the session.
    private func record(isWebtoon: Bool, in state: inout State) {
        let direction = state.readingSetting.readingDirection
        state.isWebtoon = isWebtoon
        if state.destination?.is(\.readingSetting) == true {
            state.destination?.modify(\.readingSetting) { $0.galleryIsWebtoon = isWebtoon }
        }
        if state.readingSetting.readingDirection != direction {
            state.toast = .success(title: .webtoonToastTitle, caption: .webtoonToastMessage)
        }
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

    /// The three pages a verdict is drawn from (W-1): the middle three, `m - 1`, `m` and `m + 1` with
    /// `m = (pageCount + 1) / 2`, whatever page the reader is on, so a cover, a title page or an end page cannot
    /// decide the gallery. `nil` for a gallery of fewer than three pages, which is never detected.
    static func webtoonSamplePages(pageCount: Int) -> ClosedRange<Int>? {
        guard pageCount >= 3 else { return nil }
        let middle = (pageCount + 1) / 2
        return (middle - 1)...(middle + 1)
    }

    /// The verdict the known sizes give for the middle sample (D-05, W-1): a webtoon when the three sampled pages are
    /// all extremely tall, not one when any of them is not, and `nil` while a sampled page's size is not known yet.
    /// The sizes are the reader's own (`pageSizes`), from whichever source gave them.
    var webtoonVerdictFromKnownSizes: Bool? {
        guard let pages = Self.webtoonSamplePages(pageCount: gallery.pageCount) else { return nil }
        let sizes = pages.compactMap({ pageSizes[$0]?.pixelSize })
        guard sizes.count == pages.count else { return nil }
        return sizes.allSatisfy({ Double($0.height) / Double($0.width) >= Self.webtoonAspectRatio })
    }
}
