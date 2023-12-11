//
//  CanGetUIElements.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/9/23.
//

import AppKit
import Foundation

protocol CanGetUIElements {
    func getUIElements(appContext: AppContext?) -> UIElement?
}

extension CanGetUIElements {
    func getUIElements(appContext: AppContext?) -> UIElement? {
        var element = AXUIElementCreateSystemWide()
        if let appContext = appContext, let pid = appContext.pid {
            element = AXUIElementCreateApplication(pid)
        }
        
        return UIElement(from: element)
    }
}
