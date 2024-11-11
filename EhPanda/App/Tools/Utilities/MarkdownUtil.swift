//
//  MarkdownUtil.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/20.
//

import CasePaths
import CommonMark
import Foundation

struct MarkdownUtil {
    static func parseTexts(markdown: String) -> [String] {
        (try? Document(markdown: markdown))?.blocks
            .compactMap({ $0[case: \.paragraph] })
            .flatMap(\.text)
            .compactMap({ $0[case: \.text] })
        ?? []
    }
    static func parseLinks(markdown: String) -> [URL] {
        (try? Document(markdown: markdown))?.blocks
            .compactMap({ $0[case: \.paragraph] })
            .flatMap(\.text)
            .compactMap({ $0[case: \.link] })
            .compactMap(\.url)
        ?? []
    }
    static func parseImages(markdown: String) -> [URL] {
        (try? Document(markdown: markdown))?.blocks
            .compactMap({ $0[case: \.paragraph] })
            .flatMap(\.text)
            .compactMap({ $0[case: \.image] })
            .compactMap { image in
                if image.url?.absoluteString.isValidURL == true {
                    return image.url
                } else if let title = image.title, title.isValidURL {
                    return .init(string: title)
                }
                return nil
            }
        ?? []
    }
}

// MARK: CasePathable
extension Block: @retroactive CasePathable, @retroactive CasePathIterable {
    public struct AllCasePaths: CasePathReflectable, Sendable {
        public subscript(root: Block) -> PartialCaseKeyPath<Block> {
            switch root {
            case .blockQuote: \.blockQuote
            case .bulletList: \.bulletList
            case .orderedList: \.orderedList
            case .code: \.code
            case .html: \.html
            case .paragraph: \.paragraph
            case .heading: \.heading
            case .thematicBreak: \.thematicBreak
            }
        }

        // swiftlint:disable line_length
        public var blockQuote: AnyCasePath<Block, BlockQuote> {
            AnyCasePath(embed: { .blockQuote($0) }, extract: { if case .blockQuote(let value) = $0 { return value } else { return nil }})
        }
        public var bulletList: AnyCasePath<Block, BulletList> {
            AnyCasePath(embed: { .bulletList($0) }, extract: { if case .bulletList(let value) = $0 { return value } else { return nil }})
        }
        public var orderedList: AnyCasePath<Block, OrderedList> {
            AnyCasePath(embed: { .orderedList($0) }, extract: { if case .orderedList(let value) = $0 { return value } else { return nil }})
        }
        public var code: AnyCasePath<Block, CodeBlock> {
            AnyCasePath(embed: { .code($0) }, extract: { if case .code(let value) = $0 { return value } else { return nil }})
        }
        public var html: AnyCasePath<Block, HTMLBlock> {
            AnyCasePath(embed: { .html($0) }, extract: { if case .html(let value) = $0 { return value } else { return nil }})
        }
        public var paragraph: AnyCasePath<Block, Paragraph> {
            AnyCasePath(embed: { .paragraph($0) }, extract: { if case .paragraph(let value) = $0 { return value } else { return nil }})
        }
        public var heading: AnyCasePath<Block, Heading> {
            AnyCasePath(embed: { .heading($0) }, extract: { if case .heading(let value) = $0 { return value } else { return nil }})
        }
        public var thematicBreak: AnyCasePath<Block, Void> {
            AnyCasePath(embed: { .thematicBreak }, extract: { if case .thematicBreak = $0 { return () } else { return nil }})
        }
        // swiftlint:enable line_length
    }

    public static var allCasePaths: AllCasePaths {
        AllCasePaths()
    }
}

extension Block.AllCasePaths: Sequence {
    public func makeIterator() -> some IteratorProtocol<PartialCaseKeyPath<Block>> {
        [
            \.blockQuote,
             \.bulletList,
             \.orderedList,
             \.code,
             \.html,
             \.paragraph,
             \.heading,
             \.thematicBreak
        ]
        .makeIterator()
    }
}

extension Inline: @retroactive CasePathable, @retroactive CasePathIterable {
    public struct AllCasePaths: CasePathReflectable, Sendable {
        public subscript(root: Inline) -> PartialCaseKeyPath<Inline> {
            switch root {
            case .text: \.text
            case .softBreak: \.softBreak
            case .lineBreak: \.lineBreak
            case .code: \.code
            case .html: \.html
            case .emphasis: \.emphasis
            case .strong: \.strong
            case .link: \.link
            case .image: \.image
            }
        }

        // swiftlint:disable line_length
        public var text: AnyCasePath<Inline, String> {
            AnyCasePath(embed: { .text($0) }, extract: { if case .text(let value) = $0 { return value } else { return nil }})
        }
        public var softBreak: AnyCasePath<Inline, Void> {
            AnyCasePath(embed: { .softBreak }, extract: { if case .softBreak = $0 { return () } else { return nil }})
        }
        public var lineBreak: AnyCasePath<Inline, Void> {
            AnyCasePath(embed: { .lineBreak }, extract: { if case .lineBreak = $0 { return () } else { return nil }})
        }
        public var code: AnyCasePath<Inline, InlineCode> {
            AnyCasePath(embed: { .code($0) }, extract: { if case .code(let value) = $0 { return value } else { return nil }})
        }
        public var html: AnyCasePath<Inline, InlineHTML> {
            AnyCasePath(embed: { .html($0) }, extract: { if case .html(let value) = $0 { return value } else { return nil }})
        }
        public var emphasis: AnyCasePath<Inline, Emphasis> {
            AnyCasePath(embed: { .emphasis($0) }, extract: { if case .emphasis(let value) = $0 { return value } else { return nil }})
        }
        public var strong: AnyCasePath<Inline, Strong> {
            AnyCasePath(embed: { .strong($0) }, extract: { if case .strong(let value) = $0 { return value } else { return nil }})
        }
        public var link: AnyCasePath<Inline, Link> {
            AnyCasePath(embed: { .link($0) }, extract: { if case .link(let value) = $0 { return value } else { return nil }})
        }
        public var image: AnyCasePath<Inline, Image> {
            AnyCasePath(embed: { .image($0) }, extract: { if case .image(let value) = $0 { return value } else { return nil }})
        }
        // swiftlint:enable line_length
    }

    public static var allCasePaths: AllCasePaths {
        AllCasePaths()
    }
}

extension Inline.AllCasePaths: Sequence {
    public func makeIterator() -> some IteratorProtocol<PartialCaseKeyPath<Inline>> {
        [
            \.text,
             \.softBreak,
             \.lineBreak,
             \.code,
             \.html,
             \.emphasis,
             \.strong,
             \.link,
             \.image
        ]
        .makeIterator()
    }
}
