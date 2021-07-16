//
//  DFManager.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/13.
//

import Foundation

class DFManager {
    enum DFState {
        case activated
        case notActivated
    }

    static var shared = DFManager()
    static var session: URLSession {
        shared.dfState == .activated
        ? shared.dfURLSession : .shared
    }

    var dfState: DFState = .notActivated
    let dfURLSession = URLSession(
        configuration: .domainFronting
    )
}
