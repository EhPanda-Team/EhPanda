//
//  EhPandaApp.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI

@main
struct EhPandaApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(Store())
                .onOpenURL(perform: { url in
                    let entry = url.absoluteString
                    guard let range = entry.range(of: "//") else { return }
                    let key = String(entry.suffix(from: range.upperBound))
                    UserDefaults.standard.set(key, forKey: "entry")
                })
        }
    }
}
