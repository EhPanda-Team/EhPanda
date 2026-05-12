//
//  Request.swift
//  EhPanda

import Kanna
import Combine
import Foundation
import ComposableArchitecture

protocol Request {
    associatedtype Response: Sendable

    var publisher: AnyPublisher<Response, AppError> { get }
}
extension Request {
    func response() async -> Result<Response, AppError> {
        await publisher.receive(on: DispatchQueue.main).async()
    }

    func mapAppError(error: Error) -> AppError {
        switch error {
        case is ParseError:
            return .parseFailed

        case is URLError:
            return .networkingFailed

        case is DecodingError:
            return .parseFailed

        default:
            return error as? AppError ?? .unknown
        }
    }
}

extension Publisher {
    func genericRetry() -> Publishers.Retry<Self> {
        retry(3)
    }

    func async() async -> Result<Output, AppError> where Output: Sendable, Failure == AppError {
        do {
            let output = try await asyncOutput()
            return .success(output)
        } catch {
            return .failure(error as? AppError ?? .unknown)
        }
    }

    private func asyncOutput() async throws -> Output where Output: Sendable, Failure == AppError {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var finishedWithoutValue = true
            cancellable = first()
                .sink { result in
                    switch result {
                    case .finished:
                        if finishedWithoutValue {
                            continuation.resume(throwing: AppError.unknown)
                        }
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                } receiveValue: { value in
                    finishedWithoutValue = false
                    continuation.resume(returning: value)
                }
        }
    }
}
extension URLRequest {
    mutating func setURLEncodedContentType() {
        setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    }
}
extension Dictionary where Key == String, Value == String {
    func dictString() -> String {
        var array = [String]()
        keys.forEach { key in
            array.append(key + "=" + self[key].forceUnwrapped)
        }
        return array.joined(separator: "&")
    }
}

private extension URL {
    var galleryToken: String? {
        let filteredComponents = pathComponents.filter { $0 != "/" && $0.notEmpty }
        guard filteredComponents.count >= 3 else { return nil }
        return filteredComponents[2]
    }
}

// MARK: - Response Types

struct FavoritesGalleriesResult {
    let pageNumber: PageNumber
    let sortOrder: FavoritesSortOrder?
    let galleries: [Gallery]
}

struct GalleryArchiveResponse {
    let archive: GalleryArchive
    let galleryPoints: String?
    let credits: String?
}

// MARK: Routine
struct GreetingRequest: Request {
    var publisher: AnyPublisher<Greeting, AppError> {
        URLSession.shared.dataTaskPublisher(for: Defaults.URL.news)
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseGreeting)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct UserInfoRequest: Request {
    let uid: String

    var publisher: AnyPublisher<User, AppError> {
        URLSession.shared.dataTaskPublisher(for: URLUtil.userInfo(uid: uid))
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseUserInfo)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct FavoriteCategoriesRequest: Request {
    var publisher: AnyPublisher<[Int: String], AppError> {
        URLSession.shared.dataTaskPublisher(for: Defaults.URL.uConfig)
            .genericRetry()
            .tryMap { try Kanna.HTML(html: $0.data, encoding: .utf8) }
            .tryMap(Parser.parseFavoriteCategories)
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}

struct TagTranslatorRequest: Request {
    let language: TranslatableLanguage
    let updatedDate: Date

    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = Defaults.DateFormat.github
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    var publisher: AnyPublisher<TagTranslator, AppError> {
        URLSession.shared.dataTaskPublisher(for: language.checkUpdateURL)
            .genericRetry().tryMap { data, _ -> Date in
                guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let postedDateString = dict["published_at"] as? String,
                      let postedDate = dateFormatter.date(from: postedDateString)
                else { throw AppError.parseFailed }

                guard postedDate > updatedDate
                else { throw AppError.noUpdates }
                return postedDate
            }
            .flatMap { date in
                URLSession.shared.dataTaskPublisher(for: language.downloadURL)
                    .tryMap { data, _ in
                        let response = try JSONDecoder().decode(
                            EhTagTranslationDatabaseResponse.self, from: data
                        )
                        var translations = response.tagTranslations
                        guard !translations.isEmpty else { throw AppError.parseFailed }
                        if language == .traditionalChinese {
                            translations = translations.chtConverted
                        }
                        return TagTranslator(
                            language: language, updatedDate: date, translations: translations
                        )
                    }
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }
}
