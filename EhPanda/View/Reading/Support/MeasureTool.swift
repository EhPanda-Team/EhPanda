//
//  MeasureTool.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/21.
//

import SwiftUI

struct MeasureTool: View {
    @Binding var frame: CGRect

    init(frame: Binding<CGRect>) {
        _frame = frame
    }

    var body: some View {
        GeometryReader { proxy in
            Text("I'm invisible~")
                .onChange(
                    of: proxy.frame(in: .global),
                    perform: { frame = $0 }
                )
        }
        .frame(width: 0, height: 0)
    }
}
