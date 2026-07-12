import SwiftUI
import AppModels
import Resources
import SFSafeSymbols
import AppTools

public struct LoadingView: View {
    private let title: LocalizedStringResource

    public init(title: LocalizedStringResource? = nil) {
        self.title = title ?? .loading
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
                if loadingState == .loading {
                    ProgressView()
                } else if loadingState != .idle {
                    Button {
                        retryAction?()
                    } label: {
                        Image(systemSymbol: .exclamationmarkArrowTrianglehead2ClockwiseRotate90)
                            .foregroundStyle(.red).imageScale(.large)
                    }
                }
            }
            .animation(.default, value: loadingState)
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
        symbol: SFSymbol, message: LocalizedStringResource, @ViewBuilder actions: () -> Content
    ) {
        self.init(symbol: symbol, message: String(localized: message), actions: actions)
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
    private let title: LocalizedStringResource
    private let action: () -> Void

    public init(title: LocalizedStringResource, action: @escaping () -> Void) {
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
