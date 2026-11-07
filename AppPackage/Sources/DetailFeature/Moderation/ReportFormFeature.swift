public import AppComponents
public import AppModels
public import ComposableArchitecture
public import Foundation
import Resources

/// EhPanda's own Report form (18.1, UI-SPEC C-13): reports one comment to the site from a native sheet, with the
/// site's report page as the fallback.
///
/// The form opens only from a comment (D-04): its state carries the comment, the site and the gallery, and there is no
/// other origin. It reads the site's form first (DD-01), offers exactly two reasons, child and other illegal content
/// (D-06, owner msgs 1950, 1975), and posts one report to a URL rebuilt from the gallery URL (DD-02).
///
/// The email lives in this state only: nothing here writes it to settings, defaults, the keychain or a log, and no
/// report action sends an analytics signal (D-08, D-11).
@Reducer
public struct ReportFormFeature: Sendable {
    /// A reason the form offers, in the form's order (C-13 item 2).
    public enum Reason: CaseIterable, Equatable, Sendable {
        case child
        case illegal

        /// The site's `report_type` for the reason.
        public var type: ReportType {
            switch self {
            case .child: .child
            case .illegal: .other
            }
        }
    }

    /// Where the form is (C-13 States). A failed send goes back to `.ready` with the failed alert over it.
    public enum Phase: Equatable, Sendable {
        case loading
        case ready
        case sending
        case sent
        case unavailable
    }

    /// The text field with the keyboard focus; the view binds it to its `@FocusState`.
    public enum Field: Hashable, Sendable {
        case email
        case details
    }

    /// What the pinned button (and ⌘↩) is in each phase (C-13 "Pinned action bar").
    public enum PrimaryKind: Equatable, Sendable {
        case send
        case sending
        case done
        case openReportPage
    }

    /// The failed alert's buttons other than Cancel (C-13 Failed).
    @CasePathable
    public enum Alert: Equatable, Sendable {
        case retry
        case openReportPage
    }

    @Reducer
    public enum Destination {
        /// The site's report page, over the form, so closing it returns to the kept form (Research P-7).
        @ReducerCaseIgnored
        case reportPage(URL)
    }

    /// The comment being reported, as the prefill names it.
    public struct Comment: Equatable, Sendable {
        public var author: String
        public var date: Date
        public var text: String

        public init(author: String, date: Date, text: String) {
            self.author = author
            self.date = date
            self.text = text
        }
    }

    /// The gallery's report URLs, rebuilt once from the gallery URL by `CommentReportTarget` (T-18.1-01).
    struct Target: Equatable, Sendable {
        /// The site's report page (`?report=select`), the fallback.
        let page: URL
        let child: URL
        let other: URL

        init?(galleryURL: URL) {
            guard let page = CommentReportTarget.reportURL(for: galleryURL),
                  let child = CommentReportTarget.reportURL(for: galleryURL, type: .child),
                  let other = CommentReportTarget.reportURL(for: galleryURL, type: .other)
            else { return nil }
            self.page = page
            self.child = child
            self.other = other
        }

        /// Where the form is read: one page carries the fields both reasons share (DD-01).
        var form: URL { other }

        func url(for type: ReportType) -> URL {
            switch type {
            case .child: child
            case .other: other
            }
        }
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public let comment: Comment
        /// The site's display name, the `{site}` of the title and the failed message.
        public let site: String
        public let galleryURL: URL
        let target: Target
        /// The English block Details starts with (D-07).
        public let prefill: String

        public var phase = Phase.loading
        public var reason: Reason?
        public var email = ""
        public var details: String
        /// Set when Send finds the email malformed (DD-05); the next email edit clears it.
        public var emailInvalid = false
        /// Set once loading has taken 0.3 s, so a fast load never flashes a spinner (C-13 Loading).
        public var showsSpinner = false
        public var focus: Field?
        @Presents public var alert: AppAlertState<Alert>?
        @Presents public var destination: Destination.State?

