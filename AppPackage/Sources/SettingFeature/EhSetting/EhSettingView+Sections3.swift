import SwiftUI
import AppModels
import Resources
import AppTools
import Dependencies
import HapticsClient
import AppComponents

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
                description: .coverScaleFactor(
                    75.formatted(.percent),
                    150.formatted(.percent)
                )
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
            AppToggle(
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

    /// One row per language, three toggle cells wide (original / translated / rewrite).
    ///
    /// The grid's very first cell is a placeholder — the toggle list starts one slot in, so the
    /// first row carries two real toggles and every later row carries three. Consuming the
    /// bindings through a shrinking slice keeps that offset out of the row arithmetic, and a
    /// short `excludedLanguages` (a settings page that parsed light) simply yields empty
    /// trailing cells instead of an out-of-range read.
    private var rows: [(title: LocalizedStringResource, bindings: [Binding<Bool>])] {
        var remaining = languageBindings[...]
        return languages.enumerated().map { offset, title in
            let leading: [Binding<Bool>] = offset == 0 ? [.constant(false)] : []
            let cells = remaining.prefix(3 - leading.count)
            remaining = remaining.dropFirst(cells.count)
            return (title, leading + cells)
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

            ForEach(rows.enumerated(), id: \.offset) { offset, row in
                ExcludeRow(title: row.title, bindings: row.bindings, isFirstRow: offset == 0)
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
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .containerRelativeFrame(.horizontal) { width, _ in width * 0.25 }

            ForEach(bindings.enumerated(), id: \.offset) { offset, binding in
                ExcludeToggle(isOn: binding).opacity(isFirstRow && offset == 0 ? 0 : 1)
            }
        }
    }
}

struct ExcludeToggle: View {
    @Dependency(\.hapticsClient) private var hapticsClient
    @Binding var isOn: Bool

    var body: some View {
        Color.clear
            .overlay {
                Image(systemSymbol: isOn ? .nosign : .circle)
                    .foregroundStyle(isOn ? .red : .primary)
                    .font(.title)
            }
            .onTapGesture {
                withAnimation { isOn.toggle() }
                hapticsClient.generateFeedback(.soft)
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
                .autocorrectionDisabled(true)
                .focused($isFocused)
        } header: {
            Text.ehSettingBoldHeader(
                .excludedUploaders,
                description: .excludedUploadersDescription
            )
        } footer: {
            Text(
                .excludedUploadersCount(
                    used: ehSetting.excludedUploaders.ehSettingLineCount, limit: 1000
                )
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
                description: .virtualWidthDescription(100.formatted(.percent))
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
                AppToggle(
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

                AppToggle(
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
