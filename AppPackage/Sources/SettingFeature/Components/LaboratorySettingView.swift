import AppComponents
import AppModels
import ComposableArchitecture
import Resources
import SFSafeSymbols
import Sharing
import SwiftUI

struct LaboratorySettingView: View {
    private let store: StoreOf<LaboratorySettingReducer>
    @Shared(.setting) private var setting: Setting

    init(store: StoreOf<LaboratorySettingReducer>) {
        self.store = store
    }

    var body: some View {
        ScrollView {
            VStack {
                LaboratoryCell(
                    isOn: Binding($setting.bypassSNIFiltering),
                    title: .bypassSniFiltering,
                    symbol: .theatermasksFill, tintColor: .purple
                )
            }
            .padding()
        }
        .navigationTitle(.laboratory)
        .onChange(of: setting.bypassSNIFiltering) { _, newValue in
            store.send(.bypassSNIFilteringChanged(newValue))
        }
    }
}

struct LaboratoryCell: View {
    @Binding private var isOn: Bool
    private let title: LocalizedStringResource
    private let symbol: SFSymbol
    private let tintColor: Color

    init(
        isOn: Binding<Bool>, title: LocalizedStringResource,
        symbol: SFSymbol, tintColor: Color
    ) {
        _isOn = isOn
        self.title = title
        self.symbol = symbol
        self.tintColor = tintColor
    }

    private var bgColor: Color {
        isOn ? tintColor.opacity(0.2) : Color(.systemGray5)
    }
    private var contentColor: Color {
        isOn ? tintColor : .secondary
    }

    var body: some View {
        Label {
            Text(title)
                .bold()
        } icon: {
            Image(systemSymbol: symbol)
        }
        .foregroundStyle(contentColor)
        .font(.title2)
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .onTapGesture(perform: { isOn.toggle() })
        .padding(.vertical, 20)
        .background(bgColor)
        .clipShape(.rect(cornerRadius: 15))
        .animation(.default, value: isOn)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 15))
    }
}

#Preview("Initial") {
    NavigationStack {
        LaboratorySettingView(
            store: .init(initialState: .init(), reducer: LaboratorySettingReducer.init)
        )
    }
}
