//
//  LoadingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/05.
//

import SwiftUI

enum LoadingStatusType {
    case popular
    case detail
}

struct LoadingView<Content> : View where Content : View {
    @ObservedObject var manager = LoadingStatusManager.shared
    @Environment(\.colorScheme) var colorScheme
    let contentView: () -> Content
    let retryAction: () -> ()
    
    let statusType: LoadingStatusType
    var status: LoadingStatus {
        switch statusType {
        case .popular:
            return manager.popularStatus
        case .detail:
            return manager.detailStatus
        }
    }
    
    init(type: LoadingStatusType ,content: @escaping () -> Content, retryAction: @escaping () -> ()) {
        self.statusType = type
        self.contentView = content
        self.retryAction = retryAction
    }
    
    var body: some View {
        if status == .loaded {
            contentView()
        } else if status == .loading {
            ProgressView("読み込み中...")
        } else
        if status == .failed {
            VStack {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 50))
                    .padding(.bottom, 15)
                Text("読み込み中に問題が発生しました\nしばらくしてからもう一度お試しください")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .font(.headline)
                    .padding(.bottom, 5)
                Button("やり直す") {
                    retryAction()
                }
                .foregroundColor(colorScheme == .light ? .init(UIColor.darkGray) : .init(UIColor.white))
                .capsulePadding()
                .withTapEffect(backgroundColor: Color(.systemGray5))
            }
        }
    }
}
