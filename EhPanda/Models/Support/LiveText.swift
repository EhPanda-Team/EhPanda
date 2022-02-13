//
//  LiveText.swift
//  EhPanda
//
//  Created by xioxin on 2022/2/12.
//

import SwiftUI
import Foundation

// MARK: LiveTextBounds
struct LiveTextBounds {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint

    private(set) var height: Double!
    private(set) var width: Double!
    private(set) var radian: Double!
    private(set) var angle: Double!

    var edges: [CGPoint] {
        [topLeft, topRight, bottomRight, bottomLeft]
    }
    var halfHeightExpanded: Self {
        expanding(radius: height / 2)
    }

    init(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
        height = calculateHeight()
        width = calculateWidth()
        radian = calculateRadian()
        angle = 180.0 / .pi * radian
    }

    private func calculateHeight() -> Double {
        let left = abs(sqrt(pow(topLeft.x - bottomLeft.x, 2) + pow(topLeft.y - bottomLeft.y, 2)))
        let right = abs(sqrt(pow(topRight.x - bottomRight.x, 2) + pow(topRight.y - bottomRight.y, 2)))
        return max(left, right)
    }
    private func calculateWidth() -> Double {
        let top = abs(sqrt(pow(topLeft.x - topRight.x, 2) + pow(topLeft.y - topRight.y, 2)))
        let bottom = abs(sqrt(pow(bottomLeft.x - bottomRight.x, 2) + pow(bottomLeft.y - bottomRight.y, 2)))
        return max(top, bottom)
    }
    private func calculateRadian() -> Double {
        let radian = atan2(topRight.y - topLeft.y, topRight.x - topLeft.x)
        return radian < 0 ? radian + .pi * 2 : radian
    }

    // Returns a expanded version with a specific radius
    private func expanding(radius: Double) -> Self {
        let angle = 360 - angle
        let topPoint = hypotenuse(radius: radius, angle: angle)
        let rightPoint = hypotenuse(radius: radius, angle: angle + 90)
        let bottomPoint = hypotenuse(radius: radius, angle: angle + 90 * 2)
        let leftPoint = hypotenuse(radius: radius, angle: angle + 90 * 3)
        let topLeft = CGPoint(
            x: topLeft.x + topPoint.x + leftPoint.x,
            y: topLeft.y + topPoint.y + leftPoint.y
        )
        let topRight = CGPoint(
            x: topRight.x + topPoint.x + rightPoint.x,
            y: topRight.y + topPoint.y + rightPoint.y
        )
        let bottomLeft = CGPoint(
            x: bottomLeft.x + bottomPoint.x + leftPoint.x,
            y: bottomLeft.y + bottomPoint.y + leftPoint.y
        )
        let bottomRight = CGPoint(
            x: bottomRight.x + bottomPoint.x + rightPoint.x,
            y: bottomRight.y + bottomPoint.y + rightPoint.y
        )
        return .init(
            topLeft: topLeft, topRight: topRight,
            bottomLeft: bottomLeft, bottomRight: bottomRight
        )
    }
    private func hypotenuse(radius: Double, angle: Double) -> CGPoint {
        let radian = 2 * .pi / 360 * angle
        return .init(x: sin(radian) * radius, y: cos(radian) * radius)
    }
}

// MARK: LiveTextGroup
struct LiveTextGroup: Identifiable {
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
        self.minY = 1.0 - firstBlock.bounds.topLeft.y
        self.maxY = 1.0 - firstBlock.bounds.topLeft.y
        blocks.forEach { block in
            block.bounds.edges.forEach { point in
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, 1 - point.y)
                maxY = max(maxY, 1 - point.y)
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
struct LiveTextBlock: Identifiable {
    var id: UUID = .init()

    let text: String
    let bounds: LiveTextBounds
}
