//
//  StringExtensions.swift
//  Clippy
//
//  Created by Devran on 07.09.19.
//  Copyright © 2019 Devran. All rights reserved.
//

import Foundation

extension String {
    /// The value of a `key value` definition line, e.g. `DefineInfo 0x0009` -> `0x0009`.
    ///
    /// - Returns: `nil` unless the line actually is a definition of `key`, so a
    ///   value that merely mentions the key cannot be mistaken for one.
    func stringValueOfDefinition(onKey key: String) -> String? {
        let trimmedString = self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let prefix = "\(key) "
        guard trimmedString.hasPrefix(prefix) else { return nil }
        return String(trimmedString.dropFirst(prefix.count))
    }
    
    /// The value of a `key = value` line, e.g. `Width = 124` -> `124`.
    ///
    /// - Returns: `nil` unless the line actually assigns to `key`.
    func stringValueOfKeyValue(onKey key: String) -> String? {
        let trimmedString = self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let prefix = "\(key) = "
        guard trimmedString.hasPrefix(prefix) else { return nil }
        return String(trimmedString.dropFirst(prefix.count))
    }
    
    func intValueOfKeyValue(onKey key: String) -> Int? {
        return stringValueOfKeyValue(onKey: key).flatMap(Int.init)
    }

    func removedQuotes() -> String? {
        var trimmedString = self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if trimmedString.count >= 2 {
            trimmedString.removeFirst()
            trimmedString.removeLast()
        }
        return trimmedString
    }
    
    func removedCurlyBraces() -> String? {
        var trimmedString = self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if trimmedString.count >= 2 {
            trimmedString.removeFirst()
            trimmedString.removeLast()
        }
        return trimmedString
    }
    
    func fetchInclusive(_ from: String, until: String) -> [String] {
        var elements: [String] = []
        var lastElement = ""
        var isAppending = false
        self.enumerateLines(invoking: { (line: String, stop: inout Bool) in
            if line.contains(from) {
                isAppending = true
            }
            if isAppending {
                lastElement.append("\(line)\n")
            }
            if line.contains(until) {
                isAppending = false
                elements.append(lastElement)
                lastElement = ""
            }
        })
        return elements
    }
}
