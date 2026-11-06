import AnalyticsClient
import AppComponents
import AppModels
import ComposableArchitecture
@testable import DetailFeature
import Foundation
import Resources
import Testing

// The Report form's logic (18.1, UI-SPEC C-13), without a view. Every call to the site is a stub: `ReportFormClient`'s
// test value is unimplemented, so a test that reaches the site without saying what it answers fails.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are main-actor-isolated
// (see 11-22-SUMMARY.md).
@Suite
struct ReportFormReducerTests {

    // MARK: Opening

    // The form opens only from a comment, on a gallery with a report target: two reasons, none picked, and Details
    // holding the English prefill.
    @Test
    func theFormOpensWithTwoReasonsNonePickedAndThePrefill() throws {
        let state = try #require(ReportFormFeature.State(comment: Self.galleryComment, galleryURL: Self.galleryURL))

        #expect(state.phase == .loading)
        #expect(state.reasons == [.child, .illegal])
        #expect(state.reasons.map(\.type) == [.child, .other])
        #expect(state.reason == nil)
        #expect(state.site == "E-Hentai")
        #expect(state.comment == Self.comment)
        #expect(state.details == Self.prefill)
        #expect(state.prefill == Self.prefill)
        #expect(state.email.isEmpty)
        #expect(state.focus == nil)
        #expect(state.reportPageURL == Self.pageURL)
        #expect(!state.isEdited)
        #expect(!state.isDismissLocked)
    }

    @Test
    func aGalleryWithNoReportTargetHasNoForm() throws {
        let galleryURL = try #require(URL(string: "https://example.com/g/42/abc123/"))

        #expect(ReportFormFeature.State(comment: Self.galleryComment, galleryURL: galleryURL) == nil)
    }

    // MARK: Loading (C-13 Loading, Unavailable; DD-01)

    @MainActor
    @Test
    func aLoadedFormWithBothTypesIsReady() async {
        let loadedURL = LockIsolated<URL?>(nil)
        let store = makeStore(client: ReportFormClient.stub(
            load: { url in
                loadedURL.setValue(url)
                return Self.form()
            }
        ))

        await store.send(.task)
        await store.receive(\.loaded) {
            $0.phase = .ready
        }
        #expect(loadedURL.value == Self.otherURL)
    }

    // A remembered address fills the empty field and does not count as an edit.
    @MainActor
    @Test
    func aRememberedEmailIsPrefilledAndIsNotAnEdit() async {
        let store = makeStore(client: ReportFormClient.stub(load: { _ in Self.form(email: "me@example.com") }))

        await store.send(.task)
        await store.receive(\.loaded) {
            $0.phase = .ready
            $0.email = "me@example.com"
            $0.loadedEmail = "me@example.com"
        }
        #expect(!store.state.isEdited)
    }

    @MainActor
    @Test
    func aLoadErrorIsUnavailable() async {
        let store = makeStore(client: ReportFormClient.stub(load: { _ in throw AppError.networkingFailed }))

        await store.send(.task)
        await store.receive(\.loaded, nil) {
            $0.phase = .unavailable
        }
        #expect(store.state.primaryKind == .openReportPage)
    }

    @MainActor
    @Test(arguments: [Set<ReportType>([.child]), [.other], []])
    func aFormWithoutBothTypesIsUnavailable(types: Set<ReportType>) async {
        let store = makeStore(client: ReportFormClient.stub(load: { _ in Self.form(types: types) }))

        await store.send(.task)
        await store.receive(\.loaded) {
            $0.phase = .unavailable
        }
    }

    // The spinner shows only once loading has taken 0.3 s (C-13 Loading).
    @MainActor
    @Test
    func theSpinnerShowsAfterThreeTenthsOfASecond() async {
        let clock = TestClock()
        let store = makeStore(
            client: ReportFormClient.stub(load: { _ in
                try await clock.sleep(for: .seconds(1))
                return Self.form()
            }),
            clock: clock
        )

        await store.send(.task)
        await clock.advance(by: .milliseconds(290))
        #expect(!store.state.showsSpinner)
        await clock.advance(by: .milliseconds(10))
        await store.receive(\.spinnerDelayElapsed) {
            $0.showsSpinner = true
        }
        await clock.advance(by: .milliseconds(700))
        await store.receive(\.loaded) {
            $0.phase = .ready
            $0.showsSpinner = false
        }
    }

    @MainActor
    @Test
    func aFastLoadNeverShowsTheSpinner() async {
        let clock = TestClock()
        let store = makeStore(
            client: ReportFormClient.stub(load: { _ in
                try await clock.sleep(for: .milliseconds(100))
                return Self.form()
            }),
            clock: clock
        )

        await store.send(.task)
        await clock.advance(by: .milliseconds(100))
        await store.receive(\.loaded) {
            $0.phase = .ready
        }
        await clock.advance(by: .seconds(1))
        #expect(!store.state.showsSpinner)
    }

