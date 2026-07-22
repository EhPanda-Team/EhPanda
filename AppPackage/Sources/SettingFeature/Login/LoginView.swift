import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import Resources
import SFSafeSymbolsExt
import Sharing
import SwiftUI
import SystemNotification

struct LoginView: View {
    @Bindable private var store: StoreOf<LoginReducer>
    @SharedReader(.setting) private var setting: Setting

    @FocusState private var focusedField: LoginReducer.FocusedField?

    init(store: StoreOf<LoginReducer>) {
        self.store = store
    }

    // MARK: LoginView
    var body: some View {
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
            .containerRelativeFrame(.horizontal) { length, _ in length * 0.6 }

            Button {
                store.send(.login)
            } label: {
                Label(.RLocalizable.login, systemSymbol: .chevronForward)
                    .labelStyle(.iconOnly)
                    .padding()
                    .clipShape(.circle)
            }
            .overlay {
                ProgressView()
                    .animation(.default) {
                        $0.opacity(store.loginState == .loading ? 1 : 0)
                    }
            }
            .font(.title)
            .foregroundStyle(store.loginButtonColor)
            .disabled(store.loginButtonDisabled)
            .glassEffect(.regular.tint(.init(.systemGray6)).interactive(), in: .circle)
            .clipShape(.circle)
            .padding(.top, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Group {
                WaveForm(color: Color(.systemGray2).opacity(0.2), amplify: 100, isReversed: true)
                WaveForm(color: Color(.systemGray).opacity(0.2), amplify: 120, isReversed: false)
            }
            .visualEffect { content, proxy in
                content.offset(y: proxy.size.height * 0.3)
            }
            .drawingGroup()
        }
        .synchronize($store.focusedField, $focusedField)
        .sheet(item: $store.destination.webView, id: \.absoluteString) { url in
            WebView(url: url.wrappedValue) {
                store.send(.loginDone(.success(nil)))
            }
            .ignoresSafeArea(edges: .bottom)
            .privacyMask()
        }
        // The Cloudflare wall. It carries no explanatory chrome on purpose: an auto-passing
        // challenge is on screen for a second or two before the reducer dismisses it, and an
        // interactive one explains itself. Cancelling goes through the reducer rather than a bare
        // dismiss, because aborting the challenge also has to abort the login attempt behind it.
        .sheet(item: $store.destination.challenge, id: \.absoluteString) { url in
            NavigationStack {
                ChallengeWebView(url: url.wrappedValue) { clearance in
                    store.send(.challengeClearanceCaptured(clearance))
                }
                .ignoresSafeArea(edges: .bottom)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel, action: { store.send(.cancelChallenge) })
                    }
                }
            }
            .privacyMask()
        }
        .sheet(item: $store.destination.errorInfo) { errorInfo in
            ErrorInfoView(errorInfo: errorInfo.wrappedValue)
                .privacyMask()
        }
        .toast(
            $store.scope(\.$toast, action: \.toast),
            onErrorTap: { errorInfo in
                store.send(.presentErrorInfo(errorInfo))
            }
        )
        .onSubmit {
            switch focusedField {
            case .username:
                focusedField = .password
            default:
                focusedField = nil
                store.send(.login)
            }
        }
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
                Label(.website, systemSymbol: .globe)
            }
            .disabled(setting.bypassSNIFiltering)
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
            .autocorrectionDisabled(true)
            .keyboardType(isPassword ? .asciiCapable : .default)
            .padding(10)
            .glassEffect(.regular.tint(Color(.systemGray6)), in: .rect(cornerRadius: 8))
        }
    }
}

#Preview("Initial") {
    NavigationStack {
        LoginView(
            store: .init(initialState: .init(), reducer: LoginReducer.init)
        )
    }
}
