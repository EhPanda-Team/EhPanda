import Resources
import SFSafeSymbols
public import SwiftUI

/// One option of a single choice, drawn as a card (UI-SPEC C-3): a radio glyph, the option's name and its
/// description, the whole card one button.
///
/// Every card has the same size rules, type and colour; the accent appears only on the selected card, as the filled
/// radio and a 2pt stroke, and the glyph always sits on the card colour so the accent keeps its contrast. The radio's
/// centre sits on the middle of the capital letters of the name's first line, the headline font's cap height at the
/// current text size (UI-SPEC C-3, rev 1.4); the row stays on the first text baseline and the radio moves its own
/// baseline guide. The radio is two fixed layers, the grey ring and the accent disc with its check, and a pick
/// only changes their opacity; it is not one symbol swapped and recoloured, which drew the old symbol in the new
/// colour for the length of a replace effect.
///
/// An optional `label` (the analytics choice's "Recommended" on Basic, D-06f) is a neutral grey capsule after the
/// name, which drops under the name once the two no longer fit one line; it never takes the accent and looks the
/// same whether the card is selected or not. VoiceOver reads the card as one button, name, label and description in
/// that order, with the selected state as a trait. At accessibility sizes the radio sits above the text, as on the
/// age wall's checkbox; the radio's cross-fade is dropped under Reduce Motion.
public struct ChoiceCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let name: LocalizedStringResource
    private let description: LocalizedStringResource
    private let label: LocalizedStringResource?
    private let isSelected: Bool
    private let action: () -> Void

    public init(
        _ name: LocalizedStringResource,
        description: LocalizedStringResource,
        label: LocalizedStringResource? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.name = name
        self.description = description
        self.label = label
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 15))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 15)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                    }
                }
                .contentShape(.rect(cornerRadius: 15))
        }
        .buttonStyle(.plain)
        .contentShape(.hoverEffect, .rect(cornerRadius: 15))
        .hoverEffect(.highlight)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder private var content: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                radio
                text
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                radio
                    .firstLineCapCentered(.headline)
                text
            }
        }
    }

    private var radio: some View {
        ZStack {
            Image(systemSymbol: .circle)
                .foregroundStyle(Color.secondary)
                .opacity(isSelected ? 0 : 1)
            Image(systemSymbol: .checkmarkCircleFill)
                .foregroundStyle(Color.accentColor)
                .opacity(isSelected ? 1 : 0)
        }
        .font(.title2)
        .imageScale(.large)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isSelected)
        .accessibilityHidden(true)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 4) {
            nameRow
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var nameRow: some View {
        if let label {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    nameText
                    capsule(label)
                }
                VStack(alignment: .leading, spacing: 4) {
                    nameText
                    capsule(label)
                }
            }
        } else {
            nameText
        }
    }

    private var nameText: some View {
        Text(name)
            .font(.headline)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
    }

    private func capsule(_ label: LocalizedStringResource) -> some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color(.tertiarySystemFill)))
    }
}

private struct ChoiceCardPreviewList: View {
    @State var selection: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ChoiceCard(
                    .RLocalizable.consentLevelMinimal,
                    description: .RLocalizable.consentLevelMinimalDescription,
                    isSelected: selection == 0
                ) { selection = 0 }
                ChoiceCard(
                    .RLocalizable.consentLevelBasic,
                    description: .RLocalizable.consentLevelBasicDescription,
                    label: .RLocalizable.consentLevelRecommended,
                    isSelected: selection == 1
                ) { selection = 1 }
                ChoiceCard(
                    .RLocalizable.consentLevelFull,
                    description: .RLocalizable.consentLevelFullDescription,
                    isSelected: selection == 2
                ) { selection = 2 }
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Light, none selected") {
    ChoiceCardPreviewList(selection: nil)
}

#Preview("Dark, Basic selected") {
    ChoiceCardPreviewList(selection: 1)
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    ChoiceCardPreviewList(selection: 2)
        .environment(\.dynamicTypeSize, .accessibility5)
}
