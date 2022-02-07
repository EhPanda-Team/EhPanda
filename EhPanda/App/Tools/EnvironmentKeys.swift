//
//  EnvironmentKeys.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/21.
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
