import AppModels
import AppTools
import Dependencies
import HapticsClient
import Sharing
import SwiftUI

// MARK: CategoryLabel
/// A category name drawn white-on-colour inside a small rounded badge.
///
/// Every metric of the badge is proportional to the glyphs it wraps, not a fixed number of points:
/// a radius and an inset designed against a 13pt footnote read as a hairline and a hairline of air
/// once the same text is drawn three times taller, so the badge degenerates into a square block
/// with the text jammed against its sides. The caller therefore names a *text style* rather than a
/// `Font`, and that style is the reference the corner radius and the four insets scale against, so
/// the designed proportion between glyph height, breathing room and corner survives the whole type
/// ramp. `@ScaledMetric` is identity at `.large`, so the badge renders exactly as designed there.
///
/// The text keeps `.lineLimit(1)` at and below the default size, where the badge has the width for
/// the eleven fixed category names and one line is a chosen budget rather than a truncation risk.
/// That argument holds only while the badge has that width: above the default size the same names
/// are drawn several times wider inside a cover corner or a list row that never grew with them, and
/// a name cut to `Doujin…` stops naming a category — two different categories become one badge,
/// which is information the interface no longer provides (D-03/D-04). So the cap is lifted there and
/// a name that does not fit wraps instead. The vocabulary is fixed and short, so a wrapped badge is
/// at most two short lines, and the badge is always offered a bounded width (a cover's, a row's), so
/// it grows downwards rather than outwards.
public struct CategoryLabel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let text: LocalizedStringResource
    private let color: Color
    private let textStyle: Font.TextStyle
    @ScaledMetric private var topInset: CGFloat
    @ScaledMetric private var leadingInset: CGFloat
    @ScaledMetric private var bottomInset: CGFloat
    @ScaledMetric private var trailingInset: CGFloat
    @ScaledMetric private var cornerRadius: CGFloat

    public init(
        text: LocalizedStringResource, color: Color, textStyle: Font.TextStyle = .footnote,
        insets: EdgeInsets = .init(top: 1, leading: 3, bottom: 1, trailing: 3),
        cornerRadius: CGFloat = 2
    ) {
        self.text = text
        self.color = color
        self.textStyle = textStyle
        // Initialised here rather than at the declaration because every one of them scales relative
        // to the caller's `textStyle`, which is only known once the badge is constructed.
        _topInset = ScaledMetric(wrappedValue: insets.top, relativeTo: textStyle)
        _leadingInset = ScaledMetric(wrappedValue: insets.leading, relativeTo: textStyle)
        _bottomInset = ScaledMetric(wrappedValue: insets.bottom, relativeTo: textStyle)
        _trailingInset = ScaledMetric(wrappedValue: insets.trailing, relativeTo: textStyle)
        _cornerRadius = ScaledMetric(wrappedValue: cornerRadius, relativeTo: textStyle)
    }

    private var scaledInsets: EdgeInsets {
        .init(top: topInset, leading: leadingInset, bottom: bottomInset, trailing: trailingInset)
    }

    /// See the type's documentation: one line is the designed budget while the badge has the width
    /// for it, and no cap at all once it does not.
    private var lineLimit: Int? {
        dynamicTypeSize <= .large ? 1 : nil
    }

    public var body: some View {
        Text(text)
            // `.system(textStyle)` with no design or weight override is the same font as the
            // matching `Font` constant, so naming the style costs the call sites nothing.
            .font(.system(textStyle).bold())
            .lineLimit(lineLimit)
            .foregroundStyle(.white)
            .padding(scaledInsets)
            .background(
                Rectangle().foregroundStyle(color).clipShape(.rect(cornerRadius: cornerRadius))
            )
    }
}

