public import AppModels
import AppTools
public import Foundation
import Kanna
import ParserFeature

// The My Tags reads and writes (port of PR 462 item 10; the site contract read live on 2026-11-22). Every request but
// the create, the rename and the delete keeps `fetch`'s default four attempts: the reads are GETs, and a replayed
// write asks the site for the same end state (an add of a tag the set holds is taken unchanged, a remove of a tag the
// set no longer holds removes nothing, an edit or a tag set update sets the same values), so a lost response is safe
// to ask for again. A replayed create would make another set (N-4 of quick 261126-pfh), a replayed delete would find
// its set gone and come back refused though the delete took (U-5 of quick 261126-udx), and a replayed rename would
// ask the site for the name the set already has, whose answer is unknown here (W-2 of quick 261126-wzf), so all
// three are put on the wire once.

extension Request {
    /// A My Tags page the site served, or answered a form post with.
    fileprivate func myTagsPage(data: Data) throws(AppError) -> MyTagsPage {
        do {
            return try parseResponse(doc: htmlDocument(data: data), Parser.parseMyTags)
        } catch {
            throw mapAppError(error: error)
        }
    }

    /// Posts a My Tags form, its fields in order, to `url`, and parses the page the site answers with. `attempts` is
    /// `fetch`'s; its default suits a write the site can be asked for again (see the note above).
    fileprivate func postMyTagsForm(
        _ fields: [URLQueryItem],
        to url: URL,
        in session: URLSession,
        attempts: Int = 4
    ) async throws(AppError) -> MyTagsPage {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(fields.formURLEncodedString().utf8)
        request.setURLEncodedContentType()
        let (data, _) = try await fetch(request, in: session, attempts: attempts)
        return try myTagsPage(data: data)
    }

    /// The tag set form's fields in the browser's order, as the site's `do_tagset_post` submits the form: the action,
    /// the name (the new set's for a create, the new one for a rename, else the form's empty field), the Enabled box,
    /// which sends nothing when unchecked, and the colour, empty for none.
    fileprivate func tagSetFormFields(
        action: String,
        name: String,
        isEnabled: Bool,
        color: SiteColor?
    ) -> [URLQueryItem] {
        var fields = [
            URLQueryItem(name: "tagset_action", value: action),
            URLQueryItem(name: "tagset_name", value: name)
        ]
        if isEnabled {
            fields.append(URLQueryItem(name: "tagset_enable", value: "on"))
        }
        fields.append(URLQueryItem(name: "tagset_color", value: color?.hex ?? ""))
        return fields
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
        let fields = tagSetFormFields(action: "update", name: "", isEnabled: isEnabled, color: color)
        let url = Defaults.URL.myTags(host: host, tagSetID: tagSetID)
        return try await postMyTagsForm(fields, to: url, in: urlSession)
    }
}

/// Creates a tag set through the tag set form's New (`tagset_action=create`), as the site's `do_tagset_create` posts
/// it: the form of the set the page shows, to that set's page, its fields in the browser's order. Besides the new
/// set's name, those are the shown set's Enabled box, which sends nothing when unchecked, and its colour. Answers the
/// page the site returns, which carries the reason when it refused.
///
/// Put on the wire once (N-4 of quick 261126-pfh). A create is not an end state the site can be asked for again: one
/// the site took whose response was lost looks the same here as one it never received, and posting it again could
/// make a second set. A lost response costs the user one more Create instead, and a set the site did make shows at
/// the next read of My Tags.
public struct CreateMyTagSetRequest: Request {
    public init(
        host: GalleryHost,
        name: String,
        shownTagSet: MyTagSet,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.name = name
        self.shownTagSet = shownTagSet
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    /// The new set's name; the page sends it trimmed.
    public let name: String
    /// The set the page shows, whose form the create is posted from.
    public let shownTagSet: MyTagSet
    public let urlSession: URLSession

    public func response() async throws(AppError) -> MyTagsPage {
        let fields = tagSetFormFields(
            action: "create", name: name, isEnabled: shownTagSet.isEnabled, color: shownTagSet.color
        )
        let url = Defaults.URL.myTags(host: host, tagSetID: shownTagSet.id)
        return try await postMyTagsForm(fields, to: url, in: urlSession, attempts: 1)
    }
}

/// Renames a tag set through the tag set form's Rename (`tagset_action=rename`), as the site's `do_tagset_rename`
/// posts it once its prompt is answered: the form of the set the page shows, which is the set renamed, to that set's
/// page, its fields in the browser's order. Those are the new name, the set's Enabled box, which sends nothing when
/// unchecked, and its colour. Answers the page the site returns, which carries the reason when it refused.
///
/// Put on the wire once (W-2 of quick 261126-wzf). A replay asks for the same name, so it cannot rename twice; but a
/// rename the site took whose response was lost would then ask the site for the name the set already has, and what
/// the site answers to that is unknown here: a refusal would read as the failure of a rename that took, as a replayed
/// delete would (U-5 of quick 261126-udx). A lost response shows the failure instead, and the next read of My Tags
/// shows the name the site has.
public struct RenameMyTagSetRequest: Request {
    public init(
        host: GalleryHost,
        name: String,
        tagSet: MyTagSet,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.name = name
        self.tagSet = tagSet
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    /// The set's new name; the page sends it trimmed.
    public let name: String
    /// The set to rename, the one the page shows, whose form the rename is posted from.
    public let tagSet: MyTagSet
    public let urlSession: URLSession

    public func response() async throws(AppError) -> MyTagsPage {
        let fields = tagSetFormFields(action: "rename", name: name, isEnabled: tagSet.isEnabled, color: tagSet.color)
        let url = Defaults.URL.myTags(host: host, tagSetID: tagSet.id)
        return try await postMyTagsForm(fields, to: url, in: urlSession, attempts: 1)
    }
}

/// Deletes a tag set through the tag set form's Delete (`tagset_action=delete`), as the site's `do_tagset_delete`
/// posts it once its confirmation is accepted: the form of the set the page shows, which is the set deleted, to that
/// set's page, its fields in the browser's order. Those are the form's empty `tagset_name`, as with an update, the
/// set's Enabled box, which sends nothing when unchecked, and its colour. Answers the page the site returns, which
/// carries the reason when it refused.
///
/// Put on the wire once (U-5 of quick 261126-udx). A delete the site took whose response was lost looks the same here
/// as one it never received, and posting it again would find the set gone, so the site's answer would read as a
/// refusal of a delete that took. A lost response shows the failure instead, and the next read of My Tags shows
/// whether the set is gone.
public struct DeleteMyTagSetRequest: Request {
    public init(
        host: GalleryHost,
        tagSet: MyTagSet,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.tagSet = tagSet
        self.urlSession = urlSession
    }
    public let host: GalleryHost
    /// The set to delete, the one the page shows, whose form the delete is posted from.
    public let tagSet: MyTagSet
    public let urlSession: URLSession

    public func response() async throws(AppError) -> MyTagsPage {
        let fields = tagSetFormFields(action: "delete", name: "", isEnabled: tagSet.isEnabled, color: tagSet.color)
        let url = Defaults.URL.myTags(host: host, tagSetID: tagSet.id)
        return try await postMyTagsForm(fields, to: url, in: urlSession, attempts: 1)
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
