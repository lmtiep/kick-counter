import Testing
@testable import KickCore

struct ReportRowSplitterTests {
    /// Ten characters to a line, 10 points a line.
    private func lines(_ text: String) -> Double { Double((text.count + 9) / 10) * 10 }

    @Test func textThatFitsIsNotSplit() {
        let parts = ReportRowSplitter.split("short text", fitting: 10, height: lines)
        #expect(parts.head == "short text")
        #expect(parts.tail.isEmpty)
    }

    @Test func aLongTextIsCutToTheRoomAndTheRestContinues() {
        let text = String(repeating: "abcdefghi ", count: 10).trimmingCharacters(in: .whitespaces)
        let parts = ReportRowSplitter.split(text, fitting: 30, height: lines)
        #expect(lines(parts.head) <= 30)
        #expect(!parts.head.isEmpty)
        #expect(parts.head + " " + parts.tail == text)
    }

    @Test func nothingIsLostAcrossManyPages() {
        let text = (0..<300).map { "w\($0)" }.joined(separator: " ")
        var rest = text
        var pieces: [String] = []
        var guardCount = 0
        while !rest.isEmpty, guardCount < 100 {
            let parts = ReportRowSplitter.split(rest, fitting: 50, height: lines)
            #expect(!parts.head.isEmpty)
            pieces.append(parts.head)
            rest = parts.tail
            guardCount += 1
        }
        #expect(pieces.count > 1)
        #expect(pieces.joined(separator: " ") == text)
    }

    @Test func aWordLongerThanTheRoomIsCutByCharacters() {
        let word = String(repeating: "x", count: 95)
        let parts = ReportRowSplitter.split(word, fitting: 20, height: lines)
        #expect(parts.head.count == 20)
        #expect(parts.head + parts.tail == word)
    }

    @Test func nothingFittingGivesAnEmptyHead() {
        let parts = ReportRowSplitter.split("abc", fitting: 5, height: lines)
        #expect(parts.head.isEmpty)
        #expect(parts.tail == "abc")
    }

    @Test func everyCellOfARowIsSplitAgainstTheSameRoom() {
        let long = String(repeating: "ab ", count: 40).trimmingCharacters(in: .whitespaces)
        let parts = ReportRowSplitter.split(cells: ["date", long, ""], fitting: 20) { _, text in lines(text) }
        #expect(parts.head[0] == "date")
        #expect(parts.tail[0].isEmpty)
        #expect(!parts.tail[1].isEmpty)
        #expect(parts.tail[2].isEmpty)
    }
}
