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
            <div>The error returned was:</div>&nbsp;
            <table><tr><td><strong>Bad password</strong></td></tr></table>
            """

        #expect(Parser.parseLoginErrorMessage(content: content) == "Bad password")
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
