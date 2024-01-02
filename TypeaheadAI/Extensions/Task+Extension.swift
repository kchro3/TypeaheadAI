//
//  Task+Extension.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/1/24.
//

import Foundation

extension Task where Success == Never, Failure == Never {

    /// Helper function to check for cancellations before and after sleeping
    static func sleepSafe<C>(
        for duration: C.Instant.Duration,
        tolerance: C.Instant.Duration? = nil,
        clock: C = ContinuousClock()
    ) async throws where C : Clock {
        try Task.checkCancellation()
        try await Task.sleep(for: duration, tolerance: tolerance, clock: clock)
        try Task.checkCancellation()
    }
}
