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
    let performEhProfileAction: (EhProfileAction?, String?, Int) -> Void

    @FocusState private var isFocused

    var body: some View {
        Section {
            Picker(L10n.Localizable.EhSettingView.Title.selectedProfile, selection: $ehProfile) {
                ForEach(ehSetting.ehProfiles) { ehProfile in
                    Text(ehProfile.name)
                        .tag(ehProfile)
                }
            }
            .pickerStyle(.menu)

            if !ehProfile.isDefault {
                Button(L10n.Localizable.EhSettingView.Button.setAsDefault) {
                    performEhProfileAction(.default, nil, ehProfile.value)
                }

                Button(
                    L10n.Localizable.EhSettingView.Button.deleteProfile,
                    role: .destructive,
                    action: deleteDialogAction
                )
            }
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.profileSettings)
                .ehSettingRegularHeaderStyled()
        }
        .onChange(of: ehProfile) { _, newValue in
            performEhProfileAction(nil, nil, newValue.value)
        }

        Section {
            SettingTextField(text: $editingProfileName, width: nil, alignment: .leading, background: .clear)
                .focused($isFocused)

            Button(L10n.Localizable.EhSettingView.Button.rename) {
                performEhProfileAction(.rename, editingProfileName, ehProfile.value)
            }
            .disabled(isFocused)

            if ehSetting.isCapableOfCreatingNewProfile {
                Button(L10n.Localizable.EhSettingView.Button.createNew) {
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
                L10n.Localizable.EhSettingView.Title.loadImagesThroughTheHathNetwork,
                selection: $ehSetting.loadThroughHathSetting
            ) {
                ForEach(ehSetting.capableLoadThroughHathSettings) { setting in
                    Text(setting.value)
                        .tag(setting)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text.ehSettingBoldHeader(L10n.Localizable.EhSettingView.Section.Title.imageLoadSettings)
        } footer: {
            Text(ehSetting.loadThroughHathSetting.description)
        }

        Section {
            Picker(L10n.Localizable.EhSettingView.Title.browsingCountry, selection: $ehSetting.browsingCountry) {
                ForEach(EhSetting.BrowsingCountry.allCases) { country in
                    Text(country.name)
                        .tag(country)
                        .foregroundColor(country == ehSetting.browsingCountry ? .accentColor : .primary)
                }
            }
        } header: {
            Text(
                L10n.Localizable.EhSettingView.Description.browsingCountry(
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
            Picker(L10n.Localizable.EhSettingView.Title.imageResolution, selection: $ehSetting.imageResolution) {
                ForEach(ehSetting.capableImageResolutions) { setting in
                    Text(setting.value)
                        .tag(setting)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.Section.Title.imageSizeSettings,
                description: L10n.Localizable.EhSettingView.Description.imageResolution
            )
        }

        if let useOriginalImagesBinding = Binding($ehSetting.useOriginalImages) {
            Section {
                Toggle(
                    L10n.Localizable.EhSettingView.Title.useOriginalImages,
                    isOn: useOriginalImagesBinding
                )
            } header: {
                Text(L10n.Localizable.EhSettingView.Section.Title.originalImages)
                    .ehSettingRegularHeaderStyled()
            }
        }

        Section {
            Text(L10n.Localizable.EhSettingView.Title.imageSize)

            ValuePicker(
                title: L10n.Localizable.EhSettingView.Title.horizontal,
                value: $ehSetting.imageSizeWidth, range: 0...65535, unit: "px"
            )

            ValuePicker(
                title: L10n.Localizable.EhSettingView.Title.vertical,
                value: $ehSetting.imageSizeHeight, range: 0...65535, unit: "px"
            )
        } header: {
            Text(L10n.Localizable.EhSettingView.Description.imageSize)
                .ehSettingRegularHeaderStyled()
        }
    }
}

// MARK: GalleryNameDisplaySection
struct GalleryNameDisplaySection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            Picker(L10n.Localizable.EhSettingView.Title.galleryName, selection: $ehSetting.galleryName) {
                ForEach(EhSetting.GalleryName.allCases) { name in
                    Text(name.value)
                        .tag(name)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.Section.Title.galleryNameDisplay,
                description: L10n.Localizable.EhSettingView.Description.galleryName
            )
        }
    }
}

// MARK: ArchiverSettingsSection
struct ArchiverSettingsSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            Picker(L10n.Localizable.EhSettingView.Title.archiverBehavior, selection: $ehSetting.archiverBehavior) {
                ForEach(EhSetting.ArchiverBehavior.allCases) { behavior in
                    Text(behavior.value)
                        .tag(behavior)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.Section.Title.archiverSettings,
                description: L10n.Localizable.EhSettingView.Description.archiverBehavior
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
                L10n.Localizable.EhSettingView.Section.Title.frontPageSettings,
                description: L10n.Localizable.EhSettingView.Description.galleryCategory
            )
        }

        Section {
            Picker(L10n.Localizable.EhSettingView.Title.displayMode, selection: $ehSetting.displayMode) {
                ForEach(EhSetting.DisplayMode.allCases) { mode in
                    Text(mode.value)
                        .tag(mode)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(L10n.Localizable.EhSettingView.Description.displayMode)
                .ehSettingRegularHeaderStyled()
        }

        Section {
            Toggle(
                L10n.Localizable.EhSettingView.Title.showSearchRangeIndicator,
                isOn: $ehSetting.showSearchRangeIndicator
            )
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.showSearchRangeIndicator)
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
