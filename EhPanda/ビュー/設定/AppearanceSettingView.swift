//
//  AppearanceSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI

struct AppearanceSettingView: View {
    @EnvironmentObject var store: Store
    @State var isNavigationLinkActive = false
    
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
            NavigationLink(
                destination: SelectAppIconView(),
                isActive: $isNavigationLinkActive,
                label: {})
            Form {
                Section(header: Text("全般")) {
                    HStack {
                        Text("テーマ")
                        Spacer()
                        Picker(
                            selection: settingBinding.preferredColorScheme,
                            label: Text(setting.preferredColorScheme.rawValue.lString()),
                            content: {
                                ForEach(PreferredColorScheme.allCases) { colorScheme in
                                    Text(colorScheme.rawValue.lString()).tag(colorScheme)
                                }
                            }
                        )
                    }
                    .pickerStyle(MenuPickerStyle())
                    ColorPicker("テーマの色", selection: settingBinding.accentColor)
                    Button("アプリアイコン", action: onAppIconButtonTap)
                        .foregroundColor(.primary)
                        .withArrow()
                    if exx {
                        Toggle(isOn: settingBinding.translateCategory, label: {
                            Text("カテゴリーを訳す")
                        })
                    }
                }
                Section(header: Text("ホーム")) {
                    Toggle(isOn: settingBinding.showSummaryRowTags) {
                        HStack {
                            Text("リストでタグを表示")
                            if setting.showSummaryRowTags {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    if setting.showSummaryRowTags {
                        Toggle(isOn: settingBinding.summaryRowTagsMaximumActivated) {
                            Text("リストでのタグ数を制限")
                        }
                    }
                    if setting.summaryRowTagsMaximumActivated {
                        HStack {
                            Text("タグ数上限")
                            Spacer()
                            TextField("", text: settingBinding.rawSummaryRowTagsMaximum)
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                                .background(Color(.systemGray6))
                                .frame(width: 50)
                                .cornerRadius(5)
                        }
                    }
                }
            }
            .navigationBarTitle("外観")
        }
    }
    
    func onAppIconButtonTap() {
        isNavigationLinkActive.toggle()
    }
}

// MARK: SelectAppIconView
private struct SelectAppIconView: View {
    @EnvironmentObject var store: Store
    
    let selections = IconType.allCases
    var selection: IconType {
        store.appState
            .settings.setting?
            .appIconType ?? appIconType
    }
    
    
    var body: some View {
        Form {
            Section {
                ForEach(selections) { sel in
                    AppIconRow(
                        iconName: sel.iconName,
                        iconDesc: sel.description,
                        isSelected: sel == selection
                    )
                    .contentShape(Rectangle())
                    .onTapGesture(perform: {
                        onAppIconRowTap(sel)
                    })
                }
            }
        }
        .onAppear(perform: setSelection)
    }
    
    func onAppIconRowTap(_ sel: IconType) {
        UIApplication.shared.setAlternateIconName(sel.fileName) { error in
            if let error = error {
                notificFeedback(style: .error)
                print(error)
            }
            setSelection()
        }
    }
    
    func setSelection() {
        store.dispatch(.updateAppIconType(iconType: appIconType))
    }
}

// MARK: AppIconRow
private struct AppIconRow: View {
    let iconName: String
    let iconDesc: String
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .cornerRadius(12)
                .padding(.vertical, 10)
                .padding(.trailing, 20)
            Text(iconDesc.lString())
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .imageScale(.large)
            }
        }
    }
}

// MARK: 定義
public enum IconType: String, Codable, Identifiable, CaseIterable {
    public var id: Int { hashValue }
    
    case Normal = "Normal"
    case Default = "Default"
    case Weird = "Weird"
}

extension IconType {
    var iconName: String {
        switch self {
        case .Normal:
            return "AppIcon_Normal"
        case .Default:
            return "AppIcon_Default"
        case .Weird:
            return "AppIcon_Weird"
        }
    }
    var fileName: String? {
        switch self {
        case .Default:
            return nil
        default:
            return rawValue
        }
    }
    var description: String {
        switch self {
        case .Normal:
            return "普通"
        case .Default:
            return "既定"
        case .Weird:
            return "怪奇"
        }
    }
}
