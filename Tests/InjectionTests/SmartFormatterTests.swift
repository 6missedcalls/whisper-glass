import Testing
@testable import WhisperGlassCore

@Suite("SmartFormatter")
struct SmartFormatterTests {

    // MARK: - Capitalization

    @Test("Capitalizes first word of sentence")
    func capitalizesFirstWord() {
        let result = SmartFormatter.format("hello world", options: .standard)
        #expect(result == "Hello world")
    }

    @Test("Capitalizes after period")
    func capitalizesAfterPeriod() {
        let result = SmartFormatter.format("hello. world", options: .standard)
        #expect(result == "Hello. World")
    }

    @Test("Capitalizes after exclamation mark")
    func capitalizesAfterExclamation() {
        let result = SmartFormatter.format("wow! great", options: .standard)
        #expect(result == "Wow! Great")
    }

    @Test("Capitalizes after question mark")
    func capitalizesAfterQuestionMark() {
        let result = SmartFormatter.format("really? yes", options: .standard)
        #expect(result == "Really? Yes")
    }

    @Test("Multiple sentences capitalized correctly")
    func multipleSentences() {
        let result = SmartFormatter.format(
            "first sentence. second sentence. third one",
            options: .standard
        )
        #expect(result == "First sentence. Second sentence. Third one")
    }

    // MARK: - Filler Word Removal

    @Test("Removes filler word um")
    func removesUm() {
        let result = SmartFormatter.format("I um want to go", options: .standard)
        #expect(result == "I want to go")
    }

    @Test("Removes filler word uh")
    func removesUh() {
        let result = SmartFormatter.format("so uh the thing is", options: .standard)
        #expect(result == "So the thing is")
    }

    @Test("Removes standalone like as filler")
    func removesLikeAsFiller() {
        let result = SmartFormatter.format("it was like really good", options: .standard)
        #expect(result == "It was really good")
    }

    @Test("Removes you know filler phrase")
    func removesYouKnow() {
        let result = SmartFormatter.format(
            "it is you know pretty cool",
            options: .standard
        )
        #expect(result == "It is pretty cool")
    }

    @Test("Removes basically filler")
    func removesBasically() {
        let result = SmartFormatter.format("basically it works", options: .standard)
        #expect(result == "It works")
    }

    @Test("Removes actually filler")
    func removesActually() {
        let result = SmartFormatter.format("actually that is wrong", options: .standard)
        #expect(result == "That is wrong")
    }

    @Test("Multiple filler words in sequence")
    func multipleFillers() {
        let result = SmartFormatter.format("um uh like hello", options: .standard)
        #expect(result == "Hello")
    }

    @Test("Filler removal is case insensitive")
    func fillerCaseInsensitive() {
        let result = SmartFormatter.format("I Um want Uh to go", options: .standard)
        #expect(result == "I want to go")
    }

    // MARK: - Code Mode

    @Test("Code mode preserves exact text")
    func codeModePreservesText() {
        let input = "let x = 42"
        let result = SmartFormatter.format(input, options: .code)
        #expect(result == "let x = 42")
    }

    @Test("Code mode does not capitalize")
    func codeModeNoCapitalize() {
        let result = SmartFormatter.format("hello. world", options: .code)
        #expect(result == "hello. world")
    }

    @Test("Code mode does not remove fillers")
    func codeModeKeepsFillers() {
        let result = SmartFormatter.format("um uh like", options: .code)
        #expect(result == "um uh like")
    }

    // MARK: - Edge Cases

    @Test("Empty string returns empty")
    func emptyString() {
        let result = SmartFormatter.format("", options: .standard)
        #expect(result == "")
    }

    @Test("Trims leading and trailing whitespace")
    func trimsWhitespace() {
        let result = SmartFormatter.format("  hello world  ", options: .standard)
        #expect(result == "Hello world")
    }

    @Test("Collapses multiple spaces")
    func collapsesSpaces() {
        let result = SmartFormatter.format("hello   world", options: .standard)
        #expect(result == "Hello world")
    }

    @Test("Only whitespace returns empty")
    func onlyWhitespace() {
        let result = SmartFormatter.format("   ", options: .standard)
        #expect(result == "")
    }

    @Test("Capitalize disabled preserves case")
    func capitalizeDisabled() {
        let options = FormattingOptions(autoCapitalize: false, removeFillerWords: true)
        let result = SmartFormatter.format("hello world", options: options)
        #expect(result == "hello world")
    }

    @Test("Filler removal disabled keeps fillers")
    func fillerRemovalDisabled() {
        let options = FormattingOptions(autoCapitalize: true, removeFillerWords: false)
        let result = SmartFormatter.format("um hello", options: options)
        #expect(result == "Um hello")
    }
}
