//
//  LoadingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/05.
//

import SwiftUI

struct LoadingView: View {    
    var body: some View {
        ProgressView("読み込み中...")
            .padding(30)
    }
}
