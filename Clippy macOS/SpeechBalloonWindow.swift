//
//  SpeechBalloonWindow.swift
//  Clippy macOS
//
//  Copyright © 2026 Kuzey Bilgin. All rights reserved.
//

import Cocoa

/// Draws a speech balloon in the style the agent declares in its `.acd` file.
/// The bubble sits above the sprite and refers to it with a small tail.
@MainActor
final class SpeechBalloonView: NSView {
    private let text: NSAttributedString
    private let balloon: AgentBalloon
    private let font: NSFont
    private var textColor: NSColor
    private var bubbleColor: NSColor
    private var borderColor: NSColor
    private let bubbleRect: NSRect
    /// Where the tail hangs from, in this view's coordinates. Slid into place
    /// once the window knows where the sprite actually is; see `setTailAnchor`.
    private var tailAnchorX: CGFloat = 12

    private static let padding: CGFloat = 10
    private static let tailHeight: CGFloat = 18
    private static let drawOptions: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]

    init(text: String, balloon: AgentBalloon) {
        font = NSFont(name: balloon.fontName, size: CGFloat(balloon.fontHeight))
            ?? .systemFont(ofSize: CGFloat(balloon.fontHeight))
        textColor = Self.color(from: balloon.foregroundColor, fallback: .black)
        bubbleColor = Self.color(from: balloon.backgroundColor,
                                 fallback: NSColor(srgbRed: 1.0, green: 1.0, blue: 0.882, alpha: 1.0))
        borderColor = Self.color(from: balloon.borderColor, fallback: .black)
        self.balloon = balloon

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        self.text = NSAttributedString(string: text,
                                       attributes: [.font: font, .paragraphStyle: paragraph])

        // The bubble width follows the character budget declared in the `.acd`,
        // estimated from how wide this text actually renders.
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let averageCharacterWidth = text.isEmpty ? font.pointSize / 2
            : textSize.width / CGFloat(text.count)
        let bubbleWidth = min(320, max(120,
                                       CGFloat(balloon.charactersPerLine) * averageCharacterWidth + 2 * Self.padding))
        let textWidth = bubbleWidth - 2 * Self.padding
        // Measure with the exact options used at draw time; any missing option
        // (font leading in particular) clips the last line off the bubble.
        let wrapped = self.text.boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: Self.drawOptions
        )
        let minHeight = CGFloat(balloon.numberOfLines) * font.boundingRectForFont.height
        let bubbleHeight = max(minHeight, ceil(wrapped.height) + 4) + 2 * Self.padding

        bubbleRect = NSRect(x: 0, y: Self.tailHeight, width: bubbleWidth, height: bubbleHeight)
        super.init(frame: NSRect(x: 0, y: 0,
                                 width: bubbleWidth,
                                 height: bubbleHeight + Self.tailHeight))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Slides the tail along the bottom edge of the bubble so its tip aims at
    /// the sprite's mouth. Values are simply clamped, so a sprite that sits at
    /// the screen edge gets the closest possible tail; the left lean of the
    /// tail (tip 18 pt left of its base) is kept in all cases.
    func setTailAnchor(_ x: CGFloat) {
        // Room for the 18–52 pt lean span, so the base never leaves the bubble.
        tailAnchorX = min(max(x, bubbleRect.minX + 20), bubbleRect.maxX - 54)
        needsDisplay = true
    }

    /// MSAgent stores balloon colors as OLE `COLORREF`: `00BBGGRR` in hex.
    private static func color(from colorRef: String, fallback: NSColor) -> NSColor {
        guard colorRef.count == 8,
              let value = UInt32(colorRef, radix: 16)
        else {
            return fallback
        }
        let red = value & 0xFF
        let green = (value >> 8) & 0xFF
        let blue = (value >> 16) & 0xFF
        return NSColor(deviceRed: CGFloat(red) / 255,
                       green: CGFloat(green) / 255,
                       blue: CGFloat(blue) / 255,
                       alpha: 1.0)
    }

    override func draw(_: NSRect) {
        NSColor.clear.setFill()
        bounds.fill()

        // Bubble
        // Bubble. All corners are rounded — the tail attaches to the right of
        // the bottom-left corner, exactly as the original Office balloons did.
        let bubble = NSBezierPath(roundedRect: bubbleRect,
                                  xRadius: 10, yRadius: 10)
        bubbleColor.setFill()
        bubble.fill()
        borderColor.setStroke()
        bubble.lineWidth = 1.5
        bubble.stroke()

        // Tail pointing down toward the sprite this window is attached to.
        // Tip, base and lean all follow `tailAnchorX`, which layout slides to
        // sit above the sprite's mouth.
        let baseLeft = NSPoint(x: tailAnchorX + 18, y: bubbleRect.minY)
        let baseRight = NSPoint(x: tailAnchorX + 52, y: bubbleRect.minY)
        let tip = NSPoint(x: tailAnchorX, y: 2)
        let tail = NSBezierPath()
        tail.move(to: baseLeft)
        tail.line(to: tip)
        tail.line(to: baseRight)
        tail.close()
        bubbleColor.setFill()
        tail.fill()
        tail.lineWidth = 1.5
        // Only the two open sides carry the border; the seam along the bubble
        // edge is filled over above, so it stays hidden.
        let tailSides = NSBezierPath()
        tailSides.move(to: baseLeft)
        tailSides.line(to: tip)
        tailSides.line(to: baseRight)
        tailSides.stroke()

        // Text
        let textRect = bubbleRect.insetBy(dx: Self.padding, dy: Self.padding)
        text.draw(with: textRect, options: Self.drawOptions)
    }
}

/// A click-through, decorative window that displays a `SpeechBalloonView`
/// above the sprite window and moves with it as a child window.
@MainActor
final class SpeechBalloonWindow: NSWindow {
    init(text: String, balloon: AgentBalloon) {
        let content = SpeechBalloonView(text: text, balloon: balloon)
        super.init(contentRect: NSRect(origin: .zero, size: content.bounds.size),
                   styleMask: [.borderless],
                   backing: .buffered,
                   defer: false)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        level = .floating
        // The view controller keeps a strong reference and reuses/removes this
        // window; `close()` must not additionally release it out from under ARC.
        isReleasedWhenClosed = false
        contentView = content
    }

    /// Attaches the balloon above the sprite: the tail tip lands just above the
    /// sprite's top edge, like the original Office Assistant balloons did.
    func present(above spriteWindow: NSWindow) {
        spriteWindow.addChildWindow(self, ordered: .above)
        layout(above: spriteWindow)
        orderFrontRegardless()
    }

    private func layout(above spriteWindow: NSWindow) {
        let sprite = spriteWindow.frame
        // The tail aims at the sprite's mouth: its horizontal middle, a step
        // above the top edge. Centering the bubble over that point reads as
        // one "speaker"; when the screen edge then shifts the bubble, the
        // tail slides along the bottom edge to stay pointed at the sprite.
        let mouthX = sprite.midX
        var origin = NSPoint(x: mouthX - frame.width / 2, y: sprite.maxY + 2)
        if let visible = (spriteWindow.screen ?? NSScreen.main)?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 2),
                           visible.maxX - frame.width - 2)
            origin.y = min(origin.y, visible.maxY - frame.height)
        }
        setFrameOrigin(origin)
        (contentView as? SpeechBalloonView)?.setTailAnchor(mouthX - origin.x)
    }
}
