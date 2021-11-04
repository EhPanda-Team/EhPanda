//
//  NewDawnView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/05/05.
//

import SwiftUI

private let sunWidth = DeviceUtil.windowW * (DeviceUtil.isPad ? 0.5 : 0.6)

struct NewDawnView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var rotationAngle: Double = 0
    @State private var greeting: Greeting?

    private let offset = DeviceUtil.windowW * 0.2

    private var gradientColors: [Color] {
        if colorScheme == .light {
            return [Color(.systemTeal), Color(.systemIndigo)]
        } else {
            return [Color(.systemGray5), Color(.systemGray2)]
        }
    }

    init(greeting: Greeting?) {
        _greeting = State(initialValue: greeting)
    }

    // MARK: NewDawnView
    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSince1970
            let angle = Angle.degrees(now * 50)

            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: gradientColors),
                    startPoint: .top, endPoint: .bottom
                )
                VStack {
                    HStack {
                        Spacer()
                        ZStack {
                            SunView()
                            SunBeamView()
                                .rotationEffect(
                                    colorScheme == .light
                                    ? angle : Angle(degrees: 0)
                                )
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
                        text: greeting?.gainContent ?? "",
                        font: .title3, fontWeight: .bold
                    )
                }
                .padding()
            }
            .drawingGroup()
            .ignoresSafeArea()
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

    init(text: String, font: Font, fontWeight: Font.Weight = .bold) {
        self.text = text
        self.font = font
        self.fontWeight = fontWeight
    }

    var body: some View {
        HStack {
            Text(text.localized)
                .fontWeight(fontWeight).font(font)
                .lineLimit(nil).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

// MARK: SunView
private struct SunView: View {
    private let width = sunWidth

    var body: some View {
        ZStack {
            Circle().foregroundStyle(.yellow)
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

    var body: some View {
        Rectangle()
            .foregroundStyle(.yellow)
            .frame(width: width, height: width * 5)
            .cornerRadius(width / 3)
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
