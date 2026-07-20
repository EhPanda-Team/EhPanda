import AppComponents
import AppModels
import Foundation
@testable import SystemNotification
import Testing

struct ToastInteractionTests {
    private let errorInfo = ErrorInfo(error: .networkingFailed)

    @Test func onlyDiagnosticErrorsRemainPresented() {
        let diagnosticError = AppAlertState<Never>.error(errorInfo)
        let captionError = AppAlertState<Never>.error(caption: "Unavailable")
        let success = AppAlertState<Never>.success(caption: "Saved")

        #expect(diagnosticError.toastContent.autoHide == false)
        #expect(captionError.toastContent.autoHide)
        #expect(success.toastContent.autoHide)
    }
}
