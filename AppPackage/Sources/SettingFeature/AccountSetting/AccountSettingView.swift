import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import CookieClient
import Resources
import Sharing
import SwiftUI
import SystemNotification

struct AccountSettingView: View {
    @Bindable private var store: StoreOf<AccountSettingReducer>
    @Shared(.setting) private var setting: Setting

    init(store: StoreOf<AccountSettingReducer>) {
        self.store = store
    }

    // MARK: AccountSettingView
    var body: some View {
        Form {
            Section {
                Picker(.website, selection: Binding($setting.galleryHost)) {
                    ForEach(GalleryHost.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                AccountSection(
                    showNewDawnGreeting: Binding($setting.showNewDawnGreeting),
                    bypassSNIFiltering: setting.bypassSNIFiltering,
                    loginAction: { store.send(.delegate(.pushLogin)) },
                    logoutDialogAction: { store.send(.logoutButtonTapped) },
                    logoutConfirmationDialog: $store.scope(
                        \.$confirmationDialog, action: \.confirmationDialog
                    ),
                    configureAccountAction: { store.send(.delegate(.pushEhSetting)) },
                    manageTagsAction: {
                        store.send(.presentWebView(Defaults.URL.myTags(host: setting.galleryHost)))
                    }
                )
            }
            CookieSection(
                ehCookiesState: $store.ehCookiesState,
                exCookiesState: $store.exCookiesState,
                copyAction: { store.send(.copyCookies($0)) }
            )
        }
        .toast($store.scope(\.$toast, action: \.toast))
        .sheet(item: $store.destination.webView, id: \.absoluteString) { url in
            WebView(url: url.wrappedValue)
                .ignoresSafeArea(edges: .bottom)
                .privacyMask()
        }
        .navigationTitle(.account)
    }
}

// MARK: AccountSection
private struct AccountSection: View {
    @SharedReader(.didLogin) private var didLogin: Bool
    @Binding private var showNewDawnGreeting: Bool
    private let bypassSNIFiltering: Bool
    private let loginAction: () -> Void
    private let logoutDialogAction: () -> Void
    private let logoutConfirmationDialog:
        Binding<Store<ConfirmationDialogState<AccountSettingReducer.Dialog>, AccountSettingReducer.Dialog>?>
    private let configureAccountAction: () -> Void
    private let manageTagsAction: () -> Void

    init(
        showNewDawnGreeting: Binding<Bool>, bypassSNIFiltering: Bool,
        loginAction: @escaping () -> Void,
        logoutDialogAction: @escaping () -> Void,
        logoutConfirmationDialog:
            Binding<Store<ConfirmationDialogState<AccountSettingReducer.Dialog>, AccountSettingReducer.Dialog>?>,
        configureAccountAction: @escaping () -> Void,
        manageTagsAction: @escaping () -> Void
    ) {
        _showNewDawnGreeting = showNewDawnGreeting
        self.bypassSNIFiltering = bypassSNIFiltering
        self.loginAction = loginAction
        self.logoutDialogAction = logoutDialogAction
        self.logoutConfirmationDialog = logoutConfirmationDialog
        self.configureAccountAction = configureAccountAction
        self.manageTagsAction = manageTagsAction
    }

    var body: some View {
        if !didLogin {
            Button(.RLocalizable.login, action: loginAction)
        } else {
            Button(
                .logout,
                role: .destructive, action: logoutDialogAction
            )
            .confirmationDialog(logoutConfirmationDialog)
            Group {
                Button(
                    .accountConfiguration,
                    action: configureAccountAction
                )
                .withArrow()
                if !bypassSNIFiltering {
                    Button(
                        .tagsManagement,
                        action: manageTagsAction
                    )
                    .withArrow()
                }
                AppToggle(.showNewDawnGreeting, isOn: $showNewDawnGreeting)
            }
            .foregroundStyle(.primary)
        }
    }
}

// MARK: CookieSection
private struct CookieSection: View {
    @Binding private var ehCookiesState: CookiesState
    @Binding private var exCookiesState: CookiesState
    private let copyAction: (GalleryHost) -> Void

    init(
        ehCookiesState: Binding<CookiesState>,
        exCookiesState: Binding<CookiesState>,
        copyAction: @escaping (GalleryHost) -> Void
    ) {
        _ehCookiesState = ehCookiesState
        _exCookiesState = exCookiesState
        self.copyAction = copyAction
    }

    var body: some View {
        Section(GalleryHost.ehentai.rawValue) {
            CookieRow(cookieState: $ehCookiesState.memberID)
            CookieRow(cookieState: $ehCookiesState.passHash)
            Button(.copyCookies) {
                copyAction(.ehentai)
            }
            .foregroundStyle(.tint).font(.subheadline)
        }
        Section(GalleryHost.exhentai.rawValue) {
            CookieRow(cookieState: $exCookiesState.igneous)
            CookieRow(cookieState: $exCookiesState.memberID)
            CookieRow(cookieState: $exCookiesState.passHash)
            Button(.copyCookies) {
                copyAction(.exhentai)
            }
            .foregroundStyle(.tint).font(.subheadline)
        }
    }
}

// MARK: CookieRow
private struct CookieRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding private var cookieState: CookieState

    init(cookieState: Binding<CookieState>) {
        _cookieState = cookieState
    }

    /// A title-and-value row whose priorities are inverted above the default size
    /// (Phase 16 finding #24).
    ///
    /// The value is the whole point of the row: a credential fragment the user came here to read
    /// off, reproduced nowhere else in the app — the copy button next to it puts it on the
    /// pasteboard but never shows it. On one line it is also the half with no floor, so as the key
    /// beside it wraps to four lines the thirty-two-character hash is ellipsised down to three
    /// characters. Above the default size the pair therefore stops sharing a line: the key takes
    /// the first, with the validity glyph still trailing it, and the value takes the whole width
    /// underneath and wraps for as many lines as it needs.
    ///
    /// Wrapping is what the vertical axis buys — a single-line field would still scroll its text
    /// out of sight at these widths — and it is why the accessibility branch cannot inherit the
    /// designed row's trailing alignment either: a value that starts flush right and wraps reads as
    /// a ragged block, so it anchors leading like the key above it.
    ///
    /// The 8-point gap keeps the key and its value reading as one pair, well inside the form row's
    /// own vertical margins; the horizontal margins are the row's own and are untouched, so neither
    /// line moves closer to the edge than the designed row already sits.
    var body: some View {
        row
            // The vertical-axis field's return key inserts a line break instead of dismissing the
            // keyboard. A cookie value never contains one, and the reducer's echo guard trims
            // spaces only, so a stray break would be written to the jar and bounce straight back as
            // a reload that replaces what is being typed. Filtering here rather than inside the
            // accessibility branch keeps one rule for both layouts: the single-line field below the
            // default size cannot produce a break, so there the filter never fires.
            .onChange(of: cookieState.editingText) {
                let singleLine = cookieState.editingText.filter({ !$0.isNewline })
                if singleLine != cookieState.editingText {
                    cookieState.editingText = singleLine
                }
            }
    }

    @ViewBuilder private var row: some View {
        if dynamicTypeSize <= .large {
            HStack {
                keyLabel

                TextField(cookieState.value.placeholder, text: $cookieState.editingText)
                    .submitLabel(.done)
                    .autocorrectionDisabled(true)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.none)

                validityGlyph
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    keyLabel
                    Spacer()
                    validityGlyph
                }

                TextField(cookieState.value.placeholder, text: $cookieState.editingText, axis: .vertical)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.none)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The cookie's name, carrying the validity that the glyph beside it shows sighted users.
    ///
    /// The state lives here rather than on the field or on a combined row: an `accessibilityValue`
    /// on the `TextField` would replace the cookie text it exists to read out, and folding the
    /// field into one combined element would take away its editing role. So the field stays a
    /// plain text field, the glyph is kept out of the accessibility tree, and the key announces
    /// "valid" or "invalid" as its value — the same fact the glyph's shape and colour convey.
    private var keyLabel: some View {
        Text(cookieState.key)
            .accessibilityValue(validityValue)
    }

    private var validityValue: LocalizedStringResource {
        cookieState.value.isInvalid ? .accessibilityCookieInvalid : .accessibilityCookieValid
    }

    private var validityGlyph: some View {
        Image(systemSymbol: cookieState.value.isInvalid ? .xmarkCircle : .checkmarkCircle)
            .foregroundStyle(cookieState.value.isInvalid ? .red : .accentColor)
            .accessibilityHidden(true)
    }
}

#Preview("Initial") {
    NavigationStack {
        AccountSettingView(
            store: .init(initialState: .init(), reducer: AccountSettingReducer.init)
        )
    }
}

