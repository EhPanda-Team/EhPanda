import AppModels
import SwiftUI
import Resources
import AppTools
import AppComponents

struct AboutView: View {
    private var version: String {
        [
            String(localized: .version),
            AppUtil.version, "(\(AppUtil.build))"
        ]
        .joined(separator: " ")
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    Text(.Constant.copyright)
                    Text(version)
                }
                .foregroundStyle(.gray)
                .font(.caption2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            Section {
                ForEach(contacts) { contact in
                    LinkRow(urlString: contact.urlString, text: contact.text)
                }
            }
            Section(.specialThanks) {
                ForEach(specialThanks) { specialThank in
                    LinkRow(urlString: specialThank.urlString, text: specialThank.text)
                }
            }
            Section(.codeLevelContributors) {
                ForEach(codeLevelContributors) { codeLevelContributor in
                    LinkRow(urlString: codeLevelContributor.urlString, text: codeLevelContributor.text)
                }
            }
            Section(.translationContributors) {
                ForEach(translationContributors) { translationContributor in
                    LinkRow(urlString: translationContributor.urlString, text: translationContributor.text)
                }
            }
            Section(.acknowledgements) {
                ForEach(acknowledgements) { acknowledgement in
                    LinkRow(urlString: acknowledgement.urlString, text: acknowledgement.text)
                }
            }
        }
        .navigationTitle(.ehPanda)
    }

    // MARK: Contacts
    private let contacts: [Info] = {[
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
        ),
        .init(
            urlString: String(localized: .Constant.contactAltStoreLink),
            text: .altStoreSource
        )
    ]}()

    // MARK: Special thanks
    private let specialThanks: [Info] = {[
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

    // MARK: Code level contributors
    private let codeLevelContributors: [Info] = {[
        .init(
            urlString: String(localized: .Constant.codeLevelContributorVvbbnn00Link),
            text: .Constant.codeLevelContributorVvbbnn00
        ),
        .init(
            urlString: String(localized: .Constant.codeLevelContributorKaed3MiLink),
            text: .Constant.codeLevelContributorKaed3Mi
        ),
        .init(
            urlString: String(localized: .Constant.codeLevelContributorAalberrtyLink),
            text: .Constant.codeLevelContributorAalberrty
        ),
        .init(
            urlString: String(localized: .Constant.codeLevelContributorJimmyPrimeLink),
            text: .Constant.codeLevelContributorJimmyPrime
        ),
        .init(
            urlString: String(localized: .Constant.codeLevelContributorXioxinLink),
            text: .Constant.codeLevelContributorXioxin
        )
    ]}()

    // MARK: Translation contributors
    private let translationContributors: [Info] = {[
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
    ]}()

    // MARK: Acknowledgements
    private let acknowledgements: [Info] = {[
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
            urlString: String(localized: .Constant.acknowledgementSwiftyOpenCCLink),
            text: .Constant.acknowledgementSwiftyOpenCC
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
    private let urlString: String
    private let text: LocalizedStringResource

    init(urlString: String, text: LocalizedStringResource) {
        self.urlString = urlString
        self.text = text
    }

    var body: some View {
        ZStack {
            let text = Text(text).fontWeight(.medium)
            if let url = URL(string: urlString) {
                Link(destination: url) {
                    text.withArrow()
                }
            } else {
                text
            }
        }
        .foregroundColor(.primary)
    }
}

// MARK: Definition
private struct Info: Identifiable {
    var id: String { urlString }

    let urlString: String
    let text: LocalizedStringResource
}

struct EhPandaView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AboutView()
        }
    }
}
