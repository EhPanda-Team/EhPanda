public import AppModels
import AppTools
public import Foundation
import ParserFeature

/// The site's tag suggestions for a tag being typed (G-1 of quick 261126-wzg), as the tag completer of its My Tags
/// page asks the API for them: `tagsuggest` with the query's text and nothing else, which the site answers signed in
/// or not. Answers every entry, in the order the site's list shows them; which of them the list keeps for the text is
/// `SiteTagSuggestion.matches(_:)`.
///
/// A read: it keeps `fetch`'s default attempts. The editor cancels it with its effect when the text changes.
public struct TagSuggestRequest: Request {
    public init(
        host: GalleryHost,
        query: TagSuggestQuery,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.query = query
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let query: TagSuggestQuery
    public let urlSession: URLSession

    public func response() async throws(AppError) -> [SiteTagSuggestion] {
        var request = URLRequest(url: Defaults.URL.api(host: host))
        request.httpMethod = "POST"
        request.httpBody = try encodeJSONObject(["method": "tagsuggest", "text": query.text])

        let (data, _) = try await fetch(request, in: urlSession)
        do {
            return try parseResponse(data: data, Parser.parseTagSuggestions)
        } catch {
            throw mapAppError(error: error)
        }
    }
}
