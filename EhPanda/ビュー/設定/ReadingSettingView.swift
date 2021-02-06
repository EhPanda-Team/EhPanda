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
                        Text("再試行上限数")
                        Picker(
                            selection: settingBinding.contentRetryLimit,
                            label: Text("Picker"),
                            content: {
                                Text("5").tag(5)
                                Text("10").tag(10)
                                Text("15").tag(15)
                                Text("20").tag(20)
                            }
                        )
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.leading, 10)
                    }
                }
                Section(header: Text("外観")) {
                    Toggle(isOn: settingBinding.showContentDividers, label: {
                        Text("画像の間に仕切りを挿む")
                    })
                    if setting.showContentDividers {
                        HStack {
                            Text("仕切りの厚さ")
                            Picker(
                                selection: settingBinding.contentDividerHeight,
                                label: Text("Picker"),
                                content: {
                                    Text("5").tag(CGFloat(5))
                                    Text("10").tag(CGFloat(10))
                                    Text("15").tag(CGFloat(15))
                                    Text("20").tag(CGFloat(20))
                                }
                            )
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.leading, 10)
                        }
                    }
                }
            }
            .navigationBarTitle("閲覧")
        }
    }
}
