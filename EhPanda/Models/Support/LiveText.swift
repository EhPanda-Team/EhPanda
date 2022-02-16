//
//  LiveText.swift
//  EhPanda
//
//  Created by xioxin on 2022/2/12.
//

import SwiftUI
import Foundation

// MARK: LiveTextBounds
struct LiveTextBounds: Equatable {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint

    var edges: [CGPoint] {
        [topLeft, topRight, bottomRight, bottomLeft]
    }

    init(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    func expandingHalfHeight(_ size: CGSize) -> Self {
        expanding(size: size, width: 0, height: getHeight(size) / 2)
    }
    func getHeight(_ size: CGSize) -> Double {
        let topLeft = topLeft * size
        let bottomLeft = bottomLeft * size
        return abs(sqrt(pow(topLeft.x - bottomLeft.x, 2) + pow(topLeft.y - bottomLeft.y, 2)))
    }
    func getWidth(_ size: CGSize) -> Double {
        let topLeft = topLeft * size
        let topRight = topRight * size
        return abs(sqrt(pow(topLeft.x - topRight.x, 2) + pow(topLeft.y - topRight.y, 2)))
    }
    func getRadian(_ size: CGSize) -> Double {
        let topLeft = topLeft * size
        let topRight = topRight * size
        let radian = atan2(topRight.y - topLeft.y, topRight.x - topLeft.x)
        return radian < 0 ? radian + .pi * 2 : radian
    }
    func getAngle(_ size: CGSize) -> Double {
        180.0 / .pi * getRadian(size)
    }

    // Returns a expanded version with a specific radius
    private func expanding(size: CGSize, width: Double, height: Double) -> Self {
        let angle = 360 - getAngle(size)
        let projectedBottom = hypotenuse(longestSideLength: height, angle: angle)
        let projectedRight = hypotenuse(longestSideLength: width, angle: angle + 90)
        let projectedTop = hypotenuse(longestSideLength: height, angle: angle + 90 * 2)
        let projectedLeft = hypotenuse(longestSideLength: width, angle: angle + 90 * 3)

        let multipliedTopLeft = topLeft * size
        let multipliedTopRight = topRight * size
        let multipliedBottomLeft = bottomLeft * size
        let multipliedBottomRight = bottomRight * size

        let topLeft = CGPoint(
            x: multipliedTopLeft.x + projectedTop.x + projectedLeft.x,
            y: multipliedTopLeft.y + projectedTop.y + projectedLeft.y
        )
        let topRight = CGPoint(
            x: multipliedTopRight.x + projectedTop.x + projectedRight.x,
            y: multipliedTopRight.y + projectedTop.y + projectedRight.y
        )
        let bottomLeft = CGPoint(
            x: multipliedBottomLeft.x + projectedBottom.x + projectedLeft.x,
            y: multipliedBottomLeft.y + projectedBottom.y + projectedLeft.y
        )
        let bottomRight = CGPoint(
            x: multipliedBottomRight.x + projectedBottom.x + projectedRight.x,
            y: multipliedBottomRight.y + projectedBottom.y + projectedRight.y
        )
        return .init(
            topLeft: topLeft / size, topRight: topRight / size,
            bottomLeft: bottomLeft / size, bottomRight: bottomRight / size
        )
    }
    private func hypotenuse(longestSideLength: Double, angle: Double) -> CGPoint {
        let radian = 2 * .pi / 360 * angle
        return .init(x: sin(radian) * longestSideLength, y: cos(radian) * longestSideLength)
    }
}

// MARK: LiveTextGroup
struct LiveTextGroup: Equatable, Identifiable {
    var id: UUID = .init()
    let blocks: [LiveTextBlock]
    let text: String

    var minX: Double!
    var maxX: Double!
    var minY: Double!
    var maxY: Double!
    var width: Double!
    var height: Double!

    init?(blocks: [LiveTextBlock]) {
        guard let firstBlock = blocks.first else { return nil }
        self.blocks = blocks
        self.text = blocks.map(\.text).joined(separator: " ")
        self.minX = firstBlock.bounds.topLeft.x
        self.maxX = firstBlock.bounds.topLeft.x
        self.minY = firstBlock.bounds.topLeft.y
        self.maxY = firstBlock.bounds.topLeft.y
        blocks.forEach { block in
            block.bounds.edges.forEach { point in
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
            }
        }
        width = maxX - minX
        height = maxY - minY
    }

    // Returns the rect of a rectangle area which contains all live text blocks
    func getRect(width: Double, height: Double, extendSize: Double) -> CGRect {
        .init(
            x: minX * width - extendSize,
            y: minY * height - extendSize,
            width: (maxX - minX) * width + extendSize * 2,
            height: (maxY - minY) * height + extendSize * 2
        )
    }
}

// MARK: LiveTextBlock
struct LiveTextBlock: Equatable, Identifiable {
    var id: UUID = .init()

    let text: String
    let bounds: LiveTextBounds
}

// MARK: Definition
private func * (lhs: CGPoint, rhs: CGSize) -> CGPoint {
    .init(x: lhs.x * rhs.width, y: lhs.y * rhs.height)
}
private func / (lhs: CGPoint, rhs: CGSize) -> CGPoint {
    .init(x: lhs.x / rhs.width, y: lhs.y / rhs.height)
}
