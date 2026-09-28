//
//  AgentController.swift
//  Clippy macOS
//
//  Created by Devran on 07.09.19.
//  Copyright © 2019 Devran. All rights reserved.
//

import Cocoa
import AVKit
import SpriteKit

@MainActor
class AgentController {
    /// Zoom factors offered in the status bar menu. 1.0 keeps the current size.
    static let scalePresets: [CGFloat] = [0.5, 0.75, 1.0, 1.5, 2.0, 3.0]
    
    var isMuted = false
    let player = AVPlayer()
    
    var agent: Agent?
    var agentView: AgentView?
    
    var delegate: (any AgentControllerDelegate)?
    var isHidden = true
    private(set) var scale: CGFloat = 1.0
    
    init() {
    }
    
    convenience init(agentView: AgentView) {
        self.init()
        self.agentView = agentView
    }
    
    /// - Returns: `false`, if no agent with that name could be read.
    @discardableResult
    func load(name: String) -> Bool {
        guard let agent = Agent(resourceName: name) else { return false }
        delegate?.willLoadAgent(agent: agent)
        self.agent = agent
        showInitialFrame()
        delegate?.didLoadAgent(agent: agent)
        return true
    }
    
    func audioActionForFrame(frame: AgentFrame) -> SKAction? {
        guard let agent, let soundIndex = frame.soundIndex else { return nil }
        let soundURL = agent.soundURL(forIndex: soundIndex)
        let action = SKAction.run { [weak self] in
            guard let self else { return }
            let playerItem = AVPlayerItem(url: soundURL)
            self.player.replaceCurrentItem(with: playerItem)
            self.player.play()
            self.player.volume = self.isMuted ? 0 : 1.0
        }
        return action
    }
    
    func showInitialFrame() {
        guard let agent else { return }
        self.agentView?.agentSprite.texture = SKTexture(cgImage: try! agent.textureAtIndex(index: 0))
    }
    
    /// Cutting the frames out of the sprite map and merging them is the expensive
    /// part, so it runs off the main actor. `SKTexture` is not `Sendable`, so only
    /// the `CGImage`s cross over and the textures are built back on the main actor.
    func play(animation: AgentAnimation, withSoundEnabled soundEnabled: Bool = true, completion: (() -> Void)? = nil) {
        guard let agent else { return }
        
        /// All three arrays below are derived from `frames`, so they always share its count.
        let frames = animation.frames
        let durations = frames.map(\.durationInSeconds)
        let soundActions: [SKAction?] = soundEnabled ? frames.map(audioActionForFrame(frame:)) : []
        
        Task { @MainActor [weak self] in
            let images = await Task.detached(priority: .userInitiated) {
                frames.map { agent.imageForFrame($0) }
            }.value
            
            guard let self else { return }
            
            var actions: [SKAction] = []
            for (index, image) in images.enumerated() {
                if let soundAction = soundActions[index] {
                    actions.append(soundAction)
                }
                let texture = SKTexture(cgImage: image)
                texture.filteringMode = .nearest
                actions.append(SKAction.animate(with: [texture], timePerFrame: durations[index]))
            }
            
            self.agentView?.agentSprite.removeAllActions()
            await self.agentView?.agentSprite.run(SKAction.sequence(actions))
            completion?()
        }
    }
    
    func animate() {
        guard let animation = agent?.animations.randomElement() else { return }
        play(animation: animation)
    }
    
    func hide() {
        delegate?.handleHide()
    }
    
    func show() {
        delegate?.handleShow()
    }
    
    func setScale(_ scale: CGFloat) {
        guard scale != self.scale else { return }
        self.scale = scale
        agentView?.agentScale = scale
        delegate?.handleScaleChange()
    }
}
