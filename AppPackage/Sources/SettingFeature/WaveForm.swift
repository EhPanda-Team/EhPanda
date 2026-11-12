public import SwiftUI

/// The Login page's backdrop: a wave that slides sideways, one cycle every 4 seconds, from the wall clock.
///
/// The slide is position motion, so under Reduce Motion the wave stands still at phase 0 and the timeline is paused
/// (D-29, 19-10); that also lets the page settle for the snapshot matrix.
public struct WaveForm: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let color: Color
    private let amplify: CGFloat
    private let isReversed: Bool

    public init(color: Color, amplify: CGFloat, isReversed: Bool) {
        self.color = color
        self.amplify = amplify
        self.isReversed = isReversed
    }

    public var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeLine in
            Canvas { context, size in
                let angle = Self.phase(at: timeLine.date, reduceMotion: reduceMotion)
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

    /// Where in its 4-second cycle the wave is at `date`, in seconds from -2 to 2; always 0 under Reduce Motion.
    static func phase(at date: Date, reduceMotion: Bool) -> Double {
        reduceMotion ? 0 : date.timeIntervalSinceReferenceDate.remainder(dividingBy: 4)
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
