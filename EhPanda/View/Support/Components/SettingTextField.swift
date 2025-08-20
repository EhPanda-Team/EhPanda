//
//  SettingTextField.swift
//  SettingTextField
//

import SwiftUI

struct SettingTextField: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding private var text: String
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

    init(
        text: Binding<String>, promptText: String? = nil, width: CGFloat? = 50,
        alignment: TextAlignment = .center, background: Color? = nil
    ) {
        _text = text
        self.promptText = promptText
        self.width = width
        self.alignment = alignment
        self.background = background
    }

    var body: some View {
        TextField("", text: $text, prompt: prompt).keyboardType(.numbersAndPunctuation)
            .textInputAutocapitalization(.none).multilineTextAlignment(alignment)
            .disableAutocorrection(true).background(color).frame(width: width).cornerRadius(5)
    }
}
