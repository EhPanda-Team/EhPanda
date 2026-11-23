import Foundation
import Testing

/// The source scanner behind the pointer hover audit (D-08): is a hover helper after every plain button style, tap
/// gesture and custom `ButtonStyle`? Source text is only trustworthy when read the way the compiler reads it, so
/// three passes come first, each keeping the byte length and the line breaks: (1) comments, strings of every kind
/// and non-ASCII bytes become spaces, so a site or helper named there does not count; (2) `#if` is evaluated for iOS,
/// the only platform the package builds for; (3) `#Preview` bodies, compiled into the app but never shown, go blank.
enum PointerHoverScanner {
    /// The kinds of control the audit reads.
    enum SiteKind: String, CaseIterable, Sendable {
        case plainButtonStyle, plainButtonStyleInitializer, onTapGesture
        case tapGesture, spatialTapGesture, buttonStyleConformance
    }

    /// One audited site: what it is, where it is, and whether a hover helper follows it.
    struct Site: Equatable, Sendable {
        let kind: SiteKind
        let offset: Int
        let passes: Bool
    }

    /// A scan held against its allowlist; keys are `"<file>|<kind>"`.
    struct Evaluation: Equatable, Sendable {
        /// Non-passing sites no allowance covers, with the live count.
        var unlisted = [String: Int]()
        /// Allowances whose count differs from the live non-passing count, with the live count.
        var stale = [String: Int]()
        /// Allowances that carry no reason.
        var reasonless = [String]()

        var isClean: Bool {
            unlisted.isEmpty && stale.isEmpty && reasonless.isEmpty
        }
    }

    /// The members that count as a hover after a site.
    static let hoverMembers: Set<String> = ["interactiveHover", "interactiveIconHover", "cellRowHover"]
    /// The members a custom button style may carry in its body instead.
    private static let hoverCalls = hoverMembers.map({ ".\($0)(" })
}

extension PointerHoverScanner {
    /// `source` with comments, strings, non-ASCII bytes, inactive `#if` branches and `#Preview` bodies blanked.
    ///
    /// The result is ASCII of the same byte length, with every line break kept.
    static func preprocessed(_ source: String) -> String {
        var blanker = CommentAndStringBlanker(source: Array(source.utf8))
        return ascii(blankingPreviewBlocks(in: ConditionalEvaluator.evaluate(blanker.blankedBytes())))
    }

    private static func blankingPreviewBlocks(in bytes: [UInt8]) -> [UInt8] {
        var output = bytes
        let marker = "#Preview"
        for start in indices(of: marker, in: bytes) {
            var cursor = skipWhitespace(in: bytes, from: start + marker.utf8.count)
            if bytes[safe: cursor] == Ascii.openParen {
                guard let after = matchingClose(in: bytes, openingAt: cursor) else { continue }
                cursor = skipWhitespace(in: bytes, from: after)
            }
            guard bytes[safe: cursor] == Ascii.openBrace,
                  let after = matchingClose(in: bytes, openingAt: cursor) else { continue }
            blank(&output, in: cursor..<after)
        }
        return output
    }
}

extension PointerHoverScanner {
    /// The audited sites of one preprocessed file, in order of appearance.
    static func sites(in processed: String) -> [Site] {
        let bytes = Array(processed.utf8)
        let found = plainButtonStyleSites(in: bytes)
            + onTapGestureSites(in: bytes)
            + valueSites(in: bytes)
            + conformanceSites(in: bytes)
        return found.sorted(by: { $0.offset < $1.offset })
    }

    /// Whether a file sets the icon tap shape by hand: `contentShape(.interaction, HoverTargetCircle…)`.
    ///
    /// Only the icon helper may do that, because the same circle is the tap area and the hover area, and a second
    /// writer is how the two drift apart.
    static func setsIconTapShape(_ processed: String) -> Bool {
        let bytes = Array(processed.utf8)
        let call = "contentShape("
        for start in indices(of: call, in: bytes) {
            var cursor = skipWhitespace(in: bytes, from: start + call.utf8.count)
            guard matches(".interaction", at: cursor, in: bytes) else { continue }
            cursor = skipWhitespace(in: bytes, from: cursor + ".interaction".utf8.count)
            guard bytes[safe: cursor] == Ascii.comma else { continue }
            cursor = skipWhitespace(in: bytes, from: cursor + 1)
            if matches("HoverTargetCircle", at: cursor, in: bytes) {
                return true
            }
        }
        return false
    }

    private static func plainButtonStyleSites(in bytes: [UInt8]) -> [Site] {
        let call = ".buttonStyle("
        var found = [Site]()
        for start in indices(of: call, in: bytes) {
            var cursor = skipWhitespace(in: bytes, from: start + call.utf8.count)
            guard matches(".plain", at: cursor, in: bytes) else { continue }
            cursor += ".plain".utf8.count
            guard !isIdentifier(bytes[safe: cursor]) else { continue }
            cursor = skipWhitespace(in: bytes, from: cursor)
            guard bytes[safe: cursor] == Ascii.closeParen else { continue }
            let passes = chainPasses(afterMemberAt: start, in: bytes)
            found.append(Site(kind: .plainButtonStyle, offset: start, passes: passes))
        }
        return found
    }