    // MARK: Enable rule (C-13 item 5)

    @Test(arguments: [
        (nil, "me@example.com", "x", false),
        (ReportFormFeature.Reason.child, "", "x", false),
        (ReportFormFeature.Reason.child, "   ", "x", false),
        (ReportFormFeature.Reason.child, "me@example.com", "", false),
        (ReportFormFeature.Reason.child, "me@example.com", " \n", false),
        (ReportFormFeature.Reason.child, "me@example.com", "x", true),
        (ReportFormFeature.Reason.illegal, "a", "x", true)
    ])
    func sendNeedsAReasonAnEmailAndDetailsBeyondThePrefill(
        reason: ReportFormFeature.Reason?, email: String, typed: String, canSend: Bool
    ) {
        var state = Self.readyState()
        state.reason = reason
        state.email = email
        state.details = Self.prefill + typed

        #expect(state.canSend == canSend)
    }

    // The prefill alone, or the prefill with its blank lines removed, is not text beyond it.
    @Test(arguments: [prefill, prefill.trimmingCharacters(in: .whitespacesAndNewlines)])
    func thePrefillAloneDoesNotEnableSend(details: String) {
        var state = Self.readyState()
        state.reason = .child
        state.email = "me@example.com"
        state.details = details

        #expect(!state.canSend)
    }

    @Test
    func sendIsOffBeforeTheFormIsReady() {
        var state = Self.readyState()
        state.reason = .child
        state.email = "me@example.com"
        state.details = Self.prefill + "x"
        state.phase = .loading

        #expect(!state.canSend)
        #expect(state.primaryKind == .send)
    }

    // MARK: Email check on Send (DD-05, C-13 item 3)

    @MainActor
    @Test(arguments: ["a", "a@b", "@b.c", "a@.c", "a@b.", "a@@b.c", "a@b@c.d"])
    func anInvalidEmailFocusesTheFieldAndSendsNothing(email: String) async {
        let store = makeStore(state: Self.filledState(email: email))

        await store.send(.primaryTapped) {
            $0.emailInvalid = true
            $0.focus = .email
        }
    }

    // The next edit clears the invalid footer; a valid address then sends.
    @MainActor
    @Test
    func editingTheEmailClearsTheFlagAndAValidAddressSends() async {
        let sent = LockIsolated<[SendCall]>([])
        let store = makeStore(
            state: Self.filledState(email: "a"),
            client: ReportFormClient.stub(send: { url, type, email, details in
                sent.withValue({ $0.append(SendCall(url: url, type: type, email: email, details: details)) })
                return .sent
            })
        )

        await store.send(.primaryTapped) {
            $0.emailInvalid = true
            $0.focus = .email
        }
        await store.send(.binding(.set(\.email, " a@b.co "))) {
            $0.email = " a@b.co "
            $0.emailInvalid = false
        }
        await store.send(.primaryTapped) {
            $0.phase = .sending
            $0.focus = nil
        }
        await store.receive(\.sendResponse, .sent) {
            $0.phase = .sent
        }
        let call = SendCall(url: Self.childURL, type: .child, email: "a@b.co", details: Self.filledDetails)
        #expect(sent.value == [call])
    }

    @Test(arguments: ["a@b.co", "first.last+tag@mail.example.org", "x@y.z"])
    func plausibleEmailsPass(email: String) {
        #expect(ReportFormFeature.isPlausibleEmail(email))
    }

    // MARK: Sending (C-13 Sending, Sent, Failed)

