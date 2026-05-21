//
//  DownloadClient+Networking.swift
//  EhPanda
//

import Kanna
import Foundation

// MARK: - HTML & Network
extension DownloadManager {
    func htmlDocument(
        url: URL,
        allowsCellular: Bool,
        retriesRequest: Bool = true
    ) async throws -> HTMLDocument {
        var request = URLRequest(url: url)
        request.allowsCellularAccess = allowsCellular
        let (data, response) = try await dataResponse(
            for: request,
            retriesRequest: retriesRequest
        )
        if let error = detectResponseError(
            data: data,
            response: response,
            requestURL: request.url,
            expectsHTML: true
        ) {
            throw error
        }
        if let document = try? Kanna.HTML(
            html: data,
            encoding: .utf8
        ) {
            return document
        }
        if let document = try? Kanna.HTML(
            html: data.utf8InvalidCharactersRipped,
            encoding: .utf8
        ) {
            return document
        }
        throw AppError.parseFailed
    }

    func downloadResponse(
        url: URL,
        allowsCellular: Bool,
        retriesRequest: Bool = true
    ) async throws -> (URL, URLResponse) {
        var request = URLRequest(url: url)
        request.allowsCellularAccess = allowsCellular
        return try await downloadResponse(
            for: request,
            retriesRequest: retriesRequest
        )
    }

    func downloadResponse(
        for request: URLRequest,
        retriesRequest: Bool = true
    ) async throws -> (URL, URLResponse) {
        let performRequest = {
            try await self.rawDownloadResponse(for: request)
        }

        let response: (URL, URLResponse)
        if retriesRequest {
            response = try await withRetry(
                operation: "downloadResponse",
                context: [
                    "url": request.url?.absoluteString ?? ""
                ]
            ) {
                try await performRequest()
            }
        } else {
            response = try await performRequest()
        }

        if let error = detectResponseError(
            fileURL: response.0,
            response: response.1,
            requestURL: request.url
        ) {
            try? fileManager().removeItem(at: response.0)
            throw error
        }

        return response
    }

    func dataResponse(
        for request: URLRequest,
        retriesRequest: Bool = true
    ) async throws -> (Data, URLResponse) {
        if retriesRequest {
            return try await withRetry(
                operation: "dataResponse",
                context: [
                    "url": request.url?.absoluteString ?? ""
                ]
            ) {
                try await rawDataResponse(for: request)
            }
        }
        return try await rawDataResponse(for: request)
    }

