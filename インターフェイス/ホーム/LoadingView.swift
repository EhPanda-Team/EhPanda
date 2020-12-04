//
//  LoadingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/05.
//

import SwiftUI

struct LoadingView<Content> : View where Content : View {
    @ObservedObject var manager = RequestManager.shared
    @Environment(\.colorScheme) var colorScheme
    let contentView: () -> Content
    let retryAction: () -> ()
    
    var body: some View {
        if manager.status == .loaded {
            contentView()
        } else if manager.status == .loading {
            ProgressView("読み込み中...")
        } else if manager.status == .failed {
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
                .padding(.init(top: 6, leading: 10, bottom: 6, trailing: 10))
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .foregroundColor(Color(.systemGray5))
                )
            }
        }
    }
}
