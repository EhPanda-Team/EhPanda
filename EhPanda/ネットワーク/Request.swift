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

struct SearchItemsRequest {
    let keyword: String
    let parser = Parser()
    
    var publisher: AnyPublisher<[Manga], AppError> {
        let word = keyword.replacingOccurrences(of: " ", with: "+")
        return URLSession.shared
            .dataTaskPublisher(
                for: URL(string: Defaults.URL.host
                            + Defaults.URL.search
                            + word)!
            )
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map { parser.parsePopularListItems($0) }
            .mapError { _ in AppError.networkingFailed }
            .eraseToAnyPublisher()
    }
}

struct MangaDetailRequest {
    let detailURL: String
    let parser = Parser()
    
    var publisher: AnyPublisher<MangaDetail?, AppError> {
        URLSession.shared
            .dataTaskPublisher(for: URL(string: detailURL)!)
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .map { parser.parseMangaDetail($0) }
            .mapError { _ in AppError.networkingFailed }
            .eraseToAnyPublisher()
    }
}
