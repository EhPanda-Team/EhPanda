//
//  ListParserTestType.swift
//  EhPandaTests
//
//  Created by 荒木辰造 on R 4/02/11.
//

enum ListParserTestType: CaseIterable {
    case frontpage
    case watched
    case popular
    case favorites
    case toplists
}

extension ListParserTestType {
    var filename: HTMLFilename {
        switch self {
        case .frontpage:
            return .frontpage
        case .watched:
            return .watched
        case .popular:
            return .popular
        case .favorites:
            return .favorites
        case .toplists:
            return .toplists
        }
    }
    var assertCount: Int {
        switch self {
        case .frontpage:
            return 200
        case .watched:
            return 200
        case .popular:
            return 50
        case .favorites:
            return 92
        case .toplists:
            return 50
        }
    }
}
