import Foundation
import OSLog

func recordCookie(_ cookie: HTTPCookie, using privacyLog: Logger) {
    privacyLog.info("Cookie value: \(cookie.value, privacy: .private)")
}
