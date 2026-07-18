import SwiftUI
import AppModels
import Resources
import Dependencies
import DeviceClient

public struct NewDawnView: View {
    @Dependency(\.deviceClient) private var deviceClient
    @Environment(\.colorScheme) private var colorScheme
    private let greeting: Greeting

    private var gradientColors: [Color] {
        if colorScheme == .light {
            return [Color(.systemTeal), Color(.systemIndigo)]
        } else {
            return [Color(.systemGray5), Color(.systemGray2)]
        }
    }

    public init(greeting: Greeting) {
        self.greeting = greeting
    }

    // MARK: NewDawnView
    public var body: some View {
        LinearGradient(
            gradient: Gradient(colors: gradientColors),
            startPoint: .top, endPoint: .bottom
        )
        .overlay {
            Canvas { context, size in
                let offset = size.width * 0.2
                let sunWidth = size.width * (deviceClient.deviceType() == .pad ? 0.5 : 0.6)
                let sunCenter = CGPoint(x: size.width - sunWidth / 2 + offset, y: sunWidth / 2 - offset)

                context.fill(
                    Path(ellipseIn: CGRect(
                        x: sunCenter.x - sunWidth / 2, y: sunCenter.y - sunWidth / 2,
                        width: sunWidth, height: sunWidth
                    )),
                    with: .color(.yellow)
                )

                if colorScheme == .dark {
                    let beamWidth = sunWidth / 10
                    for index in 0..<8 {
                        var beamContext = context
                        beamContext.translateBy(x: sunCenter.x, y: sunCenter.y)
                        beamContext.rotate(by: .degrees(Double(index) * 45))
                        beamContext.translateBy(x: 0, y: -sunWidth / 1.2)
                        beamContext.fill(
                            Path(
                                roundedRect: CGRect(
                                    x: -beamWidth / 2, y: -beamWidth * 2.5,
                                    width: beamWidth, height: beamWidth * 5
                                ),
                                cornerRadius: beamWidth / 3
                            ),
                            with: .color(.yellow)
                        )
                    }
                }
            }
        }
        .overlay {
            VStack(spacing: 50) {
                VStack(spacing: 10) {
                    TextView(text: .first, font: .largeTitle)
                    TextView(text: .second, font: .title2)
                }
                TextView(text: greeting.gainContent ?? "", font: .title3, fontWeight: .bold)
            }
            .padding()
        }
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

    // Resource overload for the static greeting lines; the `String` init above remains for the
    // dynamic gain content.
    init(text: LocalizedStringResource, font: Font, fontWeight: Font.Weight = .bold) {
        self.init(text: String(localized: text), font: font, fontWeight: fontWeight)
    }

    var body: some View {
        Text(text)
            .fontWeight(fontWeight).font(font)
            .lineLimit(nil).foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("New dawn") {
    NewDawnView(greeting: .mock)
}
