//
//  DownloadClient+Networking.swift
//  EhPanda
//

import Foundation

// MARK: - Network
extension DownloadCoordinator {
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
            try? fileManager.operate {
                try $0.removeItem(at: response.0)
            }
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

    func pageDownloadResponse(
        url: URL,
        allowsCellular: Bool,
        context: DownloadPageTaskContext,
        retriesRequest: Bool = true
    ) async throws -> DownloadPageTransfer {
        var request = URLRequest(url: url)
        request.allowsCellularAccess = allowsCellular
        return try await pageDownloadResponse(
            for: request,
            context: context,
            retriesRequest: retriesRequest
        )
    }

    func pageDownloadResponse(
        for request: URLRequest,
        context: DownloadPageTaskContext,
        retriesRequest: Bool = true
    ) async throws -> DownloadPageTransfer {
        let performRequest = {
            try await self.rawPageDownloadResponse(
                for: request,
                context: context
            )
        }

        let transfer: DownloadPageTransfer
        if retriesRequest {
            transfer = try await withRetry(
                operation: "pageDownloadResponse",
                context: [
                    "url": request.url?.absoluteString ?? ""
                ]
            ) {
                try await performRequest()
            }
        } else {
            transfer = try await performRequest()
        }

        if let error = detectResponseError(
            fileURL: transfer.fileURL,
            response: transfer.response,
            requestURL: request.url
        ) {
            try? fileManager.operate {
                try $0.removeItem(at: transfer.fileURL)
            }
            if let taskIdentifier = transfer.taskIdentifier {
                await backgroundTaskStore.remove(taskIdentifier: taskIdentifier)
            }
            throw error
        }

        return transfer
    }

    func rawPageDownloadResponse(
        for request: URLRequest,
        context: DownloadPageTaskContext
    ) async throws -> DownloadPageTransfer {
        do {
            return try await pageDownloader.download(request, context)
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
}

// MARK: - File Operations
extension DownloadCoordinator {
    func fileExtension(
        for url: URL,
        response: URLResponse?,
        prefixData: Data
    ) -> String {
        if !url.pathExtension.isEmpty {
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
        try fileManager.operate {
            try $0.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
        }
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
        if fileManager.operate({ $0.fileExists(atPath: destinationURL.path) }) {
            try fileManager.operate {
                try $0.removeItem(at: destinationURL)
            }
        }
        try fileManager.operate {
            try $0.moveItem(at: sourceURL, to: destinationURL)
        }
    }

    func readResponsePrefixData(at fileURL: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        return try handle.read(
            upToCount: Self.responseInspectionPrefixLength
        ) ?? Data()
    }
}
