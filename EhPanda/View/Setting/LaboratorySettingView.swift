//
//  LaboratorySettingView.swift
//  LabSettingView
//
//  Created by 荒木辰造 on R 3/07/16.
//

import SwiftUI

struct LaboratorySettingView: View, StoreAccessor {
    @EnvironmentObject var store: Store

    private var settingBinding: Binding<Setting> {
        $store.appState.settings.setting
    }

    var body: some View {
        ScrollView {
            VStack {
                LaboratoryCell(
                    isOn: settingBinding.bypassesSNIFiltering,
                    title: "Bypass SNI Filtering",
                    symbol: "theatermasks.fill",
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
    private let title: String
    private let symbol: String
    private let tintColor: Color

    init(
        isOn: Binding<Bool>, title: String,
        symbol: String, tintColor: Color
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
            Spacer()
            Group {
                Image(systemName: symbol)
                Text(title.localized).fontWeight(.bold)
            }
            .foregroundColor(contentColor).font(.title2)
            Spacer()
        }
        .contentShape(Rectangle()).onTapGesture {
            withAnimation { isOn.toggle() }
            HapticUtil.generateFeedback(style: .soft)
        }
        .minimumScaleFactor(0.75).padding(.vertical, 20)
        .background(bgColor).cornerRadius(15).lineLimit(1)
    }
}
