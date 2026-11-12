import AppComponents
import AppModels
import ComposableArchitecture
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI

/// EhPanda's Report form sheet (18.1, UI-SPEC C-13 [25–31, 33, 34]).
///
/// A `NavigationStack` with only the leading system Close and the inline title "Report on {site}". The sheet's one
/// action is pinned in a `.safeAreaBar` exactly like the first-launch Continue (C-1): no fill, material or divider
/// behind it, the content scrolls under it with the soft scroll-edge effect. Its label follows the phase: Send Report
/// (loading, ready; dimmed until the form can be sent), a spinner with Sending… (sending), Done (sent) and Open Report
/// Page (unavailable). The failed alert sits on that button, the control that sent the report. Open Report Page shows
/// the site's page in `ReportPageSheet` over the kept form (Research P-7).
struct ReportFormView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable private var store: StoreOf<ReportFormFeature>
    @FocusState private var focus: ReportFormFeature.Field?
    @AccessibilityFocusState private var sentTitleFocused: Bool
    @State private var sentBounce = false
    @ScaledMetric(relativeTo: .title) private var sentSymbolSize: CGFloat = 64

    init(store: StoreOf<ReportFormFeature>) {
        self.store = store
    }

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    if store.phase != .sent {
                        ReportCloseToolbar(isDisabled: store.isCloseDisabled) {
                            store.send(.closeTapped)
                        }
                    }
                }
                .navigationTitle(store.phase == .sent ? Text(verbatim: "") : Text(.commentReport(store.site)))
                .toolbarTitleDisplayMode(.inline)
                .safeAreaBar(edge: .bottom) {
                    primaryButton
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                }
        }
        .bind($store.focus, to: $focus)
        .presentationDetents([.large])
        .interactiveDismissDisabled(store.isDismissLocked)
        .sensoryFeedback(.success, trigger: store.phase) { _, phase in phase == .sent }
        .onChange(of: store.phase) { _, phase in
            // Sent: one bounce (none under Reduce Motion) and VoiceOver moves to the title (C-13 Sent).
            guard phase == .sent else { return }
            if !reduceMotion {
                sentBounce.toggle()
            }
            sentTitleFocused = true
        }
        .sheet(item: $store.destination.reportPage, id: \.self) { url in
            ReportPageSheet(url: url.wrappedValue)
        }
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        switch store.phase {
        case .loading:
            centred {
                if store.showsSpinner {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(.reportLoading)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("report_loading")
                }
            }
        case .ready, .sending:
            form
        case .sent:
            centred { sent }
        case .unavailable:
            centred {
                ContentUnavailableView {
                    Label(.reportUnavailableTitle, systemSymbol: .exclamationmarkTriangle)
                } description: {
                    Text(.reportUnavailableBody(store.site))
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("report_unavailable")
            }
        }
    }

    /// A centred state on the form's grouped background, scrollable at the largest text sizes.
    private func centred<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            ScrollView {
                content()
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.vertical) { length, _ in length }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        }
    }

    // MARK: Form

    private var form: some View {
        Form {
            Section {
                ForEach(store.reasons, id: \.self, content: reasonRow)
            } header: {
                VStack(alignment: .leading, spacing: 15) {
                    // `Color.secondary`, not `.secondary`: the header already draws in its secondary style, and a
                    // hierarchical `.secondary` inside it would fade the intro one level further.
                    Text(.reportIntro(store.site))
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .textCase(nil)
                    Text(.reportReason)
                }
            } footer: {
                if store.reason != nil {
                    Text(.reportHelpIllegalWarning(store.site))
                        .accessibilityIdentifier("report_illegal_warning")
                }
            }

            Section {
                TextField(text: $store.email, prompt: Text(.reportEmailPlaceholder)) {
                    Text(.reportEmail)
                }
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focus, equals: .email)
                .onSubmit {
                    focus = .details
                }
                .accessibilityIdentifier("report_email")
            } header: {
                Text(.reportEmail)
            } footer: {
                emailFooter
            }

            Section {
                TextField(text: $store.details, axis: .vertical) {
                    Text(.reportDetails)
                }
                .lineLimit(5...)
                .font(.body)
                .focused($focus, equals: .details)
                .accessibilityIdentifier("report_details")
            } header: {
                Text(.reportDetails)
            } footer: {
                detailsFooter
            }
        }
        .formStyle(.grouped)
        .disabled(store.phase == .sending)
        .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        .animation(reduceMotion ? nil : .default, value: store.reason != nil)
        .animation(reduceMotion ? nil : .default, value: store.emailInvalid)
        .onChange(of: store.emailInvalid) { _, isInvalid in
            if isInvalid {
                AccessibilityNotification.Announcement(String(localized: .reportEmailInvalid)).post()
            }
        }
        .accessibilityIdentifier("report_form")
    }

    private func reasonRow(_ reason: ReportFormFeature.Reason) -> some View {
        let isSelected = store.reason == reason
        return Button {
            store.send(.reasonTapped(reason))
        } label: {
            HStack {
                // `Color.primary`: a button in a form row draws its label in the tint, and a hierarchical
                // `.primary` would resolve against it; the row's title is primary text (C-13 Form).
                Text(title(for: reason))
                    .font(.body)
                    .foregroundStyle(Color.primary)
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemSymbol: .checkmark)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.rect)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("report_reason_" + reason.type.rawValue)
    }

    private func title(for reason: ReportFormFeature.Reason) -> LocalizedStringResource {
        switch reason {
        case .child: .reportReasonChild
        case .illegal: .reportReasonIllegal
        }
    }

    @ViewBuilder private var emailFooter: some View {
        if store.emailInvalid {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemSymbol: .exclamationmarkCircle)
                    .accessibilityHidden(true)
                Text(.reportEmailInvalid)
            }
            .font(.footnote)
            .foregroundStyle(.red)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("report_email_invalid")
        } else {
            Text(.reportEmailFooter(store.site))
        }
    }

    private var detailsFooter: some View {
        let footer = String(localized: .reportCommentFooter(store.site))
        let text = store.reason == nil ? footer : String(localized: .reportHelpIllegal) + "\n\n" + footer
        return Text(verbatim: text)
            .accessibilityIdentifier("report_details_footer")
    }

    // MARK: Sent

    private var sent: some View {
        VStack(spacing: 16) {
            Image(systemSymbol: .checkmarkCircleFill)
                .font(.system(size: sentSymbolSize))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, options: .nonRepeating, value: sentBounce)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text(.reportSentTitle)
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($sentTitleFocused)
                Text(.reportSentBody(store.site))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("report_sent")
    }

    // MARK: Pinned button

    private var primaryButton: some View {
        ReportPrimaryButton(kind: store.primaryKind) {
            store.send(.primaryTapped)
        }
        .disabled(!isPrimaryEnabled)
        // The failed alert belongs to the button that sent the report (AGENTS.md alert placement).
        .modifier(ReportFailedAlert(item: $store.scope(\.$alert, action: \.alert)))
    }

    private var isPrimaryEnabled: Bool {
        switch store.primaryKind {
        case .send: store.canSend
        case .sending: false
        case .done, .openReportPage: true
        }
    }
}

