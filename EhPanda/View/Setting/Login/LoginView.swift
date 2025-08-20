//
//  LoginView.swift
//  EhPanda
//

import SwiftUI
import ComposableArchitecture

struct LoginView: View {
    @Bindable private var store: StoreOf<LoginReducer>
    private let bypassesSNIFiltering: Bool
    private let blurRadius: Double

    @FocusState private var focusedField: LoginReducer.FocusedField?

    init(store: StoreOf<LoginReducer>, bypassesSNIFiltering: Bool, blurRadius: Double) {
        self.store = store
        self.bypassesSNIFiltering = bypassesSNIFiltering
        self.blurRadius = blurRadius
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
                            focusedField: $focusedField, text: $store.username,
                            description: L10n.Localizable.LoginView.Title.username, isPassword: false
                        )
                        LoginTextField(
                            focusedField: $focusedField, text: $store.password,
                            description: L10n.Localizable.LoginView.Title.password, isPassword: true
                        )
                    }
                    .padding(.horizontal, proxy.size.width * 0.2)

                    Button {
                        store.send(.login)
                    } label: {
                        Image(systemSymbol: .chevronForwardCircleFill)
                    }
                    .overlay {
                        ProgressView()
                            .tint(nil)
                            .opacity(store.loginState == .loading ? 1 : 0)
                    }
                    .imageScale(.large)
                    .font(.largeTitle)
                    .foregroundColor(store.loginButtonColor)
                    .disabled(store.loginButtonDisabled).padding(.top, 30)
                }
            }
        }
        .synchronize($store.focusedField, $focusedField)
        .sheet(item: $store.route.sending(\.setNavigation).webView, id: \.absoluteString) { route in
            WebView(url: route.wrappedValue) {
                store.send(.loginDone(.success(nil)))
            }
            .autoBlur(radius: blurRadius)
        }
        .onSubmit {
            switch focusedField {
            case .username:
                focusedField = .password
            default:
                focusedField = nil
                store.send(.login)
            }
        }
        .animation(.default, value: store.loginState)
        .toolbar(content: toolbar)
        .navigationTitle(L10n.Localizable.LoginView.Title.login)
        .ignoresSafeArea()
    }
    // MARK: Toolbar
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                store.send(.setNavigation(.webView(Defaults.URL.webLogin)))
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
    private let focusedField: FocusState<LoginReducer.FocusedField?>.Binding
    @Binding private var text: String
    private let description: String
    private let isPassword: Bool

    private var backgroundColor: Color {
        colorScheme == .light ? Color(.systemGray6) : Color(.systemGray5)
    }

    init(
        focusedField: FocusState<LoginReducer.FocusedField?>.Binding,
        text: Binding<String>, description: String, isPassword: Bool
    ) {
        self.focusedField = focusedField
        _text = text
        self.description = description
        self.isPassword = isPassword
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(description).font(.caption).foregroundStyle(.secondary)
            Group {
                if isPassword {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .focused(focusedField.projectedValue, equals: isPassword ? .password : .username)
            .textContentType(isPassword ? .password : .username).submitLabel(isPassword ? .done : .next)
            .textInputAutocapitalization(.none).disableAutocorrection(true)
            .keyboardType(isPassword ? .asciiCapable : .default).padding(10)
            .background(backgroundColor.opacity(0.75).cornerRadius(8))
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LoginView(
                store: .init(initialState: .init(), reducer: LoginReducer.init),
                bypassesSNIFiltering: false,
                blurRadius: 0
            )
        }
    }
}
