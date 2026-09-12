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

    /// The cell reads its state to sighted users through tint (on) versus gray (off) and through the
    /// on/off glyph that leads the title; assistive technologies get the same state as a system
    /// `Toggle` carrying the cell's own title, so the label, the on/off value, the toggle trait and
    /// the Voice Control name all come from one representation while the tinted rendering and its
    /// animated colour change stay untouched.
    var body: some View {
        HStack {
            // The glyph is the state's non-colour carrier (Phase 16 criterion 11): desaturated, the
            // tinted and the gray cell measured within 1.1:1 of each other, so a filled versus an
            // empty circle says on/off where the colour alone cannot. It takes the cell's own text
            // size, so the row keeps its height. It is hidden from assistive technologies because the
            // `Toggle` representation below already carries the state as a value; the marker stays
            // decorative even if that representation is ever removed.
            Image(systemSymbol: isOn ? .checkmarkCircleFill : .circle)
                .accessibilityHidden(true)
            Label {
                Text(title)
                    .bold()
            } icon: {
                Image(systemSymbol: symbol)
            }
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
        .accessibilityRepresentation {
            Toggle(isOn: $isOn) {
                Text(title)
            }
        }
    }
}

#Preview("Initial") {
    NavigationStack {
        LaboratorySettingView(
            store: .init(initialState: .init(), reducer: LaboratorySettingReducer.init)
        )
    }
}
