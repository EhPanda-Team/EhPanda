import AppTools
import SwiftUI
import Sharing
import AppModels
import Resources
import ComposableArchitecture
import AppComponents

struct LoginView: View {
    @Bindable private var store: StoreOf<LoginReducer>
    @SharedReader(.setting) private var setting: Setting
    private let blurRadius: Double

    @FocusState private var focusedField: LoginReducer.FocusedField?

    init(store: StoreOf<LoginReducer>, blurRadius: Double) {
        self.store = store
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
                .offset(y: proxy.size.height * 0.3)
                .drawingGroup()

                VStack(spacing: 15) {
                    Group {
                        LoginTextField(
                            focusedField: $focusedField,
                            text: $store.username,
                            description: .username,
                            isPassword: false
                        )
                        LoginTextField(
                            focusedField: $focusedField,
                            text: $store.password,
                            description: .password,
                            isPassword: true
                        )
                    }
                    .padding(.horizontal, proxy.size.width * 0.2)

                    Button {
                        store.send(.login)
                    } label: {
                        Image(systemSymbol: .chevronForward)
                            .padding()
                            .clipShape(.circle)
                    }
                    .overlay {
                        ProgressView()
                            .tint(nil)
                            .opacity(store.loginState == .loading ? 1 : 0)
                    }
                    .font(.title)
                    .foregroundStyle(store.loginButtonColor)
                    .disabled(store.loginButtonDisabled)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .clipShape(.circle)
                    .padding(.top, 30)
                }
            }
        }
        .synchronize($store.focusedField, $focusedField)
        .sheet(item: $store.destination.webView, id: \.absoluteString) { url in
            WebView(url: url.wrappedValue) {
                store.send(.loginDone(.success(nil)))
            }
            .ignoresSafeArea(edges: .bottom)
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
        .navigationTitle(.RLocalizable.login)
        .ignoresSafeArea()
    }
    // MARK: Toolbar
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                store.send(.presentWebView(Defaults.URL.webLogin))
            } label: {
                Image(systemSymbol: .globe)
            }
            .disabled(setting.bypassesSNIFiltering)
        }
    }
}

// MARK: LoginTextField
private struct LoginTextField: View {
    @Environment(\.colorScheme) private var colorScheme
    private let focusedField: FocusState<LoginReducer.FocusedField?>.Binding
    @Binding private var text: String
    private let description: LocalizedStringResource
    private let isPassword: Bool

    init(
        focusedField: FocusState<LoginReducer.FocusedField?>.Binding,
        text: Binding<String>, description: LocalizedStringResource, isPassword: Bool
    ) {
        self.focusedField = focusedField
        _text = text
        self.description = description
        self.isPassword = isPassword
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)

            Group {
                if isPassword {
                    SecureField(description, text: $text)
                } else {
                    TextField(description, text: $text)
                }
            }
            .labelsHidden()
            .focused(focusedField.projectedValue, equals: isPassword ? .password : .username)
            .textContentType(isPassword ? .password : .username)
            .submitLabel(isPassword ? .done : .next)
            .textInputAutocapitalization(.none)
            .disableAutocorrection(true)
            .keyboardType(isPassword ? .asciiCapable : .default)
            .padding(10)
            .glassEffect(.regular.tint(Color(.systemGray5)), in: .rect(cornerRadius: 8))
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LoginView(
                store: .init(initialState: .init(), reducer: LoginReducer.init),
                blurRadius: 0
            )
        }
    }
}
