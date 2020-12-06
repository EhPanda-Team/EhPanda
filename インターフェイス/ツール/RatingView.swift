//
//  RatingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/29.
//

import SwiftUI

struct RatingView: View {
    let rating: Float
    let color: Color
    
    init(rating: Float, _ color: Color = .yellow) {
        self.rating = rating
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 0) {
            if rating == 0.0 {
                ForEach(0..<5) { _ in NotFilledStar(color: color) }
            } else if rating == 0.5 {
                ForEach(0..<1) { _ in HalfFilledStar(color: color) }
                ForEach(0..<4) { _ in NotFilledStar(color: color) }
            } else if rating == 1.0 {
                ForEach(0..<1) { _ in FilledStar(color: color) }
                ForEach(0..<4) { _ in NotFilledStar(color: color) }
            } else if rating == 1.5 {
                ForEach(0..<1) { _ in FilledStar(color: color) }
                ForEach(0..<1) { _ in HalfFilledStar(color: color) }
                ForEach(0..<3) { _ in NotFilledStar(color: color) }
            } else if rating == 2.0 {
                ForEach(0..<2) { _ in FilledStar(color: color) }
                ForEach(0..<3) { _ in NotFilledStar(color: color) }
            } else if rating == 2.5 {
                ForEach(0..<2) { _ in FilledStar(color: color) }
                ForEach(0..<1) { _ in HalfFilledStar(color: color) }
                ForEach(0..<3) { _ in NotFilledStar(color: color) }
            } else if rating == 3.0 {
                ForEach(0..<3) { _ in FilledStar(color: color) }
                ForEach(0..<2) { _ in NotFilledStar(color: color) }
            } else if rating == 3.5 {
                ForEach(0..<3) { _ in FilledStar(color: color) }
                ForEach(0..<1) { _ in HalfFilledStar(color: color) }
                ForEach(0..<2) { _ in NotFilledStar(color: color) }
            } else if rating == 4.0 {
                ForEach(0..<4) { _ in FilledStar(color: color) }
                ForEach(0..<1) { _ in NotFilledStar(color: color) }
            } else if rating == 4.5 {
                ForEach(0..<4) { _ in FilledStar(color: color) }
                ForEach(0..<1) { _ in HalfFilledStar(color: color) }
            } else if rating == 5.0 {
                ForEach(0..<5) { _ in FilledStar(color: color) }
            }
        }
    }
}

// 構造体
extension RatingView {
    struct FilledStar: View {
        let color: Color
        
        var body: some View {
            Image(systemName: "star.fill")
                .font(.system(size: 14))
                .foregroundColor(color)
                .imageScale(.small)
            
        }
    }
    struct HalfFilledStar: View {
        let color: Color
        
        var body: some View {
            Image(systemName: "star.lefthalf.fill")
                .font(.system(size: 14))
                .foregroundColor(color)
                .imageScale(.small)
        }
    }
    struct NotFilledStar: View {
        let color: Color
        
        var body: some View {
            Image(systemName: "star")
                .font(.system(size: 14))
                .foregroundColor(color)
                .imageScale(.small)
        }
    }
}
