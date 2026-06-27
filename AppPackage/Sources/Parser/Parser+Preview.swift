import Kanna
import AppModels
import Foundation
import Utilities

extension Parser {
    public static func parsePreviewURLs(doc: HTMLDocument) throws -> [Int: URL] {
        guard let gdtNode = doc.at_xpath("//div [@id='gdt']")
        else { throw AppError.parseFailed }

        let combinedURLs = parseCombinedPreviewURLs(node: gdtNode)
        return combinedURLs.isEmpty ? parseStandalonePreviewURLs(node: gdtNode) : combinedURLs
    }

    public static func parsePreviewConfigs(url: URL) -> PreviewConfigInfo? {
        guard var components = URLComponents(
                url: url, resolvingAgainstBaseURL: false
              ),
              let queryItems = components.queryItems
        else { return nil }

        let keys = [
            Defaults.URL.Component.Key.ehpandaWidth,
            Defaults.URL.Component.Key.ehpandaHeight,
            Defaults.URL.Component.Key.ehpandaOffset
        ]
        let configs = keys.map(\.rawValue).compactMap { key in
            queryItems.filter({ $0.name == key }).first?.value
        }
        .compactMap(Int.init)

        components.queryItems = nil
        guard configs.count == keys.count,
              let plainURL = components.url
        else { return nil }

        let size = CGSize(width: configs[0], height: configs[1])
        return PreviewConfigInfo(
            plainURL: plainURL,
            size: size,
            offset: CGSize(width: configs[2], height: 0)
        )
    }
}

private extension Parser {
    static func parseCombinedPreviewURLs(node: XMLElement) -> [Int: URL] {
        var previewURLs = [Int: URL]()

        for link in node.xpath("//a") {
            if let divNode = link.at_xpath(".//div[@title and @style]"),
               let style = divNode["style"],
               let rangeA = style.range(of: "width:"),
               let rangeB = style.range(of: "px;height:"),
               let rangeC = style.range(of: "px;background"),
               let rangeD = style.range(of: "url("),
               let rangeE = style.range(of: ") -"),
               let rangeF = style[rangeE.upperBound...].range(of: "px "),
               let urlString = style[rangeD.upperBound..<rangeE.lowerBound]
                .replacingOccurrences(of: "'", with: "")
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: urlString),
               let title = divNode["title"],
               let index = parseGTX00IndexFromTitle(from: title) {
                let width = String(style[rangeA.upperBound..<rangeB.lowerBound])
                let height = String(style[rangeB.upperBound..<rangeC.lowerBound])
                let offset = String(style[rangeE.upperBound..<rangeF.lowerBound])

                previewURLs[index] = URLUtil.combinedPreviewURL(
                    plainURL: url,
                    width: width,
                    height: height,
                    offset: offset
                )
            }
        }
        return previewURLs
    }

    static func parseStandalonePreviewURLs(node: XMLElement) -> [Int: URL] {
        var previewURLs = [Int: URL]()

        for link in node.xpath("//a") {
            if let divNode = link.at_xpath(".//div[@title and @style]"),
               let style = divNode["style"],
               let rangeA = style.range(of: "url("),
               let rangeB = style.range(of: ")"),
               let urlString = style[rangeA.upperBound..<rangeB.lowerBound]
                .replacingOccurrences(of: "'", with: "")
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: urlString),
               let title = divNode["title"],
               let index = parseGTX00IndexFromTitle(from: title) {
                previewURLs[index] = url
            }
        }
        return previewURLs
    }
}
