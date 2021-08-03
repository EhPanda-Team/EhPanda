//
//  ReadingSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI

struct ReadingSettingView: View, StoreAccessor {
    @EnvironmentObject var store: Store

    private var settingBinding: Binding<Setting> {
        $store.appState.settings.setting
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Direction")
                    Spacer()
                    Picker(
                        selection: settingBinding.readingDirection,
                        label: Text(setting.readingDirection.rawValue),
                        content: {
                            ForEach(ReadingDirection.allCases) {
                                Text($0.rawValue.localized()).tag($0)
                            }
                        }
                    )
                    .pickerStyle(.menu)
                }
                HStack {
                    let time = " times".localized()
                    Text("Retry limit")
                    Spacer()
                    Picker(
                        selection: settingBinding.contentRetryLimit,
                        label: Text("\(setting.contentRetryLimit)" + time),
                        content: {
                            let values = Array(stride(from: 5, through: 20, by: 5))
                            ForEach(values, id: \.self) { value in
                                Text("\(value)" + time).tag(value)
                            }
                        }
                    )
                    .pickerStyle(.menu)
                }
                HStack {
                    let page = " pages".localized()
                    Text("Preload limit")
                    Spacer()
                    Picker(
                        selection: settingBinding.prefetchLimit,
                        label: Text("\(setting.prefetchLimit)" + page),
                        content: {
                            let values = Array(stride(from: 6, through: 18, by: 4))
                            ForEach(values, id: \.self) { value in
                                Text("\(value)" + page).tag(value)
                            }
                        }
                    )
                    .pickerStyle(.menu)
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
                            let values = Array(stride(from: 0, through: 20, by: 5))
                            ForEach(values, id: \.self) { value in
                                Text("\(value)" + "pt").tag(Double(value))
                            }
                        }
                    )
                    .pickerStyle(.menu)
                }
                .disabled(setting.readingDirection != .vertical)
                ScaleFactorRow(
                    scaleFactor: settingBinding.maximumScaleFactor,
                    labelContent: "Maximum scale factor",
                    minFactor: 1.5,
                    maxFactor: 10,
                    accentColor: setting.accentColor
                )
                ScaleFactorRow(
                    scaleFactor: settingBinding.doubleTapScaleFactor,
                    labelContent: "Double tap scale factor",
                    minFactor: 1.5,
                    maxFactor: 5,
                    accentColor: setting.accentColor
                )
            }
        }
        .navigationBarTitle("Reading")
    }
}

// MARK: ScaleFactorRow
private struct ScaleFactorRow: View {
    @Binding private var scaleFactor: Double
    private let labelContent: String
    private let minFactor: Double
    private let maxFactor: Double
    private let accentColor: Color // workaround

    init(
        scaleFactor: Binding<Double>,
        labelContent: String,
        minFactor: Double,
        maxFactor: Double,
        accentColor: Color
    ) {
        _scaleFactor = scaleFactor
        self.labelContent = labelContent
        self.minFactor = minFactor
        self.maxFactor = maxFactor
        self.accentColor = accentColor
    }

    var body: some View {
        VStack {
            HStack {
                Text(labelContent.localized())
                Spacer()
                Text(scaleFactor.roundedString() + "x")
                    .foregroundColor(accentColor)
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
