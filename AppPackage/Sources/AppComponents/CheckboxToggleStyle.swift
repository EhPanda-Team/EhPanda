import Resources
import SFSafeSymbols
public import SwiftUI

/// The age wall's checkbox card (UI-SPEC C-2): a card the width of its column whose whole surface toggles, with an
/// empty square that becomes the accent-filled `checkmark.square.fill` when ticked.
///
/// The glyph sits on the card colour, never on the grouped background, so the accent keeps its 3:1 non-text
/// contrast (UI-SPEC Color). At accessibility sizes the glyph moves above the sentence so the sentence keeps the
/// card's full width. VoiceOver reads one element: the sentence as its label, with the toggle trait and the
/// selected state carrying on and off. Ticking and unticking each play the selection haptic; the glyph's replace
/// effect is dropped under Reduce Motion.
public struct CheckboxToggleStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        CheckboxCard(configuration: configuration)
    }
}

private struct CheckboxCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let configuration: ToggleStyleConfiguration

    var body: some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 15))
                .contentShape(.rect(cornerRadius: 15))
        }
        .buttonStyle(.plain)
        .contentShape(.hoverEffect, .rect(cornerRadius: 15))
        .hoverEffect(.highlight)
        .sensoryFeedback(.selection, trigger: configuration.isOn)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(configuration.isOn ? [.isToggle, .isSelected] : .isToggle)
    }

    @ViewBuilder private var content: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                glyph
                sentence
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                glyph
                sentence
            }
        }
    }

    private var glyph: some View {
        Image(systemSymbol: configuration.isOn ? .checkmarkSquareFill : .square)
            .font(.title2)
            .imageScale(.large)
            .foregroundStyle(configuration.isOn ? Color.accentColor : Color.secondary)
            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
            .accessibilityHidden(true)
    }

    private var sentence: some View {
        configuration.label
            .font(.body)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Light, unticked") {
    @Previewable @State var isOn = false
    Toggle(isOn: $isOn) {
        Text(.RLocalizable.ageWallDeclaration)
    }
    .toggleStyle(CheckboxToggleStyle())
    .padding(24)
    .frame(maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
}

#Preview("Dark, ticked") {
    @Previewable @State var isOn = true
    Toggle(isOn: $isOn) {
        Text(.RLocalizable.ageWallDeclaration)
    }
    .toggleStyle(CheckboxToggleStyle())
    .padding(24)
    .frame(maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

#Preview("AX5") {
    @Previewable @State var isOn = false
    ScrollView {
        Toggle(isOn: $isOn) {
            Text(.RLocalizable.ageWallDeclaration)
        }
        .toggleStyle(CheckboxToggleStyle())
        .padding(24)
    }
    .background(Color(.systemGroupedBackground))
    .environment(\.dynamicTypeSize, .accessibility5)
}
