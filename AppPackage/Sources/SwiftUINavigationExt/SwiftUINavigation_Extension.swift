import SwiftUI
import SwiftUINavigation

extension NavigationLink {
    public init<S: StringProtocol, Value, WrappedDestination>(
        _ title: S,
        unwrapping value: Binding<Value?>,
        @ViewBuilder destination: @escaping (Binding<Value>) -> WrappedDestination
    ) where Destination == WrappedDestination?, Label == Text {
        self.init(
            title,
            destination: Binding(unwrapping: value).map(destination),
            isActive: .init(value)
        )
    }
    public init<Enum: Sendable, Case: Sendable, WrappedDestination>(
        unwrapping enum: Binding<Enum?>,
        case caseKeyPath: CaseKeyPath<Enum, Case>,
        @ViewBuilder destination: @escaping (Binding<Case>) -> WrappedDestination
    ) where Destination == WrappedDestination?, Label == Text {
        self.init(
            "", unwrapping: `enum`.case(caseKeyPath),
            destination: destination
        )
    }
}

extension View {
    public func confirmationDialog<Enum: Sendable, Case: Sendable, A: View>(
        message: String,
        unwrapping enum: Binding<Enum?>,
        case caseKeyPath: CaseKeyPath<Enum, Case>,
        @ViewBuilder actions: @escaping (Case) -> A
    ) -> some View {
        self.confirmationDialog(
            item: `enum`.case(caseKeyPath),
            titleVisibility: .hidden,
            title: { _ in Text("") },
            actions: actions,
            message: { _ in Text(message) }
        )
    }
    public func confirmationDialog<Enum: Sendable, Case: Equatable & Sendable, A: View>(
        message: String,
        unwrapping enum: Binding<Enum?>,
        case caseKeyPath: CaseKeyPath<Enum, Case>,
        matching case: Case,
        @ViewBuilder actions: @escaping (Case) -> A
    ) -> some View {
        self.confirmationDialog(
            item: {
                let unwrapping = `enum`.case(caseKeyPath)
                let isMatched = `case` == unwrapping.wrappedValue
                return isMatched ? unwrapping : .constant(nil)
            }(),
            titleVisibility: .hidden,
            title: { _ in Text("") },
            actions: actions,
            message: { _ in Text(message) }
        )
    }

    public func sheet<Enum: Sendable, Case: Sendable, Content: View>(
        unwrapping enum: Binding<Enum?>,
        case caseKeyPath: CaseKeyPath<Enum, Case>,
        @ViewBuilder content: @escaping (Case) -> Content
    ) -> some View {
        self.sheet(
            isPresented: .constant(`enum`.case(caseKeyPath).wrappedValue != nil),
            content: { `enum`.case(caseKeyPath).wrappedValue.map(content) }
        )
    }
}

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
