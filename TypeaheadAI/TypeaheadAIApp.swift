import SwiftUI
import KeyboardShortcuts
import AppKit
import Carbon.HIToolbox

@MainActor
final class AppState: ObservableObject {
    @Published var textFieldContent: String = ""

    init() {
        KeyboardShortcuts.onKeyUp(for: .specialPaste) { [self] in
            self.specialPaste()
        }
    }

    func specialPaste() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            // Replace the current clipboard contents with the lowercase string
            pasteboard.declareTypes([.string], owner: nil)
            
            sendRequest(prompt: string, url: "none") { result in
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

    private func simulatePaste() {
        // Post a Command-V keystroke
        let source = CGEventSource(stateID: .hidSystemState)!
        let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)! // v key
        cmdVDown.flags = [.maskCommand]
        let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)! // v key
        cmdVUp.flags = [.maskCommand]
        
        cmdVDown.post(tap: .cghidEventTap)
        cmdVUp.post(tap: .cghidEventTap)
    }
}

@main
struct TypeaheadAIApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
