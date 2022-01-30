//
//  AlertView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/27.
//

import SwiftUI
import SFSafeSymbols

struct LoadingView: View {
    var body: some View {
        ProgressView(R.string.localizable.loadingViewTitleLoading())
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

struct ErrorView: View {
    private let error: AppError
    private let retryAction: (() -> Void)?

    init(error: AppError, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }

    var body: some View {
        GenericRetryView(
            symbol: error.symbol, message: error.alertText,
            buttonTitle: R.string.localizable.errorViewButtonRetry(),
            retryAction: retryAction
        )
    }
}

struct GenericRetryView: View {
    @Environment(\.colorScheme) private var colorScheme
    private let symbol: SFSymbol
    private let message: String
    private let buttonTitle: String
    private let retryAction: (() -> Void)?

    init(symbol: SFSymbol, message: String, buttonTitle: String, retryAction: (() -> Void)?) {
        self.symbol = symbol
        self.message = message
        self.buttonTitle = buttonTitle
        self.retryAction = retryAction
    }

    var body: some View {
        VStack {
            Image(systemSymbol: symbol).font(.system(size: 50)).padding(.bottom, 15)
            Text(message).multilineTextAlignment(.center).foregroundStyle(.gray)
                .font(.headline).padding(.bottom, 5)
            if let action = retryAction {
                Button(action: action) {
                    Text(buttonTitle).foregroundColor(.primary.opacity(0.7)).textCase(.uppercase)
                }
                .buttonStyle(.bordered).buttonBorderShape(.capsule)
            }
        }
        .frame(maxWidth: DeviceUtil.windowW * 0.8)
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
            Text(R.string.localizable.jumpPageViewTitleJumpPage()).bold()
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
