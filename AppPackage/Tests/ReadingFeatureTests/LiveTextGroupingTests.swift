import AppModels
import Foundation
@testable import ReadingFeature
import Testing

// Recognized lines group into the passages they belong to, so a balloon's lines are highlighted and
// translated together.
struct LiveTextGroupingTests {
    private static let pageSize = CGSize(width: 1000, height: 2000)

    /// A line `width` by `height` page pixels, its top-left corner at `origin`, tilted by `degrees`.
    private static func line(
        _ text: String,
        origin: CGPoint,
        width: Double,
        height: Double,
        degrees: Double = 0
    ) -> LiveTextBlock {
        let angle = degrees * .pi / 180
        func point(_ across: Double, _ down: Double) -> CGPoint {
            CGPoint(
                x: (origin.x + across * cos(angle) - down * sin(angle)) / pageSize.width,
                y: (origin.y + across * sin(angle) + down * cos(angle)) / pageSize.height
            )
        }
        return LiveTextBlock(
            text: text,
            bounds: LiveTextBounds(
                topLeft: point(0, 0),
                topRight: point(width, 0),
                bottomLeft: point(0, height),
                bottomRight: point(width, height)
            )
        )
    }

    @Test
    func aTiltedShortWordJoinsItsLines() {
        // As Vision read a hand-lettered balloon: the short word tilted by 7.4°.
        let blocks = [
            Self.line("If", origin: CGPoint(x: 480, y: 400), width: 39, height: 35),
            Self.line("nothing", origin: CGPoint(x: 445, y: 438), width: 111, height: 43, degrees: 7.4),
            Self.line("changes", origin: CGPoint(x: 440, y: 490), width: 121, height: 39, degrees: -0.15),
            Self.line("it's...", origin: CGPoint(x: 462, y: 532), width: 77, height: 39)
        ]

        let groups = LiveTextHandler.groups(of: blocks, size: Self.pageSize)

        #expect(groups.map(\.text) == ["If nothing changes it's..."])
    }

    @Test
    func longLinesRunningDifferentWaysStayApart() {
        let blocks = [
            Self.line("A caption across the panel", origin: CGPoint(x: 100, y: 400), width: 400, height: 40),
            Self.line("A sign tilted on the wall", origin: CGPoint(x: 120, y: 420), width: 400, height: 40, degrees: 20)
        ]

        let groups = LiveTextHandler.groups(of: blocks, size: Self.pageSize)

        #expect(groups.count == 2)
    }

    @Test
    func aPassageTakesEveryLineLinkedThroughOthersAndReadsDown() {
        // The middle line, recognized last, links the two before it.
        let blocks = [
            Self.line("top", origin: CGPoint(x: 400, y: 400), width: 200, height: 40),
            Self.line("bottom", origin: CGPoint(x: 400, y: 496), width: 200, height: 40),
            Self.line("middle", origin: CGPoint(x: 400, y: 448), width: 200, height: 40)
        ]

        let groups = LiveTextHandler.groups(of: blocks, size: Self.pageSize)

        #expect(groups.map(\.text) == ["top middle bottom"])
    }

    @Test
    func linesInBalloonsJoinedSideBySideStayApart() {
        // As Vision read two joined balloons: the last line of one beside the second line of the other,
        // overlapping it by a corner.
        let blocks = [
            Self.line("Still", origin: CGPoint(x: 977, y: 137), width: 65, height: 35),
            Self.line("wondering", origin: CGPoint(x: 940, y: 191), width: 133, height: 40, degrees: 4.2),
            Self.line("Batman.", origin: CGPoint(x: 1062, y: 140), width: 116, height: 39, degrees: -0.8)
        ]

        let groups = LiveTextHandler.groups(of: blocks, size: CGSize(width: 1280, height: 1791))

        #expect(groups.map(\.text) == ["Still wondering", "Batman."])
    }

    @Test
    func linesOfDifferentSizesStayApart() {
        let blocks = [
            Self.line("BOOM", origin: CGPoint(x: 400, y: 300), width: 300, height: 100),
            Self.line("What was that?", origin: CGPoint(x: 400, y: 410), width: 300, height: 40)
        ]

        let groups = LiveTextHandler.groups(of: blocks, size: Self.pageSize)

        #expect(groups.count == 2)
    }
}
