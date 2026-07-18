import SwiftUI
import AppModels
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt

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
        AlertView(
            symbol: .personCropCircleBadgeQuestionmarkFill,
            message: .needLogin
        ) {
            AlertViewButton(title: .RLocalizable.login, action: action)
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
        AlertView(symbol: error.symbol, message: error.alertText) {
            if let action = action {
                AlertViewButton(title: buttonTitle, action: action)
            }
        }
    }
}

public struct AlertView<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let symbol: SFSymbol
    private let message: String
    private let actions: Content

    public init(symbol: SFSymbol, message: String, @ViewBuilder actions: () -> Content) {
        self.symbol = symbol
        self.message = message
        self.actions = actions()
    }

    // Resource overload for static localized messages; the `String` init above remains for
    // dynamic messages that are already resolved (e.g. `AppError.alertText`).
    public init(
        symbol: SFSymbol,
        message: LocalizedStringResource,
        @ViewBuilder actions: () -> Content = EmptyView.init
    ) {
        self.init(symbol: symbol, message: String(localized: message), actions: actions)
    }

    // 50pt at default (.large); scales with Dynamic Type relative to the nearest text style (.largeTitle, 34pt).
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 50

    public var body: some View {
        VStack {
            Image(systemSymbol: symbol).font(.system(size: symbolSize)).padding(.bottom, 15)
            Text(message).multilineTextAlignment(.center).foregroundStyle(.gray)
                .font(.headline).padding(.bottom, 5)
            actions
        }
        .frame(maxWidth: 500)
        .containerRelativeFrame(.horizontal, alignment: .center) { width, _ in
            min(width * 0.8, 500)
        }
    }
}

public struct AlertViewButton: View {
    private let title: LocalizedStringResource
    private let action: () -> Void

    public init(title: LocalizedStringResource, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundStyle(.primary.opacity(0.7))
        }
        .buttonBorderShape(.capsule)
        .buttonStyle(.glass)
    }
}
