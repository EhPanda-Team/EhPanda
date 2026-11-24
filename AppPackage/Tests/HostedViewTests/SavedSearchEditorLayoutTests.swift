import AppModels
@testable import QuickSearchFeature
import SwiftUI
import Testing
import UIKit

/// The saved-search editor's Search Terms field shows its whole text at every text size.
///
/// The field was a `TextEditor`, which a `Form` gives a fixed height of its own: a query of three lines or more was
/// cut off at the bottom of its row and had to be scrolled inside the field (the owner's C1 item, 19-13). The field
/// is now a vertical-axis `TextField`, which sizes itself to its text like the Report form's details field.
@MainActor
struct SavedSearchEditorLayoutTests {
    /// Long enough for three lines at the default size on a 390 pt wide page, and for many more at the largest.
    private static let query = """
    language:english category:doujinshi artist:"example artist" parody:"example series" \
    female:"long hair" female:glasses female:schoolgirl_uniform other:full_color
    """

    @Test(arguments: [DynamicTypeSize.large, .accessibility5])
    func searchTermsFieldIsNeverShorterThanItsText(size: DynamicTypeSize) throws {
        let page = NavigationStack {
            SearchTermsEditorHost(savedSearch: SavedSearch(name: "Reading list", content: Self.query))
        }
        .environment(\.dynamicTypeSize, size)
        .environment(\.locale, Locale(identifier: "en_US"))
        try HostedView.withRoot(of: page, size: CGSize(width: 390, height: 844)) { root in
            let textView = try #require(Self.textViews(in: root).first(where: { $0.text == Self.query }))
            let needed = textView.sizeThatFits(
                CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)
            ).height
            #expect(
                textView.bounds.height + 0.5 >= needed,
                "The Search Terms text view is \(textView.bounds.height) pt tall but its text needs \(needed) pt."
            )
        }
    }

    private static func textViews(in view: UIView) -> [UITextView] {
        ((view as? UITextView).map({ [$0] }) ?? []) + view.subviews.flatMap(textViews(in:))
    }
}

/// Owns the focus state the editor takes; the saved search is constant, as the editor only reads it here.
private struct SearchTermsEditorHost: View {
    let savedSearch: SavedSearch
    @FocusState private var focusedField: QuickSearchReducer.FocusField?

    var body: some View {
        QuickSearchView.EditSavedSearchView(
            title: "Edit Saved Search",
            savedSearch: .constant(savedSearch),
            focusedField: $focusedField,
            submitAction: {},
            confirmAction: {}
        )
    }
}
