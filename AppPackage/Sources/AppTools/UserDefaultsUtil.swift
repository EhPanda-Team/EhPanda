import Foundation

public struct UserDefaultsUtil {
    public static func value<T: Codable>(forKey key: AppUserDefaults) -> T? {
        UserDefaults.standard.value(forKey: key.rawValue) as? T
    }
}

public enum AppUserDefaults: String {
    case clipboardChangeCount
}
