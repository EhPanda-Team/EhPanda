//
//  ReadingSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI

struct ReadingSettingView: View, StoreAccessor {
    @EnvironmentObject var store: Store

    private var settingBinding: Binding<Setting>? {
        Binding($store.appState.settings.setting)
    }

    var body: some View {
        if let setting = setting,
           let settingBinding = settingBinding
        {
            Form {
                Section {
                    HStack {
                        let time = " times".localized()
                        Text("Retry limit")
                        Spacer()
                        Picker(
                            selection: settingBinding.contentRetryLimit,
                            label: Text("\(setting.contentRetryLimit)" + time),
                            content: {
                                Text("5" + time).tag(5)
                                Text("10" + time).tag(10)
                                Text("15" + time).tag(15)
                                Text("20" + time).tag(20)
                            }
                        )
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                Section(header: Text("Appearance")) {
                    HStack {
                        Text("Separator height")
                        Spacer()
                        Picker(
                            selection: settingBinding.contentDividerHeight,
                            label: Text("\(Int(setting.contentDividerHeight))pt"),
                            content: {
                                Text("0pt").tag(CGFloat(0))
                                Text("5pt").tag(CGFloat(5))
                                Text("10pt").tag(CGFloat(10))
                                Text("15pt").tag(CGFloat(15))
                                Text("20pt").tag(CGFloat(20))
                            }
                        )
                        .pickerStyle(MenuPickerStyle())
                    }
                    ScaleFactorRow(
                        scaleFactor: settingBinding.maximumScaleFactor,
                        labelContent: "Maximum scale factor",
                        minFactor: 1.5,
                        maxFactor: 10
                    )
                    ScaleFactorRow(
                        scaleFactor: settingBinding.doubleTapScaleFactor,
                        labelContent: "Double tap scale factor",
                        minFactor: 1.5,
                        maxFactor: 5
                    )
                }
            }
            .navigationBarTitle("Reading")
        }
    }
}

private struct ScaleFactorRow: View {
    @Binding private var scaleFactor: CGFloat
    private let labelContent: String
    private let minFactor: CGFloat
    private let maxFactor: CGFloat

    init(
        scaleFactor: Binding<CGFloat>,
        labelContent: String,
        minFactor: CGFloat,
        maxFactor: CGFloat
    ) {
        _scaleFactor = scaleFactor
        self.labelContent = labelContent
        self.minFactor = minFactor
        self.maxFactor = maxFactor
    }

    var body: some View {
        VStack {
            HStack {
                Text(labelContent.localized())
                Spacer()
                Text(scaleFactor.roundedString() + "x")
                    .foregroundStyle(.tint)
            }
            Slider(
                value: $scaleFactor,
                in: minFactor...maxFactor,
                step: 0.5,
                minimumValueLabel:
                    Text(minFactor.roundedString() + "x")
                    .fontWeight(.medium)
                    .font(.callout),
                maximumValueLabel:
                    Text(maxFactor.roundedString() + "x")
                    .fontWeight(.medium)
                    .font(.callout),
                label: EmptyView.init
            )
        }
        .padding(.vertical, 10)
    }
}

struct ReadingSettingView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store()
        store.appState.settings.setting = Setting()
        store.appState.environment.isPreview = true

        return ReadingSettingView()
            .environmentObject(store)
            .preferredColorScheme(.dark)
    }
}
