import KickCore
import PDFKit
import UIKit

/// Draws a `ReportContent` as an A4 PDF in light colours with Be Vietnam Pro.
/// Plain text and tables with the table header repeated on every page, and the
/// footer line and page number at the bottom of each page.
enum DoctorReportPDF {
    static let pageSize = CGSize(width: 595.2, height: 841.8)
    private static let margin: CGFloat = 40
    private static let footerHeight: CGFloat = 40
    private static let cellPaddingX: CGFloat = 6
    private static let cellPaddingY: CGFloat = 4

    /// `LunaMom-BaoCao-2026-11-06.pdf` (vi) or `LunaMom-Report-2026-11-06.pdf` (en).
    static func fileName(now: Date, language: ContentLanguage = AppLocale.language, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return "LunaMom-\(language == .vi ? "BaoCao" : "Report")-\(day).pdf"
    }

    /// Writes the file into a new folder of the temp directory. The caller deletes
    /// the folder (`url.deletingLastPathComponent()`) after sharing or cancelling.
    static func write(_ data: Data, now: Date) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LunaReport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(fileName(now: now))
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    static func render(_ content: ReportContent) -> Data {
        // The first pass only counts the pages for "Page x of y".
        let pages = draw(content, total: 0).pages
        return draw(content, total: pages).data
    }

    /// The first page as an image, for the UI-test preview.
    static func firstPageImage(of data: Data, scale: CGFloat = 2) -> UIImage? {
        guard let page = PDFDocument(data: data)?.page(at: 0) else { return nil }
        let size = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
        return page.thumbnail(of: size, for: .mediaBox)
    }

    static func pageCount(of data: Data) -> Int {
        PDFDocument(data: data)?.pageCount ?? 0
    }

    // MARK: - Drawing

    private enum Ink {
        static let text = LunaPalette.pair(.textPrimary).light.uiColor
        static let secondary = LunaPalette.pair(.textSecondary).light.uiColor
        static let accent = LunaPalette.pair(.pregStrong).light.uiColor
        static let rule = LunaPalette.pair(.divider).light.uiColor
        static let headerFill = LunaPalette.pair(.surface).light.uiColor
    }

    private static func font(_ weight: LunaWeight, _ size: CGFloat) -> UIFont {
        UIFont(name: weight.rawValue, size: size) ?? .systemFont(ofSize: size)
    }

