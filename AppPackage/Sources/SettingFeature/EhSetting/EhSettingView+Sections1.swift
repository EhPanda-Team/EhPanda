import SwiftUI
import AppModels
import Resources
import ComposableArchitecture
import AppTools
import AppComponents

extension EhSettingView {

// MARK: EhProfileSection
struct EhProfileSection: View {
    @Binding var ehSetting: EhSetting
    @Binding var ehProfile: EhProfile
    @Binding var editingProfileName: String
    let deleteDialogAction: () -> Void
    let deleteConfirmationDialog:
        Binding<Store<ConfirmationDialogState<EhSettingReducer.Dialog>, EhSettingReducer.Dialog>?>
    let performEhProfileAction: (EhProfileAction?, String?, Int) -> Void

    @FocusState private var isFocused

    var body: some View {
        Section {
            Picker(L10n.Localizable.EhSettingView.selectedProfile, selection: $ehProfile) {
                ForEach(ehSetting.ehProfiles) { ehProfile in
                    Text(ehProfile.name)
                        .tag(ehProfile)
                }
            }
            .pickerStyle(.menu)

            if !ehProfile.isDefault {
                Button(L10n.Localizable.EhSettingView.setAsDefault) {
                    performEhProfileAction(.default, nil, ehProfile.value)
                }

                Button(
                    L10n.Localizable.EhSettingView.deleteProfile,
                    role: .destructive,
                    action: deleteDialogAction
                )
                .confirmationDialog(deleteConfirmationDialog)
            }
        } header: {
            Text(L10n.Localizable.EhSettingView.profileSettings)
                .ehSettingRegularHeaderStyled()
        }
        .onChange(of: ehProfile) { _, newValue in
            performEhProfileAction(nil, nil, newValue.value)
        }

        Section {
            SettingTextField(text: $editingProfileName, width: nil, alignment: .leading, background: .clear)
                .focused($isFocused)

            Button(L10n.Localizable.EhSettingView.rename) {
                performEhProfileAction(.rename, editingProfileName, ehProfile.value)
            }
            .disabled(isFocused)

            if ehSetting.isCapableOfCreatingNewProfile {
                Button(L10n.Localizable.EhSettingView.createNew) {
                    performEhProfileAction(.create, editingProfileName, ehProfile.value)
                }
                .disabled(isFocused)
            }
        }
    }
}

// MARK: ImageLoadSettingsSection
struct ImageLoadSettingsSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            Picker(
                L10n.Localizable.EhSettingView.loadImagesThroughTheHathNetwork,
                selection: $ehSetting.loadThroughHathSetting
            ) {
                ForEach(ehSetting.capableLoadThroughHathSettings) { setting in
                    Text(setting.value)
                        .tag(setting)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text.ehSettingBoldHeader(L10n.Localizable.EhSettingView.imageLoadSettings)
        } footer: {
            Text(ehSetting.loadThroughHathSetting.description)
        }

        Section {
            Picker(L10n.Localizable.EhSettingView.browsingCountry, selection: $ehSetting.browsingCountry) {
                ForEach(EhSetting.BrowsingCountry.allCases) { country in
                    Text(country.name)
                        .tag(country)
                        .foregroundColor(country == ehSetting.browsingCountry ? .accentColor : .primary)
                }
            }
        } header: {
            Text(
                L10n.Localizable.EhSettingView.browsingCountryDescription(
                    ehSetting.localizedLiteralBrowsingCountry ?? ehSetting.literalBrowsingCountry
                )
                .localizedKey
            )
            .ehSettingRegularHeaderStyled()
        }
    }
}

