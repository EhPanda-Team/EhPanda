import SwiftUI
import CasePaths

extension Binding {
    public func `case`<Enum: Sendable, Case: Sendable>(
        _ caseKeyPath: CaseKeyPath<Enum, Case>
    ) -> Binding<Case?> where Value == Enum? {
        let casePath = AnyCasePath(caseKeyPath)
        return .init(
            get: { self.wrappedValue.flatMap(casePath.extract(from:)) },
            set: { newValue, transaction in
                self.transaction(transaction).wrappedValue = newValue.map(casePath.embed)
            }
        )
    }

    public func isRemovedDuplicatesPresent<Wrapped: Sendable>() -> Binding<Bool> where Value == Wrapped? {
        .init(
            get: { wrappedValue != nil },
            set: { isPresent, transaction in
                guard self.transaction(transaction).wrappedValue != nil else { return }
                if !isPresent {
                    self.transaction(transaction).wrappedValue = nil
                }
            }
        )
    }
}
