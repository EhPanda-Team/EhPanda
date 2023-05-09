//
//  AppearanceSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI
import ComposableArchitecture

struct AppearanceSettingView: View {
    private let store: StoreOf<AppearanceSettingReducer>
    @ObservedObject private var viewStore: ViewStoreOf<AppearanceSettingReducer>

    @Binding private var preferredColorScheme: PreferredColorScheme
    @Binding private var accentColor: Color
    @Binding private var appIconType: AppIconType
    @Binding private var listDisplayMode: ListDisplayMode
    @Binding private var showsTagsInList: Bool
    @Binding private var listTagsNumberMaximum: Int
    @Binding private var displaysJapaneseTitle: Bool

    init(
        store: StoreOf<AppearanceSettingReducer>,
        preferredColorScheme: Binding<PreferredColorScheme>,
        accentColor: Binding<Color>,
        appIconType: Binding<AppIconType>,
        listDisplayMode: Binding<ListDisplayMode>,
        showsTagsInList: Binding<Bool>,
        listTagsNumberMaximum: Binding<Int>,
        displaysJapaneseTitle: Binding<Bool>
    ) {
        self.store = store
        viewStore = ViewStore(store)
        _preferredColorScheme = preferredColorScheme
        _accentColor = accentColor
        _appIconType = appIconType
        _listDisplayMode = listDisplayMode
        _showsTagsInList = showsTagsInList
        _listTagsNumberMaximum = listTagsNumberMaximum
        _displaysJapaneseTitle = displaysJapaneseTitle
    }

    var body: some View {
        Form {
            Section {
                Picker(
                    L10n.Localizable.AppearanceSettingView.Title.theme,
                    selection: $preferredColorScheme
                ) {
                    ForEach(PreferredColorScheme.allCases) { colorScheme in
                        Text(colorScheme.value)
                            .tag(colorScheme)
                    }
                }
                .pickerStyle(.menu)

                ColorPicker(L10n.Localizable.AppearanceSettingView.Title.tintColor, selection: $accentColor)

                Button(L10n.Localizable.AppearanceSettingView.Button.appIcon) {
                    viewStore.send(.setNavigation(.appIcon))
                }
                .foregroundStyle(.primary)
                .withArrow()
            }
            Section(L10n.Localizable.AppearanceSettingView.Section.Title.list) {
                Picker(
                    L10n.Localizable.AppearanceSettingView.Title.displayMode,
                    selection: $listDisplayMode,
                    content: {
                        ForEach(ListDisplayMode.allCases) { listMode in
                            Text(listMode.value)
                                .tag(listMode)
                        }
                    }
                )
                .pickerStyle(.menu)

                Toggle(isOn: $showsTagsInList) {
                    Text(L10n.Localizable.AppearanceSettingView.Title.showsTagsInList)
                }

                Picker(
                    L10n.Localizable.AppearanceSettingView.Title.maximumNumberOfTags,
                    selection: $listTagsNumberMaximum
                ) {
                    Text(L10n.Localizable.AppearanceSettingView.Menu.Title.infite)
                        .tag(0)

                    ForEach(Array(stride(from: 5, through: 20, by: 5)), id: \.self) { num in
                        Text("\(num)")
                            .tag(num)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!showsTagsInList)
            }
            Section(L10n.Localizable.AppearanceSettingView.Section.Title.gallery) {
                Toggle(
                    L10n.Localizable.AppearanceSettingView.Title.displaysJapaneseTitle,
                    isOn: $displaysJapaneseTitle
                )
            }
        }
        .background(navigationLink)
        .navigationTitle(L10n.Localizable.AppearanceSettingView.Title.appearance)
    }

    private var navigationLink: some View {
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /AppearanceSettingReducer.Route.appIcon) { _ in
            AppIconView(appIconType: $appIconType)
        }
    }
}

// MARK: SelectAppIconView
private struct AppIconView: View {
    @Binding private var appIconType: AppIconType

    init(appIconType: Binding<AppIconType>) {
        _appIconType = appIconType
    }

    var body: some View {
        Form {
            Section {
                ForEach(AppIconType.allCases) { icon in
                    AppIconRow(
                        iconName: icon.name,
                        filename: icon.filename,
                        isSelected: icon == appIconType
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { appIconType = icon }
                }
            }
        }
        .navigationTitle(L10n.Localizable.AppIconView.Title.appIcon)
    }
}

// MARK: AppIconRow
private struct AppIconRow: View {
    private let iconName: String
    private let filename: String
    private let isSelected: Bool

    init(iconName: String, filename: String, isSelected: Bool) {
        self.iconName = iconName
        self.filename = filename
        self.isSelected = isSelected
    }

    var body: some View {
        HStack(spacing: 20) {
            UIImage(named: filename, in: .main, with: nil)
                .map(Image.init)?
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .padding(.vertical, 10)

            Text(iconName)

            Spacer()

            Image(systemSymbol: .checkmarkCircleFill)
                .opacity(isSelected ? 1 : 0)
                .foregroundStyle(.tint)
                .imageScale(.large)
        }
    }
}

// MARK: Definition
enum AppIconType: Int, Codable, Identifiable, CaseIterable {
    var id: Int { rawValue }

    case `default`
    case ukiyoe
    case developer
    case standWithUkraine2022
    case notMyPresidnet
}

extension AppIconType {
    var name: String {
        switch self {
        case .default:
            return L10n.Localizable.Enum.AppIconType.Value.default

        case .ukiyoe:
            return L10n.Localizable.Enum.AppIconType.Value.ukiyoe

        case .developer:
            return L10n.Localizable.Enum.AppIconType.Value.developer

        case .standWithUkraine2022:
            return L10n.Localizable.Enum.AppIconType.Value.standWithUkraine2022

        case .notMyPresidnet:
            return L10n.Localizable.Enum.AppIconType.Value.notMyPresident
        }
    }

    var filename: String {
        switch self {
        case .default:
            return "AppIcon_Default"

        case .ukiyoe:
            return "AppIcon_Ukiyoe"

        case .developer:
            return "AppIcon_Developer"

        case .standWithUkraine2022:
            return "AppIcon_StandWithUkraine2022"

        case .notMyPresidnet:
            return "AppIcon_NotMyPresident"
        }
    }
}

struct AppearanceSettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AppearanceSettingView(
                store: .init(
                    initialState: .init(),
                    reducer: AppearanceSettingReducer()
                ),
                preferredColorScheme: .constant(.automatic),
                accentColor: .constant(.blue),
                appIconType: .constant(.default),
                listDisplayMode: .constant(.detail),
                showsTagsInList: .constant(false),
                listTagsNumberMaximum: .constant(0),
                displaysJapaneseTitle: .constant(true)
            )
        }
    }
}
