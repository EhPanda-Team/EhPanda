//
//  AboutView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI

struct AboutView: View {
    private var version: String {
        [
            L10n.Localizable.AboutView.Title.version,
            AppUtil.version, "(\(AppUtil.build))"
        ]
        .joined(separator: " ")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(L10n.Constant.App.copyright)
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
            Section(L10n.Localizable.AboutView.Section.Title.specialThanks) {
                ForEach(specialThanks) { specialThank in
                    LinkRow(urlString: specialThank.urlString, text: specialThank.text)
                }
            }
            Section(L10n.Localizable.AboutView.Section.Title.codeLevelContributors) {
                ForEach(codeLevelContributors) { codeLevelContributor in
                    LinkRow(urlString: codeLevelContributor.urlString, text: codeLevelContributor.text)
                }
            }
            Section(L10n.Localizable.AboutView.Section.Title.translationContributors) {
                ForEach(translationContributors) { translationContributor in
                    LinkRow(urlString: translationContributor.urlString, text: translationContributor.text)
                }
            }
            Section(L10n.Localizable.AboutView.Section.Title.acknowledgements) {
                ForEach(acknowledgements) { acknowledgement in
                    LinkRow(urlString: acknowledgement.urlString, text: acknowledgement.text)
                }
            }
        }
        .navigationTitle(L10n.Localizable.AboutView.Title.ehPanda)
    }

    // MARK: Contacts
    private let contacts: [Info] = {[
        .init(
            urlString: L10n.Constant.App.Contact.Link.website,
            text: L10n.Localizable.AboutView.Button.website
        ),
        .init(
            urlString: L10n.Constant.App.Contact.Link.gitHub,
            text: L10n.Constant.App.Contact.Text.gitHub
        ),
        .init(
            urlString: L10n.Constant.App.Contact.Link.discord,
            text: L10n.Constant.App.Contact.Text.discord
        ),
        .init(
            urlString: L10n.Constant.App.Contact.Link.telegram,
            text: L10n.Constant.App.Contact.Text.telegram
        ),
        .init(
            urlString: L10n.Constant.App.Contact.Link.altStore,
            text: L10n.Localizable.AboutView.Button.altStoreSource
        )
    ]}()

    // MARK: Special thanks
    private let specialThanks: [Info] = {[
        .init(
            urlString: L10n.Constant.App.SpecialThanks.Link.taylorlannister,
            text: L10n.Constant.App.SpecialThanks.Text.taylorlannister
        ),
        .init(
            urlString: L10n.Constant.App.SpecialThanks.Link.luminescentYq,
            text: L10n.Constant.App.SpecialThanks.Text.luminescentYq
        ),
        .init(
            urlString: L10n.Constant.App.SpecialThanks.Link.caxerx,
            text: L10n.Constant.App.SpecialThanks.Text.caxerx
        ),
        .init(
            urlString: L10n.Constant.App.SpecialThanks.Link.honjow,
            text: L10n.Constant.App.SpecialThanks.Text.honjow
        )
    ]}()

    // MARK: Code level contributors
    private let codeLevelContributors: [Info] = {[
        .init(
            urlString: L10n.Constant.App.CodeLevelContributor.Link.tatsuz0u,
            text: L10n.Constant.App.CodeLevelContributor.Text.tatsuz0u
        ),
        .init(
            urlString: L10n.Constant.App.CodeLevelContributor.Link.chihchy,
            text: L10n.Constant.App.CodeLevelContributor.Text.chihchy
        ),
        .init(
            urlString: L10n.Constant.App.CodeLevelContributor.Link.xioxin,
            text: L10n.Constant.App.CodeLevelContributor.Text.xioxin
        ),
        .init(
            urlString: L10n.Constant.App.CodeLevelContributor.Link.ethanChinCN,
            text: L10n.Constant.App.CodeLevelContributor.Text.ethanChinCN
        ),
        .init(
            urlString: L10n.Constant.App.CodeLevelContributor.Link.lengYue,
            text: L10n.Constant.App.CodeLevelContributor.Text.lengYue
        )
    ]}()

    // MARK: Translation contributors
    private let translationContributors: [Info] = {[
        .init(
            urlString: L10n.Constant.App.TranslationContributor.Link.tatsuz0u,
            text: L10n.Constant.App.TranslationContributor.Text.tatsuz0u
        ),
        .init(
            urlString: L10n.Constant.App.TranslationContributor.Link.nebulosaCat,
            text: L10n.Constant.App.TranslationContributor.Text.nebulosaCat
        ),
        .init(
            urlString: L10n.Constant.App.TranslationContributor.Link.paulHaeussler,
            text: L10n.Constant.App.TranslationContributor.Text.paulHaeussler
        ),
        .init(
            urlString: L10n.Constant.App.TranslationContributor.Link.caxerx,
            text: L10n.Constant.App.TranslationContributor.Text.caxerx
        ),
        .init(
            urlString: L10n.Constant.App.TranslationContributor.Link.nyaanim,
            text: L10n.Constant.App.TranslationContributor.Text.nyaanim
        )
    ]}()

    // MARK: Acknowledgements
    private let acknowledgements: [Info] = {[
        .init(
            urlString: L10n.Constant.App.Acknowledgement.Link.kanna,
            text: L10n.Constant.App.Acknowledgement.Text.kanna
        ),
        .init(
            urlString: L10n.Constant.App.Acknowledgement.Link.swiftGen,
            text: L10n.Constant.App.Acknowledgement.Text.swiftGen
        ),
        .init(
            urlString: L10n.Constant.App.Acknowledgement.Link.alertKit,
            text: L10n.Constant.App.Acknowledgement.Text.alertKit
        ),
        .init(
            urlString: L10n.Constant.App.Acknowledgement.Link.colorful,
            text: L10n.Constant.App.Acknowledgement.Text.colorful
        ),
        .init(
            urlString: L10n.Constant.App.Acknowledgement.Link.filePicker,
            text: L10n.Constant.App.Acknowledgement.Text.filePicker
        ),
        .init(
            urlString: L10n.Constant.App.Acknowledgement.Link.kingfisher,
            text: L10n.Constant.App.Acknowledgement.Text.kingfisher
        ),
        .init(
            urlString: L10n.Constant.App.Acknowledgement.Link.swiftUIPager,
            text: L10n.Constant.App.Acknowledgement.Text.swiftUIPager
        ),
        .init(
            urlString: L10n.Constant.App.Acknowledgement.Link.swiftyBeaver,
            text: L10n.Constant.App.Acknowledgement.Text.swiftyBeaver
        ),
        .init(
            urlString: L10n.Constant.App.Acknowledgement.Link.waterfallGrid,
            text: L10n.Constant.App.Acknowledgement.Text.waterfallGrid
        ),
        .init(
            urlString: L10n.Constant.App.Acknowledgement.Link.swiftyOpenCC,
            text: L10n.Constant.App.Acknowledgement.Text.swiftyOpenCC
        ),
        .init(
            urlString: L10n.Constant.App.Acknowledgement.Link.uiImageColors,
            text: L10n.Constant.App.Acknowledgement.Text.uiImageColors
        ),
        .init(
            urlString: L10n.Constant.App.Acknowledgement.Link.sfSafeSymbols,
            text: L10n.Constant.App.Acknowledgement.Text.sfSafeSymbols
        ),
        .init(
            urlString: L10n.Constant.App.Acknowledgement.Link.ttProgressHUD,
            text: L10n.Constant.App.Acknowledgement.Text.ttProgressHUD
        ),
        .init(
            urlString: L10n.Constant.App.Acknowledgement.Link.swiftUINavigation,
            text: L10n.Constant.App.Acknowledgement.Text.swiftUINavigation
        ),
        .init(
            urlString: L10n.Constant.App.Acknowledgement.Link.swiftCommonMark,
            text: L10n.Constant.App.Acknowledgement.Text.swiftCommonMark
        ),
        .init(
            urlString: L10n.Constant.App.Acknowledgement.Link.ehTagTranslationDatabase,
            text: L10n.Constant.App.Acknowledgement.Text.ehTagTranslationDatabase
        ),
        .init(
            urlString: L10n.Constant.App.Acknowledgement.Link.tca,
            text: L10n.Constant.App.Acknowledgement.Text.tca
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
            AboutView()
        }
    }
}
