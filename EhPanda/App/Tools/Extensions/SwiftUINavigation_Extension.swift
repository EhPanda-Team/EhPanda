//
//  SwiftUINavigation_Extension.swift
//  EhPanda
//

import SwiftUI
import TTProgressHUD
import SwiftUINavigation

extension NavigationLink {
    init<S: StringProtocol, Value, WrappedDestination>(
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
    init<Enum, Case, WrappedDestination>(
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
    func confirmationDialog<Enum, Case, A: View>(
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
    func confirmationDialog<Enum, Case: Equatable, A: View>(
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

    func sheet<Enum, Case, Content: View>(
        unwrapping enum: Binding<Enum?>,
        case caseKeyPath: CaseKeyPath<Enum, Case>,
        @ViewBuilder content: @escaping (Case) -> Content
    ) -> some View {
        self.sheet(
            isPresented: .constant(`enum`.case(caseKeyPath).wrappedValue != nil),
            content: { `enum`.case(caseKeyPath).wrappedValue.map(content) }
        )
    }

    func progressHUD<Enum: Equatable, Case>(
        config: TTProgressHUDConfig,
        unwrapping enum: Binding<Enum?>,
        case caseKeyPath: CaseKeyPath<Enum, Case>
    ) -> some View {
        ZStack {
            self
            TTProgressHUD(
                `enum`.case(caseKeyPath).isRemovedDuplicatesPresent(),
                config: config
            )
        }
    }
}

extension Binding {
    func `case`<Enum: Sendable, Case>(_ caseKeyPath: CaseKeyPath<Enum, Case>) -> Binding<Case?> where Value == Enum? {
        .init(
            get: { self.wrappedValue.flatMap(AnyCasePath(caseKeyPath).extract(from:)) },
            set: { newValue, transaction in
                self.transaction(transaction).wrappedValue = newValue.map(AnyCasePath(caseKeyPath).embed)
            }
        )
    }

    func isRemovedDuplicatesPresent<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
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
