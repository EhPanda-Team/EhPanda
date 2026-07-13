import SwiftUI
import AppModels
import Resources
import AppTools

extension EhSettingView {

// MARK: CoverScalingSection
struct CoverScalingSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            ValuePicker(
                title: .scaleFactor,
                value: $ehSetting.coverScaleFactor,
                range: 75...150,
                unit: "%"
            )
        } header: {
            Text.ehSettingBoldHeader(
                .coverScaling,
                description: .coverScaleFactor
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
                title: .tagFilteringThreshold,
                value: $ehSetting.tagFilteringThreshold, range: -9999...0
            )
        } header: {
            Text.ehSettingBoldHeader(
                .tagFilteringThreshold,
                description: .tagFilteringThresholdDescription
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
                title: .tagWatchingThreshold,
                value: $ehSetting.tagWatchingThreshold, range: 0...9999
            )
        } header: {
            Text.ehSettingBoldHeader(
                .tagWatchingThreshold,
                description: .tagWatchingThresholdDescription
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
                .showFilteredRemovalCount,
                isOn: $ehSetting.showFilteredRemovalCount
            )
        } header: {
            Text.ehSettingBoldHeader(
                .filteredRemovalCount,
                description: .filteredRemovalCountDescription
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
                // Blank corner above the language column; the hidden label names the column and
                // supplies the row's line height (the category cells below are height-less Color.clear).
                Text(.RLocalizable.language)
                    .hidden()
                    .containerRelativeFrame(.horizontal) { width, _ in width * 0.25 }

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
                .excludedLanguages,
                description: .excludedLanguagesDescription
            )
        }
    }
}

struct ExcludeRow: View {
    let title: LocalizedStringResource
    let bindings: [Binding<Bool>]
    let isFirstRow: Bool

    var body: some View {
        HStack {
            Text(title)
                .lineLimit(1)
                .font(.subheadline)
                .fixedSize()
                .frame(maxWidth: .infinity, alignment: .leading)
                .containerRelativeFrame(.horizontal) { width, _ in width * 0.25 }

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
                // This editor intentionally occupies 30% of the container height rather than
                // merely capping its height, giving the multi-line input a stable editing area.
                .containerRelativeFrame(.vertical) { height, _ in height * 0.3 }
                .disableAutocorrection(true)
                .focused($isFocused)
        } header: {
            Text.ehSettingBoldHeader(
                .excludedUploaders,
                description: .excludedUploadersDescription
            )
        } footer: {
            Text(
                String(localized: .excludedUploadersCount(
                    used: ehSetting.excludedUploaders.ehSettingLineCount, limit: 1000
                ))
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
                title: .virtualWidth,
                value: $ehSetting.viewportVirtualWidth,
                range: 0...9999,
                unit: "px"
            )
        } header: {
            Text.ehSettingBoldHeader(
                .viewportOverride,
                description: .virtualWidthDescription
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
                .commentsSortOrder,
                selection: $ehSetting.commentsSortOrder
            ) {
                ForEach(EhSetting.CommentsSortOrder.allCases) { order in
                    Text(order.value)
                        .tag(order)
                }
            }
            .pickerStyle(.menu)

            Picker(
                .commentsVotesShowTiming,
                selection: $ehSetting.commentVotesShowTiming
            ) {
                ForEach(EhSetting.CommentVotesShowTiming.allCases) { timing in
                    Text(timing.value)
                        .tag(timing)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(.galleryComments)
                .ehSettingRegularHeaderStyled()
        }
    }
}

// MARK: GalleryTagsSection
struct GalleryTagsSection: View {
    @Binding var ehSetting: EhSetting

    var body: some View {
        Section {
            Picker(.tagsSortOrder, selection: $ehSetting.tagsSortOrder) {
                ForEach(EhSetting.TagsSortOrder.allCases) { order in
                    Text(order.value)
                        .tag(order)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(.galleryTags)
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
                .showLabelBelowGalleryThumbnails,
                selection: $ehSetting.galleryPageNumbering
            ) {
                ForEach(EhSetting.GalleryPageNumbering.allCases) { behavior in
                    Text(behavior.value)
                        .tag(behavior)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(.galleryPageThumbnailLabeling)
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
                    .useMultiPageViewer,
                    isOn: useMultiplePageViewerBinding
                )

                Picker(
                    .displayStyle,
                    selection: multiplePageViewerStyleBinding
                ) {
                    ForEach(EhSetting.MultiplePageViewerStyle.allCases) { style in
                        Text(style.value)
                            .tag(style)
                    }
                }
                .pickerStyle(.menu)

                Toggle(
                    .showThumbnailPane,
                    isOn: multiplePageViewerShowPaneBinding
                )
            } header: {
                Text(.multiPageViewer)
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
