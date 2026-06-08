//
//  DownloadedGallery+SignatureBuilder.swift
//  EhPanda
//

import Foundation
import CryptoKit

enum DownloadSignatureBuilder {
    enum SignatureKind: Equatable {
        case chain(gid: String, token: String)
        case hash(String)
    }

    enum Comparison: Equatable {
        case same
        case different
        case incomparable
    }

    static func make(
        gallery: Gallery,
        detail: GalleryDetail,
        host _: GalleryHost,
        previewURLs: [Int: URL],
        versionMetadata: DownloadVersionMetadata? = nil
    ) -> String {
        if let versionMetadata,
           let chainSignature = chainVersionIdentifier(
               gid: versionMetadata.resolvedCurrentGID,
               token: versionMetadata.resolvedCurrentKey
           ) {
            return chainSignature
        }

        let previewHash = SHA256.hash(
            data: previewURLs
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\(normalizedPreviewSignatureValue(url: $0.value))" }
                .joined(separator: "|")
                .data(using: .utf8) ?? Data()
        )

        let payload = [
            gallery.gid,
            gallery.token,
            gallery.title,
            detail.jpnTitle ?? "",
            String(detail.pageCount),
            normalizedCoverSignatureValue(url: detail.coverURL ?? gallery.coverURL),
            detail.formattedDateString,
            previewHash.compactMap { String(format: "%02x", $0) }.joined()
        ]
        .joined(separator: "::")

        let digest = SHA256.hash(
            data: payload.data(using: String.Encoding.utf8) ?? Data()
        )
        let hash = digest.compactMap { String(format: "%02x", $0) }.joined()
        return "hash:\(hash)"
    }

    static func chainVersionIdentifier(gid: String, token: String) -> String? {
        guard !gid.isEmpty, !token.isEmpty else { return nil }
        return "chain:\(gid):\(token)"
    }

    static func parse(_ value: String?) -> SignatureKind? {
        guard let value, !value.isEmpty else { return nil }

        if value.hasPrefix("chain:") {
            let components = value.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
            guard components.count == 3,
                  !components[1].isEmpty,
                  !components[2].isEmpty
            else {
                return nil
            }
            return .chain(gid: String(components[1]), token: String(components[2]))
        }

        if value.hasPrefix("hash:") {
            let hash = String(value.dropFirst("hash:".count))
            guard !hash.isEmpty else { return nil }
            return .hash(hash)
        }

        return nil
    }

    static func compare(
        remoteVersionSignature: String,
        latestRemoteVersionSignature: String?,
        gid: String,
        token: String
    ) -> Comparison {
        guard let storedSignature = parse(remoteVersionSignature),
              let latestSignature = parse(latestRemoteVersionSignature)
        else {
            return .incomparable
        }

        switch (storedSignature, latestSignature) {
        case let (.chain(storedGID, storedToken), .chain(latestGID, latestToken)):
            return storedGID == latestGID && storedToken == latestToken ? .same : .different

        case let (.hash(storedHash), .hash(latestHash)):
            return storedHash == latestHash ? .same : .different

        case (.hash, .chain):
            return latestRemoteVersionSignature == chainVersionIdentifier(gid: gid, token: token)
                ? .same
                : .incomparable

        case (.chain, .hash):
            return .incomparable
        }
    }

    static func canonicalizeStoredSignatureIfSafe(
        remoteVersionSignature: String,
        latestRemoteVersionSignature: String?,
        gid: String,
        token: String
    ) -> String? {
        guard case .hash = parse(remoteVersionSignature),
              case .chain = parse(latestRemoteVersionSignature),
              latestRemoteVersionSignature == chainVersionIdentifier(gid: gid, token: token)
        else {
            return nil
        }
        return latestRemoteVersionSignature
    }

    static func hasUpdateComparison(
        remoteVersionSignature: String,
        latestRemoteVersionSignature: String?,
        gid: String,
        token: String
    ) -> Comparison {
        compare(
            remoteVersionSignature: remoteVersionSignature,
            latestRemoteVersionSignature: latestRemoteVersionSignature,
            gid: gid,
            token: token
        )
    }

    private static func normalizedPreviewSignatureValue(url: URL) -> String {
        let lastPathComponent = url.lastPathComponent
        guard !lastPathComponent.isEmpty else {
            return normalizedCoverSignatureValue(url: url)
        }
        return lastPathComponent
    }

    private static func normalizedCoverSignatureValue(url: URL?) -> String {
        guard let url else { return "" }
        let stablePathComponents = url.pathComponents
            .filter { $0 != "/" && !$0.isEmpty }
        return stablePathComponents.joined(separator: "/")
    }
}
