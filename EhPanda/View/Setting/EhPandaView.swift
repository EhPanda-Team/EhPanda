//
//  EhPandaView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI

struct EhPandaView: View {
    private let contacts: [Info] = {[
        .init(urlString: "https://ehpanda.app", text: R.string.localizable.ehpandaViewButtonWebsite()),
        .init(urlString: "https://github.com/tatsuz0u/EhPanda", text: "GitHub"),
        .init(urlString: "https://discord.gg/BSBE9FCBTq", text: "Discord"),
        .init(urlString: "https://t.me/ehpanda", text: "Telegram"),
        .init(
            urlString: "altstore://source?url=https://github.com/tatsuz0u/EhPanda/raw/main/AltStore.json",
            text: R.string.localizable.ehpandaViewButtonAltStoreSource()
        )
    ]}()

    private let specialThanks: [Info] = {[
        .init(urlString: "https://github.com/taylorlannister", text: "taylorlannister"),
        .init(urlString: "", text: "Luminescent_yq"),
        .init(urlString: "https://github.com/caxerx", text: "caxerx"),
        .init(urlString: "https://github.com/honjow", text: "honjow")
    ]}()

    private let acknowledgements: [Info] = {[
        .init(urlString: "https://github.com/tid-kijyun/Kanna", text: "Kanna"),
        .init(urlString: "https://github.com/mac-cain13/R.swift", text: "R.swift"),
        .init(urlString: "https://github.com/rebeloper/AlertKit", text: "AlertKit"),
        .init(urlString: "https://github.com/Co2333/Colorful", text: "Colorful"),
        .init(urlString: "https://github.com/onevcat/Kingfisher", text: "Kingfisher"),
        .init(urlString: "https://github.com/fermoya/SwiftUIPager", text: "SwiftUIPager"),
        .init(urlString: "https://github.com/SwiftyBeaver/SwiftyBeaver", text: "SwiftyBeaver"),
        .init(urlString: "https://github.com/paololeonardi/WaterfallGrid", text: "WaterfallGrid"),
        .init(urlString: "https://github.com/ddddxxx/SwiftyOpenCC", text: "SwiftyOpenCC"),
        .init(urlString: "https://github.com/jathu/UIImageColors", text: "UIImageColors"),
        .init(urlString: "https://github.com/SFSafeSymbols/SFSafeSymbols", text: "SFSafeSymbols"),
        .init(urlString: "https://github.com/honkmaster/TTProgressHUD", text: "TTProgressHUD"),
        .init(urlString: "https://github.com/pointfreeco/swiftui-navigation", text: "SwiftUI Navigation"),
        .init(urlString: "https://github.com/EhTagTranslation/Database", text: "EhTagTranslation/Database"),
        .init(
            urlString: "https://github.com/pointfreeco/swift-composable-architecture",
            text: "The Composable Architecture"
        )
    ]}()

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
                Text("Copyright © 2022 荒木辰造").captionTextStyle()
                Text(version).captionTextStyle()
            }
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
            Section(R.string.localizable.ehpandaViewSectionTitleAcknowledgements()) {
                ForEach(acknowledgements) { acknowledgement in
                    LinkRow(urlString: acknowledgement.urlString, text: acknowledgement.text)
                }
            }
        }
        .navigationTitle(R.string.localizable.enumSettingStateRouteValueEhPanda())
    }
}

private struct Info: Identifiable {
    var id: String { urlString }

    let urlString: String
    let text: String
}

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

private extension Text {
    func captionTextStyle() -> some View {
        foregroundStyle(.gray).font(.caption2.bold())
    }
}

struct EhPandaView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EhPandaView()
        }
    }
}
