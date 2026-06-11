//
//  DownloadBadgeLabel.swift
//  EhPanda
//

import SwiftUI

struct DownloadBadgeLabel: View {
    private static let ringDiameter: CGFloat = 26
    private static let ringLineWidth: CGFloat = 2.5

    private let badge: DownloadBadge
    private let isCompactStyle: Bool

    init(badge: DownloadBadge, isCompactStyle: Bool = false) {
        self.badge = badge
        self.isCompactStyle = isCompactStyle
    }

    var body: some View {
        Group {
            if isCompactStyle {
                ringSymbol
            } else {
                textLabel
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var ringSymbol: some View {
        ZStack {
            Circle()
                .stroke(badge.color.opacity(0.18), lineWidth: Self.ringLineWidth)
            Circle()
                .trim(from: 0, to: badge.progress.fraction)
                .stroke(badge.color, style: .init(lineWidth: Self.ringLineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemSymbol: badge.ringSymbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(badge.color)
        }
        .padding(Self.ringLineWidth / 2)
        .frame(width: Self.ringDiameter, height: Self.ringDiameter)
    }

    private var textLabel: some View {
        HStack(spacing: 4) {
            Image(systemSymbol: badge.symbol)
                .font(.caption.bold())
            Text(progressText)
                .font(.caption.bold().monospacedDigit())
                .lineLimit(1)
        }
        .foregroundStyle(badge.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badge.color.opacity(0.15))
        .clipShape(.capsule)
    }

    private var progressText: String {
        L10n.Localizable.Struct.DownloadBadge.progress(
            badge.progress.displayCompletedPageCount,
            badge.progress.displayPageCount
        )
    }

    private var statusText: String {
        typealias BadgeText = L10n.Localizable.Struct.DownloadBadge.Text
        switch badge.status {
        case .queued:
            return BadgeText.queued
        case .active:
            return BadgeText.downloading
        case .inactive:
            return BadgeText.paused
        case .completed:
            return BadgeText.downloaded
        case .updateAvailable:
            return BadgeText.updateAvailable
        case .error:
            return BadgeText.needsAttention
        }
    }

    private var accessibilityText: String {
        [statusText, progressText].joined(separator: " ")
    }
}
