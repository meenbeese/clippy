//
//  AgentCharacterDescription.swift
//  Clippy
//
//  Created by Devran on 06.09.19.
//  Copyright © 2019 Devran. All rights reserved.
//

import Foundation
import SpriteKit

struct Agent {
    var character: AgentCharacter
    var balloon: AgentBalloon
    var animations: [AgentAnimation]
    var states: [AgentState]
    
    var agentURL: URL
    var resourceName: String
    var resourceNameWithSuffix: String
    var spriteMap: CGImage
    let soundsURL: URL
    
    init?(agentURL: URL) {
        self.agentURL = agentURL
        self.soundsURL = agentURL.appendingPathComponent("sounds")
        self.resourceNameWithSuffix = agentURL.lastPathComponent
        self.resourceName = resourceNameWithSuffix.replacingOccurrences(of: ".agent", with: "")
        
        let log = AppLog.agent
        // A local, because the log interpolations are escaping autoclosures and
        // reading `self` from inside one of those only compiles under Swift 6.
        let name = resourceName
        let fileURL = agentURL.appendingPathComponent("\(name).acd")
        let imageURL = agentURL.appendingPathComponent("\(name)_sprite_map.png")
        
        // Every failure below is a user dropping a malformed `.agent` folder into
        // `~/Library/Application Support/Clippy/Agents`. Each one used to be a bare
        // `return nil`, so a broken agent just failed to appear with nothing in the
        // log to say why.
        guard let fileContent = try? String(contentsOf: fileURL, encoding: String.Encoding.utf8) else {
            log.error("No readable character file at \(fileURL.path, privacy: .public)")
            return nil
        }
        
        // Character
        guard let characterText = fileContent.fetchInclusive("DefineCharacter", until: "EndCharacter").first else {
            log.error("\(name, privacy: .public): no DefineCharacter block")
            return nil
        }
        guard let character = AgentCharacter.parse(content: characterText) else {
            log.error("\(name, privacy: .public): DefineCharacter block is missing a required field")
            return nil
        }
        
        // Balloon
        guard let balloonText = fileContent.fetchInclusive("DefineBalloon", until: "EndBalloon").first else {
            log.error("\(name, privacy: .public): no DefineBalloon block")
            return nil
        }
        guard let balloon = AgentBalloon.parse(content: balloonText) else {
            log.error("\(name, privacy: .public): DefineBalloon block is missing a required field")
            return nil
        }
        
        // Animations
        let animationTexts = fileContent.fetchInclusive("DefineAnimation", until: "EndAnimation")
        let animations = animationTexts.compactMap { AgentAnimation.parse(content: $0) }
        if animations.count != animationTexts.count {
            log.error("\(name, privacy: .public): \(animationTexts.count - animations.count) of \(animationTexts.count) animations failed to parse")
        }
        
        // States
        let stateTexts = fileContent.fetchInclusive("DefineState", until: "EndState")
        let states = stateTexts.compactMap { AgentState.parse(content: $0) }
        
        // Sprite Map
        guard let image = NSImage(contentsOf: imageURL)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            log.error("No readable sprite map at \(imageURL.path, privacy: .public)")
            return nil
        }
        spriteMap = image
        
        self.character = character
        self.balloon = balloon
        self.animations = animations
        self.states = states
        
