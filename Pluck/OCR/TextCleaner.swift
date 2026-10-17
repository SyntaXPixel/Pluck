import Foundation

struct TextCleanerOptions: Equatable {
    var trimWhitespace: Bool = false
    var mergeLineBreaks: Bool = false
    var removeHyphenation: Bool = false
}

enum TextCleaner {
    /// Cleans and formats OCR recognized text according to user options.
    static func clean(_ text: String, options: TextCleanerOptions) -> String {
        var result = text

        // 1. Remove hyphenation at line breaks (e.g. "experi-\nment" -> "experiment")
        if options.removeHyphenation {
            result = removeHyphenation(from: result)
        }

        // 2. Merge line breaks within paragraphs
        if options.mergeLineBreaks {
            result = mergeLineBreaks(in: result)
        }

        // 3. Trim whitespace
        if options.trimWhitespace {
            result = trimWhitespace(in: result)
        }

        return result
    }

    /// Removes hyphenation where words are split across line breaks.
    /// E.g. "trans-\nparent" becomes "transparent".
    static func removeHyphenation(from text: String) -> String {
        let pattern = #"([a-zA-Z0-9])-[\r\n]+[ \t]*([a-zA-Z0-9])"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1$2")
    }

    /// Merges single line breaks into a space while preserving multiple line breaks (paragraph separators).
    static func mergeLineBreaks(in text: String) -> String {
        // Normalize CRLF to LF
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")

        // Split text by 2 or more consecutive newlines (paragraph boundaries)
        let paragraphs = normalized.components(separatedBy: "\n\n")

        let processedParagraphs = paragraphs.map { paragraph -> String in
            // Within each paragraph, replace single line breaks with spaces
            let singleLine = paragraph.replacingOccurrences(of: "\n", with: " ")
            // Collapse multiple spaces/tabs into a single space
            let collapsed = singleLine.replacingOccurrences(
                of: "[ \t]+",
                with: " ",
                options: .regularExpression
            )
            return collapsed.trimmingCharacters(in: .whitespaces)
        }

        return processedParagraphs.joined(separator: "\n\n")
    }

    /// Trims leading and trailing whitespace from the full text and each individual line.
    static func trimWhitespace(in text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let trimmedLines = lines.map { $0.trimmingCharacters(in: .whitespaces) }
        return trimmedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