// Sample values only: a seven-digit member id and a thirty-two-character hash, the two shapes the
// screen actually shows — the short one still reads whole at XXL, the long one does not.
extension CookieState {
    fileprivate static var previewMemberID: Self {
        .init(key: "ipb_member_id", value: .init(rawValue: "1234567", localizedString: ""))
    }
    fileprivate static var previewPassHash: Self {
        .init(key: "ipb_pass_hash", value: .init(rawValue: "0a1b2c3d4e5f60718293a4b5c6d7e8f9", localizedString: ""))
    }
}

#Preview("Cookie rows, default size") {
    @Previewable @State var memberID = CookieState.previewMemberID
    @Previewable @State var passHash = CookieState.previewPassHash

    NavigationStack {
        Form {
            Section(GalleryHost.ehentai.rawValue) {
                CookieRow(cookieState: $memberID)
                CookieRow(cookieState: $passHash)
            }
        }
    }
    .environment(\.dynamicTypeSize, .large)
}

#Preview("Cookie rows, AX5") {
    @Previewable @State var memberID = CookieState.previewMemberID
    @Previewable @State var passHash = CookieState.previewPassHash

    NavigationStack {
        Form {
            Section(GalleryHost.ehentai.rawValue) {
                CookieRow(cookieState: $memberID)
                CookieRow(cookieState: $passHash)
            }
        }
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
