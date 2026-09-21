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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable private var store: StoreOf<LoginReducer>
    @SharedReader(.setting) private var setting: Setting

    @FocusState private var focusedField: LoginReducer.FocusedField?

    init(store: StoreOf<LoginReducer>) {
        self.store = store
    }

    /// The waves bleed past every edge and the form is centred against that whole window rather
    /// than against the band the navigation bar leaves below itself, which is what ignoring the
    /// safe area outright buys: waves and form share one axis, and the design is built on it.
    ///
    /// It holds only while the form is short enough to clear the large title. At accessibility
    /// sizes the title's band and the form grow into the same space from opposite ends and the
    /// bottom of `Login` is painted straight through the `Username` label — two strings that are
    /// both present and neither readable. Above the default size the screen therefore stops
    /// ignoring the safe area, so the navigation bar's inset, which is exactly as tall as the
    /// title it has to draw, pushes the form down instead of under it; the keyboard inset returns
    /// with it, which is what lets a focused field be scrolled clear of the keyboard.
    ///
    /// Only this region set changes across the threshold — never the view structure — so at and
    /// below `.large` the screen renders exactly as designed (D-15).
    private var ignoredSafeAreaRegions: SafeAreaRegions {
        dynamicTypeSize <= .large ? .all : []
    }

    // MARK: LoginView
    var body: some View {
        formLayer
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background {
                Group {
                    WaveForm(color: Color(.systemGray2).opacity(0.2), amplify: 100, isReversed: true)
                    WaveForm(color: Color(.systemGray).opacity(0.2), amplify: 120, isReversed: false)
                }
                .visualEffect { content, proxy in
                    content.offset(y: proxy.size.height * 0.3)
                }
                .drawingGroup()
                // The waves keep bleeding to the window's edges at every size: the form is what
                // steps back below the navigation bar, the backdrop it sits on is not.
                .ignoresSafeArea()
            }
            .synchronize($store.focusedField, $focusedField)
            .sheet(item: $store.destination.webView, id: \.absoluteString) { url in
                WebView(url: url.wrappedValue) {
                    store.send(.loginDone(.success(nil)))
                }
                .ignoresSafeArea(edges: .bottom)
                .scrollEdgeEffectStyle(.soft, for: .top)
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
                    .scrollEdgeEffectStyle(.soft, for: .top)
                    // The page runs edge to edge under a background-less bar, so the cancel control
                    // floats on its own glass over the challenge instead of sitting on an opaque strip.
                    // Cloudflare's interstitial is vertically centred with generous padding, so nothing
                    // it renders ends up beneath the control.
                    .ignoresSafeArea()
                    .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
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
            .ignoresSafeArea(ignoredSafeAreaRegions, edges: .all)
    }

    /// The column keeps its centred, unscrolled shape while the height it is offered can hold it,
    /// and scrolls once it cannot, so growing text lengthens the page instead of clipping its
    /// tail. Both candidates render the very same `form`; the scrolling one only adds the margins
    /// that keep the first field and the button off the bar and the home indicator.
    private var formLayer: some View {
        ViewThatFits(in: .vertical) {
            form
            ScrollView(.vertical) {
                form
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            // The 30 pt the button already puts between itself and the fields, so a scrolled form
            // opens and closes on the same rhythm it keeps inside.
            .contentMargins(.vertical, 30, for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxHeight: .infinity)
    }

    private var form: some View {
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
                        $0.visible(store.loginState == .loading)
                    }
            }
            .font(.title)
            .foregroundStyle(store.loginButtonColor)
            .disabled(store.loginButtonDisabled)
            .glassEffect(.regular.tint(.init(.systemGray6)).interactive(), in: .circle)
            .clipShape(.circle)
            .padding(.top, 30)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Toolbar
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
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
                .accessibilityHidden(true)
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

#Preview("Accessibility 5, compact width", traits: .fixedLayout(width: 393, height: 852)) {
    NavigationStack {
        LoginView(
            store: .init(initialState: .init(), reducer: LoginReducer.init)
        )
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Accessibility 5, regular width", traits: .fixedLayout(width: 744, height: 1133)) {
    NavigationStack {
        LoginView(
            store: .init(initialState: .init(), reducer: LoginReducer.init)
        )
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
