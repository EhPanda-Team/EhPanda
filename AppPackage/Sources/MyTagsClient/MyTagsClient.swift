public import AppModels
public import ComposableArchitecture
import NetworkingFeature

/// Every My Tags call a reducer makes: the reads of every tag set or one, the writes of a tag or a tag set, the
/// create and the delete of a tag set, and the site's tag suggestions (port of PR 462 item 10; the create, quick
/// 261126-pfh; the delete, quick 261126-udx; the suggestions, quick 261126-wzg).
///
/// One dependency, so a test states each outcome and the unimplemented test value reports any call a test did not
/// expect. `live` builds the requests with their own defaults on the host the caller has selected.
public struct MyTagsClient: Sendable {
    /// Every tag set, with the edit API's credentials.
    public var fetchMyTags: @Sendable (_ host: GalleryHost) async throws(AppError) -> MyTagsResponse
    /// One tag set's page.
    public var fetchTagSet: @Sendable (_ host: GalleryHost, _ tagSetID: Int) async throws(AppError) -> MyTagsPage
    /// Adds a tag to a set; answers the page the site returned.
    public var addTag: @Sendable (
        _ host: GalleryHost,
        _ tag: MyTagDraft,
        _ tagSetID: Int
    ) async throws(AppError) -> MyTagsPage
    /// Sets a tag's state, colour and weight through the edit API.
    public var updateTag: @Sendable (
        _ host: GalleryHost,
        _ apiuid: Int,
        _ apikey: String,
        _ tag: MyTag
    ) async throws(AppError) -> MyTagEditReply
    /// Removes tags from a set; answers the page the site returned.
    public var removeTags: @Sendable (
        _ host: GalleryHost,
        _ tagIDs: [Int],
        _ tagSetID: Int
    ) async throws(AppError) -> MyTagsPage
    /// Sets a set's Enabled flag and default colour; answers the page the site returned.
    public var updateTagSet: @Sendable (
        _ host: GalleryHost,
        _ tagSetID: Int,
        _ isEnabled: Bool,
        _ color: SiteColor?
    ) async throws(AppError) -> MyTagsPage
    /// Creates a tag set named `name` from the form of `shownTagSet`, the set the page shows; answers the page the
    /// site returned. Put on the wire once (`CreateMyTagSetRequest`).
    public var createTagSet: @Sendable (
        _ host: GalleryHost,
        _ name: String,
        _ shownTagSet: MyTagSet
    ) async throws(AppError) -> MyTagsPage
    /// Deletes `tagSet`, the set the page shows, from its own form; answers the page the site returned. Put on the
    /// wire once (`DeleteMyTagSetRequest`).
    public var deleteTagSet: @Sendable (
        _ host: GalleryHost,
        _ tagSet: MyTagSet
    ) async throws(AppError) -> MyTagsPage
    /// The site's suggestions for the tag being typed, as its own tag field asks for them (`TagSuggestRequest`).
    public var suggestTags: @Sendable (
        _ host: GalleryHost,
        _ query: TagSuggestQuery
    ) async throws(AppError) -> [SiteTagSuggestion]
}

// MARK: Live
extension MyTagsClient {
    public static let live = Self(
        fetchMyTags: requestMyTags,
        fetchTagSet: requestTagSet,
        addTag: requestAddTag,
        updateTag: requestUpdateTag,
        removeTags: requestRemoveTags,
        updateTagSet: requestUpdateTagSet,
        createTagSet: requestCreateTagSet,
        deleteTagSet: requestDeleteTagSet,
        suggestTags: requestSuggestTags
    )

    private static func requestMyTags(host: GalleryHost) async throws(AppError) -> MyTagsResponse {
        try await MyTagsRequest(host: host).response()
    }

    private static func requestTagSet(host: GalleryHost, tagSetID: Int) async throws(AppError) -> MyTagsPage {
        try await MyTagSetRequest(host: host, tagSetID: tagSetID).response()
    }

    private static func requestAddTag(
        host: GalleryHost,
        tag: MyTagDraft,
        tagSetID: Int
    ) async throws(AppError) -> MyTagsPage {
        try await AddMyTagRequest(host: host, tagSetID: tagSetID, tag: tag).response()
    }

    private static func requestUpdateTag(
        host: GalleryHost,
        apiuid: Int,
        apikey: String,
        tag: MyTag
    ) async throws(AppError) -> MyTagEditReply {
        try await UpdateMyTagRequest(host: host, apiuid: apiuid, apikey: apikey, tag: tag).response()
    }

    private static func requestRemoveTags(
        host: GalleryHost,
        tagIDs: [Int],
        tagSetID: Int
    ) async throws(AppError) -> MyTagsPage {
        try await RemoveMyTagsRequest(host: host, tagSetID: tagSetID, tagIDs: tagIDs).response()
    }

    private static func requestUpdateTagSet(
        host: GalleryHost,
        tagSetID: Int,
        isEnabled: Bool,
        color: SiteColor?
    ) async throws(AppError) -> MyTagsPage {
        try await UpdateMyTagSetRequest(host: host, tagSetID: tagSetID, isEnabled: isEnabled, color: color)
            .response()
    }

    private static func requestCreateTagSet(
        host: GalleryHost,
        name: String,
        shownTagSet: MyTagSet
    ) async throws(AppError) -> MyTagsPage {
        try await CreateMyTagSetRequest(host: host, name: name, shownTagSet: shownTagSet).response()
    }

