import SwiftUI
import SFSafeSymbols

public extension Label where Title == Text, Icon == Image {
    /// Builds a `Label` from a `LocalizedStringResource` title and an `SFSymbol` icon,
    /// composing `Text` and `Image(systemSymbol:)` directly so no system-name string
    /// parameter is needed. This is the initializer the `label_text_image_shorthand`
    /// lint rule expects call sites to use.
    nonisolated init(_ titleResource: LocalizedStringResource, systemSymbol: SFSymbol) {
        self.init {
            Text(titleResource)
        } icon: {
            Image(systemSymbol: systemSymbol)
        }
    }
}
