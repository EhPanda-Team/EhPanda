@testable import AppFeature
import AppModels
import ComposableArchitecture
@testable import DetailFeature
import Foundation
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

// The detail pages, Comments, the Report form and the Reader (19-07).
extension ScenarioCatalog {
    static var gallery: [String: ScenarioFactory] {
        [comments, reportForm].reduce(into: [:]) { result, group in
            result.merge(group) { first, _ in first }
        }
    }

    private static var comments: [String: ScenarioFactory] {
        typealias Page = GalleryScenarios
        return [
            "comments-list": .init(make: { try Page.comments(.list) }),
            "comments-menu": .init(make: { try Page.comments(.list) }, interact: Page.openFirstRowMenu),
            "comments-block-confirmation": .init(
                make: { try TracerScenarios.comments() }, interact: TracerScenarios.chooseBlock
            ),
            "comments-blocked-row-collapsed": .init(make: { try Page.comments(.blocked) }),
            "comments-blocked-row-shown": .init(make: { try Page.comments(.blockedShown) }),
            "comments-post-empty": .init(make: { try Page.comments(.postEmpty) }, interact: Page.holdStill),
            "comments-post-filled": .init(make: { try Page.comments(.postFilled) }, interact: Page.holdStill),
            "comments-posting-warning": .init(
                make: { try Page.comments(.postingWarning) }, interact: Page.holdStill
            )
        ]
    }

    private static var reportForm: [String: ScenarioFactory] {
        typealias Page = GalleryScenarios
        return [
            "report-form-loading": .init(make: { try Page.reportForm(.loading) }, interact: Page.holdStill),
            "report-form-ready": .init(make: { try Page.reportForm(.ready) }),
            "report-form-filled": .init(make: { try Page.reportForm(.filled) }),
            "report-form-sending": .init(make: { try Page.reportForm(.sending) }, interact: Page.holdStill),
            "report-form-sent": .init(make: { try Page.reportForm(.sent) }),
            "report-form-unavailable": .init(make: { try Page.reportForm(.unavailable) }),
            "report-form-error-alert": .init(make: { try Page.reportForm(.errorAlert) })
        ]
    }
}

@MainActor
enum GalleryScenarios {
    // MARK: Comments

    /// The synthetic gallery's page. Its token is letters and digits, as the site's are, so the gallery has a report
    /// target and a comment's menu offers Report as well as Block.
    static let galleryURL = URL(string: "https://e-hentai.org/g/1/visualtoken/")

    enum CommentsState {
        case list, blocked, blockedShown, postEmpty, postFilled, postingWarning
    }

    /// The synthetic comments on the real `CommentsView` and `CommentsReducer`. A blocked author is matched by member
    /// ID (owner msg 1918); the editor and its posting warning are the reducer's own: Post Comment is presented
    /// through its action, and the warning comes from Post over a draft that the scenario's filter list matches.
    static func comments(_ kind: CommentsState) throws -> AnyView {
        let url = try XCTUnwrap(galleryURL)
        let comments = TracerScenarios.commentFixtures()
        var state = CommentsReducer.State(gid: "1", token: "visualtoken", galleryURL: url, comments: comments)
        state.moderation.$blockedUsers.withLock { users in
            users = []
            if kind == .blocked || kind == .blockedShown {
                users.block(memberID: GalleryFixtures.blockedMemberID, name: GalleryFixtures.blockedMemberName)
            }
        }
        if kind == .blockedShown, let first = comments.first {
            state.moderation.revealedCommentIDs.insert(first.commentID)
        }
        let store = Store(initialState: state, reducer: CommentsReducer.init) {
            $0.commentFilterTerms = CommentFilterTerms(groups: ["visual": [GalleryFixtures.filteredTerm]])
        }
        switch kind {
        case .postEmpty:
            store.send(.presentPostComment(commentID: ""))
        case .postFilled:
            store.send(.presentPostComment(commentID: ""))
            store.send(.binding(.set(\.commentContent, GalleryFixtures.commentDraft)))
        case .postingWarning:
            store.send(.presentPostComment(commentID: ""))
            store.send(.binding(.set(\.commentContent, GalleryFixtures.filteredDraft)))
            store.send(.postTapped)
        case .list, .blocked, .blockedShown:
            break
        }
        return AnyView(NavigationStack {
            CommentsView(
                store: store, gid: "1", token: "visualtoken", apiKey: "", galleryURL: url, comments: comments
            )
        })
    }

