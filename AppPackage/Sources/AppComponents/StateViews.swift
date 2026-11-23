public import AppModels
import AppTools
import CasePathsCore
public import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
public import SwiftUI

public struct LoadingView: View {
    private let title: LocalizedStringResource

    public init(title: LocalizedStringResource? = nil) {
        self.title = title ?? .loading
    }

    public var body: some View {
        ProgressView(title)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .glassEffect(in: .rect(cornerRadius: 14))
    }
}

public struct FetchMoreFooter: View {
    private let loadingState: LoadingState
    private let retryAction: (() -> Void)?

    public init(loadingState: LoadingState, retryAction: (() -> Void)?) {
        self.loadingState = loadingState
        self.retryAction = retryAction
    }

    public var body: some View {
        Button {
            retryAction?()
        } label: {
            Label(.RLocalizable.retry, systemSymbol: .exclamationmarkArrowTrianglehead2ClockwiseRotate90)
                .labelStyle(.iconOnly)
                .foregroundStyle(.red)
                .imageScale(.large)
        }
        .animation(.default) {
            $0.visible(loadingState.is(\.failed))
        }
        .overlay {
            ProgressView()
                .animation(.default) {
                    $0.visible(loadingState == .loading)
                }
        }
        .frame(maxWidth: .infinity, minHeight: 50)
    }
}

public struct NotLoginView: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            Label(.needLogin, systemSymbol: .personCropCircleBadgeQuestionmarkFill)
        } actions: {
            Button(.RLocalizable.login, action: action)
                .buttonStyle(.glass(.regular.tint(.init(.systemGray5))))
                .interactiveHover(.highlight, in: .capsule)
                .padding()
        }
    }
}

public struct ErrorView: View {
    private let error: AppError
    private let buttonTitle: LocalizedStringResource
    private let showsSymbol: Bool
    private let secondaryTitle: LocalizedStringResource?
    private let secondaryAction: (() -> Void)?
    private let action: (() -> Void)?

    /// - Parameters:
    ///   - showsSymbol: Whether the error's symbol is drawn above its title; a view with little height leaves it out
    ///     so the title and the text stay in view.
    ///   - secondaryTitle: A second button's title, drawn above the first, 8 pt apart, in the same style (My Tags'
    ///     Open in Browser, design approved 2026-11-22); shown only with `secondaryAction`.
    public init(
        error: AppError,
        buttonTitle: LocalizedStringResource = .RLocalizable.retry,
        showsSymbol: Bool = true,
        secondaryTitle: LocalizedStringResource? = nil,
        secondaryAction: (() -> Void)? = nil,
        action: (() -> Void)? = nil
    ) {
        self.error = error
        self.buttonTitle = buttonTitle
        self.showsSymbol = showsSymbol
        self.secondaryTitle = secondaryTitle
        self.secondaryAction = secondaryAction
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            if showsSymbol {
                Label(error.localizedDescription, systemSymbol: error.symbol)
            } else {
                // Still a label, so the title keeps the unavailable view's title style.
                Label {
                    Text(error.localizedDescription)
                } icon: {
                    EmptyView()
                }
            }
        } description: {
            if !error.alertText.isEmpty {
                Text(error.alertText)
            }
        } actions: {
            if let secondaryTitle, let secondaryAction {
                VStack(spacing: 8) {
                    Button(secondaryTitle, action: secondaryAction)
                        .buttonStyle(.glass(.regular.tint(.init(.systemGray5))))
                    if let action {
                        Button(buttonTitle, action: action)
                            .buttonStyle(.glass(.regular.tint(.init(.systemGray5))))
                    }
                }
                .padding()
            } else if let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(.glass(.regular.tint(.init(.systemGray5))))
                    .interactiveHover(.highlight, in: .capsule)
                    .padding()
            }
        }
    }
}
