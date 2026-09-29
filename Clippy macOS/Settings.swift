//
//  Settings.swift
//  Clippy
//
//  Created by Kuzey Bilgin on 2026-09-28.
//  Copyright © 2026 Devran. All rights reserved.
//

import Foundation
import os

private let log = Logger(subsystem: "com.meenbeese.clippy", category: "settings")

/// The persisted settings. This struct is the schema: add a field here, give it a
/// default, and it round-trips through `SettingsStore` without touching anything else.
struct Settings: Equatable {
    var scale: CGFloat = 1.0
    var opacity: CGFloat = 0.5
    var isMuted = false
    var lastUsedAgent: String?
}

extension Settings: Codable {
    /// Decodes with defaults for anything missing, so a payload written by an older
    /// build keeps working after a new field is added. The synthesized conformance
    /// would throw on the first absent key and silently reset every setting.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scale = try container.decodeIfPresent(CGFloat.self, forKey: .scale) ?? 1.0
        opacity = try container.decodeIfPresent(CGFloat.self, forKey: .opacity) ?? 0.5
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        lastUsedAgent = try container.decodeIfPresent(String.self, forKey: .lastUsedAgent)
    }
}

enum SettingsError: Error {
    case encodingFailed(any Error)
    case decodingFailed(any Error)
}

/// Reads and writes `Settings` as a single plist blob under one key, so a save is
/// always atomic — a half-written state can never be observed.
@MainActor
final class SettingsStore {
    private static let key = "com.meenbeese.clippy.settings"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// - Returns: the stored settings, or the defaults if nothing is stored yet.
    ///   An unreadable payload also falls back to the defaults — losing preferences
    ///   is recoverable, refusing to launch is not — but the reason is logged so it
    ///   is not invisible the way a bare `try?` would have been.
    func load() -> Settings {
        guard let data = defaults.data(forKey: Self.key) else { return Settings() }
        do {
            return try PropertyListDecoder().decode(Settings.self, from: data)
        } catch {
            log.error("Discarding unreadable settings: \(error.localizedDescription, privacy: .public)")
            return Settings()
        }
    }

    /// Typed throws, because failing to persist is data loss and should not be a
    /// silent no-op. Callers are expected to log, not to ignore.
    func save(_ settings: Settings) throws(SettingsError) {
        do {
            let data = try PropertyListEncoder().encode(settings)
            defaults.set(data, forKey: Self.key)
        } catch {
            throw SettingsError.encodingFailed(error)
        }
    }
}
