//
//  AddAgentMenuItem.swift
//  Clippy macOS
//
//  Menu action that converts a decompiled agent folder into an installable
//  `.agent` bundle, replacing the `agent-convert.sh` step in the README.
//

import Cocoa

@MainActor
extension AppDelegate {
    private static let addAgentItemTitle = "Add Agent…"
    private static let convertingAgentItemTitle = "Converting…"

    /// Opens a folder picker, converts the chosen decompiled agent and reloads
    /// the agents menu so the new entry can be picked straight away.
    @objc func addAgentAction(sender: AnyObject) {
        let panel = NSOpenPanel()
        panel.title = "Choose a Decompiled Agent"
        panel.message = "Select the folder the MSAgent Decompiler wrote. It should contain an .acd file, plus Images and Audio folders."
        panel.prompt = "Add Agent"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let sourceURL = panel.url else { return }
            Task { @MainActor in
                self?.convertAgent(at: sourceURL)
            }
        }
    }

    private func convertAgent(at sourceURL: URL) {
        let name = AgentConverter.sanitize(sourceURL.lastPathComponent)
        guard !name.isEmpty else {
            presentAlert(title: "Could Not Add Agent",
                         message: "“\(sourceURL.lastPathComponent)” has no usable characters in its name. Rename the folder to lowercase letters, digits, “-” or “_”.")
            return
        }

        setAddAgentItemBusy(true)
        // An agent carries hundreds of sprites, so decoding and tiling them runs
        // off the main actor; only the menu and the alerts come back to it.
        Task { @MainActor in
            do {
                _ = try await Task.detached(priority: .userInitiated) {
                    try AgentConverter.convert(agentAt: sourceURL, named: name)
                }.value
                setAddAgentItemBusy(false)
                agentsMenuItem?.submenu = createAgentsMenu()
                presentAlert(title: "Agent Added",
                             message: "“\(name)” is ready. Pick it under Sprites.")
            } catch {
                setAddAgentItemBusy(false)
                agentsMenuItem?.submenu = createAgentsMenu()
                presentAlert(title: "Could Not Convert “\(name)”",
                             message: error.localizedDescription)
            }
        }
    }

    /// Renames the menu item while a conversion runs, which is the only progress
    /// feedback there is: a modal progress panel would have to spin a run loop
    /// that the conversion itself is waiting on.
    private func setAddAgentItemBusy(_ isBusy: Bool) {
        statusBarMenuItem(withTitle: isBusy ? Self.convertingAgentItemTitle : Self.addAgentItemTitle)?
            .title = isBusy ? Self.convertingAgentItemTitle : Self.addAgentItemTitle
        statusBarMenuItem(withTitle: isBusy ? Self.convertingAgentItemTitle : Self.addAgentItemTitle)?.isEnabled = !isBusy
    }

    private func statusBarMenuItem(withTitle title: String) -> NSMenuItem? {
        statusItem?.menu?.items.first { $0.title == title }
    }

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
