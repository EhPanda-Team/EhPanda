//
//  EnvironmentKeys.swift
//  EhPanda
//

import SwiftUI

struct InSheetKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var inSheet: Bool {
        get { self[InSheetKey.self] }
        set { self[InSheetKey.self] = newValue }
    }
}