        // Bound to locals first: `columns`/`rows` read `self`, and interpolating
        // them straight into the log closure trips the escaping-autoclosure check.
        let columnCount = columns
        let rowCount = rows
        log.debug("\(name, privacy: .public) loaded: \(animations.count) animations, \(states.count) states, \(columnCount)x\(rowCount) grid")
    }
    
    init?(resourceName: String) {
        let directoryName = "\(resourceName).agent"
        self.init(agentURL: Agent.agentsURL().appendingPathComponent(directoryName))
    }
    
    /// Extensions a sound may carry, most specific first.
    ///
    /// The agents shipped with the app hold MP3; ones built by `AgentConverter`
    /// hold AAC in an MPEG-4 container, because macOS can decode MP3 but not
    /// encode it. A `.wav` source folder may also be dropped in untouched.
    private static let soundExtensions = ["m4a", "mp3", "wav"]

    func soundURL(forIndex index: Int) -> URL {
        let baseName = "\(resourceName)_\(index)"
        let fileManager = FileManager.default
        for ext in Self.soundExtensions {
            let candidate = soundsURL.appendingPathComponent("\(baseName).\(ext)")
            if fileManager.fileExists(atPath: candidate.path) { return candidate }
        }
        // Nothing on disk yet: return the converter's format so callers still
        // get a usable URL to hand to `AVPlayer`.
        return soundsURL.appendingPathComponent("\(baseName).m4a")
    }
    
    func findAnimation(_ name: String) -> AgentAnimation? {
        return animations.first(where: { $0.name == name })
    }
}

extension Agent {
    var columns: Int {
        guard character.width > 0 else { return 0 }
        return Int(spriteMap.width) / character.width
    }
    var rows: Int {
        guard character.height > 0 else { return 0 }
        return Int(spriteMap.height) / character.height
    }
    
    /// - Returns: `nil` when the sprite map has no cell at that position, or when
    ///   cropping fails. A malformed `.acd` should cost a frame, not the app.
    func textureAtPosition(x: Int, y: Int) -> CGImage? {
        guard character.width > 0, character.height > 0,
              (0..<rows).contains(y), (0..<columns).contains(x) else { return nil }
        let rect = CGRect(x: x * character.width,
                          y: y * character.height,
                          width: character.width,
                          height: character.height)
        return spriteMap.cropping(to: rect)
    }
    
    func textureAtIndex(index: Int) -> CGImage? {
        guard columns > 0 else { return nil }
        return textureAtPosition(x: index % columns, y: index / columns)
    }
    
    func imageForFrame(_ frame: AgentFrame) -> CGImage? {
        let images = frame.images.reversed().compactMap { textureAtIndex(index: $0.imageNumber) }
        return CGImage.mergeImages(images) ?? textureAtIndex(index: 0)
    }
}

extension Agent {
    static func agentsURL() -> URL {
        let fileManager = FileManager.default
        
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Cant create Agents directory")
        }
        
        let agentsURL = applicationSupportURL.appendingPathComponent("Clippy/Agents", isDirectory: true)
        createAgentsDirectoriesIfNeeded(url: agentsURL)
        
