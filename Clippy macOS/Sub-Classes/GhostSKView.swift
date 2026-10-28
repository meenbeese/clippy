//
//  GhostSKView.swift
//  Clippy macOS
//
//  Created by Devran on 04.09.19.
//  Copyright © 2026 Kuzey Bilgin. All rights reserved.
//

import SpriteKit

class GhostSKView: SKView {
    override open func hitTest(_: NSPoint) -> NSView? {
        superview
    }
}
