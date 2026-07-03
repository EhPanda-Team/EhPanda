import SwiftUI
import SFSafeSymbols
import AppModels

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
        String(localized: .downloadBadgeProgress(
            badge.progress.displayCompletedPageCount,
            badge.progress.displayPageCount
        ))
    }

    private var statusText: String {
        switch badge.status {
        case .queued:
            return String(localized: .downloadBadgeQueued)
        case .active:
            return String(localized: .downloadBadgeDownloading)
        case .inactive:
            return String(localized: .downloadBadgePaused)
        case .completed:
            return String(localized: .downloadBadgeDownloaded)
        case .updateAvailable:
            return String(localized: .downloadBadgeUpdateAvailable)
        case .error:
            return String(localized: .downloadBadgeNeedsAttention)
        }
    }

    private var accessibilityText: String {
        [statusText, progressText].joined(separator: " ")
    }
}