        return agentsURL
    }
    
    static func createAgentsDirectoriesIfNeeded(url: URL) {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: url.path) else { return }
        
        do {
            try fileManager.createDirectory(at: url,
                                           withIntermediateDirectories: true,
                                           attributes: nil)
        } catch {
            AppLog.agent.error("Could not create \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }
        
        for name in ["clippit", "links", "merlin"] {
            guard let agentsArchiveURL = Bundle.main.url(forResource: "\(name).agent", withExtension: "zip") else {
                AppLog.agent.error("\(name).agent.zip is missing from the app bundle")
                continue
            }
            let destination = url.appendingPathComponent("\(name).agent.zip")
            do {
                try fileManager.copyItem(at: agentsArchiveURL, to: destination)
            } catch {
                AppLog.agent.error("Could not copy \(name).agent.zip: \(error.localizedDescription, privacy: .public)")
            }
        }
        
        unpackBundledArchives(in: url)
    }
    
    /// Expands every `*.agent.zip` in the Agents directory.
    ///
    /// The app only ever *copied* these archives on first launch, so the user had
    /// to unzip them by hand before any agent appeared. Extraction happens here
    /// instead, which is also what `agentNames()` relies on to see the agents.
    ///
    /// A directory that is already unpacked is left alone, so this is safe to run
    /// on every launch and never discards an agent the user has edited. Pass
    /// `force` to overwrite it anyway.
    @discardableResult
    static func unpackBundledArchives(in directory: URL? = nil, force: Bool = false) -> [String] {
        let fileManager = FileManager.default
        let agentsDirectory = directory ?? agentsURL()
        guard let contents = try? fileManager.contentsOfDirectory(at: agentsDirectory,
                                                                  includingPropertiesForKeys: nil) else {
            AppLog.agent.error("Could not list agents in \(agentsDirectory.path, privacy: .public)")
            return []
        }
        
        var unpacked: [String] = []
        for archive in contents where archive.pathExtension.lowercased() == "zip" {
            let name = archive.deletingPathExtension().lastPathComponent
            guard name.hasSuffix(".agent") else { continue }
            
            let target = agentsDirectory.appendingPathComponent(name)
            let isAlreadyUnpacked = isValidAgentFolder(target, resourceName: String(name.dropLast(".agent".count)))
            if isAlreadyUnpacked && !force { continue }
            
            do {
                try unpack(archive: archive, into: agentsDirectory)
                try? fileManager.removeItem(at: agentsDirectory.appendingPathComponent("__MACOSX"))
                unpacked.append(name)
            } catch {
                AppLog.agent.error("Could not unpack \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
                // A half-extracted folder would be picked up as a broken agent.
                try? fileManager.removeItem(at: target)
            }
        }
        return unpacked
    }
    
    /// `Agent(resourceName:)` needs the character file and the sprite map to
    /// exist before it can read a folder, so their presence is what marks an
    /// agent as unpacked.
    private static func isValidAgentFolder(_ url: URL, resourceName: String) -> Bool {
        let fileManager = FileManager.default
        let acd = url.appendingPathComponent("\(resourceName).acd")
        let spriteMap = url.appendingPathComponent("\(resourceName)_sprite_map.png")
        return fileManager.fileExists(atPath: acd.path) && fileManager.fileExists(atPath: spriteMap.path)
    }
    
    private static func unpack(archive: URL, into directory: URL) throws {
        let fileManager = FileManager.default
        let archive = try ZipArchive(url: archive)
        
        for entry in try archive.entries() {
            // Resource-fork and Finder metadata would otherwise show up as
            // ordinary files inside the agent folder.
            guard !entry.name.hasPrefix("__MACOSX/"),
                  !entry.name.hasPrefix("__MACOSX"),
                  !entry.name.components(separatedBy: "/").contains("__MACOSX"),
                  !entry.name.hasSuffix(".DS_Store"),
                  !entry.name.hasPrefix("/"),
                  !entry.name.contains("..") else { continue }
            
            let destination = directory.appendingPathComponent(entry.name)
            if entry.name.hasSuffix("/") {
                try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
                continue
            }
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
            try archive.data(for: entry).write(to: destination, options: .atomic)
        }
    }
    
    static func agentNames() -> [String] {
        var agentNames: [String] = []
        let fileManager = FileManager.default
        let agentsURL = agentsURL()
        // Dropping a `*.agent.zip` into the folder is the other supported way to
        // add an agent, so Reload has to expand it before listing.
        unpackBundledArchives(in: agentsURL)
        guard let items = try? fileManager.contentsOfDirectory(at: agentsURL,
                                                               includingPropertiesForKeys: nil,
                                                               options: []) else {
            // Otherwise this surfaces only as an empty "Sprites" menu, which reads
            // as "you have no agents" rather than "Clippy cannot read its own folder".
            AppLog.agent.error("Could not list agents in \(agentsURL.path, privacy: .public)")
            return []
        }
        
        for item in items {
            if item.hasDirectoryPath && item.lastPathComponent.hasSuffix(".agent") {
                agentNames.append(item.lastPathComponent.replacingOccurrences(of: ".agent", with: ""))
            }
        }
        return agentNames.sorted()
    }
    
    static func randomAgentName() -> String? {
        agentNames().randomElement()
    }
}

