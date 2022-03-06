//
//  EhPandaView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI

struct EhPandaView: View {
    private var version: String {
        [
            R.string.localizable.ehpandaViewDescriptionVersion(),
            AppUtil.version, "(\(AppUtil.build))"
        ]
        .joined(separator: " ")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(R.string.constant.ehpandaCopyright())
                Text(version)
            }
            .foregroundStyle(.gray).font(.caption2.bold())
            Spacer()
        }
        .padding(.horizontal)
        Form {
            Section {
                ForEach(contacts) { contact in
                    LinkRow(urlString: contact.urlString, text: contact.text)
                }
            }
            Section(R.string.localizable.ehpandaViewSectionTitleSpecialThanks()) {
                ForEach(specialThanks) { specialThank in
                    LinkRow(urlString: specialThank.urlString, text: specialThank.text)
                }
            }
            Section(R.string.localizable.ehpandaViewSectionTitleCodeLevelContributors()) {
                ForEach(codeLevelContributors) { codeLevelContributor in
                    LinkRow(urlString: codeLevelContributor.urlString, text: codeLevelContributor.text)
                }
            }
            Section(R.string.localizable.ehpandaViewSectionTitleTranslationContributors()) {
                ForEach(translationContributors) { translationContributor in
                    LinkRow(urlString: translationContributor.urlString, text: translationContributor.text)
                }
            }
            Section(R.string.localizable.ehpandaViewSectionTitleAcknowledgements()) {
                ForEach(acknowledgements) { acknowledgement in
                    LinkRow(urlString: acknowledgement.urlString, text: acknowledgement.text)
                }
            }
        }
        .navigationTitle(R.string.localizable.ehpandaViewTitleEhPanda())
    }

    // MARK: Contacts
    private let contacts: [Info] = {[
        .init(
            urlString: R.string.constant.ehpandaContactsLinkWebsite(),
            text: R.string.localizable.ehpandaViewButtonWebsite()
        ),
        .init(
            urlString: R.string.constant.ehpandaContactsLinkGitHub(),
            text: R.string.constant.ehpandaContactsTextGitHub()
        ),
        .init(
            urlString: R.string.constant.ehpandaContactsLinkDiscord(),
            text: R.string.constant.ehpandaContactsTextDiscord()
        ),
        .init(
            urlString: R.string.constant.ehpandaContactsLinkTelegram(),
            text: R.string.constant.ehpandaContactsTextTelegram()
        ),
        .init(
            urlString: R.string.constant.ehpandaContactsLinkAltStore(),
            text: R.string.localizable.ehpandaViewButtonAltStoreSource()
        )
    ]}()

    // MARK: Special thanks
    private let specialThanks: [Info] = {[
        .init(
            urlString: R.string.constant.ehpandaSpecialThanksLinkTaylorlannister(),
            text: R.string.constant.ehpandaSpecialThanksTextTaylorlannister()
        ),
        .init(
            urlString: R.string.constant.ehpandaSpecialThanksLinkLuminescent_yq(),
            text: R.string.constant.ehpandaSpecialThanksTextLuminescent_yq()
        ),
        .init(
            urlString: R.string.constant.ehpandaSpecialThanksLinkCaxerx(),
            text: R.string.constant.ehpandaSpecialThanksTextCaxerx()
        ),
        .init(
            urlString: R.string.constant.ehpandaSpecialThanksLinkHonjow(),
            text: R.string.constant.ehpandaSpecialThanksTextHonjow()
        )
    ]}()

    // MARK: Code level contributors
    private let codeLevelContributors: [Info] = {[
        .init(
            urlString: R.string.constant.ehpandaCodeLevelContributorsLinkTatsuz0u(),
            text: R.string.constant.ehpandaCodeLevelContributorsTextTatsuz0u()
        ),
        .init(
            urlString: R.string.constant.ehpandaCodeLevelContributorsLinkXioxin(),
            text: R.string.constant.ehpandaCodeLevelContributorsTextXioxin()
        ),
        .init(
            urlString: R.string.constant.ehpandaCodeLevelContributorsLinkEthanChinCN(),
            text: R.string.constant.ehpandaCodeLevelContributorsTextEthanChinCN()
        ),
        .init(
            urlString: R.string.constant.ehpandaCodeLevelContributorsLinkLengYue(),
            text: R.string.constant.ehpandaCodeLevelContributorsTextLengYue()
        )
    ]}()

    // MARK: Translation contributors
    private let translationContributors: [Info] = {[
        .init(
            urlString: R.string.constant.ehpandaTranslationContributorsLinkTatsuz0u(),
            text: R.string.constant.ehpandaTranslationContributorsTextTatsuz0u()
        ),
        .init(
            urlString: R.string.constant.ehpandaTranslationContributorsLinkPaulHaeussler(),
            text: R.string.constant.ehpandaTranslationContributorsTextPaulHaeussler()
        ),
        .init(
            urlString: R.string.constant.ehpandaTranslationContributorsLinkCaxerx(),
            text: R.string.constant.ehpandaTranslationContributorsTextCaxerx()
        ),
        .init(
            urlString: R.string.constant.ehpandaTranslationContributorsLinkNyaanim(),
            text: R.string.constant.ehpandaTranslationContributorsTextNyaanim()
        )
    ]}()

    // MARK: Acknowledgements
    private let acknowledgements: [Info] = {[
        .init(
            urlString: R.string.constant.ehpandaAcknowledgementsLinkKanna(),
            text: R.string.constant.ehpandaAcknowledgementsTextKanna()
        ),
        .init(
            urlString: R.string.constant.ehpandaAcknowledgementsLinkRswift(),
            text: R.string.constant.ehpandaAcknowledgementsTextRswift()
        ),
        .init(
            urlString: R.string.constant.ehpandaAcknowledgementsLinkAlertKit(),
            text: R.string.constant.ehpandaAcknowledgementsTextAlertKit()
        ),
        .init(
            urlString: R.string.constant.ehpandaAcknowledgementsLinkColorful(),
            text: R.string.constant.ehpandaAcknowledgementsTextColorful()
        ),
        .init(
            urlString: R.string.constant.ehpandaAcknowledgementsLinkFilePicker(),
            text: R.string.constant.ehpandaAcknowledgementsTextFilePicker()
        ),
        .init(
            urlString: R.string.constant.ehpandaAcknowledgementsLinkKingfisher(),
            text: R.string.constant.ehpandaAcknowledgementsTextKingfisher()
        ),
        .init(
            urlString: R.string.constant.ehpandaAcknowledgementsLinkSnappable(),
            text: R.string.constant.ehpandaAcknowledgementsTextSnappable()
        ),
        .init(
            urlString: R.string.constant.ehpandaAcknowledgementsLinkSwiftUIPager(),
            text: R.string.constant.ehpandaAcknowledgementsTextSwiftUIPager()
        ),
        .init(
            urlString: R.string.constant.ehpandaAcknowledgementsLinkSwiftyBeaver(),
            text: R.string.constant.ehpandaAcknowledgementsTextSwiftyBeaver()
        ),
        .init(
            urlString: R.string.constant.ehpandaAcknowledgementsLinkWaterfallGrid(),
            text: R.string.constant.ehpandaAcknowledgementsTextWaterfallGrid()
        ),
        .init(
            urlString: R.string.constant.ehpandaAcknowledgementsLinkSwiftyOpenCC(),
            text: R.string.constant.ehpandaAcknowledgementsTextSwiftyOpenCC()
        ),
        .init(
            urlString: R.string.constant.ehpandaAcknowledgementsLinkUIImageColors(),
            text: R.string.constant.ehpandaAcknowledgementsTextUIImageColors()
        ),
        .init(
            urlString: R.string.constant.ehpandaAcknowledgementsLinkSFSafeSymbols(),
            text: R.string.constant.ehpandaAcknowledgementsTextSFSafeSymbols()
        ),
        .init(
            urlString: R.string.constant.ehpandaAcknowledgementsLinkTTProgressHUD(),
            text: R.string.constant.ehpandaAcknowledgementsTextTTProgressHUD()
        ),
        .init(
            urlString: R.string.constant.ehpandaAcknowledgementsLinkSwiftUINavigation(),
            text: R.string.constant.ehpandaAcknowledgementsTextSwiftUINavigation()
        ),
        .init(
            urlString: R.string.constant.ehpandaAcknowledgementsLinkSwiftCommonMark(),
            text: R.string.constant.ehpandaAcknowledgementsTextSwiftCommonMark()
        ),
        .init(
            urlString: R.string.constant.ehpandaAcknowledgementsLinkEhTagTranslationDatabase(),
            text: R.string.constant.ehpandaAcknowledgementsTextEhTagTranslationDatabase()
        ),
        .init(
            urlString: R.string.constant.ehpandaAcknowledgementsLinkTCA(),
            text: R.string.constant.ehpandaAcknowledgementsTextTCA()
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
        NavigationView {
            EhPandaView()
        }
    }
}
