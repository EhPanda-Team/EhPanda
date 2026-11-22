import Foundation
import Sentry

/// The `beforeSend` scrubber: the last thing that touches a crash report before it leaves the device.
///
/// It never drops an event. A smaller crash report is still a crash report, so every rule below
/// removes or rewrites data and none of them returns `nil`: a scrubber that dropped events on a doubt
/// would silently turn crash reporting off exactly when something unexpected is in the report.
///
/// The type is nonisolated, pure and stateless on purpose. Sentry calls `beforeSend` on its own
/// queue, and the scrubber must neither hop to the main actor nor keep state between events.
enum CrashReportScrubber {
    /// The only contexts that survive. Each was reviewed and holds device and build facts, nothing
    /// about the person. Every other context is dropped whole, because the SDK puts an uncaught
    /// `NSException`'s `userInfo` free text in a context of its own.
    static let keptContexts: Set<String> = ["app", "culture", "device", "os", "trace"]

    /// The most characters any free-text field keeps, so a long message that slipped past a pattern
    /// still cannot carry a whole document out of the device.
    static let freeTextLimit = 300

    private static let redactedToken = "[redacted]"

    /// Clears or rewrites every field of `event` that could carry data about the person, and returns
    /// the same instance.
    ///
    /// The event is mutated in place, because the SDK's event model is made of reference types and
    /// hands this callback the instance it is about to send. The result is discardable for that reason.
    @discardableResult
    static func scrub(_ event: Event) -> Event {
        event.user = nil
        event.breadcrumbs = nil
        event.request = nil
        event.tags = nil
        event.extra = nil

        scrubContexts(of: event)
        scrubMessage(of: event)
        scrubExceptions(of: event)
        scrubPaths(of: event)
        return event
    }

    /// Redacts one free-text value.
    ///
    /// The order matters. URLs go first so that a home-folder match, which runs later, cannot swallow
    /// the scheme of a URL that follows it, and so that every later pattern only ever sees what is
    /// left of a URL, which is nothing. Address patterns (e-mail, IPv4, IPv6) respect token
    /// boundaries, so a version number, a `v1.2.3.4` tag or a `12:34:56` time of day survives while a
    /// real address does not. The cut to ``freeTextLimit`` runs last, after every pattern has seen
    /// the whole text, so a secret that straddles the limit is redacted before the cut and not
    /// half-kept by it.
    static func redact(_ text: String) -> String {
        var result = text.replacing(urlReference, with: redactedToken)
        result = redactingSiteHosts(in: result)
        result = result.replacing(credentialCookie, with: redactedToken)
        result = redactingEmailAddresses(in: result)
        result = redactingIPv4Addresses(in: result)
        result = redactingIPv6Addresses(in: result)
        result = redactHomeFolder(result)
        return String(result.prefix(freeTextLimit))
    }

    /// Replaces the account name of a `/Users/<name>` home folder, the only part of a path that names
    /// the person. Used alone for stack-frame packages and debug-image paths, which are paths and not
    /// free text, so they are neither URL-redacted nor cut.
    static func redactHomeFolder(_ path: String) -> String {
        path.replacing(homeFolder, with: "/Users/_")
    }
}

// MARK: Event fields
extension CrashReportScrubber {
    private static func scrubContexts(of event: Event) {
        guard var contexts = event.context?.filter({ keptContexts.contains($0.key) }) else { return }
        contexts["app"]?.removeValue(forKey: "device_app_hash")
        event.context = contexts
    }

    private static func scrubMessage(of event: Event) {
        guard let message = event.message else { return }
        let scrubbed = SentryMessage(formatted: redact(message.formatted))
        scrubbed.message = message.message.map(redact)
        scrubbed.params = message.params.map({ params in params.map(redact) })
        event.message = scrubbed
    }

    private static func scrubExceptions(of event: Event) {
        for exception in event.exceptions ?? [] {
            exception.value = exception.value.map(redact)
            // The Swift runtime's `crash_info_messages` lives here, nested, and carries free text.
            exception.mechanism?.data = exception.mechanism?.data.map({ data in redactStrings(in: data) })
        }
    }