    private static func onTapGestureSites(in bytes: [UInt8]) -> [Site] {
        let member = ".onTapGesture"
        var found = [Site]()
        for start in indices(of: member, in: bytes) where !isIdentifier(bytes[safe: start + member.utf8.count]) {
            let passes = chainPasses(afterMemberAt: start, in: bytes)
            found.append(Site(kind: .onTapGesture, offset: start, passes: passes))
        }
        return found
    }

    private struct ValueToken {
        let name: String
        let kind: SiteKind
        let requiresEmptyCall: Bool
    }

    private static let valueTokens = [
        ValueToken(name: "TapGesture", kind: .tapGesture, requiresEmptyCall: false),
        ValueToken(name: "SpatialTapGesture", kind: .spatialTapGesture, requiresEmptyCall: false),
        ValueToken(name: "PlainButtonStyle", kind: .plainButtonStyleInitializer, requiresEmptyCall: true)
    ]

    /// Sites that are values. A value is no modifier, so it reads the chain of the outermost enclosing `.member(`
    /// call (`.buttonStyle(PlainButtonStyle())`, `.simultaneousGesture(TapGesture())`), or its own postfix members.
    private static func valueSites(in bytes: [UInt8]) -> [Site] {
        var found = [Site]()
        for token in valueTokens {
            for start in indices(of: token.name, in: bytes) {
                let nameEnd = start + token.name.utf8.count
                guard !isIdentifier(bytes[safe: start - 1]), !isIdentifier(bytes[safe: nameEnd]) else { continue }
                var valueEnd = nameEnd
                let argumentsStart = skipInlineSpaces(in: bytes, from: nameEnd)
                if bytes[safe: argumentsStart] == Ascii.openParen,
                   let after = matchingClose(in: bytes, openingAt: argumentsStart) {
                    valueEnd = after
                }
                let emptyCallEnd = skipWhitespace(in: bytes, from: argumentsStart + 1)
                if token.requiresEmptyCall, bytes[safe: emptyCallEnd] != Ascii.closeParen {
                    continue
                }
                let passes: Bool
                if let dot = outermostEnclosingMemberCall(before: start, in: bytes) {
                    passes = chainPasses(afterMemberAt: dot, in: bytes)
                } else {
                    passes = !hoverMembers.isDisjoint(with: chainMembers(from: valueEnd, in: bytes))
                }
                found.append(Site(kind: token.kind, offset: start, passes: passes))
            }
        }
        return found
    }

    /// `struct Name: …ButtonStyle…` or `…PrimitiveButtonStyle…`; it passes when its body holds a helper.
    private static func conformanceSites(in bytes: [UInt8]) -> [Site] {
        var found = [Site]()
        for start in indices(of: "struct", in: bytes) {
            guard !isIdentifier(bytes[safe: start - 1]), !isIdentifier(bytes[safe: start + 6]) else { continue }
            var cursor = skipWhitespace(in: bytes, from: start + 6)
            let nameStart = cursor
            while isIdentifier(bytes[safe: cursor]) { cursor += 1 }
            guard cursor > nameStart else { continue }
            cursor = skipWhitespace(in: bytes, from: cursor)
            if bytes[safe: cursor] == Ascii.lessThan {
                guard let after = matchingClose(in: bytes, openingAt: cursor) else { continue }
                cursor = skipWhitespace(in: bytes, from: after)
            }
            guard bytes[safe: cursor] == Ascii.colon,
                  let bodyStart = bytes[cursor...].firstIndex(of: Ascii.openBrace) else { continue }
            let inheritance = ascii(bytes[cursor..<bodyStart])
            let adopted = inheritance.split(whereSeparator: { !isIdentifier($0.utf8.first) }).map(String.init)
            guard adopted.contains("ButtonStyle") || adopted.contains("PrimitiveButtonStyle"),
                  let bodyEnd = matchingClose(in: bytes, openingAt: bodyStart) else { continue }
            let body = ascii(bytes[bodyStart..<bodyEnd])
            let passes = hoverCalls.contains(where: { body.contains($0) })
            found.append(Site(kind: .buttonStyleConformance, offset: start, passes: passes))
        }
        return found
    }
}

extension PointerHoverScanner {
    /// Whether a hover member follows the member call at `dot`, which is itself not counted.
    private static func chainPasses(afterMemberAt dot: Int, in bytes: [UInt8]) -> Bool {
        !hoverMembers.isDisjoint(with: chainMembers(from: dot, in: bytes).dropFirst())
    }

    /// The names of the members chained from `position`, in order, each with its arguments and trailing closures
    /// skipped: `.a(x) { … }.b` reads `["a", "b"]`.
    private static func chainMembers(from position: Int, in bytes: [UInt8]) -> [String] {
        var members = [String]()
        var cursor = position
        while true {
            let dot = skipWhitespace(in: bytes, from: cursor)
            guard bytes[safe: dot] == Ascii.dot, isIdentifierStart(bytes[safe: dot + 1]) else { break }
            var nameEnd = dot + 1
            while isIdentifier(bytes[safe: nameEnd]) { nameEnd += 1 }
            members.append(ascii(bytes[(dot + 1)..<nameEnd]))
            cursor = skipArguments(in: bytes, from: nameEnd)
        }
        return members
    }

