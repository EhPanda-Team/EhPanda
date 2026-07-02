import SwiftUI
import AppModels
import Resources
import SFSafeSymbols
import AppTools

public struct LoadingView: View {
    private let title: String

    public init(title: String = L10n.Localizable.LoadingView.Title.loading) {
        self.title = title
    }

    public var body: some View {
        ProgressView(title)
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
        HStack(alignment: .center) {
            Spacer()
            ZStack {
                ProgressView().opacity(loadingState == .loading ? 1 : 0)
                Button {
                    retryAction?()
                } label: {
                    Image(systemSymbol: .exclamationmarkArrowTrianglehead2ClockwiseRotate90)
                        .foregroundStyle(.red).imageScale(.large)
                }
                .opacity(![.idle, .loading].contains(loadingState) ? 1 : 0)
            }
            Spacer()
        }
        .frame(height: 50)
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
            message: L10n.Localizable.NotLoginView.Title.needLogin
        ) {
            AlertViewButton(title: L10n.Localizable.NotLoginView.Button.login, action: action)
        }
    }
}

public struct ErrorView: View {
    private let error: AppError
    private let buttonTitle: String
    private let action: (() -> Void)?

    public init(
        error: AppError,
        buttonTitle: String = L10n.Localizable.ErrorView.Button.retry,
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

    public var body: some View {
        VStack {
            Image(systemSymbol: symbol).font(.system(size: 50)).padding(.bottom, 15)
            Text(message).multilineTextAlignment(.center).foregroundStyle(.gray)
                .font(.headline).padding(.bottom, 5)
            actions
        }
        .frame(maxWidth: DeviceUtil.windowW * 0.8)
    }
}

public struct AlertViewButton: View {
    private let title: String
    private let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundColor(.primary.opacity(0.7))
                .textCase(.uppercase)
        }
        .buttonBorderShape(.capsule)
        .buttonStyle(.glass)
    }
}
