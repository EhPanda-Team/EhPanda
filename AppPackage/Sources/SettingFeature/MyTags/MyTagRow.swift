import AppModels
import Resources
import SwiftUI

/// A tag's row on My Tags (port of PR 462 item 10, design approved 2026-11-22). Line 1: the weight, signed, in a
/// capsule at least 36 wide, then the tag as the site keeps it, `namespace:tag`. Line 2: a dot in the tag's colour
/// (its own, else its set's; an empty ring with neither), the colour's code and a watched or hidden tag's state. No
/// symbol. One VoiceOver element: the tag, its state, its weight and its colour.
struct MyTagRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var dotSize = 12.0
    let tag: MyTag
    let tagSetColor: SiteColor?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: isWrapping ? .top : .center, spacing: 8) {
                Text(weightText)
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 1)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 36)
                    .background(.fill.tertiary, in: .capsule)
                Text(tag.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(isWrapping ? 3 : 1)
            }
            HStack(spacing: 6) {
                dot
                Text(detailText)
            }
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(.myTagsRowHint)
    }

    /// Above Large the tag wraps, up to three lines, as a tag chip does.
    private var isWrapping: Bool { dynamicTypeSize > .large }

    private var color: SiteColor? { tag.color ?? tagSetColor }

    private var weightText: String {
        tag.weight.formatted(.number.sign(strategy: .always(includingZero: false)))
    }

    private var stateText: String? {
        switch tag.kind {
        case .flagged: nil
        case .watched: String(localized: .RLocalizable.myTagsStateWatched)
        case .hidden: String(localized: .RLocalizable.myTagsStateHidden)
        }
    }

    private var colorText: String {
        color?.hex ?? String(localized: .myTagsNoColor)
    }

    private var detailText: String {
        guard let stateText else { return colorText }
        return String(localized: .myTagsColorState(colorText, stateText))
    }

    private var accessibilityText: String {
        let colorValue = color.map({ String(localized: .myTagsColorValue($0.hex)) })
        let parts = [
            tag.name,
            stateText,
            String(localized: .myTagsWeightValue(weightText)),
            colorValue ?? String(localized: .myTagsNoColor)
        ]
        return parts.compactMap(\.self).formatted(.list(type: .and, width: .narrow))
    }

    @ContentBuilder private var dot: some View {
        if let color {
            Circle()
                .fill(color.color)
                .overlay {
                    Circle().strokeBorder(.separator, lineWidth: 1)
                }
                .frame(width: dotSize, height: dotSize)
                .accessibilityHidden(true)
        } else {
            Circle()
                .strokeBorder(.tertiary, lineWidth: 1)
                .frame(width: dotSize, height: dotSize)
                .accessibilityHidden(true)
        }
    }
}
