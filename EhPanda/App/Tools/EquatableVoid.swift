//
//  EquatableVoid.swift
//  EhPanda
//
//  Created by Chihchy on 2024/10/27.
//

import Foundation

public struct EquatableVoid: Hashable, Sendable, Identifiable {
    public let id: UUID

    public init(id: UUID = .init()) {
        self.id = id
    }
}

private let uniqueID = UUID()

public extension EquatableVoid {
    static let unique = Self(id: uniqueID)
}