// MARK: ImageSizeSettingsSection
struct ImageSizeSettingsSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            Picker(L10n.Localizable.EhSettingView.imageResolution, selection: $ehSetting.imageResolution) {
                ForEach(ehSetting.capableImageResolutions) { setting in
                    Text(setting.value)
                        .tag(setting)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.imageSizeSettings,
                description: L10n.Localizable.EhSettingView.imageResolutionDescription
            )
        }

        if let useOriginalImagesBinding = Binding($ehSetting.useOriginalImages) {
            Section {
                Toggle(
                    L10n.Localizable.EhSettingView.useOriginalImages,
                    isOn: useOriginalImagesBinding
                )
            } header: {
                Text(L10n.Localizable.EhSettingView.originalImages)
                    .ehSettingRegularHeaderStyled()
            }
        }

        Section {
            Text(L10n.Localizable.EhSettingView.imageSize)

            ValuePicker(
                title: L10n.Localizable.EhSettingView.horizontal,
                value: $ehSetting.imageSizeWidth, range: 0...65535, unit: "px"
            )

            ValuePicker(
                title: L10n.Localizable.EhSettingView.vertical,
                value: $ehSetting.imageSizeHeight, range: 0...65535, unit: "px"
            )
        } header: {
            Text(L10n.Localizable.EhSettingView.imageSizeDescription)
                .ehSettingRegularHeaderStyled()
        }
    }
}

// MARK: GalleryNameDisplaySection
struct GalleryNameDisplaySection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            Picker(L10n.Localizable.EhSettingView.galleryName, selection: $ehSetting.galleryName) {
                ForEach(EhSetting.GalleryName.allCases) { name in
                    Text(name.value)
                        .tag(name)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.galleryNameDisplay,
                description: L10n.Localizable.EhSettingView.galleryNameDescription
            )
        }
    }
}

// MARK: ArchiverSettingsSection
struct ArchiverSettingsSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            Picker(L10n.Localizable.EhSettingView.archiverBehavior, selection: $ehSetting.archiverBehavior) {
                ForEach(EhSetting.ArchiverBehavior.allCases) { behavior in
                    Text(behavior.value)
                        .tag(behavior)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.archiverSettings,
                description: L10n.Localizable.EhSettingView.archiverBehaviorDescription
            )
        }
    }
}

// MARK: FrontPageSettingsSection
struct FrontPageSettingsSection: View {
    @Binding var ehSetting: EhSetting

    private var categoryBindings: [Binding<Bool>] {
        $ehSetting.disabledCategories.map({ $0 })
    }

    var body: some View {
        Section {
            CategoryView(bindings: categoryBindings)
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.frontPageSettings,
                description: L10n.Localizable.EhSettingView.galleryCategory
            )
        }

        Section {
            Picker(L10n.Localizable.EhSettingView.displayMode, selection: $ehSetting.displayMode) {
                ForEach(EhSetting.DisplayMode.allCases) { mode in
                    Text(mode.value)
                        .tag(mode)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(L10n.Localizable.EhSettingView.displayModeDescription)
                .ehSettingRegularHeaderStyled()
        }

        Section {
            Toggle(
                L10n.Localizable.EhSettingView.showSearchRangeIndicatorDescription,
                isOn: $ehSetting.showSearchRangeIndicator
            )
        } header: {
            Text(L10n.Localizable.EhSettingView.showSearchRangeIndicator)
                .ehSettingRegularHeaderStyled()
        }
    }
}

// MARK: Shared Helpers
struct ValuePicker: View {
    private let title: String
    @Binding var value: Float
    private let range: ClosedRange<Float>
    private let unit: String

    init(title: String, value: Binding<Float>, range: ClosedRange<Float>, unit: String = "") {
        self.title = title
        _value = value
        self.range = range
        self.unit = unit
    }

    var body: some View {
        LabeledContent(title) {
            Text(String(Int(value)) + unit)
                .foregroundStyle(.tint)
        }

        Slider(
            value: $value,
            in: range,
            label: EmptyView.init,
            minimumValueLabel: {
                Text(String(Int(range.lowerBound)) + unit)
                    .fontWeight(.medium)
                    .font(.callout)
            },
            maximumValueLabel: {
                Text(String(Int(range.upperBound)) + unit)
                    .fontWeight(.medium)
                    .font(.callout)
            }
        )
    }
}

}

extension Text {
    static func ehSettingBoldHeader(_ title: String, description: String? = nil) -> Self {
        var result = AttributedString(title)
        result.font = .body.weight(.bold)
        if let description {
            var descriptionString = AttributedString("\n\(description)")
            descriptionString.font = .subheadline.weight(.regular)
            result.append(descriptionString)
        }
        return Text(result)
    }

    func ehSettingRegularHeaderStyled() -> Self {
        font(.subheadline.weight(.regular))
    }
}
