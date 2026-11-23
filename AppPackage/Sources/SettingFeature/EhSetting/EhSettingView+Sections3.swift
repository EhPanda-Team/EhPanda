import AppComponents
import AppModels
import AppTools
import Dependencies
import HapticsClient
import Resources
import SFSafeSymbols
import SwiftUI

extension EhSettingView {

// MARK: CoverScalingSection
struct CoverScalingSection: View {
    @Binding var ehSetting: EhSetting
    let updatingOptions: Set<EhSettingReducer.Option>

    var body: some View {
        Section {
            ValuePicker(
                title: .scaleFactor,
                value: $ehSetting.coverScaleFactor,
                range: 75...150,
                unit: "%"
            )
            .disabled(updatingOptions.contains(.coverScaleFactor))
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
    let updatingOptions: Set<EhSettingReducer.Option>

    var body: some View {
        Section {
            ValuePicker(
                title: .tagFilteringThreshold,
                value: $ehSetting.tagFilteringThreshold, range: -9999...0
            )
            .disabled(updatingOptions.contains(.tagFilteringThreshold))
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
    let updatingOptions: Set<EhSettingReducer.Option>

    var body: some View {
        Section {
            ValuePicker(
                title: .tagWatchingThreshold,
                value: $ehSetting.tagWatchingThreshold, range: 0...9999
            )
            .disabled(updatingOptions.contains(.tagWatchingThreshold))
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
    let updatingOptions: Set<EhSettingReducer.Option>

    var body: some View {
        Section {
            AppToggle(
                .showFilteredRemovalCount,
                isOn: $ehSetting.showFilteredRemovalCount
            )
            .disabled(updatingOptions.contains(.showFilteredRemovalCount))
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
    let updatingOptions: Set<EhSettingReducer.Option>

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
    ///
    /// `firstIndex` is the `excludedLanguages` index of the row's column 0, so the cell at column `offset` is index
    /// `firstIndex + offset`. The first row's is -1, because its column 0 is the placeholder.
    private var rows: [ExcludedLanguageRow] {
        var remaining = languageBindings[...]
        return languages.enumerated().map { offset, title in
            let leading: [Binding<Bool>] = offset == 0 ? [.constant(false)] : []
            let cells = remaining.prefix(3 - leading.count)
            remaining = remaining.dropFirst(cells.count)
            return ExcludedLanguageRow(
                title: title, bindings: leading + cells, firstIndex: cells.startIndex - leading.count
            )
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
                    ExcludeRow(
                        title: row.title, bindings: row.bindings, isFirstRow: offset == 0,
                        firstIndex: row.firstIndex, updatingOptions: updatingOptions
                    )
                }
            } else {
                ForEach(rows.enumerated(), id: \.offset) { offset, row in
                    ExcludeLanguageBlock(
                        title: row.title, bindings: row.bindings, isFirstRow: offset == 0,
                        firstIndex: row.firstIndex, updatingOptions: updatingOptions
                    )
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

/// One language's row of the exclusion grid: its name, its cells' bindings in column order, and the
/// `excludedLanguages` index of its column 0. See ``ExcludedLanguagesSection``.
private struct ExcludedLanguageRow {
    let title: LocalizedStringResource
    let bindings: [Binding<Bool>]
    let firstIndex: Int
}

struct ExcludeRow: View {
    let title: LocalizedStringResource
    let bindings: [Binding<Bool>]
    let isFirstRow: Bool
    let firstIndex: Int
    let updatingOptions: Set<EhSettingReducer.Option>

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
                        .disabled(updatingOptions.contains(.excludedLanguage(firstIndex + offset)))
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
        Button {
            withAnimation { isOn.toggle() }
            hapticsClient.generateFeedback(.soft)
        } label: {
            Color.clear
                .overlay {
                    Image(systemSymbol: isOn ? .nosign : .circle)
                        .foregroundStyle(isOn ? .red : .primary)
                        .font(.title)
                }
        }
        .buttonStyle(.unhighlighted)
        .interactiveIconHover(clippedAt: [.leading, .trailing])
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
    let firstIndex: Int
    let updatingOptions: Set<EhSettingReducer.Option>

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
                            .disabled(updatingOptions.contains(.excludedLanguage(firstIndex + offset)))
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
/// off a wrapped binding, so it also marks a switch that a site answer moves back after a save that did
/// not take. At the default size the grid's cell, whose feedback belongs to its tap, stays silent then.
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
/// The excluded uploaders editor, saved when editing ends.
///
/// Every write to the form saves to the site, and the editor has no submit, because Return inserts a line. So it
/// edits a view-local `draft` and writes the form when focus leaves it. While the editor is not focused the draft
/// follows the form, so a site answer shows in it. The footer counts the draft, so it follows the typing.
struct ExcludedUploadersSection: View {
    @Binding var ehSetting: EhSetting
    let updatingOptions: Set<EhSettingReducer.Option>
    @State private var draft: String
    @FocusState private var isFocused: Bool

    init(ehSetting: Binding<EhSetting>, updatingOptions: Set<EhSettingReducer.Option>) {
        _ehSetting = ehSetting
        self.updatingOptions = updatingOptions
        _draft = State(initialValue: ehSetting.wrappedValue.excludedUploaders)
    }

    var body: some View {
        Section {
            TextEditor(text: $draft)
                .textInputAutocapitalization(.none)
                // This editor intentionally occupies 30% of the container height rather than
                // merely capping its height, giving the multi-line input a stable editing area.
                .containerRelativeFrame(.vertical) { height, _ in height * 0.3 }
                .autocorrectionDisabled(true)
                .focused($isFocused)
                .disabled(updatingOptions.contains(.excludedUploaders))
        } header: {
            Text.ehSettingBoldHeader(
                .excludedUploaders,
                description: .excludedUploadersDescription
            )
        } footer: {
            Text(
                .excludedUploadersCount(
                    used: draft.ehSettingLineCount, limit: 1000
                )
            )
        }
        .onChange(of: isFocused) {
            guard !isFocused, draft != ehSetting.excludedUploaders else { return }
            ehSetting.excludedUploaders = draft
        }
        .onChange(of: ehSetting.excludedUploaders) {
            guard !isFocused else { return }
            draft = ehSetting.excludedUploaders
        }
    }
}

// MARK: ViewportOverrideSection
struct ViewportOverrideSection: View {
    @Binding var ehSetting: EhSetting
    let updatingOptions: Set<EhSettingReducer.Option>

    var body: some View {
        Section {
            ValuePicker(
                title: .virtualWidth,
                value: $ehSetting.viewportVirtualWidth,
                range: 0...9999,
                unit: "px"
            )
            .disabled(updatingOptions.contains(.viewportVirtualWidth))
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
    let updatingOptions: Set<EhSettingReducer.Option>

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
            .disabled(updatingOptions.contains(.commentsSortOrder))

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
            .disabled(updatingOptions.contains(.commentVotesShowTiming))
        } header: {
            Text(.galleryComments)
                .ehSettingRegularHeaderStyled()
        }
    }
}

// MARK: GalleryTagsSection
struct GalleryTagsSection: View {
    @Binding var ehSetting: EhSetting
    let updatingOptions: Set<EhSettingReducer.Option>

    var body: some View {
        Section {
            Picker(.tagsSortOrder, selection: $ehSetting.tagsSortOrder) {
                ForEach(EhSetting.TagsSortOrder.allCases) { order in
                    Text(order.value)
                        .tag(order)
                }
            }
            .ehSettingPickerStyled()
            .disabled(updatingOptions.contains(.tagsSortOrder))
        } header: {
            Text(.galleryTags)
                .ehSettingRegularHeaderStyled()
        }
    }
}

// MARK: GalleryPageThumbnailLabelingSection
struct GalleryPageThumbnailLabelingSection: View {
    @Binding var ehSetting: EhSetting
    let updatingOptions: Set<EhSettingReducer.Option>

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
            .disabled(updatingOptions.contains(.galleryPageNumbering))
        } header: {
            Text(.galleryPageThumbnailLabeling)
                .ehSettingRegularHeaderStyled()
        }
    }
}

// MARK: MultiplePageViewerSection
struct MultiplePageViewerSection: View {
    @Binding var ehSetting: EhSetting
    let updatingOptions: Set<EhSettingReducer.Option>

    var body: some View {
        if let useMultiplePageViewerBinding = Binding($ehSetting.useMultiplePageViewer),
           let multiplePageViewerStyleBinding = Binding($ehSetting.multiplePageViewerStyle),
           let multiplePageViewerShowPaneBinding = Binding($ehSetting.multiplePageViewerShowThumbnailPane) {
            Section {
                AppToggle(
                    .useMultiPageViewer,
                    isOn: useMultiplePageViewerBinding
                )
                .disabled(updatingOptions.contains(.useMultiplePageViewer))

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
                .disabled(updatingOptions.contains(.multiplePageViewerStyle))

                AppToggle(
                    .showThumbnailPane,
                    isOn: multiplePageViewerShowPaneBinding
                )
                .disabled(updatingOptions.contains(.multiplePageViewerShowThumbnailPane))
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
            EhSettingView.ExcludedLanguagesSection(ehSetting: $ehSetting, updatingOptions: [])
        }
    }
    .environment(\.dynamicTypeSize, .large)
}

#Preview("Excluded languages, AX3") {
    @Previewable @State var ehSetting = excludedLanguagesPreviewSetting

    NavigationStack {
        Form {
            EhSettingView.ExcludedLanguagesSection(ehSetting: $ehSetting, updatingOptions: [])
        }
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
