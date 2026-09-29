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
import os

@MainActor
class AgentController {
    /// Zoom factors offered in the status bar menu. 1.0 keeps the current size.
    static let scalePresets: [CGFloat] = [0.5, 0.75, 1.0, 1.5, 2.0, 3.0]
    
    /// Alpha values offered in the status bar menu. 1.0 never dims the window.
    static let opacityPresets: [CGFloat] = [0.25, 0.5, 0.75, 1.0]
    
    var isMuted = false
    let player = AVPlayer()
    
    var agent: Agent?
    var agentView: AgentView?
    
    var delegate: (any AgentControllerDelegate)?
    var isHidden = true
    private(set) var scale: CGFloat
    private(set) var opacity: CGFloat
    
    /// The agent to reopen on the next launch. Owned here rather than on
    /// `AppDelegate` so every persisted value lives in one place.
    var lastUsedAgent: String? {
        didSet {
            guard lastUsedAgent != oldValue else { return }
            persist()
        }
    }
    
    private let settingsStore: SettingsStore
    private let log = Logger(subsystem: "com.meenbeese.clippy", category: "settings")
    
    init(settingsStore: SettingsStore = SettingsStore()) {
        self.settingsStore = settingsStore
        let settings = settingsStore.load()
        self.scale = settings.scale
        self.opacity = settings.opacity
        self.isMuted = settings.isMuted
        self.lastUsedAgent = settings.lastUsedAgent
    }
    
    convenience init(agentView: AgentView, settingsStore: SettingsStore = SettingsStore()) {
        self.init(settingsStore: settingsStore)
        self.agentView = agentView
    }
    
    /// Pushes the restored settings into the view and the window.
    ///
    /// Call once from `AppDelegate` after both exist. Reading them back out of
    /// `Settings` would be pointless — `AgentView` and `AgentWindow` each keep
    /// their own default, so setting the stored property alone leaves the sprite
    /// and the window alpha stale.
    func applyRestoredSettings() {
        agentView?.agentScale = scale
        delegate?.handleScaleChange()
        delegate?.handleOpacityChange()
    }
    
    private func persist() {
        let settings = Settings(scale: scale,
                                opacity: opacity,
                                isMuted: isMuted,
                                lastUsedAgent: lastUsedAgent)
        do {
            try settingsStore.save(settings)
        } catch {
            log.error("Could not save settings: \(error.localizedDescription, privacy: .public)")
        }
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
        guard let agent, let image = agent.textureAtIndex(index: 0) else { return }
        agentView?.agentSprite.texture = SKTexture(cgImage: image)
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
                // A frame we cannot render is skipped whole, so its sound does not
                // outlive the missing image. `durations` and `soundActions` stay
                // index-aligned with `frames` because this loop never reorders them.
                guard let image else { continue }
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
        persist()
    }
    
    func setOpacity(_ opacity: CGFloat) {
        guard opacity != self.opacity else { return }
        self.opacity = opacity
        delegate?.handleOpacityChange()
        persist()
    }
    
    func setMuted(_ isMuted: Bool) {
        guard isMuted != self.isMuted else { return }
        self.isMuted = isMuted
        persist()
    }
}
