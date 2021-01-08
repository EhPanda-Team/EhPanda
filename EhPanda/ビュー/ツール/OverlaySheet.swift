//
//  OverlaySheet.swift
//  PokeMaster
//
//  Created by 王 巍 on 2019/08/11.
//  Copyright © 2019 OneV's Den. All rights reserved.
//

import SwiftUI

struct OverlaySheet<Content: View>: View {

    private let isPresented: Binding<Bool>
    private let makeContent: () -> Content

    @GestureState private var translation = CGPoint.zero

    init(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
        self.isPresented = isPresented
        self.makeContent = content
    }

    var body: some View {
        VStack {
            Spacer()
            makeContent()
        }
        .offset(y: (isPresented.wrappedValue ? 0 : UIScreen.main.bounds.height) + max(0, translation.y))
        .animation(.interpolatingSpring(stiffness: 70, damping: 12))
        .edgesIgnoringSafeArea(.bottom)
        .gesture(panelDraggingGesture)
    }

    var panelDraggingGesture: some Gesture {
        DragGesture()
            .updating($translation) { current, state, _ in
                state.y = current.translation.height
            }
            .onEnded { state in
                if state.translation.height > 250 {
                    self.isPresented.wrappedValue = false
                }
            }
    }
}

extension View {
    func overlaySheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View
    {
        overlay(
            OverlaySheet(isPresented: isPresented, content: content)
        )
    }
}
