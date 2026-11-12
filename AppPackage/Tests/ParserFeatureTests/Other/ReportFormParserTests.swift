import AppModels
import Foundation
import Kanna
import ParserFeature
import Testing
import TestingSupport

/// The site's report pages, saved as a guest on 2026-11-06 (18.1 DD-01, DD-03).
///
/// `ReportOther` and `ReportChild` are the second step of the site's form. `ReportSelect` is its first step, which has
/// only the type picker and so is not a form the app can send. The inline pages are `ReportOther` with one detail
/// changed.
struct ReportFormParserTests: TestHelper {
    @Test(arguments: [HTMLFilename.reportOther, .reportChild])
    func theSecondStepPageOffersBothCommentTypes(filename: HTMLFilename) throws {
        let form = try Parser.parseReportForm(doc: htmlDocument(filename: filename))

        // The page also offers the copyright and technical types; they are ignored.
        #expect(form == ReportForm(types: [.child, .other], email: "", hasDetails: true))
    }

    @Test
    func theFirstStepPageIsNotAForm() throws {
        let document = try htmlDocument(filename: .reportSelect)

        #expect(throws: AppError.parseFailed) {
            try Parser.parseReportForm(doc: document)
        }
    }

    @Test
    func aPageWithoutTheChildOptionOffersOnlyOther() throws {
        let document = try reportOther(
            replacing: #"<option value="child">Child Pornography</option>"#,
            with: ""
        )

        #expect(try Parser.parseReportForm(doc: document).types == [.other])
    }

    @Test
    func aRememberedEmailIsRead() throws {
        let document = try reportOther(
            replacing: #"id="r_email" name="r_email" placeholder="Please provide a working email address." value="""#,
            with: #"id="r_email" name="r_email" value="someone@example.com""#
        )

        #expect(try Parser.parseReportForm(doc: document).email == "someone@example.com")
    }

    @Test(arguments: [
        // The form
        #"<form id="reportform""#,
        // The type picker
        #"<select id="report_type" name="report_type""#,
        // The email field
        #"<input type="text" id="r_email" name="r_email""#,
        // The details field
        #"<textarea id="r_details" name="r_details""#,
        // The submit button
        #"<input type="submit" name="sendreport""#
    ])
    func aPageMissingAPartOfTheFormIsNotAForm(part: String) throws {
        let document = try reportOther(replacing: part, with: "<span")

        #expect(throws: AppError.parseFailed) {
            try Parser.parseReportForm(doc: document)
        }
    }

    @Test
    func aReplyThatStillShowsTheFormIsRejected() throws {
        let document = try htmlDocument(filename: .reportOther)

        #expect(Parser.parseReportSubmission(doc: document) == .rejected)
    }

    @Test
    func aReplyWithoutTheFormIsSent() throws {
        let document = try Kanna.HTML(
            html: "<html><body><p>Thank you for your report.</p></body></html>",
            encoding: .utf8
        )

        #expect(Parser.parseReportSubmission(doc: document) == .sent)
    }

    @Test
    func theTypesAreChildThenOther() {
        #expect(ReportType.allCases.map(\.rawValue) == ["child", "other"])
    }

    private func reportOther(replacing target: String, with replacement: String) throws -> any HTMLDocument {
        let html = try htmlString(filename: .reportOther)
        // A guard against a test that silently changes nothing.
        try #require(html.contains(target))
        return try Kanna.HTML(html: html.replacing(target, with: replacement), encoding: .utf8)
    }
}
