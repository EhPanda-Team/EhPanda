import AppModels
@testable import DetailFeature
import Foundation
import SwiftUI
import Testing
import UIKit

/// A revealed comment in the list (UI-SPEC C-7) keeps its whole header at every size: offered the height it asks for,
/// as a list row offers it, it fills that height. A `VStack` hands such a height out in equal shares rather than by
/// each child's ideal, so the C-7 line above the comment could take a share the comment needed, and the comment's
/// header, the one part of it that gives way, lost its date's second line to an ellipsis at AX5 (18-UAT, UI review
/// top fix 1). The comment alone, before the block, has no sibling to share with.
@MainActor
struct RevealedCommentCellLayoutTests {
    private static let comment = GalleryComment(
        votedUp: false, votedDown: false, votable: true, editable: false,
        score: "+7", author: "黑锋血色",
        contents: [
            .init(type: .plainText, text: AttributedString("赛博亚历山大图书馆")),
            .init(type: .plainText, text: AttributedString("EhPanda UITest Fixture Alt"))
        ],
        commentID: "6894060", commentDate: Date(timeIntervalSince1970: 1_730_010_240)
    )

    /// The comment row's width in a phone's comments sheet: the 262pt and 307pt content widths of the line's tests,
    /// plus the cell's padding, and the iPhone Air's 352pt row measured at AX5.
    @Test(arguments: [294, 339, 352] as [CGFloat], [DynamicTypeSize.large, .accessibility3, .accessibility5])
    func offeredItsHeightTheRevealedCommentFillsIt(width: CGFloat, size: DynamicTypeSize) {
        let revealed = CommentsView.CommentCell(gid: "1", comment: Self.comment, hideAction: {}, linkAction: { _ in })
        let ideal = Self.size(of: revealed, in: CGSize(width: width, height: .greatestFiniteMagnitude), at: size)
        let laidOut = Self.size(of: revealed, in: CGSize(width: width, height: ideal.height), at: size)

        #expect(
            abs(laidOut.height - ideal.height) < 0.5,
            "At \(width)pt and \(size) the revealed comment asks for \(ideal.height)pt and fills \(laidOut.height)pt."
        )
    }

    private static func size(of view: some View, in proposal: CGSize, at size: DynamicTypeSize) -> CGSize {
        UIHostingController(rootView: view
            .environment(\.dynamicTypeSize, size)
            .environment(\.locale, Locale(identifier: "en_US"))
        )
        .sizeThatFits(in: proposal)
    }
}
