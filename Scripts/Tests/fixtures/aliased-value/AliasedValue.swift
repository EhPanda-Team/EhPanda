import Foundation
import OSLog

func recordCookie(_ cookie: HTTPCookie, using auditLog: Logger) {
    let diagnosticValue = cookie.value
    auditLog.info("Cookie value: \(diagnosticValue, privacy: .public)")
}
