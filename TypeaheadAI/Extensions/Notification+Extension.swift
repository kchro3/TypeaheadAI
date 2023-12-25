//
//  Notification+Extension.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/14/23.
//

import Foundation

extension Notification.Name {
    static let smartCopyPerformed = Notification.Name("smartCopyPerformed")

    static let startOnboarding = Notification.Name("startOnboarding")

    static let oAuthCallback = Notification.Name("OAuthCallBack")

    static let chatComplete = Notification.Name("chatComplete")

    static let scrollToMessage = Notification.Name("scrollToMessage")

    static let appDidChange = Notification.Name("NSWorkspaceDidActivateApplicationNotification")
}
