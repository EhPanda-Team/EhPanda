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
                            Text("5" + time).tag(5)
                            Text("10" + time).tag(10)
                            Text("15" + time).tag(15)
                            Text("20" + time).tag(20)
                        }
                    )
                    .pickerStyle(.menu)
                }
            }
            Section(header: Text("Appearance")) {
                HStack {
                    Text("Content spacing")
                    Spacer()
                    Picker(
                        selection: settingBinding.contentSpacing,
                        label: Text("\(Int(setting.contentSpacing))pt"),
                        content: {
                            Text("0pt").tag(CGFloat(0))
                            Text("5pt").tag(CGFloat(5))
                            Text("10pt").tag(CGFloat(10))
                            Text("15pt").tag(CGFloat(15))
                            Text("20pt").tag(CGFloat(20))
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
