//
//  Application.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/11/23.
//

import Foundation

struct Application: Identifiable, Codable {
    let bundleIdentifier: String
    let appName: String
    var isWhitelisted: Bool

    var id: String {
        return bundleIdentifier
    }
}
