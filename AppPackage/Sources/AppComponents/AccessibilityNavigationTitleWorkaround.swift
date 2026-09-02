import SwiftUI

/// Temporary workaround for iOS 26.5 navigation titles disappearing at accessibility sizes.
/// Apply only to automatic-title screens with a recorded navigation-bar rendering failure;
/// `.inlineLarge` screens must be measured separately and do not inherit this policy.
///
/// Reproduction: expand a large title at the default text size, then change to AX5. Toplists
/// loses its title while retaining the title band's space. Inline mode avoids this failure.
/// Archives also has a recorded iPad failure where the large title overlaps scrolled cards.
/// Keep the same view identity when the size changes so navigation and scroll state survive.
///
/// Remove this modifier and its call sites once the affected screens render correctly without it
/// on the supported OS versions, including cold entry and live size changes at AX1 through AX5.
private struct AccessibilityNavigationTitleWorkaround: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content.toolbarTitleDisplayMode(dynamicTypeSize.isAccessibilitySize ? .inline : .automatic)
    }
}

extension View {
    /// Temporarily protects an affected automatic navigation title at accessibility text sizes.
    public func accessibilityNavigationTitleWorkaround() -> some View {
        modifier(AccessibilityNavigationTitleWorkaround())
    }
}
