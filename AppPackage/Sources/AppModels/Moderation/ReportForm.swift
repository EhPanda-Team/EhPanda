/// A report type the native Report form sends, as the site's `report_type` value (18.1 D-05).
///
/// The form opens only from a comment, and a comment can be reported for child pornography or other illegal content
/// (owner msg 1950). The site's other values (copyright, updates and restore) are not offered anywhere (owner msg
/// 1975), so they have no case: a page that offers them is read for these two alone. The order is the form's order
/// (UI-SPEC C-13): child, then other illegal content.
public enum ReportType: String, CaseIterable, Sendable {
    case child
    case other
}

/// What the site's report page offers, read before the form is shown (18.1 DD-01).
public struct ReportForm: Equatable, Sendable {
    /// The recognised types the page's `select#report_type` offers. The form is usable only when both are present.
    public var types: Set<ReportType>
    /// The `#r_email` value the page carries, trimmed; empty for a guest. Prefilled, never stored (D-08).
    public var email: String
    /// Whether the page has the `#r_details` field.
    public var hasDetails: Bool

    public init(types: Set<ReportType>, email: String, hasDetails: Bool) {
        self.types = types
        self.email = email
        self.hasDetails = hasDetails
    }
}

/// How the site answered a submitted report (18.1 DD-03).
///
/// The site's reply to a real report has never been seen (owner msg 1933 rules out a real submission), so the rule is
/// deliberately narrow: a reply that still shows the report form is never taken as sent.
public enum ReportSubmission: Equatable, Sendable {
    /// The reply no longer shows the report form.
    case sent
    /// The reply still shows the report form.
    case rejected
}
