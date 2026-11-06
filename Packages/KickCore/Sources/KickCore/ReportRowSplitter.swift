import Foundation

/// Splits table text across pages when a row is taller than the room left, so
/// no text is lost. Pure: the caller measures text height (the PDF layout does
/// it with the real font and column width).
public enum ReportRowSplitter {
    /// The longest head of `text` that is at most `available` tall (as `height` measures
    /// it), cut at a space when there is one in the second half of the head. The tail
    /// is the rest. `head` is empty only when not even one character fits.
    public static func split(_ text: String, fitting available: Double, height: (String) -> Double) -> (head: String, tail: String) {
        if text.isEmpty || height(text) <= available { return (text, "") }
        let characters = Array(text)
        var low = 0
        var high = characters.count
        while low < high {
            let middle = (low + high + 1) / 2
            if height(String(characters[..<middle])) <= available { low = middle } else { high = middle - 1 }
        }
        var cut = low
        if cut == 0 { return ("", text) }
        if let space = characters[..<cut].lastIndex(where: \.isWhitespace), space > cut / 2 { cut = space }
        let head = String(characters[..<cut]).trimmingCharacters(in: .whitespacesAndNewlines)
        let tail = String(characters[cut...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (head, tail)
    }

    /// `split` for every cell of a row: the row's head cells and the cells that continue on the next page.
    public static func split(
        cells: [String], fitting available: Double, height: (_ column: Int, _ text: String) -> Double
    ) -> (head: [String], tail: [String]) {
        var head: [String] = []
        var tail: [String] = []
        for (column, cell) in cells.enumerated() {
            let parts = split(cell, fitting: available) { height(column, $0) }
            head.append(parts.head)
            tail.append(parts.tail)
        }
        return (head, tail)
    }
}
