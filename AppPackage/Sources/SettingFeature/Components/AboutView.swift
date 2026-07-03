import AppModels
import SwiftUI
import Resources
import AppTools
import AppComponents

struct AboutView: View {
    private var version: String {
        [
            L10n.Localizable.AboutView.version,
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
            Section(L10n.Localizable.AboutView.specialThanks) {
                ForEach(specialThanks) { specialThank in
                    LinkRow(urlString: specialThank.urlString, text: specialThank.text)
                }
            }
            Section(L10n.Localizable.AboutView.codeLevelContributors) {
                ForEach(codeLevelContributors) { codeLevelContributor in
                    LinkRow(urlString: codeLevelContributor.urlString, text: codeLevelContributor.text)
                }
            }
            Section(L10n.Localizable.AboutView.translationContributors) {
                ForEach(translationContributors) { translationContributor in
                    LinkRow(urlString: translationContributor.urlString, text: translationContributor.text)
                }
            }
            Section(L10n.Localizable.AboutView.acknowledgements) {
                ForEach(acknowledgements) { acknowledgement in
                    LinkRow(urlString: acknowledgement.urlString, text: acknowledgement.text)
                }
            }
        }
        .navigationTitle(L10n.Localizable.AboutView.ehPanda)
        .toolbar {
            ToolbarItem(placement: .largeSubtitle) {
                VStack(alignment: .leading) {
                    Text(L10n.Constant.copyright)
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
            urlString: L10n.Constant.Contact.website,
            text: L10n.Localizable.AboutView.website
        ),
        .init(
            urlString: L10n.Constant.Contact.gitHub,
            text: L10n.Constant.Contact.gitHubLink
        ),
        .init(
            urlString: L10n.Constant.Contact.discord,
            text: L10n.Constant.Contact.discordLink
        ),
        .init(
            urlString: L10n.Constant.Contact.telegram,
            text: L10n.Constant.Contact.telegramLink
        ),
        .init(
            urlString: L10n.Constant.Contact.altStoreLink,
            text: L10n.Localizable.AboutView.altStoreSource
        )
    ]}()

    // MARK: Special thanks
    private let specialThanks: [Info] = {[
        .init(
            urlString: L10n.Constant.SpecialThanks.taylorlannisterLink,
            text: L10n.Constant.SpecialThanks.taylorlannister
        ),
        .init(
            urlString: L10n.Constant.SpecialThanks.luminescentYqLink,
            text: L10n.Constant.SpecialThanks.luminescentYq
        ),
        .init(
            urlString: L10n.Constant.SpecialThanks.caxerxLink,
            text: L10n.Constant.SpecialThanks.caxerx
        ),
        .init(
            urlString: L10n.Constant.SpecialThanks.honjowLink,
            text: L10n.Constant.SpecialThanks.honjow
        )
    ]}()

    // MARK: Code level contributors
    private let codeLevelContributors: [Info] = {[
        .init(
            urlString: L10n.Constant.CodeLevelContributor.vvbbnn00Link,
            text: L10n.Constant.CodeLevelContributor.vvbbnn00
        ),
        .init(
            urlString: L10n.Constant.CodeLevelContributor.kaed3miLink,
            text: L10n.Constant.CodeLevelContributor.kaed3mi
        ),
        .init(
            urlString: L10n.Constant.CodeLevelContributor.aalberrtyLink,
            text: L10n.Constant.CodeLevelContributor.aalberrty
        ),
        .init(
            urlString: L10n.Constant.CodeLevelContributor.jimmyPrimeLink,
            text: L10n.Constant.CodeLevelContributor.jimmyPrime
        ),
        .init(
            urlString: L10n.Constant.CodeLevelContributor.xioxinLink,
            text: L10n.Constant.CodeLevelContributor.xioxin
        )
    ]}()

    // MARK: Translation contributors
    private let translationContributors: [Info] = {[
        .init(
            urlString: L10n.Constant.TranslationContributor.nebulosaCatLink,
            text: L10n.Constant.TranslationContributor.nebulosaCat
        ),
        .init(
            urlString: L10n.Constant.TranslationContributor.paulHaeusslerLink,
            text: L10n.Constant.TranslationContributor.paulHaeussler
        ),
        .init(
            urlString: L10n.Constant.TranslationContributor.caxerxLink,
            text: L10n.Constant.TranslationContributor.caxerx
        ),
        .init(
            urlString: L10n.Constant.TranslationContributor.neKoOuOLink,
            text: L10n.Constant.TranslationContributor.neKoOuO
        )
    ]}()

    // MARK: Acknowledgements
    private let acknowledgements: [Info] = {[
        .init(
            urlString: L10n.Constant.Acknowledgement.kannaLink,
            text: L10n.Constant.Acknowledgement.kanna
        ),
        .init(
            urlString: L10n.Constant.Acknowledgement.colorfulLink,
            text: L10n.Constant.Acknowledgement.colorful
        ),
        .init(
            urlString: L10n.Constant.Acknowledgement.swiftGenLink,
            text: L10n.Constant.Acknowledgement.swiftGen
        ),
        .init(
            urlString: L10n.Constant.Acknowledgement.kingfisherLink,
            text: L10n.Constant.Acknowledgement.kingfisher
        ),
        .init(
            urlString: L10n.Constant.Acknowledgement.swiftUIPagerLink,
            text: L10n.Constant.Acknowledgement.swiftUIPager
        ),
        .init(
            urlString: L10n.Constant.Acknowledgement.waterfallGridLink,
            text: L10n.Constant.Acknowledgement.waterfallGrid
        ),
        .init(
            urlString: L10n.Constant.Acknowledgement.swiftyOpenCCLink,
            text: L10n.Constant.Acknowledgement.swiftyOpenCC
        ),
        .init(
            urlString: L10n.Constant.Acknowledgement.uiImageColorsLink,
            text: L10n.Constant.Acknowledgement.uiImageColors
        ),
        .init(
            urlString: L10n.Constant.Acknowledgement.sfSafeSymbolsLink,
            text: L10n.Constant.Acknowledgement.sfSafeSymbols
        ),
        .init(
            urlString: L10n.Constant.Acknowledgement.systemNotificationLink,
            text: L10n.Constant.Acknowledgement.systemNotification
        ),
        .init(
            urlString: L10n.Constant.Acknowledgement.swiftCommonMarkLink,
            text: L10n.Constant.Acknowledgement.swiftCommonMark
        ),
        .init(
            urlString: L10n.Constant.Acknowledgement.ehTagTranslationDatabaseLink,
            text: L10n.Constant.Acknowledgement.ehTagTranslationDatabase
        ),
        .init(
            urlString: L10n.Constant.Acknowledgement.tcaLink,
            text: L10n.Constant.Acknowledgement.tca
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