    private static func scrubPaths(of event: Event) {
        for exception in event.exceptions ?? [] {
            redactPackages(in: exception.stacktrace)
        }
        for thread in event.threads ?? [] {
            redactPackages(in: thread.stacktrace)
        }
        redactPackages(in: event.stacktrace)
        for image in event.debugMeta ?? [] {
            image.codeFile = image.codeFile.map(redactHomeFolder)
        }
    }

    private static func redactPackages(in stacktrace: SentryStacktrace?) {
        for frame in stacktrace?.frames ?? [] {
            frame.package = frame.package.map(redactHomeFolder)
        }
    }

    /// Redacts every string at any depth of `value`; other values and every dictionary key are left
    /// untouched.
    private static func redactStrings(in data: [String: Any]) -> [String: Any] {
        data.mapValues({ value in redactStrings(inValue: value) })
    }

    private static func redactStrings(inValue value: Any) -> Any {
        switch value {
        case let text as String:
            redact(text)
        case let dictionary as [String: Any]:
            redactStrings(in: dictionary)
        case let array as [Any]:
            array.map({ element in redactStrings(inValue: element) })
        default:
            value
        }
    }
}

// MARK: Patterns
/// Each pattern is built where it is used, or is a computed property, because `Regex` is not `Sendable`
/// and so cannot be a stored `static let`. Swift Regex has no lookbehind, so every "not preceded by"
/// boundary is a leading capture group named `boundary` that the replacement writes back. The regex
/// of those rules is a function-local `let` so that its capture tuple is read by name and never spelled.
extension CrashReportScrubber {
    /// A scheme, `://`, and the rest of the non-whitespace run: every URL, whatever its scheme,
    /// including `ehpanda://` and `file://` references.
    private static var urlReference: Regex<Substring> {
        #/[A-Za-z][A-Za-z0-9+.\-]*:\/\/\S*/#
    }

    /// A credential cookie written as a `name=value` or JSON-style `"name": "value"` pair. The names
    /// are `Defaults.Cookie.ipbMemberId`, `.ipbPassHash` and `.igneous`, which a test keeps in step.
    private static var credentialCookie: Regex<Substring> {
        #/(?i)\b(?:ipb_member_id|ipb_pass_hash|igneous)["']?\s*[=:]\s*["']?[^;,&"'\s]*/#
    }

    private static var homeFolder: Regex<Substring> {
        #/\/Users\/[^\/\s]+/#
    }

    /// A scheme-less E-Hentai or ExHentai host reference, with any subdomain, port and path.
    private static func redactingSiteHosts(in text: String) -> String {
        let siteHost = #/
            (?<boundary>^|[^\w.\-\/])
            (?i:(?:[a-z0-9\-]+\.)*(?:e-hentai|exhentai)\.org(?::\d+)?(?:[\/?\#]\S*)?)
            /#
        return text.replacing(siteHost, with: { "\($0.output.boundary)\(redactedToken)" })
    }

    private static func redactingEmailAddresses(in text: String) -> String {
        let emailAddress = #/(?<boundary>^|[^\w.])[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)*/#
        return text.replacing(emailAddress, with: { "\($0.output.boundary)\(redactedToken)" })
    }

    private static func redactingIPv4Addresses(in text: String) -> String {
        let ipv4Address = #/(?<boundary>^|[^\w.:])\d{1,3}(?:\.\d{1,3}){3}(?!\w|\.\d)/#
        return text.replacing(ipv4Address, with: { "\($0.output.boundary)\(redactedToken)" })
    }

    /// Either all eight groups, or a compressed form that holds `::`, optionally ending in a dotted
    /// IPv4 tail and a `%zone`.
    private static func redactingIPv6Addresses(in text: String) -> String {
        let ipv6Address = #/
            (?<boundary>^|[^\w:])
            (?:
                (?:[0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4}
                |
                (?:[0-9A-Fa-f]{1,4}(?::[0-9A-Fa-f]{1,4}){0,6})?
                ::
                (?:[0-9A-Fa-f]{1,4}(?::[0-9A-Fa-f]{1,4}){0,6})?
            )
            (?:\.\d{1,3}){0,3}
            (?:%[0-9A-Za-z._\-]+)?
            (?![\w:])
            /#
        return text.replacing(ipv6Address, with: { "\($0.output.boundary)\(redactedToken)" })
    }
}
