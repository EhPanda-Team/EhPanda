//
//  LoginView.swift
//  EhPanda
//
//  Created by 荒木辰造 on 2021/08/12.
//

import SwiftUI

private enum FocusedField {
    case username
    case password
}

struct LoginView: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismissAction

    @FocusState private var focusedState: FocusedField?
    @State var isLoggingIn = false
    @State var username = ""
    @State var password = ""

    private var isLoginButtonDisabled: Bool {
        username.isEmpty || password.isEmpty
    }
    private var loginButtonColor: Color {
        guard !isLoggingIn else { return .clear }
        return isLoginButtonDisabled
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
                    Group {
                        LoginTextField(
                            focusedState: $focusedState, text: $username,
                            description: "Username", isPassword: false
                        )
                        LoginTextField(
                            focusedState: $focusedState, text: $password,
                            description: "Password", isPassword: true
                        )
                    }
                    .padding(.horizontal, proxy.size.width * 0.2)
                    Button(action: login) {
                        Image(systemName: "chevron.forward.circle.fill")
                    }
                    .overlay { ProgressView().opacity(isLoggingIn ? 1 : 0) }
                    .imageScale(.large).font(.largeTitle)
                    .foregroundColor(loginButtonColor)
                    .disabled(isLoginButtonDisabled)
                    .padding(.top, 30)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: toggleWebLogin) {
                    Image(systemName: "globe")
                }
                .disabled(setting.bypassesSNIFiltering)
            }
        }
        .onSubmit {
            switch focusedState {
            case .username:
                focusedState = .password
            case .password:
                focusedState = nil
                login()
            default:
                break
            }
        }
        .navigationTitle("Login")
        .ignoresSafeArea()
    }

    private func login() {
        guard !isLoginButtonDisabled || isLoggingIn else { return }
        withAnimation { isLoggingIn = true }
        impactFeedback(style: .soft)

        let token = SubscriptionToken()
        LoginRequest(username: username, password: password)
            .publisher.receive(on: DispatchQueue.main)
            .sink { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { isLoggingIn = false }
                    guard didLogin else {
                        notificFeedback(style: .error)
                        return
                    }
                    notificFeedback(style: .success)
                    dismissAction.callAsFunction()
                    store.dispatch(.fetchFrontpageItems)
                    store.dispatch(.fetchUserInfo)
                    store.dispatch(.verifyProfile)
                }
                token.unseal()
            } receiveValue: { _ in }
            .seal(in: token)
    }
    private func toggleWebLogin() {
        store.dispatch(.toggleSettingViewSheet(state: .webviewLogin))
    }
}

private struct LoginTextField: View {
    private let focusedState: FocusState
                <FocusedField?>.Binding
    @Binding private var text: String
    private let description: String
    private let isPassword: Bool

    init(
        focusedState: FocusState
        <FocusedField?>.Binding,
        text: Binding<String>,
        description: String,
        isPassword: Bool
    ) {
        self.focusedState = focusedState
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
            .focused(
                focusedState.projectedValue,
                equals: isPassword ? .password : .username
            )
            .textContentType(isPassword ? .password : .username)
            .submitLabel(isPassword ? .done : .next)
            .textInputAutocapitalization(.none)
            .disableAutocorrection(true)
            .keyboardType(.asciiCapable)
            .autocapitalization(.none)
            .padding(10)
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
