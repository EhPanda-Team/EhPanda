import SwiftUI

/// Reflows one category and three persistent controls without constructing alternate button trees.
struct HeaderActionsLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        placement(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let plan = placement(width: bounds.width, subviews: subviews)
        for (subview, frame) in zip(subviews, plan.frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func placement(width: CGFloat?, subviews: Subviews) -> Placement {
        guard let category = subviews.first else { return Placement(size: .zero, frames: []) }
        let actions = subviews.dropFirst().map({ $0.sizeThatFits(.unspecified) })
        let idealCategory = category.sizeThatFits(.unspecified)
        let minimumActionWidth = actions.map(\.width).max() ?? 0
        let proposedWidth = width.flatMap({ $0.isFinite ? max($0, minimumActionWidth) : nil })
        let categorySize: CGSize
        if let proposedWidth, idealCategory.width > proposedWidth {
            categorySize = category.sizeThatFits(.init(width: proposedWidth, height: nil))
        } else {
            categorySize = idealCategory
        }
        return Self.placement(
            category: categorySize, idealCategoryWidth: idealCategory.width,
            actions: actions, proposedWidth: proposedWidth
        )
    }

    struct Placement {
        let size: CGSize
        let frames: [CGRect]
    }

    static func placement(
        category: CGSize, idealCategoryWidth: CGFloat, actions: [CGSize], proposedWidth: CGFloat?
    ) -> Placement {
        let arrangements = stride(from: max(1, actions.count), through: 1, by: -1).map {
            actionPlacement(sizes: actions, columns: $0)
        }
        guard let horizontal = arrangements.first, let vertical = arrangements.last else {
            return Placement(size: category, frames: [CGRect(origin: .zero, size: category)])
        }
        let idealWidth = idealCategoryWidth + 8 + horizontal.size.width
        let availableWidth = proposedWidth.flatMap({ $0.isFinite ? $0 : nil }) ?? idealWidth
        if let actions = arrangements.first(where: { idealCategoryWidth + 8 + $0.size.width <= availableWidth }) {
            let width = max(availableWidth, category.width + 8 + actions.size.width)
            let height = max(category.height, actions.size.height)
            let categoryFrame = CGRect(
                x: 0, y: (height - category.height) / 2, width: category.width, height: category.height
            )
            let offset = CGPoint(x: width - actions.size.width, y: (height - actions.size.height) / 2)
            return Placement(
                size: CGSize(width: width, height: height),
                frames: [categoryFrame] + actions.frames.map({ $0.offsetBy(dx: offset.x, dy: offset.y) })
            )
        }
        let actions = arrangements.first(where: {
            max(idealCategoryWidth, $0.size.width) <= availableWidth
        }) ?? vertical
        let width = max(availableWidth, category.width, actions.size.width)
        return Placement(
            size: CGSize(width: width, height: category.height + 8 + actions.size.height),
            frames: [CGRect(origin: .zero, size: category)] + actions.frames.map({
                $0.offsetBy(dx: width - actions.size.width, dy: category.height + 8)
            })
        )
    }

    private static func actionPlacement(sizes: [CGSize], columns: Int) -> Placement {
        var rows: [[CGSize]] = []
        for (offset, size) in sizes.enumerated() {
            if offset.isMultiple(of: columns) {
                rows.append([size])
            } else if let last = rows.indices.last {
                rows[last].append(size)
            }
        }
        let rowSizes = rows.map { row in
            CGSize(
                width: row.reduce(0, { $0 + $1.width }) + CGFloat(max(0, row.count - 1)) * 6,
                height: row.map(\.height).max() ?? 0
            )
        }
        let width = rowSizes.map(\.width).max() ?? 0
        var frames: [CGRect] = []
        var originY: CGFloat = 0
        for (row, rowSize) in zip(rows, rowSizes) {
            var originX = width - rowSize.width
            for size in row {
                frames.append(CGRect(
                    x: originX, y: originY + (rowSize.height - size.height) / 2, width: size.width, height: size.height
                ))
                originX += size.width + 6
            }
            originY += rowSize.height + 6
        }
        return Placement(size: CGSize(width: width, height: max(0, originY - 6)), frames: frames)
    }
}