    @MainActor
    @Test(arguments: [ReportFormFeature.Reason.child, .illegal])
    func aSentReportIsSent(reason: ReportFormFeature.Reason) async {
        let sent = LockIsolated<[SendCall]>([])
        var state = Self.filledState()
        state.reason = reason
        let store = makeStore(
            state: state,
            client: ReportFormClient.stub(send: { url, type, email, details in
                sent.withValue({ $0.append(SendCall(url: url, type: type, email: email, details: details)) })
                return .sent
            })
        )

        await store.send(.primaryTapped) {
            $0.phase = .sending
        }
        #expect(store.state.isDismissLocked)
        #expect(store.state.isCloseDisabled)
        #expect(store.state.primaryKind == .sending)
        await store.receive(\.sendResponse, .sent) {
            $0.phase = .sent
        }
        #expect(store.state.primaryKind == .done)
        #expect(!store.state.isDismissLocked)
        let url = reason == .child ? Self.childURL : Self.otherURL
        #expect(sent.value == [
            SendCall(url: url, type: reason.type, email: "me@example.com", details: Self.filledDetails)
        ])
    }

    // A rejected reply or a thrown error keeps every field, goes back to ready and shows the failed alert; Retry sends
    // the same fields again.
    @MainActor
    @Test(arguments: [FailureKind.rejected, .thrown])
    func aFailedSendKeepsTheFieldsAndRetrySendsThemAgain(failure: FailureKind) async {
        let sent = LockIsolated<[SendCall]>([])
        let store = makeStore(
            state: Self.filledState(),
            client: ReportFormClient.stub(send: { url, type, email, details in
                let isFirst = sent.withValue { calls in
                    calls.append(SendCall(url: url, type: type, email: email, details: details))
                    return calls.count == 1
                }
                guard isFirst else { return .sent }
                switch failure {
                case .rejected: return .rejected
                case .thrown: throw AppError.networkingFailed
                }
            })
        )
        let before = store.state

        await store.send(.primaryTapped) {
            $0.phase = .sending
        }
        await store.receive(\.sendResponse, failure == .rejected ? .rejected : nil) {
            $0.phase = .ready
            $0.alert = Self.failedAlert
        }
        #expect(store.state.reason == before.reason)
        #expect(store.state.email == before.email)
        #expect(store.state.details == before.details)
        #expect(store.state.primaryKind == .send)

        await store.send(.alert(.presented(.retry))) {
            $0.alert = nil
            $0.phase = .sending
        }
        await store.receive(\.sendResponse, .sent) {
            $0.phase = .sent
        }
        let call = SendCall(url: Self.childURL, type: .child, email: "me@example.com", details: Self.filledDetails)
        #expect(sent.value == [call, call])
    }

    @MainActor
    @Test
    func openReportPageFromTheFailedAlertPresentsTheSitesPage() async {
        var state = Self.filledState()
        state.alert = Self.failedAlert
        let store = makeStore(state: state)

        await store.send(.alert(.presented(.openReportPage))) {
            $0.alert = nil
            $0.destination = .reportPage(Self.pageURL)
        }
    }

    @MainActor
    @Test
    func cancelDismissesOnlyTheAlert() async {
        var state = Self.filledState()
        state.alert = Self.failedAlert
        let store = makeStore(state: state)

        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
        #expect(store.state.phase == .ready)
    }

    // MARK: Reasons (C-13 item 2)

    // The first pick moves focus to Details; switching reasons keeps what was typed and does not move focus again.
    @MainActor
    @Test
    func switchingReasonsKeepsTheEmailAndDetails() async {
        var state = Self.readyState()
        state.email = "me@example.com"
        state.details = Self.filledDetails
        let store = makeStore(state: state)

        await store.send(.reasonTapped(.child)) {
            $0.reason = .child
            $0.focus = .details
        }
        await store.send(.binding(.set(\.focus, .email))) {
            $0.focus = .email
        }
        await store.send(.reasonTapped(.illegal)) {
            $0.reason = .illegal
        }
        #expect(store.state.email == "me@example.com")
        #expect(store.state.details == Self.filledDetails)
    }

    @MainActor
    @Test
    func reasonsCannotBePickedBeforeTheFormIsReady() async {
        let store = makeStore(state: Self.openState())

        await store.send(.reasonTapped(.child))
    }

    // MARK: The pinned button and Close (C-13 Presentation)

    @MainActor
    @Test
    func thePrimaryActionDoesNothingWhileSending() async {
        var state = Self.filledState()
        state.phase = .sending
        let store = makeStore(state: state)

        await store.send(.primaryTapped)
        await store.send(.closeTapped)
    }

    @MainActor
    @Test
    func doneDismissesTheSentForm() async {
        let dismissed = LockIsolated(0)
        var state = Self.filledState()
        state.phase = .sent
        let store = makeStore(state: state, dismissed: dismissed)

        await store.send(.primaryTapped)
        await store.finish()
        #expect(dismissed.value == 1)
    }

    @MainActor
    @Test
    func theUnavailableFormOpensTheSitesPage() async {
        var state = Self.openState()
        state.phase = .unavailable
        let store = makeStore(state: state)

        await store.send(.primaryTapped) {
            $0.destination = .reportPage(Self.pageURL)
        }
    }

    @MainActor
    @Test(arguments: [ReportFormFeature.Phase.loading, .ready, .unavailable, .sent])
    func closeDismissesUnlessSending(phase: ReportFormFeature.Phase) async {
        let dismissed = LockIsolated(0)
        var state = Self.filledState()
        state.phase = phase
        let store = makeStore(state: state, dismissed: dismissed)

        await store.send(.closeTapped)
        await store.finish()
        #expect(dismissed.value == 1)
    }

    // Any edit locks the swipe-down; the untouched form does not, and neither does the sent one.
    @Test
    func editsLockInteractiveDismissal() {
        var state = Self.readyState()
        #expect(!state.isEdited)
        #expect(!state.isDismissLocked)

        var picked = state
        picked.reason = .illegal
        #expect(picked.isEdited)
        #expect(picked.isDismissLocked)

        var typedDetails = state
        typedDetails.details += "x"
        #expect(typedDetails.isEdited)
        #expect(typedDetails.isDismissLocked)

        var typedEmail = state
        typedEmail.email = "m"
        #expect(typedEmail.isEdited)
        #expect(typedEmail.isDismissLocked)

        state.reason = .child
        state.phase = .sent
        #expect(!state.isDismissLocked)
    }

    // MARK: Analytics (D-11)

    // The analytics client fails on any call, so a full flow passing proves no report action sends a signal.
    @MainActor
    @Test
    func aFullReportFlowSendsNoAnalyticsSignal() async {
        let store = makeStore(
            state: Self.openState(),
            client: ReportFormClient.stub(load: { _ in Self.form() }, send: { _, _, _, _ in .sent }),
            analyticsClient: .unimplemented
        )
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.reasonTapped(.illegal))
        await store.send(.binding(.set(\.email, "me@example.com")))
        await store.send(.binding(.set(\.details, Self.filledDetails)))
        await store.send(.primaryTapped)
        await store.receive(\.sendResponse)
        await store.send(.primaryTapped)
        await store.finish()

        #expect(store.state.phase == .sent)
    }
}

