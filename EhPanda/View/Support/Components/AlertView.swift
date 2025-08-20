//
//  AlertView.swift
//  EhPanda
//

import SwiftUI
import SFSafeSymbols

struct LoadingView: View {
    private let title: String

    init(title: String = L10n.Localizable.LoadingView.Title.loading) {
        self.title = title
    }

    var body: some View {
        ProgressView(title)
    }
}

struct FetchMoreFooter: View {
    private let loadingState: LoadingState
    private let retryAction: (() -> Void)?

    init(loadingState: LoadingState, retryAction: (() -> Void)?) {
        self.loadingState = loadingState
        self.retryAction = retryAction
    }

    var body: some View {
        HStack(alignment: .center) {
            Spacer()
            ZStack {
                ProgressView().opacity(loadingState == .loading ? 1 : 0)
                Button {
                    retryAction?()
                } label: {
                    Image(systemSymbol: .exclamationmarkArrowTriangle2Circlepath)
                        .foregroundStyle(.red).imageScale(.large)
                }
                .opacity(![.idle, .loading].contains(loadingState) ? 1 : 0)
            }
            Spacer()
        }
        .frame(height: 50)
    }
}

struct NotLoginView: View {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        AlertView(
            symbol: .personCropCircleBadgeQuestionmarkFill,
            message: L10n.Localizable.NotLoginView.Title.needLogin
        ) {
            AlertViewButton(title: L10n.Localizable.NotLoginView.Button.login, action: action)
        }
    }
}

struct ErrorView: View {
    private let error: AppError
    private let buttonTitle: String
    private let action: (() -> Void)?

    init(
        error: AppError,
        buttonTitle: String = L10n.Localizable.ErrorView.Button.retry,
        action: (() -> Void)? = nil
    ) {
        self.error = error
        self.buttonTitle = buttonTitle
        self.action = action
    }

    var body: some View {
        AlertView(symbol: error.symbol, message: error.alertText) {
            if let action = action {
                AlertViewButton(title: buttonTitle, action: action)
            }
        }
    }
}

struct AlertView<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let symbol: SFSymbol
    private let message: String
    private let actions: Content

    init(symbol: SFSymbol, message: String, @ViewBuilder actions: () -> Content) {
        self.symbol = symbol
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        VStack {
            Image(systemSymbol: symbol).font(.system(size: 50)).padding(.bottom, 15)
            Text(message).multilineTextAlignment(.center).foregroundStyle(.gray)
                .font(.headline).padding(.bottom, 5)
            actions
        }
        .frame(maxWidth: DeviceUtil.windowW * 0.8)
    }
}

struct AlertViewButton: View {
    private let title: String
    private let action: () -> Void

    init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title).foregroundColor(.primary.opacity(0.7)).textCase(.uppercase)
        }
        .buttonStyle(.bordered).buttonBorderShape(.capsule)
    }
}

struct PageJumpView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding private var inputText: String
    private var isFocused: FocusState<Bool>.Binding
    private let pageNumber: PageNumber

    init(inputText: Binding<String>, isFocused: FocusState<Bool>.Binding, pageNumber: PageNumber) {
        _inputText = inputText
        self.isFocused = isFocused
        self.pageNumber = pageNumber
    }

    var body: some View {
        VStack {
            Text(L10n.Localizable.JumpPageView.Title.jumpPage).bold()
            HStack {
                let opacity = colorScheme == .light ? 0.15 : 0.1
                TextField(inputText, text: $inputText).multilineTextAlignment(.center).keyboardType(.numberPad)
                    .padding(.horizontal, 10).padding(.vertical, 5).background(Color.gray.opacity(opacity))
                    .cornerRadius(5).frame(width: 75).focused(isFocused.projectedValue)
                Text("-")
                Text("\(pageNumber.maximum + 1)")
            }
            .lineLimit(1)
        }
    }
}
