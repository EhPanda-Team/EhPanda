//
//  SettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/27.
//

import SwiftUI
import SFSafeSymbols
import ComposableArchitecture

struct SettingView: View {
    private let store: Store<SettingState, SettingAction>
    private let sharedDataStore: Store<SharedData, SharedDataAction>
    @ObservedObject private var viewStore: ViewStore<SettingState, SettingAction>
    @ObservedObject private var coreViewStore: ViewStore<CoreSettingState, CoreSettingAction>

    init(store: Store<SettingState, SettingAction>, sharedDataStore: Store<SharedData, SharedDataAction>) {
        self.store = store
        self.sharedDataStore = sharedDataStore
        viewStore = ViewStore(store)
        coreViewStore = ViewStore(store.scope(state: \.coreSettingState, action: SettingAction.core))
    }

    // MARK: SettingView
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(SettingRowType.allCases) { type in
                        SettingRow(rowType: type) {
                            coreViewStore.send(.setRoute($0))
                        }
                    }
                }
                .padding(.vertical, 40).padding(.horizontal)
            }
            .background(
                ForEach(SettingRowType.allCases) { type in
                    NavigationLink("", tag: type, selection: coreViewStore.binding(\.$route), destination: {
                        switch type {
                        case .account:
                            AccountSettingView(
                                store: store.scope(state: \.accountSettingState, action: SettingAction.account),
                                sharedDataStore: sharedDataStore
                            )
                        case .general:
                            GeneralSettingView()
                        case .appearance:
                            AppearanceSettingView()
                        case .reading:
                            ReadingSettingView()
                        case .laboratory:
                            LaboratorySettingView()
                        case .ehpanda:
                            EhPandaView()
                        }
                    })
                }
            )
            .navigationBarTitle("Setting")
        }
    }
}

// MARK: SettingRow
private struct SettingRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressing = false

    private let rowType: SettingRowType
    private let tapAction: (SettingRowType) -> Void

    private var color: Color {
        colorScheme == .light ? Color(.darkGray) : Color(.lightGray)
    }
    private var backgroundColor: Color {
        isPressing ? color.opacity(0.1) : .clear
    }

    init(rowType: SettingRowType, tapAction: @escaping (SettingRowType) -> Void) {
        self.rowType = rowType
        self.tapAction = tapAction
    }

    var body: some View {
        HStack {
            Image(systemSymbol: rowType.symbol)
                .font(.largeTitle).foregroundColor(color)
                .padding(.trailing, 20).frame(width: 45)
            Text(rowType.rawValue.localized).fontWeight(.medium)
                .font(.title3).foregroundColor(color)
            Spacer()
        }
        .contentShape(Rectangle()).padding(.vertical, 10)
        .padding(.horizontal, 20).background(backgroundColor)
        .cornerRadius(10).onTapGesture { tapAction(rowType) }
        .onLongPressGesture(
            minimumDuration: .infinity, maximumDistance: 50,
            pressing: { isPressing = $0 }, perform: {}
        )
    }
}

// MARK: Definition

enum SettingRowType: String, Hashable, Identifiable, CaseIterable {
    var id: String { rawValue }

    case account = "Account"
    case general = "General"
    case appearance = "Appearance"
    case reading = "Reading"
    case laboratory = "Laboratory"
    case ehpanda = "About EhPanda"
}
extension SettingRowType {
    var symbol: SFSymbol {
        switch self {
        case .account:
            return .personFill
        case .general:
            return .switch2
        case .appearance:
            return .circleRighthalfFilled
        case .reading:
            return .newspaperFill
        case .laboratory:
            return .testtube2
        case .ehpanda:
            return .pCircleFill
        }
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView(
            store: Store<SettingState, SettingAction>(
                initialState: SettingState(), reducer: settingReducer, environment: AnyEnvironment()
            ),
            sharedDataStore: Store<SharedData, SharedDataAction>(
                initialState: SharedData(), reducer: sharedDataReducer, environment: AnyEnvironment()
            )
        )
    }
}
