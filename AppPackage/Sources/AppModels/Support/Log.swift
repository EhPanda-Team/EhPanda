public struct Log: Identifiable, Comparable, Sendable {
    public static func < (lhs: Log, rhs: Log) -> Bool {
        lhs.fileName < rhs.fileName
    }

    public var id: String { fileName }
    public let fileName: String
    public let contents: [String]

    public init(fileName: String, contents: [String]) {
        self.fileName = fileName
        self.contents = contents
    }
}

extension Log: CustomStringConvertible {
    public var description: String {
        let params = String(
            describing: [
                "fileName": fileName,
                "contentsCount": contents.count
            ]
            as [String: Any]
        )
        return "Log(\(params))"
    }
}
