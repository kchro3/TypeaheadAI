//
//  View+Extension.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/27/24.
//

import Combine
import Foundation
import SwiftUI

/// Taken from: https://stackoverflow.com/questions/53616609/how-to-ask-for-accessibility-permission-in-macos
public extension View {
    func checkAccessibility(interval: TimeInterval, access: Binding<Bool>) -> some View {
        self.modifier( AccessibilityCheckMod(interval: interval, access: access) )
    }

    func checkAccessibilityOnAppear(access: Binding<Bool>) -> some View {
        self.onAppear {
            access.wrappedValue = AXIsProcessTrusted()
        }
    }
}

public struct AccessibilityCheckMod: ViewModifier {
    let timer: Publishers.Autoconnect<Timer.TimerPublisher>
    @Binding var access: Bool

    init(interval: TimeInterval, access: Binding<Bool>) {
        self.timer = Timer.publish(every: interval, on: .current, in: .common).autoconnect()
        _access = access
    }

    public func body(content: Content) -> some View {
        content
            .onReceive(timer) { _ in
                let privAccess = AXIsProcessTrusted()

                if self.access != privAccess {
                    self.access = privAccess
                }
            }
    }
}
