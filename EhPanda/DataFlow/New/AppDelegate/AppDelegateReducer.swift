//
//  AppDelegateReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import SwiftUI
import SwiftyBeaver
import ComposableArchitecture

let appDelegateReducer = Reducer<Bool, AppDelegateAction, AppDelegateEnvironment> { state, action, _ in
    Logger.info(action)
    switch action {
    case .didFinishLaunching:
        AppUtil.dispatchMainSync {
            configureWebImage(bypassesSNIFiltering: state)
            configureDomainFronting(bypassesSNIFiltering: state)
        }
        configureTabBar()
        configureLogging()
        configureIgnoreOffensive()

        Logger.info(action)
        return .none
    }
}

// MARK: Configuration
private func configureLogging() {
    var file = FileDestination()
    var console = ConsoleDestination()
    let format = [
        "$Dyyyy-MM-dd HH:mm:ss.SSS$d",
        "$C$L$c $N.$F:$l - $M $X"
    ].joined(separator: " ")

    file.format = format
    console.format = format
    configure(file: &file)
    configure(console: &console)

    Logger.addDestination(file)
#if DEBUG
    guard !AppUtil.isUnitTesting else { return }
    Logger.addDestination(console)
#endif
}
private func configure(file: inout FileDestination) {
    file.logFileAmount = 10
    file.calendar = Calendar(identifier: .gregorian)
    file.logFileURL = FileUtil.logsDirectoryURL?
        .appendingPathComponent(Defaults.FilePath.ehpandaLog)
}
private func configure(console: inout ConsoleDestination) {
    console.calendar = Calendar(identifier: .gregorian)
#if DEBUG
    console.asynchronously = false
#endif
    console.levelColor.verbose = "😪"
    console.levelColor.warning = "⚠️"
    console.levelColor.error = "‼️"
    console.levelColor.debug = "🐛"
    console.levelColor.info = "📖"
}

private func configureTabBar() {
    let apparence = UITabBarAppearance()
    apparence.configureWithOpaqueBackground()
    UITabBar.appearance().scrollEdgeAppearance = apparence
}
private func configureWebImage(bypassesSNIFiltering: Bool) {
    AppUtil.configureKingfisher(bypassesSNIFiltering: bypassesSNIFiltering)
}
private func configureDomainFronting(bypassesSNIFiltering: Bool) {
    guard bypassesSNIFiltering else { return }
    URLProtocol.registerClass(DFURLProtocol.self)
}
private func configureIgnoreOffensive() {
    CookiesUtil.set(for: Defaults.URL.ehentai.safeURL(), key: "nw", value: "1")
    CookiesUtil.set(for: Defaults.URL.exhentai.safeURL(), key: "nw", value: "1")
}