    /// The end of a member's call: an argument list opening on the same line, then trailing closures, the first
    /// opening on the same line and the labelled ones after it opening where they please.
    private static func skipArguments(in bytes: [UInt8], from position: Int) -> Int {
        var cursor = position
        let argumentsStart = skipInlineSpaces(in: bytes, from: cursor)
        if bytes[safe: argumentsStart] == Ascii.openParen {
            guard let after = matchingClose(in: bytes, openingAt: argumentsStart) else { return bytes.count }
            cursor = after
        }
        var closureStart: Int? = skipInlineSpaces(in: bytes, from: cursor)
        guard bytes[safe: closureStart ?? -1] == Ascii.openBrace else { return cursor }
        while let open = closureStart {
            guard let after = matchingClose(in: bytes, openingAt: open) else { return bytes.count }
            cursor = after
            closureStart = labelledClosureStart(in: bytes, after: after)
        }
        return cursor
    }

    /// The `{` of a `label: {` closure that follows a closure ending at `position`, if there is one.
    private static func labelledClosureStart(in bytes: [UInt8], after position: Int) -> Int? {
        var cursor = skipWhitespace(in: bytes, from: position)
        let labelStart = cursor
        while isIdentifier(bytes[safe: cursor]) { cursor += 1 }
        guard cursor > labelStart else { return nil }
        cursor = skipInlineSpaces(in: bytes, from: cursor)
        guard bytes[safe: cursor] == Ascii.colon else { return nil }
        cursor = skipWhitespace(in: bytes, from: cursor + 1)
        return bytes[safe: cursor] == Ascii.openBrace ? cursor : nil
    }

    /// The `.` of the outermost call written as `.member(` that encloses `index`, if any. The walk goes backwards,
    /// balancing parentheses, and ends at a `{` or `}` outside every group it passed: the edge of the value's block.
    private static func outermostEnclosingMemberCall(before index: Int, in bytes: [UInt8]) -> Int? {
        var outermost: Int?
        var depth = 0
        var cursor = index - 1
        while cursor >= 0 {
            let byte = bytes[cursor]
            if byte == Ascii.closeParen {
                depth += 1
            } else if byte == Ascii.openParen {
                if depth > 0 {
                    depth -= 1
                } else if let dot = memberDot(precedingOpenParenAt: cursor, in: bytes) {
                    outermost = dot
                    cursor = dot
                } else {
                    break
                }
            } else if (byte == Ascii.openBrace || byte == Ascii.closeBrace) && depth == 0 {
                break
            }
            cursor -= 1
        }
        return outermost
    }

    /// The `.` of `.member(` when the `(` at `openParen` directly follows a member name.
    private static func memberDot(precedingOpenParenAt openParen: Int, in bytes: [UInt8]) -> Int? {
        var cursor = openParen - 1
        while cursor >= 0, isIdentifier(bytes[cursor]) { cursor -= 1 }
        guard cursor < openParen - 1, bytes[safe: cursor] == Ascii.dot else { return nil }
        return cursor
    }
}

extension PointerHoverScanner {
    /// The key one file and kind share in every count below.
    static func key(file: String, kind: SiteKind) -> String {
        "\(file)|\(kind.rawValue)"
    }

    /// The non-passing site count per file and kind, listing only the pairs that have any.
    static func unmetCounts(in sitesByFile: [String: [Site]]) -> [String: Int] {
        var counts = [String: Int]()
        for (file, sites) in sitesByFile {
            for site in sites where !site.passes {
                counts[key(file: file, kind: site.kind), default: 0] += 1
            }
        }
        return counts
    }

    /// The count each allowance grants, summed where a file and kind are listed twice.
    static func allowedCounts(_ allowances: [HoverAuditAllowance]) -> [String: Int] {
        var counts = [String: Int]()
        for allowance in allowances {
            counts[key(file: allowance.file, kind: allowance.kind), default: 0] += allowance.count
        }
        return counts
    }

