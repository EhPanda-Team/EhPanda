@testable import DownloadsFeature
import Foundation
import Testing

/// B-4: the queue operations' labels read the owner's wording in every locale, each written natively for its
/// language rather than translated word for word.
struct DownloadQueueOperationCopyTests {
    struct Label: Sendable, CustomTestStringConvertible {
        let key: String
        let resource: LocalizedStringResource
        let values: [String: String]

        var testDescription: String { key }
    }

    @Test(arguments: [
        Label(
            key: "download_next",
            resource: .downloadNext,
            values: [
                "en": "Download Next", "de": "Als Nächstes laden", "ja": "次にダウンロード", "ko": "다음에 다운로드",
                "zh-Hans": "接着下载", "zh-Hant": "接著下載"
            ]
        ),
        Label(
            key: "move_up",
            resource: .moveUp,
            values: [
                "en": "Move Up", "de": "Nach oben", "ja": "上へ移動", "ko": "위로 이동",
                "zh-Hans": "往前移", "zh-Hant": "往前移"
            ]
        ),
        Label(
            key: "move_down",
            resource: .moveDown,
            values: [
                "en": "Move Down", "de": "Nach unten", "ja": "下へ移動", "ko": "아래로 이동",
                "zh-Hans": "往后移", "zh-Hant": "往後移"
            ]
        ),
        Label(
            key: "download_last",
            resource: .downloadLast,
            values: [
                "en": "Download Last", "de": "Als Letztes laden", "ja": "最後にダウンロード", "ko": "마지막에 다운로드",
                "zh-Hans": "最后下载", "zh-Hant": "最後下載"
            ]
        ),
        Label(
            key: "reorder",
            resource: .reorder,
            values: [
                "en": "Reorder", "de": "Reihenfolge ändern", "ja": "順番を変更", "ko": "순서 변경",
                "zh-Hans": "调整顺序", "zh-Hant": "調整順序"
            ]
        )
    ])
    func eachLocaleReadsItsOwnWording(_ label: Label) {
        for (locale, expected) in label.values {
            var resource = label.resource
            resource.locale = Locale(identifier: locale)
            #expect(String(localized: resource) == expected, "\(label.key) in \(locale)")
        }
    }
}
