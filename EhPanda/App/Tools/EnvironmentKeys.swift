//
//  EnvironmentKeys.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/21.
//

import SwiftUI

struct IsSheetKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isSheet: Bool {
        get { self[IsSheetKey.self] }
        set { self[IsSheetKey.self] = newValue }
    }
}
