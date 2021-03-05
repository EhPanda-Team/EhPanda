//
//  Home.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/20.
//  Copied from https://kavsoft.dev/SwiftUI_2.0/Twitter_Menu/
//

import SwiftUI

struct Home : View {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) var colorScheme
    
    // スライドメニュー
    @State var direction: Direction = .none
    @State var offset = -Defaults.FrameSize.slideMenuWidth
    @State var width = Defaults.FrameSize.slideMenuWidth
    
    // プライバシーロック
    @State var blurRadius: CGFloat = 0
        
    var environment: AppState.Environment {
        store.appState.environment
    }
    var isAppUnlocked: Bool {
        environment.isAppUnlocked
    }
    var isSlideMenuClosed: Bool {
        environment.isSlideMenuClosed
    }
    
    enum Direction {
        case none
        case toLeft
        case toRight
    }
    
    var hasPermission: Bool {
        vcsCount == 1
    }
    var opacity: Double {
        let scale = colorScheme == .light ? 0.2 : 0.5
        return Double((width + offset) / width) * scale
    }
    
    var body: some View {
        ZStack {
            ZStack {
                HomeView()
                    .offset(x: offset + width)
                SlideMenu(offset: $offset)
                    .offset(x: offset)
                    .background(
                        Color.black.opacity(opacity)
                            .edgesIgnoringSafeArea(.vertical)
                            .onTapGesture {
                                performTransition(-width)
                            }
                    )
            }
            .blur(radius: blurRadius)
            .allowsHitTesting(isAppUnlocked)
            AuthView(blurRadius: $blurRadius)
        }
        .gesture (
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    if hasPermission {
                        withAnimation(Animation.linear(duration: 0.2)) {
                            switch direction {
                            case .none:
                                let isToLeft = value.translation.width < 0
                                direction = isToLeft ? .toLeft : .toRight
                            case .toLeft:
                                if offset > -width {
                                    offset = min(value.translation.width, 0)
                                }
                            case .toRight:
                                if offset < 0, value.startLocation.x < 20 {
                                    offset = max(-width + value.translation.width, -width)
                                }
                            }
                            updateSlideMenuState(isClosed: offset == -width)
                        }
                    }
                }
                .onEnded { value in
                    if hasPermission {
                        let perdictedWidth = value.predictedEndTranslation.width
                        if perdictedWidth > width / 2 || -offset < width / 2 {
                            performTransition(0)
                        }
                        if perdictedWidth < -width / 2 || -offset > width / 2 {
                            performTransition(-width)
                        }
                        direction = .none
                    }
                }
        )
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.didBecomeActiveNotification
            )
        ) { _ in
            onWidthChange()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIDevice.orientationDidChangeNotification
            )
        ) { _ in
            if isPortrait || isLandscape {
                onWidthChange()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("SlideMenuShouldClose")
            )
        ) { _ in
            onReceiveSlideMenuShouldCloseNotification()
        }
    }
    
    func onWidthChange() {
        if isPad {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if width != Defaults.FrameSize.slideMenuWidth {
                    withAnimation {
                        offset = -Defaults.FrameSize.slideMenuWidth
                        width = Defaults.FrameSize.slideMenuWidth
                    }
                }
                postAppWidthDidChangeNotification()
            }
        }
    }
    func onReceiveSlideMenuShouldCloseNotification() {
        performTransition(-width)
    }
    
    func performTransition(_ offset: CGFloat) {
        withAnimation(Animation.default) {
            self.offset = offset
        }
        updateSlideMenuState(isClosed: offset == -width)
    }
    
    func updateSlideMenuState(isClosed: Bool) {
        if isSlideMenuClosed != isClosed {
            store.dispatch(.updateIsSlideMenuClosed(isClosed: isClosed))
        }
    }
}
