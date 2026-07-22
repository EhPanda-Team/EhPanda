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

// The capsule is a fixed shape: one line of title over one line of subtitle, never taller. Several
// `AppError` messages are deliberately two sentences split across lines, so the mapping has to
// flatten them before the view's line limits would otherwise drop the second sentence entirely.
struct ToastLineCountTests {
    @Test func aMultiLineErrorMessageIsFlattenedToOneLine() throws {
        // `.unknown` carries an embedded newline: "…occurred.\nPlease try again later."
        let content = AppAlertState<Never>.error(ErrorInfo(error: .unknown)).toastContent
        let subtitle = try #require(content.subtitle)

        #expect(!subtitle.contains("\n"))
        // Flattened, not cut at the break — the second sentence survives into the one line.
        #expect(!subtitle.isEmpty)
    }

    @Test func titlesAreFlattenedToo() {
        let content = AppAlertState<Never>.error(ErrorInfo(error: .unknown)).toastContent

        #expect(!content.title.contains("\n"))
    }

    @Test func aSingleLineMessageIsLeftAlone() {
        let content = AppAlertState<Never>.error(caption: "Unavailable").toastContent

        #expect(content.title == "Unavailable" || content.subtitle == "Unavailable")
    }
}
