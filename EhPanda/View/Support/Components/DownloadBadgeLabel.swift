//
//  DownloadBadgeLabel.swift
//  EhPanda
//

import SwiftUI

struct DownloadBadgeLabel: View {
    private let badge: DownloadBadge
    private let isCompactStyle: Bool

    init?(badge: DownloadBadge, compact: Bool = false) {
        guard badge != .none else { return nil }

        self.badge = badge
        self.isCompactStyle = compact
    }

    var body: some View {
        labelText
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, isCompactStyle ? 6 : 8)
            .padding(.vertical, isCompactStyle ? 3 : 4)
            .background(backgroundColor)
            .clipShape(.capsule)
    }

    private var labelText: Text {
        if isCompactStyle {
            Text(compactText)
                .font(.caption2.bold())
        } else {
            Text(badge.text)
                .font(.caption.bold().monospacedDigit())
        }
    }

    private var compactText: String {
        switch badge {
        case .downloading:
            return L10n.Localizable.Struct.DownloadBadge.Compact.downloading
        case .paused:
            return L10n.Localizable.Struct.DownloadBadge.Compact.paused
        case .partial:
            return L10n.Localizable.Struct.DownloadBadge.Compact.needsAttention
        case .downloaded:
            return L10n.Localizable.Struct.DownloadBadge.Compact.done
        case .failed:
            return L10n.Localizable.Struct.DownloadBadge.Compact.needsAttention
        default:
            return badge.text
        }
    }

    private var backgroundColor: Color {
        badge.color.opacity(0.15)
    }

    private var foregroundColor: Color {
        switch badge {
        case .updateAvailable:
            return .orange
        default:
            return badge.color
        }
    }
}
