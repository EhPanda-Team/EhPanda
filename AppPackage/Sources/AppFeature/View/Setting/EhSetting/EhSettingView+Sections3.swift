import SwiftUI
import AppModels
import Resources

extension EhSettingView {

// MARK: CoverScalingSection
struct CoverScalingSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            ValuePicker(
                title: L10n.Localizable.EhSettingView.Title.scaleFactor,
                value: $ehSetting.coverScaleFactor,
                range: 75...150,
                unit: "%"
            )
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.Section.Title.coverScaling,
                description: L10n.Localizable.EhSettingView.Description.coverScaleFactor
            )
        }
    }
}

// MARK: TagFilteringThresholdSection
struct TagFilteringThresholdSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            ValuePicker(
                title: L10n.Localizable.EhSettingView.Title.tagFilteringThreshold,
                value: $ehSetting.tagFilteringThreshold, range: -9999...0
            )
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.Section.Title.tagFilteringThreshold,
                description: L10n.Localizable.EhSettingView.Description.tagFilteringThreshold
            )
        }
    }
}

// MARK: TagWatchingThresholdSection
struct TagWatchingThresholdSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            ValuePicker(
                title: L10n.Localizable.EhSettingView.Title.tagWatchingThreshold,
                value: $ehSetting.tagWatchingThreshold, range: 0...9999
            )
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.Section.Title.tagWatchingThreshold,
                description: L10n.Localizable.EhSettingView.Description.tagWatchingThreshold
            )
        }
    }
}

// MARK: FilteredRemovalCountSection
struct FilteredRemovalCountSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            Toggle(
                L10n.Localizable.EhSettingView.Title.showFilteredRemovalCount,
                isOn: $ehSetting.showFilteredRemovalCount
            )
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.Section.Title.filteredRemovalCount,
                description: L10n.Localizable.EhSettingView.Description.filteredRemovalCount
            )
        }
    }
}

// MARK: ExcludedLanguagesSection
struct ExcludedLanguagesSection: View {
    @Binding var ehSetting: EhSetting

    private let languages = Language.allExcludedCases.map(\.value)
    private var languageBindings: [Binding<Bool>] {
        $ehSetting.excludedLanguages.map({ $0 })
    }
    private func rowBindings(index: Int) -> [Binding<Bool>] {
        [-1, 0, 1].map { num in
            let index = index * 3 + num
            if index != -1 {
                return languageBindings[index]
            } else {
                return .constant(false)
            }
        }
    }

    var body: some View {
        Section {
            HStack {
                Text("")
                    .frame(width: DeviceUtil.windowW * 0.25)

                ForEach(EhSetting.ExcludedLanguagesCategory.allCases) { category in
                    Color.clear
                        .overlay {
                            Text(category.value)
                                .lineLimit(1)
                                .font(.subheadline)
                                .fixedSize()
                        }
                }
            }

            ForEach(0..<(languageBindings.count / 3) + 1, id: \.self) { index in
                ExcludeRow(
                    title: languages[index],
                    bindings: rowBindings(index: index),
                    isFirstRow: index == 0
                )
            }
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.Section.Title.excludedLanguages,
                description: L10n.Localizable.EhSettingView.Description.excludedLanguages
            )
        }
    }
}

struct ExcludeRow: View {
    let title: String
    let bindings: [Binding<Bool>]
    let isFirstRow: Bool

    var body: some View {
        HStack {
            Text(title)
                .lineLimit(1)
                .font(.subheadline)
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(width: DeviceUtil.windowW * 0.25)

            ForEach(0..<bindings.count, id: \.self) { index in
                let shouldHide = isFirstRow && index == 0
                ExcludeToggle(isOn: bindings[index]).opacity(shouldHide ? 0 : 1)
            }
        }
    }
}

struct ExcludeToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Color.clear
            .overlay {
                Image(systemSymbol: isOn ? .nosign : .circle)
                    .foregroundColor(isOn ? .red : .primary)
                    .font(.title)
            }
            .onTapGesture {
                withAnimation { isOn.toggle() }
                HapticsUtil.generateFeedback(style: .soft)
            }
    }
}

// MARK: ExcludedUploadersSection
struct ExcludedUploadersSection: View {
    @Binding var ehSetting: EhSetting
    @FocusState var isFocused

