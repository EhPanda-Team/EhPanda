import AppComponents
import AppModels
import AppTools
import Dependencies
import HapticsClient
import Resources
import SwiftUI

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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

    /// The three-column radio matrix is kept verbatim at and below the default size and abandoned
    /// above it (Phase 16 finding #27).
    ///
    /// The grid's whole meaning lives in its column headers: twenty-odd rows of identical circles
    /// say nothing on their own. Those headers are three separate words centred over height-less
    /// columns, and no arrangement of them survives accessibility widths — a quarter of the row goes
    /// to the language name and each column gets a third of what is left, which is narrower than a
    /// single scaled word. Wrapping them would only trade today's overlap for three columns of
    /// stacked letters, and the circles they label would still be indistinguishable.
    ///
    /// So above the default size the matrix stops being a matrix. Each language becomes a block
    /// headed by its own name, and its three exclusions become plain labelled switches underneath.
    /// Every option then carries the word that names it instead of inheriting it from a column
    /// position — which is also what VoiceOver gains, since the circles announce nothing but their
    /// own symbol today.
    var body: some View {
        Section {
            if dynamicTypeSize <= .large {
                columnHeader
                ForEach(rows.enumerated(), id: \.offset) { offset, row in
                    ExcludeRow(title: row.title, bindings: row.bindings, isFirstRow: offset == 0)
                }
            } else {
                ForEach(rows.enumerated(), id: \.offset) { offset, row in
                    ExcludeLanguageBlock(title: row.title, bindings: row.bindings, isFirstRow: offset == 0)
                }
            }
        } header: {
            Text.ehSettingBoldHeader(
                .excludedLanguages,
                description: .excludedLanguagesDescription
            )
        }
    }

    private var columnHeader: some View {
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
                if isFirstRow && offset == 0 {
                    // The first row has no `original` variant, but its slot has to stay so the rows
                    // below line up under it. An inert placeholder rather than the toggle drawn at
                    // zero opacity: an invisible control is still tappable and still an
                    // accessibility element, so it would offer to flip a binding that has no cell.
                    Color.clear
                } else if let category = EhSetting.ExcludedLanguagesCategory(rawValue: offset) {
                    ExcludeToggle(title: title, category: category, isOn: binding)
                }
            }
        }
    }
}

/// One cell of the exclusion grid: a circle that becomes a no-sign when the language is excluded.
///
/// Visually the cell is a bare glyph whose meaning comes from the language name at the row's start
/// and the category word at the column's top. Assistive technologies see none of that geometry,
/// so the cell is presented to them as a system `Toggle` named "Exclude <language> <category>":
/// the representation supplies the label, the on/off value, the toggle trait and the Voice
/// Control name in one move, while the rendered glyph and its tap feedback stay exactly as
/// designed.
struct ExcludeToggle: View {
    @Dependency(\.hapticsClient) private var hapticsClient
    let title: LocalizedStringResource
    let category: EhSetting.ExcludedLanguagesCategory
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
            .accessibilityRepresentation {
                Toggle(isOn: $isOn) {
                    Text(.accessibilityExcludeLanguage(String(localized: title), String(localized: category.value)))
                }
            }
    }
}

/// One language's exclusions as a self-contained block, for the sizes at which the grid is dropped.
/// See ``EhSettingView/ExcludedLanguagesSection``.
///
/// `bindings` arrives in column order, so a cell's offset *is* its `ExcludedLanguagesCategory` raw
/// value — including on the first row, whose placeholder occupies the `original` slot the grid draws
/// at zero opacity. Here there are no columns to keep aligned, so that cell is simply not built
/// rather than drawn invisibly.
///
/// Spacing is chosen for a block that is now a heading over three controls rather than a row of
/// circles: 16 points sets the language name off from the options it governs, 12 points separates
/// the options from each other, and 6 points of vertical padding widens the gap the `List`
/// separator already puts between one language and the next. The horizontal margins are the form
/// row's own and are untouched, so no label sits closer to the edge than the grid's did.
struct ExcludeLanguageBlock: View {
    let title: LocalizedStringResource
    let bindings: [Binding<Bool>]
    let isFirstRow: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(bindings.enumerated(), id: \.offset) { offset, binding in
                    if !(isFirstRow && offset == 0),
                       let category = EhSetting.ExcludedLanguagesCategory(rawValue: offset) {
                        ExcludeLanguageToggle(category: category, isOn: binding)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

/// A single exclusion, named by its category so its meaning never depends on a column position.
///
/// The switch stands in for the grid's tap target and fires the same soft feedback, so flipping an
/// exclusion feels the same at every size; the system control brings the label, the on/off value
/// and the hit target that the bare `Image` never had. The feedback hangs off the value rather than
/// off a wrapped binding because the exclusion is only ever flipped from this switch — the settings
/// payload is fetched once per profile and never toggles a language behind the user's back.
struct ExcludeLanguageToggle: View {
    @Dependency(\.hapticsClient) private var hapticsClient
    let category: EhSetting.ExcludedLanguagesCategory
    @Binding var isOn: Bool

    var body: some View {
        AppToggle(category.value, isOn: $isOn)
            .onChange(of: isOn) {
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
            .ehSettingPickerStyled()

            Picker(
                .commentsVotesShowTiming,
                selection: $ehSetting.commentVotesShowTiming
            ) {
                ForEach(EhSetting.CommentVotesShowTiming.allCases) { timing in
                    Text(timing.value)
                        .tag(timing)
                }
            }
            .ehSettingPickerStyled()
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
            .ehSettingPickerStyled()
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
            .ehSettingPickerStyled()
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
                .ehSettingPickerStyled()

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

// A couple of exclusions are switched on so both states of a cell are visible in either layout:
// index 0 is Japanese › translated (the first row has no `original` cell) and index 3 is
// English › translated.
private var excludedLanguagesPreviewSetting: EhSetting {
    var setting = EhSetting.empty
    setting.excludedLanguages = setting.excludedLanguages.enumerated().map { offset, isExcluded in
        offset == 0 || offset == 3 || isExcluded
    }
    return setting
}

#Preview("Excluded languages, default size") {
    @Previewable @State var ehSetting = excludedLanguagesPreviewSetting

    NavigationStack {
        Form {
            EhSettingView.ExcludedLanguagesSection(ehSetting: $ehSetting)
        }
    }
    .environment(\.dynamicTypeSize, .large)
}

#Preview("Excluded languages, AX3") {
    @Previewable @State var ehSetting = excludedLanguagesPreviewSetting

    NavigationStack {
        Form {
            EhSettingView.ExcludedLanguagesSection(ehSetting: $ehSetting)
        }
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