    /// Holds a scan against its allowlist: every non-passing site must be granted exactly, every grant must still be
    /// needed exactly, and every grant must say why.
    static func evaluate(sitesByFile: [String: [Site]], allowances: [HoverAuditAllowance]) -> Evaluation {
        let unmet = unmetCounts(in: sitesByFile)
        let allowed = allowedCounts(allowances)
        var evaluation = Evaluation()
        for (key, count) in unmet where allowed[key] == nil {
            evaluation.unlisted[key] = count
        }
        for (key, count) in allowed where unmet[key, default: 0] != count {
            evaluation.stale[key] = unmet[key, default: 0]
        }
        evaluation.reasonless = allowances
            .filter({ $0.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            .map({ key(file: $0.file, kind: $0.kind) })
            .sorted()
        return evaluation
    }
}

private enum Ascii {
    static let newline = UInt8(ascii: "\n")
    static let carriageReturn = UInt8(ascii: "\r")
    static let space = UInt8(ascii: " ")
    static let tab = UInt8(ascii: "\t")
    static let quote = UInt8(ascii: "\"")
    static let hash = UInt8(ascii: "#")
    static let dot = UInt8(ascii: ".")
    static let comma = UInt8(ascii: ",")
    static let colon = UInt8(ascii: ":")
    static let underscore = UInt8(ascii: "_")
    static let openParen = UInt8(ascii: "(")
    static let closeParen = UInt8(ascii: ")")
    static let openBrace = UInt8(ascii: "{")
    static let closeBrace = UInt8(ascii: "}")
    static let lessThan = UInt8(ascii: "<")
    static let greaterThan = UInt8(ascii: ">")
}

private extension Array {
    /// The element at `index`, or nil outside the array, so a scan never traps on a truncated file.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// The text of `bytes`, which are ASCII by the time any pass hands them on.
private func ascii(_ bytes: some Collection<UInt8>) -> String {
    String(bytes.map({ Character(Unicode.Scalar($0)) }))
}

private func isIdentifierStart(_ byte: UInt8?) -> Bool {
    guard let byte else { return false }
    return (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte)
        || (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(byte)
        || byte == Ascii.underscore
}

private func isIdentifier(_ byte: UInt8?) -> Bool {
    guard let byte else { return false }
    return isIdentifierStart(byte) || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
}

private func matches(_ text: String, at index: Int, in bytes: [UInt8]) -> Bool {
    index >= 0 && bytes.dropFirst(index).starts(with: text.utf8)
}

/// Every index where `text` starts, in order.
private func indices(of text: String, in bytes: [UInt8]) -> [Int] {
    bytes.indices.filter({ matches(text, at: $0, in: bytes) })
}

private func skipInlineSpaces(in bytes: [UInt8], from position: Int) -> Int {
    var cursor = position
    while let byte = bytes[safe: cursor], byte == Ascii.space || byte == Ascii.tab {
        cursor += 1
    }
    return cursor
}

private func skipWhitespace(in bytes: [UInt8], from position: Int) -> Int {
    var cursor = position
    while let byte = bytes[safe: cursor],
          byte == Ascii.space || byte == Ascii.tab || byte == Ascii.newline || byte == Ascii.carriageReturn {
        cursor += 1
    }
    return cursor
}

/// The index just after the bracket that closes the one at `index`, or nil when it never closes.
///
/// Strings and comments are already blank by the time this runs, so no bracket inside one can unbalance it.
private func matchingClose(in bytes: [UInt8], openingAt index: Int) -> Int? {
    guard let open = bytes[safe: index] else { return nil }
    let close: UInt8
    switch open {
    case Ascii.openParen: close = Ascii.closeParen
    case Ascii.openBrace: close = Ascii.closeBrace
    case Ascii.lessThan: close = Ascii.greaterThan
    default: return nil
    }
    var depth = 0
    var cursor = index
    while let byte = bytes[safe: cursor] {
        if byte == open {
            depth += 1
        } else if byte == close {
            depth -= 1
            if depth == 0 {
                return cursor + 1
            }
        }
        cursor += 1
    }
    return nil
}

/// Blanks `range` in place, keeping line breaks so every offset stays valid.
private func blank(_ bytes: inout [UInt8], in range: Range<Int>) {
    for index in range.clamped(to: bytes.indices) where bytes[index] != Ascii.newline
        && bytes[index] != Ascii.carriageReturn {
        bytes[index] = Ascii.space
    }
}

/// Blanks every comment and string literal, interpolations included, and then every non-ASCII byte. A string is
/// walked to its own closing delimiter (as many hashes as the opening one; an escape carries them too), and `\(…)`
/// hands control back to code until its parenthesis closes, so a nested string cannot end the outer one.
private struct CommentAndStringBlanker {
    private struct StringOpening {
        let hashes: Int
        let isMultiline: Bool

        var length: Int {
            hashes + (isMultiline ? 3 : 1)
        }
    }

    private let source: [UInt8]
    private var output: [UInt8]
    private var cursor = 0

    init(source: [UInt8]) {
        self.source = source
        output = source
    }

    mutating func blankedBytes() -> [UInt8] {
        blankCode(inInterpolation: false)
        for index in output.indices where output[index] >= 0x80 {
            output[index] = Ascii.space
        }
        return output
    }

    /// Walks code, blanking the comments and strings it meets; inside an interpolation it blanks the code too and
    /// returns just past the parenthesis that closes it.
    private mutating func blankCode(inInterpolation: Bool) {
        var depth = 1
        while cursor < source.count {
            if matches("//", at: cursor, in: source) {
                blankLineComment()
            } else if matches("/*", at: cursor, in: source) {
                blankBlockComment()
            } else if let opening = stringOpening() {
                blankString(opening)
            } else {
                let byte = source[cursor]
                if inInterpolation {
                    blankCurrent(count: 1)
                    depth += byte == Ascii.openParen ? 1 : 0
                    depth -= byte == Ascii.closeParen ? 1 : 0
                    if depth == 0 {
                        return
                    }
                } else {
                    cursor += 1
                }
            }
        }
    }

    private mutating func blankCurrent(count: Int) {
        blank(&output, in: cursor..<(cursor + count))
        cursor += count
    }

    private mutating func blankLineComment() {
        while let byte = source[safe: cursor], byte != Ascii.newline {
            blankCurrent(count: 1)
        }
    }

    /// Block comments nest in Swift, so `/* /* */ */` is one comment.
    private mutating func blankBlockComment() {
        var depth = 0
        while cursor < source.count {
            if matches("/*", at: cursor, in: source) {
                depth += 1
                blankCurrent(count: 2)
            } else if matches("*/", at: cursor, in: source) {
                depth -= 1
                blankCurrent(count: 2)
                if depth == 0 {
                    return
                }
            } else {
                blankCurrent(count: 1)
            }
        }
    }

    private func stringOpening() -> StringOpening? {
        var hashes = 0
        while source[safe: cursor + hashes] == Ascii.hash {
            hashes += 1
        }
        guard source[safe: cursor + hashes] == Ascii.quote else { return nil }
        return StringOpening(hashes: hashes, isMultiline: matches("\"\"\"", at: cursor + hashes, in: source))
    }

    private mutating func blankString(_ opening: StringOpening) {
        blankCurrent(count: opening.length)
        let hashes = String(repeating: "#", count: opening.hashes)
        let closing = String(repeating: "\"", count: opening.isMultiline ? 3 : 1) + hashes
        let escape = "\\" + hashes
        while cursor < source.count {
            if matches(escape, at: cursor, in: source) {
                blankCurrent(count: escape.utf8.count)
                guard let escaped = source[safe: cursor] else { return }
                blankCurrent(count: 1)
                if escaped == Ascii.openParen {
                    blankCode(inInterpolation: true)
                }
            } else if matches(closing, at: cursor, in: source) {
                blankCurrent(count: closing.utf8.count)
                return
            } else {
                blankCurrent(count: 1)
            }
        }
    }
}

/// Evaluates `#if` for iOS and blanks what the compiler would skip. The grammar is `!`, `&&`, `||`, parentheses,
/// `true`, `false`, `os(X)` (true only for iOS), `canImport(X)` (false only for AppKit) and every other name or call
/// (`DEBUG`, `targetEnvironment(…)`), which is true: better to read a branch the compiler may skip than miss one.
private enum ConditionalEvaluator {
    private struct Frame {
        let parentActive: Bool
        var taken: Bool
        var active: Bool
    }

    private enum Directive {
        case open(String)
        case elseIf(String)
        case otherwise
        case close
    }

    static func evaluate(_ bytes: [UInt8]) -> [UInt8] {
        var output = bytes
        var stack = [Frame]()
        var lineStart = 0
        while lineStart < bytes.count {
            let lineEnd = bytes[lineStart...].firstIndex(of: Ascii.newline) ?? bytes.count
            let text = ascii(bytes[lineStart..<lineEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let directive = directive(in: text) {
                apply(directive, to: &stack)
                blank(&output, in: lineStart..<lineEnd)
            } else if stack.last?.active == false {
                blank(&output, in: lineStart..<lineEnd)
            }
            lineStart = lineEnd + 1
        }
        return output
    }

    private static func apply(_ directive: Directive, to stack: inout [Frame]) {
        switch directive {
        case .open(let condition):
            let parentActive = stack.last?.active ?? true
            let value = isTrue(condition)
            stack.append(Frame(parentActive: parentActive, taken: value, active: parentActive && value))
        case .elseIf(let condition):
            guard var frame = stack.popLast() else { return }
            if frame.taken {
                frame.active = false
            } else {
                let value = isTrue(condition)
                frame.active = frame.parentActive && value
                frame.taken = value
            }
            stack.append(frame)
        case .otherwise:
            guard var frame = stack.popLast() else { return }
            frame.active = frame.parentActive && !frame.taken
            frame.taken = true
            stack.append(frame)
        case .close:
            _ = stack.popLast()
        }
    }

    private static func directive(in line: String) -> Directive? {
        if let rest = remainder(of: line, after: "#if") {
            .open(rest)
        } else if let rest = remainder(of: line, after: "#elseif") {
            .elseIf(rest)
        } else if remainder(of: line, after: "#else") != nil {
            .otherwise
        } else if remainder(of: line, after: "#endif") != nil {
            .close
        } else {
            nil
        }
    }

    /// What follows `keyword` on `line`, when the keyword stands alone as a word.
    private static func remainder(of line: String, after keyword: String) -> String? {
        guard line.hasPrefix(keyword) else { return nil }
        let rest = line.dropFirst(keyword.count)
        guard !isIdentifier(rest.utf8.first) else { return nil }
        return String(rest)
    }

    private static func isTrue(_ condition: String) -> Bool {
        var parser = ConditionParser(bytes: Array(condition.utf8))
        return parser.parseOr()
    }
}

private struct ConditionParser {
    let bytes: [UInt8]
    var cursor = 0

    mutating func parseOr() -> Bool {
        var value = parseAnd()
        while consume("||") {
            let right = parseAnd()
            value = value || right
        }
        return value
    }

    private mutating func parseAnd() -> Bool {
        var value = parseUnary()
        while consume("&&") {
            let right = parseUnary()
            value = value && right
        }
        return value
    }

    private mutating func parseUnary() -> Bool {
        if consume("!") {
            return !parseUnary()
        }
        return parsePrimary()
    }

    private mutating func parsePrimary() -> Bool {
        cursor = skipWhitespace(in: bytes, from: cursor)
        if consume("(") {
            let value = parseOr()
            _ = consume(")")
            return value
        }
        let nameStart = cursor
        while isIdentifier(bytes[safe: cursor]) {
            cursor += 1
        }
        let name = ascii(bytes[nameStart..<cursor])
        let argumentStart = skipWhitespace(in: bytes, from: cursor)
        var argument = ""
        if bytes[safe: argumentStart] == Ascii.openParen,
           let after = matchingClose(in: bytes, openingAt: argumentStart) {
            argument = ascii(bytes[(argumentStart + 1)..<(after - 1)]).trimmingCharacters(in: .whitespacesAndNewlines)
            cursor = after
        }
        switch name {
        case "false": return false
        case "os": return argument == "iOS"
        case "canImport": return argument != "AppKit"
        default: return true
        }
    }

    /// Consumes `token` after any whitespace when it comes next.
    private mutating func consume(_ token: String) -> Bool {
        let start = skipWhitespace(in: bytes, from: cursor)
        guard matches(token, at: start, in: bytes) else { return false }
        cursor = start + token.utf8.count
        return true
    }
}

// MARK: - Fixture tests

/// Every rule the scanner has is guarded by a fixture that fails when the rule is removed, so a change to the
/// scanner cannot quietly widen what the audit lets through. Each fixture is its own test case.
@Suite
struct PointerHoverScannerTests {
    struct Fixture: Sendable, CustomTestStringConvertible {
        let name: String
        let source: String
        /// The site outcomes in order (`kind:pass` or `kind:fail`), or the markers that survive preprocessing.
        let expected: [String]

        var testDescription: String {
            name
        }

        init(_ name: String, _ source: String, _ expected: [String] = []) {
            self.name = name
            self.source = source
            self.expected = expected
        }
    }

    private static let markers = ["aMac", "bIOS", "cDebug", "dElse", "eOuter", "fInMac", "gInElse", "hOutElse"]

    private static func processed(_ source: String) -> String {
        PointerHoverScanner.preprocessed(source)
    }

    private static func outcomes(_ source: String) -> [String] {
        let sites = PointerHoverScanner.sites(in: processed(source))
        return sites.map({ "\($0.kind.rawValue):\($0.passes ? "pass" : "fail")" })
    }

    /// Each source hides `TapGesture` in something that must be blanked and keeps `keepMe` outside it.
    static let blanking = [
        Fixture("line comment", "// TapGesture\nkeepMe\n"),
        Fixture("block comment", "/* TapGesture\n */ keepMe\n"),
        Fixture("nested block comment", "/* a /* TapGesture */ TapGesture */ keepMe\n"),
        Fixture("doc comments", "/// TapGesture\n/** TapGesture */\nkeepMe\n"),
        Fixture("escaped quote", #"let a = "say \"TapGesture\" now" ; keepMe"#),
        Fixture("multiline string", "let a = \"\"\"\n  TapGesture \"q\"\n  \"\"\"\nkeepMe\n"),
        Fixture("raw string holding a quote",
                ###"let a = #"a " TapGesture"# ; let b = ##"x "# TapGesture"##"### + " ; keepMe"),
        Fixture("raw multiline string", "let a = #\"\"\"\n \"\" TapGesture \"\"\" TapGesture\n \"\"\"#\nkeepMe\n"),
        Fixture("interpolation holding a nested string", #"let a = "x \(foo("TapGesture)")) y TapGesture" ; keepMe"#),
        Fixture("raw interpolation", ##"let a = #"x \#(foo("TapGesture)")) \(TapGesture) "# ; keepMe"##)
    ]

    @Test(arguments: blanking)
    func commentsAndStringsAreBlanked(_ fixture: Fixture) {
        let result = Self.processed(fixture.source)

        #expect(result.contains("TapGesture") == false)
        #expect(result.contains("keepMe"))
        #expect(result.utf8.count == fixture.source.utf8.count)
    }

    @Test
    func nonASCIIBytesBecomeSpacesAndTheLayoutIsKept() {
        let source = "let a = \"日本語\" // é\nlet 名前 = keepMe\n"
        let result = Self.processed(source)

        #expect(result.utf8.count == source.utf8.count)
        #expect(result.utf8.allSatisfy({ $0 < 0x80 }))
        #expect(result.utf8.filter({ $0 == UInt8(ascii: "\n") }).count == 2)
        #expect(result.contains("keepMe"))
    }

    /// `keepMe` under `#if <name>` survives exactly when `expected` says `kept`.
    static let conditions = [
        Fixture("os(iOS)", "os(iOS)", ["kept"]),
        Fixture("os(macOS)", "os(macOS)"),
        Fixture("canImport(AppKit)", "canImport(AppKit)"),
        Fixture("canImport(UIKit)", "canImport(UIKit)", ["kept"]),
        Fixture("DEBUG", "DEBUG", ["kept"]),
        Fixture("!os(iOS)", "!os(iOS)"),
        Fixture("os(iOS) && DEBUG", "os(iOS) && DEBUG", ["kept"]),
        Fixture("os(macOS) || os(iOS)", "os(macOS) || os(iOS)", ["kept"]),
        Fixture("negated parentheses", "!(os(macOS) || canImport(AppKit))", ["kept"])
    ]

    @Test(arguments: conditions)
    func aConditionIsEvaluatedForIOS(_ fixture: Fixture) {
        let result = Self.processed("#if \(fixture.source)\nkeepMe\n#endif\n")

        #expect((result.contains("keepMe") ? ["kept"] : []) == fixture.expected)
    }

    static let branches = [
        Fixture("else branch", "#if os(macOS)\naMac\n#else\ndElse\n#endif\n", ["dElse"]),
        Fixture(
            "elseif picks the first true branch only",
            "#if os(macOS)\naMac\n#elseif os(iOS)\nbIOS\n#elseif DEBUG\ncDebug\n#else\ndElse\n#endif\n",
            ["bIOS"]
        ),
        Fixture(
            "nested conditionals",
            "#if os(iOS)\neOuter\n#if os(macOS)\nfInMac\n#else\ngInElse\n#endif\n#else\nhOutElse\n#endif\n",
            ["eOuter", "gInElse"]
        ),
        Fixture("conditionals inside an inactive branch",
                "#if os(macOS)\n#if os(iOS)\nbIOS\n#else\ndElse\n#endif\n#endif")
    ]

    @Test(arguments: branches)
    func branchesAreChosenLikeTheCompilerDoes(_ fixture: Fixture) {
        let result = Self.processed(fixture.source)

        #expect(Self.markers.filter({ result.contains($0) }) == fixture.expected)
    }

    @Test
    func aPreviewBlockIsBlanked() {
        let source = "#Preview(\"A\") {\n  x.buttonStyle(.plain)\n}\n#Preview {\n  x.onTapGesture {}\n}\nkeepMe"

        #expect(Self.outcomes(source).isEmpty)
        #expect(Self.processed(source).contains("keepMe"))
    }

    static let sites = [
        Fixture(
            "helper after the plain style",
            "x\n.buttonStyle(.plain)\n.interactiveHover(.highlight, in: .rect)\n.padding()",
            ["plainButtonStyle:pass"]
        ),
        Fixture(
            "helper after a padding that follows the style",
            "x\n.buttonStyle(.plain)\n.padding(8)\n.cellRowHover()",
            ["plainButtonStyle:pass"]
        ),
        Fixture(
            "helper inside the label, before the style",
            "x {\n  y.interactiveHover(.highlight, in: .rect)\n}\n.buttonStyle(.plain)",
            ["plainButtonStyle:fail"]
        ),
        Fixture(
            "helper named in a comment or a string",
            "x\n.buttonStyle(.plain)\n// .cellRowHover()\n.help(\"interactiveHover\")",
            ["plainButtonStyle:fail"]
        ),
        Fixture(
            "the next view's helper is not borrowed",
            "x\n.buttonStyle(.plain)\ny\n.buttonStyle(.row)\n.cellRowHover()",
            ["plainButtonStyle:fail"]
        ),
        Fixture(
            "plain initializer, helper after the style call",
            "x\n.buttonStyle(PlainButtonStyle())\n.cellRowHover()",
            ["plainButtonStyleInitializer:pass"]
        ),
        Fixture("plain initializer, no helper", "x\n.buttonStyle(PlainButtonStyle())\n.padding()",
                ["plainButtonStyleInitializer:fail"]),
        Fixture("onTapGesture with a trailing closure, then a helper", "x\n.onTapGesture {\n  go()\n}\n.cellRowHover()",
                ["onTapGesture:pass"]),
        Fixture(
            "onTapGesture with labelled closures, then a helper",
            "x\n.onTapGesture { go() } label: { name() }\n.cellRowHover()",
            ["onTapGesture:pass"]
        ),
        Fixture(
            "onTapGesture without a helper",
            "x\n.onTapGesture(count: 2) { go() }\n.padding()\ny\n.onTapGesture(perform: go)",
            ["onTapGesture:fail", "onTapGesture:fail"]
        ),
        Fixture(
            "tap gesture in a simultaneous gesture, helper after the call",
            "x\n.simultaneousGesture(\n  TapGesture().onEnded { _ in go() }\n)\n.cellRowHover()",
            ["tapGesture:pass"]
        ),
        Fixture(
            "tap gesture in a simultaneous gesture, no helper",
            "x\n.simultaneousGesture(\n  TapGesture().onEnded { _ in go() }\n)\n.padding()",
            ["tapGesture:fail"]
        ),
        Fixture(
            "tap gestures nested in exclusively read the outer call",
            "x\n.highPriorityGesture(\n  TapGesture(count: 2).exclusively(before: TapGesture())\n)\n.cellRowHover()",
            ["tapGesture:pass", "tapGesture:pass"]
        ),
        Fixture(
            "tap gestures nested in exclusively, no helper",
            "x\n.highPriorityGesture(\n  TapGesture(count: 2).exclusively(before: TapGesture())\n)\n.padding()",
            ["tapGesture:fail", "tapGesture:fail"]
        ),
        Fixture(
            "tap gesture value with no enclosing call",
            "let a = TapGesture().onEnded { go() }.cellRowHover()\nlet b = TapGesture()\nlet c = 1",
            ["tapGesture:pass", "tapGesture:fail"]
        ),
        Fixture(
            "spatial tap gesture is not a tap gesture",
            "let s = SpatialTapGesture(count: 1)\n  .onEnded { value in go(value) }",
            ["spatialTapGesture:fail"]
        ),
        Fixture("recognizers and handler names",
                "UITapGestureRecognizer(target: self)\nh.onSingleTapGestureEnded(x)\nTapGestureCount")
    ]

    @Test(arguments: sites)
    func sitesAreReadWithTheirChains(_ fixture: Fixture) {
        #expect(Self.outcomes(fixture.source) == fixture.expected)
    }

    static let styles = [
        Fixture(
            "button style with a helper in its body",
            "struct S: ButtonStyle {\n  var body: V { x.interactiveHover(.highlight, in: .rect) }\n}",
            ["buttonStyleConformance:pass"]
        ),
        Fixture("button style without a helper", "struct S: ButtonStyle {\n  var body: V { x }\n}",
                ["buttonStyleConformance:fail"]),
        Fixture(
            "primitive button style with a helper",
            "struct S: PrimitiveButtonStyle {\n  var body: V { x.cellRowHover() }\n}",
            ["buttonStyleConformance:pass"]
        ),
        Fixture("primitive button style without a helper", "struct S: PrimitiveButtonStyle {\n  var body: V { x }\n}",
                ["buttonStyleConformance:fail"]),
        Fixture(
            "button style listed after another protocol",
            "private struct S: Sendable, ButtonStyle {\n  var body: V { x }\n}",
            ["buttonStyleConformance:fail"]
        ),
        Fixture("other styles and look-alike names",
                "struct T: ToggleStyle {}\nextension ButtonStyle where Self == S {}\nstruct N: MyButtonStyleHelper {}")
    ]

    @Test(arguments: styles)
    func buttonStylesAreAuditedThroughTheirBodies(_ fixture: Fixture) {
        #expect(Self.outcomes(fixture.source) == fixture.expected)
    }

    @Test
    func aHandWrittenIconTapShapeIsDetected() {
        let written = [
            "x.contentShape(.interaction, HoverTargetCircle(clippedAt: .leading))",
            "x.contentShape(\n    .interaction,\n    HoverTargetCircle()\n)"
        ]
        let other = [
            "x.contentShape(.hoverEffect, HoverTargetCircle())",
            "x.contentShape(.interaction, .rect)",
            "// x.contentShape(.interaction, HoverTargetCircle())"
        ]

        #expect(written.allSatisfy({ PointerHoverScanner.setsIconTapShape(Self.processed($0)) }))
        #expect(other.contains(where: { PointerHoverScanner.setsIconTapShape(Self.processed($0)) }) == false)
    }

    private static let allowance = HoverAuditAllowance(file: "A.swift", kind: .tapGesture, count: 2, reason: "Why.")
    private static let unmet = [
        "A.swift": [
            PointerHoverScanner.Site(kind: .tapGesture, offset: 1, passes: false),
            PointerHoverScanner.Site(kind: .tapGesture, offset: 9, passes: false),
            PointerHoverScanner.Site(kind: .plainButtonStyle, offset: 20, passes: true)
        ]
    ]

    @Test
    func aStaleAllowanceCountIsReported() {
        let stale = HoverAuditAllowance(file: "A.swift", kind: .tapGesture, count: 3, reason: "Why.")
        let evaluation = PointerHoverScanner.evaluate(sitesByFile: Self.unmet, allowances: [stale])

        #expect(evaluation.stale == ["A.swift|tapGesture": 2])
        #expect(evaluation.unlisted.isEmpty)
        #expect(PointerHoverScanner.evaluate(sitesByFile: [:], allowances: [Self.allowance]).stale.count == 1)
        #expect(PointerHoverScanner.evaluate(sitesByFile: Self.unmet, allowances: [Self.allowance]).isClean)
    }

    @Test
    func aMissingAllowanceIsReported() {
        let evaluation = PointerHoverScanner.evaluate(sitesByFile: Self.unmet, allowances: [])

        #expect(evaluation.unlisted == ["A.swift|tapGesture": 2])
        #expect(evaluation.stale.isEmpty)
    }

    @Test
    func anAllowanceWithoutAReasonIsReported() {
        let silent = HoverAuditAllowance(file: "A.swift", kind: .tapGesture, count: 2, reason: "  \n")
        let evaluation = PointerHoverScanner.evaluate(sitesByFile: Self.unmet, allowances: [silent])

        #expect(evaluation.reasonless == ["A.swift|tapGesture"])
        #expect(evaluation.isClean == false)
    }
}
