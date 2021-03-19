//
//  NetworkErrorView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/27.
//

import SwiftUI

struct LoadingView: View {
    let isCompact: Bool
    
    init(isCompact: Bool = false) {
        self.isCompact = isCompact
    }
    
    var body: some View {
        switch isCompact {
        case true:
            ProgressView()
        case false:
            ProgressView("Loading...")
        }
    }
}

struct NotLoginView: View {
    let loginAction: (()->())?
    
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
    let retryAction: (()->())?
    
    var body: some View {
        GenericRetryView(
            symbolName: "questionmark.circle.fill",
            message: "Your search didn't match any docs.",
            buttonText: "Retry",
            retryAction: retryAction
        )
    }
}

struct NetworkErrorView: View {
    let isCompact: Bool
    let retryAction: (()->())?
    
    init(
        isCompact: Bool = false,
        retryAction: (()->())?
    ) {
        self.isCompact = isCompact
        self.retryAction = retryAction
    }
    
    var body: some View {
        switch isCompact {
        case true:
            Button(action: onRetryButtonTap) {
                Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                    .imageScale(.large)
            }
        case false:
            GenericRetryView(
                symbolName: "wifi.exclamationmark",
                message: "A Network error occurred.\nPlease try again later.",
                buttonText: "Retry",
                retryAction: onRetryButtonTap
            )
        }
    }
    
    func onRetryButtonTap() {
        if let action = retryAction {
            action()
        }
    }
}

struct GenericRetryView: View {
    @Environment(\.colorScheme) var colorScheme
    let symbolName: String
    let message: String
    let buttonText: String
    let retryAction: (()->())?
    
    var buttonColor: Color {
        colorScheme == .light
            ? Color(UIColor.darkGray)
            : Color(UIColor.white)
    }
    
    var body: some View {
        VStack {
            Image(systemName: symbolName)
                .font(.system(size: 50))
                .padding(.bottom, 15)
            Text(message.lString())
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .font(.headline)
                .padding(.bottom, 5)
            if let action = retryAction {
                Button(buttonText.lString().uppercased()) {
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
