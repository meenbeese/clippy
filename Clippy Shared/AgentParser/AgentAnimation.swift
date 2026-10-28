//
//  AgentAnimation.swift
//  Clippy
//
//  Created by Devran on 07.09.19.
//  Copyright © 2026 Kuzey Bilgin. All rights reserved.
//

import Foundation

struct AgentAnimation {
    let name: String
    let transitionType: Int
    let frames: [AgentFrame]
}

extension AgentAnimation {
    static func parse(content: String) -> AgentAnimation? {
        var animationName: String?
        var transitionType: Int?
        let frameTexts = content.fetchInclusive("DefineFrame", until: "EndFrame")
        let frames = frameTexts.compactMap { AgentFrame.parse(content: $0) }

        content.enumerateLines { line, _ in
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.starts(with: "DefineAnimation ") {
                animationName = trimmedLine.stringValueOfDefinition(onKey: "DefineAnimation")?.removedQuotes()
            }
            if trimmedLine.starts(with: "TransitionType ") {
                transitionType = trimmedLine.intValueOfKeyValue(onKey: "TransitionType")
            }
        }

        if let animationName, let transitionType {
            return AgentAnimation(name: animationName, transitionType: transitionType, frames: frames)
        }
        return nil
    }
}
