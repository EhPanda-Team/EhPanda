//
//  LaboratorySettingView.swift
//  LabSettingView
//
//  Created by 荒木辰造 on R 3/07/16.
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
                    title: "Bypass SNI Filtering",
                    symbol: .theatermasksFill,
                    tintColor: .purple
                )
            }
            .padding()
        }
        .navigationBarTitle("Laboratory")
    }
}

struct LaboratoryCell: View {
    @Binding private var isOn: Bool

    // workaround: `withAnimation` doesn't work with @BindableState
    @State private var bgColor: Color
    @State private var contentColor: Color

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

        bgColor = isOn.wrappedValue ? tintColor.opacity(0.2) : Color(.systemGray5)
        contentColor = isOn.wrappedValue ? tintColor : .secondary
    }

    var body: some View {
        HStack {
            Spacer()
            Group {
                Image(systemSymbol: symbol)
                Text(title.localized).bold()
            }
            .foregroundColor(contentColor).font(.title2)
            Spacer()
        }
        .contentShape(Rectangle()).onTapGesture { isOn.toggle() }
        .minimumScaleFactor(0.75).padding(.vertical, 20)
        .background(bgColor).cornerRadius(15).lineLimit(1)
        .onChange(of: isOn) { newValue in
            withAnimation {
                bgColor = newValue ? tintColor.opacity(0.2) : Color(.systemGray5)
                contentColor = newValue ? tintColor : .secondary
            }
        }
    }
}
