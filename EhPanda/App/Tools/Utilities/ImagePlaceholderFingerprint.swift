//
//  ImagePlaceholderFingerprint.swift
//  EhPanda
//

import CryptoKit
import Foundation

/// A known E-H asset placeholder that decodes as a valid image but is *not* page
/// content: the ExHentai "kokomade" login wall and the H@H `509` bandwidth notice.
///
/// Both the download pipeline and the reader's owned fetch must reject these
/// identically — a placeholder that slips through poisons the shared image cache
/// for its full expiry window and can be displayed or exported as if it were the
/// real page. Centralising the fingerprints keeps the two paths in lockstep.
enum ImagePlaceholderFingerprint: Sendable {
    case authenticationRequired
    case quotaExceeded

    var error: AppError {
        switch self {
        case .authenticationRequired: .authenticationRequired
        case .quotaExceeded: .quotaExceeded
        }
    }

    static let authenticationRequiredByteCount = 144_844
    static let authenticationRequiredSHA1 = "e48ed350e902a51581246d2a764fa7827e8e6988"
    static let quotaExceededByteCount = 28_658
    static let quotaExceededSHA1 = "f54b887b017694dc25eb1a1404f71981885f8ed9"

    /// Returns the matching placeholder when `data` is byte-for-byte one of the
    /// known fixtures (exact length plus SHA-1), otherwise `nil`. The length gate
    /// makes the common, non-placeholder case cost one comparison.
    static func match(_ data: Data) -> Self? {
        if matches(data, byteCount: authenticationRequiredByteCount, sha1: authenticationRequiredSHA1) {
            return .authenticationRequired
        }
        if matches(data, byteCount: quotaExceededByteCount, sha1: quotaExceededSHA1) {
            return .quotaExceeded
        }
        return nil
    }

    private static func matches(_ data: Data, byteCount: Int, sha1: String) -> Bool {
        guard data.count == byteCount else { return false }
        return sha1Hex(for: data) == sha1
    }

    static func sha1Hex(for data: Data) -> String {
        Insecure.SHA1.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