// MARK: Fixtures

extension ReportFormReducerTests {
    enum FailureKind: Sendable {
        case rejected
        case thrown
    }

    struct SendCall: Equatable, Sendable {
        let url: URL
        let type: ReportType
        let email: String
        let details: String
    }

    static let galleryURL = URL(string: "https://e-hentai.org/g/42/abc123/")!
    static let pageURL = URL(string: "https://e-hentai.org/g/42/abc123/?report=select")!
    static let childURL = URL(string: "https://e-hentai.org/g/42/abc123/?report=child")!
    static let otherURL = URL(string: "https://e-hentai.org/g/42/abc123/?report=other")!
    static let date = Date(timeIntervalSince1970: 1_793_883_840) // 2026-11-05 13:04:00 UTC
    static let comment = ReportFormFeature.Comment(author: "Alice", date: date, text: "Buy now")
    static let prefill = "Reporting a comment by Alice (2026-11-05 13:04 UTC):\n\"Buy now\"\n\n"
    static let filledDetails = prefill + "Links to illegal content."
    static let galleryComment = GalleryComment(
        votedUp: false, votedDown: false, votable: true, editable: false,
        author: "Alice", authorMemberID: "12",
        contents: [CommentContent(type: .plainText, text: AttributedString("Buy now"))],
        commentID: "1", commentDate: date
    )

    static var failedAlert: AppAlertState<ReportFormFeature.Alert> {
        AppAlertState {
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
            TextState(localized: .reportFailedBody("E-Hentai"))
        }
    }

    static func form(types: Set<ReportType> = [.child, .other], email: String = "") -> ReportForm {
        ReportForm(types: types, email: email, hasDetails: true)
    }

    /// The form as it opens, still loading.
    static func openState() -> ReportFormFeature.State {
        guard let state = ReportFormFeature.State(comment: comment, galleryURL: galleryURL) else {
            preconditionFailure("the fixture gallery has a report target")
        }
        return state
    }

    /// The loaded form, untouched.
    static func readyState() -> ReportFormFeature.State {
        var state = openState()
        state.phase = .ready
        return state
    }

    /// The loaded form with the child reason, `email` and text beyond the prefill: Send is enabled.
    static func filledState(email: String = "me@example.com") -> ReportFormFeature.State {
        var state = readyState()
        state.reason = .child
        state.email = email
        state.details = filledDetails
        return state
    }

    @MainActor
    func makeStore(
        state: ReportFormFeature.State = openState(),
        client: ReportFormClient = ReportFormClient(),
        clock: any Clock<Duration> = TestClock(),
        dismissed: LockIsolated<Int> = LockIsolated(0),
        analyticsClient: AnalyticsClient = .unimplemented
    ) -> TestStoreOf<ReportFormFeature> {
        TestStore(initialState: state, reducer: ReportFormFeature.init) {
            $0.reportFormClient = client
            $0.continuousClock = clock
            $0.dismiss = DismissEffect { dismissed.withValue({ $0 += 1 }) }
            $0.analyticsClient = analyticsClient
        }
    }
}

extension ReportFormClient {
    /// The unimplemented test value with the given endpoints answered; any other call fails the test.
    static func stub(
        load: (@Sendable (URL) async throws -> ReportForm)? = nil,
        send: (@Sendable (URL, ReportType, String, String) async throws -> ReportSubmission)? = nil
    ) -> Self {
        var client = Self()
        if let load {
            client.load = load
        }
        if let send {
            client.send = send
        }
        return client
    }
}
