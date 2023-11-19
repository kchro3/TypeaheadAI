//
//  Notification+Extension.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/14/23.
//

import Foundation

extension Notification.Name {
    static let smartClick = Notification.Name("smartClick")

    static let smartCopyPerformed = Notification.Name("smartCopyPerformed")

    static let startOnboarding = Notification.Name("startOnboarding")

    static let oAuthCallback = Notification.Name("OAuthCallBack")
}