        /// The email the loaded form carried, so a remembered address does not count as an edit.
        var loadedEmail = ""

        /// The form for `comment` on the gallery at `galleryURL`, or `nil` when the gallery has no report target.
        public init?(comment: GalleryComment, galleryURL: URL) {
            self.init(
                comment: Comment(
                    author: comment.author, date: comment.commentDate, text: ReportPrefill.commentText(of: comment)
                ),
                galleryURL: galleryURL
            )
        }

        public init?(comment: Comment, galleryURL: URL) {
            guard let target = Target(galleryURL: galleryURL),
                  let site = CommentReportTarget.siteName(for: galleryURL)
            else { return nil }
            self.comment = comment
            self.site = site
            self.galleryURL = galleryURL
            self.target = target
            prefill = ReportPrefill.text(author: comment.author, date: comment.date, comment: comment.text)
            details = prefill
        }

        /// Always child, then other illegal content; nothing else exists (D-06).
        public var reasons: [Reason] { Reason.allCases }

        /// The site's report page, which Open Report Page presents.
        public var reportPageURL: URL { target.page }

        /// Send Report's enable rule (C-13 item 5): a reason, an email, and Details text beyond the prefill.
        public var canSend: Bool {
            phase == .ready && reason != nil && !trimmedEmail.isEmpty && hasDetailsBeyondPrefill
        }

        /// Whether the user changed anything: a reason, an email other than the loaded one, or Details.
        public var isEdited: Bool {
            reason != nil || email != loadedEmail || details != prefill
        }

        /// Whether a swipe-down must not close the sheet: while sending, and while edited until sent.
        public var isDismissLocked: Bool {
            switch phase {
            case .sending: true
            case .sent: false
            case .loading, .ready, .unavailable: isEdited
            }
        }

        /// Close is the deliberate exit, except while a report is on the wire.
        public var isCloseDisabled: Bool { phase == .sending }

        public var primaryKind: PrimaryKind {
            switch phase {
            case .loading, .ready: .send
            case .sending: .sending
            case .sent: .done
            case .unavailable: .openReportPage
            }
        }

        var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

        var hasDetailsBeyondPrefill: Bool {
            let typed = details.hasPrefix(prefill) ? String(details.dropFirst(prefill.count)) : details
            let trimmedTyped = typed.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPrefill = prefill.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmedTyped.isEmpty && trimmedTyped != trimmedPrefill
        }

        /// The failed alert (C-13 Failed): Retry, Open Report Page, Cancel, in that order.
        mutating func presentFailedAlert() {
            let site = site
            alert = AppAlertState {
                TextState(localized: .reportFailedTitle)
            } actions: {
                ButtonState(action: .retry) {
                    TextState(localized: .RLocalizable.retry)
                }
                ButtonState(action: .openReportPage) {
                    TextState(localized: .commentReportOpen)
                }
                ButtonState(role: .cancel) {
                    TextState(localized: .RLocalizable.cancel)
                }
            } message: {
                TextState(localized: .reportFailedBody(site))
            }
        }
    }

    public enum Action: BindableAction, Equatable, Sendable {
        case alert(PresentationAction<Alert>)
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        /// The view appeared: read the site's form.
        case task
        case spinnerDelayElapsed
        /// The loaded form, or `nil` when it could not be read.
        case loaded(ReportForm?)
        case reasonTapped(Reason)
        /// The pinned button or ⌘↩.
        case primaryTapped
        /// The site's answer, or `nil` for a transport error or an error status.
        case sendResponse(ReportSubmission?)
        case closeTapped
    }

    private enum CancelID {
        case load, spinner, send
    }

