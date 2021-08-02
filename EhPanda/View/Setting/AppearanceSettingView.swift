//
//  AppearanceSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI
import SwiftyBeaver

struct AppearanceSettingView: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @State private var isNavLinkActive = false

    private var settingBinding: Binding<Setting> {
        $store.appState.settings.setting
    }
    private var selectedIcon: IconType {
        store.appState.settings.setting.appIconType
    }

    var body: some View {
        NavigationLink(
            destination: SelectAppIconView(
                selectedIcon: selectedIcon,
                selectAction: onIconSelect
            ),
            isActive: $isNavLinkActive,
            label: {}
        )
        Form {
            Section {
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
                .pickerStyle(.menu)
                ColorPicker("Tint Color", selection: settingBinding.accentColor)
                Button("App Icon", action: onAppIconButtonTap)
                    .foregroundStyle(.primary).withArrow()
                Toggle("Translates category", isOn: settingBinding.translatesCategory)
                    .disabled(Locale.current.languageCode == "en")
            }
            Section(header: Text("List")) {
                HStack {
                    Text("Display mode")
                    Spacer()
                    Picker(
                        selection: settingBinding.listMode,
                        label: Text(setting.listMode.rawValue.localized()),
                        content: {
                            ForEach(ListMode.allCases) { listMode in
                                Text(listMode.rawValue.localized()).tag(listMode)
                            }
                        }
                    )
                }
                .pickerStyle(.menu)
                Toggle(isOn: settingBinding.showsSummaryRowTags) {
                    Text("Shows tags in list")
                }
                Toggle(isOn: settingBinding.summaryRowTagsMaximumActivated) {
                    Text("Sets maximum number of tags")
                }
                .disabled(!setting.showsSummaryRowTags)
                HStack {
                    Text("Maximum number of tags")
                    Spacer()
                    Picker(selection: settingBinding.summaryRowTagsMaximum,
                           label: Text("\(setting.summaryRowTagsMaximum)")
                    ) {
                        let nums = Array(stride(
                            from: 5, through: 20, by: 5
                        ))
                        ForEach(nums, id: \.self) { num in
                            Text("\(num)").tag(num)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .disabled(
                    !setting.summaryRowTagsMaximumActivated
                    || !setting.showsSummaryRowTags
                )
            }
        }
        .navigationBarTitle("Appearance")
    }

    private func onAppIconButtonTap() {
        isNavLinkActive.toggle()
    }
    private func onIconSelect() {
        DispatchQueue.main.async {
            store.dispatch(.updateAppIconType(iconType: appIconType))
        }
    }
}

// MARK: SelectAppIconView
private struct SelectAppIconView: View {
    private let selectedIcon: IconType
    private let selectAction: () -> Void

    init(
        selectedIcon: IconType,
        selectAction: @escaping () -> Void
    ) {
        self.selectedIcon = selectedIcon
        self.selectAction = selectAction
    }

    var body: some View {
        Form {
            Section {
                ForEach(IconType.allCases) { icon in
                    AppIconRow(
                        iconName: icon.iconName,
                        iconDesc: icon.rawValue,
                        isSelected: icon == selectedIcon
                    )
                    .contentShape(Rectangle())
                    .onTapGesture(perform: {
                        onAppIconRowTap(icon: icon)
                    })
                }
            }
        }
        .task(selectAction)
    }

    private func onAppIconRowTap(icon: IconType) {
        UIApplication.shared.setAlternateIconName(icon.fileName) { error in
            if let error = error {
                notificFeedback(style: .error)
                SwiftyBeaver.error(error)
            }
            selectAction()
        }
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
            Image(systemName: "checkmark.circle.fill")
                .opacity(isSelected ? 1 : 0)
                .foregroundStyle(.tint)
                .imageScale(.large)
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
