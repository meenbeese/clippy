//
//  AgentViewController.swift
//  Clippy
//
//  Created by Devran on 04.09.19.
//  Copyright © 2026 Kuzey Bilgin. All rights reserved.
//

import AppKit

class AgentViewController: NSViewController {
    var agentController: AgentController
    var agentView: AgentView
    var balloonWindow: SpeechBalloonWindow?
    var balloonDismissWorkItem: DispatchWorkItem?
    /// Idle chatter scheduling. A non-`nil` work item is the scheduled next
    /// line; cancelling and clearing it pauses the chatter entirely.
    var idleChatterWorkItem: DispatchWorkItem?
    /// Shuffled deck of idle tips, so a line repeats only after the whole
    /// cycle has been spoken once.
    var idleLineDeck: [String] = []
    
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
        agentView.pressAction = { [weak self] in
            guard let self else { return }
            agentController.animate()
            speakRandomBalloonLine()
        }
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
        restartIdleChatter()
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
        restartIdleChatter()
    }

    override func mouseExited(with event: NSEvent) {
        (view.superview?.window as? AgentWindow)?.applyAlpha(isForeground: false)
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
        restartIdleChatter()
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
        restartIdleChatter()
        if event.clickCount == 2 {
            agentController.animate()
            speakRandomBalloonLine()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        restartIdleChatter()
        guard let _ = agentController.agent else { return }
        
        let menu = NSMenu(title: "Sprite")
        let hideItem = NSMenuItem(title: "Hide",
                                  action: #selector(hideAction(sender:)),
                                  keyEquivalent: "")
        hideItem.keyEquivalent = "h"
        hideItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(hideItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Options…",
                                action: nil,
                                keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Choose Assistant…",
                                action: #selector(chooseAssistantAction),
                                keyEquivalent: ""))
        let animateItem = NSMenuItem(title: "Animate!",
                                     action: #selector(animateAction(sender:)),
                                     keyEquivalent: "")
        animateItem.keyEquivalent = "a"
        animateItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(animateItem)
        NSMenu.popUpContextMenu(menu, with: event, for: agentView)
    }
    
    /// Classic Office Assistant lines for the balloon, shown when the sprite
    /// animates on demand.
    private static let balloonLines = [
        "It looks like you're writing a letter. Would you like help?",
        "Is there something I can do for you?",
        "Did you know? I can animate on demand!",
        "This looks like something we should investigate…",
        "Would you like me to try that again?",
        "You seem to be having trouble with your computer. How can I help?",
        "What would you like to do today?",
        "Great! Let's get started.",
        "I'm glad I could help!",
        "Hold on a moment… still thinking.",
        "Excellent choice! Watch this.",
        "That was fun! Would you like to see another trick?",
        "Nothing seems to be going wrong today. Enjoy!",
        "Did you know I've been around since 1997?",
        "Tip: The arrow keys make me look around.",
        "Would you like me to call a different assistant? Press Return!",
    ]

    /// Friendly lines spoken on their own when nothing has happened for a
    /// while, in the style of the original Office Assistant. Tips use the
    /// app's real shortcuts so they are always true.
    private static let idleLines = [
        "It looks like you're writing a letter. Would you like help?",
        "Hello! Everything is going well here.",
        "Just checking in. Is everything all right?",
        "It's been a while! Would you like to see a trick?",
        "I've been watching… you're doing great!",
        "Tip: Press ⌘⇧A to make me animate at any time.",
        "Tip: The arrow keys make me look around.",
        "Tip: Press Return to call a different assistant.",
        "Tip: Right-click me for more options.",
        "Tip: You can drag me anywhere on the screen.",
        "Tip: Press ⌘⇧M to mute my sound effects.",
        "Tip: Press ⌘⇧H when you'd like me to take a break.",
        "Tip: Zoom and Opacity live in the paperclip menu.",
        "Did you know? I can animate on demand!",
    ]

    /// Schedules the next idle line, 2–5 minutes out. Every user interaction
    /// goes through here first, so the plan for the next chatter only exists
    /// while the last one has a chance to fire quietly.
    func restartIdleChatter() {
        idleChatterWorkItem?.cancel()
        let chatter = DispatchWorkItem { [weak self] in
            self?.speakIdleLine()
        }
        idleChatterWorkItem = chatter
        let delay = TimeInterval.random(in: Self.idleChatterMinDelay...Self.idleChatterMaxDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: chatter)
    }

    /// Drops the scheduled idle line without re-arming; used while Clippy is
    /// hidden, so a visually absent assistant does not keep chattering.
    func stopIdleChatter() {
        idleChatterWorkItem?.cancel()
        idleChatterWorkItem = nil
    }

    private static let idleChatterMinDelay: TimeInterval = 2 * 60
    private static let idleChatterMaxDelay: TimeInterval = 5 * 60

    private func speakIdleLine() {
        defer { restartIdleChatter() }
        // Reduce Motion suppresses the animations that accompany the lines;
        // a repeated static sprite popping up text would only distract.
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        guard let window = view.superview?.window, window.isVisible,
              !agentController.isHidden, agentController.agent != nil,
              balloonWindow == nil else { return }
        if idleLineDeck.isEmpty {
            idleLineDeck = Self.idleLines.shuffled()
        }
        guard let line = idleLineDeck.popLast() else { return }
        agentController.animate()
        agentController.speak(line)
    }

    private func speakRandomBalloonLine() {
        guard let line = Self.balloonLines.randomElement() else { return }
        agentController.speak(line)
    }

    @objc func animateAction(sender: AnyObject) {
        agentController.animate()
        speakRandomBalloonLine()
    }

    @objc func hideAction(sender: AnyObject) {
        agentController.hide()
    }
    
    @objc func optionsAction(sender: AnyObject) {
        let viewController = BalloonViewController(nibName: nil, bundle: nil)
        let popOver = NSPopover()
        popOver.behavior = .semitransient
        popOver.contentSize = CGSize(width: 200, height: 300)
        popOver.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popOver.contentViewController = viewController
        let rect = self.view.frame
        popOver.show(relativeTo: rect, of: view, preferredEdge: NSRectEdge.maxY)
    }
}
