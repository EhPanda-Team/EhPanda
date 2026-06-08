//
//  DownloadIpBanTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadIpBanTests: DownloadFeatureTestCase {
    @Test
    func testIpBannedDoesNotRetryImmediately() async throws {
        let sessionID = UUID().uuidString
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        configuration.httpAdditionalHeaders = [SharedSessionStubURLProtocol.headerKey: sessionID]
        let manager = DownloadManager(
            storage: DownloadFileStorage(
                rootURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString, isDirectory: true),
                fileManager: .default
            ),
            urlSession: URLSession(configuration: configuration)
        )
        let recorder = RequestRecorder()
        let ipBannedHTML = try fixtureData(resource: HTMLFilename.ipBanned.rawValue, pathExtension: "html")
        let fallbackBannedURL = try #require(URL(string: "https://example.com/banned"))
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { request in
            recorder.recordDetail()
            return (
                try #require(HTTPURLResponse(
                    url: request.url ?? fallbackBannedURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "text/html; charset=utf-8"]
                )),
                ipBannedHTML
            )
        }
        defer {
            SharedSessionStubURLProtocol.removeHandler(for: sessionID)
        }

        let download = sampleDownload(
            gid: "123456",
            title: "Banned Gallery",
            status: .partial
        )

        do {
            _ = try await manager.testingFetchLatestPayload(
                for: download,
                mode: .redownload
            )
            Issue.record("Expected ipBanned error")
        } catch let error as AppError {
            guard case .ipBanned = error else {
                Issue.record("Expected ipBanned, got \(error)")
                return
            }
        }

        #expect(recorder.snapshot().detailRequests == 1)
    }

}
