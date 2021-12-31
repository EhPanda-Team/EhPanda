//
//  EhPandaView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI

struct EhPandaView: View {
    private var contacts: [Info] {[
        Info(url: "https://ehpanda.app", text: "Website".localized),
        Info(url: "https://github.com/tatsuz0u/EhPanda", text: "GitHub"),
        Info(url: "https://discord.gg/BSBE9FCBTq", text: "Discord"),
        Info(url: "https://t.me/ehpanda", text: "Telegram"),
        Info(
            url: "altstore://source?url=https://github.com/tatsuz0u/EhPanda/raw/main/AltStore.json",
            text: "AltStore Source".localized
        )
    ]}

    private var acknowledgements: [Info] {[
        Info(url: "https://github.com/taylorlannister", text: "taylorlannister"),
        Info(url: "https://github.com/caxerx", text: "caxerx"),
        Info(url: "https://github.com/honjow", text: "honjow"),
        Info(url: "https://github.com/tid-kijyun/Kanna", text: "Kanna"),
        Info(url: "https://github.com/rebeloper/AlertKit", text: "AlertKit"),
        Info(url: "https://github.com/onevcat/Kingfisher", text: "Kingfisher"),
        Info(url: "https://github.com/fermoya/SwiftUIPager", text: "SwiftUIPager"),
        Info(url: "https://github.com/SwiftyBeaver/SwiftyBeaver", text: "SwiftyBeaver"),
        Info(url: "https://github.com/paololeonardi/WaterfallGrid", text: "WaterfallGrid"),
        Info(url: "https://github.com/ddddxxx/SwiftyOpenCC", text: "SwiftyOpenCC"),
        Info(url: "https://github.com/honkmaster/TTProgressHUD", text: "TTProgressHUD"),
        Info(url: "https://github.com/EhTagTranslation/Database", text: "EhTagTranslation/Database")
    ]}

    private var version: String {
        ["Version".localized, AppUtil.version, "(\(AppUtil.build))"].joined(separator: " ")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Copyright © 2021 荒木辰造").captionTextStyle()
                Text(version).captionTextStyle()
            }
            Spacer()
        }
        .padding(.horizontal)
        Form {
            Section {
                ForEach(contacts) { contact in
                    LinkRow(url: contact.url.safeURL(), text: contact.text)
                }
            }
            Section("Acknowledgement".localized) {
                ForEach(acknowledgements) { acknowledgement in
                    LinkRow(url: acknowledgement.url.safeURL(), text: acknowledgement.text)
                }
            }
        }
        .navigationBarTitle("EhPanda")
    }
}

private struct Info: Identifiable {
    var id: String { url }

    let url: String
    let text: String
}

private struct LinkRow: View {
    let url: URL
    let text: String

    var body: some View {
        Link(destination: url, label: {
            Text(text).fontWeight(.medium).foregroundColor(.primary).withArrow()
        })
    }
}

private extension Text {
    func captionTextStyle() -> some View {
        foregroundStyle(.gray).font(.caption2.bold())
    }
}
