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
                .environmentObject(Settings())
        }
    }
}
