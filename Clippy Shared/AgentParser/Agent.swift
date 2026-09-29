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
        
        let fileURL = agentURL.appendingPathComponent("\(resourceName).acd")
        let imageURL = agentURL.appendingPathComponent("\(resourceName)_sprite_map.png")
        
        guard let fileContent = try? String(contentsOf: fileURL, encoding: String.Encoding.utf8) else { return nil }
        
        // Character
        guard let characterText = fileContent.fetchInclusive("DefineCharacter", until: "EndCharacter").first else { return nil }
        let character = AgentCharacter.parse(content: characterText)
        
        // Balloon
        guard let balloonText = fileContent.fetchInclusive("DefineBalloon", until: "EndBalloon").first else { return nil }
        let balloon = AgentBalloon.parse(content: balloonText)
        
        // Animations
        let animationTexts = fileContent.fetchInclusive("DefineAnimation", until: "EndAnimation")
        let animations = animationTexts.compactMap { AgentAnimation.parse(content: $0) }
        
        // States
        let stateTexts = fileContent.fetchInclusive("DefineState", until: "EndState")
        let states = stateTexts.compactMap { AgentState.parse(content: $0) }
        
        // Sprite Map
        guard let image = NSImage(contentsOf: imageURL)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        spriteMap = image
        
        if let character = character, let balloon = balloon {
            self.character = character
            self.balloon = balloon
            self.animations = animations
            self.states = states
        } else {
            return nil
        }
    }
    
    init?(resourceName: String) {
        let directoryName = "\(resourceName).agent"
        self.init(agentURL: Agent.agentsURL().appendingPathComponent(directoryName))
    }
    
    func soundURL(forIndex index: Int) -> URL {
        let fileName = "\(resourceName)_\(index).mp3"
        return soundsURL.appendingPathComponent(fileName)
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
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url,
                                             withIntermediateDirectories: true,
                                             attributes: nil)
            ["clippit", "links", "merlin"].forEach {
                guard let agentsArchiveURL = Bundle.main.url(forResource: "\($0).agent", withExtension: "zip") else {
                    return
                }
                try? fileManager.copyItem(at: agentsArchiveURL, to: url.appendingPathComponent("\($0).agent.zip"))
            }
        }
    }
    
    static func agentNames() -> [String] {
        var agentNames: [String] = []
        let fileManager = FileManager.default
        guard let items = try? fileManager.contentsOfDirectory(at: agentsURL(),
                                                               includingPropertiesForKeys: nil,
                                                               options: []) else {
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

