//
//  WaveForm.swift
//  WaveForm
//
//  Created by 荒木辰造 on R 3/08/12.
//  Copied from Kavsoft
//

import SwiftUI

struct WaveForm: View {
    private let color: Color
    private let amplify: CGFloat
    private let isReversed: Bool

    init(color: Color, amplify: CGFloat, isReversed: Bool) {
        self.color = color
        self.amplify = amplify
        self.isReversed = isReversed
    }

    var body: some View {
        TimelineView(.animation) { timeLine in
            Canvas { context, size in
                let timeNow = timeLine.date.timeIntervalSinceReferenceDate
                let angle = timeNow.remainder(dividingBy: 4)
                let offset = angle * size.width / 4

                context.translateBy(x: isReversed ? -offset : offset, y: 0)
                context.fill(getPath(size: size), with: .color(color))
                context.translateBy(x: -size.width, y: 0)
                context.fill(getPath(size: size), with: .color(color))
                context.translateBy(x: size.width * 2, y: 0)
                context.fill(getPath(size: size), with: .color(color))
            }
        }
    }

    func getPath(size: CGSize) -> Path {
        Path { path in
            let midHeight = size.height / 2
            let width = size.width

            path.move(to: CGPoint(x: 0, y: midHeight))

            path.addCurve(
                to: CGPoint(x: width, y: midHeight),
                control1: CGPoint(x: width * 0.4, y: midHeight + amplify),
                control2: CGPoint(x: width * 0.65, y: midHeight - amplify)
            )

            path.addLine(to: CGPoint(x: width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
        }
    }
}
