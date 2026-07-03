import SwiftUI
import SFSafeSymbols
import AppModels
import Resources

public struct DownloadBadgeLabel: View {
    private let badge: DownloadBadge

    public init(badge: DownloadBadge) {
        self.badge = badge
    }

    public var body: some View {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var progressText: String {
        L10n.Localizable.DownloadBadge.progress(
            badge.progress.displayCompletedPageCount,
            badge.progress.displayPageCount
        )
    }

    private var statusText: String {
        typealias BadgeText = L10n.Localizable.DownloadBadge
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
