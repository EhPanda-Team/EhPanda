import SwiftUI
import AppModels
import AppTools

// MARK: CategoryLabel
public struct CategoryLabel: View {
    private let text: LocalizedStringResource
    private let color: Color
    private let font: Font
    private let insets: EdgeInsets
    private let cornerRadius: CGFloat
    private let corners: UIRectCorner

    public init(
        text: LocalizedStringResource, color: Color, font: Font = .footnote,
        insets: EdgeInsets = .init(top: 1, leading: 3, bottom: 1, trailing: 3),
        cornerRadius: CGFloat = 2, corners: UIRectCorner = .allCorners
    ) {
        self.text = text
        self.color = color
        self.font = font
        self.insets = insets
        self.cornerRadius = cornerRadius
        self.corners = corners
    }

    public var body: some View {
        Text(text).font(font.bold()).lineLimit(1).foregroundStyle(.white)
            .padding(insets).background(
                Rectangle().foregroundStyle(color).cornerRadius(cornerRadius, corners: corners)
            )
    }
}

// MARK: CategoryView
public struct CategoryView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let bindings: [Binding<Bool>]

    private var gridItems: [GridItem] {
        [GridItem(.adaptive(minimum: horizontalSizeClass == .regular ? 100 : 80, maximum: 100))]
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
    }
}

// MARK: CategoryCell
private struct CategoryCell: View {
    @Binding private var isFiltered: Bool
    private let category: AppModels.Category

    init(isFiltered: Binding<Bool>, category: AppModels.Category) {
        _isFiltered = isFiltered
        self.category = category
    }

    var body: some View {
        let color = category.color(host: AppUtil.galleryHost)
        ZStack {
            Rectangle()
                .foregroundColor(isFiltered ? color.opacity(0.3) : color)
            Text(category.value).bold().foregroundStyle(.white)
                .padding(.vertical, 5).lineLimit(1)
        }
        .onTapGesture {
            isFiltered.toggle()
            HapticsUtil.generateFeedback(style: .soft)
        }
        .cornerRadius(5)
    }
}
