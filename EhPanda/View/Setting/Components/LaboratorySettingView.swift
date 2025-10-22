//
//  LaboratorySettingView.swift
//  LabSettingView
//

import SwiftUI
import SFSafeSymbols

struct LaboratorySettingView: View {
    @Binding private var bypassesSNIFiltering: Bool

    init(bypassesSNIFiltering: Binding<Bool>) {
        _bypassesSNIFiltering = bypassesSNIFiltering
    }

    var body: some View {
        ScrollView {
            VStack {
                LaboratoryCell(
                    isOn: $bypassesSNIFiltering,
                    title: L10n.Localizable.LaboratorySettingView.Title.bypassesSNIFiltering,
                    symbol: .theatermasksFill, tintColor: .purple
                )
            }
            .padding()
        }
        .navigationTitle(L10n.Localizable.LaboratorySettingView.Title.laboratory)
    }
}

struct LaboratoryCell: View {
    @Binding private var isOn: Bool
    private let title: String
    private let symbol: SFSymbol
    private let tintColor: Color

    init(
        isOn: Binding<Bool>, title: String,
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
        HStack {
            Image(systemSymbol: symbol)

            Text(title)
                .bold()
        }
        .foregroundStyle(contentColor)
        .font(.title2)
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .onTapGesture(perform: { isOn.toggle() })
        .minimumScaleFactor(0.75)
        .padding(.vertical, 20)
        .background(bgColor)
        .cornerRadius(15)
        .lineLimit(1)
        .animation(.default, value: isOn)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 15))
    }
}

struct LaboratorySettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LaboratorySettingView(
                bypassesSNIFiltering: .constant(false)
            )
        }
    }
}
