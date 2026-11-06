public import AppModels
import Foundation
public import Kanna

extension Parser {
    /// Reads the site's gallery report page (18.1 DD-01).
    ///
    /// A page is a usable form only when its `form#reportform` holds the type picker `select#report_type`, the email
    /// field `input#r_email`, the details field `textarea#r_details` and the `sendreport` submit, each under the name
    /// the report is posted with. The first step of the site's form (`?report=select`) has the picker alone, so it is
    /// not one. Only the option values that are a `ReportType` are read; any other value is ignored.
    ///
    /// The form's `action` is not read: the report is posted to a URL rebuilt from the validated gallery URL (DD-02).
    public static func parseReportForm(doc: any HTMLDocument) throws(AppError) -> ReportForm {
        guard let form = doc.at_xpath("//form[@id='reportform']"),
              let select = form.at_xpath(".//select[@id='report_type'][@name='report_type']"),
              let email = form.at_xpath(".//input[@id='r_email'][@name='r_email']"),
              form.at_xpath(".//textarea[@id='r_details'][@name='r_details']") != nil,
              form.at_xpath(".//input[@type='submit'][@name='sendreport']") != nil
        else { throw .parseFailed }

        let types = Set(select.xpath(".//option").compactMap({ $0["value"].flatMap(ReportType.init(rawValue:)) }))
        return ReportForm(
            types: types,
            email: (email["value"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            hasDetails: true
        )
    }

    /// Classifies the site's reply to a submitted report (18.1 DD-03, Research OQ-1).
    ///
    /// The site's reply to a real report has never been seen, so a reply is taken as sent only when it no longer
    /// shows the report form; a reply that still shows it is rejected.
    public static func parseReportSubmission(doc: any HTMLDocument) -> ReportSubmission {
        doc.at_xpath("//*[@id='reportform']") == nil ? .sent : .rejected
    }
}
