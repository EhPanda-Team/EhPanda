//
//  DownloadClient+ResponseValidation.swift
//  EhPanda
//

import Kanna
import Foundation
import ImageIO

// MARK: - Response Error Detection
extension DownloadCoordinator {
    func detectResponseError(
        data: Data,
        response: URLResponse,
        requestURL: URL?,
        expectsHTML: Bool = false
    ) -> AppError? {
        detectResponseError(
            prefixData: Data(
                data.prefix(Self.responseInspectionPrefixLength)
            ),
            fullData: data,
            response: response,
            requestURL: requestURL,
            expectsHTML: expectsHTML
        )
    }

    func detectResponseError(
        fileURL: URL,
        response: URLResponse,
        requestURL: URL?
    ) -> AppError? {
        let prefixData = (try? readResponsePrefixData(
            at: fileURL
        )) ?? Data()
        if let error = detectPlaceholderFileErrors(
            response: response,
            fileURL: fileURL,
            requestURL: requestURL
        ) {
            return error
        }
        let mimeType = normalizedMimeType(response)
        let shouldInspect = shouldInspectTextResponse(
            mimeType: mimeType,
            prefixData: prefixData
        )
        guard shouldInspect else {
            if statusCode(for: response) == 404 {
                return .notFound
            }
            return nil
        }
        return detectResponseError(
            prefixData: prefixData,
            fullData: resolveFileData(
                fileURL: fileURL,
                mimeType: mimeType,
                prefixData: prefixData,
                response: response
            ),
            response: response,
            requestURL: requestURL,
            expectsHTML: false
        )
    }

    private func detectPlaceholderFileErrors(
        response: URLResponse,
        fileURL: URL,
        requestURL: URL?
    ) -> AppError? {
        let placeholderData = loadPlaceholderDataIfNeeded(
            response: response,
            fileURL: fileURL
        )
        if let placeholderData {
            if isAuthenticationRequiredPlaceholderImageData(
                placeholderData
            ) {
                return .authenticationRequired
            }
            if isQuotaExceededAssetData(placeholderData) {
                return .quotaExceeded
            }
        }
        if isAuthenticationRequiredPlaceholderResponse(
            response: response,
            requestURL: requestURL
        ) {
            return .authenticationRequired
        }
        if isQuotaExceededResponse(
            fullData: nil,
            fileURL: fileURL,
            response: response,
            requestURL: requestURL
        ) {
            return .quotaExceeded
        }
        return nil
    }

    private func resolveFileData(
        fileURL: URL,
        mimeType: String?,
        prefixData: Data,
        response: URLResponse
    ) -> Data? {
        let looksLikeHTML = responseLooksLikeHTML(
            mimeType: mimeType,
            prefixData: prefixData,
            expectsHTML: false
        )
        let placeholderData = loadPlaceholderDataIfNeeded(
            response: response,
            fileURL: fileURL
        )
        if looksLikeHTML {
            return placeholderData ?? (try? Data(
                contentsOf: fileURL,
                options: .mappedIfSafe
            ))
        }
        return placeholderData
    }

    func detectResponseError(
        prefixData: Data,
        fullData: Data?,
        response: URLResponse,
        requestURL: URL?,
        expectsHTML: Bool
    ) -> AppError? {
        if let error = detectDataErrors(
            fullData: fullData,
            response: response,
            requestURL: requestURL
        ) {
            return error
        }

        let mimeType = normalizedMimeType(response)
        let shouldInspect = expectsHTML
            || shouldInspectTextResponse(
                mimeType: mimeType,
                prefixData: prefixData
            )
        if shouldInspect {
            let inspectedData = fullData ?? prefixData
            if let error = detectTextualDownloadError(
                data: inspectedData,
                looksLikeHTML: responseLooksLikeHTML(
                    mimeType: mimeType,
                    prefixData: prefixData,
                    expectsHTML: expectsHTML
                )
            ) {
                return error
            }
        }
        if isAuthenticationRequiredResponse(
            prefixData: prefixData,
            fullData: fullData,
            response: response,
            requestURL: requestURL
        ) {
            return .authenticationRequired
        }
        guard shouldInspect else { return nil }

        let htmlContext = HTMLResponseContext(
            prefixData: prefixData, fullData: fullData,
            response: response, requestURL: requestURL,
            mimeType: mimeType
        )
        return detectHTMLResponseError(
            context: htmlContext, expectsHTML: expectsHTML
        )
    }

    private func detectDataErrors(
        fullData: Data?,
        response: URLResponse,
        requestURL: URL?
    ) -> AppError? {
        if let fullData {
            if isAuthenticationRequiredPlaceholderImageData(
                fullData
            ) {
                return .authenticationRequired
            }
            if isQuotaExceededAssetData(fullData) {
                return .quotaExceeded
            }
        }
        if isAuthenticationRequiredPlaceholderResponse(
            response: response,
            requestURL: requestURL
        ) {
            return .authenticationRequired
        }
        if isQuotaExceededResponse(
            fullData: fullData,
            fileURL: nil,
            response: response,
            requestURL: requestURL
        ) {
            return .quotaExceeded
        }
        return nil
    }

    private func detectHTMLResponseError(
        context: HTMLResponseContext,
        expectsHTML: Bool
    ) -> AppError? {
        let prefixData = context.prefixData
        let fullData = context.fullData
        let response = context.response
        let requestURL = context.requestURL
        let mimeType = context.mimeType
        let textPrefix = String(
            bytes: prefixData,
            encoding: .utf8
        ) ?? ""

        guard !prefixLooksLikeJSON(prefixData) else {
            return nil
        }

        let looksLikeHTML = responseLooksLikeHTML(
            mimeType: mimeType,
            prefixData: prefixData,
            expectsHTML: expectsHTML
        )
        guard looksLikeHTML else {
            if statusCode(for: response) == 404 {
                return .notFound
            }
            return nil
        }

        if let fullData,
           let document = try? Kanna.HTML(
            html: fullData.utf8InvalidCharactersRipped,
            encoding: .utf8
           ),
           let error = Parser.parseResponseError(
            doc: document
           ) {
            return error
        }
        if expectsHTML {
            if statusCode(for: response) == 404 {
                return .notFound
            }
            return nil
        }
        Logger.error(
            "Download received unexpected HTML response.",
            context: [
                "url": requestURL?.absoluteString ?? "",
                "snippet": String(textPrefix.prefix(240))
            ]
        )
        if statusCode(for: response) == 404 {
            return .notFound
        }
        return .parseFailed
    }

    private func loadPlaceholderDataIfNeeded(
        response: URLResponse,
        fileURL: URL
    ) -> Data? {
        let byteCount = responseContentLength(response)
            ?? fileSize(at: fileURL)
        guard let byteCount,
              byteCount == ImagePlaceholderFingerprint.authenticationRequiredByteCount
                || byteCount == ImagePlaceholderFingerprint.quotaExceededByteCount
        else {
            return nil
        }
        return try? Data(
            contentsOf: fileURL,
            options: .mappedIfSafe
        )
    }
}