/// The pinned button (C-13 "Pinned action bar"), built like `FirstLaunchContinueButton`: full width, large,
/// accent-filled glass, a `.headline` label that wraps and grows the button, white on the light accent and black on
/// the dark one, and the system's dimmed colours while disabled. ⌘↩ triggers it only while it is enabled.
private struct ReportPrimaryButton: View {
    @Environment(\.isEnabled) private var isEnabled

    let kind: ReportFormFeature.PrimaryKind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .font(.headline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .foregroundStyle(isEnabled ? Self.onAccentLabel : Color.secondary)
                // The labels swap in place so the bar never jumps (C-13).
                .transaction { $0.animation = nil }
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .tint(.accentColor)
        .keyboardShortcut(.return, modifiers: .command)
        .accessibilityIdentifier("report_primary_button")
    }

    @ViewBuilder private var label: some View {
        switch kind {
        case .send:
            Text(.reportSend)
        case .sending:
            HStack(spacing: 8) {
                // The regular spinner sits on the label's line; the bar's large control size would draw it large.
                ProgressView()
                    .controlSize(.regular)
                    .tint(isEnabled ? Self.onAccentLabel : Color.secondary)
                Text(.reportSending)
            }
        case .done:
            Text(.reportSentDone)
        case .openReportPage:
            Text(.commentReportOpen)
        }
    }

    private static let onAccentLabel = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .black : .white })
}

/// The failed alert (C-13 Failed), drawn like `appAlert` but with Retry as the alert's default button: it is the
/// first button, and the one Return chooses. The buttons keep the reducer's order: Retry, Open Report Page, Cancel.
private struct ReportFailedAlert: ViewModifier {
    @Binding var item: Store<AppAlertState<ReportFormFeature.Alert>, ReportFormFeature.Alert>?

    func body(content: Content) -> some View {
        content.alert(
            item.map({ Text($0.title) }) ?? Text(verbatim: ""),
            isPresented: Binding($item),
            presenting: item,
            actions: { store in
                ForEach(store.buttons) { button in
                    Button(role: button.role.map(ButtonRole.init)) {
                        button.withAction { action in
                            if let action { store.send(action) }
                        }
                    } label: {
                        Text(button.label)
                    }
                    .keyboardShortcut(button.action.action == .retry ? .defaultAction : nil)
                }
            },
            message: { store in
                if let message = store.message {
                    Text(message)
                }
            }
        )
    }
}

/// The form's only toolbar item: the leading system Close, icon only (Colo msg 1974), which the reducer can refuse
/// while a report is being sent. Built like `SheetCloseToolbar`.
private struct ReportCloseToolbar: ToolbarContent {
    let isDisabled: Bool
    let action: () -> Void

    var body: some ToolbarContent {
        if #available(iOS 27.1, *) {
            closeItem.axisBehavior(.horizontalOnly)
        } else {
            closeItem
        }
    }

    private var closeItem: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(role: .close, action: action)
                .disabled(isDisabled)
        }
    }
}
