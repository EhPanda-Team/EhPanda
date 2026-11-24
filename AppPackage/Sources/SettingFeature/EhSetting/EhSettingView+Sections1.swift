import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import Resources
import SwiftUI

extension EhSettingView {

// MARK: EhProfileSection
struct EhProfileSection: View {
    @Binding var ehSetting: EhSetting
    @Binding var ehProfile: EhProfile
    let updatingOptions: Set<EhSettingReducer.Option>
    let profilePickerFocus: AccessibilityFocusState<Bool>.Binding
    @Binding var editingProfileName: String
    let deleteDialogAction: () -> Void
    let deleteConfirmationDialog:
        Binding<Store<ConfirmationDialogState<EhSettingReducer.Dialog>, EhSettingReducer.Dialog>?>
    let performEhProfileAction: (EhProfileAction?, String?, Int) -> Void

    @FocusState private var isFocused

    var body: some View {
        Section {
            Picker(.selectedProfile, selection: $ehProfile) {
                ForEach(ehSetting.ehProfiles) { ehProfile in
                    Text(ehProfile.name)
                        .tag(ehProfile)
                }
            }
            .ehSettingPickerStyled()
            .accessibilityFocused(profilePickerFocus)
            .disabled(updatingOptions.contains(.profile))

            if !ehProfile.isDefault {
                Button(.setAsDefault) {
                    performEhProfileAction(.default, nil, ehProfile.value)
                }
                .cellRowHover()
                .disabled(updatingOptions.contains(.profile))

                Button(
                    .deleteProfile,
                    role: .destructive,
                    action: deleteDialogAction
                )
                .cellRowHover()
                .disabled(updatingOptions.contains(.profile))
                .confirmationDialog(deleteConfirmationDialog)
            }
        }
        .onChange(of: ehProfile) { _, newValue in
            performEhProfileAction(nil, nil, newValue.value)
        }

        Section {
            SettingTextField(
                text: $editingProfileName, title: .profileName,
                promptText: .profileName,
                width: nil, alignment: .leading, background: .clear
            )
            .focused($isFocused)

            Button(.rename) {
                performEhProfileAction(.rename, editingProfileName, ehProfile.value)
            }
            .cellRowHover()
            .disabled(isFocused || updatingOptions.contains(.profile))

            if ehSetting.isCapableOfCreatingNewProfile {
                Button(.createNew) {
                    performEhProfileAction(.create, editingProfileName, ehProfile.value)
                }
                .cellRowHover()
                .disabled(isFocused || updatingOptions.contains(.profile))
            }
        }
    }
}

// MARK: ImageLoadSettingsSection
struct ImageLoadSettingsSection: View {
    @Binding var ehSetting: EhSetting
    let updatingOptions: Set<EhSettingReducer.Option>

    var body: some View {
        Section {
            Picker(
                .loadImagesThroughHentaiAtHome,
                selection: $ehSetting.loadThroughHathSetting
            ) {
                ForEach(ehSetting.capableLoadThroughHathSettings) { setting in
                    Text(setting.value)
                        .tag(setting)
                }
            }
            .ehSettingPickerStyled()
            .disabled(updatingOptions.contains(.loadThroughHathSetting))
        } header: {
            Text.ehSettingBoldHeader(.imageLoadSettings)
        } footer: {
            Text(ehSetting.loadThroughHathSetting.description)
        }

        Section {
            Picker(.hahRegion, selection: $ehSetting.hahRegion) {
                ForEach(EhSetting.HahRegion.allCases) { region in
                    Text(region.name)
                        .tag(region)
                }
            }
            .ehSettingPickerStyled()
            .disabled(updatingOptions.contains(.hahRegion))
        } header: {
            if let country = ehSetting.literalDetectedCountry, let region = ehSetting.literalHahRegion {
                Text(
                    .hahRegionDescription(
                        ehSetting.localizedLiteralDetectedCountry ?? country,
                        ehSetting.localizedLiteralHahRegion ?? region
                    )
                )
                .ehSettingRegularHeaderStyled()
            }
        }
    }
}

// MARK: ImageSizeSettingsSection
struct ImageSizeSettingsSection: View {
    @Binding var ehSetting: EhSetting
    let updatingOptions: Set<EhSettingReducer.Option>

    var body: some View {
        Section {
            Picker(.imageResolution, selection: $ehSetting.imageResolution) {
                ForEach(ehSetting.capableImageResolutions) { setting in
                    Text(setting.value)
                        .tag(setting)
                }
            }
            .ehSettingPickerStyled()
            .disabled(updatingOptions.contains(.imageResolution))
        } header: {
            Text.ehSettingBoldHeader(
                .imageSizeSettings,
                description: .imageResolutionDescription
            )
        }

        if let useOriginalImagesBinding = Binding($ehSetting.useOriginalImages) {
            Section {
                AppToggle(
                    .useOriginalImages,
                    isOn: useOriginalImagesBinding
                )
                .disabled(updatingOptions.contains(.useOriginalImages))
            } header: {
                Text(.originalImages)
                    .ehSettingRegularHeaderStyled()
            }
        }

        Section {
            Text(.imageSize)

            ValuePicker(
                title: .horizontal,
                value: $ehSetting.imageSizeWidth, range: 0...65535, unit: "px"
            )
            .disabled(updatingOptions.contains(.imageSizeWidth))

            ValuePicker(
                title: .vertical,
                value: $ehSetting.imageSizeHeight, range: 0...65535, unit: "px"
            )
            .disabled(updatingOptions.contains(.imageSizeHeight))
        } header: {
            Text(.imageSizeDescription)
                .ehSettingRegularHeaderStyled()
        }
    }
}

// MARK: GalleryNameDisplaySection
struct GalleryNameDisplaySection: View {
    @Binding var ehSetting: EhSetting
    let updatingOptions: Set<EhSettingReducer.Option>