// MARK: CategoryView
/// The grid of category toggles shown in the Filters sheet and in the EhSetting front-page section.
///
/// The adaptive column bounds are the designed 80 / 100 / 100 points scaled against `.body` — the
/// style a cell's name is drawn in — so a column widens at the rate of the label it has to hold
/// rather than keeping the width it was designed at, which is what used to eat the names from the
/// right one size step at a time. `@ScaledMetric` is identity at `.large`, so the designed grid
/// (three columns across a phone's sheet) renders there unchanged; above it the same rule fits
/// fewer, wider cells (P-07).
public struct CategoryView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// The designed minimum column width, one value per size class, and the shared maximum.
    /// Declared as three metrics rather than one scaled multiplier so each designed number stays
    /// legible as the number it is.
    @ScaledMetric(relativeTo: .body) private var compactColumnMinimum: CGFloat = 80
    @ScaledMetric(relativeTo: .body) private var regularColumnMinimum: CGFloat = 100
    @ScaledMetric(relativeTo: .body) private var columnMaximum: CGFloat = 100
    @State private var gridWidth: CGFloat = .zero

    private let bindings: [Binding<Bool>]

    /// A scaled bound that has outgrown the grid itself would ask for a column wider than the sheet
    /// that holds it, so both ends are clamped to the measured width: the extreme sizes land on one
    /// column spanning the whole grid instead of one overflowing it. Clamping both by the same
    /// ceiling keeps the minimum at or below the maximum. Before the first measurement — and it is
    /// the grid's own container that decides that width, so no measurement feeds back into it — the
    /// designed bounds stand.
    private var gridItems: [GridItem] {
        let minimum = horizontalSizeClass == .regular ? regularColumnMinimum : compactColumnMinimum
        let ceiling = gridWidth > .zero ? gridWidth : .greatestFiniteMagnitude
        return [GridItem(.adaptive(minimum: min(minimum, ceiling), maximum: min(columnMaximum, ceiling)))]
    }
    private var tuples: [(Binding<Bool>, AppModels.Category)] {
        AppModels.Category.allFiltersCases.enumerated().map { value in
            (bindings[value.offset], value.element)
        }
    }

    public init?(bindings: [Binding<Bool>]) {
        guard bindings.count == 10 else { return nil }
        self.bindings = bindings
    }

    public var body: some View {
        LazyVGrid(columns: gridItems) {
            ForEach(tuples, id: \.1) { isFiltered, category in
                CategoryCell(isFiltered: isFiltered, category: category)
            }
        }
        .padding(.vertical)
        .onGeometryChange(for: CGFloat.self, of: \.size.width) {
            gridWidth = $0
        }
    }
}

// MARK: CategoryCell
/// One category tile of the Filters grid: a `Button` whose visible name is its label, so VoiceOver
/// reaches it as a button and Voice Control lists it under the name on the tile (D-20, D-30).
///
/// The tile's colour carries the category and its opacity carries the filter state (CATEGORYCELL=A
/// keeps the designed 0.3 wash for an excluded category, with no extra visible cue). Neither is a
/// name and neither is readable by assistive technology, so the state is exposed as the
/// `.isSelected` trait instead of being spelled into a label: a trait is re-announced on its own
/// when it changes, where a state baked into the label would re-read the whole label.
///
/// The name is white on every tile, like `CategoryLabel`'s, and a press draws nothing
/// (`.unhighlighted`): the tile keeps its designed look in every state (owner decision, 2026-09-15).
private struct CategoryCell: View {
    @Dependency(\.hapticsClient) private var hapticsClient
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @SharedReader(.setting) private var setting: Setting
    @Binding private var isFiltered: Bool
    private let category: AppModels.Category

    /// The designed opacity of an excluded tile.
    private static let excludedOpacity = 0.3

