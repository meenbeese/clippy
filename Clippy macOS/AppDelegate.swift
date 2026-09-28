//
//  AppDelegate.swift
//  Clippy macOS
//
//  Created by Devran on 03.09.19.
//  Copyright © 2019 Devran. All rights reserved.
//

import Cocoa

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let applicationName = "Clippy"
    var window: NSWindow?
    var statusItem: NSStatusItem?
    var agentsMenuItem: NSMenuItem?
    var zoomMenuItem: NSMenuItem?
    var opacityMenuItem: NSMenuItem?
    static var agentController: AgentController?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        window = AgentWindow(contentRect: CGRect.zero, styleMask: [], backing: .buffered, defer: true)
        window?.title = applicationName
        window?.contentViewController = AgentViewController()
        if !Agent.agentNames().isEmpty {
            window?.makeKeyAndOrderFront(self)
        }
        window?.center()
        
        setupStatusBar()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func setupStatusBar() {
        let statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.imagePosition = .imageOnly
            button.toolTip = applicationName
            setStatusBarIcon(on: button)
        }
        
        setupStatusBarMenu()
    }
    
    /// An SF Symbol keeps the icon legible against both the light and the dark
    /// menu bar. `NSImage(systemSymbolName:)` already hands back a template
    /// image, but the flag is set explicitly — template rendering is what makes
    /// AppKit tint it.
    private func setStatusBarIcon(on button: NSStatusBarButton) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let symbol = NSImage(systemSymbolName: "paperclip",
                             accessibilityDescription: applicationName)?
            .withSymbolConfiguration(configuration)
        symbol?.isTemplate = true
        button.image = symbol
    }
    
    func createAgentsMenu() -> NSMenu {
        let agentsMenu = NSMenu(title: "Agents")
        let agentNames = Agent.agentNames()
        
        if agentNames.isEmpty {
            agentsMenu.addItem(withTitle: "No Agents found.",
                               action: nil,
                               keyEquivalent: "")
        }
        for agentName in agentNames {
            let item = NSMenuItem(title: agentName.capitalized,
                                  action: #selector(selectAgent(sender:)),
                                  keyEquivalent: "")
            if AppDelegate.agentController?.lastUsedAgent == agentName {
                item.state = .on
            }
            agentsMenu.addItem(item)
        }
        agentsMenu.addItem(NSMenuItem.separator())
        agentsMenu.addItem(withTitle: "Reload",
                           action: #selector(reloadAction(sender:)),
                           keyEquivalent: "")
        return agentsMenu
    }
    
    func createZoomMenu() -> NSMenu {
        let zoomMenu = NSMenu(title: "Zoom")
        let scale = AppDelegate.agentController?.scale ?? 1.0
        
        for preset in AgentController.scalePresets {
            let item = NSMenuItem(title: "\(Int((preset * 100).rounded()))%",
                                  action: #selector(setScaleAction(sender:)),
                                  keyEquivalent: "")
            item.representedObject = preset
            item.state = (preset == scale) ? .on : .off
            zoomMenu.addItem(item)
        }
        return zoomMenu
    }
    
    func createOpacityMenu() -> NSMenu {
        let opacityMenu = NSMenu(title: "Opacity")
        let opacity = AppDelegate.agentController?.opacity ?? 0.5
        
        for preset in AgentController.opacityPresets {
            let item = NSMenuItem(title: "\(Int((preset * 100).rounded()))%",
                                  action: #selector(setOpacityAction(sender:)),
                                  keyEquivalent: "")
            item.representedObject = preset
            item.state = (preset == opacity) ? .on : .off
            opacityMenu.addItem(item)
        }
        return opacityMenu
    }
    
    func setupStatusBarMenu() {
        // Status bar menu
        let statusBarMenu = NSMenu(title: "Clippy")
        agentsMenuItem = NSMenuItem(title: "Sprites", action: nil, keyEquivalent: "")
        zoomMenuItem = NSMenuItem(title: "Zoom", action: nil, keyEquivalent: "")
        opacityMenuItem = NSMenuItem(title: "Opacity", action: nil, keyEquivalent: "")
        guard let menuItem = agentsMenuItem,
              let zoomItem = zoomMenuItem,
              let opacityItem = opacityMenuItem else  { return }
        
        statusBarMenu.addItem(withTitle: "Show", action: #selector(showAction(sender:)), keyEquivalent: "")
        statusBarMenu.addItem(withTitle: "Hide", action: #selector(hideAction(sender:)), keyEquivalent: "")
        
        /// Built explicitly so the restored mute state gets its checkmark, which
        /// `toggleMuteAction` alone can only ever set on the item that was clicked.
        let muteItem = NSMenuItem(title: "Mute", action: #selector(toggleMuteAction(sender:)), keyEquivalent: "")
        muteItem.state = AppDelegate.agentController?.isMuted == true ? .on : .off
        statusBarMenu.addItem(muteItem)
        
        statusBarMenu.addItem(zoomItem)
        statusBarMenu.addItem(opacityItem)
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(menuItem)
        statusBarMenu.addItem(withTitle: "Show in Finder",
                           action: #selector(openFolderAction(sender:)),
                           keyEquivalent: "")
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(withTitle: "About \(applicationName)",
                           action: #selector(aboutAction(sender:)),
                           keyEquivalent: "")
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(withTitle: "Quit \(applicationName)", action: #selector(quitAction(sender:)), keyEquivalent: "")
        
        // Agents menu
        statusBarMenu.setSubmenu(createAgentsMenu(), for: menuItem)
        // Zoom menu
        statusBarMenu.setSubmenu(createZoomMenu(), for: zoomItem)
        // Opacity menu
        statusBarMenu.setSubmenu(createOpacityMenu(), for: opacityItem)
                statusItem?.menu = statusBarMenu
    }
    
    @objc func quitAction(sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }
    
    /// The app is an `LSUIElement`, so the panel has to be activated explicitly
    /// to land in front of whatever the user is working in.
    @objc func aboutAction(sender: AnyObject) {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        
        let credits = NSAttributedString(string: """
        Yes, Clippy from Microsoft Office is back — on macOS!
        
        The sprite maps, sounds and graphics were created by Microsoft.
        """)
        
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: applicationName,
            .applicationVersion: "\(version) (\(build))",
            .credits: credits,
        ])
    }
    
    @objc func reloadAction(sender: AnyObject) {
        agentsMenuItem?.submenu = createAgentsMenu()
    }
    
    @objc func openFolderAction(sender: AnyObject) {
        NSWorkspace.shared.open(Agent.agentsURL())
    }
    
    @objc func hideAction(sender: AnyObject) {
        AppDelegate.agentController?.hide()
    }
    
    @objc func showAction(sender: AnyObject) {
        window?.makeKeyAndOrderFront(self)
    }
    
    @objc func toggleMuteAction(sender: AnyObject) {
        guard let menuItem = sender as? NSMenuItem,
              let isMuted = AppDelegate.agentController?.isMuted else { return }
        let newValue = !isMuted
        AppDelegate.agentController?.setMuted(newValue)
        menuItem.state = newValue ? .on : .off
    }
    
    @objc func setScaleAction(sender: AnyObject) {
        guard let menuItem = sender as? NSMenuItem,
              let scale = menuItem.representedObject as? CGFloat else { return }
        AppDelegate.agentController?.setScale(scale)
        zoomMenuItem?.submenu = createZoomMenu()
    }
    
    @objc func setOpacityAction(sender: AnyObject) {
        guard let menuItem = sender as? NSMenuItem,
              let opacity = menuItem.representedObject as? CGFloat else { return }
        AppDelegate.agentController?.setOpacity(opacity)
        opacityMenuItem?.submenu = createOpacityMenu()
    }
    
    @objc func selectAgent(sender: AnyObject) {
        guard let menuItem = sender as? NSMenuItem else { return }
        let name = menuItem.title.lowercased()
        
        if window?.isVisible == true {
            AppDelegate.agentController?.load(name: name)
            if let animation = AppDelegate.agentController?.agent?.findAnimation("Show") {
                AppDelegate.agentController?.play(animation: animation)
            }
        } else {
            AppDelegate.agentController?.lastUsedAgent = name
            window?.makeKeyAndOrderFront(self)
        }
        
        agentsMenuItem?.submenu = createAgentsMenu()
    }
}