    var body: some View {
        Section {
            Picker(.galleryName, selection: $ehSetting.galleryName) {
                ForEach(EhSetting.GalleryName.allCases) { name in
                    Text(name.value)
                        .tag(name)
                }
            }
            .ehSettingPickerStyled()
            .disabled(updatingOptions.contains(.galleryName))
        } header: {
            Text.ehSettingBoldHeader(
                .galleryNameDisplay,
                description: .galleryNameDescription
            )
        }
    }
}

// MARK: ArchiverSettingsSection
struct ArchiverSettingsSection: View {
    @Binding var ehSetting: EhSetting
    let updatingOptions: Set<EhSettingReducer.Option>

    var body: some View {
        Section {
            Picker(.archiverBehavior, selection: $ehSetting.archiverBehavior) {
                ForEach(EhSetting.ArchiverBehavior.allCases) { behavior in
                    Text(behavior.value)
                        .tag(behavior)
                }
            }
            .ehSettingPickerStyled()
            .disabled(updatingOptions.contains(.archiverBehavior))
        } header: {
            Text.ehSettingBoldHeader(
                .archiverSettings,
                description: .archiverBehaviorDescription
            )
        }
    }
}

// MARK: FrontPageSettingsSection
struct FrontPageSettingsSection: View {
    @Binding var ehSetting: EhSetting
    let updatingOptions: Set<EhSettingReducer.Option>

    private var categoryBindings: [Binding<Bool>] {
        $ehSetting.disabledCategories.map({ $0 })
    }

    var body: some View {
        Section {
            CategoryView(
                bindings: categoryBindings,
                disabledIndices: Set(
                    categoryBindings.indices.filter({ updatingOptions.contains(.disabledCategory($0)) })
                )
            )
        } header: {
            Text.ehSettingBoldHeader(
                .frontPageSettings,
                description: .galleryCategory
            )
        }

        Section {
            Picker(.displayMode, selection: $ehSetting.displayMode) {
                ForEach(EhSetting.DisplayMode.allCases) { mode in
                    Text(mode.value)
                        .tag(mode)
                }
            }
            .ehSettingPickerStyled()
            .disabled(updatingOptions.contains(.displayMode))
        } header: {
            Text(.displayModeDescription)
                .ehSettingRegularHeaderStyled()
        }

        Section {
            Picker(.searchRangeIndicator, selection: $ehSetting.searchRangeIndicatorStyle) {
                ForEach(EhSetting.SearchRangeIndicatorStyle.allCases) { style in
                    Text(style.value)
                        .tag(style)
                }
            }
            .ehSettingPickerStyled()
            .disabled(updatingOptions.contains(.searchRangeIndicatorStyle))
        } header: {
            Text(.searchRangeIndicatorDescription)
                .ehSettingRegularHeaderStyled()
        }
    }
}

// MARK: Shared Helpers
/// A slider row whose value saves once per drag.
///
/// Every write to the form saves to the site, so the slider moves a view-local `draft` while the thumb is down and
/// writes the form once, when the drag ends. The label follows the draft. While no drag is in progress the draft
/// follows the form, so a site answer moves the thumb. A change that arrives with no drag session, such as an
/// assistive adjustment, ends no drag, so it is written at once: without that it would never be saved.
struct ValuePicker: View {
    private let title: LocalizedStringResource
    @Binding var value: Float
    private let range: ClosedRange<Float>
    private let unit: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var draft: Float
    @State private var isDragging = false

    init(title: LocalizedStringResource, value: Binding<Float>, range: ClosedRange<Float>, unit: String = "") {
        self.title = title
        _value = value
        self.range = range
        self.unit = unit
        _draft = State(initialValue: value.wrappedValue)
    }