    private static func draw(_ content: ReportContent, total: Int) -> (data: Data, pages: Int) {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: content.title, kCGPDFContextCreator as String: "Luna Mom"]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)
        var pages = 0
        let data = renderer.pdfData { context in
            var sheet = Sheet(context: context, footer: content.footer, total: total)
            sheet.beginPage()
            sheet.drawHeader(title: content.title, lines: content.headerLines)
            for table in content.tables {
                sheet.draw(table)
            }
            sheet.endPage()
            pages = sheet.number
        }
        return (data, pages)
    }

    private struct Sheet {
        let context: UIGraphicsPDFRendererContext
        let footer: String
        let total: Int
        var number = 0
        var y: CGFloat = 0

        private var contentWidth: CGFloat { DoctorReportPDF.pageSize.width - 2 * DoctorReportPDF.margin }
        private var bottom: CGFloat { DoctorReportPDF.pageSize.height - DoctorReportPDF.margin - DoctorReportPDF.footerHeight }

        init(context: UIGraphicsPDFRendererContext, footer: String, total: Int) {
            self.context = context
            self.footer = footer
            self.total = total
        }

        mutating func beginPage() {
            context.beginPage()
            number += 1
            y = DoctorReportPDF.margin
        }

        /// The footer line on the left and "Page x of y" on the right.
        mutating func endPage() {
            let y = DoctorReportPDF.pageSize.height - DoctorReportPDF.margin - 12
            let small = DoctorReportPDF.font(.regular, 8)
            let pageText = total > 0 ? L10n.reportPDFPage(number, of: total) : ""
            let pageWidth: CGFloat = 90
            Self.draw(footer, font: small, color: Ink.secondary, in: CGRect(x: DoctorReportPDF.margin, y: y, width: contentWidth - pageWidth - 8, height: 12))
            Self.draw(pageText, font: small, color: Ink.secondary, alignment: .right,
                      in: CGRect(x: DoctorReportPDF.margin + contentWidth - pageWidth, y: y, width: pageWidth, height: 12))
        }

        private mutating func ensure(_ needed: CGFloat) {
            guard y + needed > bottom else { return }
            endPage()
            beginPage()
        }

        mutating func drawHeader(title: String, lines: [String]) {
            let brand = DoctorReportPDF.font(.semibold, 10)
            Self.draw("Luna Mom", font: brand, color: Ink.accent, in: CGRect(x: DoctorReportPDF.margin, y: y, width: contentWidth, height: 14))
            y += 18
            let titleFont = DoctorReportPDF.font(.bold, 22)
            y += Self.draw(title, font: titleFont, color: Ink.text, in: CGRect(x: DoctorReportPDF.margin, y: y, width: contentWidth, height: 200)) + 8
            let body = DoctorReportPDF.font(.regular, 10.5)
            for line in lines {
                y += Self.draw(line, font: body, color: Ink.text, in: CGRect(x: DoctorReportPDF.margin, y: y, width: contentWidth, height: 200)) + 3
            }
            y += 10
        }

        mutating func draw(_ table: ReportContent.Table) {
            let titleFont = DoctorReportPDF.font(.semibold, 13)
            let headFont = DoctorReportPDF.font(.semibold, 9)
            let bodyFont = DoctorReportPDF.font(.regular, 9.5)
            let weightSum = table.columns.reduce(0) { $0 + $1.weight }
            let widths = table.columns.map { contentWidth * $0.weight / weightSum }
            let titleHeight = height(table.title, font: titleFont, width: contentWidth)
            let headHeight = rowHeight(table.columns.map(\.title), widths: widths, font: headFont)
            let firstHeight = table.rows.first.map { rowHeight($0, widths: widths, font: bodyFont) } ?? 0
            ensure(titleHeight + 8 + headHeight + firstHeight)
            y += 8
            y += Self.draw(table.title, font: titleFont, color: Ink.accent, in: CGRect(x: DoctorReportPDF.margin, y: y, width: contentWidth, height: 200)) + 6
            drawRow(table.columns.map(\.title), widths: widths, font: headFont, height: headHeight, fill: Ink.headerFill)
            for row in table.rows {
                let h = rowHeight(row, widths: widths, font: bodyFont)
                if y + h > bottom {
                    endPage()
                    beginPage()
                    drawRow(table.columns.map(\.title), widths: widths, font: headFont, height: headHeight, fill: Ink.headerFill)
                }
                drawRow(row, widths: widths, font: bodyFont, height: h, fill: nil)
            }
        }

        private func rowHeight(_ cells: [String], widths: [CGFloat], font: UIFont) -> CGFloat {
            let tallest = zip(cells, widths).map { height($0, font: font, width: $1 - 2 * DoctorReportPDF.cellPaddingX) }.max() ?? 0
            return tallest + 2 * DoctorReportPDF.cellPaddingY
        }

        private mutating func drawRow(_ cells: [String], widths: [CGFloat], font: UIFont, height: CGFloat, fill: UIColor?) {
            if let fill {
                fill.setFill()
                UIBezierPath(rect: CGRect(x: DoctorReportPDF.margin, y: y, width: contentWidth, height: height)).fill()
            }
            var x = DoctorReportPDF.margin
            for (cell, width) in zip(cells, widths) {
                Self.draw(
                    cell, font: font, color: Ink.text,
                    in: CGRect(
                        x: x + DoctorReportPDF.cellPaddingX, y: y + DoctorReportPDF.cellPaddingY,
                        width: width - 2 * DoctorReportPDF.cellPaddingX, height: height
                    )
                )
                x += width
            }
            y += height
            Ink.rule.setFill()
            UIBezierPath(rect: CGRect(x: DoctorReportPDF.margin, y: y - 0.5, width: contentWidth, height: 0.5)).fill()
        }

        private func height(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
            guard !text.isEmpty else { return 0 }
            let rect = NSAttributedString(string: text, attributes: [.font: font])
                .boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            return ceil(rect.height)
        }

        /// Draws the text and returns the height it took.
        @discardableResult
        private static func draw(
            _ text: String, font: UIFont, color: UIColor, alignment: NSTextAlignment = .left, in rect: CGRect
        ) -> CGFloat {
            guard !text.isEmpty else { return 0 }
            let style = NSMutableParagraphStyle()
            style.alignment = alignment
            let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
            let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
            let size = string.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude), options: options, context: nil)
            string.draw(with: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: ceil(size.height)), options: options, context: nil)
            return ceil(size.height)
        }
    }
}
