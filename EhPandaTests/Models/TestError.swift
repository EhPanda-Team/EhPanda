//
//  TestError.swift
//  EhPandaTests
//

enum TestError: Error {
    case htmlDocumentNotFound(HTMLFilename)
    case parsingFailed(String)
}

extension TestError {
    var localizedDescription: String {
        switch self {
        case .htmlDocumentNotFound(let filename):
            return "HTML document \(filename.rawValue) not found."
        case .parsingFailed(let type):
            return "Failed in parsing \(type)."
        }
    }
}
