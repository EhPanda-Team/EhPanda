//
//  AppearanceSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI
import ComposableArchitecture

struct AppearanceSettingView: View {
    private let store: Store<AppearanceSettingState, AppearanceSettingAction>
    @ObservedObject private var viewStore: ViewStore<AppearanceSettingState, AppearanceSettingAction>

    @Binding private var preferredColorScheme: PreferredColorScheme
    @Binding private var accentColor: Color
    @Binding private var appIconType: AppIconType
    @Binding private var listDisplayMode: ListDisplayMode
    @Binding private var showsTagsInList: Bool
    @Binding private var listTagsNumberMaximum: Int
    @Binding private var displaysJapaneseTitle: Bool

    init(
        store: Store<AppearanceSettingState, AppearanceSettingAction>,
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
                    R.string.localizable.appearanceSettingViewTitleTheme(),
                    selection: $preferredColorScheme
                ) {
                    ForEach(PreferredColorScheme.allCases) { colorScheme in
                        Text(colorScheme.value)
                            .tag(colorScheme)
                    }
                }
                .pickerStyle(.menu)

                ColorPicker(R.string.localizable.appearanceSettingViewTitleTintColor(), selection: $accentColor)

                Button(R.string.localizable.appearanceSettingViewButtonAppIcon()) {
                    viewStore.send(.setNavigation(.appIcon))
                }
                .foregroundStyle(.primary)
                .withArrow()
            }
            Section(R.string.localizable.appearanceSettingViewSectionTitleList()) {
                HStack {
                    Text(R.string.localizable.appearanceSettingViewTitleDisplayMode())

                    Spacer()

                    Picker(
                        selection: $listDisplayMode,
                        label: Text(listDisplayMode.value),
                        content: {
                            ForEach(ListDisplayMode.allCases) { listMode in
                                Text(listMode.value)
                                    .tag(listMode)
                            }
                        }
                    )
                }
                .pickerStyle(.menu)

                Toggle(isOn: $showsTagsInList) {
                    Text(R.string.localizable.appearanceSettingViewTitleShowsTagsInList())
                }

                Picker(
                    R.string.localizable.appearanceSettingViewTitleMaximumNumberOfTags(),
                    selection: $listTagsNumberMaximum
                ) {
                    Text(R.string.localizable.appearanceSettingViewMenuTitleInfite())
                        .tag(0)

                    ForEach(Array(stride(from: 5, through: 20, by: 5)), id: \.self) { num in
                        Text("\(num)")
                            .tag(num)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!showsTagsInList)
            }
            Section(R.string.localizable.appearanceSettingViewSectionTitleGallery()) {
                Toggle(
                    R.string.localizable.appearanceSettingViewTitleDisplaysJapaneseTitle(),
                    isOn: $displaysJapaneseTitle
                )
            }
        }
        .background(navigationLink)
        .navigationTitle(R.string.localizable.appearanceSettingViewTitleAppearance())
    }

    private var navigationLink: some View {
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /AppearanceSettingState.Route.appIcon) { _ in
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
        .navigationTitle(R.string.localizable.appIconViewTitleAppIcon())
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
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            return R.string.localizable.enumAppIconTypeValueDefault()

        case .ukiyoe:
            return R.string.localizable.enumAppIconTypeValueUkiyoe()

        case .developer:
            return R.string.localizable.enumAppIconTypeValueDeveloper()

        case .standWithUkraine2022:
            return R.string.localizable.enumAppIconTypeValueStandWithUkraine2022()

        case .notMyPresidnet:
            return R.string.localizable.enumAppIconTypeValueNotMyPresident()
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
                    reducer: appearanceSettingReducer,
                    environment: AppearanceSettingEnvironment()
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
