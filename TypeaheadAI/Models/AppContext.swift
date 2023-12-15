//
//  AppContext.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/20/23.
//

import Foundation

struct AppContext: Codable, Equatable {
    let appName: String?
    let bundleIdentifier: String?
    let pid: pid_t?
    var url: URL? = nil
    var screenshotPath: String? = nil
    var ocrText: String? = nil
    var serializedUIElement: String? = nil
}
