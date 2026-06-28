import Foundation

public extension URL {
    func modifyComponent(for url: URL, commitChanges: (inout URLComponents) -> Void) -> URL? {
        guard var components = URLComponents(
            url: self, resolvingAgainstBaseURL: false
        )
        else { return nil }
        commitChanges(&components)
        return components.url
    }
    func replaceHost(to newHost: String?) -> URL? {
        modifyComponent(for: self) { components in
            components.host = newHost
        }
    }
    func replaceScheme(to newScheme: String?) -> URL? {
        modifyComponent(for: self) { components in
            components.scheme = newScheme
        }
    }
}
