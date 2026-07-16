import AppComponents
import AppModels
import Foundation
@testable import SystemNotificationExt
import Testing

struct ToastInteractionTests {
    private let firstID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    private let secondID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
    private let errorInfo = ErrorInfo(error: .networkingFailed)

    @Test func activationConsumesTheCurrentErrorExactlyOnce() {
        var state = ToastInteractionState()
        state.present(id: firstID, errorInfo: errorInfo)

        #expect(state.activate(presentedID: firstID) == errorInfo)
        #expect(state.activate(presentedID: firstID) == nil)
    }

    @Test func replacementInvalidatesThePreviousToast() {
        var state = ToastInteractionState()
        state.present(id: firstID, errorInfo: errorInfo)
        state.present(id: secondID, errorInfo: errorInfo)

        #expect(state.activate(presentedID: firstID) == nil)
        #expect(state.activate(presentedID: secondID) == errorInfo)
        #expect(state.activate(presentedID: secondID) == nil)
    }

    @Test func dismissalInvalidatesTheCurrentToast() {
        var state = ToastInteractionState()
        state.present(id: firstID, errorInfo: errorInfo)

        state.dismiss(presentedID: firstID)

        #expect(state.activate(presentedID: firstID) == nil)
    }

    @Test func staleDismissalDoesNotInvalidateTheReplacement() {
        var state = ToastInteractionState()
        state.present(id: firstID, errorInfo: errorInfo)
        state.present(id: secondID, errorInfo: errorInfo)

        state.dismiss(presentedID: firstID)

        #expect(state.activate(presentedID: secondID) == errorInfo)
    }

    @Test func onlyDiagnosticErrorsRemainPresented() {
        let diagnosticError = AppAlertState<Never>.error(errorInfo)
        let captionError = AppAlertState<Never>.error(caption: "Unavailable")
        let success = AppAlertState<Never>.success(caption: "Saved")

        #expect(diagnosticError.toastContent.autoHide == false)
        #expect(captionError.toastContent.autoHide)
        #expect(success.toastContent.autoHide)
    }
}
