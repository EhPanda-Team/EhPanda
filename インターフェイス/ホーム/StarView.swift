//
//  StarView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/29.
//

import SwiftUI

struct StarView: View {
    let rating: Float
    
    var body: some View {
        if rating == 0.0 {
            ForEach(0..<5) { _ in NotFilledStar() }
        } else if rating == 0.5 {
            ForEach(0..<1) { _ in HalfFilledStar() }
            ForEach(0..<4) { _ in NotFilledStar() }
        } else if rating == 1.0 {
            ForEach(0..<1) { _ in FilledStar() }
            ForEach(0..<4) { _ in NotFilledStar() }
        } else if rating == 1.5 {
            ForEach(0..<1) { _ in FilledStar() }
            ForEach(0..<1) { _ in HalfFilledStar() }
            ForEach(0..<3) { _ in NotFilledStar() }
        } else if rating == 2.0 {
            ForEach(0..<2) { _ in FilledStar() }
            ForEach(0..<3) { _ in NotFilledStar() }
        } else if rating == 2.5 {
            ForEach(0..<2) { _ in FilledStar() }
            ForEach(0..<1) { _ in HalfFilledStar() }
            ForEach(0..<3) { _ in NotFilledStar() }
        } else if rating == 3.0 {
            ForEach(0..<3) { _ in FilledStar() }
            ForEach(0..<2) { _ in NotFilledStar() }
        } else if rating == 3.5 {
            ForEach(0..<3) { _ in FilledStar() }
            ForEach(0..<1) { _ in HalfFilledStar() }
            ForEach(0..<2) { _ in NotFilledStar() }
        } else if rating == 4.0 {
            ForEach(0..<4) { _ in FilledStar() }
            ForEach(0..<1) { _ in NotFilledStar() }
        } else if rating == 4.5 {
            ForEach(0..<4) { _ in FilledStar() }
            ForEach(0..<1) { _ in HalfFilledStar() }
        } else if rating == 5.0 {
            ForEach(0..<5) { _ in FilledStar() }
        }
    }
}

// 構造体
extension StarView {
    struct FilledStar: View {
        var body: some View {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .imageScale(.small)
        }
    }
    struct HalfFilledStar: View {
        var body: some View {
            Image(systemName: "star.lefthalf.fill")
                .foregroundColor(.yellow)
                .imageScale(.small)
        }
    }
    struct NotFilledStar: View {
        var body: some View {
            Image(systemName: "star")
                .foregroundColor(.yellow)
                .imageScale(.small)
        }
    }
}
