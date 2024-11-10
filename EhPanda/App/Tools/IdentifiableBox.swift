//
//  IdentifiableBox.swift
//  EhPanda
//
//  Created by Chihchy on 2024/10/27.
//

import Foundation

public struct IdentifiableBox<Value>: Identifiable {
    public let id = UUID()
    public let wrappedValue: Value

    public init(value: Value) {
        self.wrappedValue = value
    }
}

extension IdentifiableBox: Hashable where Value: Hashable {}
extension IdentifiableBox: Sendable where Value: Sendable {}
extension IdentifiableBox: Equatable where Value: Equatable {}