    var body: some View {
        Section {
            TextEditor(text: $ehSetting.excludedUploaders)
                .textInputAutocapitalization(.none)
                .frame(maxHeight: DeviceUtil.windowH * 0.3)
                .disableAutocorrection(true)
                .focused($isFocused)
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.Section.Title.excludedUploaders,
                description: L10n.Localizable.EhSettingView.Description.excludedUploaders
            )
        } footer: {
            Text(
                L10n.Localizable.EhSettingView.Description.excludedUploadersCount(
                    "\(ehSetting.excludedUploaders.ehSettingLineCount)", "\(1000)"
                )
                .localizedKey
            )
        }
    }
}

// MARK: ViewportOverrideSection
struct ViewportOverrideSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            ValuePicker(
                title: L10n.Localizable.EhSettingView.Title.virtualWidth,
                value: $ehSetting.viewportVirtualWidth,
                range: 0...9999,
                unit: "px"
            )
        } header: {
            Text.ehSettingBoldHeader(
                L10n.Localizable.EhSettingView.Section.Title.viewportOverride,
                description: L10n.Localizable.EhSettingView.Description.virtualWidth
            )
        }
    }
}

// MARK: GalleryCommentsSection
struct GalleryCommentsSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            Picker(
                L10n.Localizable.EhSettingView.Title.commentsSortOrder,
                selection: $ehSetting.commentsSortOrder
            ) {
                ForEach(EhSetting.CommentsSortOrder.allCases) { order in
                    Text(order.value)
                        .tag(order)
                }
            }
            .pickerStyle(.menu)

            Picker(
                L10n.Localizable.EhSettingView.Title.commentsVotesShowTiming,
                selection: $ehSetting.commentVotesShowTiming
            ) {
                ForEach(EhSetting.CommentVotesShowTiming.allCases) { timing in
                    Text(timing.value)
                        .tag(timing)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.galleryComments)
                .ehSettingRegularHeaderStyled()
        }
    }
}

// MARK: GalleryTagsSection
struct GalleryTagsSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            Picker(L10n.Localizable.EhSettingView.Title.tagsSortOrder, selection: $ehSetting.tagsSortOrder) {
                ForEach(EhSetting.TagsSortOrder.allCases) { order in
                    Text(order.value)
                        .tag(order)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.galleryTags)
                .ehSettingRegularHeaderStyled()
        }
    }
}

// MARK: GalleryPageThumbnailLabelingSection
struct GalleryPageThumbnailLabelingSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            Picker(
                L10n.Localizable.EhSettingView.Title.showLabelBelowGalleryThumbnails,
                selection: $ehSetting.galleryPageNumbering
            ) {
                ForEach(EhSetting.GalleryPageNumbering.allCases) { behavior in
                    Text(behavior.value)
                        .tag(behavior)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(L10n.Localizable.EhSettingView.Section.Title.galleryPageThumbnailLabeling)
                .ehSettingRegularHeaderStyled()
        }
    }
}

// MARK: MultiplePageViewerSection
struct MultiplePageViewerSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        if let useMultiplePageViewerBinding = Binding($ehSetting.useMultiplePageViewer),
           let multiplePageViewerStyleBinding = Binding($ehSetting.multiplePageViewerStyle),
           let multiplePageViewerShowPaneBinding = Binding($ehSetting.multiplePageViewerShowThumbnailPane) {
            Section {
                Toggle(
                    L10n.Localizable.EhSettingView.Title.useMultiPageViewer,
                    isOn: useMultiplePageViewerBinding
                )

                Picker(
                    L10n.Localizable.EhSettingView.Title.displayStyle,
                    selection: multiplePageViewerStyleBinding
                ) {
                    ForEach(EhSetting.MultiplePageViewerStyle.allCases) { style in
                        Text(style.value)
                            .tag(style)
                    }
                }
                .pickerStyle(.menu)

                Toggle(
                    L10n.Localizable.EhSettingView.Title.showThumbnailPane,
                    isOn: multiplePageViewerShowPaneBinding
                )
            } header: {
                Text(L10n.Localizable.EhSettingView.Section.Title.multiPageViewer)
                    .ehSettingRegularHeaderStyled()
            }
        }
    }
}

}

extension String {
    var ehSettingLineCount: Int {
        var count = 0
        enumerateLines { line, _ in
            if !line.isEmpty {
                count += 1
            }
        }
        return count
    }
}
