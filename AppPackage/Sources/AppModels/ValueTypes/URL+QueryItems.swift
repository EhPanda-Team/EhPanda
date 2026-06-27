import Foundation

extension URL {
    public func appending(queryItems: [URLQueryItem]) -> URL {
        guard !queryItems.isEmpty else { return self }
        var components: URLComponents = .init(
            url: self, resolvingAgainstBaseURL: false
        )
        .forceUnwrapped
        if components.queryItems == nil {
            components.queryItems = []
        }
        components.queryItems?.append(contentsOf: queryItems)
        return components.url.forceUnwrapped
    }
    public func appending(queryItems: [String: String]) -> URL {
        appending(queryItems: queryItems.map(URLQueryItem.init))
    }
    public func appending(queryItems: [Defaults.URL.Component.Key: Defaults.URL.Component.Value]) -> URL {
        appending(queryItems: queryItems.map({ URLQueryItem(name: $0.rawValue, value: $1.rawValue) }))
    }
    public func appending(queryItems: [Defaults.URL.Component.Key: String]) -> URL {
        appending(queryItems: queryItems.map({ URLQueryItem(name: $0.rawValue, value: $1) }))
    }
    public mutating func append(queryItems: [URLQueryItem]) {
        self = appending(queryItems: queryItems)
    }
    public mutating func append(queryItems: [String: String]) {
        self = appending(queryItems: queryItems)
    }
    public mutating func append(queryItems: [Defaults.URL.Component.Key: Defaults.URL.Component.Value]) {
        self = appending(queryItems: queryItems)
    }
    public mutating func append(queryItems: [Defaults.URL.Component.Key: String]) {
        self = appending(queryItems: queryItems)
    }
}
