/// The accessibility identifiers that the app's views carry and the UI tests find them by.
///
/// Both sides read them from here, so the app and `EhPandaUITests` cannot drift apart: renaming one is a single edit
/// that both compile against, and a misspelling fails the build instead of a test run. That is why this is a module
/// of its own with no dependencies: the UI-test target links it without linking any of the app's code.
///
/// An identifier is locale-independent and never changes what VoiceOver reads; it exists only to be found.
public enum AccessibilityIdentifiers {
    /// The gallery detail page's scroll view.
    public static let detailView = "detail_view"
    /// The reader's root view.
    public static let readingView = "reading_view"
    /// The reader toolbar's page number, which tells the page shown.
    public static let readingPageIndicator = "reading_page_indicator"
    /// The comments page's list.
    public static let commentsView = "comments_view"
    /// The toast that reports a result, such as an unsupported link.
    public static let toastMessage = "toast_message"
    /// The full-page error view.
    public static let errorInfoView = "error_info_view"

    /// The comments page row of the comment with the site's comment ID `id`.
    public static func commentCell(id: String) -> String {
        "comment_cell_" + id
    }
}
