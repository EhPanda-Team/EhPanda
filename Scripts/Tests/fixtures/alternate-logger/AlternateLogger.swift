import Foundation
import OSLog

func recordCookie(_ cookie: HTTPCookie, using securityEvents: Logger) {
    securityEvents.warning("Cookie value: \(cookie.value)")
}
