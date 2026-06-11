//
//  DownloadBadgeLabel.swift
//  EhPanda
//

import SwiftUI

struct DownloadBadgeLabel: View {
    private let badge: DownloadBadge
    private let isCompactStyle: Bool

    init?(badge: DownloadBadge?, compact: Bool = false) {
        guard let badge else { return nil }

        self.badge = badge
        self.isCompactStyle = compact
    }

    var body: some View {
        labelText
            .lineLimit(1)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, isCompactStyle ? 6 : 8)
            .padding(.vertical, isCompactStyle ? 3 : 4)
            .background(backgroundColor)
            .clipShape(.capsule)
    }

    private var labelText: Text {
        if isCompactStyle {
            Text(badge.statusText)
                .font(.caption2.bold())
        } else {
            Text(badge.text)
                .font(.caption.bold().monospacedDigit())
        }
    }

    private var backgroundColor: Color {
        badge.color.opacity(0.15)
    }

    private var foregroundColor: Color {
        badge.status == .updateAvailable ? .orange : badge.color
    }
}
