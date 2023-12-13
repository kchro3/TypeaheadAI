//
//  FunctionManager+OpenURL.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/11/23.
//

import AppKit
import Foundation

extension FunctionManager {
    func openURL(_ functionCall: FunctionCall, appInfo: AppInfo?, modalManager: ModalManager) async throws {
        let appContext = appInfo?.appContext

        guard let url = functionCall.stringArg("url") else {
            await modalManager.setError("Failed to open url...", appContext: appContext)
            return
        }

        await modalManager.appendFunction(
            "Opening \(url) and waiting for 5 seconds for the page to load...",
            functionCall: functionCall,
            appContext: appInfo?.appContext
        )

        try await openURL(url)
        try await Task.sleep(for: .seconds(5))

        await modalManager.appendTool(
            "Opened \(url) successfully",
            functionCall: functionCall,
            appContext: appContext)

        try await modalManager.continueReplying()
    }

    func openAndScrapeURL(_ functionCall: FunctionCall, appInfo: AppInfo?, modalManager: ModalManager) async throws {
        let appContext = appInfo?.appContext

        guard let url = functionCall.stringArg("url"), let prompt = functionCall.stringArg("prompt") else {
            await modalManager.setError("Failed to open and scrape url...", appContext: appContext)
            return
        }

        if url == "<current>" {
            await modalManager.appendFunction(
                "Scraping current page...",
                functionCall: functionCall,
                appContext: appInfo?.appContext
            )

            if let bundleIdentifier = appContext?.bundleIdentifier,
               let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
                // Activate the app, bringing it to the foreground
                app.activate(options: [.activateIgnoringOtherApps])
            }

            await modalManager.closeModal()
            try await Task.sleep(for: .seconds(1))
            try await simulateSelectAll()
            try await simulateCopy()
        } else {
            await modalManager.appendFunction(
                "Opening \(url). Will wait for 5 secs to load the page...",
                functionCall: functionCall,
                appContext: appContext
            )

            try await openURL(url)
            await modalManager.closeModal()
            try await Task.sleep(for: .seconds(5))
            try await simulateSelectAll()
            try await simulateCopy()
            try await simulateClose()

            if let bundleIdentifier = appContext?.bundleIdentifier,
               let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
                // Activate the app, bringing it to the foreground
                app.activate(options: [.activateIgnoringOtherApps])
            }
        }

        await modalManager.showModal()
        guard let copiedText = NSPasteboard.general.string(forType: .string) else {
            await modalManager.appendToolError("Failed to copy anything", functionCall: functionCall, appContext: appContext)
            return
        }

        if let htmlString = NSPasteboard.general.string(forType: .html),
           let links = try? htmlString.extractAttributes("href") {

            if url == "<current>" {
                await modalManager.appendTool(
                    "Here's what I copied from the current page:\n\(copiedText)\n\nLinks extracted: \(links)\n\nMy next goal: \(prompt)",
                    functionCall: functionCall,
                    appContext: appContext)
            } else {
                await modalManager.appendTool(
                    "Here's what I copied from \(url):\n\(copiedText)\n\nLinks extracted: \(links)\n\nMy next goal: \(prompt)",
                    functionCall: functionCall,
                    appContext: appContext)
            }

        } else {
            if url == "<current>" {
                await modalManager.appendTool(
                    "Here's what I copied from the current page:\n\(copiedText)\n\nMy next goal: \(prompt)",
                    functionCall: functionCall,
                    appContext: appContext)
            } else {
                await modalManager.appendTool(
                    "Here's what I copied from \(url):\n\(copiedText)\n\nMy next goal: \(prompt)",
                    functionCall: functionCall,
                    appContext: appContext)
            }
        }

        try await modalManager.continueReplying()
    }
}
