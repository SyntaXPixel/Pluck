import XCTest
@testable import Pluck

final class TextCleanerTests: XCTestCase {
    func testPassthroughWhenNoOptionsEnabled() {
        let input = "  Hello \n world -\n here  "
        let options = TextCleanerOptions(
            trimWhitespace: false,
            mergeLineBreaks: false,
            removeHyphenation: false
        )
        let output = TextCleaner.clean(input, options: options)
        XCTAssertEqual(output, input)
    }

    func testTrimWhitespace() {
        let input = "   Line 1 with trailing space   \n   Line 2   \n\n"
        let options = TextCleanerOptions(
            trimWhitespace: true,
            mergeLineBreaks: false,
            removeHyphenation: false
        )
        let output = TextCleaner.clean(input, options: options)
        XCTAssertEqual(output, "Line 1 with trailing space\nLine 2")
    }

    func testMergeLineBreaksSingleParagraph() {
        let input = "This is a sentence\nsplit across three\ndifferent lines."
        let options = TextCleanerOptions(
            trimWhitespace: false,
            mergeLineBreaks: true,
            removeHyphenation: false
        )
        let output = TextCleaner.clean(input, options: options)
        XCTAssertEqual(output, "This is a sentence split across three different lines.")
    }

    func testMergeLineBreaksPreservesParagraphs() {
        let input = "First paragraph line 1\nline 2.\n\nSecond paragraph line 1\nline 2."
        let options = TextCleanerOptions(
            trimWhitespace: false,
            mergeLineBreaks: true,
            removeHyphenation: false
        )
        let output = TextCleaner.clean(input, options: options)
        XCTAssertEqual(output, "First paragraph line 1 line 2.\n\nSecond paragraph line 1 line 2.")
    }

    func testRemoveHyphenation() {
        let input = "This is an experi-\nment in natural language\nrecog-\nnition."
        let options = TextCleanerOptions(
            trimWhitespace: false,
            mergeLineBreaks: false,
            removeHyphenation: true
        )
        let output = TextCleaner.clean(input, options: options)
        XCTAssertEqual(output, "This is an experiment in natural language\nrecognition.")
    }

    func testRemoveHyphenationPreservesSameLineHyphens() {
        let input = "A state-of-the-art OCR sys-\ntem."
        let options = TextCleanerOptions(
            trimWhitespace: false,
            mergeLineBreaks: false,
            removeHyphenation: true
        )
        let output = TextCleaner.clean(input, options: options)
        XCTAssertEqual(output, "A state-of-the-art OCR system.")
    }

    func testRemoveHyphenationWithCRLF() {
        let input = "inter-\r\nface"
        let options = TextCleanerOptions(
            trimWhitespace: false,
            mergeLineBreaks: false,
            removeHyphenation: true
        )
        let output = TextCleaner.clean(input, options: options)
        XCTAssertEqual(output, "interface")
    }

    func testAllOptionsCombined() {
        let input = "  This is an amaz-\n  ingly well-crafted   \n  tool.  \n\n  Next paragraph here.  "
        let options = TextCleanerOptions(
            trimWhitespace: true,
            mergeLineBreaks: true,
            removeHyphenation: true
        )
        let output = TextCleaner.clean(input, options: options)
        XCTAssertEqual(output, "This is an amazingly well-crafted tool.\n\nNext paragraph here.")
    }

    func testEmptyString() {
        let options = TextCleanerOptions(
            trimWhitespace: true,
            mergeLineBreaks: true,
            removeHyphenation: true
        )
        XCTAssertEqual(TextCleaner.clean("", options: options), "")
    }

    func testWhitespaceOnlyString() {
        let options = TextCleanerOptions(
            trimWhitespace: true,
            mergeLineBreaks: true,
            removeHyphenation: true
        )
        XCTAssertEqual(TextCleaner.clean("   \n\t  \n  ", options: options), "")
    }
}
