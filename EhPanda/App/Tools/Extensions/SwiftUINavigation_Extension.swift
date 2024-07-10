//
//  SwiftUINavigation_Extension.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/13.
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
        case casePath: AnyCasePath<Enum, Case>,
        @ViewBuilder destination: @escaping (Binding<Case>) -> WrappedDestination
    ) where Destination == WrappedDestination?, Label == Text {
        self.init(
            "", unwrapping: `enum`.case(casePath),
            destination: destination
        )
    }
}

extension View {
    func confirmationDialog<Enum, Case, A: View>(
        message: String,
        unwrapping enum: Binding<Enum?>,
        case casePath: AnyCasePath<Enum, Case>,
        @ViewBuilder actions: @escaping (Case) -> A
    ) -> some View {
        self.confirmationDialog(
            item: `enum`.case(casePath),
            titleVisibility: .hidden,
            title: { _ in Text("") },
            actions: actions,
            message: { _ in Text(message) }
        )
    }
    func confirmationDialog<Enum, Case: Equatable, A: View>(
        message: String,
        unwrapping enum: Binding<Enum?>,
        case casePath: AnyCasePath<Enum, Case>,
        matching case: Case,
        @ViewBuilder actions: @escaping (Case) -> A
    ) -> some View {
        self.confirmationDialog(
            item: {
                let unwrapping = `enum`.case(casePath)
                let isMatched = `case` == unwrapping.wrappedValue
                return isMatched ? unwrapping : .constant(nil)
            }(),
            titleVisibility: .hidden,
            title: { _ in Text("") },
            actions: actions,
            message: { _ in Text(message) }
        )
    }

    func progressHUD<Enum: Equatable, Case>(
        config: TTProgressHUDConfig,
        unwrapping enum: Binding<Enum?>,
        case casePath: AnyCasePath<Enum, Case>
    ) -> some View {
        ZStack {
            self
            TTProgressHUD(
                `enum`.case(casePath).isRemovedDuplicatesPresent(),
                config: config
            )
        }
    }
}

extension Binding {
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
