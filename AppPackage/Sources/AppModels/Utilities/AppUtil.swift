import Foundation

public struct AppUtil {
    public static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "null"
    }
    public static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "null"
    }

    private static let internalIsTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    public static var isTesting: Bool {
        #if DEBUG
        internalIsTesting
        #else
        false
        #endif
    }

    public static func dispatchMainSync(execute work: () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
    }
}
