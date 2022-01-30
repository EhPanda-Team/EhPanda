//
//  NewDawnView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/05/05.
//

import SwiftUI

struct NewDawnView: View {
    @Environment(\.colorScheme) private var colorScheme
    private let greeting: Greeting

    private var offset: Double {
        DeviceUtil.windowW * 0.2
    }
    private var sunWidth: Double {
        DeviceUtil.windowW * (DeviceUtil.isPad ? 0.5 : 0.6)
    }

    private var gradientColors: [Color] {
        if colorScheme == .light {
            return [Color(.systemTeal), Color(.systemIndigo)]
        } else {
            return [Color(.systemGray5), Color(.systemGray2)]
        }
    }

    init(greeting: Greeting) {
        self.greeting = greeting
    }

    // MARK: NewDawnView
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: .top, endPoint: .bottom
            )
            VStack {
                HStack {
                    Spacer()
                    ZStack {
                        SunView(width: sunWidth)
                        SunBeamView(width: sunWidth)
                            .opacity(colorScheme == .light ? 1 : 0)
                    }
                    .offset(x: offset, y: -offset)
                }
                Spacer()
            }
            VStack(spacing: 50) {
                VStack(spacing: 10) {
                    TextView(
                        text: "It is the dawn of a new day!",
                        font: .largeTitle
                    )
                    TextView(
                        text: "Reflecting on your journey so far, "
                            + "you find that you are a little wiser.",
                        font: .title2
                    )
                }
                TextView(
                    text: greeting.gainContent ?? "",
                    font: .title3, fontWeight: .bold
                )
            }
            .padding()
        }
        .drawingGroup()
        .ignoresSafeArea()
    }
}

// MARK: TextView
private struct TextView: View {
    @Environment(\.colorScheme) private var colorScheme
    private let text: String
    private let font: Font
    private let fontWeight: Font.Weight

    private var reversePrimary: Color {
        colorScheme == .light ? .white : .black
    }

    init(text: String, font: Font, fontWeight: Font.Weight = .bold) {
        self.text = text
        self.font = font
        self.fontWeight = fontWeight
    }

    var body: some View {
        HStack {
            Text(text)
                .fontWeight(fontWeight).font(font)
                .lineLimit(nil).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

// MARK: SunView
private struct SunView: View {
    private let width: Double

    init(width: Double) {
        self.width = width
    }

    var body: some View {
        ZStack {
            Circle().foregroundStyle(.yellow)
                .frame(width: width, height: width)
        }
    }
}

// MARK: SunBeamView
private struct SunBeamView: View {
    private let width: Double

    init(width: Double) {
        self.width = width
    }

    private var offset: CGFloat { width / 1.2 }
    private var evenOffset: CGFloat { offset / sqrt(2) }
    private var sizes: [CGSize] {
        [
            CGSize(width: 0, height: -offset),
            CGSize(width: evenOffset, height: -evenOffset),
            CGSize(width: offset, height: 0),
            CGSize(width: evenOffset, height: evenOffset),
            CGSize(width: 0, height: offset),
            CGSize(width: -evenOffset, height: evenOffset),
            CGSize(width: -offset, height: 0),
            CGSize(width: -evenOffset, height: -evenOffset)
        ]
    }
    private var degrees: [Double] = [
        0, 45, 90, 135, 180, 225, 270, 315
    ]

    var body: some View {
        ForEach(0..<8, id: \.self) { index in
            SunBeamItem(width: width / 10)
                .rotationEffect(Angle(degrees: degrees[index]))
                .offset(sizes[index])
        }
    }
}

// MARK: SunBeamItem
private struct SunBeamItem: View {
    private let width: Double

    init(width: Double) {
        self.width = width
    }

    var body: some View {
        Rectangle()
            .foregroundStyle(.yellow)
            .frame(width: width, height: width * 5)
            .cornerRadius(width / 3)
    }
}

struct NewDawnView_Previews: PreviewProvider {
    static var previews: some View {
        Text("")
            .sheet(isPresented: .constant(true)) {
                NewDawnView(greeting: .mock)
            }
    }
}
