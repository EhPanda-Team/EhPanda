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
        .scrollEdgeEffectStyle(.soft, for: .top)
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
                    ) {
                        $setting.withLock({ $0.appIconType = icon })
                    }
                }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(.appIcon)
        .onChange(of: setting.appIconType) { _, newValue in
            store.send(.appIconTypeChanged(newValue))
        }
    }
}

// MARK: AppIconRow
/// One selectable icon: an unhighlighted `Button` so the row is a real control — it has the button
/// role, the icon's name as its label and Voice Control name, and the current choice as the
/// `.isSelected` trait. The trailing checkmark is the sighted rendering of that same trait, so it
/// is kept out of the accessibility tree rather than announced a second time as "Selected".
private struct AppIconRow: View {
    private let iconName: LocalizedStringResource
    private let filename: String
    private let isSelected: Bool
    private let action: () -> Void

    init(iconName: LocalizedStringResource, filename: String, isSelected: Bool, action: @escaping () -> Void) {
        self.iconName = iconName
        self.filename = filename
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
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
                    .accessibilityHidden(true)
                    .foregroundStyle(.tint)
                    .imageScale(.large)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.unhighlighted)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Initial") {
    NavigationStack {
        AppearanceSettingView(
            store: .init(initialState: .init(), reducer: AppearanceSettingReducer.init)
        )
    }
}
