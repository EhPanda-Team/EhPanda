//
//  ToastMessageView.swift
//  SystemNotificationExt
//
//  The Liquid Glass capsule shown by `View.toast(_:)`. The layout adapts SystemNotificationMessage
//  (MIT, https://github.com/danielsaidi/SystemNotification): a leading symbol, a one-line bold title
//  over an optional one-line subtitle, and a hidden trailing symbol that mirrors the leading one so
//  the text stays optically centered. The capsule is pure Liquid Glass with nothing behind it —
//  layering glass over a Material would render it opaque.
//

import SwiftUI
import SFSafeSymbols
import AppComponents
import ComposableArchitecture

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
        .glassEffect(.regular, in: .capsule)
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
                .foregroundStyle(.green)
        case .error:
            Image(systemSymbol: .exclamationmarkTriangle)
                .font(.title3)
                .foregroundStyle(.red)
        }
    }

    private var text: some View {
        VStack(spacing: 2) {
            Text(content.title)
                .font(.footnote.bold())
                .foregroundStyle(.primary)
            if let subtitle = content.subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
    }
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
            title: String(state: title),
            subtitle: message.map { String(state: $0) },
            autoHide: autoHide
        )
    }
}
