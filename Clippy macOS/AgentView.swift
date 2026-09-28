//
//  AgentView.swift
//  Clippy macOS
//
//  Created by Devran on 07.09.19.
//  Copyright © 2019 Devran. All rights reserved.
//

import Cocoa
import SpriteKit

class AgentView: NSView {
    lazy var skView: SKView = {
        let skView = GhostSKView()
        skView.wantsLayer = true
        skView.allowsTransparency = true
        skView.layer?.backgroundColor = .clear
        return skView
    }()
    
    lazy var scene: SKScene = {
        let scene = SKScene(size: frame.size)
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        scene.addChild(agentSprite)
        return scene
    }()
    
    lazy var agentSprite: SKSpriteNode = {
        let sprite = SKSpriteNode()
        sprite.position = CGPoint.zero
        sprite.anchorPoint = CGPoint.zero
        return sprite
    }()
    
    /// Zoom factor relative to the size the agent already has.
    ///
    /// `SKSpriteNode.size` only affects `frame` and physics bodies, never how the
    /// texture is drawn, so scaling has to go through `xScale`/`yScale`.
    var agentScale: CGFloat = 1.0 {
        didSet {
            guard agentScale != oldValue else { return }
            applyScale()
        }
    }
    
    private func applyScale() {
        agentSprite.xScale = agentScale
        agentSprite.yScale = agentScale
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = .clear
        
        addSubview(skView)
        
        setupConstraints()
        
        skView.presentScene(scene)
        applyScale()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        agentSprite.size = frame.size
    }
    
    func setupConstraints() {
        skView.translatesAutoresizingMaskIntoConstraints = false
        skView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        skView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        rightAnchor.constraint(equalTo: skView.rightAnchor).isActive = true
        bottomAnchor.constraint(equalTo: skView.bottomAnchor).isActive = true
    }

}
