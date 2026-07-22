import AppModels
import Foundation
@testable import ParserFeature
import Testing

// A rejected login is an HTTP 200 carrying an ordinary forum page. A wrong password, a temporary
// lockout after repeated failures and a missing field all share that status code and all leave the
// auth cookies unset, so the forum's own error box is the only thing that distinguishes them.
struct LoginErrorMessageParserTests {
    @Test
    func messageIsLiftedOutOfTheForumsErrorBox() {
        let message = Parser.parseLoginErrorMessage(content: Self.errorPage(reason: "You must enter a username"))

        #expect(message == "You must enter a username")
    }

    // The point of passing the text through verbatim: a lockout is the case this app was blind to,
    // and its wording is the server's to choose, not ours to enumerate.
    @Test
    func aLockoutMessageSurvivesUnchanged() {
        let reason = "You have exceeded the number of login attempts, please wait 15 minutes"
        let message = Parser.parseLoginErrorMessage(content: Self.errorPage(reason: reason))

        #expect(message == reason)
    }

    @Test(arguments: [
        "<html><body><p>Welcome back.</p></body></html>",
        "",
        "<html><body>The error returned was:</body></html>"
    ])
    func pagesWithoutAUsableErrorBoxYieldNothing(content: String) {
        #expect(Parser.parseLoginErrorMessage(content: content) == nil)
    }

    @Test
    func markupAndEntitiesBetweenTheMarkerAndTheMessageAreIgnored() {
        let content = """
            <div class="pformstrip">The error returned was:</div>&nbsp;
            <table><tr><td><strong>Bad password</strong></td></tr></table>
            """

        #expect(Parser.parseLoginErrorMessage(content: content) == "Bad password")
    }

    // The label is the forum's, and its class attribute is not always just the one class.
    @Test(arguments: ["pformstrip", "formsubtitle", "pformstrip alt", "row2 formsubtitle"])
    func theLabelIsFoundWhateverElseItsClassAttributeCarries(labelClass: String) {
        let content = """
            <div class="\(labelClass)">The error returned was:</div>
            <div class="pformleft">Bad password</div>
            """

        #expect(Parser.parseLoginErrorMessage(content: content) == "Bad password")
    }

    // A marker phrase is evidence of a refusal only where the forum writes it — as the error box's
    // own label. Reading it anywhere on the page turns a page that merely quotes one into a refusal,
    // and that misfire is worse than a missed message: the caller throws before `setCredentials`
    // runs, so a login that actually succeeded is reported as failed and the session cookies it just
    // earned are dropped.
    @Test
    func aMarkerQuotedInOrdinaryContentIsNotAnErrorBox() {
        let content = """
            <html><body>
            <div class="borderwrap"><div class="maintitle">Welcome back</div>
            <table><tr><td><a href="showtopic=1234">Re: the error returned was: a saga</a></td></tr>
            <tr><td>Posted yesterday</td></tr></table>
            </div>
            </body></html>
            """

        #expect(Parser.parseLoginErrorMessage(content: content) == nil)
    }

    // Finding a label is not enough on its own — that label has to be the one carrying the marker,
    // or a real board message about something else adopts a phrase from further down the page.
    @Test
    func aLabelSayingSomethingElseDoesNotAdoptAMarkerFromElsewhereOnThePage() {
        let content = """
            <html><body>
            <div class="pformstrip">Board Message</div>
            <div class="pformleft">Your post has been submitted.</div>
            <div class="postcolor">Someone asked what the error returned was: nobody knew.</div>
            </body></html>
            """

        #expect(Parser.parseLoginErrorMessage(content: content) == nil)
    }

    // Untrusted remote text on its way to a log, so the length bound belongs to the parser rather
    // than to each call site that might forget it.
    @Test
    func anAbsurdlyLongMessageIsBounded() {
        let reason = String(repeating: "x", count: 500)
        let message = Parser.parseLoginErrorMessage(content: Self.errorPage(reason: reason))

        #expect(message?.count == 200)
    }

    /// The shape the forum software actually returns: a `Board Message` block whose useful content
    /// sits under a "The error returned was:" label.
    private static func errorPage(reason: String) -> String {
        """
        <html><body>
        <div class="borderwrap"><div class="maintitle">Board Message</div>
        <p>Sorry, an error occurred.</p>
        <div class="pformstrip">The error returned was:</div>
        <div class="pformleft">\(reason)</div>
        </div>
        </body></html>
        """
    }
}

// The forum labels a refused login two different ways, and the second one is what a CAPTCHA
// rejection arrives under. Reading only the first is how that went unreported.
struct LoginFormErrorParserTests {
    @Test
    func theFormLevelErrorListIsReadToo() {
        let message = Parser.parseLoginErrorMessage(content: Self.captchaRejectionPage)

        #expect(message == "The captcha was not entered correctly. Please try again.")
    }

    @Test
    func aTurnstileGatedFormIsRecognised() {
        #expect(Parser.loginFormRequiresCaptcha(content: Self.captchaRejectionPage))
    }

    @Test
    func anUngatedFormIsNotMistakenForOne() {
        let page = """
            <html><body><form name="LOGIN">
            <input type="text" name="UserName" /><input type="password" name="PassWord" />
            </form></body></html>
            """

        #expect(!Parser.loginFormRequiresCaptcha(content: page))
    }

    /// Trimmed from a real refusal: the widget in the form, and the error list above it.
    private static let captchaRejectionPage = """
        <html><head>
        <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
        </head><body>
        <div class="borderwrap">
            <div class="formsubtitle">The following errors were found:</div>
            <div class="tablepad"><span class="postcolor">The captcha was not entered correctly. \
        Please try again.</span></div>
        </div>
        <form name="LOGIN">
        <div class="cf-turnstile" data-sitekey="0x4AAAAAAC-TvH-cv03mjH96"></div>
        </form>
        </body></html>
        """
}