    @Dependency(\.reportFormClient) private var reportFormClient
    @Dependency(\.continuousClock) private var clock
    @Dependency(\.dismiss) private var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.email):
                state.emailInvalid = false
                return .none

            case .binding, .destination, .alert(.dismiss):
                return .none

            case .task:
                guard state.phase == .loading else { return .none }
                return .merge(
                    .run { send in
                        try await clock.sleep(for: .milliseconds(300))
                        await send(.spinnerDelayElapsed)
                    }
                    .cancellable(id: CancelID.spinner, cancelInFlight: true),
                    .run { [url = state.target.form] send in
                        // Any failure reads as "unavailable"; the sheet then offers the site's page (DD-01).
                        let form: ReportForm?
                        do {
                            form = try await reportFormClient.load(url)
                        } catch {
                            form = nil
                        }
                        await send(.loaded(form))
                    }
                    .cancellable(id: CancelID.load, cancelInFlight: true)
                )

            case .spinnerDelayElapsed:
                if state.phase == .loading {
                    state.showsSpinner = true
                }
                return .none

            case .loaded(let form):
                guard state.phase == .loading else { return .none }
                state.showsSpinner = false
                if let form, form.hasDetails, Set(ReportType.allCases).isSubset(of: form.types) {
                    state.phase = .ready
                    if state.email.isEmpty, !form.email.isEmpty {
                        state.email = form.email
                        state.loadedEmail = form.email
                    }
                } else {
                    state.phase = .unavailable
                }
                return .cancel(id: CancelID.spinner)

            case .reasonTapped(let reason):
                guard state.phase == .ready else { return .none }
                // Details gets focus after the first pick, not on open: the keyboard would hide the reasons (P-3).
                if state.reason == nil {
                    state.focus = .details
                }
                state.reason = reason
                return .none

            case .primaryTapped:
                switch state.primaryKind {
                case .send:
                    return send(&state)
                case .sending:
                    return .none
                case .done:
                    return .run { _ in await dismiss() }
                case .openReportPage:
                    state.destination = .reportPage(state.target.page)
                    return .none
                }

            case .sendResponse(let submission):
                guard state.phase == .sending else { return .none }
                if submission == .sent {
                    state.phase = .sent
                    state.focus = nil
                } else {
                    // Everything typed stays; the alert owns the choice (C-13 Failed).
                    state.phase = .ready
                    state.presentFailedAlert()
                }
                return .none

            case .alert(.presented(.retry)):
                return send(&state)

            case .alert(.presented(.openReportPage)):
                state.destination = .reportPage(state.target.page)
                return .none

            case .closeTapped:
                guard !state.isCloseDisabled else { return .none }
                return .run { _ in await dismiss() }
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$destination, action: \.destination)
    }

    /// Sends the report with the form's fields, after the email check (DD-05). An invalid email focuses the field
    /// instead and nothing is sent.
    private func send(_ state: inout State) -> Effect<Action> {
        guard state.canSend, let reason = state.reason else { return .none }
        guard Self.isPlausibleEmail(state.trimmedEmail) else {
            state.emailInvalid = true
            state.focus = .email
            return .none
        }
        state.phase = .sending
        state.focus = nil
        let url = state.target.url(for: reason.type)
        return .run { [email = state.trimmedEmail, details = state.details] send in
            // A transport error and an error status are both "failed" (DD-03).
            let submission: ReportSubmission?
            do {
                submission = try await reportFormClient.send(url, reason.type, email, details)
            } catch {
                submission = nil
            }
            await send(.sendResponse(submission))
        }
        .cancellable(id: CancelID.send, cancelInFlight: true)
    }

    /// DD-05: one `@`, a non-empty local part, and a domain of dot-separated, non-empty labels (at least two). No
    /// other rule: the site does its own check.
    static func isPlausibleEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, let local = parts.first, let domain = parts.last, !local.isEmpty else { return false }
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        return labels.count >= 2 && labels.allSatisfy({ !$0.isEmpty })
    }
}

extension ReportFormFeature.Destination.State: Equatable, Sendable {}
extension ReportFormFeature.Destination.Action: Equatable, Sendable {}
