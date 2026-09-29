//
//  AppLog.swift
//  Clippy
//
//  Created by Kuzey Bilgin on 2026-09-29.
//  Copyright © 2026 Devran. All rights reserved.
//

import Foundation
import os

/// The single place the app's loggers are defined.
///
/// The subsystem is read from the bundle identifier rather than repeated as a
/// literal, because a copy that falls out of step with `PRODUCT_BUNDLE_IDENTIFIER`
/// splits the log across two subsystems and the failures become invisible. That
/// already happened once: settings errors were logging to `com.cosmo.clippy`
/// while everything else used `com.meenbeese.clippy`.
///
/// Categories double as filters, so `log stream --predicate 'category == "agent"'
/// isolates one subsystem of the app.
enum AppLog {
    enum Category: String {
        /// Reading and writing `UserDefaults`.
        case settings
        /// Reading agent bundles off disk and decoding sprite maps.
        case agent
    }

    /// Falls back to the shipping identifier only if there is no bundle at all,
    /// which never happens for the app itself.
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.meenbeese.clippy"

    static func logger(_ category: Category) -> Logger {
        return Logger(subsystem: subsystem, category: category.rawValue)
    }

    static let settings = logger(.settings)
    static let agent = logger(.agent)
}
