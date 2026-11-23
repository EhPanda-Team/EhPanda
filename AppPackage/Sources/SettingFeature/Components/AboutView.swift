import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import Resources
import SwiftUI

struct AboutView: View {
    private let store: StoreOf<AboutFeature>

    init(store: StoreOf<AboutFeature>) {
        self.store = store
    }

    private var version: String {
        [
            String(localized: .version),
            AppInfo.version, "(\(AppInfo.build))"
        ]
        .joined(separator: " ")
    }

    var body: some View {
        Form {
            Section {
                ForEach(contacts) { contact in
                    LinkRow(destination: URL(string: contact.urlString), title: Text(contact.text))
                }
            }
            Section(.specialThanks) {
                ForEach(specialThanks) { specialThank in
                    LinkRow(destination: URL(string: specialThank.urlString), title: Text(specialThank.text))
                }
            }
            if store.codeContributors?.isEmpty != true {
                Section(.codeContributors) {
                    featuredContributorRows
                }
            }
            Section(.translationContributors) {
                ForEach(Self.translationContributors) { translationContributor in
                    LinkRow(
                        destination: URL(string: translationContributor.urlString),
                        title: Text(translationContributor.text)
                    )
                }
            }
            Section(.acknowledgements) {
                ForEach(acknowledgements) { acknowledgement in
                    LinkRow(destination: URL(string: acknowledgement.urlString), title: Text(acknowledgement.text))
                }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(.ehPanda)
        .toolbar {
            ToolbarItem(placement: .largeSubtitle) {
                VStack(alignment: .leading) {
                    Text(.Constant.copyright)
                    Text(version)
                }
                .foregroundStyle(.gray)
                .font(.caption2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: Code level contributors
    @ViewBuilder
    private var featuredContributorRows: some View {
        if let contributors = store.codeContributors {
            ForEach(contributors) { contributor in
                LinkRow(destination: contributor.htmlURL, title: Text(verbatim: contributor.login))
            }
        } else if let error = store.codeContributorsLoadingState.failed {
            ErrorView(error: error, action: { store.send(.fetchCodeContributors) })
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: Contacts
    private let contacts: [AboutLink] = {[
        .init(
            urlString: String(localized: .Constant.contactWebsite),
            text: .website
        ),
        .init(
            urlString: String(localized: .Constant.contactGitHub),
            text: .Constant.contactGitHubLink
        ),
        .init(
            urlString: String(localized: .Constant.contactDiscord),
            text: .Constant.contactDiscordLink
        ),
        .init(
            urlString: String(localized: .Constant.contactTelegram),
            text: .Constant.contactTelegramLink
        )
    ]}()

    // MARK: Special thanks
    private let specialThanks: [AboutLink] = {[
        .init(
            urlString: String(localized: .Constant.specialThanksTaylorlannisterLink),
            text: .Constant.specialThanksTaylorlannister
        ),
        .init(
            urlString: String(localized: .Constant.specialThanksLuminescentYqLink),
            text: .Constant.specialThanksLuminescentYq
        ),
        .init(
            urlString: String(localized: .Constant.specialThanksCaxerxLink),
            text: .Constant.specialThanksCaxerx
        ),
        .init(
            urlString: String(localized: .Constant.specialThanksHonjowLink),
            text: .Constant.specialThanksHonjow
        )
    ]}()

    // MARK: Translation contributors
    /// The fixed Translation Contributors list. Internal so `AboutFeatureTests` can pin
    /// `AboutFeature.translationContributorLogins` against it.
    static let translationContributors: [AboutLink] = [
        .init(
            urlString: String(localized: .Constant.translationContributorNebulosaCatLink),
            text: .Constant.translationContributorNebulosaCat
        ),
        .init(
            urlString: String(localized: .Constant.translationContributorPaulHaeusslerLink),
            text: .Constant.translationContributorPaulHaeussler
        ),
        .init(
            urlString: String(localized: .Constant.translationContributorCaxerxLink),
            text: .Constant.translationContributorCaxerx
        ),
        .init(
            urlString: String(localized: .Constant.translationContributorNeKoOuOLink),
            text: .Constant.translationContributorNeKoOuO
        )
    ]

    // MARK: Acknowledgements
    private let acknowledgements: [AboutLink] = {[
        .init(
            urlString: String(localized: .Constant.acknowledgementKannaLink),
            text: .Constant.acknowledgementKanna
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementColorfulXLink),
            text: .Constant.acknowledgementColorfulX
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementKingfisherLink),
            text: .Constant.acknowledgementKingfisher
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementUiImageColorsLink),
            text: .Constant.acknowledgementUiImageColors
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementSfSafeSymbolsLink),
            text: .Constant.acknowledgementSfSafeSymbols
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementSwiftMarkdownLink),
            text: .Constant.acknowledgementSwiftMarkdown
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementSystemNotificationLink),
            text: .Constant.acknowledgementSystemNotification
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementEhTagTranslationDatabaseLink),
            text: .Constant.acknowledgementEhTagTranslationDatabase
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementTcaLink),
            text: .Constant.acknowledgementTca
        )
    ]}()
}

// MARK: LinkRow
private struct LinkRow: View {
    let destination: URL?
    let title: Text

    var body: some View {
        Group {
            let title = title
                .fontWeight(.medium)

            if let destination {
                Link(destination: destination) {
                    title.withArrow()
                }
                .cellRowHover()
            } else {
                title
            }
        }
        .foregroundStyle(.primary)
    }
}

// MARK: Definition
struct AboutLink: Identifiable {
    var id: String { urlString }

    let urlString: String
    let text: LocalizedStringResource
}

#Preview("Initial") {
    var state = AboutFeature.State()
    state.codeContributors = ["aalberrty", "xioxin"].enumerated().compactMap({ offset, login in
        URL(string: "https://github.com/\(login)").map({ url in
            GitHubContributor(id: offset, login: login, htmlURL: url, accountType: "User")
        })
    })
    return NavigationStack {
        AboutView(store: Store(initialState: state, reducer: AboutFeature.init))
    }
}
