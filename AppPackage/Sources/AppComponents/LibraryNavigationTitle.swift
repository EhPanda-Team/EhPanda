import Resources
public import SwiftUI

/// The Library source menu belongs to the navigation root, so pushed gallery pages keep their own titles.
public struct LibraryNavigationTitle: ViewModifier {
    private let title: String
    private let menu: LibraryTitleMenu?

    public init(title: String, menu: LibraryTitleMenu?) {
        self.title = title
        self.menu = menu
    }

    public func body(content: Content) -> some View {
        content
            .navigationTitle(menu == nil ? title : String(localized: .RLocalizable.library))
            .navigationSubtitle(menu.map({ String(localized: $0.sourceTitle) }) ?? "")
            .toolbarTitleDisplayMode(menu == nil ? .inlineLarge : .inline)
            .toolbarRole(menu == nil ? .automatic : .browser)
            .toolbarMinimizationBehavior(menu == nil ? .automatic : .never, for: .navigationBar)
            .toolbar {
                if let menu {
                    ToolbarItem(placement: .title) {
                        menu.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
    }
}
