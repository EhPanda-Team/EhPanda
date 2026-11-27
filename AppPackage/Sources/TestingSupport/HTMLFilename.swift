public enum HTMLFilename: String, Sendable {
    // List
    // FrontPage
    case frontPageMinimalList = "FrontPageMinimalList"
    case frontPageMinimalPlusList = "FrontPageMinimalPlusList"
    case frontPageCompactList = "FrontPageCompactList"
    case frontPageExtendedList = "FrontPageExtendedList"
    case frontPageThumbnailList = "FrontPageThumbnailList"

    // Watched
    case watchedMinimalList = "WatchedMinimalList"
    case watchedMinimalPlusList = "WatchedMinimalPlusList"
    case watchedCompactList = "WatchedCompactList"
    case watchedExtendedList = "WatchedExtendedList"
    case watchedThumbnailList = "WatchedThumbnailList"

    // Popular
    case popularMinimalList = "PopularMinimalList"
    case popularMinimalPlusList = "PopularMinimalPlusList"
    case popularCompactList = "PopularCompactList"
    case popularExtendedList = "PopularExtendedList"
    case popularThumbnailList = "PopularThumbnailList"

    // Favorites
    case favoritesMinimalList = "FavoritesMinimalList"
    case favoritesMinimalPlusList = "FavoritesMinimalPlusList"
    case favoritesCompactList = "FavoritesCompactList"
    case favoritesExtendedList = "FavoritesExtendedList"
    case favoritesThumbnailList = "FavoritesThumbnailList"

    // Toplists
    case toplistsCompactList = "ToplistsCompactList"

    // Gallery
    case galleryDetail = "GalleryDetail"
    case galleryMPVKeys = "GalleryMPVKeys"
    case galleryNormalImageURL = "GalleryNormalImageURL"

    // Other
    case ipBanned = "IPBanned"
    case bandwidthExceeded = "BandwidthExceeded"
    case exLoginRequired = "ExLoginRequired"
    case ehSetting = "EhSetting"
    case galleryDetailWithGreeting = "GalleryDetailWithGreeting"

    // Report (the site's gallery report pages, saved as a guest on 2026-11-06)
    case reportSelect = "ReportSelect"
    case reportChild = "ReportChild"
    case reportOther = "ReportOther"

    // My Tags (synthetic pages in the site's markup of 2026-11-22: invented tags and credentials)
    case myTagsTagSet1 = "MyTagsTagSet1"
    case myTagsTagSet2 = "MyTagsTagSet2"
    // An empty set whose page offers deleting it (quick 261126-udx). No page with that control has been read, so its
    // Delete button is drawn after New and Rename in their markup, calling the site's `do_tagset_delete()`.
    case myTagsTagSet3 = "MyTagsTagSet3"
}
