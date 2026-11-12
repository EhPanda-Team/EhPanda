@testable import AppFeature
import AppModels
import Dependencies
import Foundation
import LibraryClient
import Sharing
import Testing

struct CaptureTagTranslationTests {
    @Test(arguments: ["en", "ja", "ko", "zh-Hans", "zh-Hant"])
    func loadsVerifiedTableThroughProductionDecoder(languageCode: String) throws {
        let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: directory) } catch { Issue.record(error) }
        }
        let data = Data(#"{"data":[{"namespace":"other","data":{"artbook":{"name":"画集"}}}]}"#.utf8)
        let path = directory.appending(component: "table.json")
        try data.write(to: path)
        let metadata = Data(
            """
            {"assets":[{"name":"\(languageCode).json","digest":"sha256:table",
             "browser_download_url":"https://example.com/\(languageCode).json"}]}
            """.utf8
        )
        let releasePath = directory.appending(component: "release.json")
        try metadata.write(to: releasePath)
        let source = CaptureTagTranslation(
            path: path.path(), sha256: CaptureFixture.sha256(data), languageCode: languageCode,
            releasePath: releasePath.path(), releaseSHA256: CaptureFixture.sha256(metadata)
        )
        let prepared = try source.prepare(in: directory)
        let translator = prepared.translator
        #expect(prepared.replay.keys.contains("https://example.com/\(languageCode).json"))
        #expect(prepared.replay.count == 2)
        #expect(translator.language?.languageCode == languageCode)
        #expect(translator.digest == "sha256:table")
        #expect(translator.translations["otherartbook"]?.value == "画集")
    }

    @Test
    func rejectsReleaseWithoutTheLanguage() throws {
        let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: directory) } catch { Issue.record(error) }
        }
        let data = Data(#"{"data":[{"namespace":"other","data":{"artbook":{"name":"画集"}}}]}"#.utf8)
        let path = directory.appending(component: "table.json")
        try data.write(to: path)
        let metadata = Data(#"{"assets":[]}"#.utf8)
        let releasePath = directory.appending(component: "release.json")
        try metadata.write(to: releasePath)
        let source = CaptureTagTranslation(
            path: path.path(), sha256: CaptureFixture.sha256(data), languageCode: "ko",
            releasePath: releasePath.path(), releaseSHA256: CaptureFixture.sha256(metadata)
        )
        let failure = CaptureFailure.malformedScene("Tag translation release metadata has no asset for the language")
        #expect(throws: failure) {
            try source.prepare(in: directory)
        }
    }

    @Test
    func translatorAndSettingsSurviveDependencyInstallation() throws {
        let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
        let storage = try CaptureStorage.reset(at: directory.appending(component: "EhPandaCapture"))
        defer {
            do { try FileManager.default.removeItem(at: directory) } catch { Issue.record(error) }
        }
        let scene = try makeScene(try MarketingFixtureBuilder.standard())
        let translator = TagTranslator(language: .japanese, digest: "sha256:table", translations: [
            "otherartbook": .init(namespace: .other, key: "artbook", value: "画集")
        ])
        withDependencies {
            CaptureScenePreparation.isolate(
                &$0, scene: scene, storage: storage, libraryClient: .noop,
                downloads: .empty, tagTranslator: translator
            )
        } operation: {
            @SharedReader(.setting) var setting
            @SharedReader(.tagTranslator) var installed
            @SharedReader(.tagTranslatorInfo) var info
            #expect(setting.translateTags && setting.enableTagsExtension)
            #expect(installed == translator)
            #expect(info.language == .japanese)
            #expect(info.digest == "sha256:table")
        }
    }

    @Test
    func rejectsTamperedSource() throws {
        let directory = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: directory) } catch { Issue.record(error) }
        }
        let path = directory.appending(component: "table.json")
        try Data("changed".utf8).write(to: path)
        let source = CaptureTagTranslation(
            path: path.path(), sha256: String(repeating: "0", count: 64), languageCode: "en",
            releasePath: path.path(), releaseSHA256: "invalid"
        )
        #expect(throws: CaptureFailure.checksumMismatch("tag translation source")) {
            try source.prepare(in: directory)
        }
    }

    @Test
    func configurationAcceptsOnlyDeclaredSupplementalKeys() throws {
        let json = #"""
        {"purpose":"marketingReal","scenarioID":"home","fixtureID":"explicit",
         "tagTranslation":{"path":"/tmp/table.json","sha256":"abc","languageCode":"ja",
          "releasePath":"/tmp/release.json","releaseSHA256":"def"}}
        """#
        let configuration = try CaptureSceneConfiguration(json: Data(json.utf8))
        #expect(configuration.tagTranslation?.languageCode == "ja")
        let unknown = json.replacingOccurrences(of: "\"languageCode\"", with: "\"unexpected\"")
        #expect(throws: CaptureFailure.self) {
            try CaptureSceneConfiguration(json: Data(unknown.utf8))
        }
    }
}
