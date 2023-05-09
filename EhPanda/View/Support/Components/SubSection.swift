//
//  SubSection.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/18.
//

import SwiftUI

struct SubSection<Content: View>: View {
    private let title: String
    private let showAll: Bool
    private let tint: Color?
    private let isLoading: Bool?
    private let reloadAction: (() -> Void)?
    private let showAllAction: () -> Void
    private let content: Content

    init(
        title: String, showAll: Bool = true,
        tint: Color? = nil, isLoading: Bool? = nil,
        reloadAction: (() -> Void)? = nil,
        showAllAction: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showAll = showAll
        self.tint = tint
        self.isLoading = isLoading
        self.reloadAction = reloadAction
        self.showAllAction = showAllAction
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button {
                    reloadAction?()
                    HapticsUtil.generateFeedback(style: .soft)
                } label: {
                    HStack(spacing: 10) {
                        Text(title).font(.title3.bold())
                        ProgressView()
                            .opacity(isLoading == true ? 1 : 0)
                            .animation(.default, value: isLoading)
                    }
                }
                .allowsHitTesting(reloadAction != nil)
                .foregroundColor(.primary)
                Spacer()
                Button(action: showAllAction) {
                    Text(L10n.Localizable.SubSection.Button.showAll).font(.subheadline)
                }
                .tint(tint).opacity(showAll ? 1 : 0)
            }
            .padding(.horizontal)
            content
        }
    }
}

struct SubSection_Previews: PreviewProvider {
    static var previews: some View {
        SubSection(title: "Title") {
            Text("Content")
        }
    }
}
