/// The accessibility identifiers that the app's views carry and the UI tests find them by.
///
/// Both sides read them from here, so the app and `EhPandaUITests` cannot drift apart: renaming one is a single edit
/// that both compile against, and a misspelling fails the build instead of a test run. That is why this is a module
/// of its own with no dependencies: the UI-test target links it without linking any of the app's code.
///
/// An identifier is locale-independent and never changes what VoiceOver reads; it exists only to be found. One that
/// names an element per item is a function of the item's ID; its `…Prefix` is there for a test that finds every such
/// element at once.
public enum AccessibilityIdentifiers {
    // MARK: Gallery detail and comments

    /// The gallery detail page's scroll view.
    public static let detailView = "detail_view"
    /// The comments page's list.
    public static let commentsView = "comments_view"

    /// The comments page row of the comment with the site's comment ID `id`.
    public static func commentCell(id: String) -> String {
        "comment_cell_" + id
    }

    public static let commentCardPrefix = "comment_card_"
    /// The detail page's card of the comment with the site's comment ID `id`.
    public static func commentCard(id: String) -> String {
        commentCardPrefix + id
    }

    /// The collapsed row that stands in for a blocked member's comment on the comments page.
    public static func blockedComment(id: String) -> String {
        "blocked_comment_" + id
    }

    /// The collapsed card that stands in for a blocked member's comment on the detail page.
    public static func blockedCommentCard(id: String) -> String {
        "blocked_comment_card_" + id
    }

    // MARK: Report form

    /// The Report form's list.
    public static let reportForm = "report_form"
    /// The spinner shown while the site's report form loads.
    public static let reportLoading = "report_loading"
    /// The notice shown when the site offers no report form.
    public static let reportUnavailable = "report_unavailable"
    /// The warning the illegal-content reason shows.
    public static let reportIllegalWarning = "report_illegal_warning"
    /// The contact email field.
    public static let reportEmail = "report_email"
    /// The note under the email field when the address is not valid.
    public static let reportEmailInvalid = "report_email_invalid"
    /// The details field.
    public static let reportDetails = "report_details"
    /// The confirmation shown once the site took the report.
    public static let reportSent = "report_sent"
    /// The form's Send or Done button.
    public static let reportPrimaryButton = "report_primary_button"

    /// The row of the report reason the site names `type`, such as `child` or `other`.
    public static func reportReason(type: String) -> String {
        "report_reason_" + type
    }

    // MARK: Reader

    /// The reader's root view.
    public static let readingView = "reading_view"
    /// The reader's pages, as the one adjustable element VoiceOver turns them with.
    public static let readingPages = "reading_pages"
    /// The reader toolbar's page number, which tells the page shown.
    public static let readingPageIndicator = "reading_page_indicator"
    /// The reader's lower control panel.
    public static let readingLowerPanel = "reading_lower_panel"
    /// The row that holds the page slider.
    public static let readingSliderRow = "reading_slider_row"
    /// The page previews shown above the slider while it is dragged.
    public static let readingSliderPreview = "reading_slider_preview"
    /// The control that moves the reader's controls to the other side.
    public static let readingMoveControls = "reading_move_controls"

    // MARK: Home

    /// Home's sections when Home fills the screen.
    public static let homeSections = "home_sections"
    /// Home's left pane when Home is split in two.
    public static let homeLeftPane = "home_left_pane"
    /// Home's right pane when Home is split in two.
    public static let homeRightPane = "home_right_pane"
    /// The Popular carousel.
    public static let homeCarousel = "home_carousel"

    public static let homeSlideshowCoverPrefix = "home_slideshow_cover_"
    /// The cover of the gallery `id` in the Popular carousel.
    public static func homeSlideshowCover(id: String) -> String {
        homeSlideshowCoverPrefix + id
    }

    public static let homeSlideshowTitlePrefix = "home_slideshow_title_"
    /// The title of the gallery `id` in the Popular carousel.
    public static func homeSlideshowTitle(id: String) -> String {
        homeSlideshowTitlePrefix + id
    }

    public static let homeFrontPageTitlePrefix = "home_front_page_title_"
    /// The title of the gallery `id` in Home's Front Page section.
    public static func homeFrontPageTitle(id: String) -> String {
        homeFrontPageTitlePrefix + id
    }

    public static let homeRankingCoverPrefix = "home_ranking_cover_"
    /// The cover of the gallery `id` in Home's Toplists section.
    public static func homeRankingCover(id: String) -> String {
        homeRankingCoverPrefix + id
    }

