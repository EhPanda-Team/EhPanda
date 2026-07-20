import AppModels
import SFSafeSymbols
import SwiftUI

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
                .contentTransition(.numericText())
                .lineLimit(1)
                .animation(.default, value: badge.progress.displayCompletedPageCount)
        }
        .foregroundStyle(badge.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badge.color.opacity(0.15))
        .clipShape(.capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var progressText: LocalizedStringResource {
        .downloadBadgeProgress(
            completed: badge.progress.displayCompletedPageCount,
            total: badge.progress.displayPageCount
        )
    }

    private var statusText: LocalizedStringResource {
        switch badge.status {
        case .queued:
            return .downloadBadgeQueued
        case .active:
            return .downloadBadgeDownloading
        case .inactive:
            return .downloadBadgePaused
        case .completed:
            return .downloadBadgeDownloaded
        case .updateAvailable:
            return .downloadBadgeUpdateAvailable
        case .error:
            return .downloadBadgeNeedsAttention
        }
    }

    private var accessibilityText: String {
        [String(localized: statusText), String(localized: progressText)].joined(separator: " ")
    }
}
