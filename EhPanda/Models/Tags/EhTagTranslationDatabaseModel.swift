//
//  EhTagTranslationDatabaseModel.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/20.
//

import Foundation

struct EhTagTranslationDatabaseResponse: Codable {
    struct Item: Codable {
        let name: String
        let intro: String
        let links: String
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

    var tagTranslations: [TagTranslation] {
        data.flatMap(\.tagTranslations)
    }
}