    public static let homeRankingTitlePrefix = "home_ranking_title_"
    /// The title of the gallery `id` in Home's Toplists section.
    public static func homeRankingTitle(id: String) -> String {
        homeRankingTitlePrefix + id
    }

    // MARK: Gallery lists

    /// The layout picker of the list `scope` names, such as `favorites`, `downloads` or `frontpage`.
    public static func galleryLayout(scope: String) -> String {
        "gallery-layout-" + scope
    }

    public static let galleryListItemPrefix = "gallery-list-item-"
    /// The row of the gallery `id` in a list.
    public static func galleryListItem(id: String) -> String {
        galleryListItemPrefix + id
    }

    public static let galleryGridCoverPrefix = "gallery-grid-cover-"
    /// The cover of the gallery `id` in a grid.
    public static func galleryGridCover(id: String) -> String {
        galleryGridCoverPrefix + id
    }

    /// The title of the gallery `id` in a grid.
    public static func galleryGridTitle(id: String) -> String {
        "gallery-grid-title-" + id
    }

    public static let galleryGridRatingPrefix = "gallery-grid-rating-"
    /// The rating of the gallery `id` in a grid.
    public static func galleryGridRating(id: String) -> String {
        galleryGridRatingPrefix + id
    }

    // MARK: Library

    /// The Library title menu that switches between Favorites and Downloads.
    public static let libraryTitleMenu = "library-title-menu"
    /// The sidebar's list of download folders and Favorites categories.
    public static let libraryCategories = "library-categories"

    public static let libraryFavoritesPrefix = "library-favorites-"
    /// The sidebar row of the Favorites category `index`, where `-1` is all of them.
    public static func libraryFavorites(index: Int) -> String {
        libraryFavoritesPrefix + String(index)
    }

    /// The sidebar row of the download folder named `folder`.
    public static func libraryDownloads(folder: String) -> String {
        "library-downloads-" + folder
    }

    /// The Favorites gallery list.
    public static let favoritesGalleryList = "favorites-gallery-list"
    /// The Downloads gallery list.
    public static let downloadsGalleryList = "downloads-gallery-list"

    /// The Downloads card of the gallery `gid`.
    public static func downloadGallery(gid: String) -> String {
        "download-gallery-" + gid
    }

    // MARK: Search

    /// The button that clears every recent keyword.
    public static let searchRemoveAllKeywords = "search-remove-all-keywords"
    /// The button that clears every recently searched gallery.
    public static let searchRemoveAllGalleries = "search-remove-all-galleries"

    // MARK: First launch

    /// The age wall page.
    public static let firstLaunchAgeWall = "first_launch_age_wall"
    /// The age wall's title.
    public static let firstLaunchAgeWallTitle = "first_launch_age_wall_title"
    /// The age wall's declaration the user confirms.
    public static let firstLaunchDeclaration = "first_launch_declaration"
    /// The analytics choice page.
    public static let firstLaunchAnalyticsChoice = "first_launch_analytics_choice"
    /// The analytics choice page's title.
    public static let firstLaunchAnalyticsTitle = "first_launch_analytics_title"
    /// The analytics choice page's introduction.
    public static let firstLaunchAnalyticsIntro = "first_launch_analytics_intro"
    /// The analytics choice page's privacy policy link.
    public static let firstLaunchPrivacyLink = "first_launch_privacy_link"
    /// Either page's Continue button.
    public static let firstLaunchContinue = "first_launch_continue"

    /// The analytics choice page's option for the level `level` names, such as `minimal`, `basic` or `full`.
    public static func firstLaunchLevel(_ level: String) -> String {
        "first_launch_level_" + level
    }

    // MARK: Settings

    /// The analytics level picker.
    public static let settingAnalyticsLevel = "setting_analytics_level"
    /// The privacy policy row.
    public static let settingPrivacyPolicy = "setting_privacy_policy"
    /// The Blocked Users row.
    public static let settingBlockedUsers = "setting_blocked_users"

    // MARK: Shared surfaces

    /// The toast that reports a result, such as an unsupported link.
    public static let toastMessage = "toast_message"
    /// The full-page error view.
    public static let errorInfoView = "error_info_view"
    /// The web view that opens a site page in the signed-in session, such as the site's own report page.
    public static let sessionWebView = "session_web_view"
    /// The capture builds' diagnostics element, whose value is the capture record as JSON.
    public static let captureDiagnostics = "capture_diagnostics"
}
