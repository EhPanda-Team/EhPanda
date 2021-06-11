//
//  AppearanceSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI

struct AppearanceSettingView: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @State private var isNavigationLinkActive = false

    private var settingBinding: Binding<Setting>? {
        Binding($store.appState.settings.setting)
    }

    var body: some View {
        if let setting = setting,
           let settingBinding = settingBinding
        {
            NavigationLink(
                destination: SelectAppIconView(),
                isActive: $isNavigationLinkActive,
                label: {}
            )
            Form {
                Section(header: Text("Global")) {
                    HStack {
                        Text("Theme")
                        Spacer()
                        Picker(
                            selection: settingBinding.preferredColorScheme,
                            label: Text(setting.preferredColorScheme.rawValue.localized()),
                            content: {
                                ForEach(PreferredColorScheme.allCases) { colorScheme in
                                    Text(colorScheme.rawValue.localized()).tag(colorScheme)
                                }
                            }
                        )
                    }
                    .pickerStyle(MenuPickerStyle())
                    ColorPicker("Tint Color", selection: settingBinding.accentColor)
                    Button("App Icon", action: onAppIconButtonTap)
                        .foregroundColor(.primary)
                        .withArrow()
                    if Locale.current.languageCode != "en" {
                        Toggle(isOn: settingBinding.translateCategory, label: {
                            Text("Translate category")
                        })
                    }
                }
                Section(header: Text("List")) {
                    Toggle(isOn: settingBinding.showSummaryRowTags) {
                        HStack {
                            Text("Show tags in list")
                            if setting.showSummaryRowTags {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    if setting.showSummaryRowTags {
                        Toggle(isOn: settingBinding.summaryRowTagsMaximumActivated) {
                            Text("Set maximum number of tags")
                        }
                    }
                    if setting.summaryRowTagsMaximumActivated {
                        HStack {
                            Text("Maximum number of tags")
                            Spacer()
                            Picker(selection: settingBinding.summaryRowTagsMaximum,
                                   label: Text("\(setting.summaryRowTagsMaximum)")
                            ) {
                                Text("5").tag(5)
                                Text("10").tag(10)
                                Text("15").tag(15)
                                Text("20").tag(20)
                                Text("20").tag(20)
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                }
            }
            .navigationBarTitle("Appearance")
        }
    }

    private func onAppIconButtonTap() {
        isNavigationLinkActive.toggle()
    }
}

// MARK: SelectAppIconView
private struct SelectAppIconView: View {
    @EnvironmentObject private var store: Store

    private let selections = IconType.allCases
    private var selection: IconType {
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
                        iconDesc: sel.rawValue,
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

    private func onAppIconRowTap(_ sel: IconType) {
        UIApplication.shared.setAlternateIconName(sel.fileName) { error in
            if let error = error {
                notificFeedback(style: .error)
                print(error)
            }
            setSelection()
        }
    }

    private func setSelection() {
        store.dispatch(.updateAppIconType(iconType: appIconType))
    }
}

// MARK: AppIconRow
private struct AppIconRow: View {
    private let iconName: String
    private let iconDesc: String
    private let isSelected: Bool

    init(
        iconName: String,
        iconDesc: String,
        isSelected: Bool
    ) {
        self.iconName = iconName
        self.iconDesc = iconDesc
        self.isSelected = isSelected
    }

    var body: some View {
        HStack {
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .cornerRadius(12)
                .padding(.vertical, 10)
                .padding(.trailing, 20)
            Text(iconDesc.localized())
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
                    .imageScale(.large)
            }
        }
    }
}

// MARK: Definition
enum IconType: String, Codable, Identifiable, CaseIterable {
    var id: Int { hashValue }

    case normal = "Normal"
    case `default` = "Default"
    case weird = "Weird"
}

extension IconType {
    var iconName: String {
        switch self {
        case .normal:
            return "AppIcon_Normal"
        case .default:
            return "AppIcon_Default"
        case .weird:
            return "AppIcon_Weird"
        }
    }
    var fileName: String? {
        switch self {
        case .default:
            return nil
        default:
            return rawValue
        }
    }
}
