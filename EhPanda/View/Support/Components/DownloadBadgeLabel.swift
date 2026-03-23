//
//  DownloadBadgeLabel.swift
//  EhPanda
//

import SwiftUI

struct DownloadBadgeLabel: View {
    private let badge: DownloadBadge
    private let compact: Bool

    init(badge: DownloadBadge, compact: Bool = false) {
        self.badge = badge
        self.compact = compact
    }

    var body: some View {
        if badge != .none {
            Text(compact ? compactText : badge.text)
                .font(compact ? .caption2.bold() : .caption.bold())
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, compact ? 6 : 8)
                .padding(.vertical, compact ? 3 : 4)
                .background(backgroundColor)
                .clipShape(Capsule())
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
