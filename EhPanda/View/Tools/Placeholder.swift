//
//  Placeholder.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/16.
//

import SwiftUI

struct Placeholder: View {
    let style: PlaceholderStyle
    var width: CGFloat?
    var height: CGFloat?
    
    var pageNumber: Int = 0
    var percentage: Float?
    
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
                        Text("\(pageNumber)")
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
