import SwiftUI

/// Temporary workaround for iOS 26.5 automatic search drawers losing their visible contents.
/// Apply only to searchable screens with a recorded failure. At accessibility sizes an always
/// visible native drawer avoids the undersized layout; other sizes retain automatic visibility.
///
/// Reproduction: reveal search at the default text size, then change to AX5. The automatic drawer
/// can lose its magnifier and prompt or query. A standalone native SwiftUI reproduction confirmed
/// that `.navigationBarDrawer(displayMode: .always)` avoids that failing layout path.
///
/// Remove this modifier and restore ordinary `.searchable` call sites once the affected screens
/// work without it on supported OS versions, including cold entry, live AX1–AX5 size changes,
/// search focus, and portrait/landscape. Do not retain this as a permanent search design choice.
private struct AccessibilitySearchableWorkaround: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var text: String
    let prompt: LocalizedStringResource?

    func body(content: Content) -> some View {
        content.searchable(
            text: $text,
            placement: .navigationBarDrawer(displayMode: dynamicTypeSize.isAccessibilitySize ? .always : .automatic),
            prompt: prompt.map(Text.init)
        )
    }
}

extension View {
    /// Uses a temporarily always-visible search drawer at accessibility sizes on affected screens.
    public func accessibilitySearchableWorkaround(
        text: Binding<String>, prompt: LocalizedStringResource? = nil
    ) -> some View {
        modifier(AccessibilitySearchableWorkaround(text: text, prompt: prompt))
    }
}
