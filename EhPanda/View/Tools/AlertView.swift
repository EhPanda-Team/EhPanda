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

struct NotLoginView: View {
    private let loginAction: (() -> Void)?

    init(loginAction: (() -> Void)?) {
        self.loginAction = loginAction
    }

    var body: some View {
        GenericRetryView(
            symbolName: "person.crop.circle.badge.questionmark",
            message: "You need to login to use this app.",
            buttonText: "Login",
            retryAction: loginAction
        )
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

struct NetworkErrorCompactView: View {
    private let retryAction: (() -> Void)?

    init(retryAction: (() -> Void)?) {
        self.retryAction = retryAction
    }

    var body: some View {
        Button(action: onRetryButtonTap) {
            Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                .imageScale(.large)
        }
    }

    private func onRetryButtonTap() {
        if let action = retryAction {
            action()
        }
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
        if let action = retryAction {
            action()
        }
    }
}

struct GenericRetryView: View {
    @Environment(\.colorScheme) private var colorScheme
    private let symbolName: String
    private let message: String
    private let buttonText: String
    private let retryAction: (() -> Void)?

    private var buttonColor: Color {
        colorScheme == .light
            ? Color(UIColor.darkGray)
            : Color(UIColor.white)
    }

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
                .foregroundColor(.gray)
                .font(.headline)
                .padding(.bottom, 5)
            if let action = retryAction {
                Button(buttonText.localized().uppercased()) {
                    action()
                }
                .foregroundColor(buttonColor)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .foregroundColor(Color(.systemGray5))
                )
            }
        }
    }
}
