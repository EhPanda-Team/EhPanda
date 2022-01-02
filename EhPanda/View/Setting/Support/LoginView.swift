//
//  LoginView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/08/12.
//

import SwiftUI
import SFSafeSymbols
import ComposableArchitecture

struct LoginView: View {
    private let store: Store<LoginState, LoginAction>
    @ObservedObject private var viewStore: ViewStore<LoginState, LoginAction>
    private let bypassesSNIFiltering: Bool

    @FocusState private var focusedField: LoginFocusedField?

    init(store: Store<LoginState, LoginAction>, bypassesSNIFiltering: Bool) {
        self.store = store
        viewStore = ViewStore(store)
        self.bypassesSNIFiltering = bypassesSNIFiltering
    }

    // MARK: LoginView
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Group {
                    WaveForm(color: Color(.systemGray2).opacity(0.2), amplify: 100, isReversed: true)
                    WaveForm(color: Color(.systemGray).opacity(0.2), amplify: 120, isReversed: false)
                }
                .offset(y: proxy.size.height * 0.3).drawingGroup()
                VStack(spacing: 15) {
                    Group {
                        LoginTextField(
                            focusedField: $focusedField, text: viewStore.binding(\.$username),
                            description: "Username", isPassword: false
                        )
                        LoginTextField(
                            focusedField: $focusedField, text: viewStore.binding(\.$password),
                            description: "Password", isPassword: true
                        )
                    }
                    .padding(.horizontal, proxy.size.width * 0.2)
                    Button {
                        viewStore.send(.login)
                    } label: {
                        Image(systemSymbol: .chevronForwardCircleFill)
                    }
                    .overlay {
                        ProgressView().tint(nil).opacity(
                            viewStore.loginState == .loading ? 1 : 0
                        )
                    }
                    .imageScale(.large).font(.largeTitle)
                    .foregroundColor(viewStore.loginButtonColor)
                    .disabled(viewStore.loginButtonDisabled).padding(.top, 30)
                }
            }
        }
        .synchronize(viewStore.binding(\.$focusedField), $focusedField)
        .sheet(isPresented: viewStore.binding(\.$webViewSheetPresented)) {
            WebView(url: Defaults.URL.login)
//                    .blur(radius: environment.blurRadius)
//                    .allowsHitTesting(environment.isAppUnlocked)
        }
        .onSubmit {
            switch focusedField {
            case .username:
                focusedField = .password
            case .password:
                focusedField = nil
                viewStore.send(.login)
            default:
                break
            }
        }
        .toolbar(content: toolbar)
        .navigationTitle("Login")
        .ignoresSafeArea()
    }
    // MARK: Toolbar
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                viewStore.send(.setWebViewSheet(true))
            } label: {
                Image(systemSymbol: .globe)
            }
            .disabled(bypassesSNIFiltering)
        }
    }
}

// MARK: LoginTextField
private struct LoginTextField: View {
    @Environment(\.colorScheme) private var colorScheme
    private let focusedField: FocusState<LoginFocusedField?>.Binding
    @Binding private var text: String
    private let description: String
    private let isPassword: Bool

    private var backgroundColor: Color {
        colorScheme == .light ? Color(.systemGray6) : Color(.systemGray5)
    }

    init(
        focusedField: FocusState<LoginFocusedField?>.Binding,
        text: Binding<String>, description: String, isPassword: Bool
    ) {
        self.focusedField = focusedField
        _text = text
        self.description = description
        self.isPassword = isPassword
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(description.localized).font(.caption).foregroundStyle(.secondary)
            Group {
                if isPassword {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .focused(focusedField.projectedValue, equals: isPassword ? .password : .username)
            .textContentType(isPassword ? .password : .username).submitLabel(isPassword ? .done : .next)
            .textInputAutocapitalization(.none).disableAutocorrection(true).keyboardType(.asciiCapable)
            .padding(10).background(backgroundColor.opacity(0.75).cornerRadius(8))
        }
    }
}

// MARK: Definition
enum LoginFocusedField {
    case username
    case password
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LoginView(
                store: Store<LoginState, LoginAction>(
                    initialState: LoginState(),
                    reducer: loginReducer,
                    environment: LoginEnvironment(
                        hapticClient: .live,
                        cookiesClient: .live
                    )
                ),
                bypassesSNIFiltering: false
            )
        }
    }
}
