//
//  The Liquid Glass capsule shown by `View.toast(_:)`. The layout adapts SystemNotificationMessage
//  (MIT, https://github.com/danielsaidi/SystemNotification): a leading symbol, a one-line bold title
//  over an optional one-line subtitle, and a hidden trailing symbol that mirrors the leading one so
//  the text stays optically centered. The capsule is pure Liquid Glass with nothing behind it,
//  layering glass over a Material would render it opaque.
//

import AppComponents
import ComposableArchitecture
import SFSafeSymbols
import SwiftUI

/// The rendered content of a toast, mapped from ``AppAlertState`` by ``AppAlertState/toastContent``.
struct ToastContent: Equatable {
    enum Icon: Equatable {
        case loading, success, error
    }

    var icon: Icon
    var title: String
    var subtitle: String?
    var autoHide: Bool
}

struct ToastMessageView: View {
    let content: ToastContent

    var body: some View {
        HStack(spacing: 16) {
            icon
            text
            icon.hidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .accessibilityIdentifier("toast_message")
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var icon: some View {
        switch content.icon {
        case .loading:
            ProgressView()
        case .success:
            Image(systemSymbol: .checkmarkCircle)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
        case .error:
            Image(systemSymbol: .exclamationmarkTriangle)
                .font(.title3)
                .foregroundStyle(.red)
        }
    }

    // One line each, so the capsule is always exactly one or two lines tall. Anything longer is
    // truncated rather than allowed to grow the capsule: the unabridged text lives on the detail
    // surface the toast taps through to, and VoiceOver still reads the full string.
    private var text: some View {
        VStack(spacing: 2) {
            Text(content.title)
                .font(.footnote.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
            if let subtitle = content.subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

/// Collapses line breaks so a multi-line message still occupies exactly one line.
///
/// `lineLimit(1)` alone would not be enough: several `AppError` messages are deliberately two
/// sentences separated by a newline, and limiting those to one line would drop the second sentence
/// outright rather than truncate the whole. Joining first keeps the sentence that would otherwise
/// vanish visible up to the truncation point.
private func singleLine(_ text: String) -> String {
    text.split(whereSeparator: \.isNewline)
        .map({ $0.trimmingCharacters(in: .whitespaces) })
        .filter({ !$0.isEmpty })
        .joined(separator: " ")
}

extension AppAlertState where Action == Never {
    /// Maps the unified presentation state onto renderable toast content. The `.alert` style never
    /// reaches a `toast` binding, so it degrades to a plain loading spinner defensively.
    var toastContent: ToastContent {
        let icon: ToastContent.Icon
        let autoHide: Bool
        switch style {
        case .alert:
            icon = .loading
            autoHide = false
        case let .toast(toastIcon, shouldAutoHide):
            autoHide = shouldAutoHide
            switch toastIcon {
            case .loading: icon = .loading
            case .success: icon = .success
            case .error: icon = .error
            }
        }
        return .init(
            icon: icon,
            title: singleLine(String(state: title)),
            subtitle: message.map({ singleLine(String(state: $0)) }),
            autoHide: autoHide
        )
    }
}
