//
//  AgentState.swift
//  Clippy
//
//  Created by Devran on 07.09.19.
//  Copyright © 2026 Kuzey Bilgin. All rights reserved.
//

import Foundation

struct AgentState {
    let name: String
    let animationNames: [String]
}

extension AgentState {
    static func parse(content: String) -> AgentState? {
        var name: String?
        var animationNames: [String] = []
        content.enumerateLines { line, _ in
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.starts(with: "DefineState ") {
                name = trimmedLine.stringValueOfDefinition(onKey: "DefineState")?.removedQuotes()
            }
            if trimmedLine.starts(with: "Animation "), let animationName = trimmedLine.stringValueOfKeyValue(onKey: "Animation")?.removedQuotes() {
                animationNames.append(animationName)
            }
        }

        if let name {
            return AgentState(name: name, animationNames: animationNames)
        }
        return nil
    }
}
