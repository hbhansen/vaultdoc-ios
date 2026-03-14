import PDFKit
import UIKit

struct PDFGenerator {
    static let teal = UIColor(red: 0.114, green: 0.620, blue: 0.459, alpha: 1)
    static let darkTeal = UIColor(red: 0.031, green: 0.314, blue: 0.255, alpha: 1)

    static func generate(for item: Item) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 72dpi
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            drawHeader(in: pageRect, ctx: ctx.cgContext, item: item)
            var yOffset: CGFloat = 130
            yOffset = drawValueCard(in: pageRect, ctx: ctx.cgContext, item: item, y: yOffset)
            yOffset = drawDetailsGrid(in: pageRect, ctx: ctx.cgContext, item: item, y: yOffset)
            yOffset = drawPhotos(in: pageRect, ctx: ctx.cgContext, item: item, y: yOffset, pdfCtx: ctx)
            drawDocumentList(in: pageRect, ctx: ctx.cgContext, item: item, y: yOffset)
            drawFooter(in: pageRect, ctx: ctx.cgContext, page: 1)
        }
    }

    static func generateAll(items: [Item]) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            for (i, item) in items.enumerated() {
                ctx.beginPage()
                drawHeader(in: pageRect, ctx: ctx.cgContext, item: item)
                var yOffset: CGFloat = 130
                yOffset = drawValueCard(in: pageRect, ctx: ctx.cgContext, item: item, y: yOffset)
                yOffset = drawDetailsGrid(in: pageRect, ctx: ctx.cgContext, item: item, y: yOffset)
                yOffset = drawPhotos(in: pageRect, ctx: ctx.cgContext, item: item, y: yOffset, pdfCtx: ctx)
                drawDocumentList(in: pageRect, ctx: ctx.cgContext, item: item, y: yOffset)
                drawFooter(in: pageRect, ctx: ctx.cgContext, page: i + 1)
            }
        }
    }

    private static func drawHeader(in rect: CGRect, ctx: CGContext, item: Item) {
        // Background bar
        ctx.setFillColor(darkTeal.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: rect.width, height: 80))

        // Logo text
        let logoAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        L10n.tr("app.name").draw(at: CGPoint(x: 30, y: 26), withAttributes: logoAttrs)

        // Reference + date
        let refAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.white.withAlphaComponent(0.8)
        ]
        let refNum = "REF-\(item.id.uuidString.prefix(8).uppercased())"
        let formatter = DateFormatter()
        formatter.locale = LanguageSettings.shared.locale
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        let dateStr = formatter.string(from: Date())
        "\(refNum)  |  \(dateStr)".draw(at: CGPoint(x: 30, y: 56), withAttributes: refAttrs)

        // Item name subtitle
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        ]
        item.name.draw(at: CGPoint(x: 30, y: 92), withAttributes: nameAttrs)
    }

    private static func drawValueCard(in rect: CGRect, ctx: CGContext, item: Item, y: CGFloat) -> CGFloat {
        let cardRect = CGRect(x: 30, y: y + 8, width: rect.width - 60, height: 72)
        ctx.setFillColor(teal.withAlphaComponent(0.12).cgColor)
        ctx.setStrokeColor(teal.cgColor)
        ctx.setLineWidth(1)
        let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 8)
        ctx.addPath(cardPath.cgPath)
        ctx.drawPath(using: .fillStroke)

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.darkGray
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: darkTeal
        ]

        L10n.tr("item_detail.declared_value_uppercase").draw(at: CGPoint(x: 50, y: y + 20), withAttributes: labelAttrs)
        CurrencyFormatter.format(item.estimatedValue).draw(at: CGPoint(x: 50, y: y + 36), withAttributes: valueAttrs)

        if let ai = item.aiEstimate {
            L10n.tr("item_detail.ai_estimate_uppercase").draw(at: CGPoint(x: 320, y: y + 20), withAttributes: labelAttrs)
            CurrencyFormatter.format(ai).draw(at: CGPoint(x: 320, y: y + 36), withAttributes: valueAttrs)
        }

        return y + 72 + 16
    }

    private static func drawDetailsGrid(in rect: CGRect, ctx: CGContext, item: Item, y: CGFloat) -> CGFloat {
        let fields: [(String, String)] = [
            (L10n.tr("item.field.category"), item.categoryDisplayName),
            (L10n.tr("item.field.year_purchased"), String(item.yearPurchased)),
            (L10n.tr("item.field.purchase_price"), CurrencyFormatter.format(item.purchasePrice)),
            (L10n.tr("item.field.serial_number"), item.serialNumber.isEmpty ? L10n.placeholderDash : item.serialNumber),
            (L10n.tr("item.field.notes"), item.notes.isEmpty ? L10n.placeholderDash : item.notes)
        ]

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.gray
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]

        let currentY = y
        let col1X: CGFloat = 30
        let col2X: CGFloat = rect.width / 2 + 10

        for (i, field) in fields.enumerated() {
            let xPos = i % 2 == 0 ? col1X : col2X
            let rowY = currentY + CGFloat(i / 2) * 44

            // Separator line
            if i % 2 == 0 && i > 0 {
                ctx.setStrokeColor(UIColor.lightGray.withAlphaComponent(0.4).cgColor)
                ctx.setLineWidth(0.5)
                ctx.move(to: CGPoint(x: 30, y: rowY - 4))
                ctx.addLine(to: CGPoint(x: rect.width - 30, y: rowY - 4))
                ctx.strokePath()
            }

            field.0.draw(at: CGPoint(x: xPos, y: rowY + 2), withAttributes: labelAttrs)
            field.1.draw(at: CGPoint(x: xPos, y: rowY + 14), withAttributes: valueAttrs)
        }

        let rows = Int(ceil(Double(fields.count) / 2.0))
        return currentY + CGFloat(rows) * 44 + 16
    }

    private static func drawPhotos(in rect: CGRect, ctx: CGContext, item: Item, y: CGFloat, pdfCtx: UIGraphicsPDFRendererContext) -> CGFloat {
        guard !item.photos.isEmpty else { return y }

        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor.darkGray
        ]
        L10n.tr("item_detail.photos_uppercase").draw(at: CGPoint(x: 30, y: y), withAttributes: headerAttrs)

        let photoSize: CGFloat = 120
        let spacing: CGFloat = 12
        var xOffset: CGFloat = 30
        var currentY = y + 18

        for photo in item.photos.prefix(4) {
            if let uiImage = UIImage(data: photo.imageData) {
                let photoRect = CGRect(x: xOffset, y: currentY, width: photoSize, height: photoSize)
                ctx.saveGState()
                let clipPath = UIBezierPath(roundedRect: photoRect, cornerRadius: 4)
                ctx.addPath(clipPath.cgPath)
                ctx.clip()
                uiImage.draw(in: photoRect)
                ctx.restoreGState()
                xOffset += photoSize + spacing
                if xOffset + photoSize > rect.width - 30 {
                    xOffset = 30
                    currentY += photoSize + spacing
                }
            }
        }

        return currentY + photoSize + 16
    }

    private static func drawDocumentList(in rect: CGRect, ctx: CGContext, item: Item, y: CGFloat) {
        guard !item.documents.isEmpty else { return }

        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor.darkGray
        ]
        let docAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        let sizeAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.gray
        ]

        L10n.tr("item_detail.documents_uppercase").draw(at: CGPoint(x: 30, y: y), withAttributes: headerAttrs)
        var currentY = y + 18

        for doc in item.documents {
            doc.filename.draw(at: CGPoint(x: 44, y: currentY), withAttributes: docAttrs)
            doc.formattedSize.draw(at: CGPoint(x: 44, y: currentY + 13), withAttributes: sizeAttrs)

            // File icon placeholder
            ctx.setFillColor(teal.withAlphaComponent(0.2).cgColor)
            ctx.fill(CGRect(x: 30, y: currentY, width: 10, height: 14))

            currentY += 32
        }
    }

    private static func drawFooter(in rect: CGRect, ctx: CGContext, page: Int) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.gray
        ]
        ctx.setStrokeColor(UIColor.lightGray.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: 30, y: rect.height - 36))
        ctx.addLine(to: CGPoint(x: rect.width - 30, y: rect.height - 36))
        ctx.strokePath()

        L10n.tr("pdf.footer.generated_by").draw(
            at: CGPoint(x: 30, y: rect.height - 24), withAttributes: attrs
        )
        L10n.format("pdf.footer.page", Int64(page)).draw(
            at: CGPoint(x: rect.width - 60, y: rect.height - 24), withAttributes: attrs
        )
    }
}
