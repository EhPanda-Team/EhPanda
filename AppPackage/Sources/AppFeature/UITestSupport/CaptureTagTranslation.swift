#if DEBUG
import AppModels
import FileClient
import Foundation

/// Hash-pinned release files used only by an isolated capture launch.
struct CaptureTagTranslation: Equatable, Sendable {
    let path: String
    let sha256: String
    let languageCode: String
    let releasePath: String
    let releaseSHA256: String

    struct Prepared {
        let translator: TagTranslator
        let replay: [String: CaptureReplay.Response]
    }

    func prepare(in directory: URL) throws(CaptureFailure) -> Prepared {
        guard let language = TranslatableLanguage.allCases.first(where: { $0.languageCode == languageCode })
        else { throw .malformedConfiguration("Invalid tag translation language") }
        let data = try verifiedData(path: path, digest: sha256)
        let metadata = try verifiedData(path: releasePath, digest: releaseSHA256)
        let release: CaptureTranslationRelease
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            release = try decoder.decode(CaptureTranslationRelease.self, from: metadata)
        } catch {
            throw .malformedScene("Cannot decode tag translation release metadata")
        }
        let translator: TagTranslator
        do {
            let client = FileClient.live(applicationSupportURL: directory, cachesURL: directory)
            translator = try client.cacheAndBuildRemoteTagTranslator(data, language, release.publicationDate)
        } catch {
            throw .malformedScene("Cannot decode tag translation source")
        }
        return Prepared(translator: translator, replay: [
            URLUtil.githubAPI(repoName: language.repoName).absoluteString:
                .init(data: metadata, mimeType: "application/json"),
            URLUtil.githubDownload(repoName: language.repoName, fileName: language.remoteFilename).absoluteString:
                .init(data: data, mimeType: "application/json")
        ])
    }

    private func verifiedData(path: String, digest: String) throws(CaptureFailure) -> Data {
        guard path.hasPrefix("/") else { throw .malformedConfiguration("Invalid tag translation source path") }
        let data: Data
        do {
            data = try Data(contentsOf: URL(filePath: path))
        } catch {
            throw .unreadableFile("tag translation source")
        }
        guard CaptureFixture.sha256(data) == digest else { throw .checksumMismatch("tag translation source") }
        return data
    }

}

private struct CaptureTranslationRelease: Decodable {
    let publicationDate: Date
    private enum CodingKeys: String, CodingKey {
        case publicationDate = "published_at"
    }
}

extension CaptureTagTranslation: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case path, sha256, languageCode, releasePath, releaseSHA256
    }

    init(from decoder: any Decoder) throws {
        try decoder.requireExactKeys(CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decode(String.self, forKey: .path)
        sha256 = try container.decode(String.self, forKey: .sha256)
        languageCode = try container.decode(String.self, forKey: .languageCode)
        releasePath = try container.decode(String.self, forKey: .releasePath)
        releaseSHA256 = try container.decode(String.self, forKey: .releaseSHA256)
    }
}
#endif
