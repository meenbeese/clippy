//
//  AgentInfo.swift
//  Clippy
//
//  Created by Devran on 07.09.19.
//  Copyright © 2026 Kuzey Bilgin. All rights reserved.
//

import Foundation

struct AgentInfo {
    let language: String
    let name: String
    let description: String
    let extraData: String
}

extension AgentInfo {
    static func parse(content: String) -> AgentInfo? {
        var language: String?
        var name: String?
        var description: String?
        var extraData: String?

        content.enumerateLines { line, _ in
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.starts(with: "DefineInfo ") {
                language = trimmedLine.stringValueOfDefinition(onKey: "DefineInfo")
            }
            if trimmedLine.starts(with: "Name ") {
                name = trimmedLine.stringValueOfKeyValue(onKey: "Name")?.removedQuotes()
            }
            if trimmedLine.starts(with: "Description ") {
                description = trimmedLine.stringValueOfKeyValue(onKey: "Description")?.removedQuotes()
            }
            if trimmedLine.starts(with: "ExtraData ") {
                extraData = trimmedLine.stringValueOfKeyValue(onKey: "ExtraData")?.removedQuotes()
            }
        }

        if let language, let name, let description, let extraData {
            return AgentInfo(language: language, name: name, description: description, extraData: extraData)
        }
        return nil
    }
}
