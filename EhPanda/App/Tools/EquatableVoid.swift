//
//  EquatableVoid.swift
//  EhPanda
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
