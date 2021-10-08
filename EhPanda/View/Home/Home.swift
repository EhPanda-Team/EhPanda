//
//  Home.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/20.
//  Copied from https://kavsoft.dev/SwiftUI_2.0/Twitter_Menu/
//

import SwiftUI
import Kingfisher

struct Home: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) private var colorScheme

    // AppLock
    @State private var blurRadius: CGFloat = 0
    // SlideMenu
    @State private var direction: Direction = .none
    @State private var width = Defaults.FrameSize.slideMenuWidth
    @State private var offset = -Defaults.FrameSize.slideMenuWidth

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
                                performTransition(offset: -width)
                            }
                    )
                    .opacity(viewControllersCount > 1 ? 0 : 1)
            }
            .blur(radius: blurRadius)
            .allowsHitTesting(isAppUnlocked)
            AuthView(blurRadius: $blurRadius)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
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
                .onEnded { value in
                    let perdictedWidth = value.predictedEndTranslation.width
                    if perdictedWidth > width / 2 || -offset < width / 2 {
                        performTransition(offset: 0)
                    }
                    if perdictedWidth < -width / 2 || -offset > width / 2 {
                        performTransition(offset: -width)
                    }
                    direction = .none
                },
            including: viewControllersCount == 1 ? .all : .none
        )
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.didBecomeActiveNotification
            )
        ) { _ in onWidthChange() }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIDevice.orientationDidChangeNotification
            )
        ) { _ in
            if DeviceUtil.isPad || DeviceUtil.isLandscape {
                onWidthChange()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("ShouldShowSlideMenu")
            )
        ) { _ in performTransition(offset: 0) }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("ShouldHideSlideMenu")
            )
        ) { _ in performTransition(offset: -width) }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("BypassesSNIFilteringDidChange")
            )
        ) { _ in toggleDomainFronting() }
    }
}

private extension Home {
    enum Direction {
        case none
        case toLeft
        case toRight
    }

    var opacity: Double {
        let scale = colorScheme == .light ? 0.2 : 0.5
        return (width + offset) / width * scale
    }

    func onWidthChange() {
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
    func toggleDomainFronting() {
        if setting.bypassesSNIFiltering {
            URLProtocol.registerClass(DFURLProtocol.self)
        } else {
            URLProtocol.unregisterClass(DFURLProtocol.self)
        }
        AppUtil.configureKingfisher(bypassesSNIFiltering: setting.bypassesSNIFiltering)
    }

    func performTransition(offset: CGFloat) {
        withAnimation {
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
