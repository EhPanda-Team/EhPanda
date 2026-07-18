import SwiftUI
import Sharing
import AppModels
import AppTools
import Dependencies
import HapticsClient

// MARK: CategoryLabel
public struct CategoryLabel: View {
    private let text: LocalizedStringResource
    private let color: Color
    private let font: Font
    private let insets: EdgeInsets
    private let cornerRadius: CGFloat

    public init(
        text: LocalizedStringResource, color: Color, font: Font = .footnote,
        insets: EdgeInsets = .init(top: 1, leading: 3, bottom: 1, trailing: 3),
        cornerRadius: CGFloat = 2
    ) {
        self.text = text
        self.color = color
        self.font = font
        self.insets = insets
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        Text(text).font(font.bold()).lineLimit(1).foregroundStyle(.white)
            .padding(insets).background(
                Rectangle().foregroundStyle(color).clipShape(.rect(cornerRadius: cornerRadius))
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
    @Dependency(\.hapticsClient) private var hapticsClient
    @SharedReader(.setting) private var setting: Setting
    @Binding private var isFiltered: Bool
    private let category: AppModels.Category

    init(isFiltered: Binding<Bool>, category: AppModels.Category) {
        _isFiltered = isFiltered
        self.category = category
    }

    var body: some View {
        Text(category.value)
            .bold()
            .foregroundStyle(.white)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .lineLimit(1)
            .background {
                Rectangle()
                    .foregroundStyle(category.color(host: setting.galleryHost).opacity(isFiltered ? 0.3 : 1))
                    .animation(.default, value: isFiltered)
            }
            .onTapGesture {
                isFiltered.toggle()
                hapticsClient.generateFeedback(.soft)
            }
            .clipShape(.rect(cornerRadius: 5))
    }
}
