import Kanna
import SwiftUI
import AppModels
import Foundation
import AppTools
import Combine
import ParserFeature

public struct MyTagsRequest: Request {
    public init(
        tagSetNo: Int = 1,
        urlSession: URLSession = .shared,
        allowsCellular: Bool = true
    ) {
        self.tagSetNo = tagSetNo
        self.urlSession = urlSession
        self.allowsCellular = allowsCellular
    }
    public let tagSetNo: Int
    public let urlSession: URLSession
    public let allowsCellular: Bool

    public var publisher: AnyPublisher<MyTagsResponse, AppError> {
        guard var components = URLComponents(
            url: Defaults.URL.myTags, resolvingAgainstBaseURL: true
        ) else {
            return Fail(error: AppError.parseFailed).eraseToAnyPublisher()
        }
        components.queryItems = [URLQueryItem(name: "tagset", value: String(tagSetNo))]
        guard let url = components.url else {
            return Fail(error: AppError.parseFailed).eraseToAnyPublisher()
        }
        return urlSession.dataTaskPublisher(
            for: urlRequest(url: url, allowsCellular: allowsCellular)
        )
        .genericRetry()
        .tryMap { try htmlDocument(data: $0.data) }
        .tryMap { try parseResponse(doc: $0, Parser.parseMyTagsPage) }
        .mapError(mapAppError)
        .eraseToAnyPublisher()
    }
}
