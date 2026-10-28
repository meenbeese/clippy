//
//  AgentBranching.swift
//  Clippy
//
//  Created by Devran on 07.09.19.
//  Copyright © 2026 Kuzey Bilgin. All rights reserved.
//

import Foundation

struct AgentBranching {
    let branchTo: Int
    let probability: Int
}

extension AgentBranching {
    static func parse(content: String) -> [AgentBranching] {
        var branchings: [AgentBranching] = []

        var branchToBuffer: Int?
        var probabilityBuffer: Int?

        content.enumerateLines { line, _ in
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.starts(with: "BranchTo ") {
                branchToBuffer = trimmedLine.intValueOfKeyValue(onKey: "BranchTo")
            }
            if trimmedLine.starts(with: "Probability ") {
                probabilityBuffer = trimmedLine.intValueOfKeyValue(onKey: "Probability")
            }
            if let branchTo = branchToBuffer, let probability = probabilityBuffer {
                branchings.append(AgentBranching(branchTo: branchTo, probability: probability))
                branchToBuffer = nil
                probabilityBuffer = nil
            }
        }

        return branchings
    }
}
