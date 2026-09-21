import CoreGraphics
@testable import DetailFeature
import Foundation
import Testing

@Suite
struct HeaderActionsLayoutTests {
    @Test
    func categoryBoundarySelectsAllActionsThenTwoPlusOne() {
        let category = CGSize(width: 72, height: 24)
        let actions = Array(repeating: CGSize(width: 32, height: 32), count: 3)

        let allInOneRow = HeaderActionsLayout.placement(
            category: category,
            idealCategoryWidth: 72,
            actions: actions,
            proposedWidth: 188
        )
        #expect(allInOneRow.size.width == 188)
        #expect(allInOneRow.size.height == 32)
        #expect(allInOneRow.frames.count == 4)
        #expect(allInOneRow.frames.dropFirst().map(\.minY) == [0, 0, 0])

        let twoPlusOne = HeaderActionsLayout.placement(
            category: category,
            idealCategoryWidth: 72,
            actions: actions,
            proposedWidth: 187
        )
        #expect(twoPlusOne.frames.count == 4)
        #expect(twoPlusOne.size.height == 70)
        #expect(twoPlusOne.frames[1].minY == 0)
        #expect(twoPlusOne.frames[2].minY == 0)
        #expect(twoPlusOne.frames[3].minY == 38)
        #expect(twoPlusOne.frames.dropFirst().allSatisfy({ $0.maxX <= twoPlusOne.size.width }))
    }

    @Test
    func longCategoryKeepsNarrowActionsContainedAndDisjoint() {
        let plan = HeaderActionsLayout.placement(
            category: CGSize(width: 280, height: 48),
            idealCategoryWidth: 280,
            actions: [
                CGSize(width: 44, height: 44),
                CGSize(width: 64, height: 44),
                CGSize(width: 44, height: 44)
            ],
            proposedWidth: 100
        )

        #expect(plan.size.width == 280)
        #expect(plan.size.height == 200)
        expectFramesAreContainedAndDisjoint(plan)
        #expect(plan.frames[0].width == 280)
        #expect(plan.frames.dropFirst().allSatisfy({ $0.minY >= 56 }))
    }

    @Test
    func unequalActionSizesPreserveOrderAndIntrinsicFrames() {
        let actions = [
            CGSize(width: 20, height: 30),
            CGSize(width: 40, height: 24),
            CGSize(width: 15, height: 36)
        ]
        let plan = HeaderActionsLayout.placement(
            category: CGSize(width: 50, height: 20),
            idealCategoryWidth: 50,
            actions: actions,
            proposedWidth: 150
        )

        #expect(plan.frames.dropFirst().map(\.size) == actions)
        #expect(plan.frames[1].minX < plan.frames[2].minX)
        #expect(plan.frames[2].minX < plan.frames[3].minX)
        expectFramesAreContainedAndDisjoint(plan)
    }

    @Test(arguments: [CGFloat.zero, CGFloat.infinity])
    func extremeProposalsRemainFinite(proposedWidth: CGFloat) {
        let plan = HeaderActionsLayout.placement(
            category: CGSize(width: 72, height: 24),
            idealCategoryWidth: 72,
            actions: [CGSize(width: 32, height: 32), CGSize(width: 32, height: 32)],
            proposedWidth: proposedWidth
        )
        expectFinite(plan)
        expectFramesAreContainedAndDisjoint(plan)
    }

    @Test
    func missingProposalUsesIntrinsicWidthAndRemainsFinite() {
        let plan = HeaderActionsLayout.placement(
            category: CGSize(width: 72, height: 24),
            idealCategoryWidth: 72,
            actions: [CGSize(width: 32, height: 32), CGSize(width: 32, height: 32)],
            proposedWidth: nil
        )
        #expect(plan.size.width == 150)
        expectFinite(plan)
        expectFramesAreContainedAndDisjoint(plan)
    }

    private func expectFramesAreContainedAndDisjoint(
        _ plan: HeaderActionsLayout.Placement
    ) {
        for frame in plan.frames {
            #expect(frame.minX >= 0)
            #expect(frame.minY >= 0)
            #expect(frame.maxX <= plan.size.width)
            #expect(frame.maxY <= plan.size.height)
        }
        for index in plan.frames.indices {
            for otherIndex in plan.frames.indices where otherIndex > index {
                #expect(!plan.frames[index].intersects(plan.frames[otherIndex]))
            }
        }
    }

    private func expectFinite(_ plan: HeaderActionsLayout.Placement) {
        #expect(plan.size.width.isFinite)
        #expect(plan.size.height.isFinite)
        for frame in plan.frames {
            #expect(frame.minX.isFinite)
            #expect(frame.minY.isFinite)
            #expect(frame.width.isFinite)
            #expect(frame.height.isFinite)
        }
    }
}
