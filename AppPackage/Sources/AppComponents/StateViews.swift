import AppModels
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI

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
            $0.opacity(loadingState.is(\.failed) ? 1 : 0)
        }
        .overlay {
            ProgressView()
                .animation(.default) {
                    $0.opacity(loadingState == .loading ? 1 : 0)
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
                .padding()
        }
    }
}

public struct ErrorView: View {
    private let error: AppError
    private let buttonTitle: LocalizedStringResource
    private let action: (() -> Void)?

    public init(
        error: AppError,
        buttonTitle: LocalizedStringResource = .RLocalizable.retry,
        action: (() -> Void)? = nil
    ) {
        self.error = error
        self.buttonTitle = buttonTitle
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            Label(error.localizedDescription, systemSymbol: error.symbol)
        } description: {
            if !error.alertText.isEmpty {
                Text(error.alertText)
            }
        } actions: {
            if let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(.glass(.regular.tint(.init(.systemGray5))))
                    .padding()
            }
        }
    }
}
