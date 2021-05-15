//
//  NewDawnView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/05/05.
//

import SwiftUI

private let sunWidth = screenW * (isPad ? 0.5 : 0.6)

struct NewDawnView: View {
    @Environment(\.colorScheme) private var colorScheme
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

    init(greeting: Greeting?) {
        _greeting = State(initialValue: greeting)
    }

    // MARK: NewDawnView
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(
                    colors: gradientColors
                ),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack {
                HStack {
                    Spacer()
                    ZStack {
                        SunView()
                        if colorScheme == .light {
                            SunBeamView()
                                .rotationEffect(Angle(degrees: rotationAngle))
                        }
                    }
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
                        text: "Reflecting on your journey so far, "
                            + "you find that you are a little wiser.",
                        font: .title2
                    )
                }
                if let content = greeting?.gainContent {
                    TextView(
                        text: content,
                        font: .title3,
                        fontWeight: .bold
                    )
                }
            }
            .padding()
        }
        .onReceive(timer, perform: onReceiveTimer)
    }
}

private extension NewDawnView {
    var gradientColors: [Color] {
        let teal = Color(.systemTeal)
        let indigo = Color(.systemIndigo)

        if colorScheme == .light {
            return [teal, indigo]
        } else {
            return [Color(.systemGray5), Color(.systemGray2)]
        }
    }

    func onReceiveTimer(_: Date) {
        withAnimation {
            rotationAngle += 1
        }
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

    init(
        text: String,
        font: Font,
        fontWeight: Font.Weight = .bold
    ) {
        self.text = text
        self.font = font
        self.fontWeight = fontWeight
    }

    var body: some View {
        HStack {
            Text(text.localized())
                .fontWeight(fontWeight)
                .font(font)
                .lineLimit(nil)
                .foregroundColor(.white)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            Spacer()
        }
    }
}

// MARK: SunView
private struct SunView: View {
    private let width = sunWidth

    var body: some View {
        ZStack {
            Circle()
                .foregroundColor(.yellow)
                .frame(width: width, height: width)
        }
    }
}

// MARK: SunBeamView
private struct SunBeamView: View {
    private let width = sunWidth
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
            SunBeamItem()
                .rotationEffect(Angle(degrees: degrees[index]))
                .offset(sizes[index])
        }
    }
}

// MARK: SunBeamItem
private struct SunBeamItem: View {
    private let width = sunWidth / 10
    private var height: CGFloat {
        width * 5
    }
    private var cornerRadius: CGFloat {
        width / 3
    }

    var body: some View {
        Rectangle()
            .foregroundColor(.yellow)
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
    }
}

struct NewDawnView_Previews: PreviewProvider {
    static var previews: some View {
        var greeting = Greeting()
        greeting.gainedEXP = 10
        greeting.gainedCredits = 10000
        greeting.gainedGP = 10000
        greeting.gainedHath = 10

        return Text("")
            .sheet(isPresented: .constant(true), content: {
                NewDawnView(greeting: greeting)
            })
    }
}
