//
//  NewDawnView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/05/05.
//

import SwiftUI

struct NewDawnView: View {
    @State private var rotationAngle: Double = 0
    @State private var greeting: Greeting?
    @State private var timer = Timer
        .publish(
            every: 1/10,
            on: .main,
            in: .common
        )
        .autoconnect()

    private let offset = screenW * 0.2

    init(greeting: Greeting) {
        self.greeting = greeting
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(
                    colors: [Color(.systemTeal), Color(.systemIndigo)]
                ),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack {
                HStack {
                    Spacer()
                    SunView()
                        .rotationEffect(Angle(degrees: rotationAngle))
                        .offset(x: offset, y: -offset)
                }
                Spacer()
            }
            .ignoresSafeArea()
            VStack(spacing: 50) {
                VStack(spacing: 10) {
                    TextView(
                        text: "It is the dawn of a new day!",
                        font: .largeTitle
                    )
                    TextView(
                        text: "Reflecting on your journey so far, you find that you are a little wiser.",
                        font: .title2
                    )
                }
                TextView(
                    text: "You gain 30 EXP, 10,393 Credits, 10,000 GP and 11 Hath!",
                    font: .title3,
                    fontWeight: .bold,
                    lineLimit: 3
                )
            }
            .padding()
        }
        .onReceive(timer, perform: onReceiveTimer)
    }
}

private extension NewDawnView {
    func onReceiveTimer(_: Date) {
        withAnimation {
            rotationAngle += 1
        }
    }
}

private struct TextView: View {
    @Environment(\.colorScheme) private var colorScheme
    private let text: String
    private let font: Font
    private let fontWeight: Font.Weight
    private let lineLimit: Int?

    private var reversePrimary: Color {
        colorScheme == .light ? .white : .black
    }

    init(
        text: String,
        font: Font,
        fontWeight: Font.Weight = .bold,
        lineLimit: Int? = nil
    ) {
        self.text = text
        self.font = font
        self.fontWeight = fontWeight
        self.lineLimit = lineLimit
    }

    var body: some View {
        HStack {
            Text(text)
                .fontWeight(fontWeight)
                .font(font)
                .lineLimit(lineLimit)
                .foregroundColor(reversePrimary)
            Spacer()
        }
    }
}

private struct SunView: View {
    private let width = screenW * 0.75
    private var offset: CGFloat { width / 2 + 70 }
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
        ZStack {
            Circle()
                .foregroundColor(.yellow)
                .frame(width: width, height: width)
            ForEach(0..<8, id: \.self) { index in
                SunBeamView()
                    .rotationEffect(Angle(degrees: degrees[index]))
                    .offset(sizes[index])
            }
        }
    }
}

private struct SunBeamView: View {
    private let width = screenW * 0.05
    private var height: CGFloat {
        width * 5
    }

    var body: some View {
        Rectangle()
            .foregroundColor(.yellow)
            .frame(width: width, height: height)
            .cornerRadius(5)
    }
}

struct NewDawnView_Previews: PreviewProvider {
    static var previews: some View {
        NewDawnView(greeting: Greeting())
    }
}
