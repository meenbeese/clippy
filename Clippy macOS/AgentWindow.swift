//
//  AgentWindow.swift
//  Clippy macOS
//
//  Created by Devran on 07.09.19.
//  Copyright © 2026 Kuzey Bilgin. All rights reserved.
//

import Cocoa

class AgentWindow: NSWindow {
    /// Alpha used whenever the window is not in the foreground.
    /// Driven by the Opacity menu, see `AgentController.opacity`.
    var unfocusedAlpha: CGFloat = 0.5

    /// Set once the window has received its default bottom-right position.
    /// Later sprite changes keep the position the user moved it to.
    var hasDefaultPosition = false

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        level = NSWindow.Level.floating
        canHide = true
        backingType = .buffered
        isMovable = true
        isMovableByWindowBackground = true
        #if DEBUG
            // Diagnosing the transparent window needs content visible against a
            // white background and a title bar; the shipped build stays seamless.
            backgroundColor = .white
            styleMask = [.titled]
        #else
            backgroundColor = .clear
        #endif

        // Fixes glitches
        hasShadow = false
        isOpaque = true
        delegate = self
    }

    override var canBecomeKey: Bool {
        true
    }

    /// Places the window at the bottom-right of the usable screen area.
    /// A small margin keeps Clippy off the Dock; `visibleFrame` already
    /// excludes the menu bar.
    func moveToLowerRightCorner() {
        guard let visibleFrame = (screen ?? NSScreen.main)?.visibleFrame else { return }
        let margin: CGFloat = 16
        var frame = frame
        frame.origin.x = visibleFrame.maxX - frame.width - margin
        frame.origin.y = visibleFrame.minY + margin
        setFrameOrigin(frame.origin)
        hasDefaultPosition = true
    }

    /// Keeps the window fully on screen whenever it changes size, so a bigger
    /// sprite or higher zoom can never push it off screen or under the Dock.
    func clampToVisibleScreen() {
        guard let visibleFrame = (screen ?? NSScreen.main)?.visibleFrame,
              frame.width <= visibleFrame.width, frame.height <= visibleFrame.height else { return }
        var frame = frame
        frame.origin.x = min(max(frame.origin.x, visibleFrame.minX), visibleFrame.maxX - frame.width)
        frame.origin.y = min(max(frame.origin.y, visibleFrame.minY), visibleFrame.maxY - frame.height)
        if frame.origin != self.frame.origin {
            setFrameOrigin(frame.origin)
        }
    }
}

extension AgentWindow: NSWindowDelegate {
    func windowDidResignKey(_: Notification) {
        applyAlpha(isForeground: false)
    }

    func windowDidBecomeKey(_: Notification) {
        applyAlpha(isForeground: true)
    }

    func applyAlpha(isForeground: Bool) {
        alphaValue = isForeground ? 1.0 : unfocusedAlpha
    }
}
