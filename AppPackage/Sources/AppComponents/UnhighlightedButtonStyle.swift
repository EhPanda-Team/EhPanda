import SwiftUI

/// A button style that draws its label exactly as given and adds nothing on press.
///
/// For a control whose designed look was a plain tappable view: making it a real `Button` gives it
/// the button role, its label and Voice Control name, which a tap gesture never had, but every
/// built-in style changes how it looks — `.plain` dims the label while pressed, and the automatic
/// style tints it and highlights the list row. The owner kept those rows' designed look
/// (2026-09-15), so the semantics come from `Button` and the rendering stays the label alone.
public struct UnhighlightedButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

extension ButtonStyle where Self == UnhighlightedButtonStyle {
    /// See `UnhighlightedButtonStyle`.
    public static var unhighlighted: UnhighlightedButtonStyle { .init() }
}
