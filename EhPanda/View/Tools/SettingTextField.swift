//
//  SettingTextField.swift
//  SettingTextField
//
//  Created by 荒木辰造 on 2021/08/07.
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
        if let background = background {
            return background
        }
        if colorScheme == .light {
            return Color(.systemGray6)
        } else {
            return Color(.systemGray3)
        }
    }
    private var prompt: Text? {
        if let text = promptText {
            return Text(text)
        } else {
            return nil
        }
    }

    init(
        text: Binding<String>,
        promptText: String? = nil,
        width: CGFloat? = 50,
        alignment: TextAlignment = .center,
        background: Color? = nil
    ) {
        _text = text
        self.promptText = promptText
        self.width = width
        self.alignment = alignment
        self.background = background
    }

    var body: some View {
        TextField("", text: $text, prompt: prompt)
            .keyboardType(.numbersAndPunctuation)
            .multilineTextAlignment(alignment)
            .disableAutocorrection(true)
            .autocapitalization(.none)
            .background(color)
            .frame(width: width)
            .cornerRadius(5)
    }
}
