//
//  AppContext.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/17/23.
//

import Foundation

struct AppContext: Codable {
    let appName: String?
    let bundleIdentifier: String?
    let url: URL?

    // NOTE: Consider a different way to hydrate these fields.
    var screenshotPath: String? = nil
    var ocrText: String? = nil
    var copiedText: String? = nil
}
