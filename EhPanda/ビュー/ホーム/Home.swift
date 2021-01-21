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
    @State var width = UIScreen.main.bounds.width - 90
    @State var x = -UIScreen.main.bounds.width + 90
    @State var direction: Direction = .none
    
    enum Direction {
        case none
        case toLeft
        case toRight
    }
    
    var hasPermission: Bool {
        vcsCount == 1
    }
    var opacity: Double {
        Double((width + x) / width) * 0.5
    }
    
    var body: some View {
        ZStack(alignment: Alignment(horizontal: .leading, vertical: .center)) {
            HomeView()
                .offset(x: x + width)
            SlideMenu()
                .offset(x: x)
                .background(
                    Color.black.opacity(opacity)
                        .edgesIgnoringSafeArea(.vertical)
                        .onTapGesture {
                            withAnimation { x = -width }
                        }
                )
        }
        .gesture (
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    if hasPermission {
                        withAnimation {
                            switch direction {
                            case .none:
                                let isToLeft = value.translation.width < 0
                                direction = isToLeft ? .toLeft : .toRight
                            case .toLeft:
                                if x > -width {
                                    x = min(value.translation.width, 0)
                                }
                            case .toRight:
                                if x < 0 {
                                    x = max(-width + value.translation.width, -width)
                                }
                            }
                        }
                    }
                }
                .onEnded { value in
                    if hasPermission {
                        withAnimation {
                            let perdictedWidth = value.predictedEndTranslation.width
                            if perdictedWidth > width / 2 || -x < width / 2 {
                                x = 0
                            }
                            if perdictedWidth < -width / 2 || -x > width / 2 {
                                x = -width
                            }
                            direction = .none
                        }
                    }
                }
            
        )
    }
}

// MARK: SlideMenu
private struct SlideMenu : View {
    @Environment(\.colorScheme) var colorScheme
    
    var menuItems: [HomeListType] = [.frontpage, .popular,.favorites, .downloaded]
    
    var reversedPrimary: Color {
        Color(.systemGray6)
//        colorScheme == .light ? .white : .black
    }
    
    var edges = UIApplication.shared.windows.first?.safeAreaInsets
    @State var show = true
    
    var body: some View {
        
        HStack(spacing: 0) {
            VStack(spacing: 20) {
                Spacer()
                ForEach(menuItems) { item in
                    MenuRow(
                        symbolName: item.symbolName,
                        text: item.rawValue.lString(),
                        action: {}
                    )
                }
                Divider()
                MenuRow(
                    symbolName: "gear",
                    text: "設定",
                    action: {}
                )
                Spacer()
            }
            .padding(.horizontal,20)
            .padding(.top,edges!.top == 0 ? 15 : edges?.top)
            .padding(.bottom,edges!.bottom == 0 ? 15 : edges?.bottom)
            .frame(width: UIScreen.main.bounds.width - 90)
            .background(reversedPrimary)
            .edgesIgnoringSafeArea(.vertical)
            
            Spacer(minLength: 0)
        }
    }
}

private struct MenuRow: View {
    @Environment(\.colorScheme) var colorScheme
    
    let symbolName: String
    let text: String
    let action: (()->())
    
    var color: Color {
        colorScheme == .light
            ? Color(.darkGray)
            : Color(.lightGray)
    }
    
    var body: some View {
        HStack {
            Image(systemName: symbolName)
                .font(.title2)
                .frame(width: 35)
                .foregroundColor(color)
                .padding(.trailing, 10)
            Text(text)
                .fontWeight(.regular)
                .foregroundColor(.primary)
                .font(.title2)
            Spacer()
        }
    }
}
