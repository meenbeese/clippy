//
//  AgentViewController.swift
//  Clippy
//
//  Created by Devran on 04.09.19.
//  Copyright © 2019 Devran. All rights reserved.
//

import AppKit

class AgentViewController: NSViewController {
    var agentController: AgentController
    var agentView: AgentView
    
    init() {
        agentView = AgentView()
        agentController = AgentController(agentView: agentView)
        AppDelegate.agentController = agentController
        super.init(nibName: nil, bundle: nil)
        agentController.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        let size = CGSize(width: 100, height: 200)
        view = NSView(frame: CGRect(origin: CGPoint.zero, size: size))
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(agentView)
        setupConstraints()
        setupTrackingArea()
    }
    
    
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(self)
        
        // Restored settings are applied here rather than from `AppDelegate` because
        // this is the first point where the window is known to exist, and it happens
        // before the first load so the sprite is never drawn at the wrong size.
        agentController.applyRestoredSettings()
        
        let name = agentController.lastUsedAgent ?? Agent.randomAgentName()
        if let name {
            agentController.load(name: name)
            agentController.show()
        }
    }
    
    func setupConstraints() {
        agentView.translatesAutoresizingMaskIntoConstraints = false
        agentView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        agentView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        view.rightAnchor.constraint(equalTo: agentView.rightAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: agentView.bottomAnchor).isActive = true
    }
    
    func setupTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .inVisibleRect, .activeAlways]
        let trackingArea = NSTrackingArea(rect: view.frame, options: options, owner: self, userInfo: nil)
        view.addTrackingArea(trackingArea)
    }
}

extension AgentViewController {
    override func mouseEntered(with event: NSEvent) {
        (view.superview?.window as? AgentWindow)?.applyAlpha(isForeground: true)
    }
    
    override func mouseExited(with event: NSEvent) {
        (view.superview?.window as? AgentWindow)?.applyAlpha(isForeground: false)
    }
    
    @objc func animateAction() {
        agentController.animate()
    }
    
    @objc func chooseAssistantAction() {
        guard let name = Agent.randomAgentName() else { return }
        agentController.load(name: name)
    }
    
    override var acceptsFirstResponder: Bool {
        true
    }
    
    override func becomeFirstResponder() -> Bool {
        true
    }
    
    /// Plays one of the four directional "look" animations, ignoring the key if the
    /// agent does not define it.
    private func look(_ name: String, of agent: Agent) {
        guard let animation = agent.findAnimation(name) else { return }
        agentController.play(animation: animation)
    }
    
    /// Matching `NSEvent.specialKey` rather than `keyCode`.
    ///
    /// The four arrow codes were four adjacent integers, which is exactly how the
    /// left/right pair came to be swapped: nothing about `124` says "right", whereas
    /// `.rightArrow` cannot be paired with the wrong animation by accident. Modifiers
    /// are ignored, so Cmd-arrow behaves as it did.
    override func keyDown(with event: NSEvent) {
        guard let agent = agentController.agent else {
            super.keyDown(with: event)
            return
        }
        
        // Space is printable, so it has no `SpecialKey` of its own.
        if event.charactersIgnoringModifiers == " " {
            agentController.animate()
            return
        }
        
        switch event.specialKey {
        case .carriageReturn, .enter:
            guard let name = Agent.randomAgentName() else { return }
            agentController.load(name: name)
            agentController.show()
        case .leftArrow:
            look("LookLeft", of: agent)
        case .rightArrow:
            look("LookRight", of: agent)
        case .upArrow:
            look("LookUp", of: agent)
        case .downArrow:
            look("LookDown", of: agent)
        default:
            super.keyDown(with: event)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            agentController.animate()
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        guard let _ = agentController.agent else { return }
        
        let menu = NSMenu(title: "Agent")
        let menuItems = [
            NSMenuItem(title: "Hide",
                       action: #selector(hideAction(sender:)),
                       keyEquivalent: ""),
            NSMenuItem.separator(),
            NSMenuItem(title: "Options…",
                       action: nil,
                       keyEquivalent: ""),
            NSMenuItem(title: "Choose Assistant…",
                       action: #selector(chooseAssistantAction),
                       keyEquivalent: ""),
            NSMenuItem(title: "Animate!",
                       action: #selector(animateAction),
                       keyEquivalent: "")
        ]
        
        for (index, menuItem) in menuItems.enumerated() {
            menu.insertItem(menuItem, at: index)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: agentView)
    }
    
    @objc func hideAction(sender: AnyObject) {
        agentController.hide()
    }
    
    @objc func optionsAction(sender: AnyObject) {
        let viewController = BalloonViewController(nibName: nil, bundle: nil)
        let popOver = NSPopover()
        popOver.behavior = .semitransient
        popOver.contentSize = CGSize(width: 200, height: 300)
        popOver.animates = true
        popOver.contentViewController = viewController
        let rect = self.view.frame
        popOver.show(relativeTo: rect, of: view, preferredEdge: NSRectEdge.maxY)
    }
}
