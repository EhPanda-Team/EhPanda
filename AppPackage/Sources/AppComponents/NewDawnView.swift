public import AppModels
import AppTools
import Resources
public import SwiftUI

public struct NewDawnView: View {
    @Environment(\.colorScheme) private var colorScheme
    private let greeting: Greeting

    /// The height the greeting is centred in, and the point past which it starts to scroll.
    @State private var containerHeight: CGFloat = 0

    /// Breathing room above the greeting once it is long enough to scroll. It is scaled because the
    /// type size is precisely what drives the first line against the container's top edge, and the
    /// value is the one that clears the sun: the disc's visible bottom sits about 170pt below the
    /// container's top edge, and at the largest sizes this grows to just past that, so the title stops
    /// being drawn across it rather than merely being nudged off its brightest part.
    @ScaledMetric private var scrollTopMargin: CGFloat = 50

    private var gradientColors: [Color] {
        if colorScheme == .light {
            return [Color(uiColor: .systemTeal), Color(uiColor: .systemIndigo)]
        } else {
            return [Color(uiColor: .systemGray5), Color(uiColor: .systemGray2)]
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
                // Form sheets can report compact width even when there is room for a smaller sun.
                let sunWidth = size.width * (size.width >= 500 ? 0.5 : 0.6)
                let sunCenter = CGPoint(x: size.width - sunWidth / 2 + offset, y: sunWidth / 2 - offset)

                // Only the body of the sun or moon, in light and dark: no rays around it (owner decision C5).
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: sunCenter.x - sunWidth / 2, y: sunCenter.y - sunWidth / 2,
                        width: sunWidth, height: sunWidth
                    )),
                    with: .color(.yellow)
                )
            }
        }
        // The backdrop is decoration, so it bleeds to every edge of the sheet.
        .ignoresSafeArea()
        .overlay {
            // The greeting is a fixed slab of prose with no way to shorten it, and in a large window
            // it is presented in a form sheet, so at accessibility sizes it outgrows whatever it is
            // given. A scroll container is the remedy: the text keeps its natural height and the
            // reader reaches the rest, rather than the first and last lines being sliced by the
            // container's edges with nowhere to scroll to.
            //
            // `minHeight` is what preserves the designed appearance. The greeting is centred in its
            // container, and a bare `ScrollView` would pin it to the top at every size; giving the
            // content the container's height as a *floor* keeps it centred while it fits and lets it
            // grow past that once it doesn't. `basedOnSize` then withholds the bounce until there is
            // something to scroll to, so at the default size this reads exactly as it did before.
            //
            // The floor is that height *less* the top content margin, so the two together still come
            // to exactly the container's height. Were the floor left whole, the margin would push the
            // content past the container at every size and the greeting would always scroll.
            //
            // The greeting is centred between the top margin and the bottom safe area, so its last line,
            // the reward line, is never under the home indicator (owner decision C5). Only the top edge
            // is ignored: the scroll view insets its content for the bottom safe area, while the
            // backdrop above still bleeds to every edge. It is prose, so sideways it stays inside the
            // safe area too and no line runs beneath a sensor housing or a vertical bar.
            ScrollView {
                VStack(spacing: 50) {
                    VStack(spacing: 10) {
                        TextView(text: .first, font: .largeTitle)
                        TextView(text: .second, font: .title2)
                    }
                    TextView(text: greeting.gainContent ?? "", font: .title3, fontWeight: .bold)
                }
                .padding()
                .frame(maxWidth: .infinity, minHeight: max(0, containerHeight - scrollTopMargin))
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .contentMargins(.top, scrollTopMargin, for: .scrollContent)
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { containerHeight = $0 }
            .ignoresSafeArea(edges: .top)
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

    // Resource overload for the static greeting lines; the `String` init above remains for the
    // dynamic gain content.
    init(text: LocalizedStringResource, font: Font, fontWeight: Font.Weight = .bold) {
        self.init(text: String(localized: text), font: font, fontWeight: fontWeight)
    }

    var body: some View {
        Text(text)
            .fontWeight(fontWeight)
            .font(font)
            .lineLimit(nil)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("New dawn") {
    NewDawnView(greeting: .mock)
}
