public import AppModels
public import SwiftUI

/// A colour as the site keeps it, for a tag and for a tag set's default: a hex field and the system colour well, 12
/// pt apart at the trailing side (port of PR 462 item 10, design approved 2026-11-22).
///
/// The field shows `color` as `#RRGGBB`, or nothing with `prompt` (else `#RRGGBB`) when there is none. It takes six
/// hex digits with or without `#`, in any case: the well follows as soon as the text is a valid code, and submit
/// writes the code back in upper case; submitting an empty field clears the colour, and an invalid code returns to
/// the last valid one. Picking in the well (`well`, no opacity: the site keeps `#rrggbb`) writes its colour.
public struct HexColorField: View {
    @ScaledMetric(relativeTo: .body) private var fieldWidth = 120.0
    @State private var text = ""
    @Binding private var color: SiteColor?
    @Binding private var well: Color
    private let title: LocalizedStringResource
    private let prompt: String?

    public init(_ title: LocalizedStringResource, color: Binding<SiteColor?>, well: Binding<Color>, prompt: String?) {
        self.title = title
        _color = color
        _well = well
        self.prompt = prompt
    }

    public var body: some View {
        LabeledContent {
            HStack(spacing: 12) {
                TextField(text: $text, prompt: promptText) {
                    Text(.myTagsHexColor)
                }
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.done)
                .accessibilityLabel(.myTagsHexColor)
                .frame(width: fieldWidth)
                .onSubmit {
                    submit()
                }
                ColorPicker(selection: $well, supportsOpacity: false) {
                    Text(title)
                }
                .labelsHidden()
            }
        } label: {
            Text(title)
        }
        // The field follows a colour set elsewhere (the well, Use Default Color), and leaves a code being typed alone.
        .onChange(of: color, initial: true) { _, newValue in
            if SiteColor(hex: text) != newValue {
                text = newValue?.hex ?? ""
            }
        }
        .onChange(of: text) { _, newValue in
            if let typed = SiteColor(hex: newValue), typed != color {
                color = typed
            }
        }
    }

    private var promptText: Text {
        if let prompt {
            return Text(verbatim: prompt)
        }
        return Text(.myTagsHexPrompt)
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            color = nil
        } else if let typed = SiteColor(hex: trimmed) {
            color = typed
            text = typed.hex
        } else {
            text = color?.hex ?? ""
        }
    }
}
