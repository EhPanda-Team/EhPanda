//
//  LoginView.swift
//  EhPanda
//
//  Created by 荒木辰造 on 2021/08/12.
//

import SwiftUI

struct LoginView: View {
    @State var username = ""
    @State var password = ""

    private var isLoginButtonDisabled: Bool {
        username.isEmpty || password.isEmpty
    }
    private var loginButtonColor: Color {
        isLoginButtonDisabled
        ? .primary.opacity(0.25)
        : .primary.opacity(0.75)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Group {
                    WaveForm(
                        color: Color(.systemGray2).opacity(0.2),
                        amplify: 100, isReversed: true
                    )
                    WaveForm(
                        color: Color(.systemGray).opacity(0.2),
                        amplify: 120, isReversed: false
                    )
                }
                .offset(y: proxy.size.height * 0.3)
                VStack(spacing: 15) {
                    LoginTextField(text: $username, description: "Username", isPassword: false)
                        .padding(.horizontal, proxy.size.width * 0.2)
                    LoginTextField(text: $password, description: "Password", isPassword: true)
                        .padding(.horizontal, proxy.size.width * 0.2)
                    Button(action: login) {
                        Image(systemName: "chevron.forward.circle.fill")
                    }
                    .imageScale(.large).font(.largeTitle)
                    .foregroundColor(loginButtonColor)
                    .disabled(isLoginButtonDisabled)
                    .padding(.top, 30)
                }
            }
        }
        .navigationTitle("Login")
        .ignoresSafeArea()
    }

    private func login() {

    }
}

private struct LoginTextField: View {
    @Binding private var text: String
    private let description: String
    private let isPassword: Bool

    init(
        text: Binding<String>,
        description: String,
        isPassword: Bool
    ) {
        _text = text
        self.description = description
        self.isPassword = isPassword
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(description.localized()).font(.caption)
                .foregroundStyle(.secondary)
            Group {
                if isPassword {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .textContentType(isPassword ? .password : .username)
            .textInputAutocapitalization(.none)
            .disableAutocorrection(true)
            .keyboardType(.asciiCapable)
            .autocapitalization(.none)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(
                Color(.systemGray6)
                    .opacity(0.75)
                    .cornerRadius(8)
            )
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LoginView()
        }
    }
}
