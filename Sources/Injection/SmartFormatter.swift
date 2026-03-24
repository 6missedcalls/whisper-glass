import Foundation

/// Options that control how transcribed text is formatted before injection.
public struct FormattingOptions: Sendable, Equatable {
    /// Capitalize the first letter of each sentence.
    public let autoCapitalize: Bool

    /// Remove common filler words (um, uh, like, you know, basically, actually).
    public let removeFillerWords: Bool

    /// Code mode: preserve exact output, disable auto-capitalize.
    public let codeMode: Bool

    public init(
        autoCapitalize: Bool = true,
        removeFillerWords: Bool = true,
        codeMode: Bool = false
    ) {
        self.autoCapitalize = autoCapitalize
        self.removeFillerWords = removeFillerWords
        self.codeMode = codeMode
    }

    /// Default formatting options for general dictation.
    public static let standard = FormattingOptions()

    /// Formatting options for code dictation — preserves exact output.
    public static let code = FormattingOptions(
        autoCapitalize: false,
        removeFillerWords: false,
        codeMode: true
    )
}

/// Pure formatting functions for cleaning up transcribed text before injection.
public struct SmartFormatter {

    /// Filler words to remove (case-insensitive matching).
    /// Each entry is matched as a standalone word bounded by whitespace.
    private static let fillerWords: Set<String> = [
        "um", "uh", "like", "you know", "basically", "actually"
    ]

    /// Formats the given text according to the specified options.
    ///
    /// - Parameters:
    ///   - text: The raw transcription text.
    ///   - options: Formatting options to apply.
    /// - Returns: The formatted text.
    public static func format(_ text: String, options: FormattingOptions) -> String {
        guard !text.isEmpty else { return text }

        if options.codeMode {
            return trimWhitespace(text)
        }

        var result = text

        if options.removeFillerWords {
            result = removeFillers(from: result)
        }

        if options.autoCapitalize {
            result = capitalizeSentences(result)
        }

        result = trimWhitespace(result)
        result = collapseMultipleSpaces(result)

        return result
    }

    // MARK: - Private Helpers

    /// Removes filler words from the text, treating them as standalone tokens.
    private static func removeFillers(from text: String) -> String {
        var result = text

        // Handle multi-word fillers first (e.g., "you know")
        let multiWordFillers = fillerWords.filter { $0.contains(" ") }
            .sorted { $0.count > $1.count } // longest first to avoid partial matches

        for filler in multiWordFillers {
            result = removeStandaloneFiller(filler, from: result)
        }

        // Handle single-word fillers
        let singleWordFillers = fillerWords.filter { !$0.contains(" ") }
        for filler in singleWordFillers {
            result = removeStandaloneFiller(filler, from: result)
        }

        return result
    }

    /// Removes a standalone filler word/phrase from text.
    ///
    /// "Standalone" means surrounded by word boundaries (spaces, punctuation, or string edges).
    private static func removeStandaloneFiller(_ filler: String, from text: String) -> String {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: filler))\\b"
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive
        ) else {
            return text
        }

        let range = NSRange(text.startIndex..., in: text)
        let result = regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: ""
        )

        return result
    }

    /// Capitalizes the first letter of each sentence.
    ///
    /// Sentences are delimited by `.`, `!`, or `?` followed by whitespace.
    private static func capitalizeSentences(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        var result = ""
        var shouldCapitalize = true

        for character in text {
            if shouldCapitalize && character.isLetter {
                result.append(character.uppercased())
                shouldCapitalize = false
            } else {
                result.append(character)
            }

            if character == "." || character == "!" || character == "?" {
                shouldCapitalize = true
            }
        }

        return result
    }

    /// Trims leading and trailing whitespace and newlines.
    private static func trimWhitespace(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Collapses multiple consecutive spaces into a single space.
    private static func collapseMultipleSpaces(_ text: String) -> String {
        let pattern = " {2,}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: " "
        )
    }
}
