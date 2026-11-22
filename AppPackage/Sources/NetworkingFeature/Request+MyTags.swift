public import AppModels
import AppTools
public import Foundation
import Kanna
import ParserFeature

// The My Tags reads and writes (port of PR 462 item 10; the site contract read live on 2026-11-22). Every request
// keeps `fetch`'s default four attempts: the reads are GETs, and a replayed write asks the site for the same end
// state (an add of a tag the set holds is taken unchanged, a remove of a tag the set no longer holds removes nothing,
// an edit or a tag set update sets the same values), so a lost response is safe to ask for again.

extension Request {
    /// A My Tags page the site served, or answered a form post with.
    fileprivate func myTagsPage(data: Data) throws(AppError) -> MyTagsPage {
        do {
            return try parseResponse(doc: htmlDocument(data: data), Parser.parseMyTags)
        } catch {
            throw mapAppError(error: error)
        }
    }

    /// Posts a My Tags form, its fields in order, to `url`, and parses the page the site answers with.
    fileprivate func postMyTagsForm(
        _ fields: [URLQueryItem],
        to url: URL,
        in session: URLSession
    ) async throws(AppError) -> MyTagsPage {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(fields.formURLEncodedString().utf8)
        request.setURLEncodedContentType()
        let (data, _) = try await fetch(request, in: session)
        return try myTagsPage(data: data)
    }
}

