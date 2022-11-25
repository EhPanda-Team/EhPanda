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
            L10n.Localizable.EhPandaView.Title.version,
            AppUtil.version, "(\(AppUtil.build))"
        ]
        .joined(separator: " ")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(L10n.Constant.EhPanda.copyright)
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
            Section(L10n.Localizable.EhPandaView.Section.Title.specialThanks) {
                ForEach(specialThanks) { specialThank in
                    LinkRow(urlString: specialThank.urlString, text: specialThank.text)
                }
            }
            Section(L10n.Localizable.EhPandaView.Section.Title.codeLevelContributors) {
                ForEach(codeLevelContributors) { codeLevelContributor in
                    LinkRow(urlString: codeLevelContributor.urlString, text: codeLevelContributor.text)
                }
            }
            Section(L10n.Localizable.EhPandaView.Section.Title.translationContributors) {
                ForEach(translationContributors) { translationContributor in
                    LinkRow(urlString: translationContributor.urlString, text: translationContributor.text)
                }
            }
            Section(L10n.Localizable.EhPandaView.Section.Title.acknowledgements) {
                ForEach(acknowledgements) { acknowledgement in
                    LinkRow(urlString: acknowledgement.urlString, text: acknowledgement.text)
                }
            }
        }
        .navigationTitle(L10n.Localizable.EhPandaView.Title.ehPanda)
    }

    // MARK: Contacts
    private let contacts: [Info] = {[
        .init(
            urlString: L10n.Constant.EhPanda.Contacts.Link.website,
            text: L10n.Localizable.EhPandaView.Button.website
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Contacts.Link.gitHub,
            text: L10n.Constant.EhPanda.Contacts.Text.gitHub
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Contacts.Link.discord,
            text: L10n.Constant.EhPanda.Contacts.Text.discord
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Contacts.Link.telegram,
            text: L10n.Constant.EhPanda.Contacts.Text.telegram
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Contacts.Link.altStore,
            text: L10n.Localizable.EhPandaView.Button.altStoreSource
        )
    ]}()

    // MARK: Special thanks
    private let specialThanks: [Info] = {[
        .init(
            urlString: L10n.Constant.EhPanda.SpecialThanks.Link.taylorlannister,
            text: L10n.Constant.EhPanda.SpecialThanks.Text.taylorlannister
        ),
        .init(
            urlString: L10n.Constant.EhPanda.SpecialThanks.Link.luminescentYq,
            text: L10n.Constant.EhPanda.SpecialThanks.Text.luminescentYq
        ),
        .init(
            urlString: L10n.Constant.EhPanda.SpecialThanks.Link.caxerx,
            text: L10n.Constant.EhPanda.SpecialThanks.Text.caxerx
        ),
        .init(
            urlString: L10n.Constant.EhPanda.SpecialThanks.Link.honjow,
            text: L10n.Constant.EhPanda.SpecialThanks.Text.honjow
        )
    ]}()

    // MARK: Code level contributors
    private let codeLevelContributors: [Info] = {[
        .init(
            urlString: L10n.Constant.EhPanda.CodeLevelContributors.Link.tatsuz0u,
            text: L10n.Constant.EhPanda.CodeLevelContributors.Text.tatsuz0u
        ),
        .init(
            urlString: L10n.Constant.EhPanda.CodeLevelContributors.Link.chihchy,
            text: L10n.Constant.EhPanda.CodeLevelContributors.Text.chihchy
        ),
        .init(
            urlString: L10n.Constant.EhPanda.CodeLevelContributors.Link.xioxin,
            text: L10n.Constant.EhPanda.CodeLevelContributors.Text.xioxin
        ),
        .init(
            urlString: L10n.Constant.EhPanda.CodeLevelContributors.Link.ethanChinCN,
            text: L10n.Constant.EhPanda.CodeLevelContributors.Text.ethanChinCN
        ),
        .init(
            urlString: L10n.Constant.EhPanda.CodeLevelContributors.Link.lengYue,
            text: L10n.Constant.EhPanda.CodeLevelContributors.Text.lengYue
        )
    ]}()

    // MARK: Translation contributors
    private let translationContributors: [Info] = {[
        .init(
            urlString: L10n.Constant.EhPanda.TranslationContributors.Link.tatsuz0u,
            text: L10n.Constant.EhPanda.TranslationContributors.Text.tatsuz0u
        ),
        .init(
            urlString: L10n.Constant.EhPanda.TranslationContributors.Link.nebulosaCat,
            text: L10n.Constant.EhPanda.TranslationContributors.Text.nebulosaCat
        ),
        .init(
            urlString: L10n.Constant.EhPanda.TranslationContributors.Link.paulHaeussler,
            text: L10n.Constant.EhPanda.TranslationContributors.Text.paulHaeussler
        ),
        .init(
            urlString: L10n.Constant.EhPanda.TranslationContributors.Link.caxerx,
            text: L10n.Constant.EhPanda.TranslationContributors.Text.caxerx
        ),
        .init(
            urlString: L10n.Constant.EhPanda.TranslationContributors.Link.nyaanim,
            text: L10n.Constant.EhPanda.TranslationContributors.Text.nyaanim
        )
    ]}()

    // MARK: Acknowledgements
    private let acknowledgements: [Info] = {[
        .init(
            urlString: L10n.Constant.EhPanda.Acknowledgements.Link.kanna,
            text: L10n.Constant.EhPanda.Acknowledgements.Text.kanna
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Acknowledgements.Link.swiftGen,
            text: L10n.Constant.EhPanda.Acknowledgements.Text.swiftGen
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Acknowledgements.Link.alertKit,
            text: L10n.Constant.EhPanda.Acknowledgements.Text.alertKit
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Acknowledgements.Link.colorful,
            text: L10n.Constant.EhPanda.Acknowledgements.Text.colorful
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Acknowledgements.Link.filePicker,
            text: L10n.Constant.EhPanda.Acknowledgements.Text.filePicker
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Acknowledgements.Link.kingfisher,
            text: L10n.Constant.EhPanda.Acknowledgements.Text.kingfisher
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Acknowledgements.Link.swiftUIPager,
            text: L10n.Constant.EhPanda.Acknowledgements.Text.swiftUIPager
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Acknowledgements.Link.swiftyBeaver,
            text: L10n.Constant.EhPanda.Acknowledgements.Text.swiftyBeaver
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Acknowledgements.Link.waterfallGrid,
            text: L10n.Constant.EhPanda.Acknowledgements.Text.waterfallGrid
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Acknowledgements.Link.swiftyOpenCC,
            text: L10n.Constant.EhPanda.Acknowledgements.Text.swiftyOpenCC
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Acknowledgements.Link.uiImageColors,
            text: L10n.Constant.EhPanda.Acknowledgements.Text.uiImageColors
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Acknowledgements.Link.sfSafeSymbols,
            text: L10n.Constant.EhPanda.Acknowledgements.Text.sfSafeSymbols
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Acknowledgements.Link.ttProgressHUD,
            text: L10n.Constant.EhPanda.Acknowledgements.Text.ttProgressHUD
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Acknowledgements.Link.swiftUINavigation,
            text: L10n.Constant.EhPanda.Acknowledgements.Text.swiftUINavigation
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Acknowledgements.Link.swiftCommonMark,
            text: L10n.Constant.EhPanda.Acknowledgements.Text.swiftCommonMark
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Acknowledgements.Link.ehTagTranslationDatabase,
            text: L10n.Constant.EhPanda.Acknowledgements.Text.ehTagTranslationDatabase
        ),
        .init(
            urlString: L10n.Constant.EhPanda.Acknowledgements.Link.tca,
            text: L10n.Constant.EhPanda.Acknowledgements.Text.tca
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
