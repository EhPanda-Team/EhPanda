//
//  NetworkErrorView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/27.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        ProgressView("Loading...")
    }
}

struct NotFoundView: View {
    private let retryAction: (() -> Void)?

    init(retryAction: (() -> Void)?) {
        self.retryAction = retryAction
    }

    var body: some View {
        GenericRetryView(
            symbolName: "questionmark.circle.fill",
            message: "Your search didn't match any docs.",
            buttonText: "Retry",
            retryAction: retryAction
        )
    }
}

struct LoadMoreFooter: View {
    private var moreLoadingFlag: Bool
    private var moreLoadFailedFlag: Bool
    private var retryAction: (() -> Void)?
    private var symbolName =
    "exclamationmark.arrow.triangle.2.circlepath"

    init(
        moreLoadingFlag: Bool,
        moreLoadFailedFlag: Bool,
        retryAction: (() -> Void)?
    ) {
        self.moreLoadingFlag = moreLoadingFlag
        self.moreLoadFailedFlag = moreLoadFailedFlag
        self.retryAction = retryAction
    }

    var body: some View {
        HStack(alignment: .center) {
            Spacer()
            ZStack {
                ProgressView()
                    .opacity(moreLoadingFlag ? 1 : 0)
                Button(action: onButtonTap) {
                    Image(systemName: symbolName)
                        .foregroundStyle(.red)
                        .imageScale(.large)
                }
                .opacity(moreLoadFailedFlag ? 1 : 0)
            }
            Spacer()
        }
        .frame(height: 50)
    }

    private func onButtonTap() {
        retryAction?()
    }
}

struct NetworkErrorView: View {
    private let retryAction: (() -> Void)?

    init(retryAction: (() -> Void)?) {
        self.retryAction = retryAction
    }

    var body: some View {
        GenericRetryView(
            symbolName: "wifi.exclamationmark",
            message: "A Network error occurred.\nPlease try again later.",
            buttonText: "Retry",
            retryAction: onRetryButtonTap
        )
    }

    private func onRetryButtonTap() {
        retryAction?()
    }
}

struct GenericRetryView: View {
    @Environment(\.colorScheme) private var colorScheme
    private let symbolName: String
    private let message: String
    private let buttonText: String
    private let retryAction: (() -> Void)?

    init(
        symbolName: String,
        message: String,
        buttonText: String,
        retryAction: (() -> Void)?
    ) {
        self.symbolName = symbolName
        self.message = message
        self.buttonText = buttonText
        self.retryAction = retryAction
    }

    var body: some View {
        VStack {
            Image(systemName: symbolName)
                .font(.system(size: 50))
                .padding(.bottom, 15)
            Text(message.localized())
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray)
                .font(.headline)
                .padding(.bottom, 5)
            Button(action: { retryAction?() }, label: {
                Text(buttonText.localized().uppercased())
                    .foregroundColor(.primary.opacity(0.7))
            })
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
        .frame(maxWidth: windowW * 0.8)
    }
}