/// Every tag set of My Tags: the first set's page, then every other set its picker lists, in the picker's order. The
/// credentials are the first page's.
public struct MyTagsRequest: Request {
    public init(
        host: GalleryHost,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let urlSession: URLSession

    public func response() async throws(AppError) -> MyTagsResponse {
        let first = try await MyTagSetRequest(host: host, tagSetID: 1, urlSession: urlSession).response()
        var tagSets = [MyTagSet]()
        for tagSetID in first.tagSetIDs {
            if tagSetID == first.tagSet.id {
                tagSets.append(first.tagSet)
            } else {
                let other = try await MyTagSetRequest(host: host, tagSetID: tagSetID, urlSession: urlSession).response()
                tagSets.append(other.tagSet)
            }
        }
        return MyTagsResponse(myTags: MyTags(tagSets: tagSets), apiuid: first.apiuid, apikey: first.apikey)
    }
}

/// One tag set's page of My Tags, at the address the site's own picker links it.
public struct MyTagSetRequest: Request {
    public init(
        host: GalleryHost,
        tagSetID: Int,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.tagSetID = tagSetID
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let tagSetID: Int
    public let urlSession: URLSession

    public func response() async throws(AppError) -> MyTagsPage {
        let url = Defaults.URL.myTags(host: host, tagSetID: tagSetID)
        let (data, _) = try await fetch(URLRequest(url: url), in: urlSession)
        return try myTagsPage(data: data)
    }
}

/// Adds a tag to a tag set through the page's add row: its state, colour and weight. Answers the page the site
/// returns, which carries the reason when it refused (an unknown tag).
public struct AddMyTagRequest: Request {
    public init(
        host: GalleryHost,
        tagSetID: Int,
        tag: MyTagDraft,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.tagSetID = tagSetID
        self.tag = tag
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let tagSetID: Int
    public let tag: MyTagDraft
    public let urlSession: URLSession

    public func response() async throws(AppError) -> MyTagsPage {
        var fields = [
            URLQueryItem(name: "usertag_action", value: "add"),
            URLQueryItem(name: "tagname_new", value: tag.name)
        ]
        switch tag.kind {
        case .flagged:
            break
        case .watched:
            fields.append(URLQueryItem(name: "tagwatch_new", value: "on"))
        case .hidden:
            fields.append(URLQueryItem(name: "taghide_new", value: "on"))
        }
        fields += [
            URLQueryItem(name: "tagcolor_new", value: tag.color?.hex ?? ""),
            URLQueryItem(name: "tagweight_new", value: String(tag.weight)),
            URLQueryItem(name: "usertag_target", value: "0")
        ]
        let url = Defaults.URL.myTags(host: host, tagSetID: tagSetID)
        return try await postMyTagsForm(fields, to: url, in: urlSession)
    }
}

/// Removes tags from a tag set through the page's Delete Selected action. Answers the page the site returns.
public struct RemoveMyTagsRequest: Request {
    public init(
        host: GalleryHost,
        tagSetID: Int,
        tagIDs: [Int],
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.tagSetID = tagSetID
        self.tagIDs = tagIDs
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let tagSetID: Int
    public let tagIDs: [Int]
    public let urlSession: URLSession

    public func response() async throws(AppError) -> MyTagsPage {
        let fields = [URLQueryItem(name: "usertag_action", value: "mass")]
            + tagIDs.map({ URLQueryItem(name: "modify_usertags[]", value: String($0)) })
            + [URLQueryItem(name: "usertag_target", value: "0")]
        let url = Defaults.URL.myTags(host: host, tagSetID: tagSetID)
        return try await postMyTagsForm(fields, to: url, in: urlSession)
    }
}

/// Sets a tag set's Enabled flag and default colour through the tag set form's Save (`tagset_action=update`), its
/// fields in the form's order; an unchecked Enabled box sends nothing, as a browser does. The site's `do_tagset_post`
/// sends the form's empty `tagset_name` with an update too. Answers the page the site returns.
public struct UpdateMyTagSetRequest: Request {
    public init(
        host: GalleryHost,
        tagSetID: Int,
        isEnabled: Bool,
        color: SiteColor?,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.tagSetID = tagSetID
        self.isEnabled = isEnabled
        self.color = color
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let tagSetID: Int
    public let isEnabled: Bool
    public let color: SiteColor?
    public let urlSession: URLSession

    public func response() async throws(AppError) -> MyTagsPage {
        var fields = [
            URLQueryItem(name: "tagset_action", value: "update"),
            URLQueryItem(name: "tagset_name", value: "")
        ]
        if isEnabled {
            fields.append(URLQueryItem(name: "tagset_enable", value: "on"))
        }
        fields.append(URLQueryItem(name: "tagset_color", value: color?.hex ?? ""))
        let url = Defaults.URL.myTags(host: host, tagSetID: tagSetID)
        return try await postMyTagsForm(fields, to: url, in: urlSession)
    }
}

/// Sets a tag's Watched and Hidden state, colour and weight through the site's edit API, `setusertag`.
///
/// The API answers `{"tagid": <id>}` when it took the edit and `{"error": "<reason>", …}` when it refused it. Its
/// success is no proof the tag exists: an unknown tag id is answered the same way and changes nothing.
public struct UpdateMyTagRequest: Request {
    public init(
        host: GalleryHost,
        apiuid: Int,
        apikey: String,
        tag: MyTag,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.apiuid = apiuid
        self.apikey = apikey
        self.tag = tag
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    public let apiuid: Int
    public let apikey: String
    public let tag: MyTag
    public let urlSession: URLSession

    public func response() async throws(AppError) -> MyTagEditReply {
        let params: [String: Any] = [
            "method": "setusertag",
            "apiuid": apiuid,
            "apikey": apikey,
            "tagid": tag.id,
            "tagwatch": tag.isWatched ? 1 : 0,
            "taghide": tag.isHidden ? 1 : 0,
            "tagcolor": tag.color?.hex ?? "",
            "tagweight": String(tag.weight)
        ]

        var request = URLRequest(url: Defaults.URL.api(host: host))
        request.httpMethod = "POST"
        request.httpBody = try encodeJSONObject(params)

        let (data, _) = try await fetch(request, in: urlSession)
        do {
            return try parseResponse(data: data) { (body: Data) throws -> MyTagEditReply in
                let reply = try JSONDecoder().decode(SetUserTagReply.self, from: body)
                if let error = reply.error {
                    return .refused(String(error.prefix(200)))
                }
                guard reply.tagID != nil else { throw AppError.parseFailed }
                return .accepted
            }
        } catch {
            throw mapAppError(error: error)
        }
    }
}

/// The edit API's reply: the tag's id when it took the edit, the reason when it refused it.
private struct SetUserTagReply: Decodable {
    let tagID: Int?
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case tagID = "tagid"
        case error
    }
}
