//
//  EhTagTranslationDatabaseModel.swift
//  EhPanda
//

import Foundation

struct EhTagTranslationDatabaseResponse: Codable {
    struct Item: Codable {
        let name: String
        var intro: String?
        var links: String?
    }

    struct Model: Codable {
        let namespace: String
        let data: [String: Item]

        var tagTranslations: [TagTranslation] {
            guard let namespace = TagNamespace(rawValue: namespace) else { return .init() }
            return data.map {
                .init(
                    namespace: namespace, key: $0, value: $1.name,
                    description: $1.intro, linksString: $1.links
                )
            }
        }
    }

    let data: [Model]

    var tagTranslations: [String: TagTranslation] {
        .init(uniqueKeysWithValues: data.flatMap(\.tagTranslations).map({
            ($0.namespace.rawValue + $0.key, $0)
        }))
    }
}
