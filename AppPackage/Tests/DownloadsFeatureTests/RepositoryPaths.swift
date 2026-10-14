import Foundation

/// Source inventories need the same relative names regardless of URL directory hints.
func repositoryRelativePath(of url: URL, under root: URL) -> String {
    let components = url.standardizedFileURL.pathComponents
    let rootComponents = root.standardizedFileURL.pathComponents
    guard components.count > rootComponents.count, components.starts(with: rootComponents) else {
        return url.standardizedFileURL.path(percentEncoded: false)
    }
    return components.dropFirst(rootComponents.count).joined(separator: "/")
}
