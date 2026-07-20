import AppComponents
import AppModels
import ComposableArchitecture
import Resources
import Sharing
import SwiftUI

struct AppearanceSettingView: View {
    private let store: StoreOf<AppearanceSettingReducer>
    @Shared(.setting) private var setting: Setting

    init(store: StoreOf<AppearanceSettingReducer>) {
        self.store = store
    }

    var body: some View {
        Form {
            Section {
                Picker(
                    .theme,
                    selection: Binding($setting.preferredColorScheme)
                ) {
                    ForEach(PreferredColorScheme.allCases) { colorScheme in
                        Text(colorScheme.value)
                            .tag(colorScheme)
                    }
                }
                .pickerStyle(.menu)

                Button(.appIcon) {
                    store.send(.delegate(.pushAppIcon))
                }
                .foregroundStyle(.primary)
                .withArrow()

                VStack(alignment: .leading) {
                    Text(.privacyMask)
                    HStack {
                        Image(systemSymbol: .eye)
                            .accessibilityHidden(true)
                        Slider(value: Binding($setting.privacyMaskIntensity), in: 0...100, step: 10)
                            .accessibilityLabel(.privacyMask)
                        Image(systemSymbol: .eyeSlash)
                            .accessibilityHidden(true)
                    }
                }
            } footer: {
                Text(.privacyMaskFooter)
            }
            Section(.list) {
                Picker(
                    .appearanceDisplayMode,
                    selection: Binding($setting.listDisplayMode),
                    content: {
                        ForEach(ListDisplayMode.allCases) { listMode in
                            Text(listMode.value)
                                .tag(listMode)
                        }
                    }
                )
                .pickerStyle(.menu)

                AppToggle(isOn: Binding($setting.showTagsInList)) {
                    Text(.showTagsInList)
                }

                Picker(
                    .maximumNumberOfTags,
                    selection: Binding($setting.listTagsNumberMaximum)
                ) {
                    Text(.infite)
                        .tag(0)

                    ForEach(Array(stride(from: 5, through: 20, by: 5)), id: \.self) { num in
                        Text(num, format: .number)
                            .tag(num)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!setting.showTagsInList)
            }
            Section(.gallery) {
                AppToggle(
                    .displayJapaneseTitle,
                    isOn: Binding($setting.displayJapaneseTitle)
                )
            }
        }
        .navigationTitle(.appearance)
        .onChange(of: setting.preferredColorScheme) { _, newValue in
            store.send(.preferredColorSchemeChanged(newValue))
        }
    }
}

// MARK: SelectAppIconView
struct AppIconView: View {
    private let store: StoreOf<AppIconReducer>
    @Shared(.setting) private var setting: Setting

    init(store: StoreOf<AppIconReducer>) {
        self.store = store
    }

    var body: some View {
        Form {
            Section {
                ForEach(AppIconType.allCases) { icon in
                    AppIconRow(
                        iconName: icon.name,
                        filename: icon.filename,
                        isSelected: icon == setting.appIconType
                    )
                    .contentShape(.rect)
                    .onTapGesture { $setting.withLock { $0.appIconType = icon } }
                }
            }
        }
        .navigationTitle(.appIcon)
        .onChange(of: setting.appIconType) { _, newValue in
            store.send(.appIconTypeChanged(newValue))
        }
    }
}

// MARK: AppIconRow
private struct AppIconRow: View {
    private let iconName: LocalizedStringResource
    private let filename: String
    private let isSelected: Bool

    init(iconName: LocalizedStringResource, filename: String, isSelected: Bool) {
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
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemSymbol: .checkmarkCircleFill)
                .opacity(isSelected ? 1 : 0)
                .foregroundStyle(.tint)
                .imageScale(.large)
        }
    }
}

#Preview("Initial") {
    NavigationStack {
        AppearanceSettingView(
            store: .init(initialState: .init(), reducer: AppearanceSettingReducer.init)
        )
    }
}
