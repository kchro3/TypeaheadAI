import SwiftUI
import KeyboardShortcuts
import AppKit
import Carbon.HIToolbox

@MainActor
final class AppState: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var isBlinking: Bool = false
    @Published var isEnabled: Bool = true
    @Published var presetsManager: PresetsManager = PresetsManager()
    
    private var globalEventMonitor: Any?
    private var blinkTimer: Timer?

    init() {
        KeyboardShortcuts.onKeyUp(for: .specialCopy) { [self] in
            self.specialCopy()
        }
        
        KeyboardShortcuts.onKeyUp(for: .specialPaste) { [self] in
            self.specialPaste()
        }

        startMonitoringCmdCAndV()
        checkAndRequestAccessibilityPermissions()
    }
    
    deinit {
        Task { // Use a task to call the method on the main actor
            await stopMonitoringCmdCAndV()
        }
    }
    
    private func startBlinking() {
        // Invalidate the previous timer if it exists
        blinkTimer?.invalidate()

        // Create and schedule a new timer
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async { self.isBlinking.toggle() }
        }
    }
    
    private func stopBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        DispatchQueue.main.async { self.isBlinking = false }
    }
    
    private func startMonitoringCmdCAndV() {
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyUp], handler: { event in
            DispatchQueue.main.async {
                let commandKeyUsed = event.modifierFlags.contains(.command)
                if event.keyCode == 8 && commandKeyUsed { // 'C' key
                    // Get the latest string content from the pasteboard
                    if let _ = NSPasteboard.general.string(forType: .string) {
                        print("copy detected")
                    }
                } else if event.keyCode == 9 && commandKeyUsed { // 'V' key
                    print("paste detected")
                }
            }
        })
    }
    
    private func stopMonitoringCmdCAndV() async {
        if let globalEventMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
        }
    }
    
    func specialCopy() {
        if !isEnabled {
            print("special copy is disabled")
            return
        }
        
        print("special copy")
        let pasteboard = NSPasteboard.general
        
        // Get the current items from the pasteboard
        let currentItems: [NSPasteboardItem] = pasteboard.pasteboardItems ?? []
        
        // Store the data for each type in a new array
        var combinedItems: [NSPasteboardItem] = []
        
        for item in currentItems {
            let newItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            combinedItems.append(newItem)
        }
        
        self.simulateCopy()

        // Append the new items to the combined items
        if let newItems = pasteboard.pasteboardItems {
            for item in newItems {
                let newItem = NSPasteboardItem()
                for type in item.types {
                    if let data = item.data(forType: type) {
                        newItem.setData(data, forType: type)
                    }
                }
                combinedItems.append(newItem)
            }
        }
        
        // Clear the pasteboard and write the combined items
        pasteboard.clearContents()
        pasteboard.writeObjects(combinedItems)

        // Debug print
        print("Number of items on pasteboard:", combinedItems.count)
    }

    func specialPaste() {
        if !isEnabled {
            print("special paste is disabled")
            return
        }
        
        print("special paste")
        let pasteboard = NSPasteboard.general
        let items = pasteboard.pasteboardItems ?? []

        if items.isEmpty {
            DispatchQueue.main.async { self.isLoading = false }
            print("No items found")
            return
        }

        var combinedString = ""
        for item in items {
            if let string = item.string(forType: .string) {
                if !combinedString.isEmpty {
                    combinedString += "\n" // Add newline delimiter between strings
                }
                combinedString += string
            }
        }

        if combinedString.isEmpty {
            DispatchQueue.main.async { self.isLoading = false }
            print("No string found")
            return
        }

        print("Combined string:", combinedString)
        
        DispatchQueue.main.async { self.isLoading = true }
        startBlinking()
        
        // Replace the current clipboard contents with the lowercase string
        pasteboard.declareTypes([.string], owner: nil)
        
        getActiveApplicationInfo { (appName, bundleIdentifier, url) in
            DispatchQueue.main.async {
                sendRequest(
                    username: NSUserName(),
                    userFullName: NSFullUserName(),
                    userObjective: self.presetsManager.getActivePrompt() ?? "",
                    copiedText: combinedString,
                    url: url ?? "none",
                    activeAppName: appName ?? "",
                    activeAppBundleIdentifier: bundleIdentifier ?? ""
                ) { result in
                    DispatchQueue.main.async { self.isLoading = false }
                    self.stopBlinking()
                    
                    switch result {
                    case .success(let response):
                        print("Response from server:", response)
                        pasteboard.setString(response, forType: .string)
                        // Simulate a paste of the lowercase string
                        self.simulatePaste()
                    case .failure(let error):
                        print("Error:", error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private func getActiveApplicationInfo(completion: @escaping (String?, String?, String?) -> Void) {
        print("get active app")
        if let activeApp = NSWorkspace.shared.frontmostApplication {
            print(activeApp)
            let appName = activeApp.localizedName
            let bundleIdentifier = activeApp.bundleIdentifier

            if bundleIdentifier == "com.google.Chrome" {
                DispatchQueue.global(qos: .userInitiated).async {
                    let url = self.getChromeActiveURL()
                    DispatchQueue.main.async {
                        completion(appName, bundleIdentifier, url)
                    }
                }
            } else {
                completion(appName, bundleIdentifier, nil)
            }
        } else {
            completion(nil, nil, nil)
        }
    }

    nonisolated private func getChromeActiveURL() -> String? {
        let source = """
            tell application "Google Chrome"
                return URL of active tab of front window
            end tell
        """

        var error: NSDictionary?
        if let script = NSAppleScript(source: source) {
            let output = script.executeAndReturnError(&error)
            return output.stringValue
        }

        if let error = error {
            print("Error retrieving URL from Chrome:", error)
        }

        return nil
    }
    
    private func simulateCopy() {
        print("simulated copy")
        // Post a Command-C keystroke
        let source = CGEventSource(stateID: .hidSystemState)!
        let cmdCDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)! // c key
        cmdCDown.flags = [.maskCommand]
        let cmdCUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)! // c key
        cmdCUp.flags = [.maskCommand]

        cmdCDown.post(tap: .cghidEventTap)
        cmdCUp.post(tap: .cghidEventTap)
    }

    private func simulatePaste() {
        print("simulated paste")
        // Post a Command-V keystroke
        let source = CGEventSource(stateID: .hidSystemState)!
        let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)! // v key
        cmdVDown.flags = [.maskCommand]
        let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)! // v key
        cmdVUp.flags = [.maskCommand]
        
        cmdVDown.post(tap: .cghidEventTap)
        cmdVUp.post(tap: .cghidEventTap)
    }
    
    private func checkAndRequestAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessibilityEnabled {
            // You can display a custom alert here to explain why the app needs accessibility permissions
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permissions Required"
                alert.informativeText = "This app requires accessibility permissions to function properly. Please grant the permissions in System Preferences."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
}

@main
struct TypeaheadAIApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        Settings {
            SettingsView()
        }

        MenuBarExtra("TypeaheadAI", systemImage: appState.isBlinking ? "list.clipboard.fill" : "list.clipboard") {
            MenuView(
                isEnabled: $appState.isEnabled,
                presetsManager: appState.presetsManager
            )
        }
        .menuBarExtraStyle(.window)
    }
}