    /// The designed 5pt breathing room above and below the name, scaled with the name itself: at
    /// the designed size it is a third of a line, and a fixed 5 under text drawn three times taller
    /// would be a hairline. Identity at `.large`.
    @ScaledMetric(relativeTo: .body) private var verticalInset: CGFloat = 5
    /// A wrapped name runs the full width of its cell, where the designed single centred line never
    /// did, so above the default size it gets an inset that keeps it off the cell's rounded corners.
    /// At and below `.large` the cell stays inset-free: the longest names already fill the designed
    /// column edge to edge there, and taking points from them would truncate the very names this
    /// fix is about.
    @ScaledMetric(relativeTo: .body) private var wrappedNameInset: CGFloat = 4
    /// The designed 5pt corner, scaled with the name it wraps. The cell was designed as a rounded
    /// tile, and a corner is only read as round in proportion to the tile it turns: 5pt on the
    /// designed cell is a sixth of its height, and the same 5pt on a cell three times taller is a
    /// hairline that reads as a right angle — the tile stops being the shape it was designed as.
    /// Scaling the radius against `.body`, the style the name is drawn in and the same reference
    /// the insets above use, holds that proportion across the whole ramp. This is the badge's
    /// argument exactly (`CategoryLabel`). Identity at `.large`, where 5 is the designed radius.
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = 5

    init(isFiltered: Binding<Bool>, category: AppModels.Category) {
        _isFiltered = isFiltered
        self.category = category
    }

    /// The name is the cell's only label, and the colour beside it is not a name: at and below the
    /// default size the designed single line is kept verbatim, and above it the cap is lifted so a
    /// name that still does not fit its widened column wraps rather than losing its tail (P-10).
    private var nameLineLimit: Int? {
        dynamicTypeSize <= .large ? 1 : nil
    }

    private var horizontalInset: CGFloat {
        dynamicTypeSize <= .large ? .zero : wrappedNameInset
    }

    private var tileColor: Color {
        category.color(host: setting.galleryHost)
    }

    var body: some View {
        Button {
            isFiltered.toggle()
            hapticsClient.generateFeedback(.soft)
        } label: {
            Text(category.value)
                .bold()
                .foregroundStyle(.white)
                .padding(.vertical, verticalInset)
                .padding(.horizontal, horizontalInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .lineLimit(nameLineLimit)
                .background {
                    Rectangle()
                        .animation(.default) {
                            $0.foregroundStyle(tileColor.opacity(isFiltered ? Self.excludedOpacity : 1))
                        }
                }
                .clipShape(.rect(cornerRadius: cornerRadius))
        }
        .buttonStyle(.unhighlighted)
        // The binding's sense is inverted relative to the trait: `isFiltered == true` means the
        // category is *excluded* from results, so the tile reads as selected exactly when it is
        // not filtered. Passing `[]` rather than removing the trait keeps the modifier unconditional.
        .accessibilityAddTraits(isFiltered ? [] : .isSelected)
    }
}

// MARK: Previews
/// The ten filter bindings the grid takes, over a width that stands in for the sheet's own.
private struct CategoryGridPreview: View {
    @State private var isFiltered = [Bool](repeating: false, count: 10)

    var body: some View {
        CategoryView(bindings: Array($isFiltered))
            .padding(.horizontal)
    }
}

#Preview("Compact, default size", traits: .sizeThatFitsLayout) {
    CategoryGridPreview().frame(width: 330)
}

#Preview("Compact, XXXL", traits: .sizeThatFitsLayout) {
    CategoryGridPreview()
        .frame(width: 330)
        .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("Compact, accessibility 3", traits: .sizeThatFitsLayout) {
    CategoryGridPreview()
        .frame(width: 330)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Compact, accessibility 5", traits: .sizeThatFitsLayout) {
    CategoryGridPreview()
        .frame(width: 330)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Regular, default size", traits: .sizeThatFitsLayout) {
    CategoryGridPreview()
        .frame(width: 640)
        .environment(\.horizontalSizeClass, .regular)
}

#Preview("Regular, accessibility 5", traits: .sizeThatFitsLayout) {
    CategoryGridPreview()
        .frame(width: 640)
        .environment(\.horizontalSizeClass, .regular)
        .environment(\.dynamicTypeSize, .accessibility5)
}