    var body: some View {
        LabeledContent(title) {
            Text(String(Int(draft)) + unit)
                .foregroundStyle(.tint)
        }
        .onChange(of: value) {
            guard !isDragging else { return }
            draft = value
        }
        .onChange(of: draft) {
            guard !isDragging, draft != value else { return }
            value = draft
        }

        if dynamicTypeSize.isAccessibilitySize {
            VStack {
                rangeLabel(range.lowerBound)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Slider(value: $draft, in: range, onEditingChanged: editingChanged)
                    .interactiveHover(.highlight, in: SliderHoverShape())
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(title)

                rangeLabel(range.upperBound)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else {
            Slider(
                value: $draft,
                in: range,
                label: EmptyView.init,
                minimumValueLabel: {
                    rangeLabel(range.lowerBound)
                },
                maximumValueLabel: {
                    rangeLabel(range.upperBound)
                },
                onEditingChanged: editingChanged
            )
            .interactiveHover(.highlight, in: SliderHoverShape())
            .accessibilityLabel(title)
        }
    }

    private func editingChanged(_ isEditing: Bool) {
        isDragging = isEditing
        if !isEditing, draft != value {
            value = draft
        }
    }

    private func rangeLabel(_ value: Float) -> some View {
        Text(String(Int(value)) + unit)
            .fontWeight(.medium)
            .font(.callout)
    }
}

/// A single-line text field whose value saves on Return.
///
/// Every write to the form saves to the site, so the field edits a view-local `draft` and writes the form only on
/// Return. Leaving the field without Return puts the saved value back, so the field never shows text that was not
/// saved. While the field is not focused the draft follows the form, so a site answer shows in it.
struct DraftTextField: View {
    @Binding private var text: String
    @State private var draft: String
    @FocusState private var isFocused: Bool
    private let title: LocalizedStringResource
    private let promptText: LocalizedStringResource?
    private let width: CGFloat?
    private let alignment: TextAlignment
    private let background: Color?

    init(
        text: Binding<String>, title: LocalizedStringResource,
        promptText: LocalizedStringResource? = nil, width: CGFloat? = 50,
        alignment: TextAlignment = .center, background: Color? = nil
    ) {
        _text = text
        self.title = title
        self.promptText = promptText
        self.width = width
        self.alignment = alignment
        self.background = background
        _draft = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        SettingTextField(
            text: $draft, title: title, promptText: promptText,
            width: width, alignment: alignment, background: background
        )
        .focused($isFocused)
        .onSubmit(submit)
        .onChange(of: isFocused) {
            guard !isFocused else { return }
            draft = text
        }
        .onChange(of: text) {
            guard !isFocused else { return }
            draft = text
        }
    }

    private func submit() {
        guard draft != text else { return }
        text = draft
    }
}

}

#Preview("Value picker, default size", traits: .fixedLayout(width: 393, height: 852)) {
    @Previewable @State var value: Float = 0

    Form {
        EhSettingView.ValuePicker(
            title: .horizontal,
            value: $value,
            range: 0...65535,
            unit: "px"
        )
    }
    .environment(\.dynamicTypeSize, .large)
}

#Preview("Value picker, AX5", traits: .fixedLayout(width: 393, height: 852)) {
    @Previewable @State var value: Float = 0

    Form {
        EhSettingView.ValuePicker(
            title: .horizontal,
            value: $value,
            range: 0...65535,
            unit: "px"
        )
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}

/// The Dynamic Type policy for this screen's menu pickers.
///
/// Every value on this page is server-authored prose — "Manual Select, Manual Start (Default)",
/// "Align left, scale if overwidth" — and a `.menu` picker measures its current value as a single
/// line while *wrapping* it once the text reaches accessibility sizes. The row is therefore laid
/// out one line tall while three are drawn, and the value spills across the row's separators, its
/// own section's rounded edges and the neighbouring rows (Phase 16 finding #28). Nothing at the
/// call site can correct that measurement: the value label belongs to the picker, not to us.
///
/// So above the default size the very same native `Picker` renders `.inline` instead, which gives
/// every option a full-width row of its own that wraps freely and leaves the system drawing the
/// selection. At and below `.large` the designed menu row is used verbatim, so the screen's default
/// appearance is unchanged (D-15). Applying this by policy rather than per row matters because the
/// values arrive from the server and any of them can be long in any locale.
///
/// Both halves were reproduced on device at AX5 with a `.menu` picker whose value wrapped to two
/// lines: the row clipped its title against the section's top edge and its value against the
/// separator below, and the identical picker at `.inline` laid the label and all three options out
/// as full-height wrapping rows with the selected one ticked.
struct EhSettingPickerStyle: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ContentBuilder
    func body(content: Content) -> some View {
        if dynamicTypeSize <= .large {
            content.pickerStyle(.menu).cellRowHover()
        } else {
            content.pickerStyle(.inline)
        }
    }
}

extension View {
    /// Applies this screen's Dynamic Type-aware picker style. See ``EhSettingPickerStyle``.
    func ehSettingPickerStyled() -> some View {
        modifier(EhSettingPickerStyle())
    }
}

extension Text {
    static func ehSettingBoldHeader(
        _ title: LocalizedStringResource, description: LocalizedStringResource? = nil
    ) -> Self {
        var result = AttributedString(String(localized: title))
        result.font = .body.weight(.bold)
        if let description {
            var descriptionString = AttributedString("\n\(String(localized: description))")
            descriptionString.font = .subheadline.weight(.regular)
            result.append(descriptionString)
        }
        return Text(result)
    }

    func ehSettingRegularHeaderStyled() -> Self {
        font(.subheadline.weight(.regular))
    }
}
