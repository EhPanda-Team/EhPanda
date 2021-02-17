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
            ProgressView("読み込み中...")
        }
    }
}

struct NotLoginView: View {
    let loginAction: (()->())?
    
    var body: some View {
        GenericRetryView(
            symbolName: "person.crop.circle.badge.questionmark",
            message: "ご利用にはログインが必要です",
            buttonText: "ログイン",
            retryAction: loginAction
        )
    }
}

struct NotFoundView: View {
    let retryAction: (()->())?
    
    var body: some View {
        GenericRetryView(
            symbolName: "questionmark.circle.fill",
            message: "お探しの情報が見つかりませんでした",
            buttonText: "やり直す",
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
                message: "ネットワーク障害が発生しました\nしばらくしてからもう一度お試しください",
                buttonText: "やり直す",
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
                .foregroundColor(colorScheme == .light ? .init(UIColor.darkGray) : .init(UIColor.white))
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
