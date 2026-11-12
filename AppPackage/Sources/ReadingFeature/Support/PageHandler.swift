import AppModels

/// Maps between reading pages, counted from 1, and the pager's positions, counted from 0: one position holds two pages
/// in a landscape dual-page layout. The reader's page lives in reading-page space (`ReaderPosition`); the pager's
/// position is derived from it with these maps for the layout on screen.
struct PageHandler: Sendable {
    func mapFromPager(
        index: Int,
        pageCount: Int,
        setting: Setting,
        isLandscape: Bool
    ) -> Int {
        guard isLandscape && setting.enableDualPageMode
                && setting.readingDirection != .vertical
        else { return index + 1 }
        guard index > 0 else { return 1 }

        let result = setting.exceptCover ? index * 2 : index * 2 + 1

        if result + 1 == pageCount {
            return pageCount
        } else {
            return result
        }
    }

    func mapToPager(index: Int, setting: Setting, isLandscape: Bool) -> Int {
        guard isLandscape && setting.enableDualPageMode
                && setting.readingDirection != .vertical
        else { return index - 1 }
        guard index > 1 else { return 0 }

        return setting.exceptCover ? index / 2 : (index - 1) / 2
    }

    /// The page the pager reports for the position `page` lies in, which is the page a turn to `page` lands on.
    func landingPage(of page: Int, pageCount: Int, setting: Setting, isLandscape: Bool) -> Int {
        mapFromPager(
            index: mapToPager(index: page, setting: setting, isLandscape: isLandscape),
            pageCount: pageCount, setting: setting, isLandscape: isLandscape
        )
    }

    /// The page `offset` positions on from the position `page` lies in, forward when positive, kept within the
    /// gallery's positions. Tap-to-turn, auto-play and the accessibility page actions turn by positions.
    func page(
        turningFrom page: Int, by offset: Int, pageCount: Int, setting: Setting, isLandscape: Bool
    ) -> Int {
        guard pageCount > 0 else { return page }
        let lastPosition = mapToPager(index: pageCount, setting: setting, isLandscape: isLandscape)
        let position = mapToPager(index: page, setting: setting, isLandscape: isLandscape) + offset
        return mapFromPager(
            index: min(max(position, 0), lastPosition),
            pageCount: pageCount, setting: setting, isLandscape: isLandscape
        )
    }
}
