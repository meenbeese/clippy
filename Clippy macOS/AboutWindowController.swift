//
//  AboutWindowController.swift
//  Clippy macOS
//
//  Copyright © 2026 Kuzey Bilgin. All rights reserved.
//

import Cocoa

final class AboutViewController: NSViewController {

    private let githubURL = URL(string: "https://github.com/meenbeese/clippy")!

    override func loadView() {
        let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 420, height: 520))
        container.material = .underWindowBackground
        container.blendingMode = .behindWindow
        container.state = .active
        container.autoresizingMask = [.width, .height]

        let clippy = NSImageView(image: NSApp.applicationIconImage)
        clippy.translatesAutoresizingMaskIntoConstraints = false
        clippy.wantsLayer = true
        NSLayoutConstraint.activate([
            clippy.widthAnchor.constraint(equalToConstant: 128),
            clippy.heightAnchor.constraint(equalToConstant: 128),
        ])

        let nameLabel = Self.label("Clippy", font: .systemFont(ofSize: 28, weight: .bold),
                                   color: .labelColor)

        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        let versionLabel = Self.label("Version \(version) (\(build))",
                                      font: .systemFont(ofSize: 13),
                                      color: .secondaryLabelColor)

        let tagline = Self.label("Yes, Clippy from Microsoft Office is back — on macOS!",
                                 font: .systemFont(ofSize: 14),
                                 color: .labelColor)

        let credits = Self.label("The sprite maps, sounds and graphics were created by Microsoft.",
                                 font: .systemFont(ofSize: 11),
                                 color: .secondaryLabelColor)

        let copyright = Self.label(info?["NSHumanReadableCopyright"] as? String ?? "",
                                   font: .systemFont(ofSize: 10),
                                   color: .tertiaryLabelColor)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            separator.widthAnchor.constraint(equalToConstant: 220),
        ])

        let linkButton = NSButton(title: "View Source on GitHub",
                                  target: self,
                                  action: #selector(openGitHub(sender:)))
        linkButton.translatesAutoresizingMaskIntoConstraints = false
        linkButton.bezelStyle = .rounded
        linkButton.controlSize = .small

        let stack = NSStackView(views: [clippy, nameLabel, versionLabel, tagline,
                                        separator, credits, linkButton, copyright])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(6, after: versionLabel)
        stack.setCustomSpacing(18, after: tagline)
        stack.setCustomSpacing(18, after: separator)
        stack.setCustomSpacing(18, after: linkButton)

        container.addSubview(stack)

        for label in [tagline, credits, copyright] {
            label.widthAnchor.constraint(equalToConstant: 300).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: 10),
        ])

        bob(clippy)
        view = container
    }

    /// Clippy earns his keep: an endless gentle bobbing motion.
    private func bob(_ clippy: NSImageView) {
        let bobbing = CAKeyframeAnimation(keyPath: "transform.translation.y")
        bobbing.values = [0, -7, 0, -3, 0]
        bobbing.keyTimes = [0, 0.4, 0.65, 0.85, 1]
        bobbing.duration = 2.6
        bobbing.repeatCount = .infinity
        bobbing.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        clippy.layer?.add(bobbing, forKey: "clippy-bob")
    }

    private static func label(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.alignment = .center
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    @objc func openGitHub(sender: AnyObject) {
        NSWorkspace.shared.open(githubURL)
    }
}

final class AboutWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
                              styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered,
                              defer: false)
        window.title = "About Clippy"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        // Held strongly by `AppDelegate` and reused, so manual closing must not
        // free the window while the reference still exists.
        window.isReleasedWhenClosed = false
        window.contentViewController = AboutViewController()
        window.center()
        self.init(window: window)
    }
}