    func rawDataResponse(
        for request: URLRequest
    ) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch let error as AppError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError
                    where error.code == .cancelled {
            throw CancellationError()
        } catch {
            if Self.isCancellationLikeError(error) {
                throw CancellationError()
            }
            if error is URLError {
                throw AppError.networkingFailed
            }
            throw AppError.unknown
        }
    }

    func rawDownloadResponse(
        for request: URLRequest
    ) async throws -> (URL, URLResponse) {
        do {
            return try await urlSession.download(for: request)
        } catch let error as AppError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError
                    where error.code == .cancelled {
            throw CancellationError()
        } catch {
            if Self.isCancellationLikeError(error) {
                throw CancellationError()
            }
            if error is URLError {
                throw AppError.networkingFailed
            }
            throw AppError.unknown
        }
    }

    func withRetry<T>(
        operation: String,
        context: [String: Any],
        maxAttempts: Int = retryLimit,
        body: () async throws -> T
    ) async throws -> T {
        var attempt = 1
        while true {
            do {
                return try await body()
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as AppError {
                guard error.isRetryable,
                      attempt < maxAttempts else {
                    throw error
                }
                Logger.error(
                    "Download operation will retry.",
                    context: context.merging([
                        "operation": operation,
                        "attempt": attempt,
                        "error": error.localizedDescription
                    ], uniquingKeysWith: { _, new in new })
                )
                attempt += 1
            } catch {
                guard attempt < maxAttempts else {
                    throw error
                }
                Logger.error(
                    "Download operation will retry"
                        + " after unexpected error.",
                    context: context.merging([
                        "operation": operation,
                        "attempt": attempt,
                        "error": error.localizedDescription
                    ], uniquingKeysWith: { _, new in new })
                )
                attempt += 1
            }
        }
    }

    func fetchThumbnailURLs(
        galleryURL: URL,
        pageNum: Int,
        allowsCellular: Bool
    ) async throws -> [Int: URL] {
        let detailPageURL = URLUtil.detailPage(
            url: galleryURL,
            pageNum: pageNum
        )
        let urls = try await withRetry(
            operation: "fetchThumbnailURLs",
            context: [
                "galleryURL": galleryURL.absoluteString,
                "detailPageURL": detailPageURL.absoluteString,
                "pageNum": pageNum
            ]
        ) {
            let doc = try await htmlDocument(
                url: detailPageURL,
                allowsCellular: allowsCellular,
                retriesRequest: false
            )
            return try Parser.parseThumbnailURLs(doc: doc)
        }
        guard !urls.isEmpty else { throw AppError.notFound }
        return urls
    }

    struct MPVKeysResult: Sendable {
        let mpvKey: String
        let imageKeys: [Int: String]
    }

    func fetchMPVKeys(
        mpvURL: URL,
        allowsCellular: Bool
    ) async throws -> MPVKeysResult {
        let (mpvKey, imageKeys) = try await withRetry(
            operation: "fetchMPVKeys",
            context: [
                "mpvURL": mpvURL.absoluteString
            ]
        ) {
            let doc = try await htmlDocument(
                url: mpvURL,
                allowsCellular: allowsCellular,
                retriesRequest: false
            )
            return try Parser.parseMPVKeys(doc: doc)
        }
        return MPVKeysResult(
            mpvKey: mpvKey,
            imageKeys: imageKeys
        )
    }

    func fetchMPVImageURL(
        payload: DownloadRequestPayload,
        index: Int,
        mpvKey: String,
        imageKey: String,
        retriesRequest: Bool = true
    ) async throws -> URL {
        guard let gidInteger = Int(payload.gallery.gid) else {
            throw AppError.notFound
        }
        let params: [String: Any] = [
            "method": "imagedispatch",
            "gid": gidInteger,
            "page": index,
            "imgkey": imageKey,
            "mpvkey": mpvKey
        ]

        var request = URLRequest(
            url: payload.host.url
                .appendingPathComponent("api.php")
        )
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization
            .data(withJSONObject: params)
        request.allowsCellularAccess =
            payload.options.allowCellular

        let (data, response) = try await dataResponse(
            for: request,
            retriesRequest: retriesRequest
        )
        if let error = detectResponseError(
            data: data,
            response: response,
            requestURL: request.url
        ) {
            throw error
        }
        guard let dictionary = try JSONSerialization
                .jsonObject(with: data) as? [String: Any],
              let imageURLString = dictionary["i"] as? String,
              let imageURL = URL(string: imageURLString)
        else {
            throw AppError.parseFailed
        }
        return imageURL
    }
}

// MARK: - File Operations
extension DownloadManager {
    func fileExtension(
        for url: URL,
        response: URLResponse?,
        prefixData: Data
    ) -> String {
        if url.pathExtension.notEmpty {
            return url.pathExtension.lowercased()
        }
        if let ext = extensionFromMimeType(response) {
            return ext
        }
        return prefixData.knownBinaryImageFileExtension ?? "jpg"
    }

    private func extensionFromMimeType(
        _ response: URLResponse?
    ) -> String? {
        guard let mimeType = response?.mimeType?.lowercased()
        else {
            return nil
        }
        switch mimeType {
        case "image/jpeg":
            return "jpg"
        case "image/png":
            return "png"
        case "image/gif":
            return "gif"
        case "image/webp":
            return "webp"
        default:
            return nil
        }
    }

    func createDirectory(at url: URL) throws {
        try fileManager().createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }

    func write(data: Data, to url: URL) throws {
        try createDirectory(at: url.deletingLastPathComponent())
        try data.write(to: url, options: .atomic)
    }

    func moveDownloadedFile(
        from sourceURL: URL,
        to destinationURL: URL
    ) throws {
        try createDirectory(
            at: destinationURL.deletingLastPathComponent()
        )
        if fileManager()
            .fileExists(atPath: destinationURL.path) {
            try fileManager().removeItem(at: destinationURL)
        }
        try fileManager()
            .moveItem(at: sourceURL, to: destinationURL)
    }

    func readResponsePrefixData(at fileURL: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        return try handle.read(
            upToCount: Self.responseInspectionPrefixLength
        ) ?? Data()
    }
}
