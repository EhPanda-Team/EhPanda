//
//  MeasureTool.swift
//  MeasureTool
//
//  Created by 荒木辰造 on 2021/07/21.
//

import SwiftUI

struct MeasureTool: View {
    @Binding var frame: CGRect

    init(bindingFrame: Binding<CGRect>) {
        _frame = bindingFrame
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
