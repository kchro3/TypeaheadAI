//
//  CanSimulateCopy.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/11/23.
//

import AppKit
import Foundation
import Carbon.HIToolbox

let whitelistedApps = [
    "Numbers"
]

let whitelistedUrls = [
    "docs.google.com/spreadsheets"
]

protocol CanSimulateCopy {
    func simulateCopy(completion: @escaping () -> Void)
}

extension CanSimulateCopy {
    func simulateCopy(completion: @escaping () -> Void) {
        // Post a Command-C keystroke
        let source = CGEventSource(stateID: .hidSystemState)!
        let cmdCDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)! // c key
        cmdCDown.flags = [.maskCommand]
        let cmdCUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)! // c key
        cmdCUp.flags = [.maskCommand]

        cmdCDown.post(tap: .cghidEventTap)
        cmdCUp.post(tap: .cghidEventTap)

        // Delay for the clipboard to update, then call the completion handler
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            completion()
        }
    }

    // TODO: Only support HTML tables from specific allowlisted apps / urls for now.
    func extractHTML(appName: String?, bundleIdentifier: String?, url: String?) -> String? {
        var isWhitelisted = false
        if let appName = appName, whitelistedApps.contains(appName) {
            isWhitelisted = true
        }
        if let url = url, let _ = whitelistedUrls.first(where: { $0.contains(url) }) {
            isWhitelisted = true
        }

        if isWhitelisted,
           let html = NSPasteboard.general.data(forType: .html),
           let htmlString = String(data: html, encoding: .utf8),
           htmlString.contains("</table>") {
            return htmlString
        } else {
            return nil
        }
    }
}
