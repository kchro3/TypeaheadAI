//
//  CanSetVOFocus.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/19/24.
//

import AppKit
import Foundation

protocol CanSetVOFocus {
    func voFocus(on: AXUIElement, functionCall: FunctionCall, appContext: AppContext?) async throws
}

extension CanSetVOFocus {
    func voFocus(on axElement: AXUIElement, functionCall: FunctionCall, appContext: AppContext?) async throws {
        if NSWorkspace.shared.isVoiceOverEnabled {
            let status = AXUIElementSetAttributeValue(axElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            try await Task.safeSleep(for: .milliseconds(100))

            guard status == .success else {
                throw ClientManagerError.functionCallError(
                    "Failed to set VO focus",
                    functionCall: functionCall,
                    appContext: appContext
                )
            }
        }
    }
}