    // MARK: Report form

    enum ReportFormState {
        case loading, ready, filled, sending, sent, unavailable, errorAlert
    }

    /// The Report form for the first synthetic comment, as Comments presents it from the comment's Report. Its phase
    /// and fields are the form reducer's own state; the failed alert is the reducer's own. The site is never asked:
    /// the form's load waits for good, which is the loading state, and nothing sends.
    static func reportForm(_ kind: ReportFormState) throws -> AnyView {
        let url = try XCTUnwrap(galleryURL)
        let comments = TracerScenarios.commentFixtures()
        let comment = try XCTUnwrap(comments.first)
        var form = try XCTUnwrap(ReportFormFeature.State(comment: comment, galleryURL: url))
        switch kind {
        case .loading:
            form.phase = .loading
            form.showsSpinner = true
        case .ready:
            form.phase = .ready
        case .filled, .sending, .errorAlert:
            form.phase = kind == .sending ? .sending : .ready
            form.reason = .child
            form.email = GalleryFixtures.reportEmail
            form.details = form.prefill + "\n\n" + GalleryFixtures.reportDetails
            if kind == .errorAlert {
                form.presentFailedAlert()
            }
        case .sent:
            form.phase = .sent
            form.reason = .child
            form.email = GalleryFixtures.reportEmail
            form.details = form.prefill + "\n\n" + GalleryFixtures.reportDetails
        case .unavailable:
            form.phase = .unavailable
        }
        var state = CommentsReducer.State(gid: "1", token: "visualtoken", galleryURL: url, comments: comments)
        state.moderation.$blockedUsers.withLock({ $0 = [] })
        state.destination = .reportForm(form)
        let store = Store(initialState: state, reducer: CommentsReducer.init) {
            $0.reportFormClient.load = { _ in
                try await Task.sleep(for: .seconds(3600))
                throw CancellationError()
            }
            $0.reportFormClient.send = { _, _, _, _ in
                try await Task.sleep(for: .seconds(3600))
                throw CancellationError()
            }
        }
        return AnyView(NavigationStack {
            CommentsView(
                store: store, gid: "1", token: "visualtoken", apiKey: "", galleryURL: url, comments: comments
            )
        })
    }

    // MARK: User steps

    /// Lets a sheet, its focus and any alert over it finish presenting, then holds the caret and any spinner still:
    /// the layer clock of the hosted view and of every controller presented over it is stopped. Every attempt hosts
    /// a fresh controller, so no clock stays stopped. The keyboard is a separate window and is not drawn.
    static func holdStill(_ window: UIWindow) async throws {
        try await ContinuousClock().sleep(for: .milliseconds(1500))
        var controller = try XCTUnwrap(window.rootViewController)
        while true {
            controller.view.layer.speed = 0
            controller.view.layer.timeOffset = 0
            guard let presented = controller.presentedViewController else { return }
            controller = presented
        }
    }

    /// Opens the first comment's `…` moderation menu, as a tap on it does. The button is hidden from VoiceOver (its
    /// items are the row's own actions), so it is found as the first menu control of the list.
    static func openFirstRowMenu(_ window: UIWindow) async throws {
        let root = try XCTUnwrap(window.rootViewController?.view)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        while true {
            if let control = menuControls(in: root).min(by: {
                $0.convert($0.bounds, to: nil).minY < $1.convert($1.bounds, to: nil).minY
            }) {
                control.performPrimaryAction()
                return
            }
            guard clock.now < deadline else { throw AccessibilityActionDriver.Failure.notFound("comment menu") }
            try await clock.sleep(for: .milliseconds(100))
        }
    }

    private static func menuControls(in view: UIView) -> [UIControl] {
        if view.isHidden || view is UINavigationBar { return [] }
        var found: [UIControl] = []
        if let control = view as? UIControl,
           control.showsMenuAsPrimaryAction || control.isContextMenuInteractionEnabled {
            found.append(control)
        }
        return found + view.subviews.flatMap(menuControls(in:))
    }
}
