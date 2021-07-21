//
//  Placeholder.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/16.
//

import SwiftUI

struct Placeholder: View {
    private let style: PlaceholderStyle

    init(style: PlaceholderStyle) {
        self.style = style
    }

    var body: some View {
        switch style {
        case .activity:
            ZStack {
                Color(.systemGray5)
                ProgressView()
            }
        case .progress(let pageNumber, let percentage):
            GeometryReader { proxy in
                ZStack {
                    Color(.systemGray5)
                    VStack {
                        Text(pageNumber.withoutComma)
                            .fontWeight(.bold)
                            .font(.largeTitle)
                            .foregroundStyle(.gray)
                            .padding(.bottom, 15)
                        ProgressView(value: percentage, total: 1)
                            .progressViewStyle(.linear)
                            .frame(width: proxy.size.width * 0.5)
                    }
                }
            }
        }
    }
}

enum PlaceholderStyle {
    case activity
    case progress(pageNumber: Int, percentage: Float)
}
