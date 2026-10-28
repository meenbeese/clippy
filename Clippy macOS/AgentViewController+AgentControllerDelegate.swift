//
//  AgentViewController+AgentDelegate.swift
//  Clippy macOS
//
//  Created by Devran on 08.09.19.
//  Copyright © 2026 Kuzey Bilgin. All rights reserved.
//

import Cocoa

extension AgentViewController: AgentControllerDelegate {
    func willLoadAgent(agent: Agent) {
        guard let window = view.superview?.window else { return }
        
        var agentName = agent.resourceName
        if let name = agent.character.infos.first(where: { $0.language == "0x0009" })?.name {
            agentName = name
        }
        
        window.title = agentName
        
        /// Disable animation, when the window was not moved before.
        /// This happens, when the window was initially created.
        let animated = window.frame.origin.x > 0 && window.frame.origin.y > 0
        resizeWindow(toFit: agent.character, animated: animated)
    }
    
    func didLoadAgent(agent: Agent) {
        agentController.lastUsedAgent = agent.resourceName
    }
    
    /// The window keeps the 2x headroom the agent sprite has always been drawn
    /// into, multiplied by the current zoom factor.
    private func resizeWindow(toFit character: AgentCharacter, animated: Bool) {
        guard let window = view.superview?.window else { return }
        let scale = agentController.scale * 2
        let size = CGSize(width: character.size.width * scale,
                          height: character.size.height * scale)
        let rect = CGRect(origin: window.frame.origin, size: size)
        window.setFrame(rect, display: true, animate: animated)
        /// The very first sprite sizes the window and picks its default spot;
        /// after that only the position the user has chosen is kept safe.
        if let agentWindow = window as? AgentWindow {
            if agentWindow.hasDefaultPosition {
                agentWindow.clampToVisibleScreen()
            } else {
                agentWindow.moveToLowerRightCorner()
            }
        }
    }
    
    func handleHide() {
        if let animation = agentController.agent?.findAnimation("Hide") {
            agentController.play(animation: animation) {
                self.agentController.isHidden = true
                NSApp.hide(self)
            }
        }
    }
    
    func handleShow() {
        view.superview?.window?.makeKeyAndOrderFront(self)
        agentController.isHidden = false
        if let animation = agentController.agent?.findAnimation("Show") {
            agentController.play(animation: animation)
        }
    }
    
    func handleScaleChange() {
        guard let character = agentController.agent?.character else { return }
        resizeWindow(toFit: character, animated: true)
    }
    
    func handleOpacityChange() {
        guard let window = view.superview?.window as? AgentWindow else { return }
        window.unfocusedAlpha = agentController.opacity
        window.applyAlpha(isForeground: window.isKeyWindow)
    }
}
