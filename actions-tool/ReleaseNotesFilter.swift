//
//  main.swift
//  EnglishFilter
//
//  Created by 荒木辰造 on R 3/09/12.
//

import Foundation

guard let releaseNotes = CommandLine.arguments.dropFirst().first else {
    FileHandle.standardError.write(Data("Usage: ReleaseNotesFilter <release-notes>\n".utf8))
    exit(EXIT_FAILURE)
}

print(
    releaseNotes
        .split(separator: "\r\n")
        .map(String.init)
        .filter({
            Array(0...100)
                .map({ .init($0) + ". " })
                .contains(where: $0.hasPrefix)
        })
        .joined(separator: "\\n")
)
