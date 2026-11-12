import Foundation

public struct EhTagTranslationDatabaseResponse: Codable, Sendable {
    public init(
        data: [Model]
    ) {
        self.data = data
    }
    public struct Item: Codable, Sendable {
        public init(
            name: String,
            intro: String? = nil,
            links: String? = nil
        ) {
            self.name = name
            self.intro = intro
            self.links = links
        }
        public let name: String
        public var intro: String?
        public var links: String?
    }

    public struct Model: Codable, Sendable {
        public init(
            namespace: String,
            data: [String: Item]
        ) {
            self.namespace = namespace
            self.data = data
        }
        public let namespace: String
        public let data: [String: Item]

        public var tagTranslations: [TagTranslation] {
            guard let namespace = TagNamespace(rawValue: namespace) else { return .init() }
            return data.map {
                .init(
                    namespace: namespace, key: $0, value: $1.name,
                    description: $1.intro, linksString: $1.links
                )
            }
        }
    }

    public let data: [Model]

    public var tagTranslations: [String: TagTranslation] {
        .init(uniqueKeysWithValues: data.flatMap(\.tagTranslations).map({
            ($0.namespace.rawValue + $0.key, $0)
        }))
    }
}
