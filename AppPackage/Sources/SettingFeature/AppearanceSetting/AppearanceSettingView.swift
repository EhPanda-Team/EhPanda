import SwiftUI
import AppModels
import Resources
import ComposableArchitecture
import AppComponents

struct AppearanceSettingView: View {
    private let store: StoreOf<AppearanceSettingReducer>

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
                    L10n.Localizable.AppearanceSettingView.theme,
                    selection: $preferredColorScheme
                ) {
                    ForEach(PreferredColorScheme.allCases) { colorScheme in
                        Text(colorScheme.value)
                            .tag(colorScheme)
                    }
                }
                .pickerStyle(.menu)

                ColorPicker(L10n.Localizable.AppearanceSettingView.tintColor, selection: $accentColor)

                Button(L10n.Localizable.AppearanceSettingView.appIcon) {
                    store.send(.delegate(.pushAppIcon))
                }
                .foregroundStyle(.primary)
                .withArrow()
            }
            Section(L10n.Localizable.AppearanceSettingView.list) {
                Picker(
                    L10n.Localizable.AppearanceSettingView.displayMode,
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
                    Text(L10n.Localizable.AppearanceSettingView.showsTagsInList)
                }

                Picker(
                    L10n.Localizable.AppearanceSettingView.maximumNumberOfTags,
                    selection: $listTagsNumberMaximum
                ) {
                    Text(L10n.Localizable.AppearanceSettingView.infite)
                        .tag(0)

                    ForEach(Array(stride(from: 5, through: 20, by: 5)), id: \.self) { num in
                        Text("\(num)")
                            .tag(num)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!showsTagsInList)
            }
            Section(L10n.Localizable.AppearanceSettingView.gallery) {
                Toggle(
                    L10n.Localizable.AppearanceSettingView.displaysJapaneseTitle,
                    isOn: $displaysJapaneseTitle
                )
            }
        }
        .navigationTitle(L10n.Localizable.AppearanceSettingView.appearance)
    }
}

// MARK: SelectAppIconView
struct AppIconView: View {
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
                    .contentShape(.rect)
                    .onTapGesture { appIconType = icon }
                }
            }
        }
        .navigationTitle(L10n.Localizable.AppIconView.appIcon)
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
                .clipShape(.rect(cornerRadius: 15))
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

struct AppearanceSettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AppearanceSettingView(
                store: .init(initialState: .init(), reducer: AppearanceSettingReducer.init),
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
