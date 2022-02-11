//
//  main.swift
//  EnglishFilter
//
//  Created by 荒木辰造 on R 3/09/12.
//

import Foundation

print(
    CommandLine.arguments[1]
        .split(separator: "\r\n")
        .map(String.init)
        .filter({
            Array(0...100)
                .map({ .init($0) + ". " })
                .contains(where: $0.hasPrefix)
        })
        .joined(separator: "\\n")
)
