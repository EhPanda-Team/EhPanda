import SwiftUI
import Foundation

public struct MyTagsResponse: Sendable {
    public let tagSets: [(number: Int, name: String)]
    public let tagSetEnable: Bool
    public let tagSetBackgroundColor: Color?
    public let tags: [WatchedTag]
    public let apikey: String

    public init(
        tagSets: [(number: Int, name: String)],
        tagSetEnable: Bool,
        tagSetBackgroundColor: Color?,
        tags: [WatchedTag],
        apikey: String
    ) {
        self.tagSets = tagSets
        self.tagSetEnable = tagSetEnable
        self.tagSetBackgroundColor = tagSetBackgroundColor
        self.tags = tags
        self.apikey = apikey
    }
}

public struct WatchedTag: Identifiable, Equatable, Hashable, Sendable, Codable {
    public init(
        namespace: String,
        key: String,
        watched: Bool = true,
        hidden: Bool = false,
        backgroundColor: Color? = nil,
        weight: Int = 0
    ) {
        self.namespace = namespace
        self.key = key
        self.watched = watched
        self.hidden = hidden
        self.backgroundColor = backgroundColor
        self.weight = weight
    }
    public let id: String = UUID().uuidString
    public var namespace: String
    public var key: String
    public var watched: Bool
    public var hidden: Bool
    public var backgroundColor: Color?
    public var weight: Int

    enum CodingKeys: String, CodingKey {
        case namespace, key, watched, hidden, backgroundColor, weight
    }
}

public struct TagSetInfo: Equatable, Sendable, Codable {
    public init(
        number: Int,
        name: String,
        enable: Bool,
        backgroundColor: Color? = nil,
        tags: [WatchedTag] = []
    ) {
        self.number = number
        self.name = name
        self.enable = enable
        self.backgroundColor = backgroundColor
        self.tags = tags
    }
    public let number: Int
    public let name: String
    public var enable: Bool
    public var backgroundColor: Color?
    public var tags: [WatchedTag]
}
