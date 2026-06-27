import SwiftUI

public struct InSheetKey: EnvironmentKey, Sendable {
    public static let defaultValue = false
}

extension EnvironmentValues {
    public var inSheet: Bool {
        get { self[InSheetKey.self] }
        set { self[InSheetKey.self] = newValue }
    }
}
