import AppModels

extension EhSettingReducer {
    /// One saved control of the settings form: the unit whose control is disabled while the site answers its save.
    ///
    /// The cases follow the form's order. The per-index controls (a category cell, a favorites name, an excluded
    /// language) are each their own option, and the profile section's controls share `profile`.
    public enum Option: Hashable, Sendable {
        case loadThroughHathSetting
        case hahRegion
        case imageResolution
        case useOriginalImages
        case imageSizeWidth
        case imageSizeHeight
        case galleryName
        case archiverBehavior
        case disabledCategory(Int)
        case displayMode
        case searchRangeIndicatorStyle
        case enableGalleryThumbnailSelector
        case favoriteCategory(Int)
        case favoritesSortOrder
        case searchResultCount
        case thumbnailLoadTiming
        case thumbnailConfigSize
        case thumbnailConfigRows
        case coverScaleFactor
        case ratingsColor
        case tagWatchingThreshold
        case tagFilteringThreshold
        case showFilteredRemovalCount
        case excludedLanguage(Int)
        case excludedUploaders
        case viewportVirtualWidth
        case commentsSortOrder
        case commentVotesShowTiming
        case tagsSortOrder
        case galleryPageNumbering
        case useMultiplePageViewer
        case multiplePageViewerStyle
        case multiplePageViewerShowThumbnailPane
        case profile
    }
}

extension EhSettingReducer.Option {
    /// The options whose values differ between two settings, in form order.
    ///
    /// Each scalar field is compared on its own and each array index by index, and an index only one side has counts
    /// as changed. This is the only place that maps options to `EhSetting` fields. It never lists `profile`: the
    /// profile list is not a form value, and a profile action does not go through it.
    static func changes(from old: EhSetting, to new: EhSetting) -> [Self] {
        var changed = [Self]()
        func compare<Value: Equatable>(_ option: Self, _ field: KeyPath<EhSetting, Value>) {
            if old[keyPath: field] != new[keyPath: field] {
                changed.append(option)
            }
        }

        compare(.loadThroughHathSetting, \.loadThroughHathSetting)
        compare(.hahRegion, \.hahRegion)
        compare(.imageResolution, \.imageResolution)
        compare(.useOriginalImages, \.useOriginalImages)
        compare(.imageSizeWidth, \.imageSizeWidth)
        compare(.imageSizeHeight, \.imageSizeHeight)
        compare(.galleryName, \.galleryName)
        compare(.archiverBehavior, \.archiverBehavior)
        changed += changedIndices(old.disabledCategories, new.disabledCategories).map(Self.disabledCategory)
        compare(.displayMode, \.displayMode)
        compare(.searchRangeIndicatorStyle, \.searchRangeIndicatorStyle)
        compare(.enableGalleryThumbnailSelector, \.enableGalleryThumbnailSelector)
        changed += changedIndices(old.favoriteCategories, new.favoriteCategories).map(Self.favoriteCategory)
        compare(.favoritesSortOrder, \.favoritesSortOrder)
        compare(.searchResultCount, \.searchResultCount)
        compare(.thumbnailLoadTiming, \.thumbnailLoadTiming)
        compare(.thumbnailConfigSize, \.thumbnailConfigSize)
        compare(.thumbnailConfigRows, \.thumbnailConfigRows)
        compare(.coverScaleFactor, \.coverScaleFactor)
        compare(.ratingsColor, \.ratingsColor)
        compare(.tagWatchingThreshold, \.tagWatchingThreshold)
        compare(.tagFilteringThreshold, \.tagFilteringThreshold)
        compare(.showFilteredRemovalCount, \.showFilteredRemovalCount)
        changed += changedIndices(old.excludedLanguages, new.excludedLanguages).map(Self.excludedLanguage)
        compare(.excludedUploaders, \.excludedUploaders)
        compare(.viewportVirtualWidth, \.viewportVirtualWidth)
        compare(.commentsSortOrder, \.commentsSortOrder)
        compare(.commentVotesShowTiming, \.commentVotesShowTiming)
        compare(.tagsSortOrder, \.tagsSortOrder)
        compare(.galleryPageNumbering, \.galleryPageNumbering)
        compare(.useMultiplePageViewer, \.useMultiplePageViewer)
        compare(.multiplePageViewerStyle, \.multiplePageViewerStyle)
        compare(.multiplePageViewerShowThumbnailPane, \.multiplePageViewerShowThumbnailPane)
        return changed
    }

    /// The offsets where the two arrays differ, followed by the offsets only the longer one has.
    private static func changedIndices<Element: Equatable>(_ old: [Element], _ new: [Element]) -> [Int] {
        let differing = zip(old, new).enumerated().compactMap({ offset, pair in
            pair.0 == pair.1 ? nil : offset
        })
        return differing + Array(min(old.count, new.count)..<max(old.count, new.count))
    }
}