    private static func requestDeleteTagSet(
        host: GalleryHost,
        tagSet: MyTagSet
    ) async throws(AppError) -> MyTagsPage {
        try await DeleteMyTagSetRequest(host: host, tagSet: tagSet).response()
    }

    private static func requestSuggestTags(
        host: GalleryHost,
        query: TagSuggestQuery
    ) async throws(AppError) -> [SiteTagSuggestion] {
        try await TagSuggestRequest(host: host, query: query).response()
    }
}

public enum MyTagsClientKey: DependencyKey {
    public static let liveValue = MyTagsClient.live
    public static let previewValue = MyTagsClient.noop
    public static let testValue = MyTagsClient.unimplemented
}

extension DependencyValues {
    public var myTagsClient: MyTagsClient {
        get { self[MyTagsClientKey.self] }
        set { self[MyTagsClientKey.self] = newValue }
    }
}

// MARK: Test
extension MyTagsClient {
    /// Answers the fetch with no tag sets, so no tag carries a symbol and no tag menu item shows, and the tag
    /// suggestions with none; fails every other call as not found, since a page has no empty answer.
    public static let noop = Self(
        fetchMyTags: { (_: GalleryHost) async throws(AppError) -> MyTagsResponse in
            MyTagsResponse(myTags: MyTags(tagSets: []), apiuid: 0, apikey: "")
        },
        fetchTagSet: { (_: GalleryHost, _: Int) async throws(AppError) -> MyTagsPage in
            throw .notFound
        },
        addTag: { (_: GalleryHost, _: MyTagDraft, _: Int) async throws(AppError) -> MyTagsPage in
            throw .notFound
        },
        updateTag: { (_: GalleryHost, _: Int, _: String, _: MyTag) async throws(AppError) -> MyTagEditReply in
            throw .notFound
        },
        removeTags: { (_: GalleryHost, _: [Int], _: Int) async throws(AppError) -> MyTagsPage in
            throw .notFound
        },
        updateTagSet: { (_: GalleryHost, _: Int, _: Bool, _: SiteColor?) async throws(AppError) -> MyTagsPage in
            throw .notFound
        },
        createTagSet: { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) -> MyTagsPage in
            throw .notFound
        },
        deleteTagSet: { (_: GalleryHost, _: MyTagSet) async throws(AppError) -> MyTagsPage in
            throw .notFound
        },
        suggestTags: { (_: GalleryHost, _: TagSuggestQuery) async throws(AppError) -> [SiteTagSuggestion] in
            []
        }
    )

    public static let unimplemented = Self(
        fetchMyTags: IssueReporting.unimplemented(
            "MyTagsClient.fetchMyTags", throwing: AppError.unknown
        ),
        fetchTagSet: IssueReporting.unimplemented(
            "MyTagsClient.fetchTagSet", throwing: AppError.unknown
        ),
        addTag: IssueReporting.unimplemented(
            "MyTagsClient.addTag", throwing: AppError.unknown
        ),
        updateTag: IssueReporting.unimplemented(
            "MyTagsClient.updateTag", throwing: AppError.unknown
        ),
        removeTags: IssueReporting.unimplemented(
            "MyTagsClient.removeTags", throwing: AppError.unknown
        ),
        updateTagSet: IssueReporting.unimplemented(
            "MyTagsClient.updateTagSet", throwing: AppError.unknown
        ),
        createTagSet: IssueReporting.unimplemented(
            "MyTagsClient.createTagSet", throwing: AppError.unknown
        ),
        deleteTagSet: IssueReporting.unimplemented(
            "MyTagsClient.deleteTagSet", throwing: AppError.unknown
        ),
        suggestTags: IssueReporting.unimplemented(
            "MyTagsClient.suggestTags", throwing: AppError.unknown
        )
    )

    /// Fails every call with `error` and reports nothing. Use it for a call a test starts but does not care about,
    /// failed the way an offline device would fail it.
    public static func failing(_ error: AppError) -> Self {
        Self(
            fetchMyTags: { (_: GalleryHost) async throws(AppError) -> MyTagsResponse in
                throw error
            },
            fetchTagSet: { (_: GalleryHost, _: Int) async throws(AppError) -> MyTagsPage in
                throw error
            },
            addTag: { (_: GalleryHost, _: MyTagDraft, _: Int) async throws(AppError) -> MyTagsPage in
                throw error
            },
            updateTag: { (_: GalleryHost, _: Int, _: String, _: MyTag) async throws(AppError) -> MyTagEditReply in
                throw error
            },
            removeTags: { (_: GalleryHost, _: [Int], _: Int) async throws(AppError) -> MyTagsPage in
                throw error
            },
            updateTagSet: { (_: GalleryHost, _: Int, _: Bool, _: SiteColor?) async throws(AppError) -> MyTagsPage in
                throw error
            },
            createTagSet: { (_: GalleryHost, _: String, _: MyTagSet) async throws(AppError) -> MyTagsPage in
                throw error
            },
            deleteTagSet: { (_: GalleryHost, _: MyTagSet) async throws(AppError) -> MyTagsPage in
                throw error
            },
            suggestTags: { (_: GalleryHost, _: TagSuggestQuery) async throws(AppError) -> [SiteTagSuggestion] in
                throw error
            }
        )
    }
}
