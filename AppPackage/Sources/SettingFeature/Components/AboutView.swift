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
                ForEach(contacts) { contact in
                    LinkRow(urlString: contact.urlString, text: contact.text)
                }
            }
            Section(String(localized: .specialThanks)) {
                ForEach(specialThanks) { specialThank in
                    LinkRow(urlString: specialThank.urlString, text: specialThank.text)
                }
            }
            Section(String(localized: .codeLevelContributors)) {
                ForEach(codeLevelContributors) { codeLevelContributor in
                    LinkRow(urlString: codeLevelContributor.urlString, text: codeLevelContributor.text)
                }
            }
            Section(String(localized: .translationContributors)) {
                ForEach(translationContributors) { translationContributor in
                    LinkRow(urlString: translationContributor.urlString, text: translationContributor.text)
                }
            }
            Section(String(localized: .acknowledgements)) {
                ForEach(acknowledgements) { acknowledgement in
                    LinkRow(urlString: acknowledgement.urlString, text: acknowledgement.text)
                }
            }
        }
        .navigationTitle(String(localized: .ehPanda))
        .toolbar {
            ToolbarItem(placement: .largeSubtitle) {
                VStack(alignment: .leading) {
                    Text(String(localized: .Constant.copyright))
                    Text(version)
                }
                .foregroundStyle(.gray)
                .font(.caption2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: Contacts
    private let contacts: [Info] = {[
        .init(
            urlString: String(localized: .Constant.contactWebsite),
            text: String(localized: .website)
        ),
        .init(
            urlString: String(localized: .Constant.contactGitHub),
            text: String(localized: .Constant.contactGitHubLink)
        ),
        .init(
            urlString: String(localized: .Constant.contactDiscord),
            text: String(localized: .Constant.contactDiscordLink)
        ),
        .init(
            urlString: String(localized: .Constant.contactTelegram),
            text: String(localized: .Constant.contactTelegramLink)
        ),
        .init(
            urlString: String(localized: .Constant.contactAltStoreLink),
            text: String(localized: .altStoreSource)
        )
    ]}()

    // MARK: Special thanks
    private let specialThanks: [Info] = {[
        .init(
            urlString: String(localized: .Constant.specialThanksTaylorlannisterLink),
            text: String(localized: .Constant.specialThanksTaylorlannister)
        ),
        .init(
            urlString: String(localized: .Constant.specialThanksLuminescentYqLink),
            text: String(localized: .Constant.specialThanksLuminescentYq)
        ),
        .init(
            urlString: String(localized: .Constant.specialThanksCaxerxLink),
            text: String(localized: .Constant.specialThanksCaxerx)
        ),
        .init(
            urlString: String(localized: .Constant.specialThanksHonjowLink),
            text: String(localized: .Constant.specialThanksHonjow)
        )
    ]}()

    // MARK: Code level contributors
    private let codeLevelContributors: [Info] = {[
        .init(
            urlString: String(localized: .Constant.codeLevelContributorVvbbnn00Link),
            text: String(localized: .Constant.codeLevelContributorVvbbnn00)
        ),
        .init(
            urlString: String(localized: .Constant.codeLevelContributorKaed3MiLink),
            text: String(localized: .Constant.codeLevelContributorKaed3Mi)
        ),
        .init(
            urlString: String(localized: .Constant.codeLevelContributorAalberrtyLink),
            text: String(localized: .Constant.codeLevelContributorAalberrty)
        ),
        .init(
            urlString: String(localized: .Constant.codeLevelContributorJimmyPrimeLink),
            text: String(localized: .Constant.codeLevelContributorJimmyPrime)
        ),
        .init(
            urlString: String(localized: .Constant.codeLevelContributorXioxinLink),
            text: String(localized: .Constant.codeLevelContributorXioxin)
        )
    ]}()

    // MARK: Translation contributors
    private let translationContributors: [Info] = {[
        .init(
            urlString: String(localized: .Constant.translationContributorNebulosaCatLink),
            text: String(localized: .Constant.translationContributorNebulosaCat)
        ),
        .init(
            urlString: String(localized: .Constant.translationContributorPaulHaeusslerLink),
            text: String(localized: .Constant.translationContributorPaulHaeussler)
        ),
        .init(
            urlString: String(localized: .Constant.translationContributorCaxerxLink),
            text: String(localized: .Constant.translationContributorCaxerx)
        ),
        .init(
            urlString: String(localized: .Constant.translationContributorNeKoOuOLink),
            text: String(localized: .Constant.translationContributorNeKoOuO)
        )
    ]}()

    // MARK: Acknowledgements
    private let acknowledgements: [Info] = {[
        .init(
            urlString: String(localized: .Constant.acknowledgementKannaLink),
            text: String(localized: .Constant.acknowledgementKanna)
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementColorfulLink),
            text: String(localized: .Constant.acknowledgementColorful)
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementSwiftGenLink),
            text: String(localized: .Constant.acknowledgementSwiftGen)
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementKingfisherLink),
            text: String(localized: .Constant.acknowledgementKingfisher)
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementSwiftUIPagerLink),
            text: String(localized: .Constant.acknowledgementSwiftUIPager)
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementWaterfallGridLink),
            text: String(localized: .Constant.acknowledgementWaterfallGrid)
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementSwiftyOpenCCLink),
            text: String(localized: .Constant.acknowledgementSwiftyOpenCC)
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementUiImageColorsLink),
            text: String(localized: .Constant.acknowledgementUiImageColors)
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementSfSafeSymbolsLink),
            text: String(localized: .Constant.acknowledgementSfSafeSymbols)
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementSystemNotificationLink),
            text: String(localized: .Constant.acknowledgementSystemNotification)
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementSwiftCommonMarkLink),
            text: String(localized: .Constant.acknowledgementSwiftCommonMark)
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementEhTagTranslationDatabaseLink),
            text: String(localized: .Constant.acknowledgementEhTagTranslationDatabase)
        ),
        .init(
            urlString: String(localized: .Constant.acknowledgementTcaLink),
            text: String(localized: .Constant.acknowledgementTca)
        )
    ]}()
}

// MARK: LinkRow
private struct LinkRow: View {
    private let urlString: String
    private let text: String

    init(urlString: String, text: String) {
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
    let text: String
}

struct EhPandaView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AboutView()
        }
    }
}
