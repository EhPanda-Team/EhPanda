//
//  ReadingSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI

struct ReadingSettingView: View {
    @EnvironmentObject var store: Store

    var setting: Setting? {
        store.appState.settings.setting
    }
    var settingBinding: Binding<Setting>? {
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
                Section(header: Text("Apperance")) {
                    Toggle(isOn: settingBinding.showContentDividers, label: {
                        Text("Insert separators between images")
                    })
                    if setting.showContentDividers {
                        HStack {
                            Text("Separator height")
                            Spacer()
                            Picker(
                                selection: settingBinding.contentDividerHeight,
                                label: Text("\(Int(setting.contentDividerHeight))pt"),
                                content: {
                                    Text("5pt").tag(CGFloat(5))
                                    Text("10pt").tag(CGFloat(10))
                                    Text("15pt").tag(CGFloat(15))
                                    Text("20pt").tag(CGFloat(20))
                                }
                            )
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                }
            }
            .navigationBarTitle("Reading")
        }
    }
}
