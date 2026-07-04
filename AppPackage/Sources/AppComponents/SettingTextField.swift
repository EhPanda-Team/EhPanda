import SwiftUI

public struct SettingTextField: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding private var text: String
    private let title: LocalizedStringResource
    private let promptText: String?
    private let width: CGFloat?
    private let alignment: TextAlignment
    private let background: Color?

    private var color: Color {
        if let background = background { return background }
        return colorScheme == .light ? Color(.systemGray6) : Color(.systemGray3)
    }
    private var prompt: Text? {
        guard let text = promptText else { return nil }
        return Text(text)
    }

    public init(
        text: Binding<String>, title: LocalizedStringResource,
        promptText: String? = nil, width: CGFloat? = 50,
        alignment: TextAlignment = .center, background: Color? = nil
    ) {
        _text = text
        self.title = title
        self.promptText = promptText
        self.width = width
        self.alignment = alignment
        self.background = background
    }

    public var body: some View {
        // A non-empty, localized label keeps VoiceOver informative; `.labelsHidden()` keeps the
        // field's appearance unchanged (only the prompt shows). Avoids an empty `""` title literal.
        TextField(text: $text, prompt: prompt) {
            Text(title)
        }
        .labelsHidden()
        .keyboardType(.numbersAndPunctuation)
        .textInputAutocapitalization(.none).multilineTextAlignment(alignment)
        .disableAutocorrection(true).background(color).frame(width: width).cornerRadius(5)
    }
}
