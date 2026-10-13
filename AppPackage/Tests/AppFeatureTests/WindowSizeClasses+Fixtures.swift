@testable import AppFeature

extension WindowSizeClasses {
    /// Regular in both dimensions, as an iPad's full-screen window is.
    static let regular = Self(horizontal: .regular, vertical: .regular)
    /// Compact in width, as an iPhone in portrait, a folded iPhone Duo or a narrow iPad window is.
    static let compactWidth = Self(horizontal: .compact, vertical: .regular)
    /// Compact in height only, as a large iPhone in landscape is.
    static let compactHeight = Self(horizontal: .regular, vertical: .compact)
}
