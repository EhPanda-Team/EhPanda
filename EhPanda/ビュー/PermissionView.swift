//
//  PermissionView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/12.
//

import SwiftUI

struct PermissionView: View {
    var ehURL: URL {
        URL(string: Defaults.URL.ehentai)!
    }
    var exURL: URL {
        URL(string: Defaults.URL.exhentai)!
    }
    var igneous: String {
        cookieValue(url: exURL, cookieName: "igneous")
    }
    var ehMemberID: String {
        cookieValue(url: ehURL, cookieName: "ipb_member_id")
    }
    var exMemberID: String {
        cookieValue(url: exURL, cookieName: "ipb_member_id")
    }
    var ehPassHash: String {
        cookieValue(url: ehURL, cookieName: "ipb_pass_hash")
    }
    var exPassHash: String {
        cookieValue(url: exURL, cookieName: "ipb_pass_hash")
    }
    
    var verifiedView: some View {
        Image(systemName: "checkmark.circle")
            .foregroundColor(.green)
    }
    var notVerifiedView: some View {
        Image(systemName: "xmark.circle")
            .foregroundColor(.red)
    }
    
    var body: some View {
        Form {
            Section(header: Text("E-Hentai")) {
                HStack {
                    Text("ipb_member_id")
                    Spacer()
                    Text(ehMemberID)
                    verifyView(ehMemberID)
                }
                HStack {
                    Text("ipb_pass_hash")
                    Spacer()
                    Text(ehPassHash)
                        .lineLimit(1)
                    verifyView(ehPassHash)
                }
                Button("クッキーをコピー", action: copyEhCookies)
            }
            Section(header: Text("ExHentai")) {
                HStack {
                    Text("igneous")
                    Spacer()
                    Text(igneous)
                        .lineLimit(1)
                    verifyView(igneous)
                }
                HStack {
                    Text("ipb_member_id")
                    Spacer()
                    Text(exMemberID)
                    verifyView(exMemberID)
                }
                HStack {
                    Text("ipb_pass_hash")
                    Spacer()
                    Text(exPassHash)
                        .lineLimit(1)
                    verifyView(exPassHash)
                }
                Button("クッキーをコピー", action: copyExCookies)
            }
        }
        .navigationBarTitle("権限")
        
    }
    
    func verifyView(_ value: String) -> some View {
        let notVerified = ["なし", "期限切れ", "mystery"]
            .map { $0.lString() }.contains(value)
        return Group {
            if notVerified {
                notVerifiedView
            } else {
                verifiedView
            }
        }
    }
    
    func cookieValue(url: URL, cookieName: String) -> String {
        if let value = getCookieValue(
            url: url,
            cookieName: cookieName
        ), !value.isEmpty
        {
            return value
        } else {
            return "なし".lString()
        }
    }
    
    func copyEhCookies() {
        let cookies = "ipb_member_id: \(ehMemberID)"
        + "\nipb_pass_hash: \(ehPassHash)"
        UIPasteboard.general.string = cookies
        hapticFeedback(style: .medium)
    }
    func copyExCookies() {
        let cookies = "igneous: \(igneous)"
        + "\nipb_member_id: \(ehMemberID)"
        + "\nipb_pass_hash: \(ehPassHash)"
        UIPasteboard.general.string = cookies
        hapticFeedback(style: .medium)
    }
}
