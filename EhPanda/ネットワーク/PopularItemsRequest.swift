//
//  PopularItemsRequest.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Kanna
import Combine
import Foundation

struct PopularItemsRequest {
    let parser = Parser()
    
    var publisher: AnyPublisher<[Manga], AppError> {
        URLSession.shared
            .dataTaskPublisher(for: URL(string: Defaults.URL.host)!)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map { parser.parsePopularListItems($0) }
            .mapError { _ in AppError.networkingFailed }
            .eraseToAnyPublisher()
    }
}
