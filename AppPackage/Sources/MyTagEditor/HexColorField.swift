public import AppModels
public import SwiftUI

/// A colour as the site keeps it, for a tag and for a tag set's default: a hex field and the system colour well, 12
/// pt apart at the trailing side (port of PR 462 item 10, design approved 2026-11-22).
///
/// The field shows `color` as `#RRGGBB`, or nothing with `prompt` (else `#RRGGBB`) when there is none. It takes six
/// hex digits with or without `#`, in any case, spaces around them ignored: the well follows as soon as the text is a
/// valid code, and submit writes the code back in upper case; submitting an empty field clears the colour, and an
/// invalid code returns to the last valid one. Picking in the well (`well`, no opacity: the site keeps `#rrggbb`)
/// writes its colour.
///
/// The field keeps its text itself, unless the host passes it (`text`) to tell while it is not a code (G-2 of quick
/// 261126-wzg, `isInvalidCode(_:)`).
public struct HexColorField: View {
    @ScaledMetric(relativeTo: .body) private var fieldWidth = 120.0
    /// The text while the host does not keep it.
    @State private var ownText = ""
    /// The host's text, when the host keeps it.
    private let hostText: Binding<String>?
    @Binding private var color: SiteColor?
    @Binding private var well: Color
    private let title: LocalizedStringResource
    private let prompt: String?

    /// A field that keeps its text itself.
    public init(_ title: LocalizedStringResource, color: Binding<SiteColor?>, well: Binding<Color>, prompt: String?) {
        self.init(title, hostText: nil, color: color, well: well, prompt: prompt)
    }

    /// A field whose text the host keeps, so the host can tell while it is not a code (G-2 of quick 261126-wzg).
    public init(
        _ title: LocalizedStringResource,
        text: Binding<String>,
        color: Binding<SiteColor?>,
        well: Binding<Color>,
        prompt: String?
    ) {
        self.init(title, hostText: text, color: color, well: well, prompt: prompt)
    }

    private init(
        _ title: LocalizedStringResource,
        hostText: Binding<String>?,
        color: Binding<SiteColor?>,
        well: Binding<Color>,
        prompt: String?
    ) {
        self.title = title
        self.hostText = hostText
        _color = color
        _well = well
        self.prompt = prompt
    }

    /// Whether `text` is neither empty nor a code (G-2 of quick 261126-wzg). Spaces alone count as empty, as
    /// submitting them clears the colour.
    public nonisolated static func isInvalidCode(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty && code(in: text) == nil
    }

    /// The colour `text` holds as a code, spaces around it ignored as submit ignores them; nil for anything else.
    private nonisolated static func code(in text: String) -> SiteColor? {
        SiteColor(hex: text.trimmingCharacters(in: .whitespaces))
    }

    /// The field's text: the host's when it keeps it, else the field's own.
    private var text: Binding<String> {
        hostText ?? $ownText
    }

    public var body: some View {
        LabeledContent {
            HStack(spacing: 12) {
                TextField(text: text, prompt: promptText) {
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
            if Self.code(in: text.wrappedValue) != newValue {
                text.wrappedValue = newValue?.hex ?? ""
            }
        }
        .onChange(of: text.wrappedValue) { _, newValue in
            if let typed = Self.code(in: newValue), typed != color {
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
        let trimmed = text.wrappedValue.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            color = nil
        } else if let typed = SiteColor(hex: trimmed) {
            color = typed
            text.wrappedValue = typed.hex
        } else {
            text.wrappedValue = color?.hex ?? ""
        }
    }
}
