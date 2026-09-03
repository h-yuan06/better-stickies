import AppKit

/// Draws a list marker in the gutter beside a paragraph.
///
/// Markers are painted rather than inserted as characters, which means copying a note
/// yields clean text with no stray bullet glyphs or tab stops, and the checkbox can be
/// a real hit target instead of a text attachment that Backspace could delete.
nonisolated final class ListLayoutFragment: NSTextLayoutFragment {
    var listKind: ListKind = .bullet
    var level: Int = 0
    var isChecked: Bool = false
    var number: Int = 1
    var style: TextStyle = .default

    /// Marker rect in the fragment's own coordinate space, for drawing and hit-testing.
    var markerRect: CGRect {
        let line = textLineFragments.first
        let lineHeight = line?.typographicBounds.height ?? style.lineHeight
        let lineY = line?.typographicBounds.minY ?? 0
        var rect = ListMetrics.markerRect(level: level, lineHeight: lineHeight)
        rect.origin.y = lineY
        return rect
    }

    override func draw(at point: CGPoint, in context: CGContext) {
        drawMarker(at: point, in: context)
        super.draw(at: point, in: context)
    }

    private func drawMarker(at point: CGPoint, in context: CGContext) {
        let rect = markerRect.offsetBy(dx: point.x, dy: point.y)
        context.saveGState()
        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext

        switch listKind {
        case .bullet: drawBullet(in: rect)
        case .numbered: drawNumber(in: rect)
        case .checklist: drawCheckbox(in: rect)
        }

        NSGraphicsContext.restoreGraphicsState()
        context.restoreGState()
    }

    // MARK: - Marker styles

    private func drawBullet(in rect: CGRect) {
        // Alternate the glyph by depth the way outliners do, so nesting reads clearly.
        let diameter: CGFloat = 5
        let center = CGPoint(x: rect.midX + 2, y: rect.midY)
        let box = CGRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        )
        NSColor.secondaryLabelColor.setFill()
        NSColor.secondaryLabelColor.setStroke()

        switch level % 3 {
        case 0:
            NSBezierPath(ovalIn: box).fill()
        case 1:
            let path = NSBezierPath(ovalIn: box.insetBy(dx: 0.5, dy: 0.5))
            path.lineWidth = 1
            path.stroke()
        default:
            NSBezierPath(rect: box.insetBy(dx: 0.5, dy: 0.5)).fill()
        }
    }

    private func drawNumber(in rect: CGRect) {
        let font = style.font(bold: false, italic: false)
        let text = "\(number)."
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: font.pointSize, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        // Right-align against the text edge so 9. and 10. line up.
        let origin = CGPoint(
            x: rect.maxX - size.width,
            y: rect.minY + (rect.height - size.height) / 2
        )
        (text as NSString).draw(at: origin, withAttributes: attributes)
    }

    private func drawCheckbox(in rect: CGRect) {
        let side = min(rect.height, 15)
        let box = CGRect(
            x: rect.midX - side / 2 + 1,
            y: rect.midY - side / 2,
            width: side,
            height: side
        )
        let symbol = isChecked ? "checkmark.circle.fill" : "circle"
        let configuration = NSImage.SymbolConfiguration(pointSize: side, weight: .regular)
            .applying(NSImage.SymbolConfiguration(
                paletteColors: [isChecked ? .controlAccentColor : .tertiaryLabelColor]
            ))
        guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: isChecked ? "Completed" : "Not completed")?
            .withSymbolConfiguration(configuration) else { return }
        image.draw(in: box)
    }
}
