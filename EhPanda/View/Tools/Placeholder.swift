//
//  Placeholder.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/16.
//

import SwiftUI

struct Placeholder: View {
    private let style: PlaceholderStyle
    private var width: CGFloat?
    private var height: CGFloat?

    private var pageNumber: Int = 0
    private var percentage: Float?

    init(
        style: PlaceholderStyle,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        pageNumber: Int = 0,
        percentage: Float? = nil
    ) {
        self.style = style
        self.width = width
        self.height = height
        self.pageNumber = pageNumber
        self.percentage = percentage
    }

    var body: some View {
        switch style {
        case .activity:
            if let width = width, let height = height {
                ZStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                    ProgressView()
                }
                .frame(width: width, height: height)
            } else {
                GeometryReader { proxy in
                    ZStack {
                        Rectangle()
                            .fill(Color(.systemGray5))
                        VStack {
                            Text("\(pageNumber)")
                                .fontWeight(.bold)
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                                .padding(.bottom, 15)
                            ProgressView()
                                .frame(width: proxy.size.width * 0.5)
                        }
                    }
                }
            }
        case .progress:
            GeometryReader { proxy in
                ZStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                    VStack {
                        Text(pageNumber.withoutComma)
                            .fontWeight(.bold)
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                            .padding(.bottom, 15)
                        ProgressView(value: percentage, total: 1)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: proxy.size.width * 0.5)
                    }
                }
            }
        }
    }
}

enum PlaceholderStyle {
    case activity
    case progress
}
